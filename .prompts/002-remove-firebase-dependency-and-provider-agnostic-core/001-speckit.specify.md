/speckit.specify

Remove direct Firebase handling from TransferKit and redesign the transfer core to be provider-agnostic.

This is a major architecture and maintenance task.

## Problem

TransferKit currently presents itself as a reusable Flutter file transfer package, but the transfer implementation is tightly coupled to Firebase Storage.

The goal is to remove direct Firebase-specific handling from the core package and make TransferKit a generic file transfer toolkit.

After this task, TransferKit should not require Firebase dependencies in its core implementation.

## Goals

1. Remove direct dependency on Firebase Storage from the core package.
2. Remove Firebase-specific task factories and Firebase-specific model coupling.
3. Introduce provider-agnostic transfer abstractions.
4. Keep upload/download/task/cache APIs reusable.
5. Preserve public API compatibility where practical.
6. Provide migration guidance for users who previously used Firebase Storage.
7. Keep cache behavior provider-independent.
8. Keep notification behavior provider-independent.
9. Add tests using fake/mock transfer providers.
10. Update README.md and CHANGELOG.md.

## Functional Requirements

### Provider-agnostic transfer core

TransferKit must define generic transfer interfaces such as:

- upload source,
- download source,
- transfer request,
- transfer result,
- transfer progress,
- transfer driver/provider.

The core task lifecycle must not depend on Firebase classes.

### Remove Firebase-specific dependencies

The package core must not import:

- `package:firebase_storage/firebase_storage.dart`
- `package:cloud_firestore/cloud_firestore.dart`

unless a separate optional adapter package or explicitly isolated adapter remains outside the core.

### Generic Download

A download should work through a generic driver.

The driver must emit progress updates and final result.

Examples of possible drivers:
- HTTP download driver,
- local file copy driver,
- test fake driver,
- optional external Firebase adapter if later separated.

### Generic Upload

An upload should work through a generic driver.

The driver must emit progress updates and final result.

The upload result should be generic and not Firebase-specific.

### Task lifecycle preservation

Removing Firebase must not break:

- waiting,
- running,
- paused,
- completed,
- error,
- cancelled,
- cached,
- retry,
- grouped operations,
- batch operations.

If pause/resume cannot be supported by a given provider, the capability must be explicit.

### Capability model

Each provider/driver must expose capabilities:

- supportsUpload,
- supportsDownload,
- supportsPause,
- supportsResume,
- supportsCancel,
- supportsBackgroundTransfer,
- supportsProgress,
- supportsRetry.

The core must handle unsupported capabilities gracefully.

### Migration

Existing Firebase users need clear migration guidance.

The migration guide must explain:

- what was removed,
- why it was removed,
- what replaces it,
- how to create or plug in a provider,
- whether Firebase support moved to an optional adapter or must be implemented by the app.

## Non-Goals

- Do not implement a full Firebase adapter unless explicitly requested.
- Do not implement all possible storage providers.
- Do not redesign unrelated UI widgets unless Firebase-specific assumptions exist there.
- Do not implement notification redesign in this task.
- Do not change cache policy except what is required to make it provider-agnostic.

## User Stories

1. As a Flutter developer, I want to use TransferKit without Firebase so that the package can work with my own backend.

2. As a developer, I want the core transfer lifecycle to work with any provider.

3. As a package maintainer, I want tests to use fake providers instead of real Firebase.

4. As a developer migrating from Firebase, I want clear migration instructions.

5. As a developer, I want unsupported provider features like pause/resume to fail clearly instead of silently doing the wrong thing.

## Acceptance Criteria

- Core package no longer imports Firebase Storage.
- Core package no longer depends on Cloud Firestore unless there is a documented non-Firebase reason.
- Transfer lifecycle works through generic abstractions.
- Tests use fake transfer providers.
- Cache system works without Firebase.
- README.md no longer describes TransferKit as Firebase-only.
- CHANGELOG.md documents the architectural change.
- Migration guide exists.
