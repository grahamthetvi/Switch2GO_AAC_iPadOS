# iOS Quick Start Guide

## Get Running in 5 Minutes

### Step 1: Prerequisites (1 minute)
```bash
# Check Java
java -version  # Need 17+

# Install CocoaPods if needed
sudo gem install cocoapods
```

### Step 2: Build (2 minutes)
```bash
./build_ios.sh
```

### Step 3: Open in Xcode (1 minute)
```bash
open iosApp/iosApp.xcworkspace
```

### Step 4: Run (1 minute)
1. Select **iPhone 15 Pro** or **iPad Pro** simulator
2. Press **Cmd+R**
3. App launches! 🎉

---

## First Launch Experience

### What You'll See:
1. **Calibration prompt** - Skip for now (needs device)
2. **Categories screen** - 7 preset categories
3. **Tap any category** - See phrases
4. **Tap any phrase** - Hear it spoken via TTS

### Try These Features:
- **Settings** → CVI Display Settings → Change symbol count
- **Settings** → Edit Categories & Phrases → Customize content
- **Phrases** → Long press → Edit Style → Make it beautiful!
- **Swipe left/right** when viewing phrases

---

## Device Testing (Physical iPad Required)

### Why Device?
- Simulator doesn't have camera
- Eye tracking needs real camera feed
- Calibration requires gaze detection

### To Test on Device:
1. Connect iPad via USB
2. Trust computer on iPad
3. Select iPad in Xcode
4. Build & Run (Cmd+R)
5. Grant camera permission
6. Complete calibration
7. Use hands-free!

---

## What Works Right Now

### ✅ Working in Simulator:
- All UI screens and navigation
- Categories and phrases
- Text-to-speech
- Settings configuration
- Database operations
- Custom categories/phrases
- Phrase styling
- Swipe navigation
- Output bar

### ⚠️ Needs Physical Device:
- Camera capture
- Eye gaze tracking
- Face tracking
- Calibration with real data

---

## Common Issues

### "No such module 'VocableShared'"
```bash
./gradlew :shared:linkDebugFrameworkIosSimulatorArm64
```

### "No such module 'MediaPipeTasksVision'"
```bash
cd iosApp
pod install
cd ..
```

### Build fails
```bash
./gradlew clean
rm -rf iosApp/Pods
./build_ios.sh
```

---

## Next Steps

1. ✅ **Explore the app in simulator** - All UI works!
2. ✅ **Try customization features** - Change colors, styles, settings
3. ✅ **Create custom phrases** - Use the keyboard
4. ⏭️ **Test on device** - Experience real eye tracking
5. ⏭️ **Complete camera integration** - Wire up the final pieces

---

## File Guide

### Where Things Are:
- **Main UI**: `iosApp/iosApp/Views/`
- **Database**: `shared/src/commonMain/sqldelight/`
- **Settings**: `iosApp/iosApp/Utils/AppSettings.swift`
- **TTS**: `iosApp/iosApp/Utils/TTSManager.swift`
- **Tests**: `iosApp/iosAppTests/`

### Key Files to Know:
- `ContentView.swift` - Main app container
- `CategoriesView.swift` - Home screen
- `PhrasesView.swift` - Phrase grid
- `PhraseStyleEditorView.swift` - Style customization
- `DatabaseManager.swift` - Database initialization

---

## Help & Support

**Questions?**
- Check `BUILD_AND_RUN.md` for detailed instructions
- Check `IMPLEMENTATION_COMPLETE.md` for full feature list
- Check `TESTING_GUIDE.md` for testing procedures

**Need Help?**
- Email: grahamthetvi@icloud.com
- Review console logs in Xcode

---

**You're ready to go!** 🚀

The iOS app has everything your Android app has, plus iOS-native polish.

Enjoy building accessible communication tools for CVI students! 💙
