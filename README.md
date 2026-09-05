# macos-bootstrap

My personal setup for a fresh Mac.

Every time I get a new machine — or nuke an old one — I don't want to spend
a day clicking through download pages, hunting for my dotfiles and
remembering which twelve CLI tools I actually depend on. This repo is the
answer to that: clone it, run one script, walk away, come back to a machine
that looks and behaves exactly like the one I left.

It is **idempotent** — running it twice is safe, and running it on an
already-configured machine is how I pick up changes I've committed since.

## What it sets up

- **Homebrew** — GUI apps (casks) and system-level tooling
- **mise** — pinned CLI tools and language runtimes (node, ruby, …)
- **oh-my-zsh + powerlevel10k** — shell, prompt, autosuggestions and
  syntax highlighting, cloned into `$ZSH_CUSTOM` and updated by `omz update`
- **Xcode** — installed and switched via `xcodes`, plus simulator runtimes
- **Dotfiles** — symlinked out of `dotfiles/` so edits land back in the repo
- **SSH** — key generation, keychain, GitHub upload, SSH commit signing
- **macOS defaults** — the `defaults write` settings I change on day one
- **Mac App Store** — via `mas`, for the handful of apps that only live there

## Usage

```sh
xcode-select --install          # then wait for it to finish

git clone https://github.com/<user>/macos-bootstrap.git ~/dev/macos-bootstrap
cd ~/dev/macos-bootstrap
chmod +x bootstrap.sh install/*.sh scripts/*.sh
./bootstrap.sh
```

Run a single step, or a few:

```sh
./bootstrap.sh 40-mise 50-xcode
./bootstrap.sh --list           # show all steps
./bootstrap.sh --dry-run        # show what would run, change nothing
```

## Steps

| #  | Script                  | What it does                                        |
|----|-------------------------|-----------------------------------------------------|
| 00 | `00-preflight.sh`       | Xcode Command Line Tools, Rosetta 2                 |
| 10 | `10-homebrew.sh`        | Install Homebrew, wire up `shellenv`                |
| 20 | `20-brew-bundle.sh`     | Everything in the `Brewfile`                        |
| 30 | `30-dotfiles.sh`        | oh-my-zsh + custom theme/plugins, symlink `dotfiles/`|
| 40 | `40-mise.sh`            | CLI tools and language runtimes via mise            |
| 50 | `50-xcode.sh`           | Xcode versions + simulator runtimes via `xcodes`    |
| 60 | `60-ssh.sh`             | SSH key, agent, GitHub upload, commit signing       |
| 70 | `70-macos-defaults.sh`  | `defaults write` system preferences                 |
| 80 | `80-mas.sh`             | Mac App Store apps from `Masfile`                   |

Steps run in filename order. Each runs in its own subshell, so one step
cannot leak exports into the next.

## Layout

```
macos-bootstrap/
├── bootstrap.sh                 # single entry point
├── Brewfile                     # GUI apps + system tooling
├── Masfile                      # Mac App Store apps
├── lib/common.sh                # logging, symlinking, shared helpers
├── install/                     # numbered, idempotent steps
├── config/
│   ├── xcode-versions.txt       # which Xcodes to install
│   └── simulator-runtimes.txt   # which simulator runtimes to install
├── dotfiles/                    # mirrors $HOME, one dir per package
│   ├── zsh/.zshrc
│   ├── zsh/.p10k.zsh
│   ├── git/.gitconfig
│   ├── git/.config/git/ignore
│   ├── mise/.config/mise/config.toml
│   ├── ghostty/.config/ghostty/config
│   ├── tmux/.tmux.conf
│   └── nvim/.config/nvim/init.lua
└── scripts/sync-back.sh         # dump current machine state into the repo
```

## How dotfiles work

`dotfiles/<package>/` mirrors the structure of `$HOME`. The linker walks
each package and symlinks **individual files**, so:

```
dotfiles/mise/.config/mise/config.toml  →  ~/.config/mise/config.toml
```

Files are symlinked rather than copied, which means editing `~/.zshrc` on
any machine edits the repo directly — `git diff` shows me what drifted.
Anything already at the destination is moved aside to a timestamped
`.backup.<ts>` file first, never overwritten.

To add a new dotfile: drop it in the right package directory and re-run
`./bootstrap.sh 30-dotfiles`.

## Where to add things

| I want to add…       | Edit                                             |
|----------------------|--------------------------------------------------|
| A GUI app            | `Brewfile`                                       |
| A CLI tool           | `dotfiles/mise/.config/mise/config.toml`         |
| An Xcode version     | `config/xcode-versions.txt`                      |
| A simulator runtime  | `config/simulator-runtimes.txt`                  |
| A dotfile            | `dotfiles/<package>/<path relative to $HOME>`    |
| A macOS setting      | `install/70-macos-defaults.sh`                   |

### Why the brew/mise split

Homebrew handles GUI applications and things that need to integrate with
the system (fonts, `mas`, `xcodes`, image libraries). mise handles CLI
tools and language runtimes, because it pins exact versions and honours
per-project `.config/mise/config.toml` overrides — which matters a lot on
iOS projects where every repo wants its own `tuist`/`swiftlint`/
`swiftformat`. Deliberately, **no iOS tooling is pinned globally**; each
project brings its own.

## Keeping it current

Dotfiles are symlinks, so they're always in sync. For package state:

```sh
./scripts/sync-back.sh
git diff                        # review, then merge into Brewfile by hand
```

Day-to-day updates:

```sh
up                              # alias: brew + mise + omz, all at once
```

## Manual steps afterwards

The script deliberately stops short of anything that needs a password
typed into a GUI:

1. Restart the terminal (`exec zsh`)
2. `p10k configure` — only to change the prompt; `.p10k.zsh` is committed
3. `gh auth login`
4. Sign in to Fork, VS Code, Bitwarden, Spotify, Notion, Obsidian
5. Restore Logi Options+ profiles
6. Sign in to the App Store, then `./bootstrap.sh 80-mas`
7. Delete any stale `~/Library/Application Support/com.mitchellh.ghostty/config`
   so the repo's `~/.config/ghostty/config` is unambiguously the one in use

## What never goes in this repo

`~/.gitconfig.local` (name and email), `~/.ssh/`, `~/.zshrc.local`, API
tokens, `.env` files. `.gitignore` blocks the obvious shapes, but the real
rule is: if it's a secret, it lives in Bitwarden, not here.
