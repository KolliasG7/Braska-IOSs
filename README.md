<div align="center">
  <h1>Strawberry Manager - Reworked</h1>
  <p>A premium, entirely full-stack Flutter Application designed for real-time telemetry, remote management, and quick-settings integration for the PlayStation 4 over localized or tunneled backends.</p>
</div>

---

## Features

### **Live Real-time Telemetry Dashboard**
- Tracks live CPU & RAM usage percentages securely.
- Granular APU Temp polling combined with live Fan RPM metrics.
- OLED-ready premium stark minimalist dark-mode aesthetics.

### **Full PTY Remote Shell**
- Native interactive terminal leveraging WebSocket pipelines directly into the host PS4 shell environment.
- Re-attaches to background-running host terminals automatically upon reconnecting.
- Full custom `pty` keyboard emulation handling.

### **File Manager & Execution Tooling**
- Browse the internal host directory layout.
- Upload custom payloads or general binary tools securely over API.
- Download core files reliably using Android 10+ scoped native Storage Access Framework `saveFile` intents (no more random permission exceptions).

### **Native Android Quick Settings Integration**
Strawberry Manager ships with pure Android Kotlin-level integrated Quick Settings Tiles allowing hardware modifications without even booting the Flutter engine!
1. **Fan Tuner Tile**: Tap this newly designed Cooling/Snowflake notification tile to dynamically cycle and scale your APU Cooling threshold instantly between `45°C` to `85°C`. Your active mode is written explicitly in the tile natively.
2. **LED Tuner Tile**: Read out exactly what color profile your console is firing. Taps flawlessly cycle through 12+ API-queried colors seamlessly from the backend (`White`, `Blue`, `Red`, etc.) dynamically preventing out-of-index crashes.

### **New Cleaner UI and Navigation System
---

## Getting Started

### Prerequisites
- **Flutter SDK**: `^3.3.0` or higher
- **Dart**: `>=3.0.0`
- **Android**: Requires `.SDK 24+` minimum platform build architectures with Gradle fully synced.
- **Backend Host**: Requires the companion Python FastAPI `ps4-api` backend running effectively on your PS4 host device (leveraging the appropriate REST paths `/api/fan/threshold`, `/ws/telemetry`, etc). 

### Installation 

1. **Clone the repository:**
   ```bash
   git clone https://github.com/rmuxnet/Braska
   cd Braska
   ```
2. **Fetch core packages (including the Android native bridges):**
   ```bash
   flutter pub get
   ```
3. **Run normally (Hot Reload Supported):**
   ```bash
   flutter run
   ```

### Release Building (Native Sideloading)
The release structure is pre-configured to utilize the `debug` keystore inside the top-level Gradle definitions implicitly allowing for totally effortless self-hosting:
```bash
flutter build apk --release
adb install build/app/outputs/flutter-apk/app-release.apk
```

---

## Architecture 
- **WebSocket Services**: Asynchronous event streams actively handle `ws.terminal` and `ws.telemetry` ports concurrently.
- **Background Headless Isolates**: Custom Kotlin `TileService` integrations natively parse flutter `SharedPreferences` `shared.xml` registries using HTTP Cleartext permissions (`HttpURLConnection`) to bypass any overhead of spooling out the app UI!

## License
[MIT License](LICENSE)





CREDITS TO https://github.com/rmuxnet
