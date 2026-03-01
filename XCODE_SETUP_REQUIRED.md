# 🔧 Xcode Setup Required - Add New Files

## ⚠️ Current Issue

Xcode is showing compilation errors because it doesn't know about the new Swift files we created. We need to add them to the Xcode project.

**Errors:**
```
Cannot find 'DatabaseManager' in scope
```

**Cause**: Files created outside Xcode aren't automatically added to the build target.

---

## ✅ **Fix: Add Files to Xcode** (2 minutes)

### Step 1: In Xcode Navigator
1. Look at the left sidebar (Project Navigator)
2. Find the **iosApp** folder (blue icon)
3. You should see existing files like:
   - Switch2GoApp.swift ✅
   - ContentView.swift ✅
   - Views/ folder ✅
   - Camera/ folder ✅

### Step 2: Add New Directories
We need to add these NEW directories:

**Right-click on `iosApp` folder → "Add Files to 'iosApp'..."**

Add these folders **one at a time**:

1. **Data/** folder
   - Navigate to: `iosApp/iosApp/Data/`
   - Select the **Data** folder
   - ✅ Check "Copy items if needed"
   - ✅ Check "Create groups"
   - ✅ Select target: **iosApp**
   - Click "Add"

2. **Utils/** folder
   - Navigate to: `iosApp/iosApp/Utils/`
   - Select the **Utils** folder
   - Same checkboxes as above
   - Click "Add"

3. **ViewModels/** folder
   - Navigate to: `iosApp/iosApp/ViewModels/`
   - Select the **ViewModels** folder
   - Same checkboxes
   - Click "Add"

4. **Update Views/** folder
   - You already have a Views/ folder
   - But we need to add new subfolders
   - Right-click **Views** → "Add Files to 'iosApp'..."
   - Navigate to `iosApp/iosApp/Views/`
   - Select ALL these folders:
     - OutputBar/
     - Categories/
     - Phrases/
     - Keyboard/
     - NumberPad/
     - EmptyStates/
     - (Settings/ - if not already there)
   - Click "Add"

5. **Resources/** folder (localization)
   - Navigate to: `iosApp/iosApp/Resources/`
   - Select the **Resources** folder
   - Click "Add"

### Step 3: Verify Files Added
After adding, your Project Navigator should show:
```
iosApp/
├── Switch2GoApp.swift
├── ContentView.swift
├── Info.plist
├── Data/ ← NEW
│   ├── DatabaseManager.swift
│   └── Models/
│       └── PhraseStyleExtensions.swift
├── Utils/ ← NEW
│   ├── AppSettings.swift
│   ├── TTSManager.swift
│   ├── AccessibilityHelpers.swift
│   ├── LocalizationHelper.swift
│   ├── PerformanceMonitor.swift
│   └── ImageCache.swift
├── ViewModels/ ← NEW
│   ├── CategoriesViewModel.swift
│   └── PhrasesViewModel.swift
├── Views/
│   ├── OutputBar/ ← NEW
│   ├── Categories/ ← NEW
│   ├── Phrases/ ← NEW
│   ├── Keyboard/ ← NEW
│   ├── NumberPad/ ← NEW
│   ├── EmptyStates/ ← NEW
│   ├── Settings/ (updated)
│   ├── Calibration/ (existing)
│   └── AAC/ (existing)
├── Tracking/
├── Camera/
├── MediaPipe/
├── Resources/ ← NEW
│   ├── en.lproj/
│   ├── es.lproj/
│   └── fr.lproj/
└── Assets.xcassets/
```

### Step 4: Build Again
- **Cmd+Shift+K** (Clean Build Folder)
- **Cmd+B** (Build)
- Should compile successfully now!

---

## 🎯 **Alternative: Drag and Drop Method**

If "Add Files" is confusing:

1. Open **Finder**
2. Navigate to `/Users/user289033/Switch2GO_AAC_iPadOS/iosApp/iosApp/`
3. See all the folders: Data/, Utils/, ViewModels/, etc.
4. **Drag each folder** from Finder into Xcode's Project Navigator
5. Drop onto the **iosApp** group (blue folder icon)
6. In the popup:
   - ✅ Check "Copy items if needed"
   - ✅ Check "Create groups"
   - ✅ Select target: **iosApp**
   - Click "Finish"

---

## 🔍 **Verify Files Are in Build Target**

After adding files:

1. Select any new Swift file (e.g., DatabaseManager.swift) in Navigator
2. Look at **File Inspector** on the right (sidebar)
3. Under "Target Membership":
   - ✅ **iosApp** should be checked
   - ✅ **iosAppTests** optional

If not checked, check the box!

---

## 📝 **Why This Happened**

When we created files via terminal/code, they were saved to disk but not added to the Xcode project file (.xcodeproj). Xcode needs to know:
- Which files to compile
- Which targets they belong to
- How to organize them

This is a one-time setup step.

---

## ✅ **After Adding Files**

The errors should disappear:
- ✅ `DatabaseManager` will be found
- ✅ All imports will resolve
- ✅ Build will succeed

Then **Cmd+R** will launch the app!

---

## 🚀 **Quick Checklist**

- [ ] Add Data/ folder to Xcode
- [ ] Add Utils/ folder to Xcode
- [ ] Add ViewModels/ folder to Xcode
- [ ] Add new Views/ subfolders to Xcode
- [ ] Add Resources/ folder to Xcode
- [ ] Clean Build Folder (Cmd+Shift+K)
- [ ] Build (Cmd+B)
- [ ] Run (Cmd+R)

---

**Once files are added, the app will compile and run!**
