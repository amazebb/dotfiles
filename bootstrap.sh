#!/usr/bin/env bash
# bootstrap.sh - Safe bare repo dotfiles installer

DOTFILES_DIR="$HOME/.dotfiles"
BACKUP_DIR="$HOME/.dotfiles-backup-$(date +%Y%m%d-%H%M%S)"
REPO_URL="https://github.com/x626f/dotfiles.git"

echo "Setting up bare dotfiles repository..."

# Clone as bare repo
git clone --bare "$REPO_URL" "$DOTFILES_DIR"

# Define the git command for this bare repo
function dotfiles() {
  git --git-dir="$DOTFILES_DIR" --work-tree="$HOME" "$@"
}

# Don't show untracked files
dotfiles config --local status.showUntrackedFiles no

# Get list of all files that would be checked out
FILES=$(dotfiles ls-files)

# Check for conflicts
CONFLICTS=()
while IFS= read -r file; do
  if [ -e "$HOME/$file" ]; then
    CONFLICTS+=("$file")
  fi
done <<<"$FILES"

# Handle conflicts
if [ ${#CONFLICTS[@]} -gt 0 ]; then
  echo ""
  echo "⚠️  The following files already exist:"
  printf '  %s\n' "${CONFLICTS[@]}"
  echo ""
  read -p "Backup existing files to $BACKUP_DIR? [y/N] " -n 1 -r
  echo

  if [[ $REPLY =~ ^[Yy]$ ]]; then
    mkdir -p "$BACKUP_DIR"
    for file in "${CONFLICTS[@]}"; do
      # Create parent directory structure in backup
      mkdir -p "$BACKUP_DIR/$(dirname "$file")"
      mv "$HOME/$file" "$BACKUP_DIR/$file"
      echo "  Backed up: $file"
    done
    echo "✓ Backup complete: $BACKUP_DIR"
  else
    echo "Aborted. Remove $DOTFILES_DIR to clean up."
    exit 1
  fi
fi

# Now safe to checkout
echo ""
echo "Checking out dotfiles..."
if dotfiles checkout; then
  echo "✓ Dotfiles installed successfully!"
  echo ""
  echo "Add this alias to use the dotfiles repo:"
  echo "  alias dotfiles='git --git-dir=$DOTFILES_DIR --work-tree=$HOME'"
else
  echo "✗ Checkout failed. Check $BACKUP_DIR for your files."
  exit 1
fi

# Option to preview without installing
if [ "$1" = "--dry-run" ]; then
  echo "Files that would be installed:"
  dotfiles ls-files
  exit 0
fi

# Or show diff for files that would be replaced
for file in "${CONFLICTS[@]}"; do
  echo "=== $file ==="
  diff "$HOME/$file" <(dotfiles show HEAD:"$file")
done
