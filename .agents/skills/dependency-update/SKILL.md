# Dependency Update Skill

This skill automates the process of checking for outdated dependencies, evaluating compatibility, and generating pull requests with safe dependency updates.

## Overview

The dependency update skill monitors project dependencies (Python packages via `pyproject.toml` / `requirements.txt`) and:

1. Identifies outdated packages using `pip list --outdated` or `uv` tooling
2. Evaluates semantic versioning to classify updates (patch / minor / major)
3. Checks changelogs or release notes for breaking changes
4. Runs the existing test suite to validate compatibility
5. Creates a structured summary report of proposed updates
6. Optionally opens a pull request with the changes

## When to Use

- Scheduled maintenance runs (e.g., weekly)
- Before a release to ensure dependencies are current
- After a security advisory is published for a transitive dependency

## Inputs

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `update_type` | string | No | `patch` | Minimum update level: `patch`, `minor`, or `major` |
| `packages` | list | No | all | Specific packages to check; empty means all |
| `dry_run` | bool | No | `true` | If true, report only — do not modify files |
| `create_pr` | bool | No | `false` | Automatically open a GitHub PR with changes |
| `branch_prefix` | string | No | `deps/` | Prefix for the update branch name |

## Outputs

- `report.md` — Markdown summary of checked packages, available updates, and test results
- `pyproject.toml` / `requirements.txt` — Updated dependency files (when `dry_run=false`)
- Pull request URL (when `create_pr=true`)

## Steps

1. **Discover** — Parse `pyproject.toml` and any `requirements*.txt` files to build the current dependency manifest.
2. **Check** — Query PyPI JSON API for the latest available version of each package.
3. **Filter** — Apply `update_type` filter to limit changes to the desired risk level.
4. **Validate** — Run `pytest` (or the project's configured test command) against the proposed versions in an isolated virtual environment.
5. **Report** — Generate `report.md` with a table of results.
6. **Apply** — If `dry_run=false`, write updated version pins back to source files.
7. **PR** — If `create_pr=true`, commit changes to a new branch and open a pull request via the GitHub API.

## Notes

- The skill respects version constraints already present in `pyproject.toml` (e.g., `>=1.0,<2.0`) and will not propose updates that violate them.
- Major version bumps are always flagged for human review even when `update_type=major`.
- Uses `uv` when available for faster resolution; falls back to `pip`.
