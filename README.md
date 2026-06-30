# Academia — Cameroon 🎓
### Flutter App (converted from HTML)

A full school management platform for Cameroonian students, teachers, and parents.

---

## 📱 Platforms Supported
- ✅ Android
- ✅ iOS
- ✅ Web (Flutter Web)
- ✅ Desktop (Windows, macOS, Linux)

---

## 🚀 Getting Started

### Prerequisites
- Flutter SDK ≥ 3.10.0 → https://flutter.dev/docs/get-started/install
- Android Studio or VS Code with Flutter extension
- For Android: Android SDK / emulator
- For iOS: Xcode (macOS only)

### Setup

```bash
# 1. Navigate to project folder
cd academia_cameroon

# 2. Install dependencies
flutter pub get

# 3. Run on Android emulator
flutter run

# 4. Run as Flutter Web
flutter run -d chrome

# 5. Build APK for Android
flutter build apk --release

# 6. Build for Web
flutter build web
```

---

## 📂 Project Structure

```
lib/
├── main.dart               # App entry point + theme toggle
├── theme.dart              # Colors, fonts, light/dark themes
├── models/
│   └── models.dart         # Data models + sample data
├── widgets/
│   └── widgets.dart        # Reusable UI components
├── screens/
│   ├── login_screen.dart   # Login / Register screen
│   └── home_screen.dart    # Main shell with sidebar nav
└── pages/
    ├── dashboard_page.dart     # 🏠 Home dashboard + charts
    ├── grades_page.dart        # 📊 Report card + analytics
    ├── lessons_page.dart       # 📚 Video lessons grid
    ├── library_page.dart       # 📖 Library + Chat + Assignments
    ├── timetable_page.dart     # 🗓️ Weekly schedule table
    ├── fees_page.dart          # 💳 School fees & payment
    ├── attendance_page.dart    # ✅ Attendance records
    └── notifications_page.dart # 🔔 Notifications + Settings + Subscription
```

---

## 🎨 Features

| Feature | Status |
|---|---|
| Login / Register | ✅ |
| Demo accounts | ✅ |
| Dark / Light mode | ✅ |
| Dashboard with charts | ✅ |
| Grade report table | ✅ |
| Bar, Radar, Doughnut charts | ✅ |
| Video lessons + filter | ✅ |
| Library (Free / Premium) | ✅ |
| Live chat rooms | ✅ |
| Assignments checklist | ✅ |
| Timetable | ✅ |
| Fees & payment | ✅ |
| Attendance tracking | ✅ |
| Notifications | ✅ |
| Subscription / Premium | ✅ |
| Voucher codes | ✅ |
| Responsive (mobile + web) | ✅ |

---

## 🔑 Demo Login Credentials

| Name | Email | Role |
|---|---|---|
| Amina Bello | amina@student.cm | Student |
| Prof. Martin Essomba | martin@teacher.cm | Teacher |
| Paul Bello | paul@parent.cm | Parent |

Password: anything (demo mode)

---

## 🎟️ Premium Voucher Codes
- `SCHOLAR2026`
- `FREE2026`

---

## 📦 Dependencies

| Package | Purpose |
|---|---|
| `fl_chart` | Charts (line, bar, radar, doughnut) |
| `google_fonts` | Sora + IBM Plex Sans fonts |
| `shared_preferences` | Local storage |
| `intl` | Date formatting |

---

## 🔄 Next Steps (Production)
- [ ] Connect to real backend / Firebase
- [ ] Add push notifications (FCM)
- [ ] Add offline support with Hive/Isar
- [ ] Add real video player (video_player package)
- [ ] Add PDF viewer for library books
- [ ] Deploy Flutter Web to hosting
