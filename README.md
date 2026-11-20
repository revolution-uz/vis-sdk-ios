# Vis iOS SDK

The SDK ships as a compiled, checksum-verified `VisSDK.xcframework` attached to each [release](https://github.com/revolution-uz/vis-sdk-ios/releases).

Native iOS SDK for the Vis identity-verification platform (vis.uz). It runs the whole KYC capture flow inside your app: consent, document scan, liveness selfie. It then returns one typed result. Your backend starts each attempt and receives the verdict by webhook; the SDK never sees your API credentials.

There is a matching [Android SDK](https://github.com/revolution-uz/vis-sdk-android) with the same flow and result types.

## Requirements

- iOS 15 or later
- Xcode 16.4 or later
- A real device for production use (App Attest and the camera are not available on most simulators)
- A Vis partner account with your app's bundle ID and Apple Team ID registered with vis.uz

## Installation

### Swift Package Manager

In `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/revolution-uz/vis-sdk-ios", from: "1.0.3")
],
targets: [
    .target(name: "YourApp", dependencies: [
        .product(name: "VisSDK", package: "vis-sdk-ios")
    ])
]
```

In Xcode: **File > Add Package Dependencies…**, enter `https://github.com/revolution-uz/vis-sdk-ios`, choose "Up to Next Major Version" from `1.0.3`, and add the `VisSDK` library to your app target.

### CocoaPods

```ruby
pod 'VisSDK', '~> 1.0'
```

## Host app setup

1. **Camera.** Add `NSCameraUsageDescription` to your Info.plist with a user-facing reason. The SDK opens the camera for document and selfie capture.
2. **App Attest.** In Signing & Capabilities add **App Attest**. The entitlement must be set for production:
   ```xml
   <key>com.apple.developer.devicecheck.appattest-environment</key>
   <string>production</string>
   ```
   (`development` works for debug builds signed with a development profile.)
3. **Registration.** Give vis.uz your bundle ID and Team ID. Attempts from other apps are refused.
4. **Consent.** By default the flow opens straight on the camera, so your app must obtain the user's biometric consent before launching it. Set `showsConsentScreen: true` to let the SDK show its own consent screen first.

## Backend handoff

Your **backend** starts every attempt with `POST /api/sdk/v1/session/start`, authenticating with your OAuth client credentials (server to server). Credentials never go into the app. The response is a one-shot, short-lived handoff that your backend passes to the app:

| Field | Meaning |
|---|---|
| `attempt_id` | The attempt's identifier. |
| `bootstrap_secret` | One-time secret, consumed when the SDK binds the device. |
| `bootstrap_expires_at` | ISO-8601 time after which the secret is dead. |
| `bind_nonce` | Nonce the SDK includes in its device attestation. |
| `capture_policy_version` | Capture policy the server expects. |
| `app_check`, `documents` | Optional: `"required"` or `"off"`. Pass them through unchanged. |

Launch the flow promptly. If the app dies mid-flow or the window expires, ask your backend for a new attempt; there is no resume. The final verdict is also delivered to your backend by webhook, so decide policy there, not on the device.

## Configuration

Call once at app start:

```swift
import VisSDK

Vis.configure(VisConfig(
    baseURL: URL(string: "https://vis.uz")!,
    pins: ["sha256/<leaf>", "sha256/<backup>"],
    locale: Locale(identifier: "uz"),
    theme: VisTheme(primary: UIColor(red: 0.05, green: 0.33, blue: 0.41, alpha: 1))
))
```

`VisConfig` parameters:

| Parameter | Default | Description |
|---|---|---|
| `baseURL` | required | Platform origin, e.g. `https://vis.uz`. HTTPS only (plain HTTP only for loopback hosts); no path. |
| `pins` | `[]` | SPKI certificate pins in the form `sha256/<base64>` (OkHttp format, so one set serves Android and iOS). Provide the leaf and at least one backup in production. |
| `allowUnpinned` | `false` | Must be `true` to run with empty `pins`. For development servers only. |
| `locale` | `uz` | UI language: `uz`, `ru` or `en`. |
| `theme` | `VisTheme()` | Colours, corner radius and fonts (`VisTypography`, by PostScript name; register the font files yourself). Every token has a default; pass only what you change. |
| `processingTimeout` | `90` | Seconds (10 to 600) to wait for a verdict before returning `.timeout`. The attempt keeps processing and the webhook still arrives. |
| `showsConsentScreen` | `false` | Show the SDK's consent screen first. |

Invalid values stop the app with a precondition failure at configuration time.

## Launching a verification

```swift
let request = VerifyRequest(
    attemptId: handoff.attemptId,
    bootstrapSecret: handoff.bootstrapSecret,
    bootstrapExpiresAt: handoff.bootstrapExpiresAt,
    bindNonce: handoff.bindNonce,
    capturePolicyVersion: handoff.capturePolicyVersion,
    appCheck: handoff.appCheck,    // optional
    documents: handoff.documents   // optional
)

Vis.verification(request).present(from: self) { result in
    // handle the VerifyResult
}
```

The SDK presents a full-screen controller from the view controller you pass. From SwiftUI, present it from the key window's top view controller (or wrap a `UIViewControllerRepresentable` that calls `present(from:)`). The sheet cannot be swiped away mid-run; the user cancels explicitly, which is reported as `.cancelled`.

`VerifyRequest` redacts `bootstrapSecret` and `bindNonce` from `print`, `dump` and debugger output.

## Handling results

`VerifyResult` is the SDK's whole output:

| Result | Meaning | What to do |
|---|---|---|
| `.approved(attemptId:)` | The person was verified. | Proceed (confirm via your webhook). |
| `.rejected(reason:)` | The person failed a check. | Show the category guidance below. |
| `.review` | The attempt went to human review. | Treat as pending, never as pass or fail. |
| `.timeout` | No verdict within `processingTimeout`. | Tell the user to check back; the webhook still arrives. |
| `.cancelled` | The user backed out. | Nothing to report. |
| `.failed(VisError)` | The platform or SDK failed. | Not the user's fault; never present it as a rejection. |

`VerifyResult`, `VisError`, `VisRejectReason` and `VisEvent` may gain cases in a minor release, so give every `switch` over them an `@unknown default` branch.

### Rejection reasons (`VisRejectReason`)

| Reason | Tell the user |
|---|---|
| `.livenessFailed` | The live check did not pass (head turn, video, more than one face). Try again in good light, alone, facing the camera. |
| `.faceMismatch` | The face did not match the face on the document. |
| `.invalidDocument` | The document was not accepted (unreadable, expired, not a valid card, or not the person's card). |
| `.documentDataMismatch` | The typed document number or birth date does not match the document. Type it again. |
| `.unknown` | Generic failure. Categories added later reach older SDKs as `.unknown`, so always handle it. |

### Errors (`VisError`)

| Error | Meaning | Action |
|---|---|---|
| `.sessionNotFound` | Attempt unknown or its credentials already consumed. | Request a new attempt from your backend. |
| `.sessionExpired` | Bootstrap window or attempt lifetime elapsed. | Request a new attempt. |
| `.deviceUnsupported(reason:)` | No camera, OS too old, attestation unsupported, or a retired SDK version. | Another device, or update the app. |
| `.attestationFailed` | The server rejected the device or app attestation. | Apply your own policy. |
| `.captureRejected(hint:)` | Capture could not satisfy the server, or the last selfie try was missed. The attempt is over. | Request a new attempt. |
| `.rateLimited(retryAfterSeconds:)` | Throttled. | Retry after the given seconds. |
| `.networkUnavailable` | Network down after the SDK's own retries. | Retry when online. |
| `.permissionDenied` | Camera permission denied. | Send the user to Settings. |
| `.internalError(detail:)` | Unexpected failure. `detail` is safe to log and has no personal data. | Log and retry. |

`error.captureRejection` parses the `captureRejected` hint into `reason` (`turn_not_completed`, `turn_not_started`, `face_not_ready` or a server code) and, for a selfie miss, `attempt` / `maxAttempts`. Do not parse `hint` yourself.

### Selfie tries

The SDK retakes the selfie locally, up to 3 recordings per challenge, only when the user did not do the head turn and enough time remains. Nothing is uploaded for a missed try, so do not count them. Everything else ends the attempt at once, so one `.rejected` or one selfie `.captureRejected` is one finished attempt.

## Events

Optional analytics, with no images, scores or tokens:

```swift
Vis.eventHandler = { event in track(event) }
```

`VisEvent` cases: `stepStarted(FlowStep)`, `stepCompleted(FlowStep, durationMs:)`, `captureRetaken(FlowStep, gate:)`, `flowCompleted(outcome:)`, `documentTypeChosen(documentType:)`, `livenessIntroShown`, `livenessIntroStartTapped(timeOnScreenMs:)`, `livenessIntroBack`, `livenessHelpOpened(phase:attempt:turnSide:)`, `livenessHelpClosed(method:timeOpenMs:attempt:turnSide:)`. `FlowStep` covers consent, binding, document choice, identity, liveness intro, challenge, document front and back capture, selfie capture, uploading and processing. The handler is invoked on the main thread.

`Vis.sdkVersion` returns the SDK's semantic version string.

## Privacy manifest

The SDK ships `PrivacyInfo.xcprivacy`. It declares no tracking and no required-reason API use, and these collected data types, all linked to the user and used only for app functionality: photos or videos (document photos, selfie video), sensitive info (face biometrics), other data (document data, motion-sensor trace) and other diagnostic data (device integrity signals). Include the SDK in your own App Store privacy answers accordingly.

## Privacy and security

- No media is persisted: photos and the selfie clip live in memory or a temporary file and are discarded after upload.
- EXIF and other metadata are stripped from document photos.
- The selfie screen is hidden while the screen is being recorded or mirrored.
- Logs never contain tokens, secrets, URLs, bodies or media. The few diagnostics the SDK emits use the `.debug` level (subsystem `uz.vis.sdk`) with timings and counts only; they are not persisted and appear only while debug logs are streamed.
- Numeric model scores are never parsed from the API and never reach your app.
- The transport uses an ephemeral `URLSession`: no cache, no cookies, no stored responses.
- Requests are DPoP-bound to a per-attempt Secure Enclave key, attested with App Attest. Devices without a Secure Enclave fail closed.
- SPKI certificate pinning is enforced whenever `pins` is non-empty.
- A platform processing error surfaces as `.failed`, never as a rejection of the user.

## Versioning

The SDK follows [Semantic Versioning](https://semver.org). The version is sent to the platform as `X-SDK-Version`; the platform can refuse retired versions, which surfaces as `.failed(.deviceUnsupported)`. See [CHANGELOG.md](CHANGELOG.md).

## License

See [LICENSE](LICENSE).
