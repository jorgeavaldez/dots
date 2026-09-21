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

## Optional source refresh

On a device with access to the configured source provider (1Password requires
an installed, authenticated `op` CLI), or with device-specific non-sensitive
plaintext defaults:

1. In Nu, create the template if needed and open the **device-local** file in
   Neovim. This respects `FNOX_CONFIG_DIR`; replace `nvim` with your editor if
   needed. `secrets init` does not overwrite an existing file.

   ```nu
   secrets init
   let sources = ($env.FNOX_CONFIG_DIR? | default ($nu.home-dir | path join ".config" "fnox") | path join "sources.toml")
   ^nvim $sources
   ```

2. Keep `[providers.onepassword]` if using 1Password, or configure another fnox
   source provider. Under the existing `[secrets]` section, add one entry per
   environment variable. For example:

   ```toml
   [providers.onepassword]
   type = "1password"

   [secrets]
   OPENAI_API_KEY = { provider = "onepassword", value = "op://Vault/Item/credential" }
   HOMELAB_URL = { default = "https://example.invalid" }
   ```

   `default` is plaintext in the private source file; use it only for
   non-sensitive, device-specific values such as service URLs. Replace
   `op://Vault/Item/credential` with that field's **secret reference**, not
   its actual value. You can copy the reference from the 1Password desktop app;
   see [1Password's secret reference guide](https://developer.1password.com/docs/cli/secret-references/).
   The variable name on the left is what child processes receive. Add entries to
   the existing `[secrets]` table rather than creating a duplicate table. Keep all
   intended refresh-managed keys in this file: refresh removes cached `dots-age`
   keys absent from it. Never edit the generated `config.toml` to add references.

3. Save and quit Neovim (`Esc`, then `:wq`, then Enter). Back in Nu, validate the
   TOML without displaying its contents, then refresh the encrypted cache:

   ```nu
   open $sources | ignore
   secrets refresh
   ```

   If TOML validation reports an error, fix it before running refresh. A failed
   refresh leaves the existing encrypted cache intact. The native hook picks up
   a successful refresh at the next prompt; check presence without printing the
   secret:

   ```nu
   $env.OPENAI_API_KEY? != null
   ```

Refresh syncs provider-backed entries and encrypts plaintext-default entries
into a staged global age cache; failed source access leaves the live cache intact.
Other fnox source providers can be configured in `sources.toml`; use a provider
name other than the destination `dots-age`. Each provider-backed source must
produce a `dots-age` encrypted result.

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
export NU_BIN=/absolute/path/to/nu
export FNOX_BIN=/absolute/path/to/fnox
export AGE_KEYGEN_BIN=/absolute/path/to/age-keygen
export ZOXIDE_BIN=/absolute/path/to/zoxide
export TMPDIR=/existing/scratch/directory
"$NU_BIN" --no-config-file tests/run.nu
```

Tests use real tools and disposable homes/configuration, synthetic values only,
and a narrow test-only `mise which` resolver. Their PATH excludes host mise
shims and puts a failing, invocation-recording `op` sentinel before host binaries;
offline enrollment, reads, injection, and the native hook assert it is never called.
Tests cover permission failures, concurrent enrollment, and recipient mismatch.
They never enroll the host or use its credentials. Nu and its bundled
`std/assert` run the suite; Python is not required. Missing tools fail explicitly.
See [the Nu test guide](test-nushell.md) for required tools and isolation details.
Linux tests do not exercise native Windows/macOS keychains.
