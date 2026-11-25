# PureSound Offline

100% oflayn, telefonning o'zida (On-Device AI) ishlaydigan audio va video shovqin tozalovchi Flutter ilovasi.

## GitHub orqali tayyor APK olish (Android Studio'siz)

1. GitHub'da yangi repozitoriy yarating (masalan: `puresound-offline`).
2. Ushbu ZIP ichidagi **barcha fayl va papkalarni** (`.github` papkasi bilan birga) repozitoriyga yuklang.
3. GitHub sahifasida yuqoridagi **Actions** bo'limiga o'ting.
4. **Build PureSound APK** jarayoni avtomatik boshlanadi (yoki `Run workflow` tugmasini bosing).
5. 3–5 daqiqadan so'ng jarayon yakunlangach, pastdagi **Artifacts** bo'limidan `PureSound-Offline-APK` faylini yuklab olib telefoningizga o'rnating.

## Lokal kompyuterda yig'ish

```bash
flutter create . --platforms=android
flutter pub get
flutter build apk --release --split-per-abi
```
