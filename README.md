# MediMate — Your Health, Right on Time.

## Purpose and audience

Native SwiftUI iOS app that helps adults, elderly users, people following multi-medicine schedules, and caregivers record **user-prescribed** medication routines. MediMate offers local reminders, actual dose responses, history, stock estimates, and Apple Vision-assisted label transcription. It does **not** prescribe or validate medicine or dosage safety.

## Requirements

- Xcode 16 on macOS, iOS 17+ deployment target, iPhone or iPad simulator.
- XcodeGen: `brew install xcodegen`.
- No server, network, account, or third-party dependency.

```bash
xcodegen generate
open MediMate.xcodeproj
# Or build from terminal:
xcodebuild -project MediMate.xcodeproj -scheme MediMate -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build
```

Run in an iPhone simulator. Onboarding appears on the first run. The app seeds three editable **demo medicines**, plus consistent historical sample dose records. These are fictional fixtures, **not clinical recommendations**. Deleting all local data will not reseed them.

## Technical architecture

- `App/`: root `@main` App, tab navigation, native `NavigationStack`, splash, onboarding, model container setup.
- `Models/`: six SwiftData `@Model` entities (Medicine, MedicineSchedule, DoseLog, StockEvent, UserProfile, AppSettings).
- `Services/`: medication recurrence engine, idempotent dose transitions and inventory ledger, rolling UserNotifications scheduler, Vision OCR, CSV export, demo fixtures.
- `Views/`: thirteen required screen groups across native tabs, push navigation and sheets.
- `Components/`: ProgressRing, DoseChip, StatTile, MedicineCard, EmptyStateView.
- `Theme/`: centralized colors, CardStyle, PrimaryButtonStyle, ShimmerEffect.
- `Resources/`: generated print-like `SampleLabel.png` for real Vision OCR in a simulator.
- `MediMateTests/`, `MediMateUITests/`: behavior tests and primary navigation smoke test.

SwiftData is the source of truth. `DoseLog.occurrenceID` is unique per schedule + local civil day. DoseService prevents duplicate stock deductions and records reversal events if an existing Taken status is corrected to Skipped. Medicine deletions intentionally preserve snapshot-based historical records.

## Core journeys

1. Onboarding → Dashboard → Add Medication → Save → daily dose schedule → reminders, calendar and insights.
2. Home → Scan Label → choose camera, gallery or included sample → **actual Vision OCR** → manually verify → Confirm & Continue → Add Medication → Save.
3. Home or History → tap a scheduled dose → Taken/Remind Later/Skip. Only Taken reduces stock.
4. Medicines → search/sort/filter/reorder → view/edit/pause/delete, with notifications reconciled on changes.
5. Home → Inventory → manual restock and threshold changes; view chronological stock events.
6. Profile → edit emergency contact/allergies/medical notes → Settings → notification controls, theme, text size, CSV export, privacy, delete local data.

## Permissions and limitations

- Notifications: permission is requested via **Settings → Allow Notification Permission**. On iOS, local scheduling can be revoked in system settings.
- Camera: permission requested on actual device when selecting Capture Image. iOS simulator cannot emulate a real camera; use bundled label or PhotosPicker.
- Photo library: system PhotosPicker performs user-controlled selection.
- OCR is imperfect; no medical interpretation or automated dosage decisions are provided. The sample label must flow through Vision; there is no hardcoded recognition result.
- Notification manager schedules up to 48 upcoming notifications in a rolling 14-day window (iOS keeps a limited number of pending requests). Opening the app renews the window. An app left unopened longer than two weeks may not receive reminders after the scheduled horizon. Real-device/background tests are essential before any real health use.
- This demonstration uses the iOS app container for storage; it does not claim encrypted cloud backup or clinical compliance.
- English UI is present. Sinhala is not implemented.

## Tests

Run tests via the Xcode `MediMate` scheme or:

```bash
xcodebuild -project MediMate.xcodeproj -scheme MediMate -destination 'platform=iOS Simulator,name=iPhone 16' CODE_SIGNING_ALLOWED=NO test
```

Adapt the simulator name to `xcrun simctl list devices available`. The unit suite covers weekday recurrence, intervals, idempotent Taken/correction, stock events, adherence, OCR string parsing, and deterministic occurrence IDs; the UI smoke suite checks the core tab screens.

## Accessibility, privacy and design

- Green `#278765` palette, material cards, status text accompanied by icons, responsive layouts, system fonts, Dynamic Type, dark/light/system theme, and Reduce Motion support in major animations.
- Medical-profile data remains local unless the user exports/shares it. Sensitive fields should not be filled with real patient data while presenting this coursework prototype.
- The user is always responsible for transcription verification and prescribed medication details.

## Five-minute viva walkthrough

0:00 app mission + three onboarding slides; 0:45 Medicine list and Add Medicine validation; 1:30 scan the bundled label through Vision and review details; 2:30 show dose Taken action and inventory change, tap again to prove no double deduction; 3:30 calendar and real-data chart; 4:15 settings, privacy and tests. Explain the unique schedule occurrence identifier and 14-day notification queue limitation.

## Current verification

Swift files were parsed on Linux and metadata syntax was checked. **iOS Xcode build, iPhone simulator functionality, real notifications and UI screenshots remain unverified** until you run the Mac checklist. Do not represent them as passed before performing that work.
