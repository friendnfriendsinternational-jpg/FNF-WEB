# FnF International Flutter Web App

## Project Overview

A Flutter-based web application for **Friend n Friends (FnF) International**, a construction and government contracting company based in Pakistan. The app helps employs generate project cost estimates, view services, and manage supply chain orders.

## Technologies

- **Framework:** Flutter 3.32.0 (Web)
- **Language:** Dart 3.8.0
- **Key Packages:** url_launcher, shared_preferences, pdf, printing, cupertino_icons

## Project Structure

```text
lib/
├── main.dart                   # App entry point & Material 3 theme
└── screens/
    ├── home_screen.dart        # Home with company info & client list
    ├── quotation_screen.dart   # Cost estimator + PDF generation
    ├── services_screen.dart    # Services & trusted clients
    ├── contact_screen.dart     # WhatsApp/Email/Website contact
    ├── gallery_screen.dart     # Saved project quotations
    ├── supply_screen.dart      # Supply chain quotations
    └── supply_gallery_screen.dart  # Saved supply orders
assets/
├── logo.png                   # Company logo
└── letterhead.jpg             # Used in PDF generation
build/web/                     # Built Flutter web output (served)
```

## Running the App

### Development

The workflow builds the Flutter web app and serves it on port 5000:

```bash
flutter build web --release && python3 serve.py
```

### Build Only

```bash
flutter pub get
flutter build web --release
```

## Workflow

- **Name:** Start application
- **Command:** `flutter build web --release 2>&1 && python3 serve.py`
- **Port:** 5000 (webview)
- **Serve script:** `serve.py` — Python HTTP server serving `build/web/` on 0.0.0.0:5000

## Deployment

- **Target:** Static
- **Build command:** `flutter build web --release`
- **Public directory:** `build/web`
