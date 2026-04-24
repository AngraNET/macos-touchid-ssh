# macOS Touch ID SSH — Claude Setup Guide

Follow these steps exactly, in order, on a fresh macOS machine. Each step must succeed before moving to the next. Steps marked **(interactive)** require the user to run the command themselves via `! <command>` because they need keyboard/biometric input.

## Prerequisites check

```bash
# Verify macOS with Touch ID
sw_vers
# Verify Xcode CLI tools (includes swiftc)
xcode-select -p
swiftc --version
# If not installed: xcode-select --install (interactive)
```

```bash
# Verify Homebrew
which brew
# If not installed: /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" (interactive)
```

## Step 1: Install GitHub CLI

```bash
brew install gh
```

## Step 2: Authenticate GitHub CLI (interactive)

User must run:
```bash
! gh auth login
```
Select: GitHub.com > HTTPS > Login with a web browser. Complete the browser flow.

## Step 3: Create SSH directory

```bash
mkdir -p ~/.ssh && chmod 700 ~/.ssh
```

## Step 4: Generate SSH key (interactive)

User must run:
```bash
! ssh-keygen -t ed25519 -C "<user-email>" -f ~/.ssh/id_ed25519
```
**The user MUST set a passphrase.** Without a passphrase, Touch ID has nothing to protect. Remind them before they run it.

## Step 5: Store passphrase in Keychain (interactive)

User must run:
```bash
! security add-generic-password -a id_ed25519 -s ssh-passphrase -U -w
```
They type their SSH passphrase when prompted. This stores it in Keychain for the askpass binary to retrieve after Touch ID.

## Step 6: Compile Touch ID askpass binary

```bash
swiftc <path-to-repo>/touchid-askpass.swift -o ~/.ssh/touchid-askpass -framework LocalAuthentication -framework Security
chmod +x ~/.ssh/touchid-askpass
```

Verify it compiled and links only to Apple system libraries:
```bash
otool -L ~/.ssh/touchid-askpass
```
Expected: only `/System/Library/Frameworks/` and `/usr/lib/` entries.

## Step 7: Write SSH config

Write `~/.ssh/config`:
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

Key config explained:
- `AddKeysToAgent no` — key is never cached in the agent; every operation triggers askpass
- No `UseKeychain` needed — we manage Keychain access directly in the askpass binary

## Step 8: Add GitHub host keys

```bash
ssh-keyscan github.com >> ~/.ssh/known_hosts 2>/dev/null
chmod 600 ~/.ssh/known_hosts
```

## Step 9: Set shell environment variables

Append to `~/.zshrc`:
```bash
# SSH Touch ID askpass
export SSH_ASKPASS="$HOME/.ssh/touchid-askpass"
export SSH_ASKPASS_REQUIRE=force
```

Then reload:
```bash
source ~/.zshrc
```

Both variables are required:
- `SSH_ASKPASS` — path to the Touch ID binary
- `SSH_ASKPASS_REQUIRE=force` — forces SSH to use askpass even when a TTY is available

## Step 10: Clear the SSH agent

```bash
ssh-add -D
```

The key must NOT be in the agent. If it is, SSH uses the cached key without calling askpass.

## Step 11: Upload public key to GitHub

```bash
gh auth refresh -h github.com -s admin:public_key
```
Then (interactive — browser flow):
```bash
! gh auth refresh -h github.com -s admin:public_key
```

After the browser flow completes:
```bash
gh ssh-key add ~/.ssh/id_ed25519.pub --title "MacBook Touch ID"
gh config set git_protocol ssh --host github.com
```

## Step 12: Test

```bash
ssh -T git@github.com
```

Expected: Touch ID prompt appears. After fingerprint, output:
```
Hi <username>! You've successfully authenticated, but GitHub does not provide shell access.
```

## Step 13: Update existing cloned repos to SSH

For any repos previously cloned via HTTPS:
```bash
git -C <repo-path> remote set-url origin git@github.com:<owner>/<repo>.git
```

## Verification checklist

- [ ] `ssh-add -l` returns "The agent has no identities"
- [ ] `ssh -T git@github.com` triggers Touch ID prompt
- [ ] Cancelling Touch ID causes the operation to fail
- [ ] `otool -L ~/.ssh/touchid-askpass` shows only Apple system libraries
- [ ] `gh config get git_protocol -h github.com` returns `ssh`

## Architecture

```
git push / ssh
    |
    v
SSH client needs passphrase (key not in agent)
    |
    v
SSH_ASKPASS → ~/.ssh/touchid-askpass (compiled Swift binary)
    |
    v
LocalAuthentication.framework → Touch ID prompt
    |
    v (on success)
Security.framework → retrieve passphrase from Keychain
    |
    v
passphrase returned to SSH → connection proceeds
```

## Files

- `touchid-askpass.swift` — source for the Touch ID askpass binary
- No third-party dependencies. Only Apple's LocalAuthentication and Security frameworks.
