# NetPulse Architecture

## Overview

NetPulse uses a small SwiftUI application layer around a concurrent network probe engine. The application performs work only during an active probe or scheduled wake-up; result rendering and persistence remain local.

## Components

| Component | Responsibility |
|---|---|
| `NetPulseApp.swift` | Menu bar status item and single-instance dashboard scenes |
| `StatusBarController.swift` | Animated monochrome sailfish, menu bar commands and status score |
| `AppModel.swift` | Application state, scheduling, target management and notifications |
| `ProbeEngine.swift` | Concurrent DNS/TCP/TLS/HTTP probes and timing collection |
| `Models.swift` | Targets, samples, runs, health and performance classification |
| `Persistence.swift` | Atomic JSON configuration and history storage |
| `DashboardView.swift` | Primary status, schedule control and result list |
| `ProbeResultViews.swift` | Result rows, metrics and sample details |
| `ManagementViews.swift` | Target configuration, runtime settings and history |
| `NotificationManager.swift` | macOS notification authorization and deduplication |

## Probe Flow

1. `AppModel` snapshots the current configuration.
2. `ProbeEngine` runs enabled targets concurrently.
3. Each target runs the configured number of samples.
4. Samples record DNS, TCP, TLS, first-byte and total duration where available.
5. Results are classified by availability first, then median latency; P95 remains visible as tail-latency evidence.
6. The run is stored locally and passed to the notification manager.

## Scheduling

Scheduling uses one cancellable Swift concurrency task. Updating the interval replaces the existing task, preventing overlapping timers. `runNow()` also rejects a second run while one is active.

## Persistence Compatibility

Configuration and history are JSON files under:

```text
~/Library/Application Support/NetPulse/
```

New `ProbeTarget` fields must provide decoding defaults. This keeps older configuration and history files readable after upgrades.

## Security Boundaries

- Probe URLs are user-controlled and should be treated as untrusted input.
- Runtime configuration and history remain in the user's Application Support directory.
- The repository contains no proxy subscription, messaging integration or account credential.
- Fake-IP addresses in `198.18.0.0/15` are display-only routing evidence and are not public client addresses.

## Application Identity

- Bundle ID: `com.ftpai.futeng.NetPulse`
- Deployment target: macOS 13
- Release architectures: Apple Silicon (`arm64`) and Intel (`x86_64`)
- Current public releases: ad-hoc signed and not notarized
