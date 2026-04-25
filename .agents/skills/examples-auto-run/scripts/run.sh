#!/usr/bin/env bash
# examples-auto-run/scripts/run.sh
# Automatically discovers and runs all examples in the repository,
# capturing output and reporting pass/fail status for each.

set -euo pipefail

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------
REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
EXAMPLES_DIR="${REPO_ROOT}/examples"
RESULTS_DIR="${REPO_ROOT}/.agents/skills/examples-auto-run/results"
TIMEOUT_SECONDS="${TIMEOUT_SECONDS:-60}"
PYTHON="${PYTHON:-python}"
VENV_DIR="${REPO_ROOT}/.venv"

PASS=0
FAIL=0
SKIP=0
FAILED_EXAMPLES=()

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
log()  { echo "[examples-auto-run] $*"; }
warn() { echo "[examples-auto-run] WARN: $*" >&2; }
err()  { echo "[examples-auto-run] ERROR: $*" >&2; }

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || { err "Required command '$1' not found."; exit 1; }
}

# ---------------------------------------------------------------------------
# Environment setup
# ---------------------------------------------------------------------------
setup_venv() {
  if [[ ! -d "${VENV_DIR}" ]]; then
    log "Creating virtual environment at ${VENV_DIR} ..."
    "${PYTHON}" -m venv "${VENV_DIR}"
  fi

  # shellcheck disable=SC1091
  source "${VENV_DIR}/bin/activate"

  if [[ -f "${REPO_ROOT}/pyproject.toml" ]]; then
    log "Installing package in editable mode ..."
    pip install -q -e "${REPO_ROOT}[examples]" 2>/dev/null \
      || pip install -q -e "${REPO_ROOT}" 2>/dev/null \
      || warn "Could not install package; examples may fail due to missing deps."
  fi
}

# ---------------------------------------------------------------------------
# Example runner
# ---------------------------------------------------------------------------
run_example() {
  local script="$1"
  local rel_path
  rel_path="$(realpath --relative-to="${REPO_ROOT}" "${script}")"
  local result_file="${RESULTS_DIR}/$(echo "${rel_path}" | tr '/' '__').txt"

  mkdir -p "${RESULTS_DIR}"

  # Skip examples that require interactive input or explicit API keys
  if grep -qE '^\s*#\s*skip-auto-run' "${script}" 2>/dev/null; then
    log "SKIP  ${rel_path}  (marked skip-auto-run)"
    SKIP=$((SKIP + 1))
    return
  fi

  log "RUN   ${rel_path}"

  local exit_code=0
  timeout "${TIMEOUT_SECONDS}" "${PYTHON}" "${script}" \
    > "${result_file}" 2>&1 || exit_code=$?

  if [[ ${exit_code} -eq 0 ]]; then
    log "PASS  ${rel_path}"
    PASS=$((PASS + 1))
  elif [[ ${exit_code} -eq 124 ]]; then
    warn "TIMEOUT ${rel_path} (exceeded ${TIMEOUT_SECONDS}s)"
    echo "TIMEOUT after ${TIMEOUT_SECONDS}s" >> "${result_file}"
    FAIL=$((FAIL + 1))
    FAILED_EXAMPLES+=("${rel_path} [TIMEOUT]")
  else
    warn "FAIL  ${rel_path}  (exit ${exit_code})"
    FAIL=$((FAIL + 1))
    FAILED_EXAMPLES+=("${rel_path} [exit ${exit_code}]")
  fi
}

# ---------------------------------------------------------------------------
# Discover examples
# ---------------------------------------------------------------------------
discover_examples() {
  if [[ ! -d "${EXAMPLES_DIR}" ]]; then
    warn "Examples directory not found: ${EXAMPLES_DIR}"
    return
  fi

  # Find all top-level example scripts; prefer files named main.py or the
  # single .py file in a directory to avoid running helper modules.
  while IFS= read -r -d '' script; do
    run_example "${script}"
  done < <(
    find "${EXAMPLES_DIR}" -type f -name '*.py' \
      ! -name '__*' \
      ! -path '*/.*' \
      -print0 | sort -z
  )
}

# ---------------------------------------------------------------------------
# Summary report
# ---------------------------------------------------------------------------
print_summary() {
  echo ""
  echo "======================================="
  echo " Examples Auto-Run Summary"
  echo "======================================="
  echo "  PASS   : ${PASS}"
  echo "  FAIL   : ${FAIL}"
  echo "  SKIP   : ${SKIP}"
  echo "  TOTAL  : $((PASS + FAIL + SKIP))"
  echo "---------------------------------------"

  if [[ ${#FAILED_EXAMPLES[@]} -gt 0 ]]; then
    echo "  Failed examples:"
    for ex in "${FAILED_EXAMPLES[@]}"; do
      echo "    - ${ex}"
    done
  fi

  echo "  Results saved to: ${RESULTS_DIR}"
  echo "======================================="
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
main() {
  require_cmd git
  require_cmd python

  log "Repository root : ${REPO_ROOT}"
  log "Examples dir    : ${EXAMPLES_DIR}"
  log "Timeout         : ${TIMEOUT_SECONDS}s per example"

  setup_venv
  discover_examples
  print_summary

  if [[ ${FAIL} -gt 0 ]]; then
    exit 1
  fi
}

main "$@"
