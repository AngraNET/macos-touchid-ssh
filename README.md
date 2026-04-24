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

## Dependencies

| Dependency | How to get it |
|---|---|
| **Xcode Command Line Tools** (includes `swiftc`) | `xcode-select --install` |
| **Homebrew** | `/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"` |
| **GitHub CLI** (`gh`) | `brew install gh` |

## Files installed

| File | Purpose |
|---|---|
| `~/.ssh/id_ed25519` | SSH private key (passphrase-protected) |
| `~/.ssh/id_ed25519.pub` | SSH public key |
| `~/.ssh/touchid-askpass` | Compiled Touch ID binary |
| `~/.ssh/config` | SSH client configuration |
| `~/.ssh/known_hosts` | GitHub host keys |

Keychain also stores:
- Generic password with service `ssh-passphrase`, account `id_ed25519`

## Manual setup

### 1. Install prerequisites

```bash
# Xcode Command Line Tools (provides swiftc compiler)
xcode-select --install

# Homebrew
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# GitHub CLI
brew install gh
```

### 2. Generate SSH key

```bash
mkdir -p ~/.ssh && chmod 700 ~/.ssh
ssh-keygen -t ed25519 -C "your-email@example.com" -f ~/.ssh/id_ed25519
```

**Important:** Set a passphrase when prompted. This passphrase gets stored in Keychain — you only type it twice more (once for Keychain, once to verify the key).

### 3. Store passphrase in Keychain

```bash
security add-generic-password -a id_ed25519 -s ssh-passphrase -U -w
```

Type your SSH passphrase when prompted. This stores it in Keychain for the askpass binary to retrieve after Touch ID.

### 4. Compile Touch ID askpass

```bash
swiftc touchid-askpass.swift -o ~/.ssh/touchid-askpass -framework LocalAuthentication -framework Security
chmod +x ~/.ssh/touchid-askpass
```

### 5. Configure SSH

Create `~/.ssh/config`:

```
Host *
  AddKeysToAgent no
  IdentityFile ~/.ssh/id_ed25519

Host github.com
  HostName github.com
  User git
  IdentityFile ~/.ssh/id_ed25519
```

```bash
chmod 600 ~/.ssh/config
```

### 6. Add GitHub host keys

```bash
ssh-keyscan github.com >> ~/.ssh/known_hosts 2>/dev/null
chmod 600 ~/.ssh/known_hosts
```

### 7. Set environment variables

Add to `~/.zshrc` (or `~/.bashrc`):

```bash
# SSH Touch ID askpass
export SSH_ASKPASS="$HOME/.ssh/touchid-askpass"
export SSH_ASKPASS_REQUIRE=force
```

Then reload:

```bash
source ~/.zshrc
```

### 8. Clear the SSH agent

```bash
ssh-add -D
```

### 9. Set up GitHub

```bash
# Authenticate gh CLI
gh auth login

# Add SSH key permission scope
gh auth refresh -h github.com -s admin:public_key

# Upload public key to GitHub
gh ssh-key add ~/.ssh/id_ed25519.pub --title "MacBook Touch ID"

# Set gh to use SSH
gh config set git_protocol ssh --host github.com
```

### 10. Test

```bash
ssh -T git@github.com
```

A Touch ID prompt should appear. After authenticating, you should see:

```
Hi <username>! You've successfully authenticated, but GitHub does not provide shell access.
```

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
security add-generic-password -a id_ed25519 -s ssh-passphrase -U -w
```

## License

MIT
