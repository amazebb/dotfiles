# Audit: dotfiles (2026-09-29)

Scope: `bootstrap` (bash, 305 lines), `dotfiles` (zsh function, 75 lines), `README.md`. Last commit audited: `96085eb`.

Trust boundaries:
- `bootstrap` treats the repo it clones as untrusted input, and its files then run as you (`.zshrc`, etc.).
- `dotfiles` runs git in whatever directory you `cd` into, including repos you did not create.

Every row is marked **(reproduced)** (run in a scratch `$HOME`) or **(by reading)**.

## Security

| Where | Issue | Example and consequence | Fix |
|---|---|---|---|
| `bootstrap:173-185`, `bootstrap:272` | Repo paths are not checked for `..`. A crafted tree entry named `..` gives the path `../victim`, and `mv "$HOME/$file" "$BACKUP_DIR/$file"` moves a file outside `$HOME`. **(reproduced)** | Tree with `../victim`, `HOME=<scratch>/home/u`, and `<scratch>/home/victim` existing: `bootstrap -f` moved `home/victim` into `home/u/`. Git's checkout then refused the path, so the only effect was the move. Any file your user can write, in a directory you own, can be relocated. | Clone with `-c transfer.fsckObjects=true` (reproduced: it rejects the tree with `hasDotdot`). Also reject any path containing a `..` component, a leading `/`, or a `.git` component before using it. |
| `bootstrap:218-219`, `bootstrap:240`, `bootstrap:248` | Filenames and conflict-diff content print raw. The `%q` fix covered only lines 184 and 290. **(reproduced)** | A file named `ev<ESC>[31mIL` printed as a raw escape at the "New files" list (`cat -v` shows `ev^[[31mIL`). A hostile repo can recolour, overwrite or forge lines in the list you are asked to approve. | Use `printf '  %q\n'` at 240 and 248, `printf '%q'` in the `echo` at 218, and pipe the `diff` at 219 through `cat -v`. |
| `bootstrap:161` | Cleartext transports (`http://`, `git://`) are accepted for a repo whose files run as you. (From git's documented defaults, **not tested**.) | `bootstrap http://host/dots.git`: anyone on the path can swap the repo contents. | `-c protocol.allow=never -c protocol.https.allow=always -c protocol.ssh.allow=always` (add `protocol.file.allow=always` if you use local paths). |

## Bugs

| Where | Issue | Example and consequence | Fix |
|---|---|---|---|
| `bootstrap:265-294` | The final "Proceed with checkout?" prompt comes after files are backed up and the repo is moved. Answering `n` exits with `$HOME` stripped. **(reproduced)** | `.zshrc` exists, run `bootstrap -f`, answer `y`, `y`, `n`: `Aborted.`, and `.zshrc` is now only in `.dotfiles-backup-<timestamp>/`. Nothing is restored. | Ask that question before the backup at 265, or restore the backup on any exit before checkout succeeds. |
| `dotfiles:63-75` | With `autoload -Uz dotfiles` the file is run as the function body, so the first call defines things and its arguments are dropped. **(reproduced)** | Fresh shell, `dotfiles log --oneline` prints nothing. The second call prints `6c07d06 i`. Harmless if the prompt hook calls it first, wrong if you type it first. | End the file with `dotfiles "$@"` so the first call is forwarded. **(untested)** |
| `dotfiles:23` | `xargs dirname` splits names on whitespace. **(reproduced)** | Tracked `.config/my app/f` yields `.config` (wrong) and `app` (bogus). `~/.config/my app` is not marked tracked, and `~/app` is. | `ls-files -z`, then zsh `${(0)$(git ls-files -z)}` and `${(u)files:h}`, with no `xargs`, `sort` or `sed`. |
| `dotfiles:18-19` | `( echo msg; return 1 )` returns only from the subshell. **(reproduced)** | No `~/.dotfiles`: it prints `No <path> repo found`, then carries on to `fatal: not a git repository`, returning 1. | `{ echo msg; return 1; }` |
| `bootstrap:112`, `bootstrap:156`, `bootstrap:280` | `TMPDIR` is the standard env var. It is exported and overwritten. **(reproduced)** | `TMPDIR=""` at 112 sends the first `mktemp -d` to `/tmp` instead of your per-user temp dir. Line 156 then exports the clone dir as `TMPDIR` to every child. Line 280 exports it empty for `git checkout`. | Rename the variable to `WORK`. |
| `bootstrap:279` | Only `-e "$DOTFILES_DIR"` is checked. A `-d` whose parent does not exist makes `mv` fail after the backup. **(by reading)** | `bootstrap -f -d /no/such/dir/x repo`: files backed up, `mv` fails, the trap deletes the clone. | Check `dirname "$DOTFILES_DIR"` exists at 151. |
| `bootstrap:151`, `bootstrap:159` | `$DRY_RUN && <command>` runs the variable as a command. **(by reading)** | Latent: works while the value is `true` or `false`. `DRY_RUN=yes` would try to run `yes`. | `[[ $DRY_RUN == true ]]` |
| `dotfiles:32` | `for folder` is a global in a zsh function. **(by reading)** | The prompt clobbers a `folder` variable in your shell. | `local folder` |
| `dotfiles:21-26` | `_ZDF` is built once per shell. **(by reading)** | `dotfiles add ~/.config/new/f`, then `cd ~/.config/new`: the prompt uses plain git until a new shell. | Rebuild `_ZDF` after `add` and `commit`. |

## Performance

Measured on this machine, 200 prompt calls each: 12 ms per `dotfiles --zsh-prompt` when clean, 20 ms when dirty, 6.5 ms for a single `git status --porcelain=v2 --branch`.

- `dotfiles:40,48` starts 2 git processes per prompt (**reproduced** with a counting `git` shim), clean or dirty. The extra ~8 ms when dirty is the three `echo | grep -c` pipelines at 52-56. `xargs`, `sort` and `sed` run once per shell, not per prompt.
- Replace `rev-parse` and `status` with one `git --no-optional-locks status --porcelain=v2 --branch`, and count entries in zsh, e.g. `${#${(M)lines:#1 [MTADRC].*}}`. Expected ~7 ms clean or dirty.
- `--no-optional-locks` also stops the prompt taking `index.lock` while another git command runs.
- The git dir does not change with `$PWD` inside one repo: read it from `$_ZD[repo]` or cache it in `_zz_dot_is_tracked`.

## Quality

- `bootstrap:21` `ask()` is unused. `color` has names nothing uses (GREEN, YELLOW, MAGENTA, CYAN).
- `bootstrap:14` and `bootstrap:22`: `read` failing without a tty exits silently under `set -e`, with no "Aborted." message.
- `bootstrap:175`: the symlink refusal also blocks a dry-run, so a stow-style symlinked `~/.config` cannot be previewed. Consider refusing only at the backup step.
- `bootstrap:207`: `pgrep -x FileMerge` waits on any FileMerge process, not the one it opened.
- `bootstrap:210`: the vimdiff temp name `tr '/' '-'` collides (`a/b-c` vs `a-b/c`). Use `mktemp`.
- `bootstrap:282` defines a `dotfiles` shell function with the same name as the zsh one. Rename to `_dot`.
- `dotfiles:44-58`: unmerged states (`U`, `AA`, `DD`) are not counted, and there is no ahead/behind. `--branch` supplies both.
- `dotfiles:67-74`: `--zsh-prompt` and `--print-status` are matched before real git args. Document them or move them to a separate function.
- `dotfiles:10`: `zsh -n dotfiles` fails with `bad subscript for direct array assignment: repo`, so it cannot be linted. The `key value` form of the assignment should parse. **(untested)**
- README: line 76-77 "no guarantees elsewhere, including macOS" contradicts itself. Line 109 says three global variables and lists four. Line 119 has the typo `_$ZDF`. Line 98 says `~/.gitignore` defines tracked files, but the code uses `ls-files`. The install steps do not mention the `-v` review the script now recommends. The clone from `main` over https is not pinned.
- `shfmt -d -i 4 bootstrap` reports style differences (`local name=$1; shift` on one line, aligned `case` arms).
- No tests and no CI. Add `shellcheck` and `bats`. `shellcheck` cannot check zsh, so `dotfiles` needs `zsh -n` or `zsh -f` smoke tests.

## Since last audit

Baseline: the previous `AUDIT.md` (bugs, performance, quality) plus the seven security fixes from commit `96085eb`. Sec 6 and 7 and the bash 3.2 crash were reverted or fixed in the follow-up commit.

| Finding | Status | Note |
|---|---|---|
| Sec 1 backup dir 700 | fixed | Backup dir is `drwx------` (**reproduced**). |
| Sec 2 anchored `y/n` | fixed | "maybe" aborted (**reproduced** last session). |
| Sec 3 symlinked parent | fixed | Refused a symlinked `~/.config` (**reproduced** last session). |
| Sec 4 NUL-delimited names, `%q` | still open (partial) | Only two of five print sites use `%q`. See Security row 2. |
| Sec 5 confirm after diffs, show new files | fixed | New-file contents print through `cat -v`. Conflict diffs at 219 do not. |
| Sec 6 `protocol.ext.allow=never` | reverted | The flag was redundant (`ext` is already blocked by default, **reproduced**). Clone line is back to the original. Cleartext transports remain open. |
| Sec 7 `core.fsmonitor=false` | reverted | Prompt git calls are back to the original. Plain `git status` runs a repo's `core.fsmonitor` hook (**reproduced**), so the risk in hostile repos is open. Your call whether to address it. |
| Prior perf claim "about 8 processes per prompt" | **corrected** | It is 2 git processes, plus 3 grep pipelines when dirty. |
| `TMPDIR` | still open | Refined with reproduced details above. |
| Backup or `mv` fails partway | still open | New variant: answering `n` at the last prompt. |
| `$DRY_RUN` as a command | still open | Latent. |
| `dotfiles:18-19`, `xargs`, `folder`, `_ZDF` staleness | still open | First two reproduced. |
| `"${NEW[@]}"` on bash 3.2 | fixed | Regression from the security commit, now guarded and verified on `/bin/bash` 3.2. |
| `-d` parent-dir check, vimdiff temp name, unmerged states, flag collisions, CI | still open | Unchanged. |

## Tooling results

- `shellcheck -x bootstrap`: no findings. `bash -n bootstrap`: ok.
- `zsh -n dotfiles`: fails at line 10, identically on the pre-audit version (see Quality).
- `shfmt -d -i 4 bootstrap`: style differences only.
- Secrets scan: `git log -p --all` grep for password/token/key patterns found nothing. `gitleaks` and `trufflehog` are not installed.
- `bats` is not installed. No dependency manifests, so no dependency audit applies.
- All reproductions ran in a scratch directory with `HOME` pointed at it. The real `$HOME` was not touched.
