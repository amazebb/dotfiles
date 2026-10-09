#!/bin/sh
# Install the dotfiles function: clone, optional bootstrap (dry-run first), autoload.
set -eu

ask() { # ask <prompt> <default>; reads the terminal because stdin is the script
    printf '%s [%s]: ' "$1" "$2" >&2
    read -r reply </dev/tty || reply=
    printf '%s\n' "${reply:-$2}"
}

# INSTALL_DIR, REPO_DOTFILE and DOTFILES_URL may be preset in the environment
DOTFILES_URL=${DOTFILES_URL:-https://github.com/amazebb/dotfiles.git}
[ -n "${INSTALL_DIR+x}" ] || INSTALL_DIR=$(ask "INSTALL_DIR" "$HOME/.local/share/zsh/site-functions/dotfiles")
[ -n "${REPO_DOTFILE+x}" ] || REPO_DOTFILE=$(ask "REPO_DOTFILE (https:// URL, empty to skip bootstrap)" "")

if [ -d "$INSTALL_DIR/.git" ]; then
    git -C "$INSTALL_DIR" checkout master
    git -C "$INSTALL_DIR" pull --ff-only
else
    mkdir -p "$(dirname "$INSTALL_DIR")"
    git clone "$DOTFILES_URL" "$INSTALL_DIR"
    git -C "$INSTALL_DIR" checkout master
fi

case $REPO_DOTFILE in
https://*)
    if "$INSTALL_DIR/bootstrap" "$REPO_DOTFILE"; then
        case $(ask "Review with -v, apply with -f, or skip? (v/f/s)" "s") in
        v) "$INSTALL_DIR/bootstrap" -v "$REPO_DOTFILE" ;;
        f) "$INSTALL_DIR/bootstrap" -f "$REPO_DOTFILE" ;;
        esac
    else
        echo "bootstrap dry-run failed, skipping bootstrap" >&2
    fi
    ;;
"") ;;
*) echo "REPO_DOTFILE must start with https://, skipping bootstrap" >&2 ;;
esac

if ! grep -qs 'autoload -Uz +X dotfiles' "$HOME/.zshenv"; then
    cat <<EOT >>"$HOME/.zshenv"

# Custom dotfiles function
fpath+=( "$INSTALL_DIR" )
autoload -Uz +X dotfiles
EOT
fi
echo "Done. Open a new shell to use \`dotfiles\`."
