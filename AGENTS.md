# Repository Guidelines

## Project Structure & Module Organization
- `HelpMeTrain/`: Primary Xcode project folder (source code, assets, and configuration).
- `HelpMeTrain/Resources/`: Images, colors, and other app assets.
- `HelpMeTrain/Tests/` and `HelpMeTrain/UITests/`: Unit and UI tests (create as you add tests).
- `docs/`: Optional project notes, architecture decisions, and design references.

Adjust paths if you reorganize modules (e.g., `Features/`, `Shared/`, `Services/`).

## Build, Test, and Development Commands
- `xcodebuild -project HelpMeTrain.xcodeproj -scheme HelpMeTrain build`: Build from CLI.
- `xcodebuild -project HelpMeTrain.xcodeproj -scheme HelpMeTrain test`: Run unit tests.
- `open HelpMeTrain.xcodeproj`: Open the project in Xcode.

Use Xcode for day-to-day builds, running on device, and UI test execution.

## Coding Style & Naming Conventions
- Swift: 2-space or 4-space indentation (pick one and keep it consistent).
- Files: `UpperCamelCase.swift` (e.g., `WorkoutPlanView.swift`).
- Types: `UpperCamelCase`, variables/functions: `lowerCamelCase`.
- Prefer SwiftLint/SwiftFormat if added later; keep formatting consistent.

## Testing Guidelines
- Frameworks: XCTest for unit/UI tests.
- Naming: `FeatureNameTests` and `FeatureNameUITests`.
- Focus: critical workflows (onboarding, training flow, saved plans).
- Run tests with `xcodebuild ... test` or Xcode’s Test navigator.

## Commit & Pull Request Guidelines
- No commit history yet. Use concise, imperative commit messages:
  - Example: `Add workout plan model` or `Fix timer pause bug`.
- PRs should include:
  - Summary of changes and reasoning.
  - Screenshots for UI changes.
  - Linked issue or task reference if applicable.

## Configuration Tips
- Keep secrets out of the repo; use `.xcconfig` files or Xcode build settings.
- Document required environment steps in `docs/` if setup gets complex.
