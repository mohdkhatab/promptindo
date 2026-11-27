# PromptIndo 🎀

A production-ready **social AI-prompt-sharing platform** — discover, copy, save,
like, remix, comment, follow and publish prompts — built as:

| Layer    | Tech |
|----------|------|
| App      | Flutter + Riverpod (Clean Architecture, feature folders) |
| Backend  | Firebase — Auth, Firestore, Storage, Cloud Functions, FCM, App Check |
| Hosting  | Firebase Hosting (deep-link verification + privacy/terms pages) |
| Tests    | Firebase Emulator Suite rules-unit-testing (deny/allow coverage of `firestore.rules`) |

This repository replaces the earlier PHP/REST variant with a pure
Firebase serverless backend. **The app contains no admin panel** — moderation
happens server-side through admin-callable Cloud Functions invoked from any
HTTP client / script with an admin custom claim (see *Admin & moderation*).

---

## 1. Repository layout

```
promptindo/
├── firebase.json              # emulator ports, hosting config, deploy targets
├── .firebaserc                # default project: prompindo
├── firestore.rules            # deny-by-default security rules (unit-tested)
├── firestore.indexes.json     # 19 composite indexes (incl. title-prefix search)
├── storage.rules              # image rules: contentType image/* + size caps
├── functions/                 # TypeScript Cloud Functions (Node 20, firebase-functions v6)
│   └── src/
│       ├── triggers/          # likes, comments, follows, prompts, reports, auth
│       ├── callables/         # social, account, admin
│       ├── scheduled/         # trending recompute + view cleanup
│       ├── notify.ts          # notification doc + FCM push from the same function
│       └── config.ts          # tunables (trend weights, App Check flag, …)
├── firestore-tests/           # rules unit tests (Emulator Suite)
├── hosting/                   # static site served by Firebase Hosting
│   ├── .well-known/assetlinks.json        # Android App Links verification
│   ├── .well-known/apple-app-site-association
│   ├── index.html, privacy.html, terms.html, robots.txt, manifest.json
├── scripts/ (functions/scripts/make-admin.js)  # grant the admin custom claim
├── dist/                      # built APKs (app-debug.apk, app-release.apk)
└── app/                       # the Flutter application
    └── lib/
        ├── core/              # design system: glass widgets, curves, theme, providers, services
        └── features/          # auth, home, explore, prompts, categories, comments,
                               # bookmarks, notifications, profile, settings, shell
        #   each feature: data/ (repositories) · domain/ (entities+contracts) · presentation/
```

**Architecture rule:** screens never touch `FirebaseFirestore.instance`
directly. Every read/write goes through a repository interface in
`domain/` implemented in `data/` and provided via Riverpod
(`core/providers/firebase_providers.dart`).

---

## 2. Prerequisites

* Flutter ≥ 3.47 (Dart ≥ 3.13) — repo was built with Flutter 3.47.5
* Node.js ≥ 20 (Functions target Node 20)
* **JDK 21** for the Firebase emulators (firebase-tools no longer supports
  older Javas; JDK 17 remains fine for Gradle/Android builds)
* Firebase CLI (`npm i -g firebase-tools` or use the copy in
  `firestore-tests/node_modules/.bin/firebase`)
* A Firebase project — this repo is wired to project **`prompindo`**
  (project number `66910648137`)

---

## 3. Firebase configuration (already wired)

| File | What it configures |
|------|--------------------|
| `app/android/app/google-services.json` | Android app `Com.promptindo.ai` → project `prompindo` |
| `app/lib/firebase_options.dart` | Same values for `firebase_core` (Android done; iOS placeholder — see §10) |
| `app/android/settings.gradle.kts` + `app/build.gradle.kts` | google-services Gradle plugin |
| `.firebaserc` | default project id `prompindo` |

> ⚠️ **Package-name casing:** the Android `applicationId` is deliberately
> `Com.promptindo.ai` (mixed case) because that is exactly the package name
> registered in the Firebase console / `google-services.json`, and Android
> matches it case-sensitively. **Do not “fix” the casing** — instead consider
> renaming the app to `com.promptindo.ai` in *both* the Firebase console and
> `google-services.json` + `build.gradle.kts` together if you want lowercase.

---

## 4. Run the app locally

```bash
cd app
flutter pub get
flutter run            # device/emulator with Google Play services
```

Notes:

* **App Check** activates in monitor-only mode automatically; in debug builds
  the token is printed so you can register it in the console (§8).
* First login after registration triggers `onUserCreate`, which provisions
  `users/{uid}` + `users_private/{uid}`; the client retries provisioning a few
  times before surfacing an error.
* Deep links: `https://prompindo.web.app/p/{promptId}` etc. (see §7 hosting).

---

## 5. Firebase deploy

```bash
firebase login
firebase deploy --only firestore:rules          # firestore.rules
firebase deploy --only firestore:indexes        # firestore.indexes.json
firebase deploy --only storage                  # storage.rules
firebase deploy --only functions                # builds TS via predeploy hook
firebase deploy --only hosting                  # static site (privacy/terms/app-links)
firebase deploy                                 # everything
```

Emulated end-to-end (optional):

```bash
firebase emulators:start        # auth 9099 · firestore 8080 · storage 9199 · functions 5001
```

### Seed an admin

There is **no admin UI in the app**. Grant yourself the custom claim:

```bash
node functions/scripts/make-admin.js <UID-or-email>
# then sign out/in so the ID token refreshes; admin callables check request.auth.token.role
```

---

## 6. Firestore data model

**Top-level collections** (composite doc IDs are load-bearing — the first path
segment must equal the caller's `uid`, enforced in rules):

| Collection | Doc ID | Notes |
|------------|--------|-------|
| `users` | `{uid}` | public profile — **no `email` field**; counters/role/status are Cloud-Function-only |
| `users_private` | `{uid}` | `email` lives here (Firestore can't field-redact reads) |
| `users/{uid}/fcm_tokens` | device id | per-device FCM tokens |
| `prompts` | auto-id | `status`, `visibility`, counters, `trend_score`, denormalised creator fields |
| `likes` | `{uid}_{promptId}` | existence = liked; forged prefixes rejected by rules |
| `bookmarks` | `{uid}_{promptId}` | same discipline |
| `follows` | `{followerUid}_{followedUid}` | self-follow rejected |
| `comments` | auto-id | `prompt_id`, `parent_id` (threading), denormalised author |
| `comment_likes` | `{uid}_{commentId}` | same discipline |
| `notifications` | auto-id | **create: Cloud Functions only** (`allow create: if false`); recipient flips `is_read` |
| `categories` | slug | world-readable; writes via admin claim |
| `reports` | auto-id | create by any signed-in user; read/resolve admin-only |
| `admin_actions` | auto-id | audit log — written only by Admin SDK inside callables |
| `views` | `{uid_or_anonId}_{promptId}` | 24h view dedupe — clients never touch it |

**Composite indexes** (`firestore.indexes.json`, 19 total) include all required
ones: prompts `(status,visibility,{trend_score|created_at}desc)`,
`(status,visibility,category_id,created_at)`,
`(status,visibility,creator_id,created_at)`, **`(status,visibility,title)` for
title-prefix search**, tags array-contains, comments
`(prompt_id,status,created_at)`, notifications
`(recipient_id,created_at)` and `(recipient_id,is_read,created_at)`.

---

## 7. Cloud Functions

| Export | Kind | Does |
|--------|------|------|
| `onUserCreate` / `onUserDelete` | Auth trigger (v1 API) | provision `users`+`users_private`; cascade delete |
| `onLikeCreate/Delete` | Firestore trigger | `like_count` ±, notification + FCM to prompt owner |
| `onBookmarkCreate/Delete` | Firestore trigger | `bookmark_count` ± (no notification) |
| `onCommentCreate/Delete` | Firestore trigger | `comment_count` ±, notification, `get()` on parent |
| `onCommentLikeCreate/Delete` | Firestore trigger | comment `like_count` ±, notification |
| `onFollowCreate/Delete` | Firestore trigger | follower/following counts ±, notification |
| `onPromptCreate/Delete` | Firestore trigger | user `prompt_count`, denormalisation cleanup |
| `onReportCreate` | Firestore trigger | 1-hour duplicate-report rule, escalate repeat offenders |
| `copyPrompt` | callable | `copy_count` + clipboard-side stats, App-Check enforced |
| `recordView` | callable | dedupes via `views/{uid}_{promptId}` (24h), counts views |
| `deleteUserAccount` | callable | verified-owner full cascade (profile, prompts, media, tokens) |
| `adminSetUserStatus`, `adminSetRole`, `adminSetPromptStatus`, `adminSetPromptFeatured`, `adminDeletePrompt`, `adminDeleteComment`, `adminResolveReport`, `adminSaveCategory`, `adminDeleteCategory` | callables | admin-claim only; **every one writes `admin_actions`** |
| `recomputeTrending` | scheduled (15 min) | `trend_score = likes*3 + copies*5 + views*1 + recency_bonus` (48h decay, cap 40) |
| `cleanupViews` | scheduled | deletes expired `views` dedupe docs |

*The client **never** writes counters or `notifications` — rules deny it and
tests prove it.*

```bash
cd functions
npm install
npx tsc --noEmit     # type-check
npm run build        # emit dist/ (also runs automatically as a deploy prehook)
```

---

## 8. App Check

* Client: `FirebaseAppCheck.activate(providerAndroid: AndroidPlayIntegrityProvider(),
  providerApple: AppleDeviceCheckProvider())` in `app/lib/main.dart`.
* Enforcement for callables: `APP_CHECK_ENFORCED` in `functions/src/config.ts`.

**Enrollment flow:** ship a build (monitor-only) → register the Play Integrity
provider in the Firebase console with your Play Console package
`Com.promptindo.ai` → wait for attestation traffic → flip
`APP_CHECK_ENFORCED = true` → redeploy functions. While still enrolling, set it
to `false` or callables will reject unattested clients.

---

## 9. Security rules & tests

`firestore.rules` is deny-by-default with targeted `allow`s:

* owner-only writes; `role`/`status`/counters/`created_at` are never
  client-writable (`diff().affectedKeys()` guards)
* prompt visibility double-enforced (read **and** filtered queries)
* composite doc-ID prefix must equal `request.auth.uid`
* comment delete needs a `get()` on the parent prompt (prompt-owner moderation)
* notifications: recipient-only read, `is_read`-only update, `create: if false`
* reports: create-auth / read-admin; `admin_actions`: client write denied even
  with an admin claim (Admin SDK only)
* admin decisions use the `role: "admin"` **custom claim** only

Run the suite (JDK 21 required by firebase-tools):

```bash
cd firestore-tests && npm install && cd ..
JAVA_HOME=/usr/lib/jvm/temurin-21-jdk-amd64 \
  ./firestore-tests/node_modules/.bin/firebase emulators:exec \
  --only firestore --project prompindo-test \
  "node --test firestore-tests/test/"
```

~30 tests cover allow **and** deny paths for users, users_private, fcm_tokens,
prompts (create/edit/delete/queries/visibility), likes, bookmarks, follows,
comments (author vs prompt-owner delete via parent `get()`), comment_likes,
notifications, categories, reports, admin_actions, views and the catch-all.

`storage.rules`: `contentType.matches('image/.*')`, avatars < 5 MB,
thumbnails < 8 MB, owner-scoped writes.

---

## 10. iOS

The provided Firebase config only contains an **Android** app. To ship iOS:

1. Register an iOS app (bundle id `com.promptindo.promptindo`, matching
   `PRODUCT_BUNDLE_IDENTIFIER` in `app/ios/Runner.xcodeproj`) in the Firebase
   console.
2. Download `GoogleService-Info.plist` into `app/ios/Runner/` and add it to the
   Xcode target.
3. Replace the `ios` placeholder in `app/lib/firebase_options.dart`
   (`GOOGLE_APP_ID` / `REPLACE_WITH_IOS_APP_ID`) — or run
   `flutterfire configure`.
4. Add the reverse client id to `Info.plist` `CFBundleURLTypes` for Google
   Sign-In, and your Team ID to `hosting/.well-known/apple-app-site-association`.

---

## 11. Building APKs

```bash
cd app
flutter build apk --debug     # → build/app/outputs/flutter-apk/app-debug.apk
flutter build apk --release   # → app-release.apk (currently signed with the DEBUG key)
```

Built copies live in **`dist/`**. Before uploading to Play, configure real
release signing:

```bash
keytool -genkey -v -keystore ~/upload-keystore.jks -keyalg RSA \
        -keysize 2048 -validity 100000 -alias upload
```

```properties
# app/android/key.properties  (never commit)
storePassword=…
keyPassword=…
keyAlias=upload
storeFile=/path/to/upload-keystore.jks
```

Then wire `signingConfigs.create("release")` + `signingConfig = release` in
`app/android/app/build.gradle.kts`, or use Play App Signing (recommended:
upload the app bundle `flutter build appbundle` and let Google re-sign).

> The debug build shows a harmless Gradle warning that some Firebase plugins
> still apply the Kotlin Gradle Plugin directly — expected with current plugin
> versions; harmless until Flutter removes KGP support (upgrade plugins then).

---

## 12. Play Store checklist

- [ ] Rename decision made for `Com.promptindo.ai` casing (keep as-is or change
      console + `google-services.json` + `applicationId` **together**).
- [ ] Release signing configured (or Play App Signing with `appbundle`).
- [ ] `versionCode`/`versionName` set (from `pubspec.yaml`; currently `1.0.0+1`).
- [ ] App icon (adaptive) + feature graphic + at least 2 phone screenshots.
- [ ] Store listing text; content rating questionnaire; data-safety form
      (email, user content, FCM tokens — no sale/sharing; links to policy).
- [ ] Privacy policy URL: `https://prompindo.web.app/privacy`
      and ToS `https://prompindo.web.app/terms` (hosting already serves them).
- [ ] Deploy hosting first so those URLs resolve (also hosts
      `/.well-known/assetlinks.json` for Android App Links — replace
      `REPLACE_WITH_YOUR_UPLOAD_KEY_SHA256` with your upload-key fingerprint:
      `keytool -list -v -keystore upload-keystore.jks -alias upload`).
- [ ] Firebase: enable Email/Password + Google sign-in providers.
- [ ] `firebase deploy --only firestore:rules,firestore:indexes,storage,functions,hosting`.
- [ ] Seed categories (admin callable `adminSaveCategory`).
- [ ] App Check enrollment completed; `APP_CHECK_ENFORCED = true`.
- [ ] Test on a physical device: register → verify email → publish prompt →
      like/bookmark/copy/comment/follow → notifications → delete account.
- [ ] Ban/unban flow verified from a script using admin callables.
- [ ] Pre-launch report clean (no crashes/ANRs); target API level current.

---

## 13. Documented simplifications & deviations

Compared with the original PHP/REST version and/or the written spec:

1. **Dark-mode glass fill** — spec says white 12 % over near-black; that composites
   to ~`#282828`, which makes the mandated **pure-black text on glass**
   unreadable. Dark mode uses **white 70 %** (`0xB3FFFFFF`), light mode uses the
   literal 55 %. Single source of truth: `GlassTokens.fill`; the spec’s 12 % is
   kept as the hairline/border opacity.
2. **No admin/moderation UI in the app** (deliberate product decision — the app
   is a pure *user* app). Admin actions are callables invoked out-of-band with
   the `role: "admin"` claim; `make-admin.js` grants it. `AppUser.role` remains
   as inert data.
3. **Android package casing** — `Com.promptindo.ai` kept verbatim from the
   Firebase config (case-sensitive match); see §3.
4. **Search** — title prefix scan is merged **client-side** over a
   `title >= q && title <= q` style bounded query plus `tags array-contains`
   and username-prefix people search; there is no third-party search service
   (Algolia/Typesense dropped vs any PHP variant).
5. **“Recommended” feed** falls back to “Latest” when you follow nobody — no
   collaborative-filtering model.
6. **Username uniqueness** is best-effort via the `username_lower` mirror field;
   a create race can still slip a duplicate through (documented; a
   Firestore-transaction claim doc would be the fix).
7. **`bookmark_count`** was added to the prompt schema so bookmark triggers have
   a real counter (the original model had no server bookmark count).
8. **Dynamic Links are dead** — deep links use Hosting + `assetlinks.json` /
   AASA + the `app_links` package instead.
9. **Views** are deduped by a `views/{uid}_{promptId}` doc with a 24-hour TTL —
   no IP fingerprinting (privacy-preserving approximation of the PHP version).
10. **Push + inbox are written by the same function** (notification doc first,
    then FCM); clients only read Firestore, so history survives lost pushes.
11. **iOS is scaffold-only** — no iOS Firebase app was provided; see §10.
12. **Email verification** is enforced client-side (poll + gate). Rule-level
    `request.auth.token.email_verified` gating can be added later without
    schema changes.

---

## 14. Design system (quick reference)

* Backgrounds: dark radial `#0A0A0A→#121212`, light `#F5F5F7`; glass panels are
  white-tinted with **black text in both themes** (black-55 secondary on glass).
* One shared `GlassContainer` (blur σ26, hairline top/sides, faded bottom,
  black30 shadow) — screens never instantiate `BackdropFilter` directly.
* Type: Inter (bundled) — Display 32/700 · Title 22/700 · Subtitle 17/600 ·
  Body 15/400 h1.3 · Caption 13 · Micro 11/500 uppercase ls0.5.
* Radii: cards 22 · buttons pill · sheets 28 · dialogs 24 · fields 16; 8 px grid,
  20 px screen padding, 12 px card gap, 16 px card padding.
* Motion: `AppMotion`/`AppCurves` centralise every curve — press 0.96/100 ms,
  release spring(1/300/20), like easeOutBack 350 ms, push 380 ms easeOutQuint
  with the previous route scaled 0.95 + 10 % darken, sheets 300/250 ms over a
  40 % scrim, toasts scale-in + 1600 ms hold, tab crossfade 150 ms + sliding
  pill 250 ms, first-load stagger 40 ms/card, shimmer 1400 ms, error shake 3×±6 px.
* No Material ripple anywhere (`NoSplash.splashFactory`, no `InkWell`).

---

## 15. Troubleshooting

| Symptom | Fix |
|---------|-----|
| `firebase emulators:exec` → “Java version before 21” | `JAVA_HOME=/usr/lib/jvm/temurin-21-jdk-amd64` |
| Gradle “No space left on device” | `flutter clean`; clear `~/.npm/_cacache` / old `app/build` |
| Callables fail with permission-denied after enabling App Check | set `APP_CHECK_ENFORCED=false` while enrolling, or ship an attested build |
| Duplicate usernames under load | see §13.6 (known race) |
| Push notifications not shown on Android 13+ | grant POST_NOTIFICATIONS (declared in the manifest; prompt via FCM) |
| Google Sign-In fails on Android | add your debug + upload SHA-1/SHA-256 to the Firebase console |
