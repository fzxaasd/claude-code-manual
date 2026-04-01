# 7.9 Voice Mode

> Claude Code 的语音交互功能

## 概述

Voice Mode 允许用户通过语音与 Claude Code 进行交互，支持语音输入和语音反馈。源码位于 `src/voice/` 目录。

```
┌────────────────────────────────────────────────────────────┐
│                   Voice Mode 架构                           │
├────────────────────────────────────────────────────────────┤
│                                                            │
│  用户语音                                                   │
│     │                                                      │
│     ├── 语音识别 ──────> 文本转换                          │
│     │                                                      │
│     └── 文本响应 ──────> 语音合成                          │
│                              │                             │
│                              ↓                             │
│                         语音输出                           │
│                                                            │
└────────────────────────────────────────────────────────────┘
```

---

## 核心功能

### 启用控制

基于 `src/voice/voiceModeEnabled.ts`：

```typescript
function isVoiceModeEnabled(): boolean {
  // 需要满足以下条件：
  // 1. 环境变量 CLAUDE_CODE_VOICE_MODE=true
  // 2. 或 CLI 参数 --voice
  // 3. 或用户设置中启用
}
```

### 配置选项

```typescript
interface VoiceConfig {
  enabled: boolean
  inputLanguage: string        // 输入语言 (如 "en-US", "zh-CN")
  outputVoice?: string          // 输出语音名称
  continuousMode: boolean       // 连续监听模式
  wakeWord?: string             // 唤醒词
  silenceTimeout: number        // 静默超时（毫秒）
}
```

---

## 语音识别

### 输入配置

```typescript
interface SpeechRecognitionConfig {
  interimResults: boolean       // 显示临时结果
  maxAlternatives: number       // 最大替代结果数
  language: string             // 识别语言
}
```

### 语音输入处理

```
1. 麦克风捕获音频
    ↓
2. 实时语音识别（Web Speech API）
    ↓
3. 生成文本输入
    ↓
4. 发送到 Claude Code 处理
    ↓
5. 清理命令（如需要）
```

---

## 语音合成

### TTS 配置

```typescript
interface TextToSpeechConfig {
  voice: string                 // 语音名称
  rate: number                  // 语速 (0.1 - 10)
  pitch: number                 // 音调 (0 - 2)
  volume: number                // 音量 (0 - 1)
}
```

### 可用语音

```javascript
// 列出可用语音
speechSynthesis.getVoices().forEach(voice => {
  console.log(`${voice.name} (${voice.lang})`)
})
```

---

## 命令模式

Voice Mode 支持特殊的语音命令：

| 命令 | 功能 |
|------|------|
| `stop` | 停止当前响应 |
| `pause` | 暂停语音输出 |
| `resume` | 恢复语音输出 |
| `skip` | 跳过当前段落 |
| `clear` | 清空对话历史 |

### 命令识别

```typescript
interface VoiceCommand {
  command: string
  confidence: number
  alternatives?: string[]
}
```

---

## 配置示例

### 启用 Voice Mode

```bash
# 命令行
claude --voice

# 环境变量
export CLAUDE_CODE_VOICE_MODE=true

# 配置文件
{
  "voice": {
    "enabled": true,
    "inputLanguage": "en-US",
    "continuousMode": false,
    "silenceTimeout": 2000
  }
}
```

### 完整配置

```json
{
  "voice": {
    "enabled": true,
    "inputLanguage": "zh-CN",
    "outputVoice": "Google 中文",
    "continuousMode": true,
    "silenceTimeout": 1500,
    "wakeWord": "hey claude"
  }
}
```

---

## 使用场景

### 1. 快速提问

```text
用户: "Hey Claude, what files did I modify today?"

Claude: [语音响应] "You modified three files today: src/index.js,
          src/styles.css, and package.json."
```

### 2. 编程辅助

```text
用户: "Create a new React component called UserProfile"

Claude: [创建组件并语音确认] "I've created the UserProfile component
        in src/components/UserProfile.tsx"
```

### 3. 代码审查

```text
用户: "Review the changes in the last commit"

Claude: [语音播报审查结果] "The changes look good overall. I noticed
        a potential issue in line 42..."
```

---

## 与其他模式集成

### Team Mode 集成

Voice Mode 可以与 Team Mode 配合使用：

```typescript
// 团队语音交互
interface TeamVoiceConfig {
  leaderVoice: boolean
  teammateAnnouncements: boolean
}
```

### Plan Mode 集成

语音输入在 Plan Mode 中特别有用：

```
用户（语音）: "Help me refactor the authentication module"
Claude: 进入 Plan Mode，分析代码
Claude（语音）: "I found three areas for improvement..."
```

---

## 限制与注意事项

### 当前限制

1. **语音识别准确度**：依赖浏览器 Web Speech API
2. **网络依赖**：部分语音服务需要网络连接
3. **延迟**：语音识别和合成有处理延迟
4. **命令歧义**：自然语言命令可能识别不准确

### 建议

1. 使用清晰的命令语调
2. 在安静环境中使用
3. 对于复杂任务仍建议使用文本输入
4. 注意隐私敏感场合

---

## 故障排除

### 语音识别不工作

```bash
# 1. 检查麦克风权限
# macOS: 系统偏好设置 > 隐私与安全性 > 麦克风
# Linux: 检查 PulseAudio/ALSA 配置

# 2. 测试麦克风
arecord -d 5 test.wav

# 3. 检查浏览器支持
# 需要 Chrome/Edge/Safari（不支持 Firefox）
```

### 语音输出不工作

```bash
# 1. 检查音频服务
pulseaudio --check

# 2. 测试音频输出
speaker-test -t sine -f 440

# 3. 检查浏览器音频设置
```

### 识别延迟高

```javascript
// 优化：使用更轻量的识别设置
const recognition = new webkitSpeechRecognition()
recognition.interimResults = true    // 启用临时结果
recognition.maxAlternatives = 1      // 减少替代结果
```

---

## API 参考

### 核心接口

```typescript
// 初始化语音服务
async function initVoiceService(config: VoiceConfig): Promise<VoiceService>

// 开始语音输入
async function startVoiceInput(): Promise<void>

// 停止语音输入
async function stopVoiceInput(): Promise<void>

// 开始语音输出
async function speak(text: string, config?: TTSConfig): Promise<void>

// 停止语音输出
async function stopSpeaking(): Promise<void>
```

### 事件接口

```typescript
interface VoiceEvents {
  onSpeechStart: () => void
  onSpeechEnd: (transcript: string) => void
  onInterimResult: (text: string) => void
  onSpeakingStart: () => void
  onSpeakingEnd: () => void
  onError: (error: VoiceError) => void
}
```

---

## 测试验证

```bash
# 检查 Voice Mode 状态
claude voice status

# 启动语音测试
claude voice test --input

# 测试语音输出
claude voice test --output "Hello, this is a test"

# 检查可用语音
claude voice voices
```

---

## 安全与隐私

### 数据处理

- 语音数据在本地处理（Web Speech API）
- 识别文本通过标准 API 发送到 Claude
- 不存储原始语音数据

### 隐私建议

1. 在可信网络环境中使用
2. 敏感信息建议使用文本输入
3. 定期检查系统隐私设置
