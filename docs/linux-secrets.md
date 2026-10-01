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
`secrets init` creates a private `sources.toml` template without enrolling or
fetching credentials. Once enrolled, setup/init add a `source-age` provider using
the device's existing identity, without replacing entries, comments, or existing
providers. Repeating setup upgrades an older source map this way. Bootstrap
installs the native shell hook but does not create an identity. No tool-path
lookups happen merely by importing the module.

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

## Local encrypted sources without `op`

`sources.toml` is the private source of truth; `config.toml` is its derived shell
cache. `source-age` encrypts local inputs in the source map; `dots-age` encrypts
the cache. Both use the same enrolled device identity. No server, `op`, or
password-manager session is needed for this flow.

Store a key using fnox's hidden interactive prompt, then refresh:

```nu
secrets local MY_SERVICE_TOKEN
secrets refresh
fnox --non-interactive check --all
fnox --non-interactive exec -- your-command
```

`secrets local KEY` accepts only the variable name as an argument. Paste the key
at the hidden prompt, not on the shell command line. To use the 1Password Android
app, copy the selected field, return to Termux and paste into that prompt. Clear
the clipboard and keyboard clipboard history afterward. This is manual transfer,
not an automatic connection to the app.

Alternatively pipe a string from a trusted process. For a selected key already
inherited from the old `secrets.sh`:

```nu
$env.MY_SERVICE_TOKEN | secrets local MY_SERVICE_TOKEN
secrets refresh
```

This encrypts the value in `sources.toml`, never directly in the cache, and does
not print the secret or put it in argv. Do not put literal credentials in shell
commands. Repeat local + refresh to rotate a key. Remove its `[secrets]` entry
and refresh to remove it from the cache. Other entries, including non-sensitive
plaintext defaults, remain in the same source map. `DOTS_AGE_IDENTITY` is reserved
and cannot be added with `secrets local`.

A future desktop bridge can resolve selected 1Password references on a desktop,
encrypt them to the phone's public recipient, and transfer ciphertext to update
the phone's encrypted source entries. Only the public recipient leaves the phone;
no private identity or plaintext transfer is needed. That bridge is not automated
by these commands.

Stored values in both files are encrypted for this device; shell injection needs
the identity and derived cache, not the original password manager.
`secrets setup-shell` regenerates the native fnox hook after upgrades; open a new Nu shell afterward. Existing child
processes do not retroactively receive new environment variables.

For another machine, prefer generating a distinct identity there and sharing
only its public recipient (`age-keygen -y ~/.config/fnox/age.txt`) with the trusted
source machine. Re-encrypt secrets to that recipient before transfer over
verified SSH. Simply copying ciphertext encrypted for a different identity will
not work. Restoring an identity does not itself restore its encrypted cache.
When restoring a cache, preserve the destination `dots-age.key_file` path and
provider name and verify decryption with `fnox check`/`fnox exec` before relying
on it. Do not forward or copy a new device's private key just to refresh it.

## Optional remote references and plaintext defaults

The same source map can mix local encrypted inputs with remote references and
non-sensitive plaintext defaults. Remote 1Password entries require an installed,
authenticated `op` CLI during refresh; simply having a `[providers.onepassword]`
stanza with no secrets using it does not require `op`.

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

Refresh resolves encrypted local and remote-provider entries, and encrypts
plaintext defaults into a staged global age cache. Failed source access leaves
the live cache intact.
Other fnox source providers can be configured in `sources.toml`; use a provider
name other than the destination `dots-age`. Each provider-backed source must
produce a `dots-age` encrypted result.

**`op://` references cannot resolve offline by themselves.** A device without
`op` can read an already-populated local age cache, but cannot refresh 1Password
references. A successful cached check is not proof of source authentication.

**Keep sources authoritative:** refresh treats `sources.toml` as the complete set
of global `dots-age` secrets and removes cached keys absent from it. Use
`secrets local`, not `fnox set --global`, for local inputs that must survive
refresh. If keys were added directly to the cache, migrate them into the source
map before refreshing; an empty source map would remove them.

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
