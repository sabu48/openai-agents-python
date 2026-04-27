#!/usr/bin/env bash
# Dependency Update Skill - Automated dependency version checking and updating
# This script checks for outdated dependencies and creates update PRs

set -euo pipefail

# ─── Configuration ────────────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../../.." && pwd)"
LOG_PREFIX="[dependency-update]"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# ─── Helpers ──────────────────────────────────────────────────────────────────
log_info()  { echo -e "${BLUE}${LOG_PREFIX} INFO:${NC}  $*"; }
log_ok()    { echo -e "${GREEN}${LOG_PREFIX} OK:${NC}    $*"; }
log_warn()  { echo -e "${YELLOW}${LOG_PREFIX} WARN:${NC}  $*"; }
log_error() { echo -e "${RED}${LOG_PREFIX} ERROR:${NC} $*" >&2; }

die() {
  log_error "$*"
  exit 1
}

# ─── Dependency checks ────────────────────────────────────────────────────────
check_required_tools() {
  local missing=()
  for tool in python3 pip git; do
    if ! command -v "$tool" &>/dev/null; then
      missing+=("$tool")
    fi
  done
  if [[ ${#missing[@]} -gt 0 ]]; then
    die "Missing required tools: ${missing[*]}"
  fi
  log_ok "All required tools are available."
}

# ─── Python dependency handling ───────────────────────────────────────────────
check_outdated_python_deps() {
  log_info "Checking for outdated Python dependencies..."

  cd "${REPO_ROOT}"

  if [[ ! -f "pyproject.toml" ]] && [[ ! -f "requirements.txt" ]]; then
    log_warn "No pyproject.toml or requirements.txt found. Skipping Python dep check."
    return 0
  fi

  # Use pip list --outdated to find stale packages
  local outdated
  outdated=$(pip list --outdated --format=json 2>/dev/null || echo "[]")

  local count
  count=$(echo "$outdated" | python3 -c "import sys, json; data=json.load(sys.stdin); print(len(data))" 2>/dev/null || echo "0")

  if [[ "$count" -eq 0 ]]; then
    log_ok "All Python dependencies are up to date."
    return 0
  fi

  log_warn "Found ${count} outdated Python package(s):"
  echo "$outdated" | python3 -c "
import sys, json
data = json.load(sys.stdin)
for pkg in data:
    print(f\"  {pkg['name']:40s} {pkg['version']:15s} -> {pkg['latest_version']}\")
"
  # Export for later use
  OUTDATED_PYTHON_DEPS="$outdated"
  OUTDATED_PYTHON_COUNT="$count"
}

update_python_deps() {
  local target_package="${1:-}"

  cd "${REPO_ROOT}"

  if [[ -n "$target_package" ]]; then
    log_info "Updating Python package: ${target_package}"
    pip install --upgrade "${target_package}"
  else
    log_info "Updating all outdated Python packages..."
    pip list --outdated --format=freeze | grep -v '^\-e' | cut -d = -f 1 | xargs -r pip install --upgrade
  fi

  log_ok "Python dependencies updated."
}

# ─── Git helpers ──────────────────────────────────────────────────────────────
create_update_branch() {
  local branch_name="deps/auto-update-$(date +%Y%m%d-%H%M%S)"
  log_info "Creating branch: ${branch_name}"
  git -C "${REPO_ROOT}" checkout -b "${branch_name}"
  echo "${branch_name}"
}

commit_dependency_changes() {
  local branch_name="$1"

  cd "${REPO_ROOT}"

  if git diff --quiet && git diff --cached --quiet; then
    log_warn "No changes to commit after dependency update."
    return 0
  fi

  git add -A
  git commit -m "chore(deps): automated dependency update $(date +%Y-%m-%d)"
  log_ok "Changes committed on branch '${branch_name}'."
}

# ─── Report generation ────────────────────────────────────────────────────────
generate_report() {
  local report_file="${REPO_ROOT}/dependency-update-report.md"

  log_info "Generating dependency update report at ${report_file}..."

  cat > "${report_file}" << EOF
# Dependency Update Report

Generated: $(date -u +"%Y-%m-%dT%H:%M:%SZ")

## Summary

- **Outdated packages found:** ${OUTDATED_PYTHON_COUNT:-0}

## Outdated Python Packages

| Package | Current | Latest |
|---------|---------|--------|
EOF

  if [[ -n "${OUTDATED_PYTHON_DEPS:-}" ]]; then
    echo "${OUTDATED_PYTHON_DEPS}" | python3 -c "
import sys, json
data = json.load(sys.stdin)
for pkg in data:
    print(f\"| {pkg['name']} | {pkg['version']} | {pkg['latest_version']} |\")
" >> "${report_file}"
  else
    echo "| — | — | — |" >> "${report_file}"
  fi

  log_ok "Report written to ${report_file}."
}

# ─── Main ─────────────────────────────────────────────────────────────────────
main() {
  local mode="${1:-check}"  # check | update | report

  log_info "Starting dependency-update skill (mode: ${mode})"

  check_required_tools

  OUTDATED_PYTHON_DEPS=""
  OUTDATED_PYTHON_COUNT=0

  case "$mode" in
    check)
      check_outdated_python_deps
      ;;
    update)
      check_outdated_python_deps
      if [[ "${OUTDATED_PYTHON_COUNT:-0}" -gt 0 ]]; then
        branch=$(create_update_branch)
        update_python_deps
        commit_dependency_changes "$branch"
        generate_report
      else
        log_ok "Nothing to update."
      fi
      ;;
    report)
      check_outdated_python_deps
      generate_report
      ;;
    *)
      die "Unknown mode '${mode}'. Use: check | update | report"
      ;;
  esac

  log_ok "dependency-update skill finished."
}

main "$@"
