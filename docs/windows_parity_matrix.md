# Windows Parity Matrix

Status key: `todo` | `in_progress` | `done` | `blocked`

## Core App
| Area | Status | Notes |
|---|---|---|
| App boot on Windows | done | `windows/` target scaffolded |
| Notification init safety | done | Windows init + guard added |
| Encoding/text sanity | in_progress | mojibake cleanup pass ongoing |

## Connect Screen
| Feature | Status | Notes |
|---|---|---|
| Host input/edit | todo | validate local+tunnel formats |
| Connect action + error surface | todo | verify no platform-specific regressions |
| Password dialog/login | todo | verify focus/enter behavior |
| Payload injection flow | todo | file picker + socket send verification |

## Dashboard
| Feature | Status | Notes |
|---|---|---|
| Live telemetry render | todo | WS lifecycle on Windows |
| Tab navigation | todo | keyboard/mouse parity |
| Fan/LED/Power controls | todo | API action parity |

## Files
| Feature | Status | Notes |
|---|---|---|
| Browse/list | todo | path semantics on Windows host side |
| Upload/download/delete | todo | desktop file dialogs and paths |

## Terminal
| Feature | Status | Notes |
|---|---|---|
| Connect + output stream | todo | WS terminal behavior |
| Input/send shortcuts | todo | keyboard-specific tuning |

## Settings/Logs/Processes
| Feature | Status | Notes |
|---|---|---|
| Logs fetch/filter | todo | verify API + UI states |
| Processes list/actions | todo | verify kill action path |
| Settings toggles | todo | persistence parity |
