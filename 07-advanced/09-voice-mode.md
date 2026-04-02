# 7.9 Voice Mode

> 基于源码 `src/voice/voiceModeEnabled.ts`, `src/commands/voice/`, `src/hooks/useVoice.ts` 深度分析

## 概述

Voice Mode 是 Claude Code 的语音输入功能，支持通过麦克风进行语音转文字输入。**注意：目前没有语音合成 (TTS) 输出功能。**

```
┌────────────────────────────────────────────────────────────┐
│                   Voice Mode 架构                           │
├────────────────────────────────────────────────────────────┤
│                                                            │
│  用户按住快捷键 (默认: 空格键)                              │
│       │                                                   │
│       ▼                                                   │
│  原生音频捕获 (CoreAudio/cpal/SoX)                        │
│       │                                                   │
│       ▼                                                   │
│  WebSocket → Anthropic voice_stream 端点                   │
│       │                                                   │
│       ▼                                                   │
│  Deepgram STT 转文字                                        │
│       │                                                   │
│       ▼                                                   │
│  输入到 Claude Code                                        │
│                                                            │
└────────────────────────────────────────────────────────────┘
```

---

## 启用条件

基于 `src/voice/voiceModeEnabled.ts`：

```typescript
function isVoiceModeEnabled(): boolean {
  return hasVoiceAuth() && isVoiceGrowthBookEnabled()
}

function hasVoiceAuth(): boolean {
  // 检查 Anthropic OAuth tokens 是否存在
  // Voice 需要 OAuth 认证，不支持纯 API Key
}

function isVoiceGrowthBookEnabled(): boolean {
  // feature('VOICE_MODE') 且 GrowthBook: !tengu_amber_quartz_disabled
}
```

**前提条件**：
1. 使用 Claude.ai OAuth 登录（非纯 API Key）
2. GrowthBook feature flag `tengu_amber_quartz_disabled` 为 false
3. `feature('VOICE_MODE')` 编译时常量开启

---

## 激活方式

```bash
/voice
```

切换语音模式开关状态。

---

## 配置

### voiceEnabled 设置

```json
{
  "voiceEnabled": true
}
```

### 语言设置

```json
{
  "language": "zh-CN"
}
```

支持 20 种语言代码：en, es, fr, ja, de, pt, it, ko, hi, id, ru, pl, tr, nl, uk, el, cs, da, sv, no。

**注意**：如果设置的语言不支持，会自动回退到英语（en）并显示提示。

### 预检检查

启用语音模式时，会执行以下检查：

1. **录音可用性检查** (`checkRecordingAvailability`) — 检查麦克风访问权限
2. **语音流可用性检查** (`isVoiceStreamAvailable`) — 检查 OAuth 认证和账户状态
3. **依赖检查** (`checkVoiceDependencies`) — 检查 SoX/cpal/audio-tool 可用性
4. **麦克风权限请求** (`requestMicrophonePermission`) — 触发系统权限对话框

**注意**：`isVoiceStreamAvailable` 本身已包含 OAuth 认证检查，不是独立的第 5 步。

### Focus Mode (焦点模式)

终端获得焦点时自动开始录音，失去焦点时停止录音。支持"多窗口语音跟随"工作流。

**关键行为**：
- 静默 5 秒后自动断开 WebSocket (`FOCUS_SILENCE_TIMEOUT_MS = 5_000`)
- 事件追踪：`focusTriggered`、`silenceTimedOut`、`focusFlushedChars`

**Hold-to-talk 检测细节**：
- 第一次按键即开始录音（无延迟）
- 使用 auto-repeat 检测控制释放计时器
- 释放超时 200ms (`RELEASE_TIMEOUT_MS = 200`)
- 修饰键组合直接激活，无需按键次数检测

### 按键配置

```json
{
  "voice:pushToTalk": "space"
}
```

按住指定按键开始录音，松开停止。

**绑定类型**：
- `space` — 空格键（默认）
- 修饰键组合 — 如 `meta+k`, `ctrl+shift+v`
- 字母键 — 产生输入热键警告（因为热键期间会打印到输入）

---

## 技术实现

### 音频捕获

| 平台 | 实现 |
|------|------|
| macOS | CoreAudio via audio-capture-napi |
| Linux | SoX `rec` 或 cpal |
| Windows | cpal |

### STT 服务

使用 Deepgram Nova 3 模型 (`deepgram-nova3`) 进行语音识别。

**关键字增强**：自动向 STT 发送编程术语（MCP, symlink, grep, regex 等）、项目名称、git 分支、近期文件名作为提示词。

### 状态机

```typescript
type VoiceState = 'idle' | 'recording' | 'processing'

// idle: 未录音
// recording: 正在捕获音频
// processing: 等待转写结果
```

---

## 限制与注意事项

### 当前限制

1. **仅语音输入**：没有语音合成 (TTS) 输出功能
2. **OAuth 必须**：不支持纯 API Key 认证
3. **平台限制**：需要本地麦克风权限

### 故障排除

```bash
# 检查麦克风权限
# macOS: 系统偏好设置 > 隐私与安全性 > 麦克风

# 检查音频依赖
# 确保 SoX (Linux) 或 CoreAudio (macOS) 可用
```

---

## 未文档化的功能

### Silent-drop Replay

当服务端接受音频但返回零转录时（~1% session-sticky CE pod bug），自动在新连接上重放缓冲音频。

### Audio Waveform Visualizer

16 条 RMS 振幅波形可视化 (`AUDIO_LEVEL_BARS = 16`)。

### Early-error Retry

连接错误且无转录时，250ms 后自动重试一次。

### Audio Buffering

WebSocket 连接期间缓冲音频 (~32KB/秒)。

### Focus Mode Transcript Flushing

Focus 模式下每个 final transcript 立即注入（非累积）。

### Remote Session 检测

检测 `CLAUDE_CODE_REMOTE` 环境变量，自动禁用语音。

### Linux 音频实现

- **ALSA cards 检测**: 读取 `/proc/asound/cards`
- **arecord fallback**: Linux 上 SoX 之外的备选方案
- **WSL 特定处理**: WSL1/Win10-WSL2 无音频设备时的错误提示

### Analytics Events

| 事件 | 说明 |
|------|------|
| `tengu_voice_recording_started` | 开始录音 |
| `tengu_voice_recording_completed` | 录音完成 |
| `tengu_voice_silent_drop_replay` | Silent-drop replay 触发 |

---

## 安全与隐私

- 音频数据通过 WebSocket 发送到 Anthropic 服务器
- 不存储原始音频数据
- 转写文本通过标准 API 处理
