# Best Waiting

[中文](README.md) | [English](README_EN.md)

## Why Use English with Claude

Anthropic CEO Dario Amodei has consistently advocated for AI safety and transparency — but nobody actually knows whether Claude treats different languages differently under the hood. Given that uncertainty, using English with Claude is at least the safer bet.

So many people deliberately switch to English. But then their spoken English can't keep up: the thought is there, the expression isn't, and it slows everything down. And on top of that, once you send a prompt, you wait — 10 seconds, 30 seconds, sometimes longer. Too short to start something new, too long to do nothing.

**Best Waiting** answers both at once: practice speaking English during the wait.

## The Solution

Press a hotkey, say something in English — whatever you just sent to Claude, your thoughts on the task, anything. Press again to stop. Your speech is transcribed locally by Whisper and inserted into the current text field.

Meanwhile, **Ghost Coach** quietly records every sentence you speak, analyzes it for Chinglish patterns, collocation errors, and unnatural phrasing, then writes the results to a log.

You keep waiting for Claude. Ghost Coach quietly builds your personal error log.

## Ghost Coach

Every time you use voice input, Ghost Coach does two things:

**Step 1: Log.** Appends every utterance to:

```
~/Library/Application Support/bestWaiting/coaching.jsonl
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
cat ~/Library/Application\ Support/bestWaiting/coaching.jsonl | python3 -c \
  'import sys,json; [print(json.dumps(json.loads(l), indent=2, ensure_ascii=False)) for l in sys.stdin]'

# Top recurring error categories
cat ~/Library/Application\ Support/bestWaiting/coaching.jsonl \
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
3. Open `bestWaiting.xcodeproj` in Xcode
4. Set up signing: Select the `bestWaiting` target → **Signing & Capabilities** → Check **"Automatically manage signing"** → Select your **Personal Team** → Set Signing Certificate to **"Sign to Run Locally"**
5. Press **Cmd+R** to build and run

After building, look for the microphone icon (🎙) in the top-right menu bar.

### 2. Grant Permissions

On first launch, grant:
- **Microphone** — for recording
- **Accessibility** — for the global hotkey and text insertion

### 3. Start the Local Transcription Server

Transcription runs locally using [OpenAI Whisper](https://github.com/openai/whisper) — fully offline, no API key required.

```bash
# Install dependencies
pip install openai-whisper

# Start the local transcription server (keep the terminal running)
python3 whisper_server.py
```

On first run, Whisper will automatically download the `base` model (~140 MB). Once ready, the server runs at `http://localhost:5001` and the app connects automatically.

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

Transcription runs on a local Whisper model — no API key, completely free. Ghost Coach analysis uses Kimi's `kimi-for-coding` model, which requires a [Kimi](https://kimi.moonshot.cn/) account and is billed at Kimi's standard rates.

## License

MIT
