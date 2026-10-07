# shellcheck shell=bash
# bootstrap tests. Run via tests/run, which sets BS_SHELL (bash 3.2 and bash 5).
# Each test builds its repos under $T and runs bootstrap with HOME=$T/home.

# bs <answers> <bootstrap args...>: feed answers on stdin; output in $OUT, status in $RC
bs() {
    local answers=$1
    shift
    OUT=$(printf '%b' "$answers" | "$BS_SHELL" "$ROOT/bootstrap" "$@" 2>&1)
    RC=$?
}

snapshot() { (cd "$HOME" && find . -mindepth 1 | LC_ALL=C sort); }

# --- security -------------------------------------------------------------

test_dotdot_path_refused() {
    echo keep >"$T/victim"
    mkcrafted "$T/evil.git" .. victim
    bs 'y\ny\ny\n' -f "$T/evil.git"
    ((RC != 0)) || fail "bootstrap accepted a '..' path"
    assert_contains "$OUT" "unsafe path"
    assert_content "$T/victim" keep
    assert_no_file "$HOME/victim"
}

test_dotdot_tree_rejected_by_fsck() {
    echo keep >"$T/victim"
    mkcrafted "$T/evil.git" .. victim
    bs 'y\ny\ny\n' -f "file://$T/evil.git"
    ((RC != 0)) || fail "clone of malformed tree succeeded"
    assert_contains "$OUT" "fsck"
    assert_content "$T/victim" keep
}

test_dot_git_path_refused() {
    mkcrafted "$T/evil.git" .git hooks post-checkout
    bs 'y\ny\ny\n' -f "$T/evil.git"
    ((RC != 0)) || fail "bootstrap accepted a .git path"
    assert_contains "$OUT" "unsafe path"
}

test_escape_codes_in_names_not_printed_raw() {
    mkrepo "$T/r.git" ".zshrc=export A=1" $'ev\e[31mIL=hi'
    bs 'y\n' "$T/r.git"
    assert_contains "$OUT" "New files"
    assert_not_contains "$OUT" $'ev\e[31m' "raw ESC from filename reached the terminal"
}

test_escape_codes_in_diff_not_printed_raw() {
    mkrepo "$T/r.git" ".zshrc=export A=1"
    printf '\e[31mHI\n' >"$HOME/.zshrc"
    PATH=$(minimal_path) bs 'y\n' -v "$T/r.git"
    assert_contains "$OUT" "^[[31mHI"
    assert_not_contains "$OUT" $'< \e[31mHI'
}

test_symlinked_parent_refused() {
    mkdir "$T/real"
    ln -s "$T/real" "$HOME/.config"
    mkrepo "$T/r.git" ".config/app/f=x" ".zshrc=new"
    echo old >"$HOME/.zshrc"
    bs 'y\ny\ny\n' -f "$T/r.git"
    ((RC != 0)) || fail "bootstrap followed a symlinked parent"
    assert_contains "$OUT" "symlink"
    assert_content "$HOME/.zshrc" old
    assert_no_file "$T/real/app"
}

test_non_directory_parent_refused() {
    echo "i am a file" >"$HOME/.config"
    mkrepo "$T/r.git" ".config/my app/f=x" ".zshrc=new"
    echo old >"$HOME/.zshrc"
    bs 'y\ny\ny\n' -f "$T/r.git"
    ((RC != 0)) || fail "bootstrap continued with a file where a directory is needed"
    assert_contains "$OUT" "not a directory"
    assert_content "$HOME/.zshrc" old
    assert_no_file "$HOME/.dotfiles"
}

test_backup_dir_is_private() {
    mkrepo "$T/r.git" ".zshrc=new"
    echo old >"$HOME/.zshrc"
    bs 'y\ny\ny\n' -f "$T/r.git"
    ((RC == 0)) || fail "apply failed: $OUT"
    local mode
    # shellcheck disable=SC2012
    mode=$(ls -ld "$HOME"/.dotfiles-backup-* | cut -c1-10)
    assert_eq "$mode" "drwx------"
}

test_only_exact_yes_proceeds() {
    mkrepo "$T/r.git" ".zshrc=new"
    bs 'maybe\n' "$T/r.git"
    ((RC != 0)) || fail "'maybe' was accepted"
    assert_contains "$OUT" "Aborted."
}

# --- behaviour ------------------------------------------------------------

test_dry_run_changes_nothing() {
    mkrepo "$T/r.git" ".zshrc=new" ".config/my app/f=x"
    echo old >"$HOME/.zshrc"
    local before
    before=$(snapshot)
    bs 'y\n' "$T/r.git"
    ((RC == 0)) || fail "dry-run failed: $OUT"
    assert_contains "$OUT" "Dry-run finished"
    assert_eq "$(snapshot)" "$before" "HOME changed during dry-run"
}

test_answering_no_at_final_prompt_leaves_home_intact() {
    mkrepo "$T/r.git" ".zshrc=new"
    echo old >"$HOME/.zshrc"
    bs 'y\ny\nn\n' -f "$T/r.git"
    ((RC != 0)) || fail "expected non-zero after answering n"
    assert_content "$HOME/.zshrc" old
    assert_no_file "$HOME/.dotfiles"
    [[ -z $(ls -d "$HOME"/.dotfiles-backup-* 2>/dev/null) ]] || fail "backup was made before the final confirmation"
}

test_missing_dotfiles_parent_refused_before_backup() {
    mkrepo "$T/r.git" ".zshrc=new"
    echo old >"$HOME/.zshrc"
    bs 'y\ny\ny\n' -f -d "$HOME/no/such/x" "$T/r.git"
    ((RC != 0)) || fail "expected refusal"
    assert_contains "$OUT" "does not exist"
    assert_content "$HOME/.zshrc" old
}

test_full_apply_with_conflict_and_new_file() {
    mkrepo "$T/r.git" ".zshrc=new" ".config/my app/f=x"
    echo old >"$HOME/.zshrc"
    bs 'y\ny\ny\n' -f "$T/r.git"
    ((RC == 0)) || fail "apply failed: $OUT"
    assert_content "$HOME/.zshrc" new
    assert_content "$HOME/.config/my app/f" x
    assert_content "$(ls -d "$HOME"/.dotfiles-backup-*)/.zshrc" old
    assert_eq "$(git --git-dir="$HOME/.dotfiles" config status.showUntrackedFiles)" no
}

test_full_apply_with_nothing_existing() {
    mkrepo "$T/r.git" ".zshrc=new"
    bs 'y\ny\n' -f "$T/r.git"
    ((RC == 0)) || fail "apply failed: $OUT"
    assert_content "$HOME/.zshrc" new
}

test_tmpdir_is_honoured_and_not_leaked() {
    mkrepo "$T/r.git" ".zshrc=new"
    mkdir "$T/tmp"
    shim_git "$T/git.log"
    TMPDIR=$T/tmp bs 'y\ny\n' -f "$T/r.git"
    ((RC == 0)) || fail "apply failed: $OUT"
    assert_contains "$OUT" "Cloning into bare repository '$T/tmp/"
    local bad
    bad=$(grep -v "^TMPDIR=\[$T/tmp\] " "$T/git.log" || true)
    [[ -z $bad ]] || fail "a child git saw a different TMPDIR:"$'\n'"$bad"
}

# --- known open (expected to fail until fixed) ----------------------------

test_double_dash_keeps_operands() {
    mkrepo "$T/r.git" ".zshrc=new"
    bs 'n\n' -- "$T/r.git"
    assert_contains "$OUT" "Cloning from $T/r.git"
}

test_option_like_operand_after_double_dash_is_not_a_git_option() {
    bs 'n\n' -- --upload-pack=true
    ((RC != 0)) || fail "expected clone to fail"
    assert_not_contains "$OUT" "Unknown option"
    assert_contains "$OUT" "git clone failed"
    assert_contains "$OUT" "repository '--upload-pack=true' does not exist" "git parsed the operand as an option"
}

test_cleartext_transports_refused() {
    local url
    for url in http://127.0.0.1:9/x.git git://127.0.0.1:9/x.git; do
        bs 'n\n' "$url"
        ((RC != 0)) || fail "$url was accepted"
        assert_contains "$OUT" "not allowed" "$url"
        assert_not_contains "$OUT" "Failed to connect" "a connection to $url was attempted"
    done
}

test_ssh_style_url_is_not_blocked_by_transport_rules() {
    # no server here: the clone must fail on the connection, not on the transport rule
    bs 'n\n' nobody@127.0.0.1:9/x.git
    assert_not_contains "$OUT" "not allowed"
}

test_backup_failure_midway_restores_moved_files() {
    trap 'chmod -R u+w "$T"; teardown' EXIT
    mkrepo "$T/r.git" ".a=new" ".config/f=new"
    echo old >"$HOME/.a"
    mkdir "$HOME/.config"
    echo old >"$HOME/.config/f"
    chmod 555 "$HOME/.config"
    bs 'y\ny\ny\n' -f "$T/r.git"
    ((RC != 0)) || fail "expected failure"
    assert_contains "$OUT" "Nothing was changed"
    assert_content "$HOME/.a" old
    assert_content "$HOME/.config/f" old
    assert_no_file "$HOME/.dotfiles"
    [[ -z $(find "$HOME" -maxdepth 1 -name '.dotfiles-backup-*') ]] || fail "empty backup dir left behind"
}

test_repo_move_failure_with_nothing_backed_up_reports_cleanly() {
    trap 'chmod -R u+w "$T"; teardown' EXIT
    mkrepo "$T/r.git" ".zshrc=new"
    mkdir "$HOME/sub"
    chmod 555 "$HOME/sub"
    bs 'y\ny\n' -f -d "$HOME/sub/x" "$T/r.git"
    ((RC != 0)) || fail "expected failure"
    assert_contains "$OUT" "Nothing was changed"
    assert_not_contains "$OUT" "unbound variable"
}

test_repo_move_failure_after_backup_restores_files() {
    trap 'chmod -R u+w "$T"; teardown' EXIT
    mkrepo "$T/r.git" ".zshrc=new"
    echo old >"$HOME/.zshrc"
    mkdir "$HOME/sub"
    chmod 555 "$HOME/sub"
    bs 'y\ny\ny\n' -f -d "$HOME/sub/x" "$T/r.git"
    ((RC != 0)) || fail "expected failure"
    assert_contains "$OUT" "Nothing was changed"
    assert_content "$HOME/.zshrc" old
    [[ -z $(find "$HOME" -maxdepth 1 -name '.dotfiles-backup-*') ]] || fail "backup dir left behind"
}

test_stdin_eof_says_aborted() {
    mkrepo "$T/r.git" ".zshrc=new"
    bs '' "$T/r.git"
    ((RC != 0)) || fail "expected non-zero at EOF"
    assert_contains "$OUT" "Aborted."
}

test_second_repo_operand_is_refused() {
    mkrepo "$T/a.git" ".zshrc=a"
    mkrepo "$T/b.git" ".zshrc=b"
    bs 'n\n' "$T/a.git" "$T/b.git"
    ((RC != 0)) || fail "two repos were accepted"
    assert_contains "$OUT" "only one repo"
    assert_not_contains "$OUT" "Cloning"
}

test_second_repo_operand_after_double_dash_is_refused() {
    mkrepo "$T/a.git" ".zshrc=a"
    bs 'n\n' -- "$T/a.git" "$T/a.git"
    ((RC != 0)) || fail "two repos were accepted"
    assert_contains "$OUT" "only one repo"
}

test_backups_in_the_same_second_do_not_overwrite_each_other() {
    mkdir -p "$T/shim"
    printf '#!/bin/sh\necho 20200101-000000\n' >"$T/shim/date"
    chmod +x "$T/shim/date"
    PATH=$T/shim:$PATH
    mkrepo "$T/r.git" ".zshrc=new"
    echo old1 >"$HOME/.zshrc"
    bs 'y\ny\ny\n' -f -d "$HOME/.d1" "$T/r.git"
    ((RC == 0)) || fail "first apply failed: $OUT"
    echo old2 >"$HOME/.zshrc"
    bs 'y\ny\ny\n' -f -d "$HOME/.d2" "$T/r.git"
    ((RC == 0)) || fail "second apply failed: $OUT"
    local all
    all=$(cat "$HOME"/.dotfiles-backup-*/.zshrc | sort | tr '\n' ' ')
    assert_eq "$all" "old1 old2 " "a backup was overwritten"
}
