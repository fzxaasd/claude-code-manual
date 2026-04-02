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

**Note**: Focus Mode is hardcoded to `false` in the implementation and not exposed as a user setting.

---

## Technical Implementation

### Audio Capture

| Platform | Implementation |
|------|------|
| macOS | CoreAudio via audio-capture-napi |
| Linux | SoX `rec` or cpal |
| Windows | cpal |

### STT Service

Uses Deepgram Nova 3 model (`deepgram-nova3`) for speech recognition.

**Keyword Enhancement**: Automatically sends programming terms (MCP, symlink, grep, regex, etc.), project names, git branches, and recent filenames to STT as prompts.

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

## Security and Privacy

- Audio data is sent to Anthropic servers via WebSocket
- Raw audio data is not stored
- Transcribed text is processed through standard API
