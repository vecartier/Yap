# Technology Stack

**Analysis Date:** 2026-03-21

## Languages

**Primary:**
- Swift 6.2 - Entire macOS application codebase

## Runtime

**Environment:**
- macOS 15+ (Sequoia or later)
- Apple Silicon (native support)

**Build System:**
- Swift Package Manager (SPM)
- Xcode 26+

**Package Manager:**
- Swift Package Manager (SPM)
- Lockfile: `Package.resolved` present

## Frameworks

**Core Audio & Transcription:**
- [FluidAudio](https://github.com/FluidInference/FluidAudio.git) 0.12.1 - Audio capture and processing
- [WhisperKit](https://github.com/argmaxinc/WhisperKit.git) 0.17.0 - Local speech-to-text using CoreML
- Swift standard library (Foundation, AVFoundation, CoreAudio)

**LLM & Inference:**
- Custom `OpenRouterClient` - OpenAI-compatible streaming client for cloud LLM APIs
- `SuggestionEngine` - in-process LLM orchestration

**UI & App:**
- AppKit (native macOS UI framework, not SwiftUI)
- Core Observation framework (`@Observable` macros)

**App Management:**
- [Sparkle](https://github.com/sparkle-project/Sparkle) 2.9.0 - Automatic app updates
- [LaunchAtLogin-Modern](https://github.com/sindresorhus/LaunchAtLogin-Modern) 1.1.0 - Launch app at system startup

**CLI:**
- [swift-argument-parser](https://github.com/apple/swift-argument-parser.git) 1.7.0 - Command-line argument parsing

**Transformers & NLP:**
- [swift-transformers](https://github.com/huggingface/swift-transformers) 1.1.9 - Hugging Face model inference
- [swift-jinja](https://github.com/huggingface/swift-jinja.git) 2.3.2 - Template rendering for prompts
- [yyjson](https://github.com/ibireme/yyjson.git) 0.12.0 - Fast JSON parsing

**Cryptography & Security:**
- [swift-crypto](https://github.com/apple/swift-crypto.git) 4.2.0 - Cryptographic functions
- [swift-asn1](https://github.com/apple/swift-asn1.git) 1.5.1 - ASN.1 parsing

**Collections & Utilities:**
- [swift-collections](https://github.com/apple/swift-collections.git) 1.3.0 - Advanced collection types

## Key Dependencies

**Critical:**
- WhisperKit 0.17.0 - Enables 100% offline speech transcription without cloud API calls
- FluidAudio 0.12.1 - Provides system audio capture (internal audio from calls)

**Infrastructure:**
- Sparkle 2.9.0 - Self-updating app distribution (desktop software practice)
- LaunchAtLogin-Modern 1.1.0 - Background service capability

## Configuration

**Environment:**
- Configuration handled via `AppSettings` class (`/Users/vcartier/Desktop/OpenOats-fork/OpenOats/Sources/OpenOats/Settings/AppSettings.swift`)
- Support for environment-specific API keys (OpenRouter, Voyage AI, etc.)
- User preferences stored locally in Application Support directory

**Build:**
- `Package.swift` at `/Users/vcartier/Desktop/OpenOats-fork/OpenOats/Package.swift` defines 2 products:
  - `OpenOatsKit` - Core library target
  - `OpenOats` - Executable target
- Test target: `OpenOatsTests`

**Entitlements:**
- `com.apple.security.device.audio-input` - Microphone access (required for transcription)
- Located at `OpenOats/Sources/OpenOats/OpenOats.entitlements`

## Platform Requirements

**Development:**
- Apple Silicon Mac (native ARM64)
- macOS 15+ (Sequoia or later)
- Xcode 26 with Swift 6.2 toolchain
- Command-line: `./scripts/build_swift_app.sh`

**Production:**
- Apple Silicon Mac only (no Intel support)
- macOS 15+
- ~600 MB disk space for first-run WhisperKit model download

**Distribution:**
- Homebrew Cask: `brew tap yazinsai/openoats && brew install --cask yazinsai/openoats/openoats`
- DMG distribution with drag-to-Applications installation
- Auto-updates via Sparkle framework

## Storage & Persistence

**Local Storage:**
- Application Support directory: `~/Library/Application Support/OpenOats/sessions/`
- Session files stored as JSONL with metadata sidecars
- Knowledge base indexing cached locally
- Downloaded models in `~/Library/Documents/huggingface/models/`

---

*Stack analysis: 2026-03-21*
