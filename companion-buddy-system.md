# Companion/Buddy 系统

> 基于源码 `src/buddy/` 完整分析

---

## 概述

Companion（Buddy）是一个桌面伴侣系统，通过 ASCII 精灵和语音气泡与用户互动。它不是 Agent，而是一个独立的 UI 组件系统。

**注意**: `/buddy pet` 命令**不存在**。宠物动画由 AppState 中的 `companionPetAt` 时间戳触发。

---

## 系统组件

| 文件 | 组件 | 说明 |
|------|------|------|
| `CompanionSprite.tsx` | React 组件 | ASCII 精灵 + 语音气泡渲染（含 `CompanionFloatingBubble`） |
| `companion.ts` | 生成逻辑 | Mulberry32 PRNG 生成伴侣 |
| `types.ts` | 类型定义 | 物种、稀有度、属性定义 |
| `sprites.ts` | ASCII 艺术 | 各物种 ASCII 精灵 |
| `prompt.ts` | 提示生成 | Companion 互动提示 |
| `useBuddyNotification.tsx` | 通知钩子 | 日期门控和通知逻辑 |

---

## 物种系统

共 **18 种** ASCII 精灵：

| 物种 | 英文名 |
|------|--------|
| 鸭 | duck |
| 鹅 | goose |
| 史莱姆 | blob |
| 猫 | cat |
| 龙 | dragon |
| 章鱼 | octopus |
| 猫头鹰 | owl |
| 企鹅 | penguin |
| 乌龟 | turtle |
| 蜗牛 | snail |
| 幽灵 | ghost |
| 蝾螈 | axolotl |
| 水豚 | capybara |
| 仙人掌 | cactus |
| 机器人 | robot |
| 兔子 | rabbit |
| 蘑菇 | mushroom |
| 大块头 | chonk |

### 眼睛类型

```typescript
const EYES = ['·', '✦', '×', '◉', '@', '°']
```

### 帽子类型

```typescript
const HATS = ['none', 'crown', 'tophat', 'propeller', 'halo', 'wizard', 'beanie', 'tinyduck']
```

---

## 稀有度系统

### 概率权重

| 稀有度 | 概率 | 星星 |
|--------|------|------|
| common | 60% | ★ |
| uncommon | 25% | ★★ |
| rare | 10% | ★★★ |
| epic | 4% | ★★★★ |
| legendary | 1% | ★★★★★ |

### 属性下限

| 稀有度 | 属性下限 |
|--------|----------|
| common | 5 |
| uncommon | 15 |
| rare | 25 |
| epic | 35 |
| legendary | 50 |

### 闪光（Shiny）

- 闪光概率：**1%**
- 闪光伴侣拥有特殊颜色

### 帽子分配

- common: 只能获得 `none`
- uncommon 及以上: 随机分配帽子

---

## 伴侣属性

### 五项属性

| 属性 | 说明 |
|------|------|
| DEBUGGING | 调试能力 |
| PATIENCE | 耐心程度 |
| CHAOS | 混乱程度 |
| WISDOM | 智慧程度 |
| SNARK | 吐槽程度 |

### 属性分配

每种属性会随机分配：
- 一个峰值属性（最高）
- 一个低谷属性（最低）
- 其他三项随机

---

## 生成机制

### Mulberry32 PRNG

使用 Mulberry32 伪随机数生成器，确保确定性：

```typescript
function mulberry32(seed: number): () => number
```

### 哈希生成

```typescript
function hashString(s: string): number
```

使用 `userId` 作为种子，确保每个用户生成相同的伴侣。

### roll() 函数

```typescript
export function roll(userId: string): Roll
```

其中 `Roll` 类型定义为：

```typescript
type Roll = {
  bones: CompanionBones
  inspirationSeed: number
}
```

流程：
1. 使用 `hashString(userId)` 生成种子
2. 通过 PRNG 确定稀有度
3. 分配物种、眼睛、帽子
4. 掷骰子决定是否闪光
5. 分配五项属性

---

## CompanionSoul

伴侣的灵魂部分由模型生成（非确定性）：

```typescript
type CompanionSoul = {
  name: string        // 伴侣名字
  personality: string // 性格描述
}
```

伴侣名字和性格在**孵化后**存储到配置中，不会再次更改。

---

## Companion 配置

### 配置存储

```typescript
// globalConfig.companion
type StoredCompanion = {
  name: string
  personality: string
  hatchedAt: number
}
```

### 伴侣静音

```typescript
// config.ts
companionMuted: boolean
```

设置 `companionMuted: true` 可禁用伴侣。

---

## CompanionObserver

伴侣反应生成系统：

```typescript
fireCompanionObserver(messages: Message[], onReaction: (reaction: string) => void): Promise<void>
```

使用 LLM 生成伴侣对用户输入的反应。该函数在 `REPL.tsx` 中调用，第一个参数为当前消息数组，第二个参数为回调函数用于更新 `AppState.companionReaction`。

---

## 日期门控

### Buddy 窗口期

```typescript
// useBuddyNotification.tsx
isBuddyTeaserWindow()  // 预告窗口期
isBuddyLive()          // 正式上线窗口期
```

Buddy 系统有日期门控，不同时期有不同的可用性。

---

## UI 显示

### 最小列数

```typescript
MIN_COLS_FOR_FULL_SPRITE = 100
```

终端宽度小于 100 列时，显示简化版本。

### 伴侣保留列

```typescript
companionReservedColumns(): number
```

为伴侣精灵保留 UI 空间。

---

## Companion 气泡

### 气泡内容

```typescript
companionReaction: string  // AppState 字段
```

伴侣的语音气泡内容存储在 AppState 中。

### 宠物动画

```typescript
companionPetAt: number  // AppState 时间戳
```

当写入此字段时，触发宠物动画（爱心漂浮效果）：
- 5 帧动画
- 持续 2.5 秒

---

## 相关文件

### CompanionSprite 组件

```typescript
export function CompanionSprite(props: {
  companion: Companion
  isShiny: boolean
})
```

渲染 ASCII 精灵和语音气泡。

### CompanionFloatingBubble 组件

全屏模式下的浮动气泡组件。

---

## AppState 相关字段

| 字段 | 说明 |
|------|------|
| `companion` | 已孵化的伴侣配置 |
| `companionMuted` | 是否静音 |
| `companionReaction` | 气泡内容 |
| `companionPetAt` | 宠物动画时间戳 |

---

## Feature Gate

Buddy 系统通过 `feature('BUDDY')` 控制启用/禁用。
