"""Linux Nu startup/clipboard tests. Real Nu, fake integration/clipboard commands."""
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
NU = os.environ.get("NU_BIN") or shutil.which("nu")


@unittest.skipUnless(NU, "set NU_BIN or put nu on PATH")
class LinuxShell(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory(prefix="dots-shell-")
        self.addCleanup(self.tmp.cleanup)
        self.home = Path(self.tmp.name)
        self.bin = self.home / ".local/bin"
        self.bin.mkdir(parents=True)
        self.env = {
            "HOME": str(self.home), "PATH": f"{self.bin}:/usr/bin:/bin",
            "XDG_CONFIG_HOME": str(self.home / ".config"),
            "XDG_DATA_HOME": str(self.home / ".local/share"),
            "XDG_CACHE_HOME": str(self.home / ".cache"),
            "SSH_AUTH_SOCK": "/device/agent.sock", "TERM": "xterm",
        }
        self.command("mise", '#!/bin/sh\nprintf "export-env {}\\n"\n')
        data = self.home / ".local/share/nushell"
        data.mkdir(parents=True)
        (data / "zoxide.nu").write_text("")

    def command(self, name, text):
        path = self.bin / name
        path.write_text(text)
        path.chmod(0o755)

    def nu(self, code, success=True):
        assert NU is not None
        result = subprocess.run(
            [NU, "--env-config", str(ROOT / "nushell/env.nu"),
             "--config", str(ROOT / "nushell/config.nu"), "-i", "-c", code],
            env=self.env, cwd=self.home, text=True, capture_output=True,
        )
        if success:
            self.assertEqual(result.returncode, 0, result.stderr)
        return result

    def test_linux_shell_and_device_agent(self):
        result = json.loads(self.nu(
            '{shell: $env.SHELL, exe: $nu.current-exe, sock: $env.SSH_AUTH_SOCK, path: $env.PATH} | to json -r'
        ).stdout)
        self.assertEqual(result["shell"], result["exe"])
        self.assertEqual(result["sock"], self.env["SSH_AUTH_SOCK"])
        self.assertIn(str(self.bin), result["path"])

    def clipboard_commands(self):
        program = '''#!/usr/bin/python3
import os, pathlib, sys
p = pathlib.Path(os.environ['HOME']) / 'clipboard'
if pathlib.Path(sys.argv[0]).name == 'wl-copy' or '-in' in sys.argv:
    p.write_bytes(sys.stdin.buffer.read())
else:
    sys.stdout.buffer.write(p.read_bytes())
'''
        for name in ("wl-copy", "wl-paste", "xclip"):
            self.command(name, program)

    def test_wayland_clipboard_preserves_bytes(self):
        self.clipboard_commands()
        self.env["WAYLAND_DISPLAY"] = "wayland-0"
        text = "linux ✓\n\n"
        code = f'{json.dumps(text, ensure_ascii=False)} | pbcopy; pbpaste | to json -r'
        self.assertEqual(json.loads(self.nu(code).stdout), text)

    def test_x11_clipboard_preserves_bytes(self):
        self.clipboard_commands()
        self.env["DISPLAY"] = ":0"
        text = "x11 ✓\n"
        self.assertEqual(json.loads(self.nu(
            f'{json.dumps(text, ensure_ascii=False)} | pbcopy; pbpaste | to json -r'
        ).stdout), text)

    def test_headless_clipboard_reports_missing_session(self):
        result = self.nu('"test" | pbcopy', success=False)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("display", result.stderr.lower())


if __name__ == "__main__":
    unittest.main()
