---
name: self-review
description: Critically review your recent changes — read the actual code, find problems, report without fixing
allowed-tools: Read, Grep, Glob, Bash(git diff *), Bash(git status *)
---

# Self-Review

Critically review all uncommitted changes. Read every changed file — do not rely on conversation memory.

## Process

1. Run `git diff --name-only` to get the list of changed files
2. For each changed file in `lib/`, read the **full current contents** (not just the diff)
3. For each changed file in `spec/`, read the full current contents

## Checklist

Evaluate every changed file against these categories:

### Correctness
- Do the changes work together coherently, or are there mismatches between callers and callees?
- Are there edge cases that aren't handled (nil, empty, missing keys)?
- Did any behavioral semantics change silently (same method name, different behavior)?

### Stale References
- Comments or YARD docs mentioning removed classes, methods, or parameters
- Require statements for deleted files
- Error classes that nothing raises
- Example code in docs that uses old API

### Dead Code
- Methods, classes, constants, or requires that are no longer called
- Parameters accepted but never used
- Rescue clauses catching errors that can no longer be raised

### Test Coverage
- New public methods without tests
- Valuable test behaviors that were deleted without being migrated
- Tests that pass but no longer test what they claim (e.g., assertion doesn't match description)

### Consistency
- Naming that doesn't match existing conventions in the codebase
- Patterns that differ from how similar things are done elsewhere
- Mixed styles (e.g., some places use hash access, others use method calls for the same thing)

### Code Quality
- Unnecessary complexity or abstraction
- RuboCop disables that could be avoided by refactoring
- Long parameter lists that should be simplified

## Output Format

Present findings as a numbered list grouped by category. For each finding:
- **File and line** (if applicable)
- **What's wrong**
- **Severity**: error (will cause bugs), warning (code smell or inconsistency), note (minor improvement)

If no issues are found in a category, skip it.

**Do not fix anything.** Present the findings and wait for instructions on what to address.
