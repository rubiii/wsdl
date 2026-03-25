---
name: commit
description: Analyze changes, stage files, and provide a commit message — never run git commit
allowed-tools: Read, Write, Bash(git diff *), Bash(git status *), Bash(git log *), Bash(git add *), Bash(.claude/scripts/*)
---

# Commit

Analyze the current changes and produce a commit message. Stage the relevant files but NEVER run `git commit` — the user reviews and commits themselves.

## Process

1. Run `git status`, `git diff --cached`, and `git diff` as separate parallel calls to understand what changed
2. If the diff is large or touches multiple files, read the changed files for full context
3. Run `git log --oneline -10` to see recent message style for continuity
4. Stage the relevant files with `git add` (specific files, never `-A` or `.`)
5. Output the commit message as a copyable text block

## Message Format

### Subject line (required)

- Imperative mood — describe what the commit does when applied
- Capitalized first word, no trailing period
- 72 characters max (aim for ~50)
- Pick the verb that matches the nature of the change:
  - **Add** — new feature or capability that didn't exist before
  - **Support** — extend existing feature to handle new cases
  - **Fix** — correct a bug or broken behavior
  - **Remove** / **Drop** — delete functionality or dependencies
  - **Update** / **Improve** — enhance existing behavior
  - **Extract** / **Refactor** — restructure without behavior change
  - **Enforce** — add a constraint, validation, or stricter rule
  - **Cleanup** — remove dead code, tidy up leftovers
  - **Rename** — change names without changing behavior

### Body (optional, separated by blank line)

- Explain **what** changed and **why**, not how
- Wrap at 72 characters
- Use `*` bullet lists for multi-faceted changes
- Skip the body for self-explanatory single-purpose commits

### What makes a good message

- A reader should understand the **purpose** of the change from the subject alone
- The body adds context that isn't obvious from the diff (motivation, trade-offs, what was considered and rejected)
- Avoid repeating information that's clear from the code itself
- Don't reference conversation context — the message must stand on its own in `git log`

### Examples

Single-line (small, focused change):

```
Remove strict: parameter from Schema::Node
```

```
Fix namespace resolution for imported XSD types
```

With body (larger or non-obvious change):

```
Add Definition IR with issues pipeline and best-effort building

Introduces WSDL::Definition as a frozen, serializable intermediate
representation. The build pipeline uses an issues collector instead
of exceptions for error reporting — components always operate
best-effort, recording problems and returning partial results.
```

```
Cleanup leftovers from lenient migration

* Removes dead fetch_* methods from Schema::Collection
* Removes strict: parameter from Schema::Node
```

## Output

1. Output the commit message as plain text (for the user to review)
2. Write the message to `/tmp/commit_msg.txt` using the **Write** tool (never Bash)
3. Run `.claude/scripts/clipboard.sh /tmp/commit_msg.txt` to copy it to the clipboard

Then confirm to the user that the message is on their clipboard.
