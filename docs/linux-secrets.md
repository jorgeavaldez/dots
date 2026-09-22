# Linux secrets without 1Password

Linux enrollment uses a file-backed age identity. It does not require `op`, a
keyring daemon, a desktop session, or a 1Password SSH agent. Ordinary OpenSSH
keys/agents work independently; these commands do not change SSH configuration
or `SSH_AUTH_SOCK`. Windows and macOS retain native credential-store enrollment.

## Enroll deliberately

After bootstrap has installed `fnox` and `age`, run in Nu:

```nu
secrets setup
```

This generates `~/.config/fnox/age.txt` and `config.toml` (mode `600`) inside a
mode-`700` directory. `FNOX_CONFIG_DIR`, when set, selects a different directory.
`secrets init` only creates a private `sources.toml` template; it does not enroll
or fetch credentials. Bootstrap installs the native shell hook but does not
create an identity. No tool-path lookups happen merely by importing the module.

To restore an existing **age identity file** instead of generating one:

```nu
secrets setup --identity /secure/restore/age.txt
```

The file is validated with `age-keygen -y`, copied into the private configuration
directory, and never printed. This is an age identity, not an SSH private key.
The source copy is not deleted. Secure or remove restoration media yourself.
Import refuses an already-enrolled config; ordinary setup verifies and preserves
an existing identity/cache. Missing, mismatched or unreadable identities are not
silently regenerated. An orphan `age.txt` requires explicit `--identity` pointing
to that same file. Unrelated fnox configurations are never overwritten.

Linux setup takes an atomic, mode-`700` `.dots-setup.lock` directory before
checking existing enrollment or writing an identity. Concurrent setup fails
without changing the active enrollment; retry when the first command finishes.
Normal success and errors release the lock. A killed process or power loss can
leave a stale lock: remove that empty directory only after verifying no setup
process is running, then retry. Directory permission failures abort before copying
private material into staging; file permission failures abort before publishing
staged files. Failed enrollment/refresh staging is cleaned up.
This lock serializes setup only, not independent `fnox` writes or refresh.

The private file is **not encrypted at rest**: protect the account and backups,
prefer disk encryption, and remember that any process running as your user can
read the key and decrypt the cache. Do not commit the identity, sources, or cache.

## Populate and use a cache without `op`

Store a secret directly using fnox's hidden interactive prompt (no secret in argv
or history):

```nu
fnox set --global MY_SERVICE_TOKEN --provider dots-age
fnox --non-interactive check --all
fnox --non-interactive exec -- your-command
```

Alternatively pipe the value from a trusted process into the same `fnox set`
command. Do not put literal credentials in shell commands. Stored values in the
global config are encrypted for this device; future reads/injection need the
identity but do not need the original provider. `secrets setup-shell` regenerates
the native fnox hook after upgrades; open a new Nu shell afterward. Existing child
processes do not retroactively receive new environment variables.

For another machine, prefer generating a distinct identity there and sharing
only its public recipient (`age-keygen -y ~/.config/fnox/age.txt`) with the trusted
source machine. Re-encrypt secrets to that recipient before transfer over
verified SSH. Simply copying ciphertext encrypted for a different identity will
not work. Restoring an identity does not itself restore its encrypted cache.
When restoring a cache, preserve the destination `dots-age.key_file` path and
provider name and verify decryption with `fnox check`/`fnox exec` before relying
on it. Do not forward or copy a new device's private key just to refresh it.

## Optional desktop source refresh

On a Linux desktop with the 1Password CLI installed and authenticated, edit the
private `sources.toml` template and run:

```nu
secrets refresh
```

Refresh resolves sources and stages a replacement encrypted global cache; failed
source access leaves the live cache intact. Other fnox source providers can also
be configured in `sources.toml`; use a provider name other than the destination
`dots-age`. Each requested source must produce a `dots-age` encrypted result.

**`op://` references cannot resolve offline by themselves.** A device without
`op` can read an already-populated local age cache, but cannot refresh 1Password
references. A successful cached check is not proof of source authentication.

**Choose one cache-management workflow:** refresh treats `sources.toml` as the
complete set of global `dots-age` secrets and removes cached keys absent from it.
Do not run refresh against an empty template after adding keys manually with
`fnox set`; it will remove those keys. Use direct `fnox set` for a standalone
no-`op` device, or maintain the complete source map for a refresh-managed device.

## Isolated integration tests

```sh
NU_BIN=/absolute/path/to/nu \
FNOX_BIN=/absolute/path/to/fnox \
AGE_KEYGEN_BIN=/absolute/path/to/age-keygen \
python3 -m unittest discover -s tests -p test_linux_secrets.py -v
```

Tests use real tools and disposable homes/configuration, synthetic values only,
and a narrow test-only `mise which` resolver. Their PATH excludes host mise
shims and puts a failing, invocation-recording `op` sentinel before host binaries;
offline enrollment, reads, injection, and the native hook assert it is never called.
Tests cover permission failures, concurrent enrollment, and recipient mismatch.
They never enroll the host or use its credentials. Python 3.11+ is
required. If tools are absent the tests explicitly skip; a skipped run does not
verify integration. Linux tests do not exercise native Windows/macOS keychains.
