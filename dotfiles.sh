# Manage dotfiles with Git bare repo.
typeset -gA _ZZ_DOT
typeset -ga _ZZ_DOT_FOLDERS

_ZZ_DOT=(
  [git]=""       # Git binary, default homebrew install on macOS is /opt/homebrew/bin/git
  [repo]=""      # dotfiles repo, default is $HOME/.dotfiles
  [prefix]=""    # install directory for dotfiles.sh, default is $HOME/.config/dotfiles
  [is_tracked]=0 # current folder tracked(1)/not-tracked(0) status, automatically determined should not be set manually
)

_zz_dot_init() {
  _ZZ_DOT[git]=${_ZZ_DOT[git]:-$(command -v git)} || {
    echo "dotfiles: git not found in PATH" >&2
    return 1
  }

  # shellcheck disable=SC2296,SC2298
  _ZZ_DOT[prefix]="${${(%):-%x}:A:h}"

  _ZZ_DOT[repo]=$(head -n1 "${_ZZ_DOT[prefix]}/repo" 2>/dev/null)
  if [[ -z ${_ZZ_DOT[repo]} ]]; then
    echo "dotfiles: Repo directory not specified in ${_ZZ_DOT[repo]}" >&2
    return 1
  fi

  local config="${_ZZ_DOT[prefix]}/config"
  if [[ ! -f $config ]]; then
    echo "dotfiles: Config file not found at $config" >&2
    return 1
  fi

  if ((!${#_ZZ_DOT_FOLDERS[@]})); then
    _ZZ_DOT_FOLDERS=()
    local line
    while IFS= read -r line; do
      [[ -z $line || $line == \#* ]] && continue
      _ZZ_DOT_FOLDERS+=("${line/#\~/$HOME}")
    done <"$config"
  fi
}

_zz_dot_is_tracked() {
  # Check if PWD is HOME or within DOTFILES_TRACKED_FOLDERS
  if [[ $PWD == "$HOME" ]]; then
    _ZZ_DOT[is_tracked]=1
  else
    _ZZ_DOT[is_tracked]=0
    local folder
    for folder in "${_ZZ_DOT_FOLDERS[@]}"; do
      if [[ $PWD == $folder* ]]; then
        _ZZ_DOT[is_tracked]=1
        break
      fi
    done
  fi
}

_zz_dot_cmd() {
  # Return whether dotfiles or git binary is being used
  if ((_ZZ_DOT[is_tracked])); then
    echo "${_ZZ_DOT[prefix]}/dotfiles.sh"
  elif "${_ZZ_DOT[git]}" rev-parse --git-dir >/dev/null 2>&1; then
    echo "${_ZZ_DOT[git]}"
  else
    echo ""
  fi
}

_zz_dot_status_line() {
  local cmd, branch, porcelain, statusline

  cmd="${_ZZ_DOT[git]}"
  ((_ZZ_DOT[is_tracked])) && cmd+=" --git-dir=$HOME/.dotfiles --work-tree=$HOME"

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
  return 0
}

dotfiles() {
  local tic=$EPOCHREALTIME

  # Initialize on first run or could remove if performance not an issue
  [[ -z ${_ZZ_DOT[git]} ]] && _zz_dot_init

  _zz_dot_is_tracked

  [[ $1 == "git-cmd" ]] && _zz_dot_cmd

  # if ((_ZZ_DOT[is_tracked])); then
  #   DOTFILES_GIT="${_ZZ_DOT[git]} --git-dir=$HOME/.dotfiles --work-tree=$HOME"
  #   if [[ $1 == "status" ]]; then
  #     if [[ $2 == "--porcelain" ]]; then
  #       $DOTFILES_GIT status --porcelain
  #     else
  #       $DOTFILES_GIT "$@"
  #       untracked=$($DOTFILES_GIT ls-files --others --exclude-standard "${_ZZ_DOT_FOLDERS[@]}")
  #       if [[ -n "$untracked" ]]; then
  #         printf "\n%s\n%s\n" "Untracked files in tracked folders:" '(use "git add <file>..." to include in what will be committed)'
  #         echo -e "\033[31m"
  #         # shellcheck disable=SC2001
  #         echo "$untracked" | sed 's/^/\t/'
  #         echo -e "\033[0m"
  #       fi
  #     fi
  #   elif [[ $1 == "clean" ]]; then
  #     $DOTFILES_GIT clean "$@" "${_ZZ_DOT_FOLDERS[@]}"
  #   else
  #     $DOTFILES_GIT "$@"
  #   fi
  # else
  #   $GIT_BINARY "$@"
  # fi
  printf "dotfiles: %.6fs\n" $((EPOCHREALTIME - tic)) >&2
}
