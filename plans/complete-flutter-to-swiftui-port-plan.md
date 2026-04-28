# Complete Flutter-to-SwiftUI Port Plan

## Current State Summary

The Swift port has basic scaffolding for most screens but is missing significant functionality, the entire glassmorphism design system, several API endpoints, and proper asset bundling. The Flutter app is ~6,500 lines of Dart across screens, services, widgets, and theming. The Swift port is ~2,500 lines and needs roughly doubling in scope.

## Gap Analysis

### API Endpoints Missing from Swift APIService
| Endpoint | Flutter Method | Purpose |
|----------|---------------|---------|
| `GET /api/files/list` | `listFiles` | Browse remote filesystem |
| `GET /api/files/download` | `downloadFile` | Download files |
| `POST /api/files/upload` | `uploadFile` | Upload files |
| `DELETE /api/files/delete` | `deleteFile` | Delete files |
| `POST /api/power/:action` | `powerAction` | Shutdown/reboot/safe mode |
| `POST /api/tunnel/start` | `startTunnel` | Start Cloudflare tunnel |
| `POST /api/tunnel/stop` | `stopTunnel` | Stop tunnel |
| `GET /api/tunnel/status` | `getTunnelStatus` | Check tunnel state |
| `GET /api/system/logs` | `fetchLogs` | Journalctl log viewer |
| `POST /auth/change-password` | `rotatePassword` | Password rotation |
| `GET /api/led/active` | `getActiveLed` | Current LED profile |

### Screens Missing or Incomplete
| Screen | Status | What is Missing |
|--------|--------|----------------|
| ConnectView | Partial | Entrance animations, tunnel URL memory, payload injection |
| DashboardView | Partial | Glass bottom nav, reconnect banner, animated tab transitions, top bar with live status chips |
| MonitorTab | Good | Arc gauge widgets, per-core CPU pills, glass card styling |
| ControlTab | Good | Glass styling, gradient slider |
| TerminalView | Partial | Keyboard accessory bar with special keys - Ctrl, Tab, arrows, Esc |
| FilesView | Stub | Full file browser with upload/download/delete, breadcrumbs, file icons |
| ProcessesView | Good | Glass styling needed |
| SettingsView | Partial | Missing tunnel management, logs viewer link, payload injection section |
| LogsView | MISSING | Entire screen - journalctl viewer with priority/line filters |

### Design System - Entirely Missing
The Flutter app uses a custom glassmorphism design system with:
- Dark gradient background with animated orbital halos
- Frosted glass cards using BackdropFilter
- Specular sheen effects - LiquidGlassSheen
- Custom glass buttons, pills, and bottom navigation
- Full color token system - Bk class with 50+ color constants
- Custom spacing, radii, and duration tokens
- Glass-styled text inputs

### Assets and Build Configuration
- No Assets.xcassets catalog in the Xcode project sources
- App icon not configured
- Logo asset not bundled
- project.yml does not reference an assets directory

---

## Implementation Plan

### Phase 1: Foundation - Design System and Assets

**1.1 Create SwiftUI Theme System**
Port the Flutter `tokens.dart` color palette to Swift. Create:
- `Theme/AppColors.swift` - All Bk color constants mapped to SwiftUI Colors
- `Theme/AppSpacing.swift` - Spacing, radii, duration tokens
- `Theme/AppTypography.swift` - Font styles matching Flutter T class

**1.2 Create Glass Design Components**
- `Theme/GlassCard.swift` - Frosted glass card with `.ultraThinMaterial` + tint overlays + specular sheen
- `Theme/GlassBackground.swift` - Dark gradient backdrop with orbital halo circles
- `Theme/GlassBottomNav.swift` - Custom tab bar replacing system TabView chrome
- `Theme/GlassButton.swift` - Glass-styled icon buttons and pills
- `Theme/GlassInput.swift` - Glass-styled text fields

**1.3 Configure Assets**
- Create `Assets.xcassets` with AppIcon and logo
- Update `project.yml` to include assets in build sources
- Copy logo.png into assets catalog

### Phase 2: Complete API Layer

**2.1 Add Missing API Endpoints**
Extend `APIService.swift` with:
- File operations: `listFiles`, `downloadFile`, `uploadFile`, `deleteFile`
- Power actions: `powerAction` - shutdown, reboot, safe mode
- Tunnel management: `startTunnel`, `stopTunnel`, `getTunnelStatus`
- System logs: `fetchLogs` with line count and priority params
- Password rotation: `rotatePassword`
- Active LED: `getActiveLed`

**2.2 Add Retry Policy**
Port the exponential backoff retry logic from Flutter `RetryPolicy` to Swift, or use URLSession's built-in retry with custom logic.

### Phase 3: Complete Screens

**3.1 Rework ConnectView**
- Apply glass background with orbital halos
- Add entrance fade + slide animation
- Add tunnel URL memory via UserDefaults
- Add password dialog as a sheet
- Style with glass components

**3.2 Rework DashboardView**
- Replace system TabView with custom GlassBottomNav
- Add top bar with app title, uptime subtitle, connection status pill
- Add reconnect banner when WebSocket disconnects mid-session
- Add animated tab switching with fade-through transitions

**3.3 Enhance MonitorTab**
- Add ArcGauge custom SwiftUI shape for CPU/RAM circular gauges
- Add per-core CPU pills
- Wrap all metric sections in GlassCard with tints
- Add disk and network info cards

**3.4 Enhance ControlTab**
- Restyle fan slider with gradient track colors
- Restyle LED picker with glass buttons
- Add power controls card with confirmation dialogs

**3.5 Complete FilesView + FilesViewModel**
- Implement full file browser with directory navigation
- Add breadcrumb path display
- Add file type icons mapping
- Add file upload via document picker
- Add file download with share sheet
- Add file delete with confirmation
- Add pull-to-refresh
- Wire up to new API file endpoints

**3.6 Enhance TerminalView**
- Add keyboard accessory bar with special keys: Ctrl, Tab, Esc, arrow keys
- Add clear button
- Add reconnect button
- Style terminal output with monospace font on dark background

**3.7 Create LogsView + LogsViewModel**
- New screen: journalctl log viewer
- Line count picker: 100, 500, 1000, 2000
- Priority filter: All, Errors, Warnings+, Info+, Debug
- Pull-to-refresh
- Monospace scrollable log display
- Add navigation from Settings

**3.8 Enhance SettingsView**
- Add tunnel management section: start/stop tunnel, show URL
- Add diagnostics section with link to LogsView
- Add app version from bundle info
- Style with glass components

### Phase 4: Polish and Integration

**4.1 Connection Flow Polish**
- Ensure WebSocket connects after auth
- Add telemetry history tracking in ConnectionViewModel - cpuHistory, ramHistory, tempHistory, fanHistory arrays
- Add notification support for temperature alerts

**4.2 Animation System**
- Add entrance animations on ConnectView and DashboardView
- Add fade-through tab transitions
- Respect reduce-motion accessibility setting

**4.3 Haptic Feedback**
- Add UIImpactFeedbackGenerator on control interactions
- Add UISelectionFeedbackGenerator on navigation

### Phase 5: Build and CI

**5.1 Update project.yml**
- Add Assets.xcassets to sources
- Verify all new files are included in build

**5.2 Update CI Workflow**
- Ensure ios-ipa-sideload.yml produces a complete IPA
- Verify asset catalog is included in archive
- Test that the IPA is a reasonable size with all assets

---

## File Structure After Port

```
StrawberryManager-iOS/
  Assets.xcassets/
    AppIcon.appiconset/
    Logo.imageset/
  Models/
    ConnectionState.swift
    ProcessInfo.swift
    Telemetry.swift
  Services/
    APIService.swift          -- expanded with all endpoints
    StorageService.swift
    WebSocketService.swift
    TerminalWebSocketService.swift
  Theme/
    AppColors.swift           -- NEW
    AppSpacing.swift           -- NEW
    GlassBackground.swift      -- NEW
    GlassCard.swift            -- NEW
    GlassBottomNav.swift       -- NEW
    GlassButton.swift          -- NEW
    GlassInput.swift           -- NEW
    ArcGauge.swift             -- NEW
  ViewModels/
    ConnectionViewModel.swift
    ControlViewModel.swift
    DashboardViewModel.swift
    FilesViewModel.swift       -- rewritten
    ProcessesViewModel.swift
    LogsViewModel.swift        -- NEW
  Views/
    ContentView.swift
    Connect/
      ConnectView.swift        -- reworked
    Dashboard/
      DashboardView.swift      -- reworked
      ControlTab.swift         -- enhanced
      MonitorTab.swift         -- enhanced
      Components/
        TelemetryCard.swift
        TelemetryGraph.swift
    Files/
      FilesView.swift          -- rewritten
    Logs/
      LogsView.swift           -- NEW
    Processes/
      ProcessesView.swift
    Settings/
      SettingsView.swift       -- enhanced
    Terminal/
      TerminalView.swift       -- enhanced
  Utilities/
    Extensions/
      Color+Theme.swift        -- expanded
  project.yml                  -- updated
  Info.plist
```
