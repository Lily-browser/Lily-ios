#!/usr/bin/env bash
# Static checks for the iOS sources (the rules in CLAUDE.md). Run by `make lint` and CI.
set -euo pipefail
export PATH="/usr/bin:/bin:/usr/sbin:/sbin"
cd "$(cd "$(dirname "$0")/.." && pwd)"
failures=0
check() { # check "rule" "regex" files...
  local rule="$1" regex="$2"; shift 2
  local hits; hits="$(grep -nE -- "$regex" "$@" 2>/dev/null || true)"
  if [ -n "$hits" ]; then echo "✘ $rule" >&2; printf '%s\n' "$hits" | sed 's/^/    /' >&2; failures=$((failures + 1)); else echo "✔ $rule"; fi
}
SWIFT=(); while IFS= read -r f; do SWIFT+=("$f"); done < <(git ls-files 'Sources/*.swift' 'Tests/*.swift')
CFG=(); while IFS= read -r f; do CFG+=("$f"); done < <(git ls-files 'project.yml' 'Makefile')

check "no print/NSLog/debugPrint/dump (use os.Logger)" '(^|[^.[:alnum:]_])(print|NSLog|debugPrint|dump)\(' "${SWIFT[@]}"
check "no process spawning" '(^|[^.[:alnum:]_])(system|popen|posix_spawn)\(|NSTask|(^|[^.[:alnum:]_])Process\(' "${SWIFT[@]}"
check "no unsafe pointers" 'Unsafe(Mutable)?(Raw)?(Buffer)?Pointer|unsafeBitCast|Unmanaged' "${SWIFT[@]}"
check "no eval/innerHTML/string timers" '\beval\(|innerHTML|setTimeout\("|setInterval\("' "${SWIFT[@]}"
check "no file access from file URLs" 'allowFileAccessFromFileURLs|allowUniversalAccessFromFileURLs' "${SWIFT[@]}"
check "no secrets in UserDefaults" 'UserDefaults.*(password|token|secret|apiKey)' "${SWIFT[@]}"
check "LilyKit pinned by exact tag, never a local path" 'path:[[:space:]]*\.\.|\.package\(path' "${CFG[@]}"
[ "$failures" -eq 0 ] && echo "security-lint: all checks passed" || { echo "security-lint: $failures check(s) failed" >&2; exit 1; }
