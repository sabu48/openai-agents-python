# PR Review Assistant Skill

This skill provides automated pull request review capabilities for the openai-agents-python project. It analyzes code changes, checks for common issues, and provides structured feedback.

## Overview

The PR Review Assistant skill helps maintainers and contributors by:
- Analyzing diffs for potential bugs, style issues, and anti-patterns
- Checking that tests are included for new functionality
- Verifying documentation is updated alongside code changes
- Ensuring consistency with existing code conventions
- Flagging breaking changes that need attention

## Usage

This skill is invoked automatically on pull requests or can be triggered manually.

### Inputs

| Input | Description | Required |
|-------|-------------|----------|
| `pr_number` | The pull request number to review | Yes |
| `repo` | Repository in `owner/repo` format | Yes |
| `focus_areas` | Comma-separated areas to focus on (e.g., `security,performance,tests`) | No |
| `severity_threshold` | Minimum severity to report (`info`, `warning`, `error`) | No (default: `warning`) |

### Outputs

The skill produces a structured review with:
- **Summary**: High-level overview of the changes
- **Issues**: List of identified problems with severity levels
- **Suggestions**: Optional improvements that are not blocking
- **Checklist**: Verification that standard requirements are met

## Review Checklist

The skill automatically verifies:

- [ ] New public APIs have docstrings
- [ ] Type hints are present on function signatures
- [ ] Tests cover new/changed functionality
- [ ] `CHANGELOG` or release notes updated (for significant changes)
- [ ] No hardcoded secrets or credentials
- [ ] Dependencies added to `pyproject.toml` if applicable
- [ ] Breaking changes are clearly documented
- [ ] Examples updated if public interface changed

## Configuration

Create a `.agents/skills/pr-review-assistant/config.yaml` to customize behavior:

```yaml
severity_threshold: warning
focus_areas:
  - correctness
  - tests
  - documentation
ignore_paths:
  - "*.md"
  - "docs/"
max_comments: 20
```

## Agent Integration

See `agents/openai.yaml` for the OpenAI agent configuration used to power this skill.
