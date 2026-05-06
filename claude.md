# Claude Code Guidelines for File Management System

This document outlines the coding standards, architectural patterns, and important notes for maintaining and extending this library.

---

## Project Overview

**File Management System** is a Flutter package for managing file uploads and downloads with Firebase Storage. It provides task management, caching, progress tracking, and pre-built UI components.

---

## Architecture

### Core Patterns

#### 1. Singleton Pattern
Used for repositories and services to ensure single source of truth:

```dart
class FileTaskRepository {
  static final FileTaskRepository instance = FileTaskRepository._internal();
  FileTaskRepository._internal();
  factory FileTaskRepository() => instance;
}
```

#### 2. Stream Sharing Pattern
Multiple subscribers share a single Firebase listener to optimize resources:

```
Subscribers ──► Shared BroadcastStream ──► Single Firebase Listener
```

**Key files:**
- `lib/src/repository/firebase_storage_factory.dart`

#### 3. Repository Pattern
Data access is abstracted through repositories:
- `FileTaskRepository` - Task persistence
- `FilePathAndURLRepository` - URL/path caching
- `BackgroundTaskRepository` - Background task tracking

#### 4. Part Files
`firebase_storage_factory.dart` is a `part of` file for `file_task_repository.dart`:
```dart
// In file_task_repository.dart
part 'firebase_storage_factory.dart';

// In firebase_storage_factory.dart
part of 'file_task_repository.dart';
```

---

## Coding Standards

### Language
- **Code**: English only
- **Comments**: English only
- **Documentation**: English only

### Naming Conventions

| Type | Convention | Example |
|------|------------|---------|
| Classes | PascalCase | `FileManagementSystem` |
| Methods | camelCase | `downloadTaskStream` |
| Variables | camelCase | `taskService` |
| Constants | camelCase | `_cleanupDelay` |
| Private | Underscore prefix | `_downloadStreamCache` |
| Files | snake_case | `file_task_repository.dart` |

### Documentation

All public APIs must have dartdoc comments:

```dart
/// Creates a download task for the given URL.
///
/// ## Parameters
/// - [url]: The Firebase Storage URL
/// - [taskId]: Unique identifier for this task
///
/// ## Returns
/// A [FileTask] representing the download operation
///
/// ## Example
/// ```dart
/// final task = await repo.createDownloadTask(
///   url: 'https://...',
///   taskId: 'download_001',
/// );
/// ```
Future<FileTask> createDownloadTask({...});
```

### Error Handling

Use typed exceptions with error chaining:

```dart
try {
  await operation();
} catch (e, stackTrace) {
  throw FileDownloadException(
    'Download failed',
    cause: e,
    stackTrace: stackTrace,
  );
}
```

---

## Important Files

### Core
| File | Purpose |
|------|---------|
| `lib/transfer_kit.dart` | Main exports |
| `lib/src/transfer_kit.dart` | Main controller |
| `lib/src/core/file_management_config.dart` | Configuration |

### Repositories
| File | Purpose |
|------|---------|
| `file_task_repository.dart` | Task persistence |
| `firebase_storage_factory.dart` | Firebase task/stream management |
| `firebase_file_repository.dart` | High-level file operations |
| `file_path_and_url_repository.dart` | URL/path caching |

### Models
| File | Purpose |
|------|---------|
| `file_task.dart` | Task model |
| `file_exception.dart` | Exception classes |
| `file_path_and_url.dart` | Path/URL model with metadata |
| `media_metadata.dart` | Metadata for images, video, audio, documents |

### Services
| File | Purpose |
|------|---------|
| `metadata_extraction_service.dart` | Extract metadata from local files |

---

## Performance Guidelines

### 1. Avoid O(n²) Operations
Convert Set to List before indexed access:

```dart
// BAD
for (int i = 0; i < set.length; i++) {
  final item = set.elementAt(i); // O(n) per access
}

// GOOD
final list = set.toList();
for (int i = 0; i < list.length; i++) {
  final item = list[i]; // O(1) per access
}
```

### 2. Pre-compute Filter Conditions
```dart
// GOOD
final hasFilter = value != null;
return items.where((item) => !hasFilter || item.value == value);
```

### 3. Stream Controller Lifecycle
Always check `isClosed` before operations:

```dart
if (!controller.isClosed) {
  controller.add(value);
}
```

### 4. Use Configuration
Access settings via `FileManagementConfig.instance`:

```dart
static Duration get _cleanupDelay =>
    FileManagementConfig.instance.streamCleanupDelay;
```

---

## Security Considerations

### Path Traversal Protection
Validate paths stay within app directory:

```dart
final filePath = path.normalize(path.join(appDir.path, userInput));
if (!filePath.startsWith(appDir.path)) {
  return null; // Reject path traversal attempt
}
```

### Sensitive Data
- Never log URLs containing tokens
- Use `error.runtimeType` instead of full error message in logs

---

## Testing Checklist

When making changes, verify:

- [ ] No Arabic text in code/comments
- [ ] All public APIs documented
- [ ] Exception chaining supported
- [ ] Stream controllers properly closed
- [ ] Path traversal protected
- [ ] Configuration used (not hardcoded values)
- [ ] CHANGELOG.md updated

---

## Common Tasks

### Adding a New Configuration Option

1. Add property to `FileManagementConfig`:
```dart
int _newOption = defaultValue;
int get newOption => _newOption;
```

2. Add to `init()` method:
```dart
static void init({
  int? newOption,
  // ...
}) {
  _instance = FileManagementConfig._internal()
    .._newOption = newOption ?? defaultValue;
}
```

3. Add to `toMap()`:
```dart
return {
  'newOption': _newOption,
  // ...
};
```

4. Update README.md and CHANGELOG.md

### Adding a New Exception

1. Add to `file_exception.dart`:
```dart
class NewException extends FileException {
  const NewException(super.message, {super.cause, super.stackTrace});
}
```

2. Export in `transfer_kit.dart` (already exported via `file_exception.dart`)

### Adding a New Widget

1. Create in `lib/src/widget/`
2. Export in `lib/transfer_kit.dart`
3. Document in README.md

### Working with Metadata

#### Adding New Metadata Properties

1. Add property to `MediaMetadata`:
```dart
/// New property description
final String? newProperty;
```

2. Update constructor and `fromMap`/`toMap`:
```dart
MediaMetadata({
  // ...
  this.newProperty,
});

factory MediaMetadata.fromMap(Map<String, dynamic> map) {
  return MediaMetadata(
    // ...
    newProperty: map['newProperty'] as String?,
  );
}

Map<String, dynamic> toMap() {
  return {
    // ...
    if (newProperty != null) 'newProperty': newProperty,
  };
}
```

3. Update `mergeWith` and `copyWith` methods

4. Update documentation in README.md

#### Metadata Flow

```
API Response ──► FilePathAndURL.metadata ──► Download/Upload ──► MetadataExtractionService
                                                    │                      │
                                                    ▼                      ▼
                                            FilePathAndURLRepository ◄── Merged Metadata
                                                    │
                                                    ▼
                                              Cache (persistent)
```

---

## Git Workflow

### Commit Messages
Follow conventional commits:
- `feat:` New feature
- `fix:` Bug fix
- `refactor:` Code refactoring
- `perf:` Performance improvement
- `docs:` Documentation
- `style:` Code style (formatting)
- `test:` Tests
- `chore:` Maintenance

### Branch Naming
- `feature/description`
- `fix/description`
- `refactor/description`

---

## Dependencies

Current dependencies (keep minimal):
- `firebase_storage` - Firebase integration
- `get_storage` - Local persistence
- `path_provider` - File paths
- `collection` - Collection utilities
- `logger` - Logging

Avoid adding unnecessary dependencies.

---

## Contact

For questions about this library, refer to:
- README.md - Usage documentation
- CHANGELOG.md - Version history
- This file - Development guidelines
