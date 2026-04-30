# Windows Port Plan (Phase 1 Foundation)

Goal: deliver Windows desktop app with feature parity to current iOS/Android Flutter app while keeping one shared codebase.

## Scope
- Keep Flutter app architecture and services.
- Add Windows runner + platform-specific safeguards.
- Build parity using checklist-driven verification, not ad-hoc visual tweaks.

## Success Criteria
- All core flows work on Windows: connect/auth/dashboard/shell/files/logs/settings/payload send.
- No platform-crash paths.
- Parity matrix tracked and updated per change.
- CI can build Windows artifact.

## Phases
1. Foundation (this phase)
- Add `windows/` target.
- Add parity docs + smoke tests.
- Add platform guards for APIs with known platform differences.

2. Feature parity pass
- Validate each screen + action from matrix.
- Fix input, path, dialog, notification, keyboard/mouse deltas.

3. UX parity pass
- Desktop spacing/typography/motion tuning.
- Accessibility and keyboard shortcuts.

4. Release hardening
- CI artifact build.
- Crash/error telemetry checks.
- Final regression sweep.

## Risks
- Some plugin behavior differs on Windows.
- iOS-only visual expectations may not map 1:1 to desktop.

## Immediate Next Steps
1. Execute matrix for Connect + Dashboard.
2. Add Windows CI workflow artifact lane.
3. Add integration tests for connect/auth happy path + error path.
