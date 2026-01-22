# Dotfiles
This outlines the dotfiles management functionality

## Overview

This is a zsh plugin for managing dotfiles using a Git bare repository pattern. It provides two scripts:

- **dotfiles**: A zsh function that wraps git commands for the bare repo, with context-aware behavior based on current directory
- **bootstrap**: A bash script for initial setup that clones the bare repo and handles file conflicts

## Architecture

### Bare Repository Pattern

The dotfiles are stored in a bare Git repository (default: `~/.dotfiles`) with the work tree set to the parent folder of (default: `$HOME`). 
This allows tracking dotfiles without interfering with other git repos in the home directory.

### Configuration Files

- `~/.config/dotfiles/repo`: Optional file containing custom bare repo path (supports `~` and `$HOME` expansion)
- `~/.config/dotfiles/config`: Required file listing tracked folders (one per line, supports `~` and `$HOME`)

### Global State Variables

The `dotfiles` script uses three global zsh variables:
- `_ZD`: Associative array holding git path, repo path, track status, and prompt info
- `_ZDF`: Array of tracked folder paths from config file
- `_ZEX`: Array containing git command with appropriate `--git-dir` and `--work-tree` flags

### Context-Aware Behavior

When in a tracked folder (defined in config), commands route through the bare repo. Otherwise, commands pass through to regular git. The `_zz_dot_is_tracked()` function determines this based on `$PWD`.

### Custom Subcommands

- `dotfiles stline [--echo]`: Returns git status summary for shell prompts (branch name with staged/unstaged/untracked counts)
- `dotfiles track`: Returns 1 if current folder is tracked, 0 otherwise
- `dotfiles status`: Shows standard status plus untracked files in tracked folders
- `dotfiles clean`: Runs git clean scoped to tracked folders only
