#!/usr/bin/env bash
set -euo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
host=""
host_arg=""
dry_run=0
check=0
install_packages=0
apply_dotfiles=0
apply_portage=0
apply_openrc=0
install_ble_sh=0
install_xelabash=0
fix_machine_id=0

usage() {
  cat <<'EOF'
Usage: ./setup.sh --host HOST [--check] [--dry-run]
                  [--install-packages] [--apply-dotfiles]
                  [--apply-portage] [--apply-openrc]
                  [--install-ble-sh] [--install-xelabash]
                  [--fix-machine-id]

  Default behavior with no action flags is --check.
EOF
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --host)
      host_arg="${2:?--host requires a value}"
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
    --install-xelabash)
      install_xelabash=1
      shift
      ;;
    --fix-machine-id)
      fix_machine_id=1
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

detect_host() {
  local hostname_value product_name product_version product_family sys_vendor
  hostname_value="$(hostname)"
  product_name="$(cat /sys/class/dmi/id/product_name 2>/dev/null || true)"
  product_version="$(cat /sys/class/dmi/id/product_version 2>/dev/null || true)"
  product_family="$(cat /sys/class/dmi/id/product_family 2>/dev/null || true)"
  sys_vendor="$(cat /sys/class/dmi/id/sys_vendor 2>/dev/null || true)"

  case "$sys_vendor:$product_name:$product_version:$product_family" in
    *LENOVO*:ThinkPad\ X9-14\ Gen\ 1*|*Lenovo*:ThinkPad\ X9-14\ Gen\ 1*)
      printf '%s\n' laptop
      ;;
    *)
      printf '%s\n' "$hostname_value"
      ;;
  esac
}

if [ -n "$host_arg" ]; then
  host="$host_arg"
else
  echo "Error: --host is required. Use --host laptop or --host ladmin." >&2
  exit 1
fi

if [ "$check" -eq 0 ] &&
   [ "$install_packages" -eq 0 ] &&
   [ "$apply_dotfiles" -eq 0 ] &&
   [ "$apply_portage" -eq 0 ] &&
   [ "$apply_openrc" -eq 0 ] &&
   [ "$install_ble_sh" -eq 0 ] &&
   [ "$install_xelabash" -eq 0 ]; then
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

dotfile_target_from_rel() {
  local rel="$1"
  rel="${rel//dot_/.}"
  rel="${rel//slash_/\/}"
  printf '%s/%s\n' "$HOME" "$rel"
}

dotfile_sources() {
  local base src rel
  declare -A sources=()

  for base in "$repo_dir/dotfiles" "$repo_dir/hosts/$host/dotfiles"; do
    [ -d "$base" ] || continue
    while IFS= read -r -d '' src; do
      rel="${src#$base/}"
      sources["$rel"]="$src"
    done < <(find "$base" -type f -print0)
  done

  for rel in "${!sources[@]}"; do
    printf '%s\t%s\n' "$rel" "${sources[$rel]}"
  done | sort
}

all_managed_dotfile_rels() {
  local base src rel
  {
    [ -d "$repo_dir/dotfiles" ] && find "$repo_dir/dotfiles" -type f
    [ -d "$repo_dir/hosts" ] && find "$repo_dir/hosts" -path '*/dotfiles/*' -type f
  } | while IFS= read -r src; do
    case "$src" in
      "$repo_dir/dotfiles/"*)
        base="$repo_dir/dotfiles"
        ;;
      "$repo_dir/hosts/"*"/dotfiles/"*)
        base="${src%%/dotfiles/*}/dotfiles"
        ;;
      *)
        continue
        ;;
    esac
    rel="${src#$base/}"
    printf '%s\n' "$rel"
  done | sort -u
}

target_is_repo_symlink() {
  local target="$1" link resolved
  [ -L "$target" ] || return 1
  link="$(readlink "$target")"
  resolved="$(readlink -f "$target" 2>/dev/null || true)"
  case "$link" in
    "$repo_dir"|"$repo_dir"/*)
      return 0
      ;;
  esac
  case "$resolved" in
    "$repo_dir"|"$repo_dir"/*)
      return 0
      ;;
  esac
  return 1
}

backup_target() {
  local target="$1"
  mkdir -p "$backup_dir/$(dirname "${target#$HOME/}")"
  cp -a "$target" "$backup_dir/${target#$HOME/}"
}

show_dotfile_plan() {
  local rel src target desired_rels stale
  declare -A desired=()

  echo "Dotfile changes for host '$host':"
  while IFS=$'\t' read -r rel src; do
    desired["$rel"]=1
    target="$(dotfile_target_from_rel "$rel")"
    if target_is_repo_symlink "$target"; then
      echo "  replace   $target"
    elif [ -e "$target" ]; then
      if cmp -s "$src" "$target"; then
        echo "  unchanged $target"
      else
        echo "  replace   $target"
        diff -u "$target" "$src" || true
      fi
    else
      echo "  copy      $target"
    fi
  done < <(dotfile_sources)

  while IFS= read -r stale; do
    [ -n "$stale" ] || continue
    [ -n "${desired[$stale]:-}" ] && continue
    target="$(dotfile_target_from_rel "$stale")"
    if target_is_repo_symlink "$target"; then
      echo "  remove    $target"
    fi
  done < <(all_managed_dotfile_rels)
}

run_dotfile_step() {
  local rel src target stale
  declare -A desired=()

  show_dotfile_plan
  if [ "$dry_run" -eq 1 ]; then
    return
  fi

  backup_dir="$HOME/.local/state/dot-files/backups/$(date +%Y%m%d-%H%M%S)"
  while IFS=$'\t' read -r rel src; do
    desired["$rel"]=1
    target="$(dotfile_target_from_rel "$rel")"
    mkdir -p "$(dirname "$target")"
    if [ -e "$target" ] && ! target_is_repo_symlink "$target" && cmp -s "$src" "$target"; then
      continue
    fi
    if [ -e "$target" ] || [ -L "$target" ]; then
      backup_target "$target"
      rm -f "$target"
    fi
    cp -a "$src" "$target"
  done < <(dotfile_sources)

  while IFS= read -r stale; do
    [ -n "$stale" ] || continue
    [ -n "${desired[$stale]:-}" ] && continue
    target="$(dotfile_target_from_rel "$stale")"
    if target_is_repo_symlink "$target"; then
      backup_target "$target"
      rm -f "$target"
    fi
  done < <(all_managed_dotfile_rels)
  echo "Backups, if any, are in $backup_dir"
}

run_xelabash_step() {
  local target="$HOME/.local/share/xelabash"
  local repo_url="https://github.com/aelindeman/xelabash.git"

  if [ -d "$target/.git" ]; then
    echo "xelabash already installed at $target"
    return
  fi

  if [ "$dry_run" -eq 1 ]; then
    echo "Would install xelabash to $target"
    return
  fi

  command -v git >/dev/null || { echo "git is required to install xelabash" >&2; exit 1; }

  local work_dir
  work_dir="$(mktemp -d)"
  trap "rm -rf '$work_dir'" EXIT

  git clone --depth 1 "$repo_url" "$work_dir/xelabash"
  mkdir -p "$target"
  find "$work_dir/xelabash" -not -path '*/.git*' -type f | while IFS= read -r f; do
    rel="${f#$work_dir/xelabash/}"
    if [ ! -e "$target/$rel" ]; then
      mkdir -p "$(dirname "$target/$rel")"
      cp "$f" "$target/$rel"
    fi
  done
  cp -r "$work_dir/xelabash/.git" "$target/.git"
  echo "Installed xelabash to $target"
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

  install_host_file "$repo_dir/portage/hosts/$host/make.conf" /etc/portage/make.conf 644
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
  local disabled_services_file="$repo_dir/openrc/hosts/$host/services.disabled.txt"
  need_host_file "$services_file"

  echo "OpenRC service changes for host '$host':"
  if [ -d "$repo_dir/openrc/common/sbin" ]; then
    find "$repo_dir/openrc/common/sbin" -type f | sort | while IFS= read -r src; do
      install_host_file "$src" "/usr/local/sbin/${src##*/}" 755
    done
  fi
  if [ -d "$repo_dir/openrc/common/polkit-1/actions" ]; then
    find "$repo_dir/openrc/common/polkit-1/actions" -type f | sort | while IFS= read -r src; do
      install_host_file "$src" "/usr/share/polkit-1/actions/${src##*/}" 644
    done
  fi
  if [ -d "$repo_dir/openrc/common/polkit-1/rules.d" ]; then
    find "$repo_dir/openrc/common/polkit-1/rules.d" -type f | sort | while IFS= read -r src; do
      install_host_file "$src" "/etc/polkit-1/rules.d/${src##*/}" 644
    done
  fi
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
  if [ -d "$repo_dir/openrc/hosts/$host/sbin" ]; then
    find "$repo_dir/openrc/hosts/$host/sbin" -type f | sort | while IFS= read -r src; do
      install_host_file "$src" "/usr/local/sbin/${src##*/}" 755
    done
  fi
  if [ -d "$repo_dir/openrc/hosts/$host/polkit-1/actions" ]; then
    find "$repo_dir/openrc/hosts/$host/polkit-1/actions" -type f | sort | while IFS= read -r src; do
      install_host_file "$src" "/usr/share/polkit-1/actions/${src##*/}" 644
    done
  fi
  if [ -d "$repo_dir/openrc/hosts/$host/elogind/logind.conf.d" ]; then
    find "$repo_dir/openrc/hosts/$host/elogind/logind.conf.d" -type f | sort | while IFS= read -r src; do
      install_host_file "$src" "/etc/elogind/logind.conf.d/${src##*/}" 644
    done
  fi
  if [ -d "$repo_dir/openrc/hosts/$host/elogind/system-sleep" ]; then
    find "$repo_dir/openrc/hosts/$host/elogind/system-sleep" -type f | sort | while IFS= read -r src; do
      install_host_file "$src" "/etc/elogind/system-sleep/${src##*/}" 755
    done
  fi
  if [ -d "$repo_dir/dracut/common" ]; then
    find "$repo_dir/dracut/common" -type f | sort | while IFS= read -r src; do
      install_host_file "$src" "/etc/dracut.conf.d/${src##*/}" 644
    done
  fi
  if [ -d "$repo_dir/dracut/hosts/$host" ]; then
    find "$repo_dir/dracut/hosts/$host" -type f | sort | while IFS= read -r src; do
      install_host_file "$src" "/etc/dracut.conf.d/${src##*/}" 644
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

  if [ -f "$disabled_services_file" ]; then
    while read -r service runlevel; do
      [ -z "${service:-}" ] && continue
      case "$service" in \#*) continue ;; esac
      if [ -z "${runlevel:-}" ] || [ "$runlevel" = "|" ]; then
        echo "  skipping malformed disabled service line: $service ${runlevel:-}" >&2
        continue
      fi
      if rc-update show "$runlevel" | awk '{print $1}' | grep -qx "$service"; then
        if [ "$dry_run" -eq 1 ]; then
          echo "  would remove $service $runlevel"
        else
          rc-update del "$service" "$runlevel"
        fi
      else
        echo "  absent $service $runlevel"
      fi
    done < "$disabled_services_file"
  fi
}

check_machine_id() {
  local id
  id="$(cat /etc/machine-id 2>/dev/null || true)"
  if [ -z "$id" ] || [ "${#id}" -ne 32 ]; then
    echo "WARNING: /etc/machine-id is missing or invalid."
    echo "  Fix: sudo ./setup.sh --host $host --fix-machine-id"
  else
    echo "machine-id: $id (ok)"
  fi
}

run_fix_machine_id_step() {
  need_root_for_apply "fix-machine-id"
  local new_id
  new_id="$(uuidgen | tr -d '-')"
  printf '%s\n' "$new_id" > /etc/machine-id
  chmod 444 /etc/machine-id
  echo "machine-id set to $new_id"
}

if [ "$check" -eq 1 ]; then
  check_machine_id
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

if [ "$install_xelabash" -eq 1 ]; then
  run_xelabash_step
fi

if [ "$fix_machine_id" -eq 1 ]; then
  run_fix_machine_id_step
fi
