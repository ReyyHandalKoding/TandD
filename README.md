# TandD 2.0 - Full Social App

TandD = Terrain + Dynimate.

Fitur utama:
- Supabase Auth login/register
- Profil: username, nama, bio, website, avatar, banner
- Feed terbaru & following
- Search akun
- Buat posting teks/foto/video
- Like, komentar, repost, bookmark, share
- Video feed
- Follow/unfollow
- Notifikasi
- DM realtime via Supabase Realtime
- Report/delete posting
- Supabase Storage
- RLS
- GitHub Actions build APK

## 1. Supabase
Buka Supabase SQL Editor dan jalankan:
`supabase/schema.sql`

## 2. Key
Edit:
`app/src/main/assets/config.js`

Isi `anonKey` dengan anon/publishable key milik project Supabase.
Jangan gunakan service_role di APK.

## 3. Build GitHub
Push ke:
https://github.com/ReyyHandalKoding/TandD

Workflow `.github/workflows/build.yml` akan membangun APK Debug.
Tidak perlu Gradle wrapper lokal.

## Catatan
Library Supabase JS dimuat saat aplikasi berjalan dari jsDelivr, sehingga perangkat membutuhkan internet.


## Email verification & upload fix
- Android WebView now supports native file chooser uploads.
- Profile/upload controls are custom modern buttons instead of raw file inputs.
- Default avatar is `default_avatar.png` based on the third uploaded image.
- Email verification redirects to `tandd://auth/callback`; add this exact URL to Supabase Authentication > URL Configuration > Redirect URLs.
