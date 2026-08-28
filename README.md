# GramMeter

Weigh it properly.

GramMeter is a personal food log for people who want a bench scale, not a social feed. It records energy and macros from [Open Food Facts](https://world.openfoodfacts.org), keeps every weigh-in on device, and has no account, ads, or remote configuration. It is not medical advice.

Contact: https://grammeter.pro/contact-us

## Architecture

The app is Elm Architecture, one program per spoke.

- Each screen owns a `Model`, a `Msg` enum, a pure `update(msg:model:) -> (Model, Cmd)`, and a `view(model:)`.
- `CalibrationCmd` describes side effects. `WeighRuntime` executes them and feeds results back as `Msg`.
- Nothing mutates outside `update`. There are no shared singletons; the runtime is created at the scene root.

This suits a precision scale: tare, unit conversion and slot rules must be deterministic. A pure update makes those rules testable without a camera or a disk, and the runtime is the only place network and file IO are allowed.

File layout follows Elm program units: `Programs/Scale`, `Programs/Catalog`, `Programs/Targets`, plus Hub, Log, Plan, Onboarding and Wish. `Runtime/` holds the archive, catalog client and `WeighRuntime`.

Navigation is hub and spoke. Today is the hub. Spokes are Weigh, Catalog, Log, Plan, Targets (and Reserved). Every spoke returns to the hub. There is no separate Detail screen — the Weigh spoke is the detail, because entering grams is the point.

Plan horizon: **14 days** ahead.

## Unique feature

**Precision weighing.** The Weigh spoke is tare-aware: enter vessel mass, then gross mass, and the readout shows net grams. Units convert between grams, ounces and millilitres (ml uses density). Each specimen can store slice / cup / tablespoon presets. The feature is on the hub, persisted in the binary archive, and unit tested.

Live `AVCaptureMetadataOutput` feeds a decoded code straight onto that same readout. On the Simulator the session degrades to sample chips plus manual entry.

## How this app differs

- Metrology lexicon (`ScaleModel`, `TareMsg` path via `ScaleMsg`, `CalibrationCmd`, `WeighRuntime`, `ReadoutView`).
- SwiftUI + bundled Metal shaders (`.colorEffect`, `.distortionEffect`, `.layerEffect`) for readout glow, needle blur and background grain.
- Hub and spoke, no sibling navigation, no separate Detail.
- Custom binary archive (not JSON / plist / Core Data). Day key is `DateComponents` year / month / day.
- Search uses `GET /api/v2/search` with a fields list and `page_size=20`.
- Slots: Weigh-In One, Weigh-In Two, Weigh-In Three, Tare. Tare is eaten-only and remaps to Weigh-In Three when a future day is chosen.
- Zero packages. Pure stdlib + Metal.
- DIN Alternate Bold for readouts; system for body.

## Design

Precision metrology. Light bench, cyan accent.

| Token | Hex |
| --- | --- |
| background | `#F0F4F8` |
| surface | `#FFFFFF` |
| ink | `#37474F` |
| accent | `#00ACC1` |
| muted | `#90A4AE` |

Hard edges. Base spacing 8 pt. Minimum tap 44 pt.

## Art style and prompts

Style: liquid chrome metallic render, polished mercury surface, cyan environment reflection, precision instrument, studio softbox lighting.

Exact prompt used for every asset (subject appended after the base clause):

- `gmt_AppIcon` — the app's single emblem, centred, filling the canvas edge to edge
- `gmt_Splash` — a vertical hero composition with a calm, uncluttered centre band
- `gmt_Onboarding1` — a person or object representing discovering what is in packaged food
- `gmt_Onboarding2` — a scanning or measuring motif showing a product being identified
- `gmt_Onboarding3` — a goal or target motif showing daily progress being met
- `gmt_EmptyLog` — an empty vessel, surface or container waiting to be filled
- `gmt_EmptySearch` — a search motif that has come back with nothing found
- `gmt_EmptyPlan` — an empty schedule, grid or horizon with nothing scheduled
- `gmt_EmptyWish` — an empty basket, list or shelf
- `gmt_SlotWeighInOne` — a morning motif appropriate to the theme
- `gmt_SlotWeighInTwo` — a midday motif appropriate to the theme
- `gmt_SlotWeighInThree` — an evening motif appropriate to the theme
- `gmt_SlotTare` — a small extra or in-between motif appropriate to the theme
- `gmt_MacroProtein` — a symbol standing for protein, rendered as a single clear emblem
- `gmt_MacroCarbs` — a symbol standing for carbohydrate, rendered as a single clear emblem
- `gmt_MacroFat` — a symbol standing for dietary fat, rendered as a single clear emblem
- `gmt_ProductPlaceholder` — a generic packaged grocery item with no readable branding
- `gmt_CardBackdrop` — an abstract backdrop suitable for sitting behind a product card
- `gmt_Texture` — a seamless repeating surface pattern
- `gmt_ControlFace` — the face of a single physical control such as a dial, key or slider handle
- `gmt_ScanOverlay` — a framing reticle or targeting bracket, open in the middle
- `gmt_TwistHero` — an emblem representing this app's signature feature
- `gmt_SuccessMark` — a confirmation mark or celebratory emblem
- `gmt_HeaderDecor` — a wide decorative band or ornament

## Build

```bash
cd App15_GramMeter
xcodegen generate
xcodebuild -scheme GramMeter -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build
xcodebuild -scheme GramMeter -destination 'platform=iOS Simulator,name=iPhone 16' CODE_SIGNING_ALLOWED=NO test
```

Requires Xcode with the iOS 17 SDK and [XcodeGen](https://github.com/yonaskolb/XcodeGen). No Swift packages.
