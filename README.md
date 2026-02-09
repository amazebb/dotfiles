# Dotfiles
ZSH dotfiles management 

## Install

Clone the repo, for instance into `~/.local/share/zsh/site-functions`, and then add an autoload to
`~/.zshenv` file. After this your `dotfiles` command can be aliased to something
more convenient in your `~/.zshrc` file. 

Example `~/.zshenv` file:

```zsh
fpath+=(~/.local/share/zsh/site-functions/dotfiles)
autoload -Uk +X dotfiles
```

## Overview

### Why
- why anything
- learn ZSH
- learn Git plumbing
- make dotfiles and zsh prompts work with sha1 and sha256
- use AI to help flesh out syntax, and help write commit messages
- take ownership of your dotfiles
- clean house

This repo contains two files that can be run under zsh, there is no attempt at
POSIX or full bash compatibility as the author did not need those features.
This was all developed on macOS, so no guarantees for other OS'.

- **dotfiles**: A zsh function that wraps git commands for the bare repo, it
  falls back to regular `git` command when in a regular repo and supports both
  `sha1` and `sha256`.
- **bootstrap**: A bash script for initial setup that clones the bare repo and
  handles file conflicts

## Architecture

The following is not needed to use `dotfiles` or `bootstrap`, but outlines how
things work at a high level.

### Bare Repository Pattern

The dotfiles are stored in a bare Git repository (default: `$HOME/.dotfiles`) with
the work tree set to the parent folder (default: `$HOME`). 
This allows tracking dotfiles without interfering with other git repos in the
home directory, and is one of the main reasons for the dotfiles/bare repo approach.

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
  state and used by `zsh-prompt` function, (branch name with
  staged/unstaged/untracked counts). An additional option, `--print-status`
  prints to stdout the current branch name, 1 if dotfiles repo, and path to
  .git/.dotfiles folder. This is used by our statusline.lua to easier get git
  status information.
