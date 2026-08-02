#!/usr/bin/env bash
# PostToolUse: format the .nix file Claude just wrote, report lints back.
# alejandra rewrites in place; statix/deadnix are read-only.
set -uo pipefail
export NO_COLOR=1

f=$(jq -r '.tool_input.file_path // .tool_response.filePath // empty')
case "$f" in
  *.nix) ;;
  *) exit 0 ;;
esac
[ -f "$f" ] || exit 0

for t in alejandra statix deadnix; do
  if ! command -v "$t" >/dev/null; then
    echo "nix-lint hook: $t not on PATH — start Claude inside the devenv shell" >&2
    exit 2
  fi
done

out=$( { alejandra --quiet "$f"; statix check -o errfmt "$f"; deadnix --fail "$f"; } 2>&1 )
if [ -n "$out" ]; then
  printf 'Nix lint findings in %s — fix these:\n%s\n' "$f" "$out" >&2
  exit 2
fi
