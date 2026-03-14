---
description: "Gunakan saat mengubah auth, role, Firestore data/rules, atau alur OTP di Proctor App."
applyTo: "**/*.{dart,md,js,ts,txt,json}"
---

# Proctor Auth, Role, and Security Rules

## Role Model

- Role yang valid hanya `super_admin`, `proctor`, dan `pending`.
- User baru harus dibuat sebagai `pending` dengan `isActive: false`.
- Hanya `super_admin` yang boleh approve, mengubah role, atau menonaktifkan user lain.

## OTP Rules

- Gunakan TOTP-only untuk verifikasi.
- Pisahkan `exit_secret` dan `alarm_secret`.
- Jangan tambahkan fallback static PIN, master PIN, atau bypass lokal.
- OTP harus digenerate lokal dari secret yang sudah dibaca, bukan meminta kode dari server setiap 30 detik.

## Firestore Constraints

- Desain harus tetap kompatibel dengan Firebase Spark tanpa Cloud Functions.
- Hindari presence tracking atau heartbeat writes.
- Minimalkan listener real-time jika one-time read sudah cukup.
- Proctor hanya boleh membaca sesi `active`.
- Pending user tidak boleh membaca sesi.

## Data Model Expectations

- `/users/{userId}` menyimpan email, display name, role, createdAt, dan isActive.
- `/sessions/{sessionId}` menyimpan nama sesi, exam URL, dua secret TOTP, creator, timestamp, jadwal, dan status.
- Jangan menambah struktur yang mendorong read/write berlebihan tanpa alasan kuat.