# Phase 2: Cloud TTS Foundation - UI Design Contract

**Phase:** 02-cloud-tts-foundation
**Status:** UI Design Complete
**Date:** 2026-04-10
**Version:** 1.0

---

## Overview

本文档定义 Phase 2 云端 TTS 功能在 Flutter App 中的 UI 设计合约。TTS Tab 作为独立页面，与 ASR Tab 通过底部导航并列存在。

**设计原则：**
- 与 Phase 1 ASR Tab 保持一致的设计语言
- 遵循 Material Design 3 规范
- 明确的交互状态反馈
- 简洁高效的布局

---

## 1. Copywriting Contract（文案规范）

### 1.1 页面标题

| 元素 | 文案 | 说明 |
|------|------|------|
| TTS Tab 标签 | `语音合成` | 底部导航图标下方文字 |
| TTS Tab 图标 | `Icons.music_note` | Material Icons |
| App Bar 标题 | `语音合成` | 页面顶部标题 |

### 1.2 CTA 按钮文案

| 状态 | 播放按钮文案 | 停止按钮文案 |
|------|-------------|-------------|
| 空闲态 | `播放` | `停止`（禁用） |
| 播放中 | `暂停` | `停止` |
| 暂停中 | `继续` | `停止` |
| 加载中 | `播放中...`（禁用） | `停止` |

### 1.3 音色选择器

| 元素 | 文案 |
|------|------|
| Placeholder | `请选择音色` |
| 下拉展开标题 | `选择音色` |

**预设音色列表：**

| ID | 显示名称 | 语言 | 性别 |
|----|---------|------|------|
| `zh_female_1` | 中文女声-温柔 | 中文 | 女 |
| `zh_male_1` | 中文男声-稳重 | 中文 | 男 |
| `en_female_1` | English Female | 英文 | 女 |
| `en_male_1` | English Male | 英文 | 男 |
| `mixed_1` | 中英混合 | 混合 | 中性 |

### 1.4 空状态文案

| 场景 | 文案 | 样式 |
|------|------|------|
| 无文本输入 | `请输入要合成的文本` | 次要颜色，居中显示 |
| 未选择音色 | `请先选择音色` | 次要颜色 |

### 1.5 加载状态文案

| 场景 | 文案 |
|------|------|
| 连接服务器 | `正在连接服务器...` |
| 接收音频中 | `正在合成...` |
| 加载音色列表 | `正在加载音色...` |

### 1.6 错误状态文案

| 错误类型 | 文案 | 处理建议 |
|----------|------|----------|
| 网络断开 | `网络连接已断开` | 显示重连按钮 |
| WebSocket 超时 | `连接超时，请重试` | 显示重试按钮 |
| 服务器错误 (500) | `服务器错误，请稍后重试` | 显示刷新按钮 |
| 文本为空 | `请输入要合成的文本` | 高亮输入框 |
| 音频播放失败 | `音频播放失败` | 显示错误详情 |

### 1.7 进度条文案

| 场景 | 文案格式 | 示例 |
|------|----------|------|
| 播放进度 | `mm:ss / mm:ss` | `00:30 / 01:00` |
| 缓冲进度 | `缓冲中...` | - |
| 未知时长 | `--:-- / --:--` | - |

---

## 2. Visuals（视觉规范）

### 2.1 整体视觉风格

**设计系统：** Material Design 3 (Material You)

- **主题模式：** 浅色模式（与 ASR Tab 一致）
- **圆角半径：** 12dp（卡片、按钮）
- **阴影：** Material 3 elevation 系统
- **图标风格：** Material Symbols Rounded

### 2.2 组件视觉层次

```
┌─────────────────────────────────────────────┐
│  Layer 1: 背景层 (surface)                   │
│  Layer 2: 卡片层 (elevated cards)           │
│  Layer 3: 输入层 (text input)               │
│  Layer 4: 控制层 (buttons, slider)          │
│  Layer 5: 状态层 (loading, error overlays)  │
└─────────────────────────────────────────────┘
```

### 2.3 动画与过渡

| 动画类型 | 参数 | 说明 |
|----------|------|------|
| 按钮点击反馈 | `InkWell` + Ripple | Material 3 标准 |
| 状态切换 | `AnimatedOpacity`, 300ms | 加载/状态文字 |
| 进度条更新 | 实时更新，无动画 | 追求流畅度 |
| Tab 切换 | `TabBarView` 默认动画 | 水平滑动 |
| 播放按钮图标 | `AnimatedSwitcher`, 200ms | 播放↔暂停切换 |
| Snackbar 显示 | 从底部滑入 | 错误提示 |

### 2.4 组件视觉规格

#### 文本输入框

- **类型：** `TextField` + `maxLines: 5`
- **边框：** `OutlineInputBorder` with `borderRadius: 12`
- **提示文字：** `请输入要合成的文本...`
- **最大字符数：** 5000 字符

#### 播放控制按钮

- **播放/暂停按钮：**
  - 尺寸：64x64 dp（主按钮，突出显示）
  - 形状：圆形
  - 图标：`Icons.play_arrow` / `Icons.pause`
  - 背景：`primary` color
  - 前景：`onPrimary` color

- **停止按钮：**
  - 尺寸：48x48 dp
  - 形状：圆形
  - 图标：`Icons.stop`
  - 背景：`surfaceContainerHighest`
  - 前景：`onSurfaceVariant`

#### 进度条

- **类型：** `Slider`（可拖动）
- **高度：** 4dp（静止）/ 6dp（拖动）
- **已播放颜色：** `primary`
- **未播放颜色：** `surfaceContainerHighest`

---

## 3. Color（颜色规范）

### 3.1 主题配色（继承自 ASR Tab）

**主色调：** Material Purple (`seedColor: 0xFF6750A4`)

```dart
ColorScheme.fromSeed(
  seedColor: const Color(0xFF6750A4),
  brightness: Brightness.light,
)
```

### 3.2 TTS 状态颜色

| 状态 | 颜色变量 | 色值 | 用途 |
|------|----------|------|------|
| 空闲态 | `surfaceContainerHighest` | `#E7E0EC` | 进度条未播放部分 |
| 播放中 | `primary` | `#6750A4` | 进度条已播放、播放按钮背景 |
| 暂停中 | `tertiary` | `#7D5260` | 暂停状态指示 |
| 缓冲中 | `secondary` | `#625B71` | 加载状态 |

### 3.3 状态指示器颜色

| 状态 | 颜色 | 说明 |
|------|------|------|
| `disconnected` | `Colors.grey` | 灰色圆点 |
| `connecting` | `Colors.orange` | 橙色圆点（闪烁） |
| `connected` | `Colors.green` | 绿色圆点 |
| `error` | `Colors.red` | 红色圆点 |

### 3.4 错误与警告颜色

| 类型 | 颜色 | 用途 |
|------|------|------|
| 错误 | `Colors.red.shade700` | 错误状态高亮 |
| 警告 | `Colors.orange.shade700` | 警告提示 |
| 成功 | `Colors.green.shade700` | 成功提示 |

---

## 4. Typography（字体规范）

### 4.1 字体系统（Material 3 Default）

**字体族：** Roboto（系统默认）

### 4.2 文本样式规格

| 元素 | 样式 | 字号 | 字重 | 行高 |
|------|------|------|------|------|
| 页面标题 | `headlineSmall` | 24sp | Bold (700) | 32sp |
| 音色选择器标签 | `labelLarge` | 14sp | Medium (500) | 20sp |
| 文本输入内容 | `bodyLarge` | 16sp | Regular (400) | 24sp |
| 提示文字 | `bodyMedium` | 14sp | Regular (400) | 20sp |
| 时长显示 | `bodyMedium` + 等宽 | 14sp | Medium (500) | 20sp |
| 按钮文案 | `labelLarge` | 14sp | Medium (500) | 20sp |
| 状态文案 | `bodySmall` | 12sp | Regular (400) | 16sp |

### 4.3 等宽字体使用

**时长显示使用等宽字体**（确保数字宽度一致）：

```dart
Text(
  '00:30 / 01:00',
  style: TextStyle(
    fontFamily: 'monospace',
    fontFeatures: [FontFeature.tabularFigures()],
  ),
)
```

---

## 5. Spacing（间距规范）

### 5.1 间距系统（8dp Grid）

```dart
// 标准间距
static const double xs = 4.0;   // 紧凑元素
static const double sm = 8.0;   // 小间距
static const double md = 16.0;  // 标准间距
static const double lg = 24.0;  // 大间距
static const double xl = 32.0;  // 特大间距
```

### 5.2 页面布局间距

```
┌─────────────────────────────────────────────┐
│ App Bar Padding:                           │
│   Left: 16dp, Top: 16dp, Right: 16dp      │
├─────────────────────────────────────────────┤
│ 组件间间距: 16dp                            │
│ Section 间距: 24dp                          │
│ 底部安全区: 额外 24dp                       │
└─────────────────────────────────────────────┘
```

### 5.3 组件内边距

| 组件 | 内边距 |
|------|--------|
| TextField | 16dp horizontal, 16dp vertical |
| Card | 16dp all sides |
| 播放控制区 | 24dp vertical |
| 底部导航 | Material 默认（56dp） |

### 5.4 元素对齐

- **水平方向：** 左对齐或居中
- **垂直方向：** 基线对齐（文字）或中心对齐（图标）
- **按钮间距：** 主按钮与次按钮间距 16dp

---

## 6. Registry Safety（组件安全）

### 6.1 使用的组件库

**主要依赖：**
- Flutter SDK (Material 3)
- `flutter_riverpod` - 状态管理
- Material Icons（内置）

**无额外 UI 组件库依赖**（与 Phase 1 保持一致）

### 6.2 需要的组件列表

#### 核心组件

| 组件名 | 类型 | 说明 |
|--------|------|------|
| `TTSScreen` | Screen | TTS Tab 主页面 |
| `VoiceSelector` | Widget | 音色选择器下拉菜单 |
| `TTSTextInput` | Widget | 文本输入框封装 |
| `PlaybackControls` | Widget | 播放控制区封装 |
| `PlaybackProgressBar` | Widget | 进度条封装 |
| `TTSSnackbar` | Widget | 错误提示 Snackbar |

#### 复用 Phase 1 组件

| 组件名 | 复用位置 |
|--------|----------|
| `StatusIndicator` | `presentation/widgets/status_indicator.dart` |
| `NetworkStatusBar` | `presentation/widgets/network_status_bar.dart` |

### 6.3 音色选择器实现

**选择：** `DropdownButton` vs 网格卡片 → **`DropdownButton`**

**理由：**
1. 节省屏幕空间
2. 与 ASR Tab 的 `LanguageToggle` 风格一致
3. 实现简单，维护成本低
4. 5 个预设音色数量适中

**备选方案：** 如果未来音色数量增加（>8个），考虑迁移到网格卡片布局

### 6.4 进度条实现

**选择：** `Slider` vs 线性进度条 → **`Slider`（可拖动）**

**理由：**
1. 支持用户手动跳转播放位置（增强控制感）
2. Material 3 默认样式
3. 符合"完整播放控制"的设计决策（D-06）

**参数配置：**

```dart
Slider(
  value: progress,  // 0.0 - 1.0
  onChanged: onSeek,
  activeColor: Theme.of(context).colorScheme.primary,
  inactiveColor: Theme.of(context).colorScheme.surfaceContainerHighest,
  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
  trackHeight: 4,
)
```

### 6.5 底部导航实现

**选择：** `BottomNavigationBar` vs `TabBar` → **`BottomNavigationBar`**

**理由：**
1. Tab 数量固定为 2（ASR / TTS）
2. 切换行为清晰
3. Material 3 支持良好

**配置：**

```dart
BottomNavigationBar(
  currentIndex: selectedTab,
  onTap: onTabChanged,
  items: const [
    BottomNavigationBarItem(
      icon: Icon(Icons.mic),
      label: '语音输入',
    ),
    BottomNavigationBarItem(
      icon: Icon(Icons.music_note),
      label: '语音合成',
    ),
  ],
)
```

---

## Appendix A: Layout Draft

```
┌─────────────────────────────────────────────────────┐
│  语音合成                               [●] 连接状态  │
├─────────────────────────────────────────────────────┤
│                                                      │
│  选择音色                                             │
│  ┌─────────────────────────────────────────────┐    │
│  │ 中文女声-温柔                            ▼  │    │
│  └─────────────────────────────────────────────┘    │
│                                                      │
│  ┌─────────────────────────────────────────────┐    │
│  │                                             │    │
│  │     请输入要合成的文本...                     │    │
│  │                                             │    │
│  │                                             │    │
│  └─────────────────────────────────────────────┘    │
│                                                      │
│  00:30 / 01:00                                     │
│  ═══════════●═══════════════════                   │
│                                                      │
│              ┌─────────┐      ┌─────────┐          │
│              │  ⏸ 暂停 │      │  ⏹ 停止 │          │
│              └─────────┘      └─────────┘          │
│                                                      │
├─────────────────────────────────────────────────────┤
│           [🎤 语音输入]      [🎵 语音合成]           │
└─────────────────────────────────────────────────────┘
```

---

## Appendix B: Component Structure

```
lib/presentation/
├── screens/
│   └── tts_screen.dart           # TTS Tab 主页面
├── widgets/
│   ├── voice_selector.dart        # 音色选择器
│   ├── tts_text_input.dart        # 文本输入框
│   ├── playback_controls.dart     # 播放控制区
│   ├── playback_progress_bar.dart # 进度条
│   └── tts_status_indicator.dart # TTS 专用状态指示
└── providers/
    └── tts_provider.dart          # TTS 状态管理
```

---

## Appendix C: State Definitions

| 状态 | 说明 | UI 反馈 |
|------|------|---------|
| `idle` | 空闲，无播放任务 | 播放按钮可用，停止按钮禁用 |
| `connecting` | 正在连接服务器 | 播放按钮显示加载中 |
| `buffering` | 正在接收音频数据 | 进度条显示缓冲中 |
| `playing` | 正在播放 | 播放按钮变为暂停图标 |
| `paused` | 播放已暂停 | 播放按钮变为继续图标 |
| `error` | 发生错误 | Snackbar 显示错误信息 |

---

## Appendix D: Accessibility

| 要求 | 实现 |
|------|------|
| 屏幕阅读器支持 | 所有按钮和输入框有语义化 label |
| 触摸目标大小 | ≥ 48x48 dp |
| 对比度 | WCAG AA 标准（4.5:1） |
| 动态字体 | 支持系统字体缩放 |

---

*Document Version: 1.0*
*Created: 2026-04-10*
*Phase: 02-cloud-tts-foundation*
