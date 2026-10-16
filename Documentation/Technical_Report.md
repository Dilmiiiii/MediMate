# MediMate Technical Report — SE4041 Part A

**Project type:** SwiftUI iOS medication-management coursework prototype, target iOS 17+.

## 1. Problem and target users

Adherence tracking can be difficult when multiple medications have different schedule patterns. A user may forget whether a dose was taken or fail to notice running-low inventory. MediMate provides an on-device schedule, user-confirmed response history, medicine stock ledger and Vision-assisted printed-label capture. Intended users include adults, older users and supervised caregivers. No automated prescription advice is provided.

## 2. Scope and functional requirements

13 screen groups support: splash, onboarding, dashboard, add, scanner, detail, dose action, calendar/history, stock, analytics, medicines list, medical profile and settings. The official minimum of three navigable screens is substantially exceeded. Features work without a backend or paid service; the real data model supplies UI state instead of fixed example analytics.

## 3. Architecture

- **SwiftUI App/Views**: TabView/NavigationStack/sheets, responsive design and local UI state.
- **SwiftData**: Medicine, MedicineSchedule, DoseLog, StockEvent, UserProfile and AppSettings.
- **MedicationEngine**: schedule generation, weekday/date boundaries, status derivation, adherence and streaks.
- **DoseService**: idempotent record/correction, exact stock reversal, append-only ledger.
- **NotificationCoordinator**: native actions and rolling local request queue.
- **OCRService**: actual Apple Vision text recognition, field parsing and manual review.
- **Swift Charts**: visualizes computed due/taken/missed values.

See shared `Assignment_Documentation/Architecture.md` for diagrams and mathematical definitions.

## 4. Design decisions

Use system typography, a restrained green palette `#278765`, large readable controls and material cards. Status indicators combine color **and text**. Larger Text is a user preference while system Dynamic Type remains supported. Native form controls reduce interaction complexity. A bundled printed sample label provides a simulator-compatible route to real OCR instead of faking scan results.

## 5. Data integrity

Dose occurrence identity is stable per local calendar day and saved schedule UUID. A Taken action creates a single persistent log and bounded stock deduction. Repeating the same action produces no second change. Correcting Taken to Skipped restores exactly the amount previously subtracted, with ledger history. Historical records keep the medication name snapshot if the live medicine is deleted. Future unsent doses are labeled Upcoming; overdue unconfirmed ones become Missed.

## 6. Safety and privacy

All dosage entries are user-supplied prescribed information. OCR cannot validate clinical correctness; scanned values must be reviewed before saving. The app does not suggest dose doubling or schedule changes based on clinical judgement. No cloud syncing is configured. Profile/allergy/emergency-contact information stays in local storage until explicit export or deletion. This is a learning prototype, not a regulated medical device.

## 7. Emerging technology

The Vision OCR integration uses `VNRecognizeTextRequest` with accurate recognition, on-device image processing and manual verification. This meets the **intended** advanced framework demonstration; the official brief lists other acceptable examples such as CoreML and HealthKit, so the student should confirm Vision's acceptability with teaching staff.

## 8. Testing, optimization and current state

Provided tests cover recurrence/weekday logic, double deduction, correction, restocking, adherence, OCR parsing, occurrence ID and UI navigation. Source parsing was performed in Linux. **App binaries, real Xcode unit/UI test results, simulator screenshots and performance measurements do not exist from this preparation environment.** Complete the integration checklist using a Mac and document real results before claiming deployment readiness.

## 9. Known engineering limitations

The notification queue schedules the next 14 days / maximum 48 standard occurrences and is refreshed when the app opens. iOS does not guarantee exact delivery time under every device condition. OCR is heuristic and requires manual review. Medicine schedule edits replace future schedule IDs; past log snapshots remain. Calendar behavior should be evaluated across real time zone changes and daylight-saving boundaries. Multi-device sync, clinical validation, Sinhala localization and PDF report export are outside this demonstration scope; CSV history export is implemented.

## 10. Challenges and reflections to complete after testing

The main design challenges anticipated are background notification correctness, SwiftData object lifecycle, reliable OCR on imperfect print, recurrence across dates/time zones, and accessible form density. **Student section:** insert actual development difficulties, time spent, Xcode compile fixes, unit and UI results, screenshot evidence, and your own reflections after running the projects. Do not present anticipated issues as already resolved.
