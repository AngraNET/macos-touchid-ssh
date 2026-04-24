# macOS Touch ID SSH

Use Touch ID (fingerprint) to authorize every SSH operation on macOS. No third-party dependencies — only Apple's built-in `LocalAuthentication` and `Security` frameworks.

When you `git push`, `git fetch`, or `ssh` into a server, macOS shows a Touch ID prompt. If you cancel or fail authentication, the operation is denied.

## How it works

1. An SSH key is generated with a passphrase
2. The passphrase is stored in Apple Keychain (you never type it again)
3. The SSH agent is disabled (`AddKeysToAgent no`) so the key is never cached
4. A native Swift binary (`touchid-askpass`) acts as `SSH_ASKPASS` — on every SSH operation it:
   - Prompts Touch ID via Apple's `LocalAuthentication` framework
   - On success, retrieves the passphrase from Keychain via Apple's `Security` framework
   - Returns the passphrase to SSH
5. If Touch ID fails or is cancelled, the passphrase is never returned and SSH is denied

## Prerequisites

| Dependency | How to get it |
|---|---|
| **Xcode Command Line Tools** (includes `swiftc`) | `xcode-select --install` |
| **Homebrew** | `/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"` |
| **GitHub CLI** (`gh`) | `brew install gh` |

## Setup

Clone this repo and point Claude at it:

```
claude
> follow CLAUDE.md to set up Touch ID SSH on this machine
```

Claude will walk you through each step, generate a key with a name it picks, compile the binary, configure SSH, and wire up GitHub — prompting you only when your input is needed (passphrase, browser auth, etc.).

## Troubleshooting

### "agent refused operation"
Clear the agent and make sure the key is not cached:
```bash
ssh-add -D
```

### No Touch ID prompt, asks for passphrase in terminal
The `SSH_ASKPASS` and `SSH_ASKPASS_REQUIRE` environment variables are not set. Make sure they're in your `~/.zshrc` and the shell is reloaded.

### "Touch ID not available"
Your Mac doesn't have Touch ID hardware, or it's disabled in System Settings.

### "Could not retrieve passphrase from Keychain"
The passphrase wasn't stored in Keychain. Run:
```bash
security add-generic-password -a <key-name> -s ssh-passphrase -U -w
```

## License

MIT
