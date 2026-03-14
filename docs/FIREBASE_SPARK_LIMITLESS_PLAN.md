# Firebase Spark Limitless Plan — Proctor App + ExamBro Pro

Dokumen ini berisi strategi maksimal untuk menggunakan **Firebase Spark (gratis)** sekaligus panduan integrasi **Proctor App** (pengawas) dan **ExamBro Pro** (siswa).

---

## Daftar Isi

1. [Limit Firebase Spark & Strategi Hemat](#1-limit-firebase-spark--strategi-hemat)
2. [Setup Firebase Project](#2-setup-firebase-project)
3. [Konfigurasi Flutter (Proctor App)](#3-konfigurasi-flutter-proctor-app)
4. [Firestore Security Rules](#4-firestore-security-rules)
5. [Struktur Data Firestore](#5-struktur-data-firestore)
6. [Alur Integrasi Proctor App ↔ ExamBro Pro](#6-alur-integrasi-proctor-app--exambro-pro)
7. [Panduan Step-by-Step: Setup Awal](#7-panduan-step-by-step-setup-awal)
8. [Panduan Step-by-Step: Persiapan Ujian](#8-panduan-step-by-step-persiapan-ujian)
9. [Panduan Step-by-Step: Pelaksanaan Ujian](#9-panduan-step-by-step-pelaksanaan-ujian)
10. [Strategi Skalabilitas Tanpa Upgrade](#10-strategi-skalabilitas-tanpa-upgrade)
11. [Estimasi Pemakaian Per Skenario](#11-estimasi-pemakaian-per-skenario)
12. [Checklist Deployment](#12-checklist-deployment)

---

## 1. Limit Firebase Spark & Strategi Hemat

### 1.1 Batas Harian Firebase Spark

| Resource              | Limit Gratis                     | Catatan                      |
| --------------------- | -------------------------------- | ---------------------------- |
| **Firestore Reads**   | 50.000/hari                      | Paling kritis, harus dihemat |
| **Firestore Writes**  | 20.000/hari                      | Cukup longgar                |
| **Firestore Deletes** | 20.000/hari                      | Jarang dipakai               |
| **Firestore Storage** | 1 GiB total                      | Sangat cukup untuk teks      |
| **Firebase Auth MAU** | 50.000/bulan                     | 651 user = 1.3% limit        |
| **Cloud Functions**   | ❌ Tidak tersedia                | Semua logika di client       |
| **Hosting**           | 10 GB/bulan transfer             | Opsional untuk web dashboard |
| **Cloud Storage**     | 5 GB storage, 1 GB/hari download | Tidak dipakai                |

### 1.2 Prinsip Emas Hemat Firestore

| #   | Prinsip                              | Penjelasan                                                                              |
| --- | ------------------------------------ | --------------------------------------------------------------------------------------- |
| 1   | **Baca sekali, cache di RAM**        | Setelah secret/sesi dibaca, simpan di memori. Tidak perlu baca ulang.                   |
| 2   | **Tanpa presence/heartbeat**         | Jangan tracking "proctor online" — 50 proctor × 1 write/30 detik = 24.000 writes/4 jam. |
| 3   | **One-time read > listener**         | Gunakan `.get()` sebisa mungkin, bukan `.snapshots()`.                                  |
| 4   | **Listener hanya untuk Super Admin** | Hanya session list Super Admin yang boleh pakai real-time stream.                       |
| 5   | **OTP digenerate lokal**             | TOTP dihitung di device dari secret di RAM, bukan diminta dari server.                  |
| 6   | **Flat structure**                   | Tidak ada subcollection — hemat read karena tidak cascade.                              |
| 7   | **Batch operasi**                    | Gabung create sesi + generate secrets dalam satu write.                                 |

### 1.3 Kapasitas Maksimal Harian (Estimasi)

Dengan prinsip di atas, dalam **satu hari ujian penuh** (4-8 jam):

| Aktivitas                                        | Reads      | Writes     |
| ------------------------------------------------ | ---------- | ---------- |
| 50 proctor login & baca profil                   | 100        | 0          |
| 1 super admin login & baca profil                | 2          | 0          |
| Super admin list semua sesi (stream, 1 snapshot) | 20         | 0          |
| Super admin list semua user                      | 50         | 0          |
| Super admin buat 10 sesi                         | 0          | 10         |
| Super admin update status 10 sesi                | 0          | 10         |
| 50 proctor baca daftar sesi aktif                | 200        | 0          |
| 50 proctor baca detail sesi (1x per sesi)        | 50         | 0          |
| Super admin approve 20 proctor baru              | 20         | 20         |
| 20 proctor self-register                         | 0          | 40         |
| Overhead (refresh, retry, navigation)            | ~200       | ~20        |
| **TOTAL**                                        | **~642**   | **~100**   |
| **Sisa dari limit harian**                       | **49.358** | **19.900** |
| **Pemakaian**                                    | **1.3%**   | **0.5%**   |

**Kesimpulan**: Bisa jalankan **~75 hari ujian berturut-turut** sebelum mendekati limit — jauh melebihi kebutuhan sekolah manapun.

---

## 2. Setup Firebase Project

### 2.1 Buat Project

1. Buka [Firebase Console](https://console.firebase.google.com/)
2. Klik **"Add project"** → beri nama, misal `proctor-sekolah`
3. Matikan Google Analytics (tidak diperlukan, menghemat complexity)
4. Pilih plan **Spark (No cost)**

### 2.2 Aktifkan Layanan

| Layanan             | Cara Aktifkan                                                                                                                                               |
| ------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Authentication**  | Firebase Console → Authentication → Sign-in method → aktifkan **Email/Password**                                                                            |
| **Cloud Firestore** | Firebase Console → Firestore Database → Create database → pilih **production mode** → region `asia-southeast1` (Singapore) atau `asia-southeast2` (Jakarta) |

> **Jangan** aktifkan Cloud Functions, Cloud Storage, atau Realtime Database — tidak diperlukan.

### 2.3 Register App

#### Android (Proctor App)

```
Firebase Console → Project Settings → Add app → Android
Package name: com.sekolah.proctor (sesuaikan)
Download google-services.json → taruh di android/app/
```

#### Web (Opsional — Dashboard Super Admin via browser)

```
Firebase Console → Project Settings → Add app → Web
Copy firebaseConfig → taruh di web/index.html atau firebase_options.dart
```

---

## 3. Konfigurasi Flutter (Proctor App)

### 3.1 Dependencies

Tambahkan di `pubspec.yaml`:

```yaml
dependencies:
  firebase_core: ^3.12.0
  firebase_auth: ^5.5.0
  cloud_firestore: ^5.6.0
```

Alternatif: gunakan CLI `flutterfire configure` untuk auto-generate `firebase_options.dart`.

### 3.2 Inisialisasi di main.dart

```dart
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const ProctorBootstrap());
}
```

### 3.3 AuthRepository — Ganti In-Memory ke Firebase

**Sebelum (scaffold)**:

```dart
class AuthRepository {
  final List<AppUser> _users = _seedUsers();
  // ... in-memory login
}
```

**Sesudah (Firebase)**:

```dart
class AuthRepository {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Login
  Future<AppUser?> signIn({required String email, required String password}) async {
    final cred = await _auth.signInWithEmailAndPassword(email: email, password: password);
    final uid = cred.user!.uid;
    final doc = await _db.collection('users').doc(uid).get();
    return AppUser.fromFirestore(doc);
  }

  // Register (self-register sebagai pending)
  Future<AppUser> register({
    required String email,
    required String displayName,
    required String password,
  }) async {
    final cred = await _auth.createUserWithEmailAndPassword(email: email, password: password);
    final uid = cred.user!.uid;
    final userData = {
      'email': email.trim().toLowerCase(),
      'displayName': displayName.trim(),
      'role': 'pending',
      'isActive': false,
      'createdAt': FieldValue.serverTimestamp(),
    };
    await _db.collection('users').doc(uid).set(userData);
    return AppUser(id: uid, email: email, displayName: displayName,
      role: UserRole.pending, createdAt: DateTime.now(), isActive: false);
  }

  // Restore user saat app dibuka
  Future<AppUser?> restoreUser() async {
    final fbUser = _auth.currentUser;
    if (fbUser == null) return null;
    final doc = await _db.collection('users').doc(fbUser.uid).get();
    if (!doc.exists) return null;
    return AppUser.fromFirestore(doc);
  }

  // Sign out
  Future<void> signOut() async => _auth.signOut();
}
```

### 3.4 SessionRepository — Ganti ke Firestore

```dart
class SessionRepository {
  final _db = FirebaseFirestore.instance;
  final _col = FirebaseFirestore.instance.collection('sessions');

  // Buat sesi (super admin only)
  Future<ExamSession> createSession({...}) async {
    final docRef = _col.doc();
    final data = { /* ... session fields ... */ };
    await docRef.set(data);
    return ExamSession.fromMap(docRef.id, data);
  }

  // One-time read semua sesi (super admin)
  Future<List<ExamSession>> getAllSessions() async {
    final snap = await _col.orderBy('createdAt', descending: true).get();
    return snap.docs.map((d) => ExamSession.fromFirestore(d)).toList();
  }

  // One-time read sesi aktif saja (proctor)
  Future<List<ExamSession>> getActiveSessions() async {
    final snap = await _col.where('status', isEqualTo: 'active').get();
    return snap.docs.map((d) => ExamSession.fromFirestore(d)).toList();
  }

  // Update status sesi
  Future<void> updateStatus(String sessionId, String status) async {
    await _col.doc(sessionId).update({'status': status});
  }
}
```

---

## 4. Firestore Security Rules

Tempel ini di Firebase Console → Firestore → Rules:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {

    function userRole() {
      return get(/databases/$(database)/documents/users/$(request.auth.uid)).data.role;
    }

    function isActive() {
      return get(/databases/$(database)/documents/users/$(request.auth.uid)).data.isActive == true;
    }

    // === Users Collection ===
    match /users/{userId} {
      // User bisa baca profilnya sendiri
      allow read: if request.auth != null && request.auth.uid == userId;

      // Super admin bisa baca semua user
      allow read: if request.auth != null && userRole() == "super_admin";

      // Self-register: hanya bisa buat doc sendiri sebagai pending + inactive
      allow create: if request.auth != null
        && request.auth.uid == userId
        && request.resource.data.role == "pending"
        && request.resource.data.isActive == false
        && request.resource.data.keys().hasAll(['email', 'displayName', 'role', 'isActive', 'createdAt']);

      // Hanya super admin yang bisa update user lain
      allow update: if request.auth != null && userRole() == "super_admin";

      // Tidak boleh hapus user
      allow delete: if false;
    }

    // === Sessions Collection ===
    match /sessions/{sessionId} {
      // Super admin bisa baca semua sesi
      allow read: if request.auth != null && userRole() == "super_admin";

      // Proctor aktif hanya bisa baca sesi yang statusnya "active"
      allow read: if request.auth != null
        && userRole() == "proctor"
        && isActive()
        && resource.data.status == "active";

      // Hanya super admin yang bisa write (create/update/delete) sesi
      allow write: if request.auth != null && userRole() == "super_admin";
    }
  }
}
```

**Keamanan yang dijamin oleh rules ini:**

- Siswa tidak punya akun → tidak bisa akses Firestore sama sekali
- User `pending` tidak bisa baca sessions
- Proctor hanya bisa baca sesi `active` (tidak bisa lihat `scheduled` atau `ended`)
- Tidak ada yang bisa self-promote ke `super_admin` atau `proctor`
- Tidak ada yang bisa hapus dokumen user

---

## 5. Struktur Data Firestore

```
Firestore Root
│
├── /users/{userId}
│     ├── email: string
│     ├── displayName: string
│     ├── role: "super_admin" | "proctor" | "pending"
│     ├── isActive: boolean
│     └── createdAt: timestamp
│
└── /sessions/{sessionId}
      ├── name: string              ← "UAS Fisika Kelas 12A"
      ├── examUrl: string           ← "https://exam.school.id/uas-fisika"
      ├── exitSecret: string        ← "JBSWY3DPEHPK3PXP" (Base32)
      ├── alarmSecret: string       ← "KRSXG5CTMVRXEZLU" (Base32)
      ├── createdBy: string         ← uid super admin
      ├── createdAt: timestamp
      ├── startsAt: timestamp
      ├── endsAt: timestamp
      └── status: "scheduled" | "active" | "ended"
```

**Total dokumen estimasi**: ~660 (651 user + ~10 sesi per ujian)
**Total storage**: < 1 MB ← jauh di bawah limit 1 GiB

---

## 6. Alur Integrasi Proctor App ↔ ExamBro Pro

### 6.1 Diagram Koneksi

```
┌──────────────────────────────────────────────────────────┐
│                    FIREBASE SPARK                        │
│  ┌──────────────┐         ┌──────────────────────────┐   │
│  │  Firebase     │         │  Cloud Firestore         │   │
│  │  Auth         │         │  /users/{uid}            │   │
│  │  (email/pass) │         │  /sessions/{sessionId}   │   │
│  └──────┬───────┘         └──────────┬───────────────┘   │
│         │                            │                    │
└─────────┼────────────────────────────┼────────────────────┘
          │                            │
          │  Login/Register            │  Read/Write
          │                            │  (via SDK + Rules)
          │                            │
┌─────────▼────────────────────────────▼───────────────────┐
│                    PROCTOR APP (Flutter)                  │
│                                                          │
│  ┌────────────┐  ┌─────────────┐  ┌──────────────────┐   │
│  │ Login/     │  │ Super Admin │  │ Proctor          │   │
│  │ Register   │  │ Dashboard   │  │ Dashboard        │   │
│  └────────────┘  │             │  │                  │   │
│                  │ • Buat Sesi │  │ • Lihat sesi     │   │
│                  │ • Gen QR    │  │   aktif          │   │
│                  │ • Kelola    │  │ • Lihat OTP      │   │
│                  │   proctor   │  │                  │   │
│                  └──────┬──────┘  └────────┬─────────┘   │
│                         │                  │              │
│              Generate QR Code        Generate OTP lokal  │
│              (JSON + secrets)        (dari secret di RAM) │
└─────────────────────────┬──────────────────┬─────────────┘
                          │                  │
                   Cetak/Tampilkan      Bacakan kode
                   QR Code              "847293"
                          │                  │
                     ┌────▼────┐        ┌────▼────┐
                     │ QR Code │        │ Suara / │
                     │ (kertas │        │ Ketik   │
                     │  /layar)│        │ manual  │
                     └────┬────┘        └────┬────┘
                          │                  │
                     Scan 1x             Input kode
                          │                  │
┌─────────────────────────▼──────────────────▼─────────────┐
│                   EXAMBRO PRO (Flutter)                   │
│                   (Device Siswa)                          │
│                                                          │
│  ┌──────────┐  ┌────────────┐  ┌──────────────────────┐  │
│  │Home      │  │ Exam       │  │ Cheat Warning        │  │
│  │ Scan QR  │→ │ WebView    │  │ (Alarm + Lock)       │  │
│  │          │  │ Secure Mode│  │                      │  │
│  └──────────┘  │ DND ON     │  │ Alarm OTP → Reset    │  │
│                │ Pinning ON │  │                      │  │
│                │            │  └──────────────────────┘  │
│                │ Exit OTP   │                            │
│                │  → Keluar  │                            │
│                └────────────┘                            │
│                                                          │
│  TIDAK ADA koneksi internet ke Firebase.                  │
│  Semua verifikasi OTP dilakukan OFFLINE via algoritma     │
│  TOTP dari secret yang dibawa QR Code.                   │
└──────────────────────────────────────────────────────────┘
```

### 6.2 Tiga Titik Integrasi

| #   | Titik         | Media              | Arah                  | Online?    |
| --- | ------------- | ------------------ | --------------------- | ---------- |
| 1   | **QR Code**   | Kertas/layar       | Proctor App → ExamBro | ❌ Offline |
| 2   | **Exit OTP**  | Suara/ketik manual | Proctor App → ExamBro | ❌ Offline |
| 3   | **Alarm OTP** | Suara/ketik manual | Proctor App → ExamBro | ❌ Offline |

**Semua titik integrasi bersifat offline** — ExamBro Pro tidak membutuhkan koneksi ke Firebase sama sekali. Ini berarti:

- **Tidak ada Firestore reads dari device siswa** (0 biaya)
- **Tidak perlu Firebase SDK di ExamBro** (lebih ringan)
- **Tidak ada attack surface** dari sisi siswa ke backend

### 6.3 Format QR Code (Kontrak Pertukaran Data)

QR Code adalah satu-satunya jembatan data antara kedua aplikasi. Formatnya:

```json
{
  "url": "https://exam.school.id/uas-fisika",
  "session_id": "ses_abc123",
  "duration_minutes": 120,
  "ends_at": "2026-03-12T10:00:00.000Z",
  "exit_otp_interval_seconds": 3600,
  "alarm_otp_interval_seconds": 30,
  "exit_secret": "JBSWY3DPEHPK3PXP",
  "alarm_secret": "KRSXG5CTMVRXEZLU"
}
```

| Field                        | Digenerate oleh             | Dipakai oleh | Keterangan                         |
| ---------------------------- | --------------------------- | ------------ | ---------------------------------- |
| `url`                        | Super Admin (Proctor App)   | ExamBro      | URL form ujian online              |
| `session_id`                 | Super Admin (Proctor App)   | ExamBro      | Identifier sesi untuk logging      |
| `duration_minutes`           | Super Admin (Proctor App)   | ExamBro      | Durasi ujian dalam menit           |
| `ends_at`                    | Super Admin (Proctor App)   | ExamBro      | Waktu selesai (ISO 8601 UTC)       |
| `exit_otp_interval_seconds`  | Proctor App                 | ExamBro      | Interval TOTP exit (default: 3600) |
| `alarm_otp_interval_seconds` | Proctor App                 | ExamBro      | Interval TOTP alarm (default: 30)  |
| `exit_secret`                | Proctor App (random Base32) | Kedua app    | Secret untuk generate exit OTP     |
| `alarm_secret`               | Proctor App (random Base32) | Kedua app    | Secret untuk generate alarm OTP    |

**Validasi di ExamBro saat scan QR:**

1. Harus valid JSON
2. Harus punya field `url`, `exit_secret`, `alarm_secret`
3. URL biasa (non-JSON) → **ditolak**
4. JSON tanpa secret → **ditolak**

### 6.4 Sinkronisasi TOTP

Kedua app harus menghasilkan OTP yang sama pada waktu yang sama:

| Parameter        | Nilai                | Keterangan                           |
| ---------------- | -------------------- | ------------------------------------ |
| Algorithm        | SHA1                 | RFC 6238 default                     |
| Digits           | 6                    | Kode 6 angka                         |
| Exit interval    | 3600 detik (1 jam)   | Kode berlaku 1 jam                   |
| Alarm interval   | 30 detik             | Kode berubah tiap 30 detik           |
| Window tolerance | ±1 step              | Menerima kode 1 step sebelum/sesudah |
| Time source      | NTP (waktu otomatis) | **Wajib aktif di device siswa**      |

**Contoh kode Dart (sama di kedua app):**

```dart
import 'package:otp/otp.dart';

String generateOtp(String secret, {required int intervalSeconds}) {
  return OTP.generateTOTPCodeString(
    secret,
    DateTime.now().millisecondsSinceEpoch,
    interval: intervalSeconds,
    algorithm: Algorithm.SHA1,
    isGoogle: true,
  );
}

// Di Proctor App (tampilkan)
final exitOtp = generateOtp(session.exitSecret, intervalSeconds: 3600);

// Di ExamBro (verifikasi)
bool verifyOtp(String input, String secret, int interval) {
  final current = generateOtp(secret, intervalSeconds: interval);
  // Juga cek ±1 window untuk toleransi
  return input == current;
}
```

---

## 7. Panduan Step-by-Step: Setup Awal

### Langkah 1: Buat Firebase Project

```
Firebase Console → Create Project → "proctor-sekolah"
→ Disable Google Analytics → Create
```

### Langkah 2: Aktifkan Auth

```
Authentication → Sign-in method → Email/Password → Enable → Save
```

### Langkah 3: Buat Firestore Database

```
Firestore Database → Create database
→ Start in production mode
→ Region: asia-southeast2 (Jakarta)
→ Create
```

### Langkah 4: Tempel Security Rules

```
Firestore → Rules → paste rules dari Section 4 → Publish
```

### Langkah 5: Register Android App

```
Project Settings → Add app → Android
→ Package name: com.sekolah.proctor
→ Download google-services.json
→ Taruh di: proctor/android/app/google-services.json
```

### Langkah 6: Jalankan FlutterFire CLI

```bash
dart pub global activate flutterfire_cli
flutterfire configure --project=proctor-sekolah
```

### Langkah 7: Seed Super Admin

```
1. Buka Proctor App → Register sebagai user biasa
2. Buka Firebase Console → Firestore → /users/{uid}
3. Edit dokumen:
   - role: "super_admin"
   - isActive: true
4. Logout dan login kembali di app
```

---

## 8. Panduan Step-by-Step: Persiapan Ujian

### H-1 atau Pagi Hari Ujian

```
┌─ Super Admin ──────────────────────────────────────────┐
│                                                        │
│  1. Login di Proctor App                               │
│                                                        │
│  2. Approve proctor baru (jika ada)                    │
│     Dashboard → Approval Proctor → klik "Approve"      │
│                                                        │
│  3. Buat sesi ujian per mata pelajaran/kelas           │
│     Dashboard → Buat Sesi                              │
│     - Nama: "UAS Fisika 12A"                           │
│     - URL: "https://exam.school.id/uas-fisika-12a"     │
│     - Durasi: 120 menit                                │
│     → Secrets otomatis digenerate                      │
│     → QR Code otomatis muncul                          │
│                                                        │
│  4. Cetak/screenshot QR Code per sesi                  │
│     Detail Sesi → Download QR                          │
│                                                        │
│  5. Distribusikan QR ke ruangan ujian                  │
│     - 1 QR per sesi (bukan per siswa)                  │
│     - Bisa ditempel di papan tulis                     │
│     - Atau ditampilkan di proyektor saat mulai ujian   │
│                                                        │
│  6. Saat ujian dimulai: Aktifkan sesi                  │
│     Detail Sesi → klik "Aktifkan"                      │
│     → Proctor sekarang bisa lihat sesi ini             │
│                                                        │
└────────────────────────────────────────────────────────┘
```

### Distribusi QR ke Device Siswa

```
┌─ Di Ruangan Ujian ─────────────────────────────────────┐
│                                                        │
│  1. Proctor tunjukkan QR di proyektor/papan            │
│                                                        │
│  2. Siswa buka ExamBro Pro → Scan QR Code              │
│     → ExamBro membaca JSON dari QR                     │
│     → Menyimpan URL + secrets di memori lokal          │
│     → Masuk Exam Screen (secure mode ON)               │
│                                                        │
│  3. Setelah semua siswa scan → QR bisa disingkirkan    │
│     (QR tidak perlu ditampilkan terus-menerus)         │
│                                                        │
└────────────────────────────────────────────────────────┘
```

---

## 9. Panduan Step-by-Step: Pelaksanaan Ujian

### Skenario A: Siswa Selesai Ujian (Normal Exit)

```
Siswa tekan back di ExamBro
      ↓
ExamBro tampilkan dialog "Masukkan kode exit"
      ↓
Siswa panggil proctor pengawas ruangan
      ↓
Proctor buka Proctor App → Layar OTP → lihat Exit OTP
      ↓
Proctor ketikkan/bacakan kode 6 digit ke siswa
      ↓
Siswa masukkan kode → ExamBro verifikasi lokal
      ↓
✓ Valid → Secure mode OFF, kembali ke Home
✗ Salah → "PIN salah", ujian tetap berlanjut
```

### Skenario B: Siswa Ketahuan Curang (Cheat Detected)

```
ExamBro deteksi kecurangan (split screen / unpin / home)
      ↓
Alarm menyala, volume 100%, layar terkunci di Cheat Warning
      ↓
Proctor datang → panggil Admin/Ketua Pengawas
      ↓
Admin buka Proctor App → Layar OTP → lihat Alarm OTP
      ↓
Admin ketikkan kode 6 digit di layar siswa
      ↓
✓ Valid → Alarm berhenti, sesi dibersihkan, kembali ke Home
         (siswa harus scan ulang jika diizinkan melanjutkan)
✗ Salah → Alarm tetap nyala, layar tetap terkunci
```

### Skenario C: Super Admin Akhiri Ujian

```
Waktu ujian habis
      ↓
Super Admin buka Proctor App → Detail Sesi → "Akhiri"
      ↓
Status sesi berubah dari "active" → "ended"
      ↓
Proctor yang refresh daftar sesi → sesi tidak muncul lagi
      ↓
QR Code sesi ini menjadi tidak berguna
(secret sudah berbeda untuk sesi berikutnya)
```

---

## 10. Strategi Skalabilitas Tanpa Upgrade

### 10.1 Bagaimana Kalau Mau Lebih dari 600 Siswa?

Siswa **tidak mengakses Firebase sama sekali**, jadi jumlah siswa tidak memengaruhi quota Firestore. Bisa 600 atau 6.000 siswa — sama saja.

Yang memengaruhi quota hanyalah:

- Jumlah **proctor** (login + baca sesi)
- Jumlah **sesi** (create + update status)
- Frekuensi **refresh** di app proctor

### 10.2 Strategi Multi-Hari Ujian Berturut

| Hari              | Sesi Baru | Proctor Baru   | Estimasi Reads   | Status  |
| ----------------- | --------- | -------------- | ---------------- | ------- |
| Hari 1            | 10 sesi   | 50 proctor     | ~642             | ✅ Aman |
| Hari 2            | 10 sesi   | 0 proctor baru | ~500             | ✅ Aman |
| Hari 3            | 10 sesi   | 5 proctor baru | ~550             | ✅ Aman |
| ...               | ...       | ...            | ...              | ✅ Aman |
| **Total 30 hari** | 300 sesi  | 55 proctor     | ~17.000/hari avg | ✅ Aman |

### 10.3 Jika Mendekati Limit (Darurat)

1. **Batasi refresh** — tambahkan debounce/cooldown pada pull-to-refresh
2. **Cache lebih agresif** — simpan daftar sesi di SharedPreferences, hanya refresh saat diminta
3. **Kurangi listener** — pastikan Super Admin tidak membuka banyak stream bersamaan
4. **Arsipkan sesi lama** — hapus sesi `ended` yang sudah > 7 hari (hemat read saat list)

### 10.4 Mapping Reads: Siapa Baca Apa?

```
┌──────────────────┬────────────────────────────┬─────────────┐
│     Aktor        │     Apa yang Dibaca        │ Berapa Kali │
├──────────────────┼────────────────────────────┼─────────────┤
│ Super Admin      │ /users/* (list all)        │ 1x per buka │
│                  │ /sessions/* (stream)       │ real-time   │
│                  │ /users/{uid} (self)        │ 1x login    │
├──────────────────┼────────────────────────────┼─────────────┤
│ Proctor          │ /users/{uid} (self)        │ 1x login    │
│                  │ /sessions (active only)    │ 1x per buka │
│                  │ /sessions/{id} (detail)    │ 1x per sesi │
├──────────────────┼────────────────────────────┼─────────────┤
│ Pending User     │ /users/{uid} (self)        │ 1x login    │
│                  │ /sessions (BLOCKED)        │ 0           │
├──────────────────┼────────────────────────────┼─────────────┤
│ Siswa (ExamBro)  │ TIDAK AKSES FIREBASE       │ 0           │
└──────────────────┴────────────────────────────┴─────────────┘
```

---

## 11. Estimasi Pemakaian Per Skenario

### Skenario Kecil: 1 Sekolah, 200 Siswa, 10 Proctor

| Resource         | Pemakaian/Hari | % Limit |
| ---------------- | -------------- | ------- |
| Auth MAU         | 11             | 0.02%   |
| Firestore Reads  | ~150           | 0.3%    |
| Firestore Writes | ~30            | 0.15%   |

### Skenario Menengah: 1 Sekolah, 600 Siswa, 50 Proctor

| Resource         | Pemakaian/Hari | % Limit |
| ---------------- | -------------- | ------- |
| Auth MAU         | 51             | 0.1%    |
| Firestore Reads  | ~642           | 1.3%    |
| Firestore Writes | ~100           | 0.5%    |

### Skenario Besar: 5 Sekolah Sharing 1 Project, 3000 Siswa, 200 Proctor

| Resource         | Pemakaian/Hari | % Limit |
| ---------------- | -------------- | ------- |
| Auth MAU         | 201            | 0.4%    |
| Firestore Reads  | ~2.500         | 5%      |
| Firestore Writes | ~400           | 2%      |

**Bahkan skenario terbesar hanya memakai 5% limit harian.**

---

## 12. Checklist Deployment

### Firebase Setup

- [ ] Buat Firebase project (Spark plan)
- [ ] Aktifkan Email/Password Authentication
- [ ] Buat Firestore database (production mode, region Jakarta/Singapore)
- [ ] Tempel Firestore Security Rules
- [ ] Register Android app + download google-services.json
- [ ] Jalankan `flutterfire configure`

### Proctor App

- [ ] Tambahkan `firebase_core`, `firebase_auth`, `cloud_firestore` di pubspec.yaml
- [ ] Ganti `AuthRepository` dari in-memory ke Firebase Auth + Firestore
- [ ] Ganti `SessionRepository` dari in-memory ke Firestore
- [ ] Test login, register, approve proctor, buat sesi, lihat OTP
- [ ] Test generate & download QR
- [ ] Build APK release: `flutter build apk --release`

### ExamBro Pro

- [ ] Pastikan parser QR menerima format JSON baru (semua field)
- [ ] Pastikan TOTP engine menggunakan parameter yang sama (SHA1, 6 digit)
- [ ] Pastikan exit OTP interval 3600 detik dan alarm OTP interval 30 detik
- [ ] Pastikan cek NTP/waktu otomatis sebelum ujian dimulai
- [ ] Test scan QR → masuk exam → exit OTP → alarm OTP
- [ ] Build APK release: `flutter build apk --release`

### Operasional

- [ ] Seed Super Admin account pertama via Firebase Console
- [ ] Distribusikan APK Proctor App ke pengawas
- [ ] Distribusikan APK ExamBro Pro ke device siswa
- [ ] Briefing proctor tentang cara lihat OTP
- [ ] Test ujian simulasi sebelum hari-H

---

> **Dokumen ini adalah panduan lengkap untuk operasikan kedua aplikasi dengan Firebase gratis tanpa batasan praktis.**
> Dengan arsitektur offline-first di sisi siswa dan read-once di sisi proctor, pemakaian Firebase akan selalu jauh di bawah limit Spark.
