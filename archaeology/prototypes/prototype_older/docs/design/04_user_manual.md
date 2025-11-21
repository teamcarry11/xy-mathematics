# Grain Documentary Part 4 — User Manual (Grain Conductor)

A hands-on walkthrough of `grain conduct`. We cover installation via the
Brewfile, Ghostty setup, and commands such as `conduct brew`, `conduct
link`, `conduct mmt`, `conduct cdn`, and `conduct ai`. Screenshots are
replaced with precise sequences: run, observe stdout, update Ray, rerun
Matklad tests. Secrets stay outside the repo in the mirrored GrainVault.

Checklist:
- Ensure `CURSOR_API_TOKEN` and `CLAUDE_CODE_API_TOKEN` exported.
- Use `grain conduct ai --tool=cursor --arg="--headless"` to kickstart
  sessions.
- Record every run in `docs/prompts.md` and `docs/outputs.md`.
