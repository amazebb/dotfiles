#!/bin/sh
# Install the dotfiles function: clone, optional bootstrap (dry-run first), autoload.
set -eu

# stdin is the script under `curl | sh`, so answers (ours and bootstrap's) come from fd 3
exec 3<"${TTY:-/dev/tty}"

ask() { # ask <prompt> <default>
    printf '%s [%s]: ' "$1" "$2" >&2
    read -r reply <&3 || reply=
    printf '%s\n' "${reply:-$2}"
}

# INSTALL_DIR, REPO_DOTFILE and DOTFILES_URL may be preset in the environment
DOTFILES_URL=${DOTFILES_URL:-https://github.com/amazebb/dotfiles.git}
[ -n "${INSTALL_DIR+x}" ] || INSTALL_DIR=$(ask "INSTALL_DIR" "$HOME/.local/share/zsh/site-functions/dotfiles")
[ -n "${REPO_DOTFILE+x}" ] || REPO_DOTFILE=$(ask "REPO_DOTFILE (user/repo or https:// URL, empty to skip bootstrap)" "")

case $INSTALL_DIR in
"~"/*) INSTALL_DIR=$HOME${INSTALL_DIR#"~"} ;;
/*) ;;
*) INSTALL_DIR=$PWD/$INSTALL_DIR ;;
esac
case $INSTALL_DIR in
*[\"\$\`\\]*) echo "INSTALL_DIR must not contain \" \$ \` or \\" >&2; exit 1 ;;
esac

[ -d "$INSTALL_DIR/.git" ] || {
    mkdir -p "$(dirname "$INSTALL_DIR")"
    git clone "$DOTFILES_URL" "$INSTALL_DIR"
}
git -C "$INSTALL_DIR" checkout master
git -C "$INSTALL_DIR" pull --ff-only

case $REPO_DOTFILE in # user/repo is GitHub shorthand
*[!A-Za-z0-9._/-]* | */*/* | /* | */ | -* | .*/*) ;;
*/*) REPO_DOTFILE=https://github.com/${REPO_DOTFILE%.git}.git ;;
esac

case $REPO_DOTFILE in
https://*)
    if "$INSTALL_DIR/bootstrap" "$REPO_DOTFILE" <&3; then
        while :; do
            case $(ask "Review with -v, apply with -f, or skip? (v/f/s)" "s") in
            v) "$INSTALL_DIR/bootstrap" -v "$REPO_DOTFILE" <&3 || true ;;
            f) "$INSTALL_DIR/bootstrap" -f "$REPO_DOTFILE" <&3 || true; break ;;
            *) break ;;
            esac
        done
    else
        echo "bootstrap dry-run failed, skipping bootstrap" >&2
    fi
    ;;
"") ;;
*) echo "REPO_DOTFILE must be user/repo or start with https://, skipping bootstrap" >&2 ;;
esac

if ! grep -qs 'autoload -Uz +X dotfiles' "$HOME/.zshenv"; then
    cat <<EOT >>"$HOME/.zshenv"

# Custom dotfiles function
fpath+=( "$INSTALL_DIR" )
autoload -Uz +X dotfiles
EOT
fi
echo "Done. Open a new shell to use \`dotfiles\`."
