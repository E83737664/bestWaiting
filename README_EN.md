# Best Waiting

[中文](README.md) | [English](README_EN.md)

People who use Claude seriously tend to switch to English — and for good reason.

The quality gap between English and Chinese prompts is real: sharper reasoning, better detail, deeper answers. So many users make the deliberate switch. But then a new problem surfaces: their spoken English isn't fluent enough to keep up. The words are there, the phrasing is off.

The second problem: waiting.

When working with Claude, waiting is constant. You send a prompt, then wait — 10 seconds, 30 seconds, sometimes longer. Too short to start something new, too long to just do nothing.

**Best Waiting** turns both problems into one solution: practice speaking English during the wait.

## The Solution

Press a hotkey, say something in English — whatever you just sent to Claude, your thoughts on the task, anything. Press again to stop. Your speech is transcribed and inserted into the current text field.

Meanwhile, **Ghost Coach** quietly records every sentence you speak, analyzes it for Chinglish patterns, collocation errors, and unnatural phrasing, then writes the results to a log.

You keep waiting for Claude. Ghost Coach quietly builds your personal error log.

## Ghost Coach

Every time you use voice input, Ghost Coach does two things:

**Step 1: Log.** Appends every utterance to:

```
~/Library/Application Support/OpenTypeless/coaching.jsonl
```

**Step 2: Analyze.** Sends the utterance to a language model that flags four issue types:

| Category | Description | Example |
|----------|-------------|---------|
| `chinglish` | Direct calques from Chinese | "give a suggestion" → "make a suggestion" |
| `collocation` | Wrong verb-noun or preposition pairing | "make a research" → "do research" |
| `hedge` | Excessive filler in professional speech | "I think maybe perhaps we could possibly..." |
| `word_choice` | A more natural word exists | Replace with idiomatic phrasing |

Minor grammar mistakes (missing articles, tense issues) are intentionally ignored. Only high-confidence issues are flagged.

### Log Format

```json
{
  "v": 1,
  "ts": "2026-05-05T09:32:27Z",
  "original": "I want to give a suggestion about this approach",
  "issue": "'Give a suggestion' is a direct calque; English uses 'make a suggestion' or 'suggest'",
  "suggestion": "I want to make a suggestion about this approach",
  "category": "chinglish",
  "session_app": "Claude"
}
```

### Viewing Your Log

```bash
# All entries
cat ~/Library/Application\ Support/OpenTypeless/coaching.jsonl | python3 -c \
  'import sys,json; [print(json.dumps(json.loads(l), indent=2, ensure_ascii=False)) for l in sys.stdin]'

# Top recurring error categories
cat ~/Library/Application\ Support/OpenTypeless/coaching.jsonl \
  | python3 -c 'import sys,json; [print(json.loads(l).get("category","null")) for l in sys.stdin if l.strip()]' \
  | sort | uniq -c | sort -rn | head -5
```

Utterances shorter than 5 words, non-English text, and rapid repeated dictations (within 10 seconds) are skipped automatically.

## Quick Start

### 1. Build & Run

1. Download **Xcode** from the [App Store](https://apps.apple.com/app/xcode/id497799835)
2. Clone the repo:
   ```bash
   git clone https://github.com/E83737664/bestWaiting.git
   ```
3. Open `OpenTypeless.xcodeproj` in Xcode
4. Set up signing: Select the `OpenTypeless` target → **Signing & Capabilities** → Check **"Automatically manage signing"** → Select your **Personal Team** → Set Signing Certificate to **"Sign to Run Locally"**
5. Press **Cmd+R** to build and run

After building, look for the microphone icon (🎙) in the top-right menu bar.

### 2. Grant Permissions

On first launch, grant:
- **Microphone** — for recording
- **Accessibility** — for the global hotkey and text insertion

### 3. Configure Transcription API

Click the menu bar icon → **Settings** → **API** tab, enter your OpenAI API key.

Get one at [platform.openai.com/api-keys](https://platform.openai.com/api-keys).

### 4. Configure Ghost Coach

Ghost Coach uses [Kimi](https://kimi.moonshot.cn/) for analysis:

```bash
pip install kimi-cli
kimi login
```

Credentials are saved automatically. No additional configuration needed.

### 5. Start Using

| Action | Hotkey |
|--------|--------|
| Start recording | Right Option (Alt) key |
| Stop & transcribe | Right Option (Alt) again |
| Cancel recording | Double-press Right Option (Alt) quickly |

The hotkey can be customized in Settings → Hotkeys tab.

## Pricing

Transcription uses `gpt-4o-mini-transcribe` by default ($0.003/min). Ghost Coach analysis uses Kimi's `kimi-for-coding` model, which requires a Kimi account and is currently free.

| Usage | Transcription cost (USD) |
|-------|--------------------------|
| 1 minute | $0.003 |
| 30 min/day, 1 month | ~$2.70 |

## License

MIT
