# Elite Live — mobile app

TikTok-style live broadcasting with virtual gifting, added to the existing
capability-aware camera app. Flutter, GetX, feature-first clean architecture.

Backend: **https://live.elite-center-ld.com** (see `../backend/README.md`)

---

## What was added

The camera feature is untouched and still reachable at `/camera`. The live
system is a sibling feature that follows the same layering the camera feature
already established.

```
lib/
  core/
    config/app_config.dart              environment, tuning constants
    theme/live_theme.dart               colours, type, number formatting
    services/
      network/api_client.dart           dio + envelope unwrap + token refresh
      network/live_socket_client.dart   socket.io, one connection app-wide
      storage/token_storage.dart        keychain / encrypted prefs
    errors/failures.dart                sealed AppFailure, now covers the API
  features/live/
    domain/
      entities/live_entities.dart       immutable models, no JSON knowledge
      repositories/live_repositories.dart
      repositories/live_media_engine.dart   vendor-agnostic video interface
      usecases/live_usecases.dart       one class, one `call`
    data/
      models/live_models.dart           the only place JSON is parsed
      datasources/live_remote_data_source.dart   the only place paths appear
      datasources/agora_media_engine.dart        the only Agora import
      repositories/live_repositories_impl.dart
    presentation/
      controllers/   session, live list, live room
      pages/         splash, auth, live list, go live, live room
      widgets/       video surface, chat, gift sheet, animations, chrome
      bindings/      dependency wiring
```

### Route map

```
/            splash — validates the stored session, then routes
/auth        sign in or register (one form, register reveals extra fields)
/live        discovery feed, kept current over the socket
/live/new    name the broadcast before the camera opens
/live/room   the room — host or viewer, decided by route arguments
/camera      the original camera, unchanged
```

---

## Design decisions worth knowing

**One room page, two roles.** Host and viewer differ only in the toolbar and
who owns the room's lifecycle. Chat, gifts, reactions, the podium and the
scrims are identical, so `LiveRoomController` takes a `LiveRoomMode` instead of
duplicating several hundred lines across two screens.

**The vendor is behind an interface.** `LiveMediaEngine` describes what the app
needs — join as host, join as audience, switch camera, renew token. The Agora
implementation is one file. Nothing in the controllers or widgets imports the
SDK, so replacing Agora means writing a second implementation.

**Reactions are batched.** A viewer can tap the heart dozens of times a second.
Hearts animate locally on every tap; the count is flushed to the server once
per `AppConfig.reactionFlushInterval` (900 ms) as a single request.

**Gifts are queued, not stacked.** A legendary gift covers most of the screen.
`GiftAnimationOverlay` plays one at a time for its own duration, so a burst of
gifts cannot black out the video.

**Chat follows the tail, unless you scrolled.** New messages auto-scroll only
while the viewer is already near the bottom, so reading back is not interrupted.

**The sender's own message comes back through the socket.** Chat is emitted over
the socket rather than optimistically appended, so everyone in the room sees the
same ordering, including the sender.

**Hearts skip the sender.** A `reaction:burst` echoed to the person who sent it
is ignored — they already saw their own hearts locally, and replaying would
double every tap.

**Leaving runs teardown.** `PopScope` intercepts the back gesture so the camera
is released, the channel is left and the server is told. A host is asked to
confirm first, because ending closes the room for everyone watching.

---

## Running it

```bash
flutter pub get
flutter run                                   # uses the deployed backend
```

Point it somewhere else with a define:

```bash
# Android emulator reaching a server on this machine
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:4000

# physical device on the same network
flutter run --dart-define=API_BASE_URL=http://192.168.1.20:4000
```

`localhost` on an Android emulator means the emulator itself, which is the usual
reason a local backend appears unreachable.

### Demo accounts

The deployed backend has `bashar` and `sara`, password `EliteLive2026!`, each
starting with 1,000 coins. Sign in as one on a phone and the other on a second
device (or register a new account — registration also grants 1,000 coins) to see
a gift travel between them.

To try the gifting loop on a single device: go live as `bashar`, then sign in as
`sara` elsewhere and send a crown.

---

## Video is currently a placeholder

The backend runs with `RTC_PROVIDER=mock` because no Agora account is connected
yet. Everything else is real: rooms open and close, chat and gifts and hearts
travel between devices in real time, coins are debited, diamonds are credited
and the leaderboards update.

Where video would be, the app shows a labelled placeholder — deliberately, since
a black rectangle reads as a bug. `_MockSurface` in `live_video_surface.dart`.

Turning on real video is a server-side env change only, described in
`../backend/README.md`. **No app rebuild is required**: the app reads the
provider from the credentials the server issues per room.

---

## Platform notes

### Android

`INTERNET` was missing from the manifest. Flutter injects it into debug builds
only, so a release build could not have reached the API at all. Added, along
with the network-state and audio-routing permissions the RTC engine needs.

**AGP is pinned to 8.12.1** in `android/settings.gradle.kts`. AGP 9 turned "two
libraries declare the same namespace" into a hard error, and Agora 6.5.4 ships
`iris-rtc` and `agora-special-full` both declaring `io.agora.rtc`. Upgrading to
Agora 6.6.x is not a way out either: it pins `ffi ^1.1.2`, which cannot resolve
alongside `device_info_plus` (`ffi ^2.x`) used by the camera feature. Revisit
when Agora ships distinct namespaces and an `ffi` 2.x constraint.

`android/build.gradle.kts` also raises any plugin module compiling below SDK 35,
because Agora declares `compileSdk 31` while its own `androidx.window`
dependency requires 33+. It is registered before the existing
`evaluationDependsOn` block, since `afterEvaluate` cannot attach to an
already-evaluated project.

### iOS

**Swift Package Manager is disabled** (`flutter config --no-enable-swift-package-manager`).
Agora 6.5.4's SPM manifest references a header it does not ship
(`AgoraRtcWrapper/AgoraPIPController.h`), which fails the build. CocoaPods
resolves the same SDK correctly.

Camera and microphone usage descriptions were already present for the camera
feature and cover live streaming too.

---

## Known gaps

- **Stream thumbnails.** The feed shows a stable per-host tinted card with the
  host's initial. Real thumbnails need a snapshot from the media service.
- **Gift artwork.** The catalogue ships emoji in `iconUrl`; `animationAsset` is
  the field a Lottie or Rive file goes in, and the tier system already drives
  how loud each gift's presentation is.
- **Avatars.** The model and widgets handle `avatarUrl`, but there is no upload
  endpoint yet, so everyone renders as an initial.
- **Payments.** See the warning in the backend README.
