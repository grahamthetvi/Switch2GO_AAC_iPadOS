---
name: iOS Full Feature Parity
overview: Implement complete feature parity between iOS and Android Switch2Go AAC apps, including database persistence, categories/phrases management, advanced settings, and all UI screens using shared Kotlin Multiplatform module.
todos:
  - id: phase1-sqldelight
    content: Add SQLDelight to shared module with database schema
    status: completed
  - id: phase1-models
    content: Create shared data models (Category, Phrase, repositories)
    status: completed
  - id: phase1-presets
    content: Populate preset categories and phrases data
    status: completed
  - id: phase2-db-init
    content: Initialize database in iOS app
    status: completed
  - id: phase2-viewmodels
    content: Create ViewModels for categories, phrases, settings
    status: completed
  - id: phase3-categories
    content: Implement CategoriesView (home screen)
    status: completed
  - id: phase3-phrases
    content: Implement PhrasesView
    status: completed
  - id: phase3-keyboard
    content: Implement KeyboardView for custom phrases
    status: completed
  - id: phase3-navigation
    content: Update ContentView with proper navigation
    status: completed
  - id: phase4-settings-main
    content: Implement main SettingsView with all options
    status: completed
  - id: phase4-edit-categories
    content: Implement Edit Categories screens
    status: completed
  - id: phase4-edit-phrases
    content: Implement Edit Phrases screens
    status: completed
  - id: phase4-timing
    content: Implement Timing & Sensitivity settings
    status: completed
  - id: phase4-selection-mode
    content: Implement Selection Mode settings
    status: completed
  - id: phase4-advanced-eye
    content: Implement Advanced Eye Tracking settings
    status: completed
  - id: phase4-cvi
    content: Implement CVI Display settings
    status: completed
  - id: phase4-phrase-style
    content: Implement PhraseStyleEditorView (colors, size, images, emoji)
    status: completed
  - id: phase4-color-picker
    content: Create reusable ColorPickerView component
    status: completed
  - id: phase4-reset-app
    content: Implement Reset App with two-step confirmation
    status: completed
  - id: phase3-output-bar
    content: Create OutputBarView for phrase composition
    status: completed
  - id: phase3-swipe-navigation
    content: Add swipe gesture navigation for pages
    status: completed
  - id: phase3-empty-states
    content: Implement empty state views for all screens
    status: completed
  - id: phase5-tts
    content: Create TTSManager with voice/rate/volume control
    status: completed
  - id: phase6-recents
    content: Implement Recent Phrases view
    status: completed
  - id: phase6-mysayings
    content: Implement My Sayings custom category
    status: completed
  - id: phase7-calibration
    content: Enhance calibration with validation and profiles
    status: completed
  - id: phase8-localization
    content: Add internationalization support
    status: completed
  - id: phase9-accessibility
    content: Add VoiceOver, Switch Control, Dynamic Type support
    status: completed
  - id: phase10-testing
    content: Write unit and UI tests
    status: completed
  - id: phase10-polish
    content: Performance optimization and UI polish
    status: completed
---

# iOS Feature Parity Implementation Plan

## Overview

This plan implements complete feature parity between the iOS and Android Switch2Go AAC apps. The Android app is a mature, feature-rich AAC application with comprehensive category/phrase management, advanced eye tracking settings, and full data persistence. The iOS app currently has only basic UI scaffolding.

## Architecture Strategy

- **Shared Database Layer**: Extend [`shared/`](shared/) KMP module with SQLDelight database (equivalent to Android's Room)
- **Business Logic**: Move category/phrase use cases to shared module
- **Platform-Specific UI**: Implement SwiftUI views matching Android's Fragment-based UI
- **Data Consistency**: Ensure both platforms use identical database schemas and business logic

## Phase 1: Shared Database Layer (Foundation)

### Add SQLDelight to Shared Module

**Files to modify:**

- [`shared/build.gradle.kts`](shared/build.gradle.kts) - Add SQLDelight plugin and dependencies
- Create `shared/src/commonMain/sqldelight/` directory structure

**Database Schema** (based on Android Room schema):

```sql
-- Category.sq
CREATE TABLE Category (
  category_id TEXT NOT NULL PRIMARY KEY,
  creation_date INTEGER NOT NULL,
  localized_name TEXT NOT NULL,  
  hidden INTEGER NOT NULL DEFAULT 0,
  sort_order INTEGER NOT NULL
);

-- Phrase.sq  
CREATE TABLE Phrase (
  phrase_id TEXT NOT NULL PRIMARY KEY,
  parent_category_id TEXT,
  creation_date INTEGER NOT NULL,
  last_spoken_date INTEGER,
  localized_utterance TEXT,
  sort_order INTEGER NOT NULL,
  style TEXT DEFAULT NULL
);

-- PresetCategory.sq
CREATE TABLE PresetCategory (
  category_id TEXT NOT NULL PRIMARY KEY,
  hidden INTEGER NOT NULL DEFAULT 0,
  sort_order INTEGER NOT NULL,
  deleted INTEGER NOT NULL DEFAULT 0
);

-- PresetPhrase.sq
CREATE TABLE PresetPhrase (
  phrase_id TEXT NOT NULL PRIMARY KEY,
  parent_category_id TEXT NOT NULL,
  creation_date INTEGER NOT NULL,
  last_spoken_date INTEGER,
  sort_order INTEGER NOT NULL,
  deleted INTEGER NOT NULL DEFAULT 0,
  style TEXT DEFAULT NULL
);
```

**Queries to implement:**

- `getAllCategories()`, `getCategoryById()`, `insertCategory()`, `updateCategory()`, `deleteCategory()`
- `getPhrasesForCategory()`, `getRecentPhrases()`, `insertPhrase()`, `updatePhrase()`, `deletePhrase()`
- Preset management queries

### Create Shared Data Models

**New files in** [`shared/src/commonMain/kotlin/com/vocable/data/`](shared/src/commonMain/kotlin/):

- `models/Category.kt` - Category data class
- `models/Phrase.kt` - Phrase data class with style enum
- `models/PresetCategories.kt` - Enum of preset categories (General, Basic Needs, Personal Care, Conversation, Environment, User Keypad, Recents)
- `repository/CategoryRepository.kt` - Interface
- `repository/PhraseRepository.kt` - Interface  
- `repository/impl/CategoryRepositoryImpl.kt` - SQLDelight implementation
- `repository/impl/PhraseRepositoryImpl.kt` - SQLDelight implementation

### Preset Data Population

**New file:** `shared/src/commonMain/kotlin/com/vocable/data/PresetData.kt`

Populate with all preset categories and phrases from Android:

- **General**: Please, Thank you, Yes, No, Maybe, Please wait, I don't know, I didn't mean say that, Be patient
- **Basic Needs**: Need restroom, I'm thirsty, I'm hungry, I'm cold, I'm hot, I'm tired, I'm fine, I'm good, I'm uncomfortable, I'm in pain, I'm finished, Want lie down, Want sit up
- **Personal Care**: Need medication, Need bath, Need shower, Need wash face, Want brush hair, Fix pillow, Need spit, Trouble breathing, Need jacket
- **Conversation**: Hello, Good morning, Good evening, Pleased to meet you, How is day, How are you, How is it going, How was your weekend, Goodbye, Okay, Bad, Good, That makes sense, I like it, Please stop, I do not agree, Please repeat
- **Environment**: Turn on lights, Turn off lights, No visitors, Like visitors, Be quiet, Like to talk, TV on, TV off, Volume up, Volume down, Open blinds, Close blinds, Open window, Close window
- **User Keypad**: 0-9, Yes, No

## Phase 2: iOS Data Layer Integration

### Database Initialization

**Files to create:**

- `iosApp/iosApp/Data/DatabaseManager.swift` - Wrapper for VocableShared database
- `iosApp/iosApp/Data/Models/` - Swift extensions for shared models

**Modify:**

- [`iosApp/iosApp/Switch2GoApp.swift`](iosApp/iosApp/Switch2GoApp.swift) - Initialize database in AppState
- Update AppState to include repositories
```swift
class AppState: ObservableObject {
    let storage: Storage
    let logger: Logger
    let categoryRepository: CategoryRepository
    let phraseRepository: PhraseRepository
    let database: VocableDatabase
    
    // ... existing code ...
}
```


### Create View Models

**New files in** `iosApp/iosApp/ViewModels/`:

- `CategoriesViewModel.swift` - Manages category list, filters
- `PhrasesViewModel.swift` - Manages phrases for a category
- `RecentsViewModel.swift` - Recent phrases logic
- `KeyboardViewModel.swift` - Custom phrase input
- `SettingsViewModel.swift` - Settings state management

## Phase 3: Main UI Implementation

### Categories Screen (Home)

**Create:** `iosApp/iosApp/Views/Categories/CategoriesView.swift`

Features:

- Grid of category buttons (matching Android's [`CategoriesFragment.kt`](app/src/main/java/com/switch2connect/aac/presets/CategoriesFragment.kt))
- Category icons/colors
- Hidden categories filtered out
- Dwell selection support
- Navigation to phrases view
- Output bar at top

**Supporting views:**

- `CategoryButtonView.swift` - Individual category button with hover state
- `OutputBarView.swift` - Update existing to support phrase composition

### Phrases Screen

**Create:** `iosApp/iosApp/Views/Phrases/PhrasesView.swift`

Features:

- Grid of phrase buttons for selected category
- Back button to categories
- Output bar with phrase composition
- Recent phrases support
- Dwell selection
- TTS on phrase selection
- Add phrase button (for custom category)

**Reference:** Android [`PhrasesFragment.kt`](app/src/main/java/com/switch2connect/aac/presets/PhrasesFragment.kt)

### Keyboard View

**Create:** `iosApp/iosApp/Views/Keyboard/KeyboardView.swift`

Features:

- QWERTY keyboard layout
- Letter buttons with dwell support
- Backspace, clear, space buttons
- Output preview
- Save phrase button
- Similar to Android [`KeyboardFragment.kt`](app/src/main/java/com/switch2connect/aac/keyboard/KeyboardFragment.kt)

### Number Pad View

**Create:** `iosApp/iosApp/Views/NumberPad/NumberPadView.swift`

Features:

- 0-9 buttons in grid
- Yes/No buttons
- Matches Android [`NumberPadFragment.kt`](app/src/main/java/com/switch2connect/aac/presets/NumberPadFragment.kt)

### Output Bar ⭐ NEW - CRITICAL

**Create:** `iosApp/iosApp/Views/OutputBar/OutputBarView.swift`

The Output Bar is the top bar that shows composed phrases and controls speech. It's persistent across all screens.

Features:

- **Composed Text Display**: Shows concatenated selected phrases
- **Placeholder Text**: "Select something" when empty
- **Speak Button**: Triggers TTS to read composed text aloud
- **Clear Button**: Clears composed text
- **Speaker Icon**: Animated indicator when TTS is speaking
- **Persistent State**: Maintains text across navigation (Categories → Phrases → Keyboard)

Reference: Android's output bar in [`PresetsFragment.kt`](app/src/main/java/com/switch2connect/aac/presets/PresetsFragment.kt) lines 489-498

### Swipe Navigation ⭐ NEW

**Update:** `PhrasesView` and supporting views

Android has swipe gesture navigation for paginating through phrases when there are more than the symbol count allows.

Features:

- **Swipe Left**: Go to next page of phrases
- **Swipe Right**: Go to previous page of phrases
- **Page Indicator**: "Page X of Y" label
- **Hint Text**: "Swipe for more" when multiple pages exist
- **Smooth Animations**: Page transitions with animation
- **Touch Detection**: Only respond to finger touch, not gaze cursor

**Implementation:**

- Use SwiftUI `.gesture(DragGesture())` modifier
- Calculate total pages: `(phraseCount + symbolCount - 1) / symbolCount`
- Track current page index
- Update displayed phrases on swipe

Reference: [`PresetsFragment.kt`](app/src/main/java/com/switch2connect/aac/presets/PresetsFragment.kt) lines 279-332

### Empty States ⭐ NEW

**Create:** `iosApp/iosApp/Views/EmptyStates/` directory

Android has specific empty state UIs for better user experience.

**Files to create:**

`EmptyPhrasesView.swift` - When custom category has no phrases

- "No phrases yet" message
- Large "Add Phrase" button
- Icon (speech bubble)

`EmptyRecentsView.swift` - When no phrases have been spoken

- Clock icon
- "No recent phrases" title
- "Select phrases to see them here" message

`EmptyCategoriesView.swift` - When all categories are hidden

- "All categories are hidden" message
- "Go to Settings to show categories" hint
- Settings navigation button

Reference: [`PresetsFragment.kt`](app/src/main/java/com/switch2connect/aac/presets/PresetsFragment.kt) lines 570-584, `MySayingsEmptyFragment.kt`

### Navigation Updates

**Modify:** [`iosApp/iosApp/ContentView.swift`](iosApp/iosApp/ContentView.swift)

Replace existing [`AACGridView`](iosApp/iosApp/Views/AAC/AACGridView.swift) with proper navigation:

- CategoriesView as root (with OutputBar at top)
- NavigationStack for Categories → Phrases → Keyboard
- Maintain gaze tracking overlay across navigation
- OutputBar always visible at top
- Settings accessible from all screens

## Phase 4: Settings Implementation

### Main Settings Screen

**Update:** [`iosApp/iosApp/Views/Settings/SettingsView.swift`](iosApp/iosApp/Views/Settings/SettingsView.swift)

Current settings are placeholder. Implement:

1. **Edit Categories & Phrases** - Navigation to management screens
2. **Timing & Sensitivity** - Hover time, cursor sensitivity
3. **Selection Mode** - Face tracking vs Eye gaze toggle
4. **Advanced Eye Tracking** - GPU, 2D/3D mode, smoothing
5. **Reset App** - Clear all data with confirmation
6. **Privacy Policy** - WebView
7. **Contact Developer** - mailto link

Reference Android [`SettingsFragment.kt`](app/src/main/java/com/switch2connect/aac/settings/SettingsFragment.kt)

### Edit Categories

**Create:** `iosApp/iosApp/Views/Settings/EditCategories/`

- `EditCategoriesListView.swift` - List of all categories
- `EditCategoryDetailView.swift` - Show/hide toggle, rename, delete
- `ReorderCategoriesView.swift` - Drag to reorder sort order

Features:

- Show/hide toggle for each category
- Reorder categories (drag and drop)
- Cannot delete preset categories, only hide them
- Can delete custom user categories

Reference: [`EditCategoriesFragment.kt`](app/src/main/java/com/switch2connect/aac/settings/EditCategoriesFragment.kt), [`EditCategoriesListFragment.kt`](app/src/main/java/com/switch2connect/aac/settings/EditCategoriesListFragment.kt)

### Edit Phrases

**Create:** `iosApp/iosApp/Views/Settings/EditPhrases/`

- `EditCategoryPhrasesView.swift` - List phrases for a category
- `EditPhraseView.swift` - Edit phrase text, style, delete
- `AddPhraseView.swift` - Add new custom phrase

Features:

- Edit phrase text (custom phrases only)
- Delete custom phrases
- Reorder phrases
- Add new phrases
- Phrase styling (future: color, size options)

Reference: [`EditCategoryPhrasesFragment.kt`](app/src/main/java/com/switch2connect/aac/settings/EditCategoryPhrasesFragment.kt), [`PhraseEditMenuFragment.kt`](app/src/main/java/com/switch2connect/aac/settings/PhraseEditMenuFragment.kt)

### Timing & Sensitivity Settings

**Create:** `iosApp/iosApp/Views/Settings/TimingSensitivityView.swift`

Features:

- **Hover Time**: Slider 0.5s - 5.0s (how long to dwell before selection)
- **Cursor Sensitivity**: Low/Medium/High buttons (pointer movement speed)
- Save to shared storage

Reference: [`SensitivityFragment.kt`](app/src/main/java/com/switch2connect/aac/settings/SensitivityFragment.kt)

### Selection Mode Settings

**Create:** `iosApp/iosApp/Views/Settings/SelectionModeView.swift`

Features:

- Toggle between:
  - **Head Tracking** (Face detection based, currently "Face tracking" in Android)
  - **Eye Gaze Tracking** (Iris-based gaze tracking)
- Requires camera permission check
- Show current mode status

Reference: [`SelectionModeFragment.kt`](app/src/main/java/com/switch2connect/aac/settings/selectionmode/SelectionModeFragment.kt)

### Advanced Eye Tracking Settings

**Create:** `iosApp/iosApp/Views/Settings/AdvancedEyeTrackingView.swift`

Features:

- **Use GPU Toggle**: Enable/disable GPU acceleration for MediaPipe
- **Tracking Method**: 
  - 2D Iris Tracking (faster, less accurate)
  - 3D Eyeball Tracking (slower, more accurate)
- **Smoothing Mode**:
  - None (no smoothing)
  - Simple (LERP interpolation)
  - Kalman Filter (standard Kalman)
  - Adaptive Kalman Filter (velocity-adaptive, recommended)
  - Combined (Kalman + LERP)
- **Eye Selection**:
  - Both Eyes (average of left and right)
  - Left Eye Only
  - Right Eye Only
- **Reset Calibration** button

Reference: [`AdvancedEyeTrackingFragment.kt`](app/src/main/java/com/switch2connect/aac/settings/AdvancedEyeTrackingFragment.kt)

**Modify:** [`iosApp/iosApp/Tracking/GazeTrackingManager.swift`](iosApp/iosApp/Tracking/GazeTrackingManager.swift) to support these modes

### CVI Display Settings

**Create:** `iosApp/iosApp/Views/Settings/CVIDisplaySettingsView.swift`

Features (for users with Cortical Visual Impairment):

- **Symbol Count Picker**: Adjustable from 2-9 symbols per page (THE defining CVI feature)
  - +/- stepper buttons
  - Current count display
  - Layout preview description
  - Reduces visual complexity for CVI users
- **Per-Position Color Customization**: Set custom colors for each of 9 symbol positions
  - Position 1 (top-left): Default Red
  - Position 2 (top-right): Default Blue
  - Position 3 (bottom-left): Default Green
  - Position 4 (bottom-right): Default Orange
  - Position 5 (center): Default Purple
  - Positions 6-9: Cyan, Pink, Yellow, Grey
  - Color picker for each position
  - Preview current colors
  - Reset to defaults button
- **Save to UserDefaults**: Persist symbol count and per-position colors

Reference: [`CVIDisplaySettingsFragment.kt`](app/src/main/java/com/switch2connect/aac/settings/CVIDisplaySettingsFragment.kt), [`VocableSharedPreferences.kt`](app/src/main/java/com/switch2connect/aac/utils/VocableSharedPreferences.kt)

**Storage Keys:**

- `symbolCount` (Int, 2-9, default 2)
- `symbolColor1` through `symbolColor9` (UInt32 color values)

### Phrase Style Editor ⭐ CRITICAL CVI FEATURE

**Create:** `iosApp/iosApp/Views/Settings/PhraseStyleEditorView.swift`

This is a **major feature** completely missing from the original plan. Android's `PhraseStyleEditorFragment` (519 lines) allows per-phrase customization for CVI users.

Features:

- **Background Color**: 19 color options (Red, Blue, Green, Orange, Purple, Cyan, Pink, Yellow, Grey, Teal, Brown, Lime, Indigo, Amber, Deep Purple, Black, White, Light Gray, Dark Gray)
- **Text Color**: Same 19 color options
- **Text Size**: 7 size options (12sp, 16sp, 18sp, 22sp, 26sp, 32sp, 40sp)
- **Bold Toggle**: Enable/disable bold text
- **Border Color**: Same 19 color options
- **Border Thickness**: 6 options (None, Thin 6dp, Medium 10dp, Thick 14dp, XL 20dp, XXL 28dp)
- **Image/Icon Picker**: 
  - 14 built-in symbols (Happy, Sad, Yes, No, Help, Food, Drink, Pain, Bathroom, Sleep, Love, Home, Person, Question)
  - Custom image upload from Photos app
  - Emoji picker (any emoji as phrase icon)
  - None option
- **Live Preview**: Shows phrase with applied styles in real-time
- **Reset to Default**: Clear all customizations

**Supporting Components:**

**Create:** `iosApp/iosApp/Views/Settings/Components/ColorPickerView.swift`

- Reusable color picker with 19 colors
- Grid layout (3-4 columns)
- Selected state indicator
- Cancel button

**Create:** `iosApp/iosApp/Views/Settings/Components/SizePickerView.swift`

- Text size picker (7 sizes)
- Preview text at each size
- Cancel button

**Create:** `iosApp/iosApp/Views/Settings/Components/BorderWidthPickerView.swift`

- Border thickness picker (6 options)
- Visual preview of each thickness
- Cancel button

**Create:** `iosApp/iosApp/Views/Settings/Components/ImagePickerView.swift`

- Grid of 14 built-in symbols
- "Add Custom Image" button (opens Photos)
- "Use Emoji" button (opens emoji keyboard)
- "None" option
- Cancel button

**Create:** `iosApp/iosApp/Views/Settings/Components/EmojiKeyboardView.swift`

- Text field for emoji input
- System emoji keyboard
- Confirm/Cancel buttons

**Database Integration:**

- PhraseStyle model in shared module
- Store as JSON string or separate style fields
- Load/save per phrase

Reference: [`PhraseStyleEditorFragment.kt`](app/src/main/java/com/switch2connect/aac/settings/PhraseStyleEditorFragment.kt), [`PhraseStyle.kt`](app/src/main/java/com/switch2connect/aac/room/PhraseStyle.kt)

### Reset App

**Create:** `iosApp/iosApp/Views/Settings/ResetAppView.swift`

Features:

- **Warning Dialog**: "This will delete all custom categories and phrases. This cannot be undone."
- **Two-Step Confirmation**: 
  - Step 1: "Are you sure?" with Continue/Cancel
  - Step 2: "Really reset?" with Reset/Cancel
- **Database Reset**:
  - Delete all custom categories
  - Delete all custom phrases  
  - Keep preset categories and phrases
  - Reset all UserDefaults to defaults
- **Settings Reset**:
  - Symbol count → 2
  - Colors → defaults
  - Sensitivity → medium
  - Dwell time → 1 second
  - All toggles → defaults
- **Navigation**: Return to home screen after reset
- **Success Message**: "App has been reset"

Reference: Android reset logic in settings

## Phase 5: Text-to-Speech Enhancements

### TTS Manager

**Create:** `iosApp/iosApp/Utils/TTSManager.swift`

Features:

- **Voice Selection**: List available AVSpeechSynthesisVoices
- **Speech Rate Control**: 0.1x - 1.0x
- **Volume Control**: 0.0 - 1.0
- **Phrase Queue**: Support speaking multiple phrases
- **Pause/Resume/Stop** controls

**Modify:** [`AACGridView.swift`](iosApp/iosApp/Views/AAC/AACGridView.swift) to use TTSManager instead of inline code

**Settings Integration:**

- Add TTS settings section in SettingsView
- Voice picker
- Rate slider
- Test speak button

## Phase 6: Recent Phrases & My Sayings

### Recent Phrases

**Create:** `iosApp/iosApp/Views/Recents/RecentsView.swift`

Features:

- Show last 8 spoken phrases (from database query)
- Clear recents button
- Same grid layout as phrases
- Updates automatically when phrases are spoken

**Update database:**

- Track `lastSpokenDate` when phrase is selected
- Query: `getRecentPhrases()` - ORDER BY lastSpokenDate DESC LIMIT 8

### My Sayings (Custom Phrases)

This is a special custom category for user-created phrases not in any other category.

Features:

- Show in category grid
- Contains only user-added phrases
- Full edit support (add/edit/delete)
- No preset phrases

## Phase 7: Calibration Enhancements

**Update:** [`iosApp/iosApp/Views/Calibration/CalibrationView.swift`](iosApp/iosApp/Views/Calibration/CalibrationView.swift)

Add features:

- **Validation mode**: After calibration, show test grid to verify accuracy
- **Recalibration flow**: Allow partial recalibration (just a few points)
- **Save multiple calibration profiles**: Different lighting/position scenarios
- **Calibration history**: Show accuracy over time

**Update:** [`iosApp/iosApp/Views/Calibration/CalibrationManager.swift`](iosApp/iosApp/Views/Calibration/CalibrationManager.swift) to persist to shared module

## Phase 8: Localization Support

### Add Internationalization

The Android app supports 20+ languages. Implement i18n for iOS:

**Create:** `iosApp/iosApp/Resources/` Localizable string files

- `en.lproj/Localizable.strings` (English - default)
- `es.lproj/Localizable.strings` (Spanish)
- `fr.lproj/Localizable.strings` (French)
- `de.lproj/Localizable.strings` (German)
- `it.lproj/Localizable.strings` (Italian)
- ... (add more as needed)

**Modify shared module:**

- `LocalesWithText` model for multi-language phrase support
- Store phrases in multiple languages in database
- Select phrase text based on device locale

**Update all SwiftUI views:**

- Replace hardcoded strings with `Text("key")` localized strings
- Use `NSLocalizedString()` for non-SwiftUI code

## Phase 9: Accessibility Enhancements

### VoiceOver Support

Add proper accessibility labels:

- Category buttons: "Category: [name]. Double tap to open."
- Phrase buttons: "Phrase: [text]. Double tap to speak."
- Settings controls: Descriptive labels and hints
- Calibration: Spoken instructions for each step

### Switch Control

- Ensure all interactive elements are keyboard/switch accessible
- Test with iOS Switch Control feature
- Add focus indicators
- Proper tab order

### Dynamic Type

- Support iOS Dynamic Type for text size
- Scale button sizes with accessibility settings
- Test with largest text sizes

## Phase 10: Testing & Polish

### Unit Tests

**Create:** `iosApp/iosAppTests/`

- `CategoryRepositoryTests.swift` - Database operations
- `PhraseRepositoryTests.swift` - Database operations  
- `CalibrationTests.swift` - Calibration math
- `TTSManagerTests.swift` - TTS functionality

### UI Tests

**Create:** `iosApp/iosAppUITests/`

- `NavigationTests.swift` - Categories → Phrases flow
- `PhraseSelectionTests.swift` - Selecting and speaking phrases
- `SettingsTests.swift` - Changing settings
- `CalibrationTests.swift` - Calibration flow

### Performance Optimization

- Lazy loading for large phrase lists
- Image caching for category icons
- Database query optimization
- Smooth 60fps gaze pointer movement
- Reduce MediaPipe inference latency

### UI Polish

- Animations for navigation transitions
- Loading states for database operations
- Empty states (no phrases, no recent phrases)
- Error handling with user-friendly messages
- Consistent color scheme and typography
- Dark mode support

## Key Files Summary

### New Shared Module Files

- `shared/src/commonMain/sqldelight/` - Database schema
- `shared/src/commonMain/kotlin/com/vocable/data/models/` - Data models
- `shared/src/commonMain/kotlin/com/vocable/data/repository/` - Repositories
- `shared/src/commonMain/kotlin/com/vocable/data/PresetData.kt` - Preset phrases

### New iOS Files

- `iosApp/iosApp/Data/DatabaseManager.swift`
- `iosApp/iosApp/ViewModels/` - All ViewModels
- `iosApp/iosApp/Views/Categories/CategoriesView.swift`
- `iosApp/iosApp/Views/Phrases/PhrasesView.swift`
- `iosApp/iosApp/Views/Keyboard/KeyboardView.swift`
- `iosApp/iosApp/Views/NumberPad/NumberPadView.swift`
- `iosApp/iosApp/Views/Recents/RecentsView.swift`
- `iosApp/iosApp/Views/Settings/` - All settings screens
- `iosApp/iosApp/Utils/TTSManager.swift`
- `iosApp/iosApp/Resources/*.lproj/` - Localization files

### Modified iOS Files

- [`iosApp/iosApp/Switch2GoApp.swift`](iosApp/iosApp/Switch2GoApp.swift) - Add database init
- [`iosApp/iosApp/ContentView.swift`](iosApp/iosApp/ContentView.swift) - Update navigation
- [`iosApp/iosApp/Tracking/GazeTrackingManager.swift`](iosApp/iosApp/Tracking/GazeTrackingManager.swift) - Add modes
- [`iosApp/iosApp/Views/AAC/AACGridView.swift`](iosApp/iosApp/Views/AAC/AACGridView.swift) - Update for real data
- [`iosApp/iosApp/Views/Settings/SettingsView.swift`](iosApp/iosApp/Views/Settings/SettingsView.swift) - Implement real settings
- [`iosApp/iosApp/Views/Calibration/CalibrationView.swift`](iosApp/iosApp/Views/Calibration/CalibrationView.swift) - Add validation

### Modified Shared Files

- [`shared/build.gradle.kts`](shared/build.gradle.kts) - Add SQLDelight

## Implementation Notes

1. **Database First**: Start with shared database layer - this is the foundation for everything
2. **Incremental UI**: Build UI screens incrementally, testing each against real data
3. **Reuse Android Logic**: Port Android's use case classes to shared module where possible
4. **Test on Device**: Eye tracking must be tested on physical iPad, not simulator
5. **Accessibility from Start**: Add accessibility labels as you build UI, not as afterthought

## Success Criteria

### Data & Persistence

- [ ] All preset categories and phrases available
- [ ] Can create custom categories and phrases
- [ ] Can edit/delete custom content
- [ ] Can reorder categories and phrases
- [ ] Recent phrases tracked and displayed (last 8)
- [ ] All settings persist in UserDefaults/database
- [ ] Database migrations work correctly

### CVI Features ⭐ CRITICAL

- [ ] **Per-phrase styling works** (colors, size, bold, borders, images, emoji)
- [ ] **Symbol count adjustable** (2-9 symbols per page)
- [ ] **Per-position color customization** (9 color slots)
- [ ] Phrase style editor fully functional
- [ ] Color pickers, size pickers, image/emoji pickers work
- [ ] Styles persist and load correctly

### Eye Tracking & Calibration

- [ ] Eye tracking with all modes (2D/3D iris tracking)
- [ ] GPU acceleration toggle works
- [ ] All smoothing modes functional (None, Simple, Kalman, Adaptive, Combined)
- [ ] Eye selection works (Both/Left/Right)
- [ ] Calibration saves and loads
- [ ] Calibration validation mode
- [ ] Manual recenter functionality

### UI & Navigation

- [ ] **Output bar always visible** with phrase composition
- [ ] **Swipe navigation** works for paginating phrases
- [ ] Page indicators show correctly (Page X of Y)
- [ ] **Empty states** display for all list views
- [ ] Categories grid displays correctly
- [ ] Phrases grid displays with applied styles
- [ ] Keyboard for custom phrase input works
- [ ] Number pad works

### Settings Screens

- [ ] Main settings screen with all 8+ options
- [ ] Timing & Sensitivity settings work
- [ ] Selection Mode toggle (Face vs Eye)
- [ ] Advanced Eye Tracking settings complete
- [ ] CVI Display settings (symbol count + colors)
- [ ] Edit Categories screens (show/hide, reorder, rename, delete)
- [ ] Edit Phrases screens (add, edit, delete, reorder, style)
- [ ] Phrase Style Editor fully functional
- [ ] Reset App with two-step confirmation
- [ ] Privacy Policy webview
- [ ] Contact Developer email link

### Text-to-Speech

- [ ] TTS with voice/rate/volume control
- [ ] Phrase queue supports multiple phrases
- [ ] Speaker icon shows when speaking
- [ ] Pause/Resume/Stop controls work

### Accessibility & Localization

- [ ] Localization for at least 3 languages
- [ ] VoiceOver support throughout app
- [ ] Switch Control accessible
- [ ] Dynamic Type support
- [ ] Proper accessibility labels

### Performance & Polish

- [ ] No crashes, smooth 60fps performance
- [ ] Gaze pointer rendering smooth
- [ ] Database queries optimized
- [ ] Image loading efficient
- [ ] Animations smooth
- [ ] Loading states for async operations
- [ ] Error handling with user-friendly messages

### Final Goal

- [ ] **Matches Android app functionality 1:1**

This is a comprehensive implementation that will take significant time but results in a fully-featured, production-ready AAC application for iOS that matches Android capabilities.