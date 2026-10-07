# shellcheck shell=bash
# Tests for the `dotfiles` zsh function. Each test writes a zsh script to $T and
# runs it with `zsh -f` (no user rc files), HOME=$T/home.

# zrun: read a zsh script on stdin, run it, merge stderr into stdout
zrun() {
    cat >"$T/t.zsh"
    zsh -f "$T/t.zsh" 2>&1
}

# first_status: first status line, skipping the one-off "No ... repo found" notice
first_status() { grep -v '^dotfiles: No ' <<<"$1" | sed -n 1p; }

# mkdotrepo: bare repo at $HOME/.dotfiles with the files checked out into $HOME
mkdotrepo() {
    mkrepo "$HOME/.dotfiles" ".zshrc=export A=1" ".config/my app/f=x"
    git --git-dir="$HOME/.dotfiles" --work-tree="$HOME" checkout -q -f
    git --git-dir="$HOME/.dotfiles" config status.showUntrackedFiles no
}

# mkwork: ordinary repo $T/work with one committed file
mkwork() {
    git init -q -b main "$T/work"
    git -C "$T/work" config user.email t@t
    git -C "$T/work" config user.name t
    touch "$T/work/plain"
    git -C "$T/work" add plain
    git -C "$T/work" commit -q -m init
}

test_zsh_parses() {
    zsh -n "$ROOT/dotfiles" || fail "zsh -n failed"
}

test_first_autoload_call_is_forwarded() {
    mkdotrepo
    out=$(zrun <<'EOF'
fpath=($ROOT $fpath)
autoload -Uz dotfiles
cd $HOME
dotfiles log --format=%s
EOF
    )
    assert_eq "$out" init
}

test_sourcing_without_args_runs_nothing() {
    mkdotrepo
    out=$(zrun <<'EOF'
source $ROOT/dotfiles
print -r -- "rc=$?"
EOF
    )
    assert_eq "$out" "rc=0"
}

test_tracked_folders_keep_spaces() {
    mkdotrepo
    out=$(zrun <<'EOF'
source $ROOT/dotfiles
_zz_dot_init
print -rl -- "${_ZDF[@]}"
EOF
    )
    assert_contains "$out" "$HOME/.config/my app"
    assert_not_contains "$out" "$HOME/app"
}

test_prompt_counts_staged_unstaged_untracked() {
    mkwork
    cd "$T/work" || exit 1
    echo 2 >>plain
    touch staged untracked untracked2
    git add staged
    git mv plain plain2
    echo 3 >>plain2
    out=$(zrun <<'EOF'
source $ROOT/dotfiles
cd $T/work
dotfiles --print-status
EOF
    )
    assert_eq "$(first_status "$out")" "main +2 ~1 ?2"
}

test_prompt_shows_head_when_detached() {
    mkwork
    git -C "$T/work" checkout -q --detach
    out=$(zrun <<'EOF'
source $ROOT/dotfiles
cd $T/work
dotfiles --print-status
EOF
    )
    assert_eq "$(first_status "$out")" "HEAD"
}

test_prompt_filename_with_newline_is_not_miscounted() {
    mkwork
    printf x >"$T/work/"$'a\nM b'
    git -C "$T/work" add -A
    git -C "$T/work" commit -q -m n
    echo y >>"$T/work/"$'a\nM b'
    out=$(zrun <<'EOF'
source $ROOT/dotfiles
cd $T/work
dotfiles --print-status
EOF
    )
    assert_eq "$(first_status "$out")" "main ~1"
}

test_prompt_in_tracked_folder_uses_dotfiles_repo() {
    mkdotrepo
    out=$(zrun <<'EOF'
source $ROOT/dotfiles
cd $HOME
dotfiles --print-status
EOF
    )
    assert_eq "$out" "main"$'\n'"1"$'\n'"$HOME/.dotfiles"
}

test_prompt_starts_one_git_process() {
    mkwork
    shim_git "$T/git.log"
    PATH=$PATH zrun <<'EOF'
source $ROOT/dotfiles
cd $T/work
dotfiles --zsh-prompt
: > $T/git.log
dotfiles --zsh-prompt
EOF
    assert_eq "$(wc -l <"$T/git.log" | tr -d ' ')" 1
}

test_prompt_does_not_run_repo_fsmonitor_hook() {
    mkwork
    printf '#!/bin/sh\ntouch %s/pwned\n' "$T" >"$T/hook.sh"
    chmod +x "$T/hook.sh"
    git -C "$T/work" config core.fsmonitor "$T/hook.sh"
    zrun <<'EOF'
source $ROOT/dotfiles
cd $T/work
dotfiles --zsh-prompt
EOF
    assert_no_file "$T/pwned"
}

test_missing_repo_reports_once_and_falls_back_to_git() {
    mkwork
    out=$(zrun <<'EOF'
source $ROOT/dotfiles
cd $T/work
dotfiles --print-status
dotfiles --print-status
EOF
    )
    assert_eq "$(grep -c 'No .* repo found' <<<"$out")" 1
    assert_eq "$(grep -c '^main$' <<<"$out")" 2
}

test_prompt_does_not_clobber_caller_variables() {
    mkdotrepo
    out=$(zrun <<'EOF'
source $ROOT/dotfiles
folder=keepme
cd $HOME
dotfiles --zsh-prompt
print -r -- $folder
EOF
    )
    assert_eq "$out" keepme
}

test_new_subfolder_of_tracked_folder_is_tracked_after_add() {
    # whitelist-style ~/.gitignore, as in a real dotfiles repo
    mkrepo "$HOME/.dotfiles" ".gitignore=*"$'\n''!.gitignore'$'\n''!.config'$'\n''!.config/nvim'$'\n''!.config/nvim/**' ".config/nvim/init.lua=i"
    git --git-dir="$HOME/.dotfiles" --work-tree="$HOME" checkout -q -f
    git --git-dir="$HOME/.dotfiles" config status.showUntrackedFiles no
    out=$(zrun <<'EOF'
source $ROOT/dotfiles
cd $HOME/.config/nvim
dotfiles status --short
mkdir -p lua
echo x > lua/p.lua
dotfiles add lua/p.lua
cd lua
dotfiles --print-status
EOF
    )
    assert_eq "$(sed -n 2p <<<"$out")" 1 "new subfolder not seen as tracked"
}

test_passthrough_commands_keep_their_exit_status() {
    mkdotrepo
    out=$(zrun <<'EOF'
source $ROOT/dotfiles
cd $HOME
dotfiles rev-parse --verify no-such-ref >/dev/null 2>&1
print -r -- "rc=$?"
dotfiles rev-parse --verify HEAD >/dev/null 2>&1
print -r -- "rc=$?"
EOF
    )
    assert_eq "$out" "rc=128"$'\n'"rc=0"
}

test_prompt_counts_unmerged_entries() {
    mkwork
    cd "$T/work" || exit 1
    echo base >f
    git add f
    git commit -q -m base
    git checkout -q -b side
    echo side >f
    git commit -q -am side
    git checkout -q main
    echo main >f
    git commit -q -am main
    git merge side >/dev/null 2>&1
    out=$(zrun <<'EOF'
source $ROOT/dotfiles
cd $T/work
dotfiles --print-status
EOF
    )
    assert_eq "$(first_status "$out")" "main !1"
}

test_prompt_shows_ahead_and_behind() {
    mkrepo "$T/up.git" "f=1"
    git clone -q "$T/up.git" "$T/w"
    git clone -q "$T/up.git" "$T/w2"
    echo 2 >"$T/w/g"
    git -C "$T/w" add g
    git -C "$T/w" commit -q -m ahead
    echo 3 >"$T/w2/h"
    git -C "$T/w2" add h
    git -C "$T/w2" commit -q -m other
    git -C "$T/w2" push -q origin main
    git -C "$T/w" fetch -q
    out=$(zrun <<'EOF'
source $ROOT/dotfiles
cd $T/w
dotfiles --print-status
EOF
    )
    assert_eq "$(first_status "$out")" "main ↑1 ↓1"
}

test_prompt_has_no_ahead_behind_without_upstream() {
    mkwork
    out=$(zrun <<'EOF'
source $ROOT/dotfiles
cd $T/work
dotfiles --print-status
EOF
    )
    assert_eq "$(first_status "$out")" "main"
}

test_works_under_user_zsh_options() {
    mkdotrepo
    out=$(zrun <<'EOF'
for opt in extendedglob ksharrays shwordsplit nounset nullglob noglob globsubst rcexpandparam kshglob; do
    (
        setopt $opt
        source $ROOT/dotfiles
        cd $HOME
        print -r -- "$opt: $(dotfiles --print-status 2>&1 | tr '\n' ' ')"
    )
done
EOF
    )
    bad=$(grep -v ": main 1 $HOME/.dotfiles $" <<<"$out" || true)
    [[ -z $bad ]] || fail "breaks under:"$'\n'"$bad"
}

test_missing_repo_message_is_not_repeated_by_passthrough_commands() {
    mkwork
    out=$(zrun <<'EOF'
source $ROOT/dotfiles
cd $T/work
dotfiles status >/dev/null
dotfiles log --oneline >/dev/null
dotfiles status >/dev/null
EOF
    )
    assert_eq "$(grep -c 'No .* repo found' <<<"$out")" 1
}
