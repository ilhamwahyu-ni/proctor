# Proctor App Working Rules

Gunakan file ini sebagai ringkasan aturan implementasi untuk repo proctor.

## Prioritas Utama

- Anggap `.github/instructions/rulesistimflow.instructions.md` sebagai source of truth utama.
- Jangan menambahkan fallback static PIN. Verifikasi harus tetap TOTP-only.
- Pertahankan pemisahan role `super_admin`, `proctor`, dan `pending` di level UI, service, dan Firestore rules.
- Pastikan secret sesi hanya dibaca saat perlu lalu dipakai untuk generate OTP lokal. Hindari polling/read berulang ke Firestore untuk OTP.
- Jaga desain tetap hemat read/write Firestore dan kompatibel dengan Firebase Spark tanpa Cloud Functions.

## Ekspektasi Arsitektur

- Gunakan Flutter dengan struktur yang bersih dan mudah dipisah antara presentasi, service, dan data.
- Pakai `Provider` dan `ChangeNotifier` untuk shared state, bukan state global ad hoc.
- Gunakan `GoRouter` untuk routing utama aplikasi.
- Hindari logika bisnis langsung di widget tree.

## Fitur Inti yang Tidak Boleh Digeser

- Registrasi proctor membuat user `pending` dan belum boleh mengakses sesi.
- Hanya `super_admin` yang boleh approve proctor dan mengelola sesi.
- Proctor hanya boleh melihat sesi dengan status `active`.
- OTP exit dan alarm harus terpisah.
- QR sesi harus berbasis JSON yang memuat URL dan kedua secret TOTP.

## Saat Menambah atau Mengubah Kode

- Cocokkan perubahan dengan flow yang terdokumentasi sebelum mengubah UI atau data model.
- Jika ada konflik antara implementasi dan flow, ikuti flow lalu jelaskan gap-nya.
- Hindari solusi yang menambah kompleksitas backend bila bisa diselesaikan aman di client + Firestore rules.