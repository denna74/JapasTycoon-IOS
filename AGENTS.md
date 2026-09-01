# Project Knowledge

## Gotchas

- **Never use `get_name` as a custom method name** — it conflicts with `GDScript.get_name()` (built-in, 0 args). Use `get_japas_name` or similar instead.
- **TextureButton with `ignore_texture_size = false` (default) ignores parent sizing** — when a `TextureButton` is a child of a manually-sized `Control`, setting `offset_right`/`offset_bottom` on the parent does NOT visually resize the texture. The TextureButton overflows to at least the texture's native size. ALWAYS set `ignore_texture_size = true` on any TextureButton that should shrink below its texture size.
- **GDScript parses type names at parse-time**, even inside unreachable blocks. Native iOS plugin classes must never be referenced directly (e.g. never `var x: GodotIap` / `ClassDB.instantiate("GodotIap")` for app code). Use the GDScript wrappers instead. The `AdsManager` drives the GDScript `UnityAds` autoload; `IAPManager` drives the `GodotIapPlugin` autoload (the `GodotIapWrapper` from `addons/godot-iap/godot_iap.gd`) via `get_node_or_null("/root/GodotIapPlugin")`. Do NOT call snake_case APIs (`init_connection`, `fetch_products`, `request_purchase`, `finish_transaction`) on the native `GodotIap` class — only the wrapper exposes them.
- **`IAPConfig.get_coin_reward()` keys** are the internal keys (`instant_coins_1/2/3`), NOT the product IDs. `MenuLevelSelect.gd` calls `get_coin_reward(sku)` with a product ID, so `get_coin_reward` maps product ID → reward internally (unlike the original Android version which keyed by SKU).

## Git Policy

- **No git actions** — I must never commit, push, branch, merge, or run any git command. The user handles all git operations manually.

## Golden Rule

- **Only implement exactly what the user asks. Never add extra logic, features, or behaviors they didn't request. If you have an idea, ask me first. No overthinking, no "helpful" additions without my confirmation.**
- **HARD DECISION — I DO NOT USE ADMOB, I USE UNITY ADS.** The iOS ads integration is Unity Ads exclusively. Never propose, evaluate, or switch to AdMob again. This is final and not open for reconsideration — do not re-litigate it even if a "simpler" AdMob plugin appears.

## iOS-Specific Notes

- This project targets iOS using Godot 4.7 with the Mobile renderer.
- **Godot 4.7 is required for the force-quit mood penalty.** Godot 4.6.x iOS never delivers `NOTIFICATION_APPLICATION_PAUSED`/`RESUMED`/`FOCUS_IN`/`FOCUS_OUT` (upstream bug #115936, SwiftUI lifecycle migration; fixed in 4.7 via PR #116395, no 4.6 backport). `Main.gd` `_notification()` sets/clears the `pending_quit_penalty` flag on PAUSED/RESUMED — on 4.6 those never fired on iOS, so the penalty never applied. Do NOT downgrade below 4.7 or this regresses.
- IAP uses OpenIAP (StoreKit 2) — the `IAPManager` autoload drives the `GodotIapPlugin` autoload (GDScript `GodotIapWrapper`), never the native `GodotIap` class directly.
- The bundled godot-iap addon is pinned to the official **3.4.1** line. iOS export preset requires `application/min_ios_version` = **17.0** (the bundled `GodotIap.framework` / `SwiftGodotRuntime.framework` inherit the SwiftGodot iOS 17 minimum; anything lower crashes before startup). CI verifies the plugin version and framework min iOS as a drift guard (`distribute.yml` "Verify Godot IAP Plugin" step).
- Ads use Unity Ads — the `AdsManager` autoload drives the GDScript `UnityAds` autoload, which wraps the native `GodotUnityAds` iOS plugin singleton (`Engine.get_singleton("GodotUnityAds")`). The iOS plugin lives in `ios/plugins/unity-ads/` (an Objective-C++ bridge built by `build.sh`, run on CI only since it needs macOS/Xcode). The Android original used the `addons/unityads/` plugin (Android-only, not present here).
- Product IDs use reverse-domain notation: `com.japastycoon.instant_coins_1/2/3`.

## Unity Ads Notes (iOS)

- The native `GodotUnityAds` singleton and `UnityAds.xcframework` are **only present after `ios/plugins/unity-ads/build.sh` runs** (CI builds them before export). Locally, `godot --headless --import` logs "Invalid plugin config file unity-ads/unity-ads.gdip" — this is expected because the bridge/framework are not built on Linux.
- The `AdsManager` flow logic is pure GDScript driving the `UnityAds` autoload signals — it works the same on desktop/tests (where the native plugin is absent and calls are no-ops).
- Game ID / placement are configured under Project Settings → `unity_ads/` (`ios/game_id`, `ios/placements/rewarded`). Default rewarded placement is `Rewarded_iOS`.

## Build & Deploy

- **There is NO local Mac/Xcode.** ALL building, signing, uploading, and iOS diagnostics happen exclusively via GitHub Actions + fastlane (`macos-latest` runners, free for public repos). Never plan around running Xcode, altool, or gym locally.
- Fastlane handles code-signing (cert+sigh) and TestFlight upload.
- **TestFlight uploads are scarce:** App Store Connect enforces a per-app daily upload quota (ITMS-90382 "Upload limit reached"). Spend builds wisely — batch diagnostics into as few TestFlight uploads as possible. Prefer zero-upload evidence first (e.g. the `iap_products` fastlane lane via the `iap-check.yml` workflow, which only reads the ASC API).
- See `README.md` for full setup instructions.
