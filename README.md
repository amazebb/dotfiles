# Dotfiles
ZSH dotfiles management 

## Install

Clone the repo, you can change INSTALL_DIR and the REPO_DOTFILE as needed.
```sh
INSTALL_DIR="~/.local/share/zsh/site-functions/"
mkdir -p "$INSTALL_DIR"
git clone https://github.com/broeknbytes/dotfiles.git "$INSTALL_DIR"
cd "$INSTALL_DIR"
```

Run the `bootstrap` function in `--dry-run` mode to ensure we correctly backup current files and
restore your personal dotfiles.

```sh
REPO_DOTFILE="https://github.com/broeknbytes/dotfiles-repo.git"
./bootstrap -r $REPO_DOTFILE
```

To proceed run:
```sh
./bootstrap -f -r $REPO_DOTFILE
```

Add `dotfiles` function to `~/.zshenv`. 

```sh
cat << 'EOF' >> ~/.zshenv

# Custom dotfiles function
fpath+=( "$INSTALL_DIR/dotfiles" )
autoload -Uz dotfiles
EOF
```

After this your `dotfiles` command can be
aliased to something more convenient in `~/.zshrc`. 

## Overview

This repo contains two files that can be run under zsh, there is no attempt at
POSIX or full bash compatibility as of yet. This was all developed on macOS, so
no guarantees elsewhere, including macOS.

- **dotfiles**: A zsh function that wraps git commands for the bare repo, it
  falls back to regular `git` command when in a regular repo and supports both
  `sha1` and `sha256`.
- **bootstrap**: A bash script for initial setup that clones the bare repo and
  handles file conflicts

## Architecture

The following is not needed to use `dotfiles` or `bootstrap`, but outlines how
things work at a high level.

### Bare Repository Pattern

The dotfiles are stored in a bare Git repository (default: `$HOME/.dotfiles`)
with the work tree set to the parent folder (default: `$HOME`). This allows
tracking dotfiles without interfering with other git repos in the home
directory, and is one of the main reasons for the dotfiles/bare repo approach.

### Configuration Files

- `~/.gitignore`: Tracked files and folders are defined here, these let us know
  if we are in a dotfiles repo.

> [!IMPORTANT] 
> Tracked folders are a bit of a :chicken: and :egg: problem. Since git does
> not have a direct way of telling you what folders are being tracked after you
> have setup your `.gitignore` file, we use `ls-files` to determine the tracked
> folders. This means **you need to have something in the folder** for it to
> be tracked. Another method would be to track folders using a separate
> file, so its either maintain two files, or just the `.gitignore` knowing the
> above caveat.

### Global State Variables

The `dotfiles` script uses three global zsh variables:
- `_ZD`: Associative array holding repo path, track status, and prompt info
- `_ZDF`: Array of tracked folder paths derived using `ls-files`
- `_ZEX`: Array containing git command with appropriate `--git-dir` and `--work-tree` flags

### Context-Aware Behavior

When in a tracked folder, commands route through the bare repo. Otherwise,
commands pass through to regular git. The `_zz_dot_is_tracked()` function
determines this based on `$PWD` and comparing with `_$ZDF`

### Custom Subcommands

- `dotfiles --zsh-prompt [-print]`: `--zsh-prompt` on its own is used to update
  state and used by [zsh-prompt](https://github.com/broeknbytes/zsh-prompt), to
  display current branch name with staged/unstaged/untracked counts. An
  additional option, `--print-status` prints to stdout

```
  current branch name
  1 if dotfiles repo, 0 otherwise
  path to .git/.dotfiles folder
```

## Why ?
- Learn some ZSH
- Learn Git plumbing
- Make dotfiles and zsh prompts work with `sha1` and `sha256`
- Take ownership of your dotfiles
- Use AI to help flesh out syntax, and help write commit messages
- Clean house
- Does any of this matter ? probably not...
- Then why , go to step 1...

