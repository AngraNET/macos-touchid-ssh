# macOS Touch ID SSH

Use Touch ID (fingerprint) to confirm every SSH operation on macOS. No third-party dependencies — only Apple's built-in `LocalAuthentication` framework.

When you `git push`, `git fetch`, or `ssh` into a server, macOS will show a Touch ID prompt. If you cancel or fail authentication, the operation is denied.

## How it works

1. An SSH key is generated with a passphrase
2. The passphrase is stored in Apple Keychain (you never type it again)
3. The SSH agent is configured to require confirmation (`-c` flag) on every key use
4. A small native Swift binary (`touchid-askpass`) acts as `SSH_ASKPASS` — it calls Apple's `LocalAuthentication` framework to trigger Touch ID
5. The SSH agent calls this binary before signing; Touch ID success = approved, failure/cancel = denied

## Dependencies

| Dependency | How to get it |
|---|---|
| **Homebrew** | `/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"` |
| **Xcode Command Line Tools** (includes `swiftc`) | `xcode-select --install` |
| **GitHub CLI** (`gh`) | `brew install gh` |

## Files installed

| File | Purpose |
|---|---|
| `~/.ssh/id_ed25519` | SSH private key (passphrase-protected) |
| `~/.ssh/id_ed25519.pub` | SSH public key |
| `~/.ssh/touchid-askpass` | Compiled Touch ID binary |
| `~/.ssh/config` | SSH client configuration |
| `~/.ssh/known_hosts` | GitHub host keys |

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

**Important:** Set a passphrase when prompted. This passphrase gets stored in Keychain — you only type it once.

### 3. Compile Touch ID askpass

```bash
swiftc touchid-askpass.swift -o ~/.ssh/touchid-askpass -framework LocalAuthentication
chmod +x ~/.ssh/touchid-askpass
```

### 4. Configure SSH

Create `~/.ssh/config`:

```
Host *
  AddKeysToAgent confirm
  UseKeychain yes
  IdentityFile ~/.ssh/id_ed25519

Host github.com
  HostName github.com
  User git
  IdentityFile ~/.ssh/id_ed25519
```

```bash
chmod 600 ~/.ssh/config
```

### 5. Add GitHub host keys

```bash
ssh-keyscan github.com >> ~/.ssh/known_hosts 2>/dev/null
chmod 600 ~/.ssh/known_hosts
```

### 6. Set environment variables

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

### 7. Add key to agent with confirmation requirement

```bash
ssh-add -c --apple-use-keychain ~/.ssh/id_ed25519
```

Type your passphrase when prompted. Keychain stores it — this is the last time you type it.

### 8. Set up GitHub

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

### 9. Test

```bash
ssh -T git@github.com
```

A Touch ID prompt should appear. After authenticating, you should see:

```
Hi <username>! You've successfully authenticated, but GitHub does not provide shell access.
```

## After reboot

After a reboot, the key is no longer in the agent. Re-add it:

```bash
ssh-add -c --apple-use-keychain ~/.ssh/id_ed25519
```

To automate this, you can add the above command to your `~/.zshrc`.

## Troubleshooting

### "agent refused operation"
The `SSH_ASKPASS` and `SSH_ASKPASS_REQUIRE` environment variables are not set. Make sure they're in your `~/.zshrc` and the shell is reloaded.

### No Touch ID prompt appears
The key was added without `-c`. Remove and re-add:
```bash
ssh-add -D
ssh-add -c --apple-use-keychain ~/.ssh/id_ed25519
```

### "Touch ID not available"
Your Mac doesn't have Touch ID hardware, or it's disabled in System Settings.

## License

MIT
