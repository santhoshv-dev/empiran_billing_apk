# React to Flutter implementation

Run `flutter pub get` and `flutter run -d chrome` from `Flutter`.

The local demo login matches React: `empirantraders` / `123456`. Staff accounts created in Settings can also sign in locally. Use an email address to sign in to the ASP.NET API, or choose **Create a cloud account** on the login screen to register. Cloud sessions use the JWT expiry returned by the API.

## Screen mapping

| React area | Flutter implementation |
| --- | --- |
| Header/sidebar/firm switcher | Responsive navigation, global search, business switching and theme toggle |
| Splash/login | Branding, password visibility, session persistence and logout |
| Quotation maker | Product search/categories, editable cart, customer selection, discounts, saved quotations and order conversion |
| Orders/invoice modal/POS | Multiple products, quantities/prices, GST/non-GST, date, payments, shipping, dispatch details and notes |
| Invoice PDF | Preview, printing/sharing, logo, customer/dispatch/bank details and amount in words |
| Sales/purchases/payments/returns | Searchable screens with date/status filters and stock movements |
| Items/stock adjustment | Add/edit/delete, images, category/unit/HSN, sales/purchase prices, services and low-stock filter |
| Parties | Add/edit/delete, opening balances, customer/supplier types, contact/GST details and ledger |
| Dashboard | Sales, purchases, receivables, expenses, low stock, recent transactions and quick actions |
| Expenses/bank accounts | Persisted records, add/edit/delete, search and totals |
| Reports | Transactions/sales/payments, preset/custom dates, totals, CSV export, report PDF and WhatsApp summary |
| Settings | Company profile/logo, staff creation/deletion, invoice numbering |
| WhatsApp | Message drafts and document sharing through the platform share sheet |

Files: `lib/suite.dart` (shell, settings, reports, forms), `lib/workflows.dart` (transaction editor/screens), `lib/app_store.dart` (state/persistence), `lib/models.dart` (models/totals), `lib/invoice_pdf.dart` (documents).

## Data and behavior

Records are cached locally with SharedPreferences. Existing Flutter keys remain compatible. A cloud login loads businesses, products, parties, transactions, expenses and bank accounts from the ASP.NET API; create/update/delete actions are sent to the API and the local cache is refreshed. The cloud icon in the header shows sync state and triggers a manual refresh. Local demo/staff login remains offline-only. Header backup exports/restores the active local cache without staff passwords.

The default API is `https://empiran-api.runasp.net/api/v1`. Override it at build/run time with `--dart-define=API_URL=http://localhost:5186/api/v1` for desktop/web local development, or `--dart-define=API_URL=http://10.0.2.2:5186/api/v1` for an Android emulator. A physical device needs your computer's LAN address and the backend must listen on that interface.

Quotations and unfulfilled orders do not change stock. Sales and purchase returns reduce stock; purchases and sale returns increase it. Services do not affect stock. Deleting a posted transaction reverses stock movement. Quotation conversion is protected against duplication. Payments affect party balances but are not automatically allocated against individual invoice balances. Bank accounts do not have automatic reconciliation.

The React orders' 9% CGST + 9% SGST calculation is retained. Discounts and shipping are included in totals. Layouts and colors are adapted to Flutter Material; exact screenshot parity has not been verified. WhatsApp opens drafts for the user to send; live QR pairing and automatic sending are not implemented in the React source or this conversion.

## Verification

Run `flutter analyze`, `flutter test`, `flutter build web`, and `flutter build apk --debug`.

Tests cover calculations, persistence, business isolation, stock movement/reversal, quotation conversion, payments, invalid input, CSV escaping, PDF generation, mobile navigation and invoice quantity editing. Platform print/share dialogs and image selection require device checks. iOS builds require macOS/Xcode.
