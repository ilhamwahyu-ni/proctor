# Proctor App

Repo ini adalah scaffold awal untuk aplikasi Proctor pendamping ExamBro Pro.
Fokusnya ada di role-based flow untuk `super_admin`, `proctor`, dan `pending`,
serta alur sesi ujian yang memakai Exit OTP dan Alarm OTP terpisah.

## Cakupan Saat Ini

- Routing dasar dengan `go_router`
- Shared state dengan `Provider` + `ChangeNotifier`
- Model user dan exam session
- Repository in-memory untuk scaffold sebelum Firebase diintegrasikan
- Login, register, pending approval, dashboard super admin, dashboard proctor,
  dan detail sesi OTP
- Generate OTP lokal dari secret session menggunakan package `otp`

## Aturan Implementasi

Source of truth repo ini ada di file berikut:

- `.github/instructions/rulesistimflow.instructions.md`
- `.github/instructions/proctor-auth-security.instructions.md`
- `.github/instructions/exam-flow-security.instructions.md`
- `.github/copilot-instructions.md`

Ringkasnya:

- Tidak boleh ada fallback static PIN
- Exit OTP dan Alarm OTP harus dipisah
- User baru selalu `pending`
- Hanya `super_admin` yang boleh approve proctor dan mengelola sesi
- Proctor hanya melihat sesi dengan status `active`
- Desain harus tetap hemat read/write Firestore dan kompatibel dengan Spark

## Akun Demo Scaffold

- `admin@proctor.local / admin123`
- `proctor@proctor.local / proctor123`
- `pending@proctor.local / pending123`

## Langkah Berikutnya

1. Sambungkan `AuthRepository` ke Firebase Authentication.
2. Ganti repository in-memory dengan Firestore-backed repositories.
3. Tambahkan QR generation, session CRUD penuh, dan binding ke Firestore rules.
4. Tambahkan test untuk role redirect, approval flow, dan status sesi aktif.
