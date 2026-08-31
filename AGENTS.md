# Project Knowledge

## Gotchas

- **Never use `get_name` as a custom method name** — it conflicts with `GDScript.get_name()` (built-in, 0 args). Use `get_japas_name` or similar instead.
- **TextureButton with `ignore_texture_size = false` (default) ignores parent sizing** — when a `TextureButton` is a child of a manually-sized `Control`, setting `offset_right`/`offset_bottom` on the parent does NOT visually resize the texture. The TextureButton overflows to at least the texture's native size. ALWAYS set `ignore_texture_size = true` on any TextureButton that should shrink below its texture size.
- **GDScript parses type names at parse-time**, even inside unreachable blocks. All native iOS plugin types must use `ClassDB.instantiate()` / `ClassDB.class_exists()` — never reference them directly (e.g. never `var x: MobileAds` / `RewardedAd.new()`). See `IAPManager.gd` (drives `GodotIap` via `ClassDB`). The `AdsManager` does NOT use ClassDB — it drives the GDScript `UnityAds` autoload.
- **`IAPConfig.get_coin_reward()` keys** are the internal keys (`instant_coins_1/2/3`), NOT the product IDs. `MenuLevelSelect.gd` calls `get_coin_reward(sku)` with a product ID, so `get_coin_reward` maps product ID → reward internally (unlike the original Android version which keyed by SKU).

## Git Policy

- **No git actions** — I must never commit, push, branch, merge, or run any git command. The user handles all git operations manually.

## Golden Rule

- **Only implement exactly what the user asks. Never add extra logic, features, or behaviors they didn't request. If you have an idea, ask me first. No overthinking, no "helpful" additions without my confirmation.**
- **HARD DECISION — I DO NOT USE ADMOB, I USE UNITY ADS.** The iOS ads integration is Unity Ads exclusively. Never propose, evaluate, or switch to AdMob again. This is final and not open for reconsideration — do not re-litigate it even if a "simpler" AdMob plugin appears.

## iOS-Specific Notes

- This project targets iOS using Godot 4.7 with the Mobile renderer.
- **Godot 4.7 is required for the force-quit mood penalty.** Godot 4.6.x iOS never delivers `NOTIFICATION_APPLICATION_PAUSED`/`RESUMED`/`FOCUS_IN`/`FOCUS_OUT` (upstream bug #115936, SwiftUI lifecycle migration; fixed in 4.7 via PR #116395, no 4.6 backport). `Main.gd` `_notification()` sets/clears the `pending_quit_penalty` flag on PAUSED/RESUMED — on 4.6 those never fired on iOS, so the penalty never applied. Do NOT downgrade below 4.7 or this regresses.
- IAP uses OpenIAP (StoreKit 2) — the `IAPManager` autoload drives the native `GodotIap` class via `ClassDB`.
- Ads use Unity Ads — the `AdsManager` autoload drives the GDScript `UnityAds` autoload, which wraps the native `GodotUnityAds` iOS plugin singleton (`Engine.get_singleton("GodotUnityAds")`). The iOS plugin lives in `ios/plugins/unity-ads/` (an Objective-C++ bridge built by `build.sh`, run on CI only since it needs macOS/Xcode). The Android original used the `addons/unityads/` plugin (Android-only, not present here).
- Product IDs use reverse-domain notation: `com.japastycoon.instant_coins_1/2/3`.

## Unity Ads Notes (iOS)

- The native `GodotUnityAds` singleton and `UnityAds.xcframework` are **only present after `ios/plugins/unity-ads/build.sh` runs** (CI builds them before export). Locally, `godot --headless --import` logs "Invalid plugin config file unity-ads/unity-ads.gdip" — this is expected because the bridge/framework are not built on Linux.
- The `AdsManager` flow logic is pure GDScript driving the `UnityAds` autoload signals — it works the same on desktop/tests (where the native plugin is absent and calls are no-ops).
- Game ID / placement are configured under Project Settings → `unity_ads/` (`ios/game_id`, `ios/placements/rewarded`). Default rewarded placement is `Rewarded_iOS`.

## Build & Deploy

- GitHub Actions CI/CD pipeline runs on `macos-latest` runners (free for public repos).
- Fastlane handles code-signing (cert+sigh) and TestFlight upload.
- See `README.md` for full setup instructions.
