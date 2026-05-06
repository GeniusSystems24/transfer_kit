<!--
SYNC IMPACT REPORT
==================
Version change: (uninitialized template) → 1.0.0
Bump rationale: Initial ratification. The previous file held only placeholder
tokens ([PROJECT_NAME], [PRINCIPLE_1_NAME], …). This commit replaces the
template with concrete principles sourced from `.prompts/constitution.md`.
Treated as a single MAJOR step from "no constitution" to "v1.0.0".

Modified principles:
- (none renamed; all 12 principles introduced for the first time)

Added sections:
- Library Identity
- Library Boundary
- Core Principles (I–XII)
- Development Workflow & Quality Gates
- Maintenance & Quality Improvement Cycle
- Governance

Removed sections:
- All `[PLACEHOLDER]` tokens from the template

Templates requiring updates:
- ✅ .specify/templates/plan-template.md — `Constitution Check` section uses a
  runtime-derived gate placeholder; no edits required at constitution time.
- ✅ .specify/templates/spec-template.md — no constitution-driven mandatory
  sections to add or remove.
- ⚠ .specify/templates/tasks-template.md — tasks template treats tests as
  OPTIONAL, while Principle XI ("Testing Requirements") makes regression
  tests MANDATORY for any behavioral fix in TransferKit. Address when
  generating tasks via `/speckit.tasks`: emit test tasks as required, not
  optional, for behavioral changes touching transfer lifecycle, cache,
  streams, or batch operations.
- ✅ .specify/templates/checklist-template.md — no constitution-driven
  changes required.
- ⚠ README.md / CHANGELOG.md — when public behavior changes, these MUST be
  updated per Principle XII. No edits required at this commit.

Follow-up TODOs:
- (none — RATIFICATION_DATE set to today since no prior adoption date exists)
-->

# TransferKit Constitution

TransferKit is a Flutter/Dart package that provides reusable file transfer
infrastructure for Flutter applications. It manages file uploads, downloads,
caching, progress tracking, transfer task state, batch operations, stream
sharing, metadata extraction, and reusable UI widgets.

TransferKit is **not** a single application feature. It is a reusable package
that other Flutter applications depend on. Therefore stability, predictable
behavior, API consistency, testability, and clear documentation are more
important than rapid feature additions.

## Library Identity

TransferKit is a production-oriented Flutter file transfer toolkit. Its
responsibilities are:

1. Upload files to Firebase Storage.
2. Download files from Firebase Storage or supported file URLs.
3. Track transfer progress in real time.
4. Manage transfer lifecycle states: waiting, running, paused, completed,
   error, cancelled, cached.
5. Provide task control operations: start, pause, resume, cancel, retry,
   remove.
6. Support single-file and multi-file transfers.
7. Support grouped transfer operations.
8. Avoid duplicated transfer listeners through stream sharing.
9. Cache downloaded files locally to avoid redundant downloads.
10. Persist task state so transfers can be restored or inspected after app
    restart.
11. Extract and store file/media metadata when enabled.
12. Provide reusable Flutter widgets for common file loading, uploading,
    downloading, and media-preview use cases.

## Library Boundary

TransferKit **owns**:

- File transfer orchestration
- Transfer task models and lifecycle
- Local task persistence
- Local file caching
- Progress streams and stream sharing
- Firebase Storage integration
- Metadata extraction
- Reusable file/media widgets

TransferKit **does not own**:

- Business-specific application logic
- User authentication flows
- Application-specific Firestore document schemas
- Backend authorization policies
- Domain-specific file ownership rules
- Chat, invoice, club, or accounting workflows
- Permanent backend database state outside the file transfer domain

Any feature added to TransferKit MUST remain generic, reusable, and
package-level. Application-specific behavior MUST be implemented outside the
package or injected through clear interfaces.

## Core Principles

### I. Public Package Stability

TransferKit is a reusable package, so public API stability is mandatory.

Rules:

- Public classes, methods, enums, and parameters MUST NOT be renamed unless
  explicitly required.
- Public APIs MUST NOT be removed without a migration path.
- Existing behavior MUST NOT change silently.
- Any breaking change MUST include: a clear explanation, a migration guide,
  a README update, a CHANGELOG entry, and a versioning decision.

**Rationale**: Downstream Flutter applications depend on stable signatures
and predictable behavior. Silent changes break consumers and erode trust.

### II. Correct Transfer Lifecycle

Every transfer task MUST follow a predictable lifecycle.

Allowed states: `waiting`, `running`, `paused`, `completed`, `error`,
`cancelled`, `cached`.

Rules:

- `start`, `pause`, `resume`, `cancel`, and `retry` MUST have separate,
  distinct meanings.
- `retry` MUST NOT be treated as a simple `start` unless the task is safely
  reset or recreated.
- Completed tasks MUST NOT return to `running` unless a new explicit task is
  created.
- Cancelled tasks MUST NOT resume accidentally.
- A task in the `cached` state MUST represent a real file that exists
  locally.
- Group operations MUST call the correct lifecycle operation for every task.

**Rationale**: Lifecycle errors silently corrupt batch behavior, break UI
state, and cause duplicate work. Distinct semantics are non-negotiable.

### III. Single Source of Truth for Task State

Task state MUST be managed consistently through the task repository / service
layer.

Rules:

- UI widgets MUST observe task streams.
- UI widgets MUST NOT directly mutate task internals.
- Firebase Storage events MUST update the same task model used elsewhere in
  the package.
- Background transfer events MUST update the same task model.
- Cache hits MUST update task state consistently.
- Duplicate representations of the same logical transfer MUST be avoided.

**Rationale**: Divergent state is the root cause of "stuck" tasks, ghost
progress, and inconsistent UI. One model, one source.

### IV. Stream Sharing and Resource Safety

TransferKit MUST prevent duplicated Firebase listeners when multiple widgets
request the same transfer.

Rules:

- Multiple subscribers for the same logical transfer SHOULD share one
  underlying stream where possible.
- Stream controllers MUST NOT receive events after being closed.
- Stream subscriptions MUST be cancelled during cleanup.
- Reference counting MUST be safe under concurrent subscribe/unsubscribe.
- Cleanup delay MUST NOT close streams that still have active subscribers.
- Completed, failed, or cancelled transfers MUST release their resources
  safely.

**Rationale**: Stream/listener leaks cause memory growth, duplicated network
traffic, and "events after close" crashes that are hard to reproduce.

### V. Cache Correctness

The local cache MUST be accurate and verifiable.

Rules:

- A file is considered cached only if the local file actually exists.
- Cache metadata MUST NOT claim success when the file is missing.
- Cache paths MUST be deterministic and safe (no path traversal).
- Cache deletion MUST only remove local files, never remote files.
- Cache expiration and max-size policies MUST be enforced or clearly
  documented as not implemented.
- Cache behavior MUST be tested for hit, miss, stale-file, deleted-file, and
  cleanup cases.

**Rationale**: A "cached but missing" state is a silent data-loss bug for
the consuming app and corrupts UI assumptions about availability.

### VI. Firebase Storage Integration Boundary

Firebase Storage is the current primary transfer provider.

Rules:

- Firebase-specific code MUST remain isolated from generic models where
  practical.
- Public models SHOULD NOT become unnecessarily coupled to Firebase
  internals.
- If future provider support is added, it MUST be introduced through clear
  abstractions.
- Firebase errors MUST be mapped into typed TransferKit exceptions.

**Rationale**: Today the package targets Firebase, but a clean boundary
keeps the door open for additional providers without API churn.

### VII. Background Transfer Honesty

Background transfer support MUST be truthful, tested, and platform-aware.

Rules:

- If transfers continue in the background, the behavior MUST be implemented
  and tested.
- If background behavior is limited by platform or Firebase SDK behavior,
  those limits MUST be documented clearly.
- Android and iOS differences MUST be documented.
- App restart recovery behavior MUST be defined.
- README claims about background transfers MUST match actual code behavior.

**Rationale**: "Works in background" is a high-stakes promise; mismatch
between docs and reality erodes trust and causes production bugs.

### VIII. Metadata Extraction Safety

Metadata extraction MUST be optional, predictable, and safe for large files.

Rules:

- Metadata extraction MUST respect `TransferKitConfig` flags.
- Expensive operations (SHA-256 hashing, thumbnail generation, waveform
  extraction, PDF rendering) MUST NOT run unless explicitly enabled.
- Metadata extraction failures MUST NOT break the entire transfer unless the
  transfer itself failed.
- Extracted metadata MUST be merged deterministically with existing metadata.
- Heavy processing SHOULD be isolated or deferred when needed.

**Rationale**: Surprise CPU/IO from metadata work has caused jank, OOMs,
and battery regressions in consumer apps. Opt-in is mandatory.

### IX. Error Handling and Logging

Errors MUST be typed, useful, and safe.

Rules:

- Use typed exceptions for upload, download, cache, delete, metadata, and
  task errors.
- Preserve the original cause where possible (exception chaining).
- URLs containing tokens, signed URLs, and Firebase credentials MUST NOT
  appear in logs.
- Logging MUST be configurable.
- User-facing errors SHOULD be understandable.
- Developer-facing errors SHOULD include enough context for debugging.

**Rationale**: Untyped errors hide root causes; logged credentials are a
security incident waiting to happen.

### X. Performance and Memory Efficiency

TransferKit MUST be efficient under repeated widget rebuilds and large
batches.

Rules:

- Duplicate transfers for the same logical file MUST be avoided.
- Duplicate stream listeners MUST be avoided.
- Unnecessary full-set rebuilds SHOULD be avoided when targeted updates are
  possible.
- O(n²) batch operations SHOULD be replaced with map/set-based algorithms
  when feasible.
- Large metadata operations MUST NOT block UI unnecessarily.
- Batch upload/download progress MUST remain responsive.

**Rationale**: This package runs in performance-sensitive UIs (lists, feeds,
chats). Hot-path inefficiency multiplies across every consumer screen.

### XI. Testing Requirements

Every behavioral fix MUST include tests.

Required test coverage areas:

- Task lifecycle transitions
- start / pause / resume / cancel / retry behavior
- Group task operations
- Stream sharing with multiple subscribers
- Stream cleanup and reference counting
- Cache hit / miss / stale / deleted file behavior
- Metadata extraction configuration
- Batch transfer progress
- Public API examples where practical

No bug fix is complete without a regression test, unless testing is
technically impractical and that reason is documented in the change.

**Rationale**: Without regression coverage, the same lifecycle/cache/stream
bugs reappear across versions. Tests are the only durable defence.

### XII. Documentation and Release Discipline

Documentation MUST reflect actual behavior.

Rules:

- `README.md` MUST describe only implemented behavior.
- `CHANGELOG.md` MUST be updated for every user-visible change.
- Public APIs MUST have clear Dartdoc comments.
- Examples MUST compile.
- Platform limitations MUST be documented.
- Breaking changes MUST include migration notes.

**Rationale**: For a consumed package, documentation IS the contract. Out
of-date docs cause downstream bugs the package author never sees.

## Development Workflow & Quality Gates

### Workflow

When modifying TransferKit:

1. Inspect existing behavior first.
2. Confirm the bug or design inconsistency.
3. Write or update tests.
4. Apply the smallest safe fix.
5. Run format, analyze, and tests.
6. Update `README.md` and `CHANGELOG.md` when behavior changes.
7. Avoid unrelated refactoring inside bug-fix tasks.

### Quality Gates

Before any implementation is accepted, ALL of the following MUST hold:

- `dart format .` passes.
- `flutter analyze` passes.
- `flutter test` passes.
- Public API examples remain valid.
- No sensitive data appears in logs.
- `README.md` and `CHANGELOG.md` match the final behavior.

## Maintenance & Quality Improvement Cycle

TransferKit development MUST follow a continuous maintenance cycle. The
purpose of this project is not only to add new features — a major part of
the work is to inspect, repair, stabilize, and improve the existing package.

A development cycle MAY include:

1. Bug fixing
2. Business logic review
3. Transfer lifecycle validation
4. Cache behavior verification
5. Stream and resource cleanup auditing
6. Performance optimization
7. Memory usage reduction
8. API consistency review
9. Documentation correction
10. Regression testing

### Maintenance Goals

**Fix Real Bugs.** Identify the incorrect behavior, locate affected files,
state the expected behavior, add or update regression tests, apply the
smallest safe fix, verify nothing else changed, and update documentation if
user-visible behavior changes. Watch especially for: methods whose names do
not match their behavior; group operations calling the wrong lifecycle
operation; `retry` behaving like `start` without a proper reset; tasks
entering invalid states from completed/cancelled/error; streams emitting
after close; cache reporting "available" for files that no longer exist.

**Audit Business Logic.** Compiling is not enough. Verify upload/download
flows behave as documented, state transitions are valid, grouped operations
apply the correct action to each task, batch progress is computed correctly,
cache hit/miss decisions are accurate, metadata extraction respects config
flags, background behavior matches README claims, and public APIs behave
consistently across single and multi-file operations.

**Improve Performance Quality.** Avoid duplicate listeners and tasks, reduce
unnecessary stream emissions and widget rebuilds, prevent memory leaks from
unclosed controllers/subscriptions, gate expensive metadata work, keep heavy
file processing off the UI isolate, and keep batch operations efficient on
large file sets. Performance work SHOULD be measurable; the reason and
expected improvement MUST be documented.

**Improve Resource Management.** Verify `StreamController` lifecycles,
`StreamSubscription` cancellation, Firebase task cleanup, cache file
deletion, completed/failed/cancelled task cleanup, delayed-cleanup behavior,
reference-counting correctness, and app-restart recovery. No resource MAY
remain active after it is no longer needed.

**Improve Code Quality.** Allowed: splitting large files for clarity,
extracting private helpers to reduce duplication, improving naming, adding
missing Dartdoc comments, replacing unsafe logic with explicit state
handling, adding typed exceptions, removing dead code, and improving
testability via dependency injection. NOT allowed: large unrelated rewrites,
cosmetic-only refactors during bug-fix tasks, public API changes without a
clear reason, new dependencies without justification, or mixing multiple
unrelated fixes in one task.

**Documentation Must Match Reality.** During every cycle verify `README.md`
describes only implemented behavior, `CHANGELOG.md` lists user-visible
changes, examples compile, public API docs match actual behavior, platform
limitations are documented, and background/cache/retry/lifecycle behavior is
described honestly. If code and documentation disagree, fix one of them —
they MUST NOT be left in conflict.

### Maintenance Workflow

1. Audit the current behavior.
2. Identify the exact problem.
3. Define the expected behavior.
4. Add or update tests.
5. Implement the smallest safe fix.
6. Run formatting, analysis, and tests.
7. Update `README.md` and `CHANGELOG.md` if needed.
8. Document any limitation or follow-up task.

### Quality Bar

A change is not complete unless:

- The bug or improvement is clearly described.
- The affected behavior is covered by tests where practical.
- The implementation does not introduce unrelated changes.
- Public APIs remain stable, unless a breaking change is approved.
- Performance and resource impact have been considered.
- Documentation is updated when behavior changes.
- The package passes format, analyze, and test checks.

## Governance

This constitution defines the stable engineering principles of TransferKit
and supersedes ad-hoc practices. Detailed feature requirements, API
contracts, implementation plans, and file-by-file tasks are written
elsewhere — see `/speckit.specify`, `/speckit.plan`, and `/speckit.tasks`.

**Authority.** All pull requests, reviews, and design decisions MUST verify
compliance with the principles above. Where a principle is not met, the
change MUST justify the deviation explicitly or be rejected.

**Amendments.** Amendments require: a written rationale, an updated version
per the policy below, propagation of any impact to dependent templates
(`.specify/templates/plan-template.md`, `spec-template.md`,
`tasks-template.md`, `checklist-template.md`), and a `CHANGELOG.md` entry
when the amendment affects user-visible behavior or public contract.

**Versioning policy** (semantic versioning of THIS document):

- **MAJOR**: Backward-incompatible governance or principle removals/redefinitions.
- **MINOR**: A new principle or section is added, or guidance is materially
  expanded.
- **PATCH**: Clarifications, wording, typo fixes, non-semantic refinements.

**Compliance review.** During every maintenance cycle (see above), reviewers
MUST confirm that recent changes still satisfy Principles I–XII. Any
discovered drift MUST be either fixed in code or escalated to a constitution
amendment — never silently tolerated.

**Runtime guidance.** Day-to-day coding standards, naming conventions, and
file layout live in `CLAUDE.md` at the package root. That file is subordinate
to this constitution: if the two ever conflict, this document wins and
`CLAUDE.md` MUST be corrected.

**Version**: 1.0.0 | **Ratified**: 2026-05-06 | **Last Amended**: 2026-05-06
