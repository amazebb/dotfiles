# Dotfiles
Zsh dotfiles management 

## Install

### 1. Clone repo

Create `INSTALL_DIR` folder 

```sh
INSTALL_DIR="$HOME/.local/share/zsh/site-functions/dotfiles"
mkdir -p "$(dirname "$INSTALL_DIR")"
```

Clone `broeknbytes/dotfiles.git`

```
git clone https://github.com/broeknbytes/dotfiles.git "$INSTALL_DIR"
```

### 2. Bootstrap your dotfiles

Set `REPO_DOTFILE` to your personal dotfiles repo if you have one, otherwise
go to Step 3.

```sh
REPO_DOTFILE="https://github.com/broeknbytes/dotfiles-repo.git"
```

Run `bootstrap` to preview what will change (dry-run is the default).

```sh
"$INSTALL_DIR/bootstrap" -r "$REPO_DOTFILE"
```

If everything looks good, run with `-f` to apply.

```sh
"$INSTALL_DIR/bootstrap" -f -r "$REPO_DOTFILE"
```

You're dotfiles repository should now be setup on your local machine.

### 3. Setup autload of dotfiles function

If the dotfiles function is not already autloaded, then we need to add it to
`~/.zshenv`

```sh
cat << EOF >> ~/.zshenv

# Custom dotfiles function
fpath+=( "$INSTALL_DIR" )
autoload -Uz dotfiles
EOF
```

After this your `dotfiles` command can be aliased to something more convenient
in `~/.zshrc`.

## Overview

This repo contains two files that can be run under Zsh, all developed on
macOS, so no guarantees elsewhere, including macOS.

- **dotfiles**: A Zsh function that wraps git commands for the bare repo, it
  falls back to regular `git` command when in a regular repo and supports both
  `sha1` and `sha256`.
- **bootstrap**: A bash script for initial setup that clones the bare repo and
  handles file conflicts

## Architecture

The following outlines how things work at a high level.

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
> be tracked.

### Global State Variables

The `dotfiles` script uses three global Zsh variables:
- `_ZD`: Associative array holding repo path, track status, and prompt info
- `_ZDF`: Array of tracked folder paths derived using `ls-files`
- `_ZEX`: Array containing git command with appropriate `--git-dir` and `--work-tree` flags
- `_ZDL`: Last path visited

### Context-Aware Behavior

When in a tracked folder, commands route through the bare repo. Otherwise,
commands pass through to regular git. The `_zz_dot_is_tracked()` function
determines this based on `$PWD` and comparing with `_$ZDF`

### Custom Subcommands

- `dotfiles [--zsh-prompt] [--print-status]`

`--zsh-prompt` - updates state used by Zsh `precmd` hook in
[zsh-prompt](https://github.com/broeknbytes/zsh-prompt), to
  display current branch name with staged/unstaged/untracked counts. 

`--print-status` - prints to stdout the following three lines:

  - current branch name followed by number of changes
  - 1 if dotfiles repo, 0 standard git repo
  - path to .git/.dotfiles folder

## Why ?
- Learn some Zsh
- Learn Git plumbing
- Make dotfiles and Zsh prompts work with `sha1` and `sha256`
- Take ownership of your dotfiles
- Use AI to help flesh out syntax, and help write commit messages
- Clean house
- Does any of this matter? probably not...
- Then why? go to step 1...

