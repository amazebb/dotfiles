# Manage dotfiles with Git bare repo.
typeset -gA _ZZ_DOT
typeset -ga _ZZ_DOT_FOLDERS

_ZZ_DOT=(
  [git]=""       # Git binary, default homebrew install on macOS is /opt/homebrew/bin/git
  [repo]=""      # dotfiles repo, default is $HOME/.dotfiles if no $HOME/.config/dotfiles/repo file found
  [is_tracked]=0 # current folder tracked(1)/not-tracked(0) status, automatically determined should not be set manually
)

_zz_dot_init() {
  _ZZ_DOT[git]=${_ZZ_DOT[git]:-$(command -v git)} || {
    echo "dotfiles: git not found in PATH" >&2
    return 1
  }

  local tmp
  tmp=$(head -n1 "$HOME/.config/dotfiles/repo" 2>/dev/null)
  tmp=${tmp/#\~/$HOME}
  tmp="${tmp/\$HOME/$HOME}"
  _ZZ_DOT[repo]=${tmp:-$HOME/.dotfiles}
  if [[ ! -d ${_ZZ_DOT[repo]} ]]; then
    echo "dotfiles: No $HOME/.dotfiles repo found or defined in file $HOME/.config/dotfiles/repo " >&2
    return 1
  fi

  local config="$HOME/.config/dotfiles/config"
  if [[ ! -f $config ]]; then
    echo "dotfiles: Config file not found at $config" >&2
    return 1
  fi

  if ((!${#_ZZ_DOT_FOLDERS[@]})); then
    _ZZ_DOT_FOLDERS=()
    local line
    while IFS= read -r line; do
      [[ -z $line || $line == \#* ]] && continue
      tmp=${line/#\~/$HOME}
      _ZZ_DOT_FOLDERS+=("${tmp/\$HOME/$HOME}")
    done <"$config"
  fi
}

_zz_dot_is_tracked() {
  _ZZ_DOT[is_tracked]=0
  # Check if PWD is parent of repo or within DOTFILES_TRACKED_FOLDERS
  if [[ $PWD == "${_ZZ_DOT[repo]:h}" ]]; then
    _ZZ_DOT[is_tracked]=1
  else
    local folder
    for folder in "${_ZZ_DOT_FOLDERS[@]}"; do
      [[ $PWD == $folder* ]] && _ZZ_DOT[is_tracked]=1 && break
    done
  fi
}

_zz_dot_cmd() {
  # Return whether dotfiles or git binary is being used
  if ((_ZZ_DOT[is_tracked])); then
    ## shellcheck disable=SC2296,SC2298
    # echo "${${(%):-%x}:A}"
    echo "$HOME/.local/share/dotfiles/dotfiles.sh"
  elif "${_ZZ_DOT[git]}" rev-parse --git-dir >/dev/null 2>&1; then
    echo "${_ZZ_DOT[git]}"
  else
    echo ""
  fi
}

_zz_dot_status_line() {
  local cmd, repo, branch, porcelain, statusline

  cmd="${_ZZ_DOT[git]}"
  repo="${_ZZ_DOT[repo]}"
  ((_ZZ_DOT[is_tracked])) && cmd+=" --git-dir=$repo --work-tree=${repo:h}}"

  # Get branch name
  branch=$($cmd rev-parse --abbrev-ref HEAD 2>/dev/null)
  if [[ $branch = "" ]]; then
    return 1
  fi
  # Check git status for changes
  porcelain=$($cmd status --porcelain 2>/dev/null)

  local staged=0
  local untracked=0
  local unstaged=0
  if [[ -n $porcelain ]]; then
    staged=$(echo "$porcelain" | grep -c "^[MTADRC]")
    unstaged=$(echo "$porcelain" | grep -c "^.[MTDRC]")
    untracked=$(echo "$porcelain" | grep -c "^??")
  fi
  local dirty=$((unstaged + staged + untracked))

  # Build VCS string
  statusline="$branch"
  if [[ $dirty -gt 0 ]]; then
    [[ $staged -gt 0 ]] && statusline="${statusline} +$staged"
    [[ $unstaged -gt 0 ]] && statusline="${statusline} ~$unstaged"
    [[ $untracked -gt 0 ]] && statusline="${statusline} ?$untracked"
  fi
  echo "$statusline"
}

_zz_dot_status() {
  if [[ $1 == "--porcelain" ]]; then
    $_DOTFILES_GIT status --porcelain
  else
    $_DOTFILES_GIT "$@"
    local untracked
    untracked=$($_DOTFILES_GIT ls-files --others --exclude-standard "${_ZZ_DOT_FOLDERS[@]}")
    if [[ -n "$untracked" ]]; then
      printf "\n%s\n%s\n" "Untracked files in tracked folders:" '(use "git add <file>..." to include in what will be committed)'
      echo -e "\033[31m"
      # shellcheck disable=SC2001
      echo "$untracked" | sed 's/^/\t/'
      echo -e "\033[0m"
    fi
  fi
}

dotfiles() {
  local tic=$EPOCHREALTIME

  # Initialize on first run or could remove if performance not an issue
  [[ -z ${_ZZ_DOT[git]} ]] && _zz_dot_init
  _zz_dot_is_tracked

  [[ $1 == "git-cmd" ]] && _zz_dot_cmd && return 0

  if ((_ZZ_DOT[is_tracked])); then
    local repo
    repo="${_ZZ_DOT[repo]}"
    _DOTFILES_GIT="${_ZZ_DOT[git]} --git-dir=$repo --work-tree=${repo:h}"
    if [[ $1 == "status" ]]; then
      _zz_dot_status "$2"
    elif [[ $1 == "clean" ]]; then
      $_DOTFILES_GIT clean "$@" "${_ZZ_DOT_FOLDERS[@]}"
    else
      $_DOTFILES_GIT "$@"
    fi
  else
    ${_ZZ_DOT[git]} "$@"
  fi

  printf "dotfiles: %.6fs\n" $((EPOCHREALTIME - tic)) >&2
}
