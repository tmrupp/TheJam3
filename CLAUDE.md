# Somnonaut (TheJam3)

The project's notes for coding agents live in AGENTS.md, shared with other tools. They're imported
here so there is one source to keep up to date:

@AGENTS.md

## Claude Code specifics

- Prefer `bash tests/run.sh <names>` for quick checks and `bash tests/run.sh full` before reporting
  work as done. Window-tier tests only run properly in the full run.
- For art work, capture stills with the matching `tests/capture_*.gd`, then crop and zoom in to
  review them before describing the result.
- When a change shifts level layouts (see "Level generation" above), say so in the report, and
  fix any layout-sensitive tests by making them robust rather than pinning to the new layout.
