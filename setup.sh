#!/usr/bin/env bash
set -euo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
host="$(hostname)"
dry_run=0
check=0
install_packages=0
apply_dotfiles=0
apply_portage=0
apply_openrc=0
install_ble_sh=0

usage() {
  cat <<'EOF'
Usage: ./setup.sh [--host HOST] [--check] [--dry-run]
                  [--install-packages] [--apply-dotfiles]
                  [--apply-portage] [--apply-openrc]
                  [--install-ble-sh]

Default behavior with no action flags is --check.
EOF
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --host)
      host="${2:?--host requires a value}"
      shift 2
      ;;
    --check)
      check=1
      shift
      ;;
    --dry-run)
      dry_run=1
      shift
      ;;
    --install-packages)
      install_packages=1
      shift
      ;;
    --apply-dotfiles)
      apply_dotfiles=1
      shift
      ;;
    --apply-portage)
      apply_portage=1
      shift
      ;;
    --apply-openrc)
      apply_openrc=1
      shift
      ;;
    --install-ble-sh)
      install_ble_sh=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

if [ "$check" -eq 0 ] &&
   [ "$install_packages" -eq 0 ] &&
   [ "$apply_dotfiles" -eq 0 ] &&
   [ "$apply_portage" -eq 0 ] &&
   [ "$apply_openrc" -eq 0 ] &&
   [ "$install_ble_sh" -eq 0 ]; then
  check=1
fi

need_host_file() {
  local path="$1"
  if [ ! -e "$path" ]; then
    echo "Missing host file: $path" >&2
    exit 1
  fi
}

need_root_for_apply() {
  local action="$1"
  if [ "$dry_run" -eq 0 ] && [ "$(id -u)" -ne 0 ]; then
    echo "$action requires root. Re-run as root, or add --dry-run to preview." >&2
    exit 1
  fi
}

package_files() {
  [ -s "$repo_dir/packages/common.txt" ] && printf '%s\n' "$repo_dir/packages/common.txt"
  [ -s "$repo_dir/packages/$host.txt" ] && printf '%s\n' "$repo_dir/packages/$host.txt"
  return 0
}

package_atoms() {
  package_files | while IFS= read -r file; do
    sed -e 's/#.*//' -e '/^[[:space:]]*$/d' "$file"
  done | sort -u
}

print_packages() {
  echo "Package atoms for host '$host':"
  package_atoms | sed 's/^/  /'
}

run_package_step() {
  local atoms
  atoms="$(package_atoms | tr '\n' ' ')"
  if [ -z "$atoms" ]; then
    echo "No package atoms found for host '$host'."
    return
  fi

  if [ "$dry_run" -eq 1 ]; then
    echo "Would run:"
    echo "  emerge --pretend --verbose --noreplace $atoms"
    emerge --pretend --verbose --noreplace $atoms
  else
    need_root_for_apply "Package install"
    echo "Running package install for host '$host'."
    emerge --ask --verbose --noreplace $atoms
  fi
}

dotfile_target() {
  local src="$1"
  local rel="${src#$repo_dir/dotfiles/}"
  rel="${rel//dot_/.}"
  rel="${rel//slash_/\/}"
  printf '%s/%s\n' "$HOME" "$rel"
}

dotfile_sources() {
  find "$repo_dir/dotfiles" -type f | sort
}

show_dotfile_plan() {
  echo "Dotfile changes for host '$host':"
  dotfile_sources | while IFS= read -r src; do
    target="$(dotfile_target "$src")"
    if [ -L "$target" ] && [ "$(readlink "$target")" = "$src" ]; then
      echo "  linked    $target -> $src"
    elif [ -e "$target" ]; then
      if cmp -s "$src" "$target"; then
        echo "  relink    $target"
      else
        echo "  differs   $target"
        diff -u "$target" "$src" || true
      fi
    else
      echo "  link      $target -> $src"
    fi
  done
}

run_dotfile_step() {
  show_dotfile_plan
  if [ "$dry_run" -eq 1 ]; then
    return
  fi

  backup_dir="$HOME/.local/state/dot-files/backups/$(date +%Y%m%d-%H%M%S)"
  dotfile_sources | while IFS= read -r src; do
    target="$(dotfile_target "$src")"
    if [ -L "$target" ] && [ "$(readlink "$target")" = "$src" ]; then
      continue
    fi
    mkdir -p "$(dirname "$target")"
    if [ -e "$target" ] || [ -L "$target" ]; then
      mkdir -p "$backup_dir/$(dirname "${target#$HOME/}")"
      cp -a "$target" "$backup_dir/${target#$HOME/}"
      rm -f "$target"
    fi
    ln -s "$src" "$target"
  done
  echo "Backups, if any, are in $backup_dir"
}

run_ble_sh_step() {
  local target="$HOME/.local/share/blesh/ble.sh"
  local repo_url="https://github.com/akinomyoga/ble.sh.git"

  if [ -r "$target" ]; then
    echo "ble.sh already installed at $target"
    return
  fi

  if [ "$dry_run" -eq 1 ]; then
    echo "Would install ble.sh to $target"
    echo "Would run:"
    echo "  git clone --recursive --depth 1 --shallow-submodules $repo_url TMPDIR/ble.sh"
    echo "  make -C TMPDIR/ble.sh install PREFIX=$HOME/.local"
    return
  fi

  command -v git >/dev/null || { echo "git is required to install ble.sh" >&2; exit 1; }
  command -v make >/dev/null || { echo "make is required to install ble.sh" >&2; exit 1; }

  local work_dir
  work_dir="$(mktemp -d)"
  trap "rm -rf '$work_dir'" EXIT

  git clone --recursive --depth 1 --shallow-submodules "$repo_url" "$work_dir/ble.sh"
  make -C "$work_dir/ble.sh" install PREFIX="$HOME/.local"
  echo "Installed ble.sh to $target"
}

copy_tree() {
  local src="$1"
  local dest="$2"
  if [ ! -e "$src" ]; then
    return
  fi
  if [ "$dry_run" -eq 1 ]; then
    echo "Would copy $src to $dest"
    find "$src" -type f | sort | while IFS= read -r file; do
      local rel="${file#$src/}"
      local target="$dest/$rel"
      if [ -e "$target" ]; then
        diff -u "$target" "$file" || true
      else
        diff -u /dev/null "$file" || true
      fi
    done
  else
    mkdir -p "$dest"
    cp -a "$src"/. "$dest"/
  fi
}

run_portage_step() {
  need_root_for_apply "Portage apply"
  echo "Portage changes for host '$host':"
  copy_tree "$repo_dir/portage/common/package.use" /etc/portage/package.use
  copy_tree "$repo_dir/portage/common/package.accept_keywords" /etc/portage/package.accept_keywords
  copy_tree "$repo_dir/portage/common/package.license" /etc/portage/package.license
  copy_tree "$repo_dir/portage/common/repos.conf" /etc/portage/repos.conf
  copy_tree "$repo_dir/portage/common/binrepos.conf" /etc/portage/binrepos.conf
  copy_tree "$repo_dir/portage/common/env" /etc/portage/env
  copy_tree "$repo_dir/portage/hosts/$host/package.use" /etc/portage/package.use
  copy_tree "$repo_dir/portage/hosts/$host/package.accept_keywords" /etc/portage/package.accept_keywords
  copy_tree "$repo_dir/portage/hosts/$host/package.license" /etc/portage/package.license
  copy_tree "$repo_dir/portage/hosts/$host/repos.conf" /etc/portage/repos.conf
  copy_tree "$repo_dir/portage/hosts/$host/binrepos.conf" /etc/portage/binrepos.conf
  copy_tree "$repo_dir/portage/hosts/$host/env" /etc/portage/env

  if [ -f "$repo_dir/portage/common/package.env" ]; then
    if [ "$dry_run" -eq 1 ]; then
      echo "Would copy portage/common/package.env to /etc/portage/package.env"
      diff -u /etc/portage/package.env "$repo_dir/portage/common/package.env" || true
    else
      cp -a "$repo_dir/portage/common/package.env" /etc/portage/package.env
    fi
  fi

  if [ -f "$repo_dir/portage/hosts/$host/package.env" ]; then
    if [ "$dry_run" -eq 1 ]; then
      echo "Would copy portage/hosts/$host/package.env to /etc/portage/package.env"
      diff -u /etc/portage/package.env "$repo_dir/portage/hosts/$host/package.env" || true
    else
      cp -a "$repo_dir/portage/hosts/$host/package.env" /etc/portage/package.env
    fi
  fi
}

install_host_file() {
  local src="$1"
  local dest="$2"
  local mode="$3"
  if [ ! -e "$src" ]; then
    return
  fi
  if [ "$dry_run" -eq 1 ]; then
    echo "Would install $src to $dest mode $mode"
    if [ -e "$dest" ]; then
      diff -u "$dest" "$src" || true
    else
      diff -u /dev/null "$src" || true
    fi
  else
    install -D -m "$mode" "$src" "$dest"
  fi
}

run_openrc_step() {
  need_root_for_apply "OpenRC apply"
  local services_file="$repo_dir/openrc/hosts/$host/services.txt"
  need_host_file "$services_file"

  echo "OpenRC service changes for host '$host':"
  if [ -d "$repo_dir/openrc/hosts/$host/init.d" ]; then
    find "$repo_dir/openrc/hosts/$host/init.d" -type f | sort | while IFS= read -r src; do
      install_host_file "$src" "/etc/init.d/${src##*/}" 755
    done
  fi
  if [ -d "$repo_dir/openrc/hosts/$host/conf.d" ]; then
    find "$repo_dir/openrc/hosts/$host/conf.d" -type f | sort | while IFS= read -r src; do
      install_host_file "$src" "/etc/conf.d/${src##*/}" 644
    done
  fi
  if [ -d "$repo_dir/hosts/$host/greetd" ]; then
    find "$repo_dir/hosts/$host/greetd" -type f | sort | while IFS= read -r src; do
      install_host_file "$src" "/etc/greetd/${src##*/}" 644
    done
  fi

  while read -r service runlevel; do
    [ -z "${service:-}" ] && continue
    case "$service" in \#*) continue ;; esac
    if [ -z "${runlevel:-}" ] || [ "$runlevel" = "|" ]; then
      echo "  skipping malformed service line: $service ${runlevel:-}" >&2
      continue
    fi
    if rc-update show "$runlevel" | awk '{print $1}' | grep -qx "$service"; then
      echo "  present $service $runlevel"
    elif [ "$dry_run" -eq 1 ]; then
      echo "  would add $service $runlevel"
    else
      rc-update add "$service" "$runlevel"
    fi
  done < "$services_file"
}

if [ "$check" -eq 1 ]; then
  print_packages
  show_dotfile_plan
  previous_dry_run="$dry_run"
  dry_run=1
  run_portage_step
  run_openrc_step
  dry_run="$previous_dry_run"
fi

if [ "$install_packages" -eq 1 ]; then
  run_package_step
fi

if [ "$apply_dotfiles" -eq 1 ]; then
  run_dotfile_step
fi

if [ "$apply_portage" -eq 1 ]; then
  run_portage_step
fi

if [ "$apply_openrc" -eq 1 ]; then
  run_openrc_step
fi

if [ "$install_ble_sh" -eq 1 ]; then
  run_ble_sh_step
fi
