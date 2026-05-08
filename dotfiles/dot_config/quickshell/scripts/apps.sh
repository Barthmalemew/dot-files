#!/bin/sh

for dir in \
  /usr/share/applications \
  /usr/local/share/applications \
  "$HOME/.local/share/applications"
do
  [ -d "$dir" ] || continue

  find "$dir" -name '*.desktop' -type f 2>/dev/null
done | while IFS= read -r file; do
  name="$(awk -F= '
    $1 == "Name" {
      print $2
      exit
    }
  ' "$file")"

  exec_cmd="$(awk -F= '
    $1 == "Exec" {
      print $2
      exit
    }
  ' "$file")"

  hidden="$(awk -F= '
    $1 == "NoDisplay" || $1 == "Hidden" {
      if ($2 == "true") print "true"
    }
  ' "$file")"

  [ -n "$name" ] || continue
  [ -n "$exec_cmd" ] || continue
  [ "$hidden" = "true" ] && continue

  exec_cmd="$(printf '%s\n' "$exec_cmd" \
    | sed 's/ *%[fFuUdDnNickvm]//g' \
    | sed 's/ *@@u.*@@//g' \
    | sed 's/ *@@.*@@//g')"

  printf '%s\t%s\n' "$name" "$exec_cmd"
done | sort -u
