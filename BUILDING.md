# Building Strawberry Manager

This document provides complete build instructions for all versions of Strawberry Manager.

## 📱 Flutter Version (Current Production)

### Prerequisites
- Flutter SDK 3.19.0+
- Dart 3.0+
- For Android: Android Studio, SDK 24+
- For iOS: Xcode 15+, macOS

### Build Commands

#### Android APK
```bash
# Development build
flutter build apk --debug

# Release build (recommended)
flutter build apk --release

# Install to device
flutter build apk --release
adb install build/app/outputs/flutter-apk/app-release.apk
```

#### iOS
```bash
# Development
flutter build ios --debug

# Release (requires code signing)
flutter build ios --release

# Or use Xcode
open ios/Runner.xcworkspace
# Then Product → Archive
```

### GitHub Actions
The repository includes automated workflows:
- `.github/workflows/flutter-build.yml` - Builds Android APK and iOS on every push
- APK artifacts available in Actions tab after build completes

---

## 🍎 Swift iOS Version (Native Rewrite)

### Prerequisites
- macOS 14.0+
- Xcode 15.0+
- iOS 17.0+ target device/simulator
- Apple Developer account (for device deployment)

### Initial Setup

#### 1. Create Xcode Project
```bash
# Open Xcode
open -a Xcode

# Create New Project:
# - iOS App
# - Product Name: StrawberryManager
# - Interface: SwiftUI
# - Language: Swift
# - Minimum Deployment: iOS 17.0
```

#### 2. Import Source Files
```bash
# From repository root, copy Swift files to Xcode project:
cd StrawberryManager-iOS/

# Drag these folders into Xcode project navigator:
# - Models/
# - ViewModels/
# - Views/
# - Services/
# - Utilities/
# - StrawberryManagerApp.swift

# Ensure "Copy items if needed" is checked
# Select "Create groups" for folders
# Add to target: StrawberryManager
```

#### 3. Configure Project Settings

**General Tab:**
- Display Name: `Strawberry Manager`
- Bundle Identifier: `com.yourname.strawberrymanager`
- Version: `1.0.0`
- Build: `1`
- Minimum Deployments: `iOS 17.0`

**Signing & Capabilities:**
- Team: Select your Apple Developer team
- Bundle Identifier: Must be unique
- Automatically manage signing: ✅

**Build Settings:**
- Swift Language Version: `Swift 5`
- Enable Bitcode: `No`

#### 4. Add App Icon
```bash
# Copy logo to Xcode
# 1. Open Assets.xcassets in Xcode
# 2. Select AppIcon
# 3. Drag assets/logo.png into 1024x1024 slot
# 4. Xcode will generate all required sizes
```

#### 5. Configure Info.plist
Add required keys:
```xml
<key>NSLocalNetworkUsageDescription</key>
<string>Connect to PS4 on local network</string>
<key>NSAppTransportSecurity</key>
<dict>
    <key>NSAllowsArbitraryLoads</key>
    <true/>
</dict>
```

### Build Commands

#### Using Xcode (Recommended)
```bash
# Open project
open StrawberryManager.xcodeproj

# Build for simulator
# 1. Select simulator from device menu
# 2. Product → Build (⌘B)
# 3. Product → Run (⌘R)

# Build for device
# 1. Connect iOS device via USB
# 2. Select device from device menu
# 3. Product → Build (⌘B)
# 4. Product → Run (⌘R)

# Archive for TestFlight/App Store
# 1. Select "Any iOS Device (arm64)"
# 2. Product → Archive
# 3. Wait for build to complete
# 4. Organizer window opens
# 5. Click "Distribute App"
```

#### Using xcodebuild (CI/CD)
```bash
# Build for simulator
xcodebuild \
  -project StrawberryManager.xcodeproj \
  -scheme StrawberryManager \
  -configuration Debug \
  -destination 'platform=iOS Simulator,name=iPhone 15 Pro' \
  build

# Build for device (requires proper code signing)
xcodebuild \
  -project StrawberryManager.xcodeproj \
  -scheme StrawberryManager \
  -configuration Release \
  -destination 'generic/platform=iOS' \
  -archivePath build/StrawberryManager.xcarchive \
  archive

# Export IPA
xcodebuild \
  -exportArchive \
  -archivePath build/StrawberryManager.xcarchive \
  -exportPath build/export \
  -exportOptionsPlist ExportOptions.plist
```

### GitHub Actions
Once Xcode project is committed:
- `.github/workflows/ios-build.yml` - Builds iOS app on every push
- Currently shows setup instructions until `.xcodeproj` is added

---

## 🔄 Comparison: Flutter vs Swift iOS

| Aspect | Flutter | Swift iOS |
|--------|---------|-----------|
| **Build Time** | ~2-5 min | ~3-8 min |
| **App Size** | ~25 MB | ~15 MB |
| **Setup Complexity** | Easy | Medium |
| **Hot Reload** | ✅ Yes | ❌ No |
| **Platforms** | iOS, Android, macOS | iOS only |
| **Code Signing** | Optional for debug | Required for device |
| **CI/CD Ready** | ✅ Yes | ⚠️ Needs Xcode project |

---

## 🚀 Distribution

### TestFlight (iOS)
1. Archive app in Xcode
2. Select "Distribute App"
3. Choose "TestFlight & App Store"
4. Follow upload wizard
5. Manage testers in App Store Connect

### App Store (iOS)
1. Create app in App Store Connect
2. Prepare screenshots, description
3. Archive and upload build
4. Submit for review

### Direct Distribution (Android)
```bash
# Build release APK
flutter build apk --release

# Share APK file
# Location: build/app/outputs/flutter-apk/app-release.apk

# Install with ADB
adb install app-release.apk
```

### Google Play Store (Android)
```bash
# Build app bundle (preferred)
flutter build appbundle --release

# Location: build/app/outputs/bundle/release/app-release.aab
# Upload to Google Play Console
```

---

## 🐛 Troubleshooting

### Flutter Build Issues

**Problem:** `Gradle build failed`
```bash
# Clean and rebuild
flutter clean
flutter pub get
flutter build apk
```

**Problem:** `CocoaPods not found` (iOS)
```bash
sudo gem install cocoapods
cd ios
pod install
cd ..
flutter build ios
```

### Swift iOS Build Issues

**Problem:** `No such module 'Charts'`
- Solution: Charts is a system framework in iOS 16+
- Ensure deployment target is iOS 17.0+
- Clean build folder (Product → Clean Build Folder)

**Problem:** `Code signing error`
```bash
# Option 1: Build for simulator (no signing required)
# Option 2: Configure signing in Xcode
# - Select target → Signing & Capabilities
# - Choose team
# - Enable "Automatically manage signing"
```

**Problem:** `Cannot find 'APIService' in scope`
- Ensure all Swift files are added to target
- Check target membership in File Inspector
- Clean and rebuild

### GitHub Actions Issues

**Problem:** Workflow doesn't trigger
- Check file paths in `on.push.paths`
- Ensure changes are pushed to correct branch
- View Actions tab for errors

**Problem:** iOS build fails
- Requires `.xcodeproj` to be committed
- Cannot build without Xcode project setup
- Follow setup instructions in workflow output

---

## 📊 Build Artifacts

### Flutter Build Outputs
```
build/
├── app/
│   ├── outputs/
│   │   ├── flutter-apk/
│   │   │   └── app-release.apk          # Android APK
│   │   └── bundle/
│   │       └── release/
│   │           └── app-release.aab      # Android Bundle
├── ios/
│   └── iphoneos/
│       └── Runner.app                   # iOS app (unsigned)
```

### Swift iOS Build Outputs
```
build/
├── Build/
│   └── Products/
│       └── Release-iphoneos/
│           └── StrawberryManager.app    # iOS app
├── StrawberryManager.xcarchive/         # Archive
└── export/
    └── StrawberryManager.ipa            # Signed IPA
```

---

## 🔐 Code Signing Setup

### iOS Development Certificate
1. Open Xcode Preferences → Accounts
2. Add Apple ID
3. Download development certificates
4. Xcode manages provisioning automatically

### iOS Distribution Certificate
1. Apple Developer Account required ($99/year)
2. App Store Connect access
3. Create distribution certificate
4. Create App ID matching bundle identifier
5. Create provisioning profile

### Android Keystore
```bash
# Generate keystore
keytool -genkey -v \
  -keystore android-release-key.jks \
  -keyalg RSA -keysize 2048 \
  -validity 10000 \
  -alias release

# Configure in android/key.properties
storePassword=your_store_password
keyPassword=your_key_password
keyAlias=release
storeFile=../android-release-key.jks
```

---

## 📞 Support

- **Flutter Issues:** Check `flutter doctor`
- **iOS Issues:** Check Xcode build logs
- **GitHub Actions:** View workflow logs in Actions tab
- **General:** See README.md files in respective directories
