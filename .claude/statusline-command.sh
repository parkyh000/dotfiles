#!/usr/bin/env bash

input=$(cat)

# Model display name
model=$(echo "$input" | jq -r '.model.display_name // "Unknown Model"')

# Current working directory (basename only)
cwd=$(echo "$input" | jq -r '.workspace.current_dir // .cwd // "."')
dir_name=$(basename "$cwd")

# Git info (skip optional locks)
git_branch=$(git -C "$cwd" --no-optional-locks branch --show-current 2>/dev/null)
git_status=""
if [ -n "$git_branch" ]; then
  dirty=$(git -C "$cwd" --no-optional-locks status --porcelain 2>/dev/null)
  if [ -n "$dirty" ]; then
    git_status="dirty"
  else
    git_status="clean"
  fi
fi

# Context usage percentage (pre-calculated)
used_pct=$(echo "$input" | jq -r '.context_window.used_percentage // empty')

# Build progress bar (20 chars wide)
build_bar() {
  local pct="$1"
  local width=20
  local filled=0
  local bar=""

  if [ -n "$pct" ]; then
    filled=$(( (pct * width + 50) / 100 ))
    [ "$filled" -gt "$width" ] && filled=$width
  fi

  local empty=$(( width - filled ))

  # Color: green < 60%, yellow < 80%, red >= 80%
  local color=""
  local reset="\033[0m"
  if [ -n "$pct" ]; then
    if [ "$pct" -ge 80 ]; then
      color="\033[31m"
    elif [ "$pct" -ge 60 ]; then
      color="\033[33m"
    else
      color="\033[32m"
    fi
  else
    color="\033[90m"
  fi

  local i
  for (( i=0; i<filled; i++ )); do bar+="█"; done
  for (( i=0; i<empty;  i++ )); do bar+="░"; done

  printf "${color}[${bar}]${reset}"
}

# Assemble output line
parts=""

# Model name (cyan)
parts+="\033[36m${model}\033[0m"

# Working directory name (white)
parts+="  \033[97m${dir_name}\033[0m"

# Git branch + status (only if inside a repo)
if [ -n "$git_branch" ]; then
  # Branch icon (U+E4E6 nerd font) in yellow
  parts+="  \033[33m\xef\x9c\xa6 ${git_branch}\033[0m"
  # Status: clean=green, dirty=red
  if [ "$git_status" = "clean" ]; then
    parts+=" \033[32mclean\033[0m"
  else
    parts+=" \033[31mdirty\033[0m"
  fi
fi

# Context usage progress bar
bar=$(build_bar "${used_pct}")
if [ -n "$used_pct" ]; then
  pct_display="${used_pct}%"
else
  pct_display="--"
fi
parts+="  ctx $(printf '%s' "$bar") ${pct_display}"

printf "${parts}\n"
