# PreventaApp

## Overview
Flutter mobile app for point-of-sale (POS) and route-based sales management. Used by vendors/pre-vendors in the field with offline-first capability.

## Tech Stack
- **Flutter** (Dart SDK `^3.7.2`) — cross-platform (Android, iOS, Linux, macOS, Windows, Web)
- **Supabase** (`supabase_flutter: ^2.12.4`) — backend, auth, and real-time sync
- **Google OAuth** (`google_sign_in: ^6.2.1`) — authentication via Google Sign-In
- **SQLite** (`sqflite: ^2.4.2`) — local database for full offline operation
- **Connectivity Plus** — network state monitoring and automatic sync
- **Thermal Printing** (`blue_thermal_printer`, `esc_pos_utils_plus`) — receipt/ticket printing
- **PDF + Printing** — PDF generation and document printing
- **Google Maps / OpenStreetMap** (`flutter_map`, `latlong2`, `geolocator`) — route and location management
- **Local Notifications** — push-style alerts via Supabase Realtime

## Architecture
- **Entry point:** `lib/main.dart` — initializes Supabase, env vars, local DB, and connectivity monitoring
- **Auth:** `lib/services/auth_service.dart` — Google OAuth sign-in/sign-out via Supabase
- **Screens:** `lib/screens/` — one file per screen (login, venta, productos, tickets, rutas, total, clientes, corte, creditos, impresora, configuracion)
- **Models:** `lib/models/` — data classes matching Supabase tables
- **Services:** `lib/services/` — auth, data CRUD, database helper, notifications, sync
- **Widgets:** `lib/widgets/` — reusable UI components (dialogs, dropdowns, cards)

## Key Features
- Offline-first POS terminal
- Product catalog with inventory tracking
- Sales ticket/receipt generation and thermal printing
- Route planning with map integration
- Client management
- Cash register cut (corte de caja)
- Credit/loan tracking
- Auto-sync when connectivity is restored

## Auth Flow
1. `LoginScreen` → Google Sign-In → `MainScreen` (bottom navigation shell)
2. Session persists via Supabase; auto-login on app restart
3. Sign-out clears session and returns to `LoginScreen`

## Theme/Colors
- Primary: `#1E3A8A` (deep blue)
- Secondary: `#3B82F6` (bright blue)
- Gradient: `#0A2540` → `#1E3A8A` → `#3B82F6`
- Font: Inter (via Google Fonts)
- Material 3 enabled

## Environment
- Requires `.env` file with `SUPABASE_URL` and `SUPABASE_ANON_KEY`

## Commands
```bash
flutter pub get          # Install dependencies
flutter run              # Run on connected device/emulator
flutter build apk        # Build Android APK
flutter analyze          # Lint/static analysis
```
