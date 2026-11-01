<div align="center">

<picture>
  <source media="(prefers-color-scheme: dark)" srcset="assets/icon_dark.png">
  <source media="(prefers-color-scheme: light)" srcset="assets/icon.png">
  <img src="assets/icon.png" alt="AutoSpend" width="100" height="100"/>
</picture>

# AutoSpend

### 🏦 Your Bank SMS → Instant Expense Log. Zero Manual Entry.

<p align="center">
  <a href="https://github.com/GaganHR2006/AutoSpend-Tracker/releases/latest">
    <img src="https://img.shields.io/badge/⬇_Download_APK-v2.0.1-7C3AED?style=for-the-badge&labelColor=0D0D1A" alt="Download APK"/>
  </a>
  &nbsp;
  <a href="https://github.com/GaganHR2006/AutoSpend-Tracker/stargazers">
    <img src="https://img.shields.io/github/stars/GaganHR2006/AutoSpend-Tracker?style=for-the-badge&logo=github&color=f5a623&labelColor=0D0D1A" alt="Stars"/>
  </a>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Android-5.0+-3DDC84?style=flat-square&logo=android&logoColor=white"/>
  <img src="https://img.shields.io/badge/Flutter-3.32.2-02569B?style=flat-square&logo=flutter&logoColor=white"/>
  <img src="https://img.shields.io/badge/Privacy-100%25_Offline-7C3AED?style=flat-square"/>
  <img src="https://img.shields.io/badge/License-MIT-06B6D4?style=flat-square"/>
  <img src="https://img.shields.io/badge/Banks-All_Indian_Banks-F59E0B?style=flat-square"/>
  <img src="https://img.shields.io/badge/Data_Sent_to_Server-ZERO-red?style=flat-square"/>
</p>

<br/>

> **AutoSpend silently reads your bank SMS messages the moment they arrive —**
> **categorizes, logs, and visualizes every rupee. No login. No cloud. No effort.**

</div>

---

## ⚡ Why AutoSpend?

| The Problem | AutoSpend's Answer |
|---|---|
| _"I forget to log expenses"_ | **You never have to.** SMS arrives → transaction logged. Automatic. |
| _"Finance apps need an account"_ | **No account. No email. No cloud.** 100% offline. |
| _"I don't trust apps with my bank data"_ | **Your data never leaves your phone.** Period. |
| _"Categorizing takes too long"_ | **Auto-categorization.** Zomato → Food 🍔. Ola → Transport 🚕. |
| _"I want to know my net spend right now"_ | **Live dashboard.** Opens in 1 second. Always accurate. |

---

## ✨ Features

<table>
<tr>
<td width="50%" valign="top">

**🤖 Auto-Capture Engine**
- Real-time SMS parsing — logged before you put your phone down
- UPI Notification Listener (PhonePe, GPay, Paytm) as backup
- 3-layer duplicate detection — SMS + notification = stored once
- **Time Travel** — bulk-import your entire SMS history
- All Indian banks supported

</td>
<td width="50%" valign="top">

**📊 Smart Dashboard**
- Live income vs. expense balance, always current
- Interactive pie & bar charts by category
- Custom date range filters (daily / weekly / monthly)
- Category summaries at a glance

</td>
</tr>
<tr>
<td width="50%" valign="top">

**💰 Budget & Alerts**
- Monthly spending budget with circular progress ring
- Per-category limits (Food ₹5K, Transport ₹2K…)
- Credit card limit tracker
- Smart alerts at 80% — max 1 per category/day

</td>
<td width="50%" valign="top">

**🔒 Privacy First**
- Biometric lock (fingerprint / face)
- Zero internet — works fully offline, no Wi-Fi needed
- No accounts, no Google sign-in, no Firebase
- Quick Settings Tile — add transactions without unlocking

</td>
</tr>
<tr>
<td width="50%" valign="top">

**🏷️ Smart Categorization**
- 20+ built-in categories with emoji icons
- Auto-maps merchants → categories out of the box
- Quick Categorize grid — assign categories in seconds
- Bulk re-categorize any set of transactions

</td>
<td width="50%" valign="top">

**👥 Lending Tracker**
- Track money lent to friends & family
- Link repayments back to the original entry
- Lending excluded from net savings calculations
- Manual entry for any custom transaction

</td>
</tr>
</table>

---

## 🔧 How It Works

```
┌─────────────────────────────────────────────────────────────────┐
│                     AUTOSPEND PIPELINE                          │
└─────────────────────────────────────────────────────────────────┘

 📱 Bank SMS arrives              📳 UPI App Notification
        │                                  │
        ▼                                  ▼
 SmsReceiver.kt               NotificationListener.kt
 (BroadcastReceiver)          (NotificationListenerService)
        │                                  │
        └──────────────┬───────────────────┘
                       ▼
              Flutter MethodChannel
                       │
                       ▼
             SmsParserService (Dart)
              ├── Extract: amount, merchant, debit/credit
              ├── Infer category from merchant name
              └── 3-Layer Duplicate Guard:
                    1. In-memory fingerprint cache
                    2. Exact SMS ID lookup in DB
                    3. Fuzzy match: ±5 min window + merchant
                       │
                       ▼
            Drift ORM → SQLite (100% local)
                       │
                       ▼
          Riverpod Streams → UI live-updates ✅
```

**Transaction appears on your dashboard within ~2 seconds of the SMS arriving.**

---

## 📥 Download & Install

> **Latest:** v2.0.1 · Android 5.0+ · 60 MB

<div align="center">

[![Download Latest APK](https://img.shields.io/badge/⬇_Download_app--release.apk-v2.0.1_|_60_MB-7C3AED?style=for-the-badge&labelColor=1a1a2e)](https://github.com/GaganHR2006/AutoSpend-Tracker/releases/latest)

</div>

**Install in 3 steps:**
```
1. Download APK from the Releases tab above
2. Settings → Install Unknown Apps → Allow your browser/file manager
3. Open the APK → Tap Install → Done ✅
```

---

## 🚀 First-Time Setup (2 minutes)

```
Step 1 ──► Grant SMS Permission          (required — core feature)
Step 2 ──► Enable Notification Access    (recommended — UPI backup)
Step 3 ──► Run Time Travel               (import all past transactions)
Step 4 ──► Set Your Budget               (optional — enables alerts)
Step 5 ──► Enable Biometric Lock         (optional — privacy)
```

### Permissions — Plain English

| Permission | Why We Need It |
|---|---|
| `READ_SMS` / `RECEIVE_SMS` | **Core feature** — read bank transaction messages |
| Notification Access | Catch UPI payments when SMS is delayed or blocked |
| Biometric | Lock the app with your fingerprint (optional) |
| Quick Settings Tile | Add a transaction from your notification shade (optional) |

> **Android 13+ users:** If SMS shows as "restricted" → Apps → AutoSpend → Permissions → SMS → Allow.
> The app has a built-in help screen that navigates you there directly.

---

## 🏗️ Tech Stack

| Layer | Technology | Why |
|---|---|---|
| **UI Framework** | Flutter 3.32.2 (Dart) | Cross-platform, smooth 60fps |
| **State Management** | Riverpod 2.x + code generation | Reactive streams, auto-refresh |
| **Database** | Drift ORM → SQLite | Type-safe, fully local, zero latency |
| **Charts** | fl_chart 0.69 | Beautiful, interactive visualizations |
| **Native Android** | Kotlin (SMS + Notification) | BroadcastReceiver, MethodChannels |
| **Auth** | local_auth | BiometricPrompt API |
| **Secure Storage** | flutter_secure_storage | Encrypted key-value store |
| **Fonts** | Google Fonts | Consistent, polished typography |
| **Notifications** | flutter_local_notifications | Budget alert delivery |

---

## 📁 Project Structure

```
📦 AutoSpend-Tracker
├── 📂 lib/src/
│   ├── 📂 core/database/       # Drift schema, migrations, DAOs
│   └── 📂 features/
│       ├── 📂 dashboard/       # Home screen, live balance, analytics
│       ├── 📂 transactions/    # Transaction list, add/edit sheets
│       ├── 📂 categories/      # Category definitions & auto-mapping
│       ├── 📂 budget/          # Budget tracking & alert service
│       ├── 📂 settings/        # App settings, backup, onboarding reset
│       └── 📂 onboarding/      # First-launch flow & guided tour
│   └── 📂 services/
│       ├── 📂 sms/             # Regex-based SMS parsing engine
│       ├── sms_service.dart    # Real-time SMS listener
│       └── notification_service.dart  # UPI notification parser
│
└── 📂 android/app/src/main/kotlin/
    ├── SmsReceiver.kt           # Android BroadcastReceiver
    ├── NotificationListener.kt  # NotificationListenerService
    └── MainActivity.kt          # MethodChannel bridge to Flutter
```

---

## 🔨 Build from Source

**Requirements:** Flutter 3.32.2+ · Android SDK 21+ · Java 11+

```bash
# Clone
git clone https://github.com/GaganHR2006/AutoSpend-Tracker.git
cd AutoSpend-Tracker

# Install dependencies
flutter pub get

# Generate code (Drift ORM + Riverpod providers)
dart run build_runner build --delete-conflicting-outputs

# Run in debug mode
flutter run

# Build release APK
flutter build apk --release
# → build/app/outputs/flutter-apk/app-release.apk
```

---

## 🗺️ Roadmap

### ✅ v2.0.1 — Current
- [x] Biometric lock with Quick Tile bypass
- [x] UPI Notification Listener (dual-capture)
- [x] Lending Tracker (Friends & Family)
- [x] Per-category budgets with smart alerts
- [x] 3-layer duplicate detection
- [x] Time Travel (bulk SMS import)
- [x] Quick Settings Tile

### 🔜 v2.1 — Next Up
- [ ] CSV / JSON data export
- [ ] Local backup & restore to file
- [ ] Recurring transaction detection
- [ ] Transaction search & filters
- [ ] Weekly / yearly budget periods

### 🔮 v2.2+
- [ ] Bill reminders
- [ ] Multiple account support
- [ ] Light mode toggle
- [ ] Transaction notes & tags
- [ ] Investment tracking (stocks, mutual funds)

---

## 🙋 FAQ

<details>
<summary><b>Does AutoSpend need internet?</b></summary>
<br/>
No. AutoSpend is <b>100% offline</b>. It never makes a single network request. All data stays on your device in a local SQLite database. No Wi-Fi required, ever.
</details>

<details>
<summary><b>Which banks are supported?</b></summary>
<br/>
Any Indian bank that sends an SMS for debit/credit — which is virtually all of them. Specifically tested: Karnataka Bank, SBI, HDFC, ICICI, Axis, Kotak, Yes Bank. All UPI apps work via the Notification Listener: PhonePe, Google Pay, Paytm, BHIM, Amazon Pay.
</details>

<details>
<summary><b>What if the same transaction arrives via both SMS and UPI notification?</b></summary>
<br/>
AutoSpend's 3-layer duplicate detection handles this automatically. It checks an in-memory fingerprint cache, the SMS ID in the database, and a fuzzy time + merchant match (±5 minutes). The transaction is stored exactly once.
</details>

<details>
<summary><b>Is my SMS content stored or transmitted anywhere?</b></summary>
<br/>
No. Raw SMS text is read locally, parsed in-memory, and immediately discarded. Only the extracted data (amount, merchant, category, date) is stored in the local SQLite database. No SMS content is ever saved or sent anywhere.
</details>

<details>
<summary><b>Can it work without SMS permission?</b></summary>
<br/>
Yes, partially. If you grant Notification Access but not SMS, AutoSpend captures transactions from UPI app notifications (PhonePe, GPay, etc.) only. SMS permission enables full auto-capture from bank messages — strongly recommended.
</details>

---

## 🤝 Contributing

Pull requests are welcome! For major changes, please open an issue first.

```bash
# Fork → Clone your fork → Create branch
git checkout -b feature/my-feature

# Make changes, then commit
git commit -m "feat: add my feature"

# Push and open a Pull Request
git push origin feature/my-feature
```

---

## 📄 Documentation

| Doc | Description |
|---|---|
| [📖 User Guide](USER_GUIDE.md) | Complete feature walkthrough — 1,100+ lines |
| [🔒 Privacy Policy](PRIVACY_POLICY.md) | Exactly what data we access and why |
| [📝 Release Notes](RELEASE_NOTES.md) | Full changelog for every version |
| [✅ Launch Checklist](LAUNCH_CHECKLIST.md) | Pre-release testing guide |

---

## 📜 License

Distributed under the **MIT License** — free to use, fork, and build upon.

---

<div align="center">

### ⭐ If AutoSpend saves you time, a star helps others discover it!

[![Star on GitHub](https://img.shields.io/github/stars/GaganHR2006/AutoSpend-Tracker?style=social)](https://github.com/GaganHR2006/AutoSpend-Tracker/stargazers)

---

**Built for privacy-conscious Indians who want effortless finance tracking**

*Your data stays on your phone. Always. No exceptions.*

<sub>Made with ❤️ using Flutter · Kotlin · Drift ORM</sub>

</div>
