# AGENTS.md

## Style

Keep everything short — replies, explanations, comments, docs.

## Commits

- English only.
- Conventional Commits prefix: `feat:`, `fix:`, `chore:`, `docs:`, `refactor:`, `ci:`, `build:`.
- Subject as short as possible. Imperative, lowercase, no trailing period.
- Body only when something genuinely cannot be inferred from the diff.
- Never add `Co-Authored-By`, "Generated with" or any other AI attribution to commits or PR descriptions.
- Exception: the commits in `build/upstream` that `patches/` is exported from. Their subjects become the patch file names, so they stay plain and descriptive.
