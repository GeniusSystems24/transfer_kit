# speckit.constitution

TransferKit is a Flutter/Dart package that provides a reusable file transfer infrastructure for Flutter applications.

The library is designed to manage file uploads, file downloads, caching, progress tracking, transfer task state, batch operations, stream sharing, metadata extraction, and reusable UI widgets.

TransferKit is not a single application feature.
It is a reusable package that other Flutter applications depend on.
Therefore, stability, predictable behavior, API consistency, testability, and clear documentation are more important than rapid feature additions.

## Library Identity

TransferKit is a production-oriented Flutter file transfer toolkit.

Its main responsibilities are:

1. Upload files to Firebase Storage.
2. Download files from Firebase Storage or supported file URLs.
3. Track transfer progress in real time.
4. Manage transfer lifecycle states such as waiting, running, paused, completed, error, cancelled, and cached.
5. Provide task control operations such as start, pause, resume, cancel, retry, and remove.
6. Support single-file and multi-file transfers.
7. Support grouped transfer operations.
8. Avoid duplicated transfer listeners using stream sharing.
9. Cache downloaded files locally to avoid redundant downloads.
10. Persist task state so transfers can be restored or inspected after app restart.
11. Extract and store file/media metadata when enabled.
12. Provide reusable Flutter widgets for common file loading, uploading, downloading, and media-preview use cases.

## Library Boundary

TransferKit owns:

- File transfer orchestration.
- Transfer task models.
- Transfer task lifecycle.
- Local task persistence.
- Local file caching.
- Progress streams.
- Stream sharing.
- Firebase Storage integration.
- Metadata extraction.
- Reusable file/media widgets.

TransferKit does not own:

- Business-specific application logic.
- User authentication flows.
- Application-specific Firestore document schemas.
- Backend authorization policies.
- Domain-specific file ownership rules.
- Chat, invoice, club, or accounting workflows.
- Permanent backend database state outside the file transfer domain.

Any feature added to TransferKit must remain generic, reusable, and package-level.
Application-specific behavior must be implemented outside the package or injected through clear interfaces.

## Core Constitutional Principles

### 1. Public Package Stability

TransferKit is a reusable package, so public API stability is mandatory.

Rules:

- Do not rename public classes, methods, enums, or parameters unless explicitly required.
- Do not remove public APIs without a migration path.
- Do not change existing behavior silently.
- Any breaking change must include:
  - clear explanation,
  - migration guide,
  - README update,
  - CHANGELOG update,
  - versioning decision.

### 2. Correct Transfer Lifecycle

Every transfer task must follow a predictable lifecycle.

Allowed states include:

- waiting
- running
- paused
- completed
- error
- cancelled
- cached

Rules:

- start, pause, resume, cancel, and retry must have separate meanings.
- retry must not be treated as a simple start operation unless the task is safely reset or recreated.
- completed tasks must not return to running unless a new explicit task is created.
- cancelled tasks must not resume accidentally.
- cached files must represent real files that exist locally.
- group operations must call the correct lifecycle operation for every task.

### 3. Single Source of Truth for Task State

Task state must be managed consistently through the task repository/service layer.

Rules:

- UI widgets must observe task streams.
- UI widgets must not directly mutate task internals.
- Firebase Storage events must update the same task model used by the rest of the package.
- Background transfer events must update the same task model.
- Cache hits must update task state consistently.
- Duplicate representations of the same transfer must be avoided.

### 4. Stream Sharing and Resource Safety

TransferKit must prevent duplicated Firebase listeners when multiple widgets request the same transfer.

Rules:

- Multiple subscribers for the same logical transfer should share one underlying stream where possible.
- Stream controllers must not receive events after being closed.
- Stream subscriptions must be cancelled during cleanup.
- Reference counting must be safe.
- Cleanup delay must not close active streams.
- Completed, failed, or cancelled transfers must release resources safely.

### 5. Cache Correctness

Local cache must be accurate and verifiable.

Rules:

- A file is considered cached only if the local file actually exists.
- Cache metadata must not claim success when the file is missing.
- Cache paths must be deterministic and safe.
- Cache deletion must only remove local files, not remote files.
- Cache expiration and max-size policies must be enforced or clearly documented as not implemented.
- Cache behavior must be tested for hit, miss, stale file, deleted file, and cleanup cases.

### 6. Firebase Storage Integration Boundary

Firebase Storage is the current primary transfer provider.

Rules:

- Firebase-specific code must remain isolated from generic models where practical.
- Public models should not become unnecessarily coupled to Firebase internals.
- If future provider support is added, it must be introduced through clear abstractions.
- Firebase errors must be mapped into typed TransferKit exceptions.

### 7. Background Transfer Honesty

Background transfer support must be truthful, tested, and platform-aware.

Rules:

- If transfers continue in the background, the behavior must be implemented and tested.
- If background behavior is limited by platform or Firebase SDK behavior, it must be documented clearly.
- Android and iOS differences must be documented.
- App restart recovery must be defined.
- Background transfer claims in README must match actual code behavior.

### 8. Metadata Extraction Safety

Metadata extraction must be optional, predictable, and safe for large files.

Rules:

- Metadata extraction must respect TransferKitConfig flags.
- Expensive operations such as SHA-256 hashing, thumbnail generation, waveform extraction, and PDF rendering must not run unexpectedly.
- Metadata extraction failures must not break the entire transfer unless the transfer itself failed.
- Extracted metadata must be merged deterministically with existing metadata.
- Heavy processing should be isolated or deferred when needed.

### 9. Error Handling and Logging

Errors must be typed, useful, and safe.

Rules:

- Use typed exceptions for upload, download, cache, delete, metadata, and task errors.
- Preserve the original cause where possible.
- Do not expose sensitive URLs, signed URLs, tokens, or Firebase credentials in logs.
- Logging must be configurable.
- User-facing errors should be understandable.
- Developer-facing errors should include enough context for debugging.

### 10. Performance and Memory Efficiency

TransferKit must be efficient under repeated widget rebuilds and large batches.

Rules:

- Avoid duplicate transfers for the same logical file.
- Avoid duplicate stream listeners.
- Avoid unnecessary full-set rebuilds where targeted updates are possible.
- Avoid O(n²) batch operations where simple maps/sets can be used.
- Large metadata operations should not block UI unnecessarily.
- Batch upload/download progress must remain responsive.

### 11. Testing Requirements

Every behavioral fix must include tests.

Required test areas:

- Task lifecycle transitions.
- start/pause/resume/cancel/retry behavior.
- Group task operations.
- Stream sharing with multiple subscribers.
- Stream cleanup and reference counting.
- Cache hit/miss/stale/deleted file behavior.
- Metadata extraction configuration.
- Batch transfer progress.
- Public API examples where practical.

No bug fix is complete without a regression test unless testing is technically impractical and the reason is documented.

### 12. Documentation and Release Discipline

Documentation must reflect actual behavior.

Rules:

- README.md must describe only implemented behavior.
- CHANGELOG.md must be updated for every user-visible change.
- Public APIs must have clear Dartdoc comments.
- Examples must compile.
- Platform limitations must be documented.
- Breaking changes require migration notes.

## Development Rules

When modifying TransferKit:

1. First inspect existing behavior.
2. Confirm the bug or design inconsistency.
3. Write or update tests.
4. Apply the smallest safe fix.
5. Run format, analyze, and tests.
6. Update README.md and CHANGELOG.md when behavior changes.
7. Avoid unrelated refactoring inside bug-fix tasks.

## Quality Gates

Before accepting any implementation:

- `dart format .` must pass.
- `flutter analyze` must pass.
- `flutter test` must pass.
- Public API examples must remain valid.
- No sensitive data may appear in logs.
- README.md and CHANGELOG.md must match the final behavior.

## Constitution Scope

This constitution defines stable engineering principles for TransferKit.

Detailed feature requirements, API contracts, implementation plans, and file-by-file tasks must be written later in:

- `/speckit.specify`
- `/speckit.plan`
- `/speckit.tasks`

The constitution should remain stable and should not contain temporary implementation details.

## Maintenance and Quality Improvement Cycle

TransferKit development must follow a continuous maintenance and quality improvement cycle.

The purpose of this project is not only to add new features.
A major part of the work is to inspect, repair, stabilize, and improve the existing package.

Every development cycle may include:

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

## Primary Maintenance Goals

The maintenance cycle must focus on the following goals:

### 1. Fix Real Bugs

Any confirmed bug must be handled through a clear process:

- Identify the incorrect behavior.
- Locate the affected files.
- Explain the expected behavior.
- Add or update regression tests.
- Apply the smallest safe fix.
- Verify that no unrelated behavior was changed.
- Update documentation if user-visible behavior changes.

Examples of bugs to guard against:

- A method name does not match its actual behavior.
- A group operation calls the wrong lifecycle operation.
- Retry behaves like start without resetting the task correctly.
- A completed, cancelled, or failed task enters an invalid state.
- A stream emits after being closed.
- A cached file is reported as available even though it no longer exists locally.

### 2. Audit Business Logic

TransferKit must not only compile successfully.
Its internal behavior must be logically correct.

Business logic review must verify:

- Whether upload and download flows behave as documented.
- Whether task state transitions are valid.
- Whether grouped operations apply the correct action to each task.
- Whether batch progress is calculated correctly.
- Whether cache hit/miss decisions are accurate.
- Whether metadata extraction respects configuration flags.
- Whether background transfer behavior matches the README claims.
- Whether public APIs behave consistently across single and multi-file operations.

The goal is to ensure that the package behavior is predictable, explainable, and safe for production use.

### 3. Improve Performance Quality

Performance improvements are part of the maintenance cycle.

Every change should consider:

- Avoiding duplicate Firebase Storage listeners.
- Avoiding duplicate upload/download tasks.
- Reducing unnecessary stream emissions.
- Reducing unnecessary widget rebuilds.
- Preventing memory leaks from unclosed controllers or subscriptions.
- Avoiding expensive metadata extraction unless enabled.
- Avoiding blocking the UI isolate with heavy file processing.
- Making batch operations efficient for large file sets.

Performance work must be measurable where possible.
If a performance fix is introduced, the reason and expected improvement must be documented.

### 4. Improve Resource Management

TransferKit manages files, streams, tasks, subscriptions, cache entries, and background work.
Therefore, resource cleanup is a first-class responsibility.

Resource management review must verify:

- StreamController lifecycle.
- StreamSubscription cancellation.
- Firebase task cleanup.
- Cache file deletion.
- Completed task cleanup.
- Failed and cancelled task cleanup.
- Delayed stream cleanup behavior.
- Reference counting correctness.
- App restart recovery behavior.

No resource should remain active after it is no longer needed.

### 5. Improve Code Quality

Code quality work is allowed when it supports maintainability, testability, or correctness.

Allowed quality improvements:

- Split large files when it improves clarity.
- Extract private helper methods when it reduces duplication.
- Improve naming when it clarifies behavior.
- Add missing Dartdoc comments.
- Replace unsafe logic with explicit state handling.
- Add typed exceptions.
- Remove dead code.
- Improve testability through dependency injection where appropriate.

Not allowed:

- Large unrelated rewrites.
- Cosmetic-only refactoring during bug-fix tasks.
- Changing public APIs without a clear reason.
- Adding new dependencies without justification.
- Mixing multiple unrelated fixes in one task.

### 6. Documentation Must Match Reality

Documentation is part of quality.

During every maintenance cycle, verify:

- README.md describes implemented behavior only.
- CHANGELOG.md includes user-visible changes.
- Examples compile.
- Public API documentation matches actual behavior.
- Platform limitations are documented.
- Background transfer behavior is described honestly.
- Cache behavior is described accurately.
- Retry and lifecycle behavior are clearly explained.

If code and documentation disagree, either the code must be fixed or the documentation must be corrected.

## Maintenance Workflow

Every repair or improvement must follow this workflow:

1. Audit the current behavior.
2. Identify the exact problem.
3. Define the expected behavior.
4. Add or update tests.
5. Implement the smallest safe fix.
6. Run formatting, analysis, and tests.
7. Update README.md and CHANGELOG.md if needed.
8. Document any limitation or follow-up task.

## Quality Bar

A change is not complete unless:

- The bug or improvement is clearly described.
- The affected behavior is covered by tests where practical.
- The implementation does not introduce unrelated changes.
- Public APIs remain stable unless a breaking change is approved.
- Performance and resource impact are considered.
- Documentation is updated when behavior changes.
- The package passes format, analyze, and test checks.
