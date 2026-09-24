#!/bin/bash
# Marblezzz adaptation of the BillHive pre-ASC gate. Never uploads.
set -uo pipefail
marblezzz_root=$(cd "$(dirname "$0")/../.." && pwd)
cd "$marblezzz_root"
allow_dirty=0
require_key=0
destination="${QA_DESTINATION:-}"
output="${QA_OUTPUT_DIR:-$marblezzz_root/artifacts/pre-asc}"
while [[ $# -gt 0 ]]; do
  case "$1" in
    --allow-dirty) allow_dirty=1 ;;
    --require-asc-key) require_key=1 ;;
    --destination) shift; destination="${1:?Missing destination}" ;;
    --help) printf '%s\n' 'Usage: tools/qa/pre_asc_qa.sh [--require-asc-key] [--allow-dirty] --destination "id=<simulator UDID>"' 'Strict checks: committed clean worktree, credential guard, project/resources/metadata/assets, engine and native tests, unsigned Release build.' 'Set ASC_KEY_PATH for --require-asc-key. --allow-dirty is development-only. Logs go to artifacts/pre-asc.'; exit 0 ;;
    *) printf 'Unknown argument: %s\n' "$1" >&2; exit 2 ;;
  esac
  shift
done
[[ -n "$destination" ]] || { printf '%s\n' 'Set --destination or QA_DESTINATION to an available iOS 27 iPhone simulator.' >&2; exit 2; }
mkdir -p "$output"
failures=0
run_check() {
  local label="$1" log="$2"; shift 2
  printf 'Running %s...\n' "$label"
  if "$@" > "$output/$log" 2>&1; then printf 'PASS: %s\n' "$label"; else printf 'FAIL: %s (see %s)\n' "$label" "$output/$log"; failures=$((failures+1)); fi
}
if ! git rev-parse --verify HEAD >/dev/null 2>&1 || [[ -n "$(git status --porcelain)" ]]; then
  if [[ $allow_dirty -eq 1 ]]; then printf '%s\n' 'WARN: Development run; dirty or uncommitted source cannot be upload-ready.'; else printf '%s\n' 'FAIL: A committed, clean worktree is required.'; failures=$((failures+1)); fi
fi
if [[ $require_key -eq 1 && ! -f "${ASC_KEY_PATH:-}" ]]; then printf '%s\n' 'FAIL: ASC_KEY_PATH is missing or unreadable.'; failures=$((failures+1)); fi
run_check 'Diff whitespace' diff.log git diff --check
run_check 'Static release inputs' static.log python3 tools/qa/static_checks.py
run_check 'Xcode project' project.log xcodebuild -list -project Marblezzz.xcodeproj
run_check 'Rules engine tests' core-tests.log swift test --package-path Packages/MarblezzzCore --scratch-path /tmp/marblezzz-qa-core
run_check 'Native unit and UI tests' native-tests.log xcodebuild -project Marblezzz.xcodeproj -scheme Marblezzz -destination "$destination" -parallel-testing-enabled NO -collect-test-diagnostics never -derivedDataPath /tmp/marblezzz-qa-native CODE_SIGN_IDENTITY=- test
run_check 'Unsigned Release device build' release.log xcodebuild -project Marblezzz.xcodeproj -scheme Marblezzz -configuration Release -destination 'generic/platform=iOS' -derivedDataPath /tmp/marblezzz-qa-release CODE_SIGNING_ALLOWED=NO build
if [[ $failures -gt 0 ]]; then printf '\nFAIL: %s release checks failed.\n' "$failures"; exit 1; fi
if [[ $allow_dirty -eq 1 ]]; then printf '\nDEVELOPMENT CHECKS PASSED; this is not an upload-ready pass.\n'; else printf '\nLOCAL PRE-ASC GATE PASSED. Signed archive validation and real-device/service checks remain separate.\n'; fi
