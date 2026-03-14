---
description: "Gunakan sebagai source of truth untuk alur sistem, keamanan, dan role Proctor App/ExamBro saat mengubah kode atau dokumentasi."
applyTo: "**"
---

# ExamBro Pro - Sistem dan Alur Kerja (System Flow)

Dokumen ini menjelaskan rancangan sistem, alur kerja (system flow), dan mekanisme keamanan dari aplikasi ExamBro Pro secara sistematis dan terstruktur.

## 1. Arsitektur Umum & State Management

Aplikasi ExamBro Pro dibangun menggunakan Flutter dengan arsitektur yang memisahkan antara _UI/Presentation_ dan _Core Services/Data_.
Manajemen state global dikendalikan melalui `MultiProvider` di `main.dart`:

- **HistoryProvider**: (Opsional) Untuk menyimpan riwayat ujian.
- **CheatAlertService**: Mengelola state alarm kecurangan dan pemutaran audio alarm.
- **BatteryService**: Memantau status baterai perangkat (memberi peringatan jika kritis/rendah).
- **ExamSessionService**: Mengelola persistensi status ujian untuk _crash recovery_ (pemulihan jika aplikasi tertutup paksa).
- **DndService**: Mengelola mode Do Not Disturb (DND) Android via native MethodChannel, memblokir panggilan telepon dan notifikasi selama ujian.

## 2. Navigasi & Routing (GoRouter)

Aplikasi menggunakan `go_router` untuk mengatur perpindahan halaman:

- `/` (Splash Screen): Memeriksa status sesi _(Apakah ada ujian yang sedang berlangsung? Apakah device dalam state peringatan kecurangan?)_ lalu mengarahkan ke halaman yang sesuai.
- `/home` (Home Screen): Halaman utama untuk memulai sesi (Scan QR).
- `/scanner` (Scanner Screen): Pemindai QR Code untuk mendapatkan URL ujian.
- `/exam` (Exam Screen): Halaman utama ujian berbasis WebView yang diamankan.
- `/cheat-warning` (Cheat Warning Screen): Halaman peringatan/blokade jika terdeteksi kecurangan.

## 3. Sistem TOTP (Full OTP — Tanpa Static PIN)

Aplikasi menggunakan **TOTP-only** untuk verifikasi pengawas — tidak ada static PIN yang bisa dihafal siswa.

### Dua Jenis Secret

1. **Exit Secret**: Digunakan pengawas ruangan di `ExamScreen` untuk mengakhiri ujian siswa secara normal.
2. **Alarm Secret**: Digunakan admin/ketua pengawas di `CheatWarningScreen` untuk mematikan alarm kecurangan.

Kedua secret dibuat oleh **Super Admin** saat generate QR Code melalui Proctor App.

### Alur Verifikasi

```
Input kode 6 digit
       |
       v
+-----------------------------+
| Cek TOTP dari secret        |
| (±1 window = 90 detik)      |
+-----------+-----------------+
       cocok?
      /      \
    Ya       Tidak
     |         |
  Valid      "PIN salah"
```

Tidak ada fallback. Pengawas **harus** buka Proctor App untuk melihat kode OTP yang berubah tiap 30 detik.

### Persyaratan Waktu Otomatis

Perangkat siswa HARUS memiliki "Waktu otomatis" (NTP) aktif. Jika nonaktif, dialog peringatan muncul sebelum ujian dimulai dan ujian tidak bisa dilanjutkan sampai waktu otomatis diaktifkan.

### Format QR Code (Wajib JSON — dari Super Admin)

```json
{
  "url": "https://exam.school.id/uas",
  "session_id": "UAS_FISIKA_12A",
  "exit_secret": "JBSWY3DPEHPK3PXP",
  "alarm_secret": "KRSXG5CTMVRXEZLU"
}
```

- `url` — **wajib**, URL ujian.
- `exit_secret` — **wajib**, TOTP secret untuk exit.
- `alarm_secret` — **wajib**, TOTP secret untuk alarm.
- `session_id` — opsional, identifier sesi untuk logging.

QR berformat URL biasa **ditolak**. Siswa tidak bisa bikin QR sendiri tanpa secret.

### Peran di Proctor App (Plan)

| Role | Akses |
| --- | --- |
| **Super Admin** | Generate QR Code (berisi URL + TOTP secrets), kelola sesi ujian, kelola akun proctor |
| **Proctor (Pengawas)** | Lihat kode TOTP real-time di Proctor App untuk verifikasi exit/alarm. Tidak bisa generate QR. |

## 4. Proctor App — Rancangan Lengkap (Plan)

Proctor App adalah aplikasi pendamping (companion app) untuk pengawas ujian. Dibangun terpisah dari ExamBro Pro (client siswa).

**Skala target**: ~600 siswa, ~50 proctor, 1 super admin.
**Constraint**: Firebase Spark (gratis) — tanpa Cloud Functions.

### 4.1 Tech Stack (Rencana)

| Komponen | Teknologi |
| --- | --- |
| **Frontend** | Flutter (Android + iOS + Web) |
| **Backend** | Firebase (Auth + Firestore saja, **tanpa Cloud Functions**) |
| **Auth** | Firebase Authentication (email/password, self-register) |
| **Database** | Cloud Firestore |
| **QR Generation** | Client-side (di Proctor App, oleh Super Admin) |
| **TOTP Engine** | Sama dengan ExamBro — package `otp` (RFC 6238, SHA1, 6 digit, 30 detik) |

> **Tidak menggunakan Cloud Functions** karena tidak tersedia di Firebase Spark (gratis).
> Semua logika dijalankan di client + dijaga oleh Firestore Security Rules.

### 4.2 Firebase Free Tier (Spark) — Estimasi Pemakaian

| Resource | Limit Gratis/hari | Estimasi Pemakaian | Status |
| --- | --- | --- | --- |
| **Firestore Reads** | 50.000 | ~600 (51 login + 250 list sesi + 50 baca secret + overhead) | Aman |
| **Firestore Writes** | 20.000 | ~80 (buat sesi + update status + registrasi) | Aman |
| **Firestore Storage** | 1 GiB | ~1 MB (651 user docs + sesi docs) | Aman |
| **Auth MAU** | 50.000/bulan | 651 | Aman |
| **Cloud Functions** | 0 (tidak ada) | 0 | Tidak dipakai |

**Prinsip hemat Firestore:**
1. **Baca 1x, cache di memori** — Proctor baca secret sesi sekali, generate OTP lokal. Tidak perlu real-time listener ke Firestore untuk OTP.
2. **Tidak ada presence tracking** — fitur "proctor online" dihapus karena heartbeat writes bisa meledak (50 proctor × 1 write/30 detik × 4 jam = 24.000 writes).
3. **Minimalisir real-time listener** — pakai one-time read (`get()`) sebisa mungkin, hanya pakai stream/snapshot listener untuk session list Super Admin.

### 4.3 Role & Hak Akses

#### Super Admin

Super Admin adalah kepala IT / koordinator ujian yang memiliki kontrol penuh.
Hanya ada **1 orang** — akun pertama yang dibuat di Firestore (di-seed manual saat setup awal).

| Fitur | Detail |
| --- | --- |
| **Approve Akun Proctor** | Proctor self-register → Super Admin set `role: "proctor"` dan `isActive: true` |
| **Nonaktifkan Proctor** | Set `isActive: false` → proctor tidak bisa login lagi |
| **Buat Sesi Ujian** | Input: nama sesi, URL ujian, waktu mulai/selesai |
| **Generate TOTP Secrets** | Otomatis generate `exit_secret` dan `alarm_secret` (Base32 random) saat buat sesi |
| **Generate QR Code** | Gabungkan URL + secrets + session_id → JSON → QR Code. Bisa cetak/tampilkan |
| **Lihat Kode TOTP** | Bisa lihat kode OTP real-time (generate lokal dari secret di memori) |
| **Monitor Sesi** | Lihat status semua sesi (scheduled, active, ended) |
| **Aktifkan/Akhiri Sesi** | Ubah status sesi `scheduled → active → ended` |

#### Proctor (Pengawas Ruangan)

Proctor adalah pengawas di lapangan yang bertugas di ruangan ujian.

| Fitur | Detail |
| --- | --- |
| **Self-Register** | Daftar sendiri via email/password. Status awal: `pending` (belum bisa akses sesi) |
| **Login** | Login setelah diapprove oleh Super Admin |
| **Pilih Sesi Aktif** | Lihat daftar sesi ujian yang statusnya `active` (one-time read) |
| **Lihat Kode Exit OTP** | Baca secret 1x dari Firestore → generate OTP lokal tiap 30 detik |
| **Lihat Kode Alarm OTP** | Baca secret 1x dari Firestore → generate OTP lokal tiap 30 detik |
| **TIDAK bisa** | Generate QR, buat sesi, kelola akun, lihat secret mentah, akses sesi non-aktif |

### 4.4 Alur Registrasi (Tanpa Cloud Functions)

```
1. Proctor buka Proctor App -> klik "Daftar"
       |
       v
2. Input email + password -> Firebase Auth createUser
   (siapa saja bisa daftar, tapi belum bisa akses apa-apa)
       |
       v
3. App otomatis buat doc di /users/{uid}:
   {
     email: "guru@sekolah.id",
     displayName: "Pak Budi",
     role: "pending",
     isActive: false,
     createdAt: timestamp
   }
       |
       v
4. App tampilkan: "Akun Anda menunggu persetujuan Super Admin."
       |
       v
5. Super Admin buka halaman "Kelola Proctor"
   -> lihat daftar user dengan role "pending"
   -> klik "Approve" -> update: role: "proctor", isActive: true
       |
       v
6. Proctor login ulang / refresh -> role sudah "proctor"
   -> bisa akses daftar sesi aktif
```

**Firestore Security Rules** memastikan:
- User `pending` tidak bisa baca `/sessions` sama sekali.
- User hanya bisa buat doc `/users/{uid}` sendiri (tidak bisa set role selain `pending`).
- Hanya `super_admin` yang bisa update role user lain.

### 4.5 Struktur Data Firestore

```
/users/{userId}
  email: string
  displayName: string
  role: "super_admin" | "proctor" | "pending"
  createdAt: timestamp
  isActive: boolean

/sessions/{sessionId}
  name: string
  examUrl: string
  exitSecret: string
  alarmSecret: string
  createdBy: string
  createdAt: timestamp
  startsAt: timestamp
  endsAt: timestamp
  status: "scheduled" | "active" | "ended"
```

> **Tidak ada** `alertCount` untuk menghindari write tambahan.
> **Tidak ada** subcollection agar struktur tetap flat dan hemat read.

### 4.6 Firestore Security Rules

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

    match /users/{userId} {
      allow read: if request.auth != null && request.auth.uid == userId;
      allow read: if request.auth != null && userRole() == "super_admin";

      allow create: if request.auth != null
        && request.auth.uid == userId
        && request.resource.data.role == "pending"
        && request.resource.data.isActive == false;

      allow update: if request.auth != null && userRole() == "super_admin";
      allow delete: if false;
    }

    match /sessions/{sessionId} {
      allow read: if request.auth != null && userRole() == "super_admin";

      allow read: if request.auth != null
        && userRole() == "proctor"
        && isActive()
        && resource.data.status == "active";

      allow write: if request.auth != null && userRole() == "super_admin";
    }
  }
}
```

### 4.7 Alur Kerja Proctor App

#### A. Super Admin — Persiapan Ujian

```
1. Login sebagai Super Admin
       |
       v
2. Buat Sesi Ujian Baru
   - Input: Nama sesi, URL ujian, jadwal
   - Otomatis generate (client-side):
     - session_id (unique)
     - exit_secret (random Base32, 16 char)
     - alarm_secret (random Base32, 16 char)
       |
       v
3. Simpan ke Firestore /sessions/{sessionId}
       |
       v
4. Generate QR Code (client-side)
   - Data: {"url": "...", "session_id": "...", "exit_secret": "...", "alarm_secret": "..."}
   - Tampilkan QR di layar atau cetak
       |
       v
5. Distribusi QR ke device siswa
       |
       v
6. Saat ujian dimulai: ubah status sesi -> "active"
```

#### B. Proctor — Selama Ujian

```
1. Login sebagai Proctor
       |
       v
2. Baca daftar sesi aktif (one-time read)
       |
       v
3. Pilih sesi -> baca detail sesi termasuk secrets (1 read)
   -> secrets disimpan di memori (RAM)
   -> OTP di-generate lokal dari secret di memori
       |
       v
4. Tampilkan Exit OTP dan Alarm OTP real-time
   Kode digenerate lokal tiap 30 detik
       |
       v
5. Proctor membacakan Exit OTP saat siswa keluar normal
6. Proctor/Admin membacakan Alarm OTP saat reset cheat warning
```

**Poin penting**: Setelah secret dibaca sekali, **tidak ada request Firestore lagi** untuk OTP.

#### C. Super Admin — Akhiri Ujian

```
1. Waktu ujian habis / semua siswa selesai
       |
       v
2. Super Admin ubah status sesi -> "ended"
       |
       v
3. Proctor yang refresh daftar sesi tidak akan lihat sesi ini lagi
```

### 4.8 Halaman-Halaman Proctor App

| Halaman | Role | Deskripsi | Firestore |
| --- | --- | --- | --- |
| **Login** | Semua | Email + password (Firebase Auth) | 0 reads |
| **Register** | Baru | Self-register, buat doc `/users/{uid}` | 1 write |
| **Menunggu Approval** | Pending | Info "akun menunggu persetujuan" | 0 reads |
| **Dashboard** | Super Admin | Ringkasan sesi aktif dan jumlah proctor | ~10 reads |
| **Kelola Sesi** | Super Admin | List sesi, buat baru, edit, akhiri | ~5 reads |
| **Buat Sesi** | Super Admin | Form nama, URL, jadwal, generate QR | 1 write |
| **Detail Sesi + QR** | Super Admin | Lihat QR dan OTP real-time | 1 read |
| **Kelola Proctor** | Super Admin | List pending/proctor, approve/nonaktifkan | ~50 reads |
| **Daftar Sesi Aktif** | Proctor | List sesi `active` | ~5 reads |
| **Layar OTP** | Proctor + Super Admin | Exit OTP + Alarm OTP | 1 read awal |

### 4.9 Keamanan Proctor App

| Aspek | Implementasi |
| --- | --- |
| **Autentikasi** | Firebase Auth dengan self-register + approval |
| **Otorisasi** | Firestore rules berbasis role |
| **Secret di Proctor** | Dibaca 1x, disimpan di RAM, OTP digenerate lokal |
| **Transport** | Firebase SDK via TLS/HTTPS |
| **Session Isolation** | Proctor hanya bisa baca sesi `active` |
| **TOTP Sinkronisasi** | SHA1, 6 digit, 30 detik, ±1 window, sinkron NTP |
| **QR Tidak Bisa Dipakai Ulang** | Secret per sesi; selesai sesi -> QR tidak berguna |
| **Self-Register Abuse** | Tanpa approval Super Admin, user `pending` tidak bisa akses data |

### 4.10 Diagram Hubungan ExamBro Pro ↔ Proctor App

```
                    +----------------------+
                    |     SUPER ADMIN      |
                    |    (Proctor App)     |
                    +----------+-----------+
                               |
                    1. Buat sesi + secrets
                    2. Generate QR Code
                               |
              +----------------+----------------+
              |                |                |
              v                v                v
     +-------------+  +-------------+  +-------------+
     |   QR Code   |  |  Firestore  |  |   QR Code   |
     |  (Siswa A)  |  |  (secrets)  |  |  (Siswa B)  |
     +------+------+  +------+------+  +------+------+
            |                |                |
         Scan QR        Read 1x saja       Scan QR
            |           (cache RAM)           |
     +------v------+  +------v------+  +------v------+
     |  ExamBro A  |  |   PROCTOR   |  |  ExamBro B  |
     |   (Siswa)   |  |  (Pengawas) |  |   (Siswa)   |
     +-------------+  +-------------+  +-------------+
            |                |                |
            |     Generate OTP lokal          |
            |     dari secret di RAM          |
            |          "847293"               |
            |                |                |
            +----- Ketik di dialog ----------+
                     Verifikasi valid
```

**Tidak ada koneksi langsung** antara ExamBro Pro dan Proctor App. Keduanya terhubung melalui:
1. **QR Code** — membawa secret dari Super Admin ke device siswa (offline, 1x scan).
2. **Algoritma TOTP** — secret yang sama menghasilkan kode yang sama pada waktu yang sama (tanpa internet).

### 4.11 Setup Awal (Satu Kali)

Karena tidak ada Cloud Functions, Super Admin account pertama harus di-seed manual:

1. Super Admin daftar via app.
2. Edit Firestore via Firebase Console.
3. Pada `/users/{uid}`, set `role: "super_admin"` dan `isActive: true`.
4. Setelah itu Super Admin bisa approve proctor lain dari dalam app.

## 5. Alur Kerja (System Flow)

### A. Alur Memulai Ujian (Normal Flow)

1. **Buka Aplikasi**: Masuk ke Splash Screen. Jika tidak ada sesi aktif, diarahkan ke `/home`.
2. **Home Screen**:
   - Aplikasi cek izin DND via `DndService.checkPermission()`.
   - Jika belum diizinkan, tampil banner edukasi oranye yang menjelaskan mengapa izin DND diperlukan dan tombol "Buka Pengaturan DND".
   - Saat user kembali dari Settings, `didChangeAppLifecycleState(resumed)` otomatis re-check izin.
   - Jika user menekan "SCAN QR CODE" tanpa izin DND, muncul dialog peringatan dengan opsi "Buka Pengaturan" atau "Lanjut Tanpa DND".
3. **Scanner**: Siswa memindai QR Code yang berisi URL ujian. Setelah berhasil, aplikasi menavigasi ke `/exam` dengan membawa parameter URL.
4. **Masuk Exam Screen**:
   - URL dimuat ke dalam `WebView`.
   - `ExamSessionService` merekam status `SessionState.active` dan menyimpan URL untuk crash recovery.
   - **Mode Aman (Secure Mode) Diaktifkan**:
     - `FLAG_SECURE` aktif.
     - UI masuk mode `immersiveSticky`.
     - **DND diaktifkan** via `DndService.enableDnd()`.
     - Sistem _Screen Pinning_ diaktifkan secara paksa.

### B. Alur Selama Ujian Berlangsung

1. **Crash Recovery & Form Persist**:
   - WebView menyuntikkan JavaScript untuk menyimpan setiap input form peserta ke `localStorage`.
   - `ExamSessionService` terus menyimpan URL terakhir.
2. **Peringatan Baterai**: `BatteryService` memonitor baterai. Jika level <= threshold, overlay peringatan muncul.
3. **Penyegaran Halaman**: Tersedia FAB untuk me-refresh WebView.

### C. Alur Keluar Ujian (Normal Exit)

1. Siswa menekan tombol back.
2. Aplikasi mencegat event back dan meminta **kode OTP** dari pengawas.
3. Pengawas membuka Proctor App dan memasukkan kode TOTP 6 digit.
   - Jika salah: ujian tetap berlanjut, counter percobaan bertambah.
   - Jika benar: sesi dibersihkan, screen pinning dimatikan, mode aman dan DND di-restore, lalu kembali ke `/home`.

### D. Alur Deteksi Kecurangan (Cheat Flow)

Sistem memiliki 5 skema deteksi kecurangan:

1. **Screen Pinning Dilepas**: Langsung memicu alarm.
2. **Menekan Tombol Home/Recent**: Threshold = **1 kali**, langsung memicu alarm.
3. **Menekan Tombol Back Berkali-kali tanpa kode OTP yang valid**: Threshold = **3 kali**, lalu memicu alarm.
4. **Split Screen / Picture-in-Picture (PiP)**: Polling tiap 5 detik. Jika terdeteksi, langsung memicu alarm.
5. **Accessibility Service Mencurigakan**: Polling tiap 5 detik. Jika terdeteksi, langsung memicu alarm.

Saat trigger alarm dipanggil:

1. `_isExiting` ditandai `true` agar tidak terpicu ganda.
2. `ExamSessionService.markCheating()` menyimpan `SessionState.cheating`.
3. Stream listener dan timer dibatalkan, tapi **Screen Pinning dan `FLAG_SECURE` tetap aktif**.
4. `CheatAlertService.triggerAlert()` memaksa volume ke 100% dan memutar alarm berulang.
5. Navigasi paksa ke `/cheat-warning`.

### E. Alur CheatWarningScreen

Ketika siswa diarahkan ke `/cheat-warning`, layar ini mengaktifkan mekanisme berikut:

1. **Immersive Mode** ditegakkan ulang tiap 3 detik.
2. **`FLAG_SECURE`** tetap aktif.
3. **Tidak melakukan re-pin Screen Pinning**.
4. **Volume Enforcement** tiap 2 detik.
5. **`PopScope(canPop: false)`** memblokir tombol back total.
6. **Lifecycle Observer** menegakkan ulang immersive mode dan volume saat resume.

### F. Alur Penyelesaian Keadaan Darurat / Reset Curang

1. Siswa tidak bisa keluar dari `/cheat-warning` tanpa tindakan lebih lanjut.
2. **Admin Utama** harus dipanggil.
3. Admin membuka Proctor App dan memasukkan **kode TOTP Alarm**.
4. Jika valid:
   - Timer enforcement dihentikan.
   - Alarm dihentikan, volume dikembalikan ke posisi semula.
   - Sesi aplikasi dibersihkan (`SessionState.none`).
   - Screen Pinning dihentikan jika masih aktif, `FLAG_SECURE` dilepas, UI mode dikembalikan ke `edgeToEdge`.
   - **DND di-restore** ke state semula.
   - Siswa diarahkan ke `/` dan harus scan ulang jika diizinkan.

Diagram alur ringkas:

```text
[Home] -> (Scan QR) -> [Exam] (Secure Mode ON) -> (Pengerjaan) -> [Exit Dialog] -> (Valid OTP) -> [Home]
  |
  | (Mencoba Keluar Paksa/Cheat)
  v
[Cheat Warning] (Alarm Menyala) -> (Admin Alarm OTP Valid) -> [Home]
```