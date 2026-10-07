# shellcheck shell=bash
# Helpers for tests/*.test.sh. Sourced by tests/run; every test runs in its own
# subshell with a scratch $HOME, so a failed assert may simply `exit 1`.

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)
export ROOT

fail() { echo "FAIL: $*" >&2; exit 1; }

setup() {
    T=$(mktemp -d "${TMPDIR:-/tmp}/dotfiles-test.XXXXXX")
    T=$(cd "$T" && pwd -P)
    export T
    export HOME=$T/home
    export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_SYSTEM=/dev/null
    export GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@t GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@t
    mkdir -p "$HOME"
}

teardown() {
    if [[ -n ${T:-} && $T == */dotfiles-test.* ]]; then
        rm -rf -- "$T"
    fi
}

# mkrepo <out.git> <path=content>...  bare repo with one commit on branch main
mkrepo() {
    local out=$1 spec src
    shift
    src=$(mktemp -d "$T/src.XXXXXX")
    git init -q -b main "$src"
    for spec in "$@"; do
        mkdir -p "$src/$(dirname "${spec%%=*}")"
        printf '%s\n' "${spec#*=}" >"$src/${spec%%=*}"
    done
    git -C "$src" add -A
    git -C "$src" commit -q -m init
    git clone -q --bare "$src" "$out"
}

# mkcrafted <out.git> <component>...  bare repo whose only entry is the given
# path, built with raw tree objects so it may contain "..", ".git", etc.
mkcrafted() {
    local out=$1 i mode=100644 t
    local -a parts
    shift
    parts=("$@")
    git init -q --bare "$out"
    t=$(echo payload | git --git-dir="$out" hash-object -w --stdin)
    for ((i = ${#parts[@]} - 1; i >= 0; i--)); do
        t=$({
            printf '%s %s\0' "$mode" "${parts[i]}"
            echo "$t" | xxd -r -p
        } | git --git-dir="$out" hash-object -t tree -w --stdin --literally)
        mode=40000
    done
    t=$(git --git-dir="$out" commit-tree "$t" -m x)
    git --git-dir="$out" update-ref refs/heads/main "$t"
    git --git-dir="$out" symbolic-ref HEAD refs/heads/main
}

# shim_git <logfile>  put a git wrapper first on PATH that logs "TMPDIR=<v> <args>"
shim_git() {
    mkdir -p "$T/shim"
    cat >"$T/shim/git" <<SH
#!/bin/sh
echo "TMPDIR=[\$TMPDIR] \$*" >> "$1"
exec "$(command -v git)" "\$@"
SH
    chmod +x "$T/shim/git"
    PATH=$T/shim:$PATH
}

# minimal_path  PATH with only the tools bootstrap needs (no opendiff/vimdiff)
minimal_path() {
    local tool
    mkdir -p "$T/mini"
    for tool in git diff cat mktemp dirname rm mv mkdir chmod date tr cp sleep grep env; do
        ln -sf "$(command -v "$tool")" "$T/mini/$tool"
    done
    echo "$T/mini"
}

assert_eq() { [[ $1 == "$2" ]] || fail "${3:-assert_eq}: expected [$2], got [$1]"; }
assert_contains() { [[ $1 == *"$2"* ]] || fail "${3:-assert_contains}: [$2] not in output:"$'\n'"$1"; }
assert_not_contains() { [[ $1 != *"$2"* ]] || fail "${3:-assert_not_contains}: [$2] found in output:"$'\n'"$1"; }
assert_file() { [[ -e $1 ]] || fail "missing: $1"; }
assert_no_file() { [[ ! -e $1 && ! -L $1 ]] || fail "unexpected: $1"; }
assert_content() { assert_eq "$(cat "$1")" "$2" "content of $1"; }
