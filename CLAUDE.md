# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

A zsh plugin for managing dotfiles using a Git bare repository pattern. Two scripts:

- **dotfiles**: zsh function wrapping git commands with context-aware routing based on current directory
- **bootstrap**: bash script for initial setup (clones bare repo, handles file conflicts)

## Architecture

### Bare Repository Pattern

Dotfiles stored in a bare Git repository (default: `~/.dotfiles`) with work tree set to parent directory (default: `$HOME`). This allows tracking dotfiles without interfering with other git repos.

### Configuration

- `~/.config/dotfiles/repo`: Optional custom bare repo path (supports `~` and `$HOME` expansion)
- Tracked folders are derived dynamically from `git ls-files` output (directories containing tracked files)

### Global State Variables

- `_ZD`: Associative array with keys: `git` (binary path), `repo` (bare repo path), `track` (0/1), `prompt` (status line)
- `_ZDF`: Array of tracked folder paths (auto-populated from git ls-files)
- `_ZEX`: Git command array with `--git-dir` and `--work-tree` flags when in tracked folder

### Context-Aware Behavior

`_zz_dot_is_tracked()` checks if `$PWD` matches any path in `_ZDF`. When tracked, `_ZEX` includes bare repo flags; otherwise, commands pass through to regular git.

### Custom Subcommands

- `dotfiles` (no args): Initialize/refresh tracked folders list
- `dotfiles stline`: Git status summary for prompts (branch + staged/unstaged/untracked counts)
- `dotfiles track`: Echo current tracked status (1=tracked, 0=not)
- All other commands pass through to git (with bare repo flags if tracked)
