# Friend n Friends International — Flutter App

## Company
- **Full Name:** Friend n Friends International
- **Website:** https://fnfinternational.odoo.com
- **WhatsApp:** +92 311 5177747
- **Email:** Friendnfriendsinternational@gmail.com
- **Branch Office:** House # 310, Lower Khalilzai, Garhi Pana Chowk, Nawan Shehr

## How to Run This App

### Prerequisites
1. Install [Flutter SDK](https://docs.flutter.dev/get-started/install) (version 3.x or higher)
2. Install [Android Studio](https://developer.android.com/studio) with Android SDK
3. Set up an Android emulator OR connect a physical Android device with USB debugging enabled

### Steps to Run

```bash
# 1. Navigate to this folder
cd artifacts/fnf-flutter

# 2. Get dependencies
flutter pub get

# 3. Run on connected device/emulator
flutter run

# 4. To build release APK
flutter build apk --release
# Output: build/app/outputs/flutter-apk/app-release.apk
```

### Project Structure

```
lib/
├── main.dart                  # App entry point & theme
└── screens/
    ├── home_screen.dart       # Home screen with company info & real clients
    ├── quotation_screen.dart  # Cost estimator with breakdown & summary
    ├── services_screen.dart   # 4 real services + trusted clients list
    └── contact_screen.dart    # WhatsApp/Email/Website + contact form
```

### Features
- **Home Screen:** Company name, slogan, stats, trusted defence & govt clients
- **Quotation Screen:** Area input + project type → instant cost estimate with material breakdown + copy summary
- **Services Screen:** 4 real service cards (expandable) + full client list
- **Contact Screen:** WhatsApp/Email/Website quick actions + contact form

### Real Services (from website)
1. Government Contracting Services
2. Construction & Building Services
3. General Order Supply (GOS)
4. Interior Design & Fit-Out Services

### Pricing Logic
| Project Type    | Rate (PKR/sq ft) |
|-----------------|-----------------|
| Grey Structure  | 2,500           |
| Standard        | 4,000           |
| Premium         | 6,000           |

### Trusted Clients (real)
DHPP, Army School of Music, HMC Texla, Havelian Ordinance Depot, AFPGMI, SSG, Army Corps Ordnance, AMC, FWO, Army Corps of Engineers, Frontier Force Regiment, Baloch Regiment
