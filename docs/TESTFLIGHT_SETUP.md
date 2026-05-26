# Reconnect iOS TestFlight Setup Guide

## Prerequisites

Before you can build and publish to TestFlight, you need:

1. **Apple Developer Account** - Active with paid membership ($99/year)
2. **Xcode** - Latest version installed
3. **App Store Connect Access** - Create your app in App Store Connect
4. **iOS Certificates & Provisioning Profiles** - Set up code signing

## Step 1: Create App in App Store Connect

1. Go to [App Store Connect](https://appstoreconnect.apple.com)
2. Click "My Apps" → "+" → "New App"
3. Fill in details:
   - **Name**: Reconnect
   - **Primary Language**: English
   - **iOS App Bundle ID**: Use reverse domain format, e.g., `com.yourcompany.reconnect`
   - **SKU**: Create a unique identifier
   - **User Access**: Select access level

4. Save the **Bundle ID** - you'll need this for code signing

## Step 2: Configure Xcode Project Settings

### 2.1 Update Bundle Identifier

1. Open `ios/Runner.xcworkspace` in Xcode
2. Select "Runner" project in left panel
3. Select "Runner" target
4. Go to "Signing & Capabilities" tab
5. Set **Bundle Identifier** to your App Store Connect Bundle ID
6. Under **Team**, select your Apple Developer Team

### 2.2 Set Version and Build Number

1. In Xcode, select "Runner" target
2. Go to "General" tab
3. Update:
   - **Version**: Should match `pubspec.yaml` version (e.g., 0.1.0)
   - **Build**: Increment for each TestFlight build (starts at 1)

## Step 3: Set Up Code Signing

### 3.1 Create Signing Certificate

1. Open Xcode Preferences: `Xcode` → `Preferences` → `Accounts`
2. Click "Manage Certificates"
3. Click "+" → Select "iOS Distribution"
4. Xcode will create the certificate automatically (or use existing)

### 3.2 Create Provisioning Profile

1. Go to [Apple Developer Certificates](https://developer.apple.com/account/resources/certificates/list)
2. Click "+" to create new certificate
3. Select "Apple Distribution"
4. Upload Certificate Signing Request (CSR) from Xcode
5. Download and install the certificate

### 3.3 Configure in Xcode

1. Open `ios/Runner.xcworkspace`
2. Select "Runner" project → "Runner" target
3. Go to "Signing & Capabilities"
4. Ensure:
   - **Team** is set correctly
   - **Signing Certificate** shows "Apple Distribution"
   - **Provisioning Profile** is automatically managed

## Step 4: Build for TestFlight

### 4.1 Using Flutter CLI (Recommended)

```bash
# Set production environment
flutter build ios --release \
  -d "FLAVOR=prod" \
  --build-name=0.1.0 \
  --build-number=1

# Or using the build script
./scripts/build_testflight.sh 0.1.0 1
```

### 4.2 Using Xcode

1. Open `ios/Runner.xcworkspace`
2. Select "Runner" scheme
3. Set build configuration to "Release"
4. Product → Archive
5. Wait for the archive to complete
6. Xcode Organizer will open - select your archive
7. Click "Distribute App" → "TestFlight"

## Step 5: Upload to TestFlight

### Option A: Automatic with Transporter Script

```bash
# Build and upload automatically
./scripts/upload_to_testflight.sh 0.1.0 1
```

### Option B: Manual with Xcode

1. Open Xcode Organizer (Window → Organizer)
2. Select your archive
3. Click "Distribute App"
4. Choose "TestFlight"
5. Select your team and app
6. Follow the wizard

### Option C: Manual with Transporter App

1. Download [Apple Transporter](https://apps.apple.com/app/transporter/id1450874784)
2. Build archive from Xcode
3. Export the .ipa file
4. Drag and drop into Transporter
5. Click "Deliver"

## Step 6: Invite Testers

1. Go to [App Store Connect](https://appstoreconnect.apple.com)
2. Select your app → TestFlight
3. Click "Internal Testing"
4. Add testers:
   - Email addresses of your friends
   - Enter their Apple IDs (must have existing iTunes accounts)
5. Click "Add"
6. Testers will receive TestFlight invitation email

## Step 7: Testers Install the App

Your friends should:

1. Install TestFlight app from App Store
2. Check email for TestFlight invitation
3. Tap the link in the email or search for "Reconnect" in TestFlight
4. Tap "Install" to download the app

## Troubleshooting

### Common Issues

**"Certificate is not trusted"**
- Make sure you created distribution certificate, not development
- Check that certificate is installed in Keychain (Applications → Utilities → Keychain Access)

**"Code Signing Error"**
- Ensure team is set in Xcode
- Check provisioning profile is still valid in Apple Developer account
- Renew certificate if needed

**"App rejected by App Store Connect"**
- Check app version is higher than previous submission
- Verify build number is unique
- Ensure code signing is valid

**Testers Not Receiving Invitation**
- Confirm email is correct
- Check email hasn't been added to external test group already
- Resend invitation from TestFlight dashboard

## Continuous Releases

For regular TestFlight builds:

1. Update version in `pubspec.yaml`
2. Update build number
3. Commit code changes
4. Run: `./scripts/build_testflight.sh {VERSION} {BUILD_NUMBER}`
5. Test build in TestFlight
6. Add testers as needed

## Next Steps

- Set up GitHub Actions for automated builds (optional)
- Prepare App Store screenshots and description for final release
- Plan beta testing feedback process
