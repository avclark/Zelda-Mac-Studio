# Codex standing instructions — Zelda Mac Studio

## Mission and authority
Read `PRD.md` and `PLAN.md` before coding. Deliver the most complete **working** native SwiftUI Mac app possible with **one autonomous engineering run**. Plan internally, implement sequentially, run tests, diagnose failures, repair them, and continue to the next independent work item without asking for phase-by-phase permission. Prioritize end-to-end working behavior over polish and over speculative integrations.

## Where judgment is yours
Choose sensible architecture, data model, persistence, build system, Swift package layout, error handling, testing fixtures, UI details and implementation ordering. Research upstream APIs/licensing as needed. Update `PLAN.md` to show decisions, progress, actual test evidence and blockers. Make incremental focused commits; keep `README.md` and a short `DECISIONS.md` current. Do not stop at a blocked optional integration; provide a truthful unavailable state and continue building independent work.

## Stop and request authorization only for
- Installing systemwide tools or changing macOS settings/permissions/OS version.
- Deleting, moving, repairing or overwriting pre-existing user data; editing actual game images, saves, keys, firmware, existing emulators or work apps.
- Network uploads/exports of private game material, keys, firmware or saves (these are **not permitted**; do not ask to do them).
- Purchases, legal agreement acceptance, Apple signing credentials, and irreversible external account changes.
- Choosing between genuinely consequential trade-offs not resolvable from the PRD.

Do not upgrade macOS. Do not repair the corrupted TOTK NSP. Do not modify real original save state. Do not assume permission to install Xcode/Homebrew or grant Full Disk Access.

## Development discipline
- Start with a **read-only toolchain audit**, then create project structure, fixtures, working app and tests.
- This inventory was performed on **the same M1 Max MacBook Pro**; do not rerun the full Nintendo content search.
- Build on **Sonoma 14.6.1** if a compatible SwiftUI toolchain is present; report exactly what stops local compilation if not.
- Treat proprietary inputs as **external references**, never repository files. `.gitignore` must exclude NSP/XCI/NSZ, NCA, keys, firmware, real saves, generated apps/build products, portable user libraries and diagnostic dumps with secrets. Verify tracked files before commit and push.
- Prefer SwiftUI, Foundation and testable dependency-injected services. Avoid heavy dependencies when system APIs suffice. If adding third-party code, review licenses, security and pin versions.
- Treat downloaded archives as untrusted. No arbitrary code execution from mods. Bound expansion; reject unsafe traversal and symlinks. Use temporary staging and fail closed.
- Every user-visible action must work or be clearly disabled/marked unavailable; never create success-only mock functionality.
- Never present “mod works” when only an archive import or file deployment succeeded. Track validation/deployment/launch/gameplay verification separately.
- True isolation: clones never share mutable save or deployment directories. Test this.
- Treat native/emulated TOTK as runtime **adapters**. Do not attempt to write an emulator or modify upstream native graphics implementations.
- Preserve source files; backup before any relevant integration. Never rewrite original game content.
- No secrets in terminal output, code comments, logs, test fixtures, screenshots, app state, README, commits or telemetry. Redact private paths in shareable reports.

## Testing / delivery contract
1. Complete highest priority requirements before optional features; use synthetic test data when real TOTK input is unverified.
2. After each coherent feature, compile/test (or explicitly record why unavailable), fix defects, and commit.
3. Never mark a milestone done without evidence in `PLAN.md` (test name/results, build command and relevant behavior).
4. Final delivery must include the app location/build instructions; tests run/passed; exact feature-status matrix (`Working / Partial / Blocked / Untested`); restrictions; and top next steps.
5. It is acceptable to finish with honest blockers, but not acceptable to stop after only a plan or a polished shell. Keep implementing working features while possible.
6. Use supported permissions/approval settings; **do not use unsafe “bypass all prompts” operation modes** merely to achieve autonomy.

## Collaboration style
Default to action. Do not ask for validation of every choice or redesign the PRD unless contradictions are material. Give concise progress updates and a detailed factual final report. If context or time is limited, update `PLAN.md`, commit a clean checkpoint, and state the exact next implementation step.
