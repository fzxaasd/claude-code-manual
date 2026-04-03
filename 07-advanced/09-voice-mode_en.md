# 7.9 Voice Mode

> Deep analysis based on source code `src/voice/voiceModeEnabled.ts`, `src/commands/voice/`, `src/hooks/useVoice.ts`

## Overview

Voice Mode is the speech input feature of Claude Code, supporting voice-to-text input via microphone. **Note: There is currently no text-to-speech (TTS) output feature.**

```
┌────────────────────────────────────────────────────────────┐
│                   Voice Mode Architecture                   │
├────────────────────────────────────────────────────────────┤
│                                                            │
│  User holds hotkey (default: space)                        │
│       │                                                    │
│       ▼                                                    │
│  Native audio capture (CoreAudio/cpal/SoX)                 │
│       │                                                    │
│       ▼                                                    │
│  WebSocket → Anthropic voice_stream endpoint               │
│       │                                                    │
│       ▼                                                    │
│  Deepgram STT to text                                      │
│       │                                                    │
│       ▼                                                    │
│  Input to Claude Code                                      │
│                                                            │
└────────────────────────────────────────────────────────────┘
```

---

## Enable Conditions

Based on `src/voice/voiceModeEnabled.ts`:

```typescript
function isVoiceModeEnabled(): boolean {
  return hasVoiceAuth() && isVoiceGrowthBookEnabled()
}

function hasVoiceAuth(): boolean {
  // Check if Anthropic OAuth tokens exist
  // Voice requires OAuth authentication, API Key alone not supported
}

function isVoiceGrowthBookEnabled(): boolean {
  // feature('VOICE_MODE') && GrowthBook: !tengu_amber_quartz_disabled
}
```

**Prerequisites**:
1. Claude.ai OAuth login (not pure API Key)
2. GrowthBook feature flag `tengu_amber_quartz_disabled` is false
3. `feature('VOICE_MODE')` compile-time constant enabled

---

## Activation

```bash
/voice
```

Toggles voice mode on/off.

---

## Configuration

### voiceEnabled Setting

```json
{
  "voiceEnabled": true
}
```

### Language Setting

```json
{
  "language": "en-US"
}
```

Supports 20 language codes: en, es, fr, ja, de, pt, it, ko, hi, id, ru, pl, tr, nl, uk, el, cs, da, sv, no.

**Note**: If the configured language is unsupported, it silently falls back to English (en) and shows a notification.

### Pre-flight Checks

When enabling voice mode, the following checks are executed:

1. **Recording availability** (`checkRecordingAvailability`) — Check microphone access
2. **Voice stream availability** (`isVoiceStreamAvailable`) — Check OAuth auth and account status
3. **Dependencies check** (`checkVoiceDependencies`) — Check SoX/cpal/audio-tool availability
4. **Microphone permission** (`requestMicrophonePermission`) — Trigger system permission dialog

**Note**: `isVoiceStreamAvailable` itself includes OAuth auth check, not a separate 5th step.

### Focus Mode

Automatically starts recording when terminal gains focus, stops when focus is lost. Supports "multi-window voice-following" workflow.

**Key behaviors**:
- Auto-disconnect WebSocket after 5s silence (`FOCUS_SILENCE_TIMEOUT_MS = 5_000`)
- Event tracking: `focusTriggered`, `silenceTimedOut`, `focusFlushedChars`

**Hold-to-talk detection details**:
- **Bare-char binding** (e.g., space): Requires 5 rapid key presses to activate (`HOLD_THRESHOLD = 5`)
  - Keys within 120ms count as rapid sequence (`RAPID_KEY_GAP_MS = 120`)
  - Shows "keep holding..." after 2nd press (`WARMUP_THRESHOLD = 2`)
- **Modifier combos** (e.g., `meta+k`): Activates on first press, 2s timeout (`MODIFIER_FIRST_PRESS_FALLBACK_MS = 2000`)
- Release timeout 200ms (`RELEASE_TIMEOUT_MS = 200`)
- Supports full-width space (CJK IME) recognized as space

### Key Configuration

```json
{
  "voice:pushToTalk": "space"
}
```

Hold the specified key to start recording, release to stop.

**Binding types**:
- `space` — Space key (default)
- Modifier combos — e.g., `meta+k`, `ctrl+shift+v`
- Letter keys — produce a warning because they print into input during warmup

---

## Technical Implementation

### Audio Capture

| Platform | Implementation |
|------|------|
| macOS | CoreAudio via audio-capture-napi |
| Linux | SoX `rec` or cpal |
| Windows | cpal |

### STT Service

Uses Deepgram for speech recognition.

**Nova 3 Model**: Controlled by GrowthBook feature `tengu_cobalt_frost`, not enabled by default. Also sets `use_conversation_engine=true` parameter.

**Keyword Enhancement**: Automatically sends programming terms (MCP, symlink, grep, regex, etc.), project names, git branches, and recent filenames to STT as prompts.

### STT WebSocket Parameters

WebSocket request parameters sent:

```typescript
{
  encoding: 'linear16',
  sample_rate: '16000',
  channels: '1',
  endpointing_ms: '300',
  utterance_end_ms: '1000',
  language: options?.language ?? 'en'
}
```

### Environment Variables

| Variable | Description |
|----------|-------------|
| `VOICE_STREAM_BASE_URL` | Override voice_stream WebSocket base URL (for development/testing) |

### State Machine

```typescript
type VoiceState = 'idle' | 'recording' | 'processing'

// idle: Not recording
// recording: Currently capturing audio
// processing: Waiting for transcription results
```

---

## Limitations and Notes

### Current Limitations

1. **Voice input only**: No text-to-speech (TTS) output feature
2. **OAuth required**: Pure API Key authentication not supported
3. **Platform limitations**: Requires local microphone permissions

### Troubleshooting

```bash
# Check microphone permissions
# macOS: System Preferences > Privacy & Security > Microphone

# Check audio dependencies
# Ensure SoX (Linux) or CoreAudio (macOS) is available
```

---

## Undocumented Features

### Silent-drop Replay

When server accepts audio but returns zero transcription (~1% session-sticky CE pod bug), automatically replays buffered audio on fresh connection.

### Audio Waveform Visualizer

16 RMS amplitude waveform visualization (`AUDIO_LEVEL_BARS = 16`).

### Early-error Retry

On connection error with no transcription, automatically retries once after 250ms.

### Audio Buffering

Buffers audio during WebSocket connection (~32KB/sec).

### Focus Mode Transcript Flushing

In Focus mode, each final transcript is injected immediately (not accumulated).

### Remote Session Detection

Detects `CLAUDE_CODE_REMOTE` environment variable, automatically disables voice.

### Homespace Environment Detection

`isRunningOnHomespace()` function detects if running on Homespace (Ant internal cloud environment), automatically disables voice recording.

### Language Hint Counter

`voiceLangHintShownCount` and `voiceLangHintLastLanguage` track language hint display count, hints shown at most **2 times** (`LANG_HINT_MAX_SHOWS = 2`).

### Linux Audio Implementation

- **ALSA cards detection**: Reads `/proc/asound/cards`
- **arecord fallback**: Alternative to SoX on Linux
- **WSL specific handling**: Error message for WSL1/Win10-WSL2 without audio device

### Analytics Events

| Event | Description |
|-------|-------------|
| `tengu_voice_recording_started` | Recording started |
| `tengu_voice_recording_completed` | Recording completed |
| `tengu_voice_silent_drop_replay` | Silent-drop replay triggered |
| `tengu_voice_stream_early_retry` | Early-error retry triggered |

### Audio Slicing Mechanism

WebSocket sending merges audio into ~1 second frames (`SLICE_TARGET_BYTES = 32_000`), reducing network overhead.

### Early-error Retry

When connection error with no transcription, automatically retries once after 250ms:
- Only retries once (`retryUsedRef`)
- Audio is re-buffered during retry

### Modifier Key Activation

First press of modifier key combination has **2 second** timeout (`MODIFIER_FIRST_PRESS_FALLBACK_MS`).

### WebSocket Protocol Details

- KeepAlive interval: 8000ms
- Finalize timeout: safety=5000ms, noData=1500ms

---

## Security and Privacy

- Audio data is sent to Anthropic servers via WebSocket
- Raw audio data is not stored
- Transcribed text is processed through standard API
