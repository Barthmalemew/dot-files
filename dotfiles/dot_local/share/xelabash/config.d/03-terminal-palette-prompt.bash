# shellcheck shell=bash source="$HOME"

# Keep xelabash prompt accents bound to terminal palette slots 0-15.

__xelabash_reset_prompt() {
  export __xelabash_PS1_last_exit="$?"
  export __xelabash_PS1_prefix=''
  if ! __xelabash_is_apple_terminal; then
    __xelabash_PS1_prefix='\[\e]0;\w\a\]'
  fi
  export __xelabash_PS1_content='\[\e[1;97m\]\w\[\e[0m\]'
  export __xelabash_PS1_suffix=' \$ '
}

__xelabash_add_exit_code_to_prompt() {
  [ "$__xelabash_PS1_last_exit" -ne 0 ] && __xelabash_PS1_suffix="\[\e[31m\]${__xelabash_PS1_suffix}\[\e[0m\]"
}

__xelabash_add_git_to_prompt() {
  local prompt
  local branch
  local status_count

  if [ "$(git rev-parse --is-inside-work-tree 2>/dev/null)" = 'true' ] || [ "$(git rev-parse --is-inside-git-dir 2>/dev/null)" = 'true' ]; then
    branch="$(git rev-parse --abbrev-ref HEAD 2>/dev/null)"
    [ -z "$branch" ] && branch='(no branch)'
    if [ "$(git rev-parse --is-inside-git-dir 2>/dev/null)" != 'true' ]; then
      status_count="$(git status --porcelain | wc -l)"
    fi
  elif [ "$(git rev-parse --is-bare-repository 2>/dev/null)" = 'true' ]; then
    branch='(bare repo)'
  fi

  if [ -n "$branch" ]; then
    if [ "${status_count:-0}" -gt 0 ]; then
      prompt="\[\e[1;33m\]${branch}*\[\e[0m\]"
    else
      prompt="\[\e[36m\]${branch}\[\e[0m\]"
    fi
    __xelabash_PS1_content="${__xelabash_PS1_content:-} ${prompt}"
  fi
}

__xelabash_add_kube_to_prompt() {
  local context
  local namespace
  context="$(kubectl config view -o=jsonpath='{.current-context}')"
  namespace="$(kubectl config view -o=jsonpath="{.contexts[?(@.name==\"${context}\")].context.namespace}")"
  __xelabash_PS1_content="${__xelabash_PS1_content:-} \[\e[34m\]${context}${namespace:+:$namespace}\[\e[0m\]"
}

__xelabash_add_ssh_to_prompt() {
  if [ -n "$SSH_CONNECTION" ]; then
    __xelabash_PS1_prefix='\[\e]0;\u@\h \w\a\]'
    __xelabash_PS1_content="\[\e[2m\]\u@\h\[\e[0m\] ${__xelabash_PS1_content}"
  fi
}
