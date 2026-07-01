# Distribution

## Current Release Model

NetPulse is a native SwiftUI macOS application. The shell scripts only compile, package and install the `.app`; they are not the application runtime.

GitHub Releases contain a Universal DMG:

```text
NetPulse-<version>-universal.dmg
NetPulse-<version>-universal.dmg.sha256
```

The Universal executable contains both `arm64` and `x86_64` slices.
GitHub Actions also creates a signed Artifact Attestation for each DMG. The
attestation binds the DMG digest to the public repository, workflow and commit
that produced it. It supplements the ad-hoc signature; it does not replace
Apple notarization or make Gatekeeper trust the publisher.

The stable application identifier is:

```text
com.ftpai.futeng.NetPulse
```

Users upgrading from early local builds that used `com.local.netpulse` may need to grant notification permission and enable launch-at-login again. Application Support data remains under the same `NetPulse` directory.

## Why macOS Shows a Warning

The project currently has no paid Apple Developer Program certificate. Release builds therefore use an ad-hoc signature:

- It seals the application so macOS can detect changes after signing.
- It does not contain a verified developer identity or Apple Team ID.
- It cannot be notarized by Apple.
- Gatekeeper cannot confirm who published the downloaded application.

An ad-hoc signature is not equivalent to a `Developer ID Application` signature. It is suitable for local builds and transparent open-source distribution, but it does not remove the first-launch warning for downloaded files.

## First Launch

After copying NetPulse to Applications:

1. Control-click NetPulse in Finder.
2. Select **Open**.
3. Confirm **Open** again.

If macOS still blocks it, attempt to open it once, then go to:

```text
System Settings → Privacy & Security → Open Anyway
```

Only download releases from the official repository and compare the DMG checksum:

```bash
shasum -a 256 -c NetPulse-<version>-universal.dmg.sha256
```

Verify the GitHub build provenance with GitHub CLI:

```bash
gh attestation verify NetPulse-<version>-universal.dmg \
  --repo futeng/NetPulse
```

The checksum detects a changed or incomplete download. The attestation proves
that the matching DMG was produced by this repository's GitHub Actions
workflow. Both checks should pass before first launch.

## Build Commands

```bash
# Native architecture
./scripts/build_netpulse.sh

# Apple Silicon
./scripts/build_netpulse.sh arm64

# Intel
./scripts/build_netpulse.sh x86_64

# Apple Silicon + Intel
./scripts/build_netpulse.sh universal

# Universal DMG and SHA-256 file
./scripts/build_release_dmg.sh universal

# Verify checksum, DMG structure, app signature, Bundle ID and architectures
./scripts/verify_release_dmg.sh
```

An Intel Mac running macOS 13 or later can build and run NetPulse directly. Apple Silicon Macs can also cross-compile the Intel slice with the installed macOS SDK.

## GitHub Release

The release workflow runs when a version tag is pushed:

```bash
git tag v1.0.0
git push origin v1.0.0
```

The workflow:

1. Builds both architectures and combines them with `lipo`.
2. Creates the ad-hoc signed Universal DMG and SHA-256 file.
3. Mounts the final DMG and verifies its signature, Bundle ID and architectures.
4. Creates signed GitHub build provenance for the DMG.
5. Publishes the DMG and checksum to GitHub Releases.

The regular CI workflow also builds and verifies a temporary Universal DMG on
every push and pull request. This catches packaging failures before a release
tag is created.

The workflow requires these GitHub token permissions:

```yaml
permissions:
  contents: write
  id-token: write
  attestations: write
```

Artifact Attestations are available for this public repository without a paid
GitHub plan. Verification requires network access to GitHub.

## Future Developer ID Distribution

When a Developer ID certificate becomes available:

1. Sign the app with `Developer ID Application`.
2. Sign the DMG.
3. Submit the DMG with `notarytool`.
4. Staple the notarization ticket.
5. Verify with `spctl` before publishing.

The existing build script accepts a signing identity through:

```bash
CODE_SIGN_IDENTITY="Developer ID Application: Example (TEAMID)" \
./scripts/build_release_dmg.sh universal
```
