@echo off
echo Fixing iOS app icons with custom logo...
echo.

REM Make sure we're in the project directory
cd /d "%~dp0"

REM Clean dependencies and reinstall
echo Cleaning and reinstalling dependencies...
flutter clean
flutter pub get

REM Run flutter launcher icons generation with proper configuration
echo Generating iOS icons from custom logo...
flutter pub run flutter_launcher_icons:main

REM Verify icons were generated
echo.
echo Checking if icons were generated...
if exist "ios\Runner\Assets.xcassets\AppIcon.appiconset\Icon-App-1024x1024@1x.png" (
    echo SUCCESS: Icons generated successfully!
    echo Your custom logo.png has been used to create iOS app icons.
) else (
    echo ERROR: Icons were not generated properly.
    echo Please check:
    echo 1. assets/logo.png exists
    echo 2. pubspec.yaml flutter_launcher_icons configuration
    echo 3. Flutter is properly installed
)

echo.
echo Next steps:
echo 1. Rebuild your iOS app: flutter build ios
echo 2. Sideload the new IPA to your iPhone
echo 3. The app should now show your custom logo
echo.

pause
