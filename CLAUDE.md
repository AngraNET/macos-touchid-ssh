# macOS Touch ID SSH — Setup Guide

Follow these steps in order on a fresh macOS machine. Each step must succeed before moving to the next.

Steps marked **(interactive)** require the user to run the command themselves via `! <command>` because they need keyboard/biometric input.

## Before you start

Pick a key name based on the machine. Use the hostname or a short descriptor (e.g., `macbook-pro-2024`, `daniels-mac`). Use this name consistently for the key filename, Keychain account, and GitHub title throughout the guide.

Example: if the key name is `macbook-pro`, the key file is `~/.ssh/macbook-pro`, the Keychain account is `macbook-pro`, and the GitHub title is `macbook-pro`.

## Step 1: Check prerequisites

```bash
sw_vers                # macOS version
xcode-select -p        # Xcode CLI tools
swiftc --version       # Swift compiler
which brew             # Homebrew
```

If Xcode CLI tools are missing: `xcode-select --install` **(interactive)**
If Homebrew is missing: `/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"` **(interactive)**

## Step 2: Install GitHub CLI

```bash
brew install gh
```

## Step 3: Authenticate GitHub CLI (interactive)

User must run:
```bash
! gh auth login
```
Select: GitHub.com > HTTPS > Login with a web browser. Complete the browser flow.

## Step 4: Create SSH directory

```bash
mkdir -p ~/.ssh && chmod 700 ~/.ssh
```

## Step 5: Generate SSH key (interactive)

Tell the user to set a passphrase. Without a passphrase, Touch ID has nothing to protect.

User must run:
```bash
! ssh-keygen -t ed25519 -C "<user-email>" -f ~/.ssh/<key-name>
```

## Step 6: Store passphrase in Keychain (interactive)

User must run:
```bash
! security add-generic-password -a <key-name> -s ssh-passphrase -U -w
```
They type their SSH passphrase when prompted. This stores it in Keychain for the askpass binary to retrieve after Touch ID.

## Step 7: Compile Touch ID askpass binary

The `touchid-askpass.swift` source is in this repo. Update the Keychain account name in the source to match `<key-name>` before compiling:

- In `touchid-askpass.swift`, change `kSecAttrAccount` value from `"id_ed25519"` to `"<key-name>"`

Then compile:
```bash
swiftc <path-to-repo>/touchid-askpass.swift -o ~/.ssh/touchid-askpass -framework LocalAuthentication -framework Security
chmod +x ~/.ssh/touchid-askpass
```

Verify it links only to Apple system libraries:
```bash
otool -L ~/.ssh/touchid-askpass
```
Expected: only `/System/Library/Frameworks/` and `/usr/lib/` entries.

## Step 8: Write SSH config

Write `~/.ssh/config`:
```
Host *
  AddKeysToAgent no
  IdentityFile ~/.ssh/<key-name>

Host github.com
  HostName github.com
  User git
  IdentityFile ~/.ssh/<key-name>
```

```bash
chmod 600 ~/.ssh/config
```

- `AddKeysToAgent no` — key is never cached in the agent; every operation triggers askpass

## Step 9: Add GitHub host keys

```bash
ssh-keyscan github.com >> ~/.ssh/known_hosts 2>/dev/null
chmod 600 ~/.ssh/known_hosts
```

## Step 10: Set shell environment variables

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

## Step 11: Clear the SSH agent

```bash
ssh-add -D
```

The key must NOT be in the agent. If it is, SSH uses the cached key without calling askpass.

## Step 12: Upload public key to GitHub

Grant the SSH key permission scope **(interactive — browser flow)**:
```bash
! gh auth refresh -h github.com -s admin:public_key
```

After the browser flow completes:
```bash
gh ssh-key add ~/.ssh/<key-name>.pub --title "<key-name>"
gh config set git_protocol ssh --host github.com
```

## Step 13: Test

```bash
ssh -T git@github.com
```

Expected: Touch ID prompt appears. After fingerprint, output:
```
Hi <username>! You've successfully authenticated, but GitHub does not provide shell access.
```

## Step 14: Update existing cloned repos to SSH

For any repos previously cloned via HTTPS, switch remotes:
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
SSH_ASKPASS → ~/.ssh/touchid-askpass
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
