
# Noble (Node.js Bluetooth LE) for MacOS

![CI](https://github.com/Timeular/noble-mac/actions/workflows/ci.yml/badge.svg)

_The mac bindings in the [`noble`](https://github.com/sandeepmistry/noble) repository use a XPC connection and an undocumented protocol to communicate directly with the bluetooth daemon.
This is error prone, as the protocol needs to be reverse engineered by sniffing the communication between a regular program which uses the official CoreBluetooth API and the 
bluetooth daemon. Since the protocol is not public Apple can change it at anytime (For now every new OSX release changed the protocol)._

This package provides the same functionality as the regular noble mac bindings using the official [CoreBluetooth API](https://developer.apple.com/documentation/corebluetooth).

## System Requirements
 * Node.js 18 or later (N-API)
 * macOS 13 or later (arm64 + x64 prebuilds)

## Prerequisites

### OS X
 * install [Xcode](https://itunes.apple.com/ca/app/xcode/id497799835?mt=12)

## Installation
Prebuilt binaries are produced for macOS (arm64/x64). Install via npm:

```bash
npm install noble-mac
```

If a prebuild is not available for your platform, the install step will fall back to building from source. You need Xcode command line tools installed.

## Usage
Simply require `noble-mac` instead of `noble`:
```javascript
const noble = require('noble-mac');
```
On non-Mac platforms this will use the regular [noble](https://github.com/sandeepmistry/noble/blob/master/README.md) implementation and on MacOS it will use the native binding using the official CoreBluetooth API.

## Note
Be careful to not write to the `Client Characteristic Configuration` descriptor directly to enable notification.
Use `subscribe` instead to enable and listen to notifications.
## Implementation Status
Everything should work that also works with the regular noble mac bindings.
 * Broadcast is not implemented, but it neither was in recent noble mac bindings
