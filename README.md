# Best Waiting

[中文](README.md) | [English](README_EN.md)

## 为什么用英文操作 Claude

Anthropic CEO Dario Amodei 一贯主张 AI 安全与透明，但没有人真正知道 Claude 对不同语言的内容是否存在差异对待。在这种不确定性下，用英文和 Claude 交互，至少是一个更不容易出错的选择。

于是很多人开始刻意切换到英文——但口语表达跟不上，想说的说不清楚，反而拖慢了节奏。更尴尬的是，发出 prompt 之后，还要等。10 秒、30 秒、有时候更长。这段时间太短，不值得打开另一件事，太长，又只是发呆。

**Best Waiting** 的答案：在等待的时候练英文口语。

## 解决方案

按下快捷键，用英语说出你的想法——可以是刚才发给 Claude 的问题、你对这个任务的思考、随便一段话。说完再按一下，语音通过本地 Whisper 模型转写完成，文字插入到当前输入框。

与此同时，**Ghost Coach** 在后台悄悄记录你说的每一句话，分析是否有中式英语、搭配错误、不自然的表达，并把结果写入日志。

你继续等 Claude。Ghost Coach 悄悄替你积累语料。

## Ghost Coach

每次你用语音输入，Ghost Coach 会做两件事：

**第一步：记录。** 将你说的每句话追加写入：

```
~/Library/Application Support/OpenTypeless/coaching.jsonl
```

**第二步：分析。** 调用语言模型判断这句话是否有问题，标记以下四类：

| 类别 | 说明 | 例子 |
|------|------|------|
| `chinglish` | 中式直译 | "give a suggestion" → "make a suggestion" |
| `collocation` | 搭配错误 | "make a research" → "do research" |
| `hedge` | 模糊语气词堆叠 | "I think maybe perhaps we could possibly..." |
| `word_choice` | 有更自然的说法 | 换用更地道的词汇 |

轻微语法错误（缺冠词、时态问题）不会被标记。只标记高置信度的问题。

### 日志格式

```json
{
  "v": 1,
  "ts": "2026-05-05T09:32:27Z",
  "original": "I want to give a suggestion about this approach",
  "issue": "'Give a suggestion' 是中式直译，英文习惯用 'make a suggestion' 或直接用 'suggest'",
  "suggestion": "I want to make a suggestion about this approach",
  "category": "chinglish",
  "session_app": "Claude"
}
```

### 查看日志

```bash
# 查看所有记录
cat ~/Library/Application\ Support/OpenTypeless/coaching.jsonl | python3 -c \
  'import sys,json; [print(json.dumps(json.loads(l), indent=2, ensure_ascii=False)) for l in sys.stdin]'

# 最常出现的错误类别
cat ~/Library/Application\ Support/OpenTypeless/coaching.jsonl \
  | python3 -c 'import sys,json; [print(json.loads(l).get("category","null")) for l in sys.stdin if l.strip()]' \
  | sort | uniq -c | sort -rn | head -5
```

少于 5 个单词、非英文内容、10 秒内连续重复的录音会被自动跳过。

## 快速开始

### 1. 编译运行

1. 从 [App Store](https://apps.apple.com/app/xcode/id497799835) 下载 **Xcode**
2. 克隆仓库：
   ```bash
   git clone https://github.com/E83737664/bestWaiting.git
   ```
3. 用 Xcode 打开 `OpenTypeless.xcodeproj`
4. 设置签名：选择 `OpenTypeless` target → **Signing & Capabilities** → 勾选 **"Automatically manage signing"** → 选择你的 **Personal Team** → Signing Certificate 选择 **"Sign to Run Locally"**
5. 按 **Cmd+R** 编译运行

编译完成后，在屏幕右上角菜单栏找到麦克风图标（🎙）。

### 2. 授权权限

首次启动时授权：
- **麦克风** — 录音
- **辅助功能** — 全局快捷键和文字插入

### 3. 启动本地语音转写

语音转写使用本地运行的 [OpenAI Whisper](https://github.com/openai/whisper) 模型，完全离线，无需 API key。

```bash
# 安装依赖
pip install openai-whisper

# 启动本地转写服务（保持终端运行）
python3 whisper_server.py
```

首次运行会自动下载 Whisper `base` 模型（约 140MB）。下载完成后服务在本地 `http://localhost:5001` 运行，应用启动后会自动连接。

### 4. 配置 Ghost Coach

Ghost Coach 使用 [Kimi](https://kimi.moonshot.cn/) 做分析：

```bash
pip install kimi-cli
kimi login
```

登录后凭证自动保存，无需其他配置。

### 5. 使用

| 操作 | 快捷键 |
|------|--------|
| 开始录音 | 右 Option（Alt）键 |
| 停止并转写 | 再按一次右 Option（Alt）键 |
| 取消录音 | 快速按两下右 Option（Alt）键 |

快捷键可在设置 → 快捷键标签页中自定义。

## 费用

语音转写使用本地 Whisper 模型，无需 API key，完全免费。Ghost Coach 分析使用 Kimi 的 `kimi-for-coding` 模型，需要 [Kimi](https://kimi.moonshot.cn/) 账号，按 Kimi 的定价计费。

## 许可证

MIT
