---
description: "Gunakan saat mengubah flow ExamBro yang berinteraksi dengan Proctor App atau dokumentasi flow keamanan ujian."
applyTo: "**/*.{dart,md}"
---

# Exam Flow and Security Guardrails

## Exit and Alarm Flow

- Exit ujian normal harus memakai Exit OTP dari Proctor App.
- Reset kondisi curang harus memakai Alarm OTP dari Proctor App.
- Kedua flow tidak boleh digabung menjadi satu secret atau satu kode yang sama.

## Secure Exam Expectations

- Flow referensi tetap mengandalkan secure mode, immersive mode, DND handling, dan screen pinning.
- Saat mendokumentasikan integrasi Proctor App, anggap state exam harus bisa mengaktifkan dan me-restore mode aman dengan benar.
- Persyaratan automatic time/NTP harus tetap dianggap wajib untuk validitas TOTP.

## Cheat Handling Expectations

- Perilaku cheat warning dianggap jalur blokade yang hanya bisa direset oleh alarm OTP.
- Jangan mendesain flow yang melemahkan deteksi curang atau membuka jalan keluar tanpa otorisasi pengawas/admin.
- Jika menulis dokumentasi integrasi, pertahankan asumsi bahwa cheat detection bersifat agresif dan reset memerlukan otorisasi eksplisit.