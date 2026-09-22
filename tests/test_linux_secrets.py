"""Real Nu/fnox/age integration; all writes stay in a temporary HOME.
Run: NU_BIN=/path/to/nu FNOX_BIN=/path/to/fnox AGE_KEYGEN_BIN=/path/to/age-keygen python3 -m unittest discover -s tests -p test_linux_secrets.py -v
"""
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import tomllib
import time
import unittest

ROOT = Path(__file__).resolve().parents[1]


class LinuxSecrets(unittest.TestCase):
    def setUp(self):
        self.tools = {name: os.environ.get(var) or shutil.which(name) for name, var in
                      [('nu', 'NU_BIN'), ('fnox', 'FNOX_BIN'), ('age-keygen', 'AGE_KEYGEN_BIN')]}
        if not all(self.tools.values()):
            self.skipTest('Requires real nu, fnox, age-keygen (or *_BIN overrides)')
        self.tools = {name: str(path) for name, path in self.tools.items()}
        self.tmp = tempfile.TemporaryDirectory(prefix='dots-secrets-', dir=os.environ.get('TMPDIR'))
        self.addCleanup(self.tmp.cleanup)
        self.home = Path(self.tmp.name)
        self.config = self.home / '.config/fnox/config.toml'
        bindir = self.home / 'bin'
        bindir.mkdir()
        # Only tool discovery is stubbed: no host mise configuration/trust changes.
        mise = bindir / 'mise'
        mise.write_text('#!/usr/bin/python3\nimport sys\ntools = ' + repr(self.tools) + '\nprint(tools[sys.argv[-1]])\n')
        mise.chmod(0o755)
        self.op_calls = self.home / 'op-calls'
        self.script('op', f"from pathlib import Path\nPath({str(self.op_calls)!r}).touch()\nraise SystemExit(91)\n")
        self.env = {'HOME': str(self.home), 'PATH': f'{bindir}:/usr/bin:/bin',
                    'XDG_CONFIG_HOME': str(self.home / '.config'),
                    'XDG_DATA_HOME': str(self.home / '.local/share'),
                    'FNOX_CONFIG_DIR': str(self.config.parent), 'FNOX_NO_DAEMON': '1'}

    def script(self, name, body):
        target = self.home / 'bin' / name
        target.write_text('#!/usr/bin/python3\n' + body)
        target.chmod(0o755)
        return target

    def fail_chmod(self, target):
        self.script('chmod', 'import os, sys\n'
                    + f'if sys.argv[-1].endswith({target!r}): raise SystemExit(73)\n'
                    + 'os.execv("/bin/chmod", ["chmod", *sys.argv[1:]])\n')

    def test_concurrent_setup_rejects_contender_and_preserves_winner(self):
        entered, release = self.home / 'entered', self.home / 'release'
        real = self.tools['age-keygen']
        wrapper = self.script('paused-age-keygen',
            'import os, sys, time\nfrom pathlib import Path\n'
            + f'entered, release = Path({str(entered)!r}), Path({str(release)!r})\n'
            + 'if "-o" in sys.argv and not entered.exists():\n'
            + '    entered.touch()\n    deadline = time.monotonic() + 15\n'
            + '    while not release.exists():\n'
            + '        if time.monotonic() > deadline: raise SystemExit(90)\n'
            + '        time.sleep(0.01)\n'
            + f'os.execv({real!r}, [{real!r}, *sys.argv[1:]])\n')
        tools = dict(self.tools, **{'age-keygen': str(wrapper)})
        self.script('mise', 'import sys\ntools = ' + repr(tools) + '\nprint(tools[sys.argv[-1]])\n')
        first = subprocess.Popen([self.tools['nu'], '--no-config-file', '-c',
            f'use {json.dumps(str(ROOT / "nushell/secrets.nu"))}; secrets setup'],
            env=self.env, cwd=self.home, text=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        try:
            deadline = time.monotonic() + 10
            while not entered.exists() and first.poll() is None and time.monotonic() < deadline:
                time.sleep(0.01)
            self.assertTrue(entered.exists(), 'first enrollment did not reach key generation')
            lock = self.config.parent / '.dots-setup.lock'
            self.assertEqual(lock.stat().st_mode & 0o777, 0o700)
            contender = self.nu('secrets setup', ok=False)
            self.assertTrue(lock.is_dir(), 'contender removed the owner lock')
            self.assertIn('enrollment lock', contender.stderr)
            self.assertFalse(self.config.exists())
        finally:
            release.touch()
            stdout, stderr = first.communicate(timeout=20)
        self.assertEqual(first.returncode, 0, stderr)
        self.assertFalse((self.config.parent / '.dots-setup.lock').exists())
        self.fnox('set', '--global', 'CONCURRENT', '--provider', 'dots-age', input='synthetic-race')
        key = self.config.parent / 'age.txt'
        before = (key.read_bytes(), self.config.read_bytes())
        self.nu('secrets setup')
        self.assertEqual(before, (key.read_bytes(), self.config.read_bytes()))
        self.assertEqual(self.fnox('get', 'CONCURRENT').stdout.strip(), 'synthetic-race')
        self.assertFalse(self.op_calls.exists())

    def test_existing_recipient_mismatch_is_not_replaced(self):
        self.nu('secrets setup')
        key = self.config.parent / 'age.txt'
        key.unlink()
        subprocess.run([self.tools['age-keygen'], '-o', str(key)], check=True, capture_output=True)
        before = (key.read_bytes(), self.config.read_bytes())
        self.nu('secrets setup', ok=False)
        self.assertEqual(before, (key.read_bytes(), self.config.read_bytes()))
        self.assertFalse((self.config.parent / '.dots-setup.lock').exists())

    def test_init_chmod_failure_stops_before_template_write(self):
        self.fail_chmod('/fnox')
        self.nu('secrets init', ok=False)
        self.assertFalse((self.config.parent / 'sources.toml').exists())

    def test_chmod_failure_stops_before_identity_copy(self):
        source = self.home / 'import.txt'
        subprocess.run([self.tools['age-keygen'], '-o', str(source)], check=True, capture_output=True)
        self.fail_chmod('/fnox')
        self.nu(f'secrets setup --identity {json.dumps(str(source))}', ok=False)
        self.assertFalse(self.config.exists())
        self.assertFalse(list(self.config.parent.rglob('age.txt')))

    def test_staging_chmod_failure_cleans_up_before_import(self):
        source = self.home / 'import.txt'
        subprocess.run([self.tools['age-keygen'], '-o', str(source)], check=True, capture_output=True)
        self.script('chmod', 'import os, sys\n'
                    + 'if ".dots-enroll-" in sys.argv[-1]: raise SystemExit(73)\n'
                    + 'os.execv("/bin/chmod", ["chmod", *sys.argv[1:]])\n')
        self.nu(f'secrets setup --identity {json.dumps(str(source))}', ok=False)
        self.assertFalse(list(self.config.parent.rglob('age.txt')))
        self.assertFalse(list(self.config.parent.glob('.dots-enroll-*')))

    def test_chmod_failure_prevents_publication(self):
        for filename in ('age.txt', 'config.toml'):
            with self.subTest(filename=filename):
                self.fail_chmod(filename)
                self.nu('secrets setup', ok=False)
                self.assertFalse(self.config.exists())
                self.assertFalse((self.config.parent / 'age.txt').exists())
                self.assertFalse(list(self.config.parent.glob('.dots-enroll-*')))

    def test_refresh_chmod_failure_preserves_cache_and_cleans_staging(self):
        self.nu('secrets setup')
        before = self.config.read_bytes()
        for target in ('.dots-refresh-', 'config.toml'):
            with self.subTest(target=target):
                self.script('chmod', 'import os, sys\n'
                            + f'if {target!r} in sys.argv[-1]: raise SystemExit(73)\n'
                            + 'os.execv("/bin/chmod", ["chmod", *sys.argv[1:]])\n')
                self.nu('secrets refresh', ok=False)
                self.assertEqual(before, self.config.read_bytes())
                self.assertFalse(list(self.config.parent.glob('.dots-refresh-*')))

    def nu(self, command, ok=True):
        result = subprocess.run([self.tools['nu'], '--no-config-file', '-c',
                                 f'use {json.dumps(str(ROOT / "nushell/secrets.nu"))}; {command}'],
                                env=self.env, cwd=self.home, text=True, capture_output=True)
        if ok:
            self.assertEqual(result.returncode, 0, result.stderr)
        else:
            self.assertNotEqual(result.returncode, 0)
        return result

    def fnox(self, *args, input=None, ok=True):
        result = subprocess.run([self.tools['fnox'], '--no-daemon', '--non-interactive', *args],
                                env=self.env, cwd=self.home, input=input, text=True, capture_output=True)
        if ok:
            self.assertEqual(result.returncode, 0, result.stderr)
        return result

    def test_linux_enrollment_is_private_idempotent_and_works_without_op(self):
        self.nu('secrets setup')
        settings = tomllib.loads(self.config.read_text())
        provider = settings['providers']['dots-age']
        self.assertEqual(provider['type'], 'age')
        identity = Path(provider['key_file'])
        self.assertEqual(identity.stat().st_mode & 0o777, 0o600)
        self.assertEqual(self.config.stat().st_mode & 0o777, 0o600)
        self.assertEqual(self.config.parent.stat().st_mode & 0o777, 0o700)
        self.assertNotIn('dots-keychain', settings['providers'])
        self.fnox('set', '--global', 'TEST_DOTS_SECRET', '--provider', 'dots-age', input='synthetic-test-only')
        before = (self.config.read_bytes(), identity.read_bytes())
        self.nu('secrets setup')
        self.assertEqual(before, (self.config.read_bytes(), identity.read_bytes()))
        self.assertEqual(self.fnox('get', 'TEST_DOTS_SECRET').stdout.strip(), 'synthetic-test-only')
        self.assertNotIn('synthetic-test-only', self.config.read_text())
        injected = self.fnox('exec', '--', '/bin/sh', '-c', 'test "$TEST_DOTS_SECRET" = synthetic-test-only')
        self.assertEqual(injected.stdout, '')
        self.assertNotIn('AGE-SECRET-KEY-', self.config.read_text())
        self.assertFalse(self.op_calls.exists())

    def test_native_hook_loads_local_cache_without_op(self):
        self.nu('secrets setup; secrets setup-shell')
        self.fnox('set', '--global', 'TEST_DOTS_SECRET', '--provider', 'dots-age', input='synthetic-hook')
        hook = self.home / '.local/share/nushell/vendor/autoload/fnox.nu'
        self.assertTrue(hook.exists())
        result = self.nu(
            f'source {json.dumps(str(hook))}; '
            'if $env.TEST_DOTS_SECRET? != "synthetic-hook" { error make {msg: "hook did not load cache"} }; '
            'if $env.DOTS_AGE_IDENTITY? != null { error make {msg: "identity exported"} }'
        )
        self.assertNotIn('synthetic-hook', result.stdout + result.stderr)
        self.assertFalse(self.op_calls.exists())

    def test_refresh_uses_real_age_source_and_failed_op_preserves_cache(self):
        self.nu('secrets setup')
        sources = self.config.parent / 'sources.toml'
        sources.write_text(self.config.read_text().replace('dots-age', 'source-age'))
        self.fnox('--config', str(sources), 'set', 'TEST_REFRESH', '--provider', 'source-age', input='synthetic-refresh')
        self.nu('secrets refresh')
        self.assertEqual(self.fnox('get', 'TEST_REFRESH').stdout.strip(), 'synthetic-refresh')
        self.assertEqual(self.config.stat().st_mode & 0o777, 0o600)
        self.assertFalse(self.op_calls.exists())
        before = self.config.read_bytes()
        sources.write_text('[providers.onepassword]\ntype="1password"\n[secrets]\nTEST_REFRESH={provider="onepassword",value="op://Fake/Absent/credential"}\n')
        self.nu('secrets refresh', ok=False)
        self.assertTrue(self.op_calls.exists())
        self.assertEqual(before, self.config.read_bytes())
        self.assertEqual(self.fnox('get', 'TEST_REFRESH').stdout.strip(), 'synthetic-refresh')
        self.assertFalse(list(self.config.parent.glob('.dots-refresh-*')))

    def test_init_creates_private_sources_and_has_no_module_side_effects(self):
        self.nu('null')
        self.assertFalse(self.config.parent.exists())
        self.nu('secrets init')
        self.assertEqual((self.config.parent / 'sources.toml').stat().st_mode & 0o777, 0o600)
        self.assertEqual(self.config.parent.stat().st_mode & 0o777, 0o700)

    def test_import_is_explicit_validated_and_never_replaces_identity(self):
        source = self.home / 'import.txt'
        subprocess.run([self.tools['age-keygen'], '-o', str(source)], check=True, capture_output=True)
        self.nu(f'secrets setup --identity {json.dumps(str(source))}')
        key = self.config.parent / 'age.txt'
        self.assertEqual(key.read_bytes(), source.read_bytes())
        before = (key.read_bytes(), self.config.read_bytes())
        self.nu(f'secrets setup --identity {json.dumps(str(source))}', ok=False)
        self.assertEqual(before, (key.read_bytes(), self.config.read_bytes()))

    def test_existing_unrelated_config_and_missing_key_are_not_replaced(self):
        self.config.parent.mkdir(parents=True)
        self.config.write_text('[providers.other]\ntype="age"\nrecipients=[]\n')
        before = self.config.read_bytes()
        self.nu('secrets setup', ok=False)
        self.assertEqual(before, self.config.read_bytes())
        self.config.unlink()
        self.nu('secrets setup')
        key = self.config.parent / 'age.txt'
        key.unlink()
        before = self.config.read_bytes()
        self.nu('secrets setup', ok=False)
        self.assertFalse(key.exists())
        self.assertEqual(before, self.config.read_bytes())

    def test_orphan_identity_requires_explicit_import(self):
        self.config.parent.mkdir(parents=True)
        key = self.config.parent / 'age.txt'
        subprocess.run([self.tools['age-keygen'], '-o', str(key)], check=True, capture_output=True)
        before = key.read_bytes()
        self.nu('secrets setup', ok=False)
        self.assertFalse(self.config.exists())
        self.nu(f'secrets setup --identity {json.dumps(str(key))}')
        self.assertEqual(before, key.read_bytes())

    def test_invalid_import_leaves_no_config_or_identity(self):
        source = self.home / 'invalid.txt'
        source.write_text('not an age key')
        self.nu(f'secrets setup --identity {json.dumps(str(source))}', ok=False)
        self.assertFalse(self.config.exists())
        self.assertFalse((self.config.parent / 'age.txt').exists())


if __name__ == '__main__':
    unittest.main()
