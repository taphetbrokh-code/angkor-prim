# ANGKOR PRIM

App មើលវីដេអូ និងស្តាប់ចម្រៀង (Flutter / Android) — ចាក់ផ្ទៃខាងក្រោយបាន បិទអេក្រង់ក៏នៅស្តាប់បាន។

## មុខងារ
- ទំព័រដើម មាន chip ប្រភេទ (ចម្រៀងខ្មែរ ព័ត៌មាន កំប្លែង ហ្គេម ...) រំកិលចុះផ្ទុកបន្ត
- ផ្ទាំង **តន្ត្រី** — ចុចបទមួយ វាចាក់បន្តរហូតដូច playlist
- ស្វែងរក + ការណែនាំពេលវាយ + ប្រវត្តិស្វែងរក + បិទភ្ជាប់តំណ YouTube ដើម្បីចាក់ផ្ទាល់
- អេក្រង់មើល៖ ចំណងជើង ចំនួនមើល ចូលចិត្ត ចែករំលែក ឆានែល ជាវ ការពិពណ៌នា មតិយោបល់ វីដេអូបន្ទាប់ Autoplay
- Player៖ ចុចពីរដងរំលង ±10s, fullscreen, គុណភាព 144p–1080p, ល្បឿន 0.25x–2x, Loop, Sleep timer
- **ចាក់ផ្ទៃខាងក្រោយ & បិទអេក្រង់** + ប៊ូតុងបញ្ជានៅ notification / lock screen
- របៀប **ស្តាប់តែសំឡេង** (សន្សំ data)
- Mini player (ទាញចុះដើម្បីបង្រួម) ជួរចាក់ (Play next / Add to queue)
- ឆានែល ការជាវ (feed វីដេអូថ្មី) បណ្ណាល័យ៖ ប្រវត្តិ មើលពេលក្រោយ ចូលចិត្ត

ទិន្នន័យ (ជាវ ចូលចិត្ត ប្រវត្តិ) រក្សាទុកក្នុងទូរស័ព្ទ — មិនត្រូវការ login ទេ។

## Build APK ដោយ GitHub Actions (មិនចាំបាច់ដំឡើងអ្វីលើកុំព្យូទ័រ)
1. បង្កើត repository ថ្មីនៅ GitHub (ឧ. `angkor-prim`)
2. Upload ឯកសារទាំងអស់ក្នុង folder នេះ (រួមទាំង folder `.github`)
3. ចូល tab **Actions** → **Build ANGKOR PRIM APK** → វានឹង build ដោយស្វ័យប្រវត្តិ (ប្រហែល 8–12 នាទី)
4. ពេលចប់ ទាញយក APK ពី **Releases** (ឬពី Artifacts ក្នុង run នោះ)
5. ដំឡើងលើ Android (អនុញ្ញាត "Install unknown apps")

## Build លើកុំព្យូទ័រ (ជម្រើស)
```bash
bash tool/setup_android.sh
flutter pub get
dart run flutter_launcher_icons
flutter build apk --release
```
APK នៅ `build/app/outputs/flutter-apk/app-release.apk`

## ចំណាំ
- App ទាញ stream ដោយផ្ទាល់ (library `youtube_explode_dart`) ដូច NewPipe — មិនអាចដាក់លើ Play Store បានទេ ចែកចាយជា APK ប៉ុណ្ណោះ។
- ពេល YouTube ផ្លាស់ប្តូរប្រព័ន្ធ វីដេអូអាចលែងចាក់ — ដោះស្រាយដោយ update `youtube_explode_dart` ក្នុង `pubspec.yaml` រួច build ម្តងទៀត។
- Android 13+ សូមអនុញ្ញាត Notification ដើម្បីឃើញប៊ូតុងបញ្ជា។
