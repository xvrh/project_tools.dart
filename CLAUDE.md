# CLAUDE.md

## Project Overview

`project_tools.dart` is a Dart utilities library for Dart/Flutter monorepo management. It provides tools for:
- Discovering and analyzing Dart projects recursively
- Formatting and organizing Dart code (import sorting, absolute-to-relative import conversion)
- File enumeration with `.gitignore` support
- Lines of code counting (cloc)
- GitHub Dependabot automation
- Flutter SDK discovery

**Package name:** `project_tools`
**Dart SDK:** `^3.4.0`
**Published as:** a Dart package library

## Commands

### Install dependencies
```bash
dart pub get
```

### Run tests
```bash
dart test
```

### Analyze
```bash
dart analyze --fatal-infos
```

### Format code
```bash
dart tool/format.dart
```

### Check for uncommitted changes (used in CI)
```bash
dart tool/check_uncommitted_changes.dart
```

### Run pub get for all nested projects
```bash
dart tool/pub_get_all_projects.dart
```

### Run pub upgrade for all nested projects
```bash
dart tool/pub_upgrade_all_projects.dart
```

## Project Structure

```
lib/
  project_tools.dart        # Public API exports
  src/
    dart_project.dart       # DartProject and ProjectFile classes
    list_files.dart         # File enumeration with .gitignore support
    git_root.dart           # Git repository root detection
    flutter_sdk.dart        # Flutter SDK discovery
    format.dart             # Code formatting utilities
    format_pre_commit.dart  # Pre-commit hook formatting
    ignore/                 # .gitignore-compatible pattern matching
    dart_format/
      fix_absolute_imports.dart  # Convert absolute to relative imports
      fix_import_order.dart      # Sort and organize imports
    cloc/                   # Lines of code counting
    dependabot/             # GitHub Dependabot automation
test/                       # Unit tests
tool/                       # Development scripts
.github/workflows/          # CI/CD (build.yaml)
```

## Key Classes

- **`DartProject`** — Represents a Dart package; discovered via `pubspec.yaml`
- **`ProjectFile`** — A file within a project with relative path info
- **`FilePath`** — Low-level file path abstraction
- **`DirectoryContext`** — Context during directory traversal
- **`Ignore`** — Port of node-ignore for `.gitignore` pattern matching
- **`FlutterSdk`** — Flutter SDK discovery and validation
- **`ClocReport`** — Lines of code analysis results

## Architecture

- Lower layer: File system utilities (`list_files.dart`, `git_root.dart`)
- Middle layer: Dart project abstraction (`dart_project.dart`)
- Upper layer: Specialized features (formatting, analysis, reporting)

Monorepo support: discovers all nested `pubspec.yaml` files from a git root. Files in nested projects are excluded when listing files for a parent project.

## Code Style

- Lint config: `analysis_options.yaml` (extends `package:lints/recommended.yaml`) with strict casts and raw types enabled
- Return types always declared
- Avoid dynamic calls
- Sort pub dependencies
- All public APIs should have doc comments

## CI/CD

GitHub Actions (`.github/workflows/build.yaml`) runs on Ubuntu, macOS, and Windows:
1. `dart pub get`
2. `dart analyze --fatal-infos`
3. `dart test`
4. `dart tool/format.dart`
5. `dart tool/check_uncommitted_changes.dart`
