# Project Knowledge

## Gotchas

- **Never use `get_name` as a custom method name** — it conflicts with `GDScript.get_name()` (built-in, 0 args). Use `get_japas_name` or similar instead.
- **TextureButton with `ignore_texture_size = false` (default) ignores parent sizing** — when a `TextureButton` is a child of a manually-sized `Control`, setting `offset_right`/`offset_bottom` on the parent does NOT visually resize the texture. The TextureButton overflows to at least the texture's native size. ALWAYS set `ignore_texture_size = true` on any TextureButton that should shrink below its texture size.
- **GDScript parses type names at parse-time**, even inside unreachable blocks. All native iOS plugin types must use `ClassDB.instantiate()` / `ClassDB.class_exists()` — never reference them directly (e.g. never `var x: MobileAds` / `RewardedAd.new()`). See `AdsManager.gd` / `IAPManager.gd`.
- **`IAPConfig.get_coin_reward()` keys** are the internal keys (`instant_coins_1/2/3`), NOT the product IDs. `MenuLevelSelect.gd` calls `get_coin_reward(sku)` with a product ID, so `get_coin_reward` maps product ID → reward internally (unlike the original Android version which keyed by SKU).

## Git Policy

- **No git actions** — I must never commit, push, branch, merge, or run any git command. The user handles all git operations manually.

## Golden Rule

- **Only implement exactly what the user asks. Never add extra logic, features, or behaviors they didn't request. If you have an idea, ask me first. No overthinking, no "helpful" additions without my confirmation.**

## iOS-Specific Notes

- This project targets iOS using Godot 4.6 with the Mobile renderer.
- IAP uses OpenIAP (StoreKit 2) — the `IAPManager` autoload drives the native `GodotIap` class via `ClassDB`.
- Ads use the poing-godot-admob iOS plugin — the `MobileAds` singleton via `ClassDB`.
- The `UnityAds` autoload was removed (was Android-only).
- Product IDs use reverse-domain notation: `com.japastycoon.instant_coins_1/2/3`.

## AdMob Plugin Notes

**ALWAYS pass `null` (or nothing) to `RewardedAdLoader.load()`** — the test ad unit ID
for iOS is `ca-app-pub-3940256099942544/1712485313`. Replace with your own ad unit ID
before production release.

## Build & Deploy

- GitHub Actions CI/CD pipeline runs on `macos-latest` runners (free for public repos).
- Fastlane handles code-signing (cert+sigh) and TestFlight upload.
- See `README.md` for full setup instructions.
