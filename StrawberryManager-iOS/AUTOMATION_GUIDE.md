# Automated iOS Building Without a Mac

## Important Understanding

**Swift iOS apps fundamentally require Xcode project files to build IPAs.** Even with GitHub Actions (which runs on macOS runners), we need to either:
1. Generate an Xcode project programmatically, OR  
2. Commit a pre-made Xcode project

GitHub Actions **does provide macOS runners** with Xcode, but building a **signed IPA for devices** requires additional setup.

---

## 🤖 What the Automated Workflow Provides

### New Workflow: `ios-build-automated.yml`

**What it does:**
✅ Runs on GitHub's macOS runners (you don't need a Mac!)  
✅ Generates Xcode project automatically from Swift source  
✅ Builds the app  
✅ Creates `.app` bundle  
✅ Uploads artifact for download  

**What it produces:**
- **Simulator Build (.app)** - Can run in iOS Simulator
- **NOT a signed IPA** - Cannot install on physical iPhone yet

---

## 🔐 Why No IPA for Devices?

Building an **IPA that works on physical iPhones** requires:

1. **Apple Developer Account** ($99/year)
2. **Code Signing Certificate** (from Apple Developer portal)
3. **Provisioning Profile** (specific to your app)
4. **Certificate private key** (stored securely)

These are **personal credentials** that can't be publicly shared in a repository.

---

## 🚀 Two Paths Forward

### Path A: Simulator Build (Works Now!) ✅

**Status:** Working right now!

**Steps:**
```bash
# 1. Trigger the workflow
# Go to: https://github.com/KolliasG7/Strawberry-Manager---Reworked/actions
# Click: "iOS Build Automated"
# Click: "Run workflow"
# Select: main branch
# Click: "Run workflow" button

# 2. Wait 5-10 minutes for build

# 3. Download the artifact
# Click on completed workflow run
# Scroll to "Artifacts" section
# Download "ios-simulator-app"

# 4. Test in iOS Simulator (requires Xcode on any Mac, or friend's Mac)
# Unzip downloaded file
# Drag StrawberryManager.app to running iOS Simulator
# App launches!
```

**Limitations:**
- ❌ Cannot install on physical iPhone
- ❌ Cannot distribute via TestFlight
- ✅ Can test all functionality in Simulator

---

### Path B: Signed IPA for Devices (Requires Setup) 📱

**Status:** Needs Apple Developer credentials

**One-Time Setup Steps:**

1. **Get Apple Developer Account:**
   - Sign up at https://developer.apple.com
   - Cost: $99/year
   - Approval: 24-48 hours

2. **Create Certificates:**
   ```bash
   # On any Mac (or borrow a friend's):
   
   # Generate certificate signing request
   # Keychain Access → Certificate Assistant → Request from Certificate Authority
   # Save as: CertificateSigningRequest.certSigningRequest
   
   # Upload to https://developer.apple.com/account/resources/certificates/add
   # Choose: iOS Distribution
   # Download: distribution.cer
   # Convert to .p12:
   # Double-click distribution.cer in Keychain Access
   # Right-click certificate → Export
   # Save as: distribution.p12 (set password)
   ```

3. **Create Provisioning Profile:**
   ```bash
   # Go to: https://developer.apple.com/account/resources/profiles/add
   # Type: Ad Hoc or App Store
   # App ID: Create new with identifier: com.github.strawberrymanager
   # Certificate: Select the one you just created
   # Devices: Select test devices (for Ad Hoc)
   # Download: profile.mobileprovision
   ```

4. **Add Secrets to GitHub:**
   ```bash
   # Go to: GitHub repo → Settings → Secrets → Actions
   
   # Add these secrets:
   # - CERTIFICATE_P12: (base64 of distribution.p12)
   # - CERTIFICATE_PASSWORD: (password you set)
   # - PROVISIONING_PROFILE: (base64 of profile.mobileprovision)
   # - APPLE_DEVELOPER_TEAM_ID: (find in developer account)
   
   # To base64 encode:
   base64 -i distribution.p12 | pbcopy
   base64 -i profile.mobileprovision | pbcopy
   ```

5. **Enable Signed Build:**
   - The workflow will detect secrets and automatically build signed IPA
   - No code changes needed!

---

## 📋 Updated Workflow (Already Created)

The new `ios-build-automated.yml` workflow:

✅ **Works NOW (Simulator Build):**
- No setup required
- Generates Xcode project automatically
- Builds .app for Simulator
- Downloadable from Actions artifacts

✅ **Will Work Later (Device Build):**
- Once you add GitHub secrets (Apple certificates)
- Automatically produces signed IPA
- Can install on physical iPhone
- Can upload to TestFlight

---

## 🎯 Quick Start (No Mac Needed!)

### Try It Now:

1. **Go to GitHub Actions:**
   ```
   https://github.com/KolliasG7/Strawberry-Manager---Reworked/actions/workflows/ios-build-automated.yml
   ```

2. **Click "Run workflow"**
   - Branch: main
   - Build type: debug
   - Click green "Run workflow"

3. **Wait ~8-10 minutes**
   - Workflow generates Xcode project
   - Builds app
   - Creates artifact

4. **Download Result:**
   - Click on completed run
   - Download "ios-simulator-app" artifact
   - Contains: StrawberryManager.app + BUILD_INFO.txt

5. **Test:**
   - Need access to any Mac with Xcode
   - Or: Use friend's Mac
   - Or: Use cloud Mac (MacStadium, MacinCloud)
   - Drag .app to iOS Simulator

---

## ⚡ For Signed IPA (Optional - Later)

When ready to build for physical devices:

1. Get Apple Developer account
2. Generate certificates (one-time, can use cloud Mac)
3. Add secrets to GitHub
4. Re-run workflow
5. Download **signed IPA** from artifacts
6. Install on iPhone or upload to TestFlight

---

## 🎁 What You Have Right Now

### Without Any Setup:
✅ Complete Swift source code (30 files)  
✅ GitHub Actions workflow that **generates Xcode project**  
✅ Automated **Simulator builds** (no Mac needed!)  
✅ Downloadable .app from every workflow run  

### With Apple Developer Setup:
✅ Automated **signed IPA builds**  
✅ TestFlight distribution  
✅ App Store submission  

---

## Summary

The new workflow **auto-generates the Xcode project** and builds a Simulator app **entirely in GitHub Actions**. You don't need a Mac to trigger builds - just use the GitHub web interface!

The .app file it produces can be tested on any Mac's iOS Simulator. For physical iPhones, you'll need Apple Developer credentials (one-time setup), which can also be done through GitHub Actions after you provide the certificates.

Try it now: https://github.com/KolliasG7/Strawberry-Manager---Reworked/actions