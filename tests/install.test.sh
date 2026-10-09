# shellcheck shell=bash
# install.sh tests. The clone comes from a local repo via DOTFILES_URL, and
# INSTALL_DIR/REPO_DOTFILE are preset so nothing prompts or touches the network.

mksrc() { # local "upstream" with a master branch holding a bootstrap stub
    SRC=$T/upstream
    git init -q -b master "$SRC"
    # shellcheck disable=SC2016
    printf '#!/bin/sh\necho "bootstrap $*" >>"$HOME/bootstrap.log"\n' >"$SRC/bootstrap"
    chmod +x "$SRC/bootstrap"
    git -C "$SRC" add -A
    git -C "$SRC" commit -q -m init
}

inst() { # inst <REPO_DOTFILE>; output in $OUT, status in $RC
    mksrc
    OUT=$(DOTFILES_URL=$SRC INSTALL_DIR=$HOME/inst REPO_DOTFILE=$1 sh "$ROOT/install.sh" 2>&1 </dev/null)
    RC=$?
}

test_install_clones_master_and_sets_autoload() {
    inst ""
    ((RC == 0)) || fail "install failed: $OUT"
    [[ $(git -C "$HOME/inst" branch --show-current) == master ]] || fail "not on master"
    grep -qx 'autoload -Uz +X dotfiles' "$HOME/.zshenv" || fail "autoload line missing"
    grep -qF "fpath+=( \"$HOME/inst\" )" "$HOME/.zshenv" || fail "fpath line missing"
}

test_install_without_repo_skips_bootstrap() {
    inst ""
    ((RC == 0)) || fail "install failed: $OUT"
    assert_no_file "$HOME/bootstrap.log"
}

test_install_non_https_repo_skips_bootstrap() {
    inst "git@github.com:me/repo.git"
    ((RC == 0)) || fail "install failed: $OUT"
    assert_contains "$OUT" "must start with https://"
    assert_no_file "$HOME/bootstrap.log"
}

test_install_https_repo_runs_dry_run_first() {
    inst "https://example.invalid/me/repo.git"
    ((RC == 0)) || fail "install failed: $OUT"
    [[ $(head -n1 "$HOME/bootstrap.log") == "bootstrap https://example.invalid/me/repo.git" ]] ||
        fail "first bootstrap call was not the plain dry-run: $(cat "$HOME/bootstrap.log")"
}

test_install_twice_keeps_one_autoload_block() {
    inst ""
    inst ""
    ((RC == 0)) || fail "second install failed: $OUT"
    [[ $(grep -c 'autoload -Uz +X dotfiles' "$HOME/.zshenv") == 1 ]] || fail "autoload block duplicated"
}
