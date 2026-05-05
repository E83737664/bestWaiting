# Best Waiting

[中文](README.md) | [English](README_EN.md)

用 Claude 的人都有一个共识：尽量用英文。

不是装，是因为用中文提问时模型表现确实会打折扣——推理质量、细节把握、回答深度，都有肉眼可见的差距。于是很多人开始刻意切换到英文，但问题随之而来：英文表达不够流利，想说的说不清楚，反而拖慢了节奏。

第二个问题：等待。

用 Claude 做事的过程中，等待是常态。你发出一个 prompt，然后等。10 秒、30 秒、有时候更长。等的时间太短，不够打开另一件事；太长，又只是发呆。

**Best Waiting** 把这两个问题合并成一个解法：在等待的时候练英文口语。

## 解决方案

按下快捷键，用英语说出你的想法——可以是刚才发给 Claude 的问题、你对这个任务的思考、随便一段话。说完再按一下，语音转写完成，文字插入到当前输入框。

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

### 3. 配置转写 API

点击菜单栏图标 → **Settings** → **API** 标签页，填入 OpenAI API key。

获取地址：[platform.openai.com/api-keys](https://platform.openai.com/api-keys)

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

语音转写默认使用 `gpt-4o-mini-transcribe`（$0.003/分钟）。Ghost Coach 分析使用 Kimi 的 `kimi-for-coding` 模型，需要 Kimi 账号，暂无额外费用。

| 使用量 | 转写费用（美元） |
|--------|----------------|
| 1 分钟 | $0.003 |
| 每天 30 分钟，1 个月 | 约 $2.70 |

## 许可证

MIT
