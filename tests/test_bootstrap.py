"""Linux bootstrap integration tests using real Nu and isolated HOME/XDG.

Run: NU_BIN=/path/to/nu python3 -m unittest discover -s tests -p test_bootstrap.py -v
Full bootstrap tests additionally require FNOX_BIN and ZOXIDE_BIN. Only the
mise install/which boundary is substituted (no tool downloads); fnox, zoxide,
symlinks, and tic are real. Full runs download the real WezTerm terminfo.
No system package manager or real user configuration is touched.
"""
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest


REPO = Path(__file__).resolve().parents[1]
NU = os.environ.get("NU_BIN") or shutil.which("nu")


@unittest.skipUnless(sys.platform.startswith("linux"), "Linux integration tests")
@unittest.skipUnless(NU, "Set NU_BIN or install Nu on PATH")
class BootstrapTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="dots-bootstrap-")
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.home = self.root / "home"
        self.home.mkdir()
        self.config = self.home / "xdg-config"
        self.bin = self.root / "bin"
        self.bin.mkdir()
        self.env = {
            "HOME": str(self.home),
            "XDG_CONFIG_HOME": str(self.config),
            "XDG_DATA_HOME": str(self.home / "xdg-data"),
            "XDG_CACHE_HOME": str(self.home / "xdg-cache"),
            "XDG_STATE_HOME": str(self.home / "xdg-state"),
            "TMPDIR": str(self.root),
            "PATH": f"{self.bin}:/usr/bin:/bin",
            "TERM": "xterm-256color",
        }

    def run_bootstrap(self, *args):
        assert NU is not None
        return subprocess.run(
            [NU, "--no-config-file", str(REPO / "bootstrap.nu"), *args],
            cwd=self.root, env=self.env, capture_output=True, text=True, timeout=90,
        )

    def assert_ok(self, result):
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)

    def test_linux_dry_run_does_not_check_or_install_system_packages(self):
        result = self.run_bootstrap("--dry-run")
        self.assert_ok(result)
        self.assertIn("Linux prerequisites are assumed installed", result.stdout)
        self.assertNotIn("Will apply system packages", result.stdout)
        self.assertNotIn("through brew", result.stdout)
        self.assertFalse(self.config.exists())

    def mock_mise_installs(self):
        for name in ("FNOX_BIN", "ZOXIDE_BIN"):
            if not os.environ.get(name):
                self.skipTest(f"Set {name} to exercise full bootstrap with real tools")
            self.env[name] = os.environ[name]
        self.env["MISE_CALLS"] = str(self.root / "mise-calls")
        mise = self.bin / "mise"
        mise.write_text('''#!/usr/bin/python3
import json, os, sys
args = sys.argv[1:]
with open(os.environ["MISE_CALLS"], "a") as log:
    log.write(json.dumps(args) + "\\n")
if args[:1] == ["--cd"]:
    args = args[2:]
if args == ["install", "--yes"]:
    pass  # MOCK: skip downloading/installing the entire shared toolchain.
elif args[:1] == ["which"] and args[1] in ("fnox", "zoxide"):
    print(os.environ[args[1].upper() + "_BIN"])
else:
    sys.exit("Unexpected mise invocation: " + repr(args))
''')
        mise.chmod(0o755)

    def test_linux_full_bootstrap_uses_real_integrations_and_terminfo(self):
        self.mock_mise_installs()
        result = self.run_bootstrap()
        self.assert_ok(result)
        self.assertTrue((self.home / ".gitconfig").is_symlink())
        self.assertTrue((self.home / "xdg-data/nushell/zoxide.nu").is_file())
        self.assertIn("fnox", (self.home / "xdg-data/nushell/vendor/autoload/fnox.nu").read_text())
        self.assertTrue(list((self.home / ".terminfo").rglob("wezterm")))
        self.assertNotIn("bootstrap", (self.root / "mise-calls").read_text())

    def test_managed_files_backups_and_local_state_survive_rerun(self):
        self.mock_mise_installs()
        ssh = self.home / ".ssh"
        ssh.mkdir()
        ssh_files = {"config": "Host test\n  IdentityFile ~/.ssh/device_key\n", "device_key": "synthetic-preservation-sentinel"}
        for name, content in ssh_files.items():
            (ssh / name).write_text(content)
        plugins = self.config / "yazi/plugins/local.yazi"
        plugins.mkdir(parents=True)
        (plugins / "main.lua").write_text("local plugin")
        starship = self.config / "starship.toml"
        starship.write_text("# old prompt\n")
        (self.home / ".gitconfig").write_text("[user]\nname = Local\n")
        self.assert_ok(self.run_bootstrap())
        expected = {
            "starship.toml": "starship.toml",
            "zellij/config.kdl": "zellij/config.kdl",
            "vicinae/dots": "vicinae",
            **{f"yazi/{name}.toml": f"yazi/{name}.toml"
               for name in ("yazi", "theme", "package", "keymap")},
        }
        for destination, source in expected.items():
            target = self.config / destination
            self.assertTrue(target.is_symlink(), str(target))
            self.assertEqual(target.resolve(), REPO / source)
        for name in (".vimrc", ".tmux.conf"):
            self.assertEqual((self.home / name).resolve(), REPO / name)
        self.assertFalse((self.config / "yazi").is_symlink())
        self.assertEqual((plugins / "main.lua").read_text(), "local plugin")
        settings = self.config / "vicinae/settings.json"
        self.assertFalse(settings.is_symlink())
        import json
        self.assertEqual(json.loads(settings.read_text()), {"imports": ["dots/settings.json"]})
        settings.write_text('{"imports": ["dots/settings.json"], "local": true}\n')
        backups = list(self.config.glob("starship.toml.before-dots-*"))
        self.assertEqual(len(backups), 1)
        self.assertEqual(backups[0].read_text(), "# old prompt\n")
        self.assertEqual((self.home / ".gitconfig.local").read_text(), "[user]\nname = Local\n")
        self.assert_ok(self.run_bootstrap())
        self.assertEqual(list(self.config.glob("starship.toml.before-dots-*")), backups)
        self.assertTrue(json.loads(settings.read_text())["local"])
        for name, content in ssh_files.items():
            self.assertEqual((ssh / name).read_text(), content)
        for name in (".zshenv", ".zshrc", ".zprofile", ".ignore"):
            self.assertFalse((self.home / name).exists())

    def test_late_directory_conflict_stops_before_install_or_links(self):
        self.mock_mise_installs()
        (self.config / "zellij/config.kdl").mkdir(parents=True)
        result = self.run_bootstrap()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("Config conflict", result.stderr)
        self.assertFalse((self.root / "mise-calls").exists())
        self.assertFalse((self.config / "mise").exists())

    def test_git_backup_collision_stops_before_install(self):
        self.mock_mise_installs()
        for name in (".gitconfig", ".gitconfig.local"):
            (self.home / name).write_text("keep " + name)
        result = self.run_bootstrap()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("already exists", result.stderr)
        self.assertFalse((self.root / "mise-calls").exists())
        self.assertEqual((self.home / ".gitconfig").read_text(), "keep .gitconfig")

    def test_dangling_links_are_backed_up_but_mutable_vicinae_is_preserved(self):
        self.mock_mise_installs()
        self.config.mkdir()
        starship = self.config / "starship.toml"
        starship.symlink_to(self.home / "missing-starship")
        settings = self.config / "vicinae/settings.json"
        settings.parent.mkdir()
        settings.symlink_to(self.home / "missing-local-settings")
        self.assert_ok(self.run_bootstrap())
        self.assertEqual(starship.resolve(), REPO / "starship.toml")
        backups = list(self.config.glob("starship.toml.before-dots-*"))
        self.assertEqual(len(backups), 1)
        self.assertEqual(backups[0].readlink(), self.home / "missing-starship")
        self.assertEqual(settings.readlink(), self.home / "missing-local-settings")
        self.assertFalse(settings.exists())

    def test_explicit_config_overrides_are_respected(self):
        self.mock_mise_installs()
        self.env.update({
            "MISE_CONFIG_DIR": str(self.home / "custom-mise"),
            "MISE_GLOBAL_CONFIG_FILE": str(self.home / "global-mise.toml"),
            "STARSHIP_CONFIG": str(self.home / "custom-starship.toml"),
            "YAZI_CONFIG_HOME": str(self.home / "custom-yazi"),
        })
        self.assert_ok(self.run_bootstrap())
        for target, source in {
            "custom-mise/tasks": "mise/tasks",
            "global-mise.toml": "mise/config.toml",
            "custom-starship.toml": "starship.toml",
            "custom-yazi/keymap.toml": "yazi/keymap.toml",
        }.items():
            self.assertEqual((self.home / target).resolve(), REPO / source)

    def test_termux_is_rejected_before_changes(self):
        for marker in ({"TERMUX_VERSION": "0.118.0"}, {"PREFIX": "/data/data/com.termux/files/usr"}):
            with self.subTest(marker=marker):
                self.env.update(marker)
                result = self.run_bootstrap("--dry-run")
                self.assertNotEqual(result.returncode, 0)
                self.assertIn("Termux", result.stderr)
                self.assertFalse(self.config.exists())
                for name in marker:
                    self.env.pop(name)


if __name__ == "__main__":
    unittest.main()
