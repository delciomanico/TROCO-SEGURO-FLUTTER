# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.


# Regras do Projeto

- Analise antes de modificar.
- Prefira simplicidade.
- Reutilize código existente.
- Não faça overengineering.
- Mostre diffs em vez de arquivos completos.
- Seja econômico com tokens.
- Execute testes relevantes após alterações.
- Mantenha compatibilidade com a arquitetura atual.

## Project

Flutter app ("Troco Seguro" — passenger app) for digital taxi payments in Luanda, Angola. Replaces physical change ("troco") with QR-code-based wallet payments. This is the **passenger** ("Passageiro") client; a separate driver ("Motorista") app shares the same backend.

## Commands

```bash
flutter pub get              # install dependencies
flutter run                  # run on connected device/emulator
flutter analyze              # static analysis (flutter_lints via analysis_options.yaml)
flutter test                 # run all tests in test/
flutter test test/api_test.dart   # run a single test file
flutter build apk            # Android release build
```

There is no CI config in this repo; rely on `flutter analyze` and `flutter test` before considering a change done.

## Architecture

### State management
A single `AppProvider` (`lib/providers/app_provider.dart`, `ChangeNotifier` via `package:provider`) is the source of truth for user, wallet balance, virtual cards, transactions, and trips. It is created once in `main.dart` above `MaterialApp` and consumed everywhere with `context.watch`/`context.read`.

- On `initialize()`, it loads cached state from `SharedPreferences` (keys prefixed `ts_`) for instant UI, then refreshes everything from the API in the background (`_refreshAllDataInBackground`).
- Each data domain (user, cards, transactions, trips) has its own loading flag and a 5-minute cache-validity window (`_cacheDuration`), though the cache check itself (`_isCacheValid`) is currently unused by the fetch methods — they always hit the API on manual refresh.
- Mutating methods (transfer, create/delete virtual card, update profile) update local state optimistically and persist to `SharedPreferences` immediately so the UI never blocks on network round-trips after the initial call succeeds.

### Networking
`lib/services/api_service.dart` is a singleton wrapping a single `Dio` instance pointed at `https://troco-seguro.onrender.com/api/v1`. Key behaviors:
- Bearer token is attached via request interceptor; on `401` the response interceptor attempts a silent token refresh (`/auth/refresh`) and replays the original request once.
- Every method returns `ApiResponse<T>` (`isSuccess`/`data`/`error`) instead of throwing — callers must check `isSuccess`, not catch exceptions.
- Tokens persist in `SharedPreferences` (`accessToken`/`refreshToken`); `loadTokens()` must be called (done in `AppProvider.initialize()` and ad hoc in some screens) before authenticated calls.
- See `API_ENDPOINTS.md` for the full endpoint contract (request/response shapes) — keep `ApiService` methods in sync with it when the backend changes.

### Authentication & session lock flow
`main.dart`'s `AppController` is the root state machine:
1. `hasSeenOnboarding` (SharedPreferences) gates `OnboardingScreen`.
2. No authenticated user → `AuthScreen`.
3. App backgrounded while authenticated → `_isLocked = true` → `ReauthScreen` (PIN or biometric unlock) shown on next foreground; the user is never auto-logged-out, just locked.
4. Otherwise → `MainScreen` (bottom-nav: Home / Wallet / Trips via `IndexedStack`).

PIN handling is split across three pieces that always work together:
- `SecureStorageService` (`lib/services/secure_storage_service.dart`) — stores the PIN itself in `flutter_secure_storage`, never in `SharedPreferences`.
- `PinGuard` (`lib/security/pin_guard.dart`) — client-side rate limiting (5 attempts, then escalating lockout 1/2/4/8/15 min) per named `scope` string (e.g. `'global'`). Always call `PinGuard.validatePin(scope:, enteredPin:, readExpectedPin:)` rather than comparing PINs directly, so lockouts stay consistent.
- `lib/security/qr_validator.dart` (`QRValidator`) — structural/freshness validation for QR payloads. This is legacy/defense-in-depth; the live payment flow validates QR tokens server-side via `ApiService.resolveQrToken`, not via this class.

### Payment flow
Orchestrated by `PaymentService` (`lib/services/payment_service.dart`), driven from `MainScreen._showPaymentFlow` in `main.dart`:
1. `QRScannerModal` scans a QR code.
2. `PaymentService.validateQrCode` extracts a `token` from the scanned data (query param, `token=` substring, or raw JWT-looking string) and calls `ApiService.resolveQrToken` (`GET /qrcodes/resolve`) — never the removed `/payments/validate-qr` endpoint.
3. On success, `PaymentConfirmationModal` collects the PIN, validated via `PinGuard`.
4. `ApiService.processPayment` (`POST /payments/process`) executes the transaction; balance is updated locally via `AppProvider.updateUserBalance`.

### Models vs API responses
`lib/models/*.dart` are the app's domain models (`User`, `Transaction`, `Trip`, `VirtualCard`, `Driver`, `FAQItem`), each with `fromJson`/`toJson` for both API parsing and `SharedPreferences` caching. `ApiService` also defines its own lightweight response wrapper classes (`AuthResult`, `TransactionResult`, `QrValidationResult`, `PaymentResult`, etc.) at the bottom of `api_service.dart` — these are transport-level shapes, not persisted, and get converted into the domain models or consumed directly by callers.

### UI conventions
- Theming: `ThemeController` (`lib/services/theme_controller.dart`) is a global `ValueNotifier<ThemeMode>` persisted to `SharedPreferences`, watched at the very top of the widget tree in `TrocoSeguroApp` — toggle dark mode via `ThemeController.instance.setDark(bool)`, never by other means.
- Most secondary flows (top-up, transfer, virtual cards, payment confirmation, QR scan, success) are implemented as bottom sheets/modals under `lib/widgets/`, opened via `showModalBottomSheet`/`showGeneralDialog` from `MainScreen`, not as pushed routes.
- `FeedbackService` (`lib/services/feedback_service.dart`) is the standard way to show success/error/info snackbars/toasts — use it instead of ad hoc `ScaffoldMessenger` calls.
- `lib/utils/responsive_helper.dart` provides the project's responsive sizing helpers; see `README_RESPONSIVE.md`/`RESPONSIVE_DESIGN_CHANGES.md` for the rationale if touching layout-sensitive screens.

## Notes from project docs

- Money values are integers in Kwanzas (Kz); PINs are 6 numeric digits (the backend contract in `API_ENDPOINTS.md` says 6 digits even though some older UI copy says 4 — follow the 6-digit contract).
- Phone numbers use the `+244XXXXXXXXX` international format.
- `AppProvider._loadFromCache` contains a guard that wipes the cache if it detects a known mocked user (`id == '1'`, `fullName == 'Adilson Fernandes'`) left over from earlier development — don't remove this without confirming no stale installs depend on it.
