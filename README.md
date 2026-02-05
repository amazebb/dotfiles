# Dotfiles
This outlines the dotfiles management functionality

## Overview

This is a zsh plugin for managing dotfiles using a Git bare repository pattern. It provides two scripts:

- **dotfiles**: A zsh function that wraps git commands for the bare repo, with context-aware behavior based on current directory. It falls back to regular `git` command when in a regualr repo and supports both 
`sha1` and `sha256` repos.
- **bootstrap**: A bash script for initial setup that clones the bare repo and handles file conflicts

## Architecture

### Bare Repository Pattern

The dotfiles are stored in a bare Git repository (default: `~/.dotfiles`) with the work tree set to the parent folder of (default: `$HOME`). 
This allows tracking dotfiles without interfering with other git repos in the home directory.

### Configuration Files

- `~/.config/dotfiles/repo`: Optional file containing custom bare repo path (supports `~` and `$HOME` expansion)
- `~/.config/.gitignore`: Tracked files and folders are defined in the `.gitignore` file

> [!IMPORTANT] 
> Tracked folders are a bit of a :chicken: and :egg: problem.
> Since git does not have a direct way of telling you what folders are being tracked 
> after you have setup your `.gitignore` file, we use `ls-files` to determine the tracked folders.
> This means that even though you have defined folders for tracking in `.gitignore`, 
> **you need to put something in the folder** then the folder will be tracked. 
> Previously we had been tracking the folders using a separate config file, so its either maintain 
> two files, or just the `.gitignore` knowing the above caveat.

### Global State Variables

The `dotfiles` script uses three global zsh variables:
- `_ZD`: Associative array holding git path, repo path, track status, and prompt info
- `_ZDF`: Array of tracked folder paths derived using `ls-files`
- `_ZEX`: Array containing git command with appropriate `--git-dir` and `--work-tree` flags

### Context-Aware Behavior

When in a tracked folder, commands route through the bare repo. Otherwise, commands pass through to regular git. The `_zz_dot_is_tracked()` function determines this based on `$PWD`.

### Custom Subcommands

- `dotfiles stline`: Returns git status summary for shell prompts (branch name with staged/unstaged/untracked counts)
- `dotfiles track`: Returns 1 if current folder is tracked, 0 otherwise
- `dotfiles getrepo`: Returns the absolute path to the repo, dotfiles or regular git
