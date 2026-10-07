# Dotfiles
Zsh dotfiles management 

## Table of Contents

- [Install](#install)
  - [Clone repo](#clone-repo)
  - [Bootstrap your dotfiles](#bootstrap-your-dotfiles)
  - [Setup autoload of dotfiles function](#setup-autoload-of-dotfiles-function)
- [Overview](#overview)
- [Architecture](#architecture)
  - [Bare Repository Pattern](#bare-repository-pattern)
  - [Configuration Files](#configuration-files)
  - [Global State Variables](#global-state-variables)
  - [Context-Aware Behavior](#context-aware-behavior)
  - [Custom Subcommands](#custom-subcommands)
- [Tests](#tests)
- [CI](#ci)
- [Why ?](#why-)

## Install

### Clone repo

Create `INSTALL_DIR` folder and clone repo

```sh
INSTALL_DIR="$HOME/.local/share/zsh/site-functions/dotfiles"
mkdir -p "$(dirname "$INSTALL_DIR")"
git clone https://github.com/amazebb/dotfiles.git "$INSTALL_DIR"
```

`bootstrap` moves files around your `$HOME`, so read it before you run it. The
clone follows `main`; to install a known version, check out a commit or tag:

```sh
git -C "$INSTALL_DIR" checkout <commit-or-tag>
```

### Bootstrap your dotfiles

This is where we install our personal dotfiles using `bootstrap`.
We live dangerously by using a bare git repo under our `$HOME` folder: `$HOME/.dotfiles`

Set `REPO_DOTFILE` to your personal dotfiles repo if you have one, otherwise
go to [Setup autoload of dotfiles function](#setup-autoload-of-dotfiles-function)

```sh
REPO_DOTFILE="https://github.com/amazebb/dotfiles-repo.git"
```

Give exactly one repo: an `https://` or `ssh` URL (`git@host:user/repo.git`
works) or a local path. `http://` and `git://` are refused. The files in your
repo run as you (`.zshrc` and friends), so only use a repo you trust.

Run `bootstrap` to preview what will change (dry-run, `-n` is the default).

```sh
"$INSTALL_DIR/bootstrap" "$REPO_DOTFILE"
```

Add `-v` to review the diffs of files that already exist in `$HOME`, and the
contents of the new ones, before you answer the prompts.

```sh
"$INSTALL_DIR/bootstrap" -v "$REPO_DOTFILE"
```

If everything looks good, run with `-f` to apply.

```sh
"$INSTALL_DIR/bootstrap" -f "$REPO_DOTFILE"
```

With `-f`, `bootstrap` asks before it changes anything. Files that already
exist are moved to `$HOME/.dotfiles-backup-<timestamp>.<random>` (readable only
by you) so the checkout can succeed, and are moved back if the backup or the
move of the repo fails. It refuses a repo that has absolute paths, `..`, `.` or
`.git` components, or whose folders in `$HOME` are symlinks or plain files.
`-d dir` puts the bare repo somewhere other than `$HOME/.dotfiles`.

Your dotfiles repository should now be setup on your local machine.

### Setup autoload of dotfiles function

If the dotfiles function is not already autoloaded, then we need to add it to
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

This repo contains two files, developed and tested on macOS only, so no
guarantees elsewhere:

- **dotfiles**: A Zsh function that wraps git commands for the bare repo, it
  falls back to regular `git` command when in a regular repo and supports both
  `sha1` and `sha256`.
- **bootstrap**: A bash script (runs on bash 3.2 and 5) for initial setup that
  clones the bare repo and handles file conflicts

## Architecture

The following outlines how things work at a high level.

### Bare Repository Pattern

The dotfiles are stored in a bare Git repository (default: `$HOME/.dotfiles`)
with the work tree set to the parent folder (default: `$HOME`). This allows
tracking dotfiles without interfering with other git repos in the home
directory, and is one of the main reasons for the dotfiles/bare repo approach.

### Configuration Files

- `~/.gitignore`: optional, and read by git, not by `dotfiles`. A common setup
  ignores everything (`*`) and un-ignores what you track (`!.zshrc`,
  `!.config/nvim/**`), so `dotfiles add` only accepts those paths. `dotfiles`
  itself finds the tracked folders from `ls-files`.

> Tracked folders are a bit of a :chicken: and :egg: problem. Since git does
> not have a direct way of telling you what folders are being tracked after you
> have setup your `.gitignore` file, `dotfiles` uses `ls-files` to determine the tracked
> folders. This means **you need to have something in the folder** for it to
> be shown as tracked.

### Global State Variables

The `dotfiles` script uses four global Zsh variables:
- `_ZD`: Associative array holding repo path, track status, and prompt info
- `_ZDF`: Array of tracked folder paths derived using `ls-files`
- `_ZEX`: Array containing git command with appropriate `--git-dir` and `--work-tree` flags
- `_ZDL`: Last path visited (cleared after a git command in a tracked folder, so `_ZDF` is rebuilt)

### Context-Aware Behavior

When in a tracked folder, commands route through the bare repo. Otherwise,
commands pass through to regular git. The `_zz_dot_is_tracked()` function
determines this based on `$PWD` and comparing with `_ZDF`

### Custom Subcommands

- `dotfiles [--zsh-prompt] [--print-status]`

`--zsh-prompt` - updates state used by Zsh `precmd` hook in
[zsh-prompt](https://github.com/amazebb/zsh-prompt), to display the current
branch name with change counts: `+N` staged, `~N` unstaged, `!N` unmerged
(conflicts), `?N` untracked, and `↑N` `↓N` commits ahead of and behind the
upstream (only when an upstream is set).

`--print-status` - prints to stdout the following three lines:

  - current branch name followed by the change counts above
  - 1 if dotfiles repo, 0 standard git repo
  - path to .git/.dotfiles folder

## Tests

```sh
tests/run              # bootstrap on bash 3.2 and bash 5, dotfiles on zsh
tests/run -k prompt    # only tests whose name contains "prompt"
```

Needs `git`, `zsh` and `xxd`, and a normal user (not root: the permission tests
rely on read-only folders). Tests run in a scratch `$HOME`. `xfail_*` tests are
known open bugs and must fail; an `XPASS` means the bug is fixed, so rename it
to `test_*`.

Lint with:

```sh
bash -n bootstrap && zsh -n dotfiles
shellcheck -x bootstrap tests/run tests/lib.sh tests/*.test.sh
```

The same lint and tests run on GitHub Actions for every push.

## CI

`.github/workflows/tests.yml` lints and runs `tests/run` on `ubuntu-24.04` and
`macos-latest` for every push and pull request. A failure does not undo the
push; it marks the commit red on GitHub.

Check or start a run with the `gh` CLI:

```sh
gh run list --workflow tests.yml --limit 5   # recent runs
gh run watch --exit-status                   # follow a run; non-zero if it fails
gh run view <run-id> --log-failed            # logs of the failing steps only
gh workflow run tests.yml                    # start a run by hand (workflow_dispatch)
```

Dependabot (`.github/dependabot.yml`) checks the actions used in the workflow
once a month and opens a pull request when one has a new version. It only
edits the workflow file on GitHub; your clone changes when you pull. To handle
one:

```sh
gh pr list --app dependabot                  # find the pull request
gh pr checks <number> --watch                # wait for the tests on that PR
gh pr merge <number> --squash --delete-branch   # merge it if they pass
git pull                                     # bring the change into your clone
```

If the tests fail, `gh run view <run-id> --log-failed` shows why; fix it on the
PR branch or close the PR with `gh pr close <number>`.

## Why ?
- Learn some Zsh
- Learn Git plumbing
- Make dotfiles and Zsh prompts work with `sha1` and `sha256`
- Take ownership of your dotfiles
- Use AI to help flesh out syntax, and help write commit messages
- Clean house
- Does any of this matter? probably not...
- Then why? go to step 1...

