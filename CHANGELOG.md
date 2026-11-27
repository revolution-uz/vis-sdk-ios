# Changelog

All notable changes to the Vis iOS SDK. This project follows [Semantic Versioning](https://semver.org).

## [1.0.4] — 2026-11-27

- Improved session cancellation. No API changes.

## [1.0.3] — 2026-11-20

- The positioning check uses the circle actually drawn on the screen. Before, it used a region sized for a 9:16 screen; on taller iPhones the preview shows only the middle of the camera frame, so recording could start with the face well off-centre in the clip. Recording now starts only when the face is inside the drawn circle, so the face is centred in the clip.
- Fewer "frame gap exceeds 250 ms" failures: the video writer starts while the user is positioning instead of on the first recorded frame, and the camera keeps at least 15 frames per second in dim light. A clip that still has a frame gap is recorded again (shown as "Find better lighting") instead of ending the verification.
- Smaller selfie clips on recent iPhones: the recorder drives the H.264 encoder (VideoToolbox) itself with a 2 Mbit/s average and a hard 2.5 Mbit/s cap per second. Before, the encoder treated the bit rate as a soft target and recent iPhones (e.g. 17 Pro Max) produced ~16 MB clips; a 9–11 s clip now stays under ~3.5 MB.

## [1.0.2] — 2026-11-19

- No changes on iOS; version aligned with the Android SDK 1.0.2.

## [1.0.1] — 2026-11-18

- Documentation wording.

## [1.0.0] — 2026-11-18

First public release.

- Complete verification flow behind one call: consent, device bind, server challenge, capture and upload, status polling, delivered to the host app as a single typed `VerifyResult`.
- Document capture (passport or ID card) with on-device quality gates (sharpness, glare, framing, steadiness) and an MRZ pre-check using ICAO 9303 check digits. EXIF and other metadata are stripped before upload.
- Liveness selfie clip that follows the server's action timeline, including the colour flash, with live guidance (face position, head-turn gauge, retry cues) and an intro and help sheet.
- Support for a session whose document photos the partner's backend sends; the SDK records only the selfie. Optional entry of the document number and birth date, which are compared with the document, and an in-SDK passport / ID card choice.
- Device evidence: App Attest with a per-attempt Secure Enclave key; devices without an enclave fail closed. Optional device integrity signals and a motion-sensor trace.
- DPoP-bound transport with SPKI certificate pinning (`sha256/<base64>`), an ephemeral URLSession and bounded retries.
- Typed results: `VerifyResult` (`approved`, `rejected(reason:)`, `review`, `timeout`, `cancelled`, `failed(VisError)`), rejection categories, and parsed capture-rejection details. No numeric scores are exposed.
- Analytics events via `Vis.eventHandler`; `Vis.sdkVersion`.
- Localized in Uzbek, Russian and English; themeable through `VisTheme`.
- Privacy manifest (`PrivacyInfo.xcprivacy`) bundled with the SDK.
- Distribution through Swift Package Manager and CocoaPods.
- `VerifyRequest` redacts its credentials from `print`, `dump` and debugger output.
- `VisConfig.debugClipExportDirectory` is available only through `@_spi(VisDebug)` and is meant for debug builds.
