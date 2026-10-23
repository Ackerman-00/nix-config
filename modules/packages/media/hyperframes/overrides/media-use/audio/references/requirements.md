# Requirements & Caches

## Credential & key priority

media-use holds no account of its own: every provider owns its own auth, and the
local paths need none. Keys resolve in this order — **first match wins**:

| Provider                         | Resolution order (first non-empty wins)                                                                 | Local deps when used                             |
| -------------------------------- | ---------------------------------------------------------------------------------------------------------- | ------------------------------------------------ |
| **ElevenLabs** (TTS)             | `$ELEVENLABS_API_KEY`                                                                                     | `pip install elevenlabs`                         |
| **Lyria** (BGM generation)       | `$GEMINI_API_KEY` → `$GOOGLE_API_KEY`                                                                     | `pip install google-genai`                       |
| **Gemini** (TTS, explicit)       | `$GEMINI_API_KEY` → `$GOOGLE_API_KEY` → `$GOOGLE_APPLICATION_CREDENTIALS` → `$GCS_CREDS`                  | `pip install google-auth requests`               |
| **Kokoro** (TTS, no key)         | always — the automatic voice fallback                                                                    | `pip install kokoro-onnx soundfile`              |
| **MusicGen** (BGM, no key)       | always — the automatic music fallback                                                                    | `pip install transformers torch soundfile numpy` |

With no key set, voice and music run fully locally (Kokoro / MusicGen) —
`npx hyperframes doctor` reports whether those local deps are installed. A
project `.env` is read automatically (walking up ≤5 dirs); the shell environment
always wins over it.

## Model caches & system dependencies

Each command downloads its own model on first run and caches it under `~/.cache/hyperframes/`:

- **TTS (ElevenLabs)** — API key + `ffmpeg` (the mp3 response is transcoded to `.wav`).
- **TTS (Kokoro)** — Kokoro-82M (~311 MB) + voices (~27 MB) in `tts/`. Requires Python 3.8+ with `kokoro-onnx` and `soundfile` (`pip install kokoro-onnx soundfile`). Non-English text also needs `espeak-ng` system-wide.
- **TTS (Gemini)** — API key or service-account credentials; no local model cache. Needs `pip install google-auth requests`.
- **BGM (Lyria)** — needs `$GEMINI_API_KEY` or `$GOOGLE_API_KEY` + `pip install google-genai`. No local model cache.
- **BGM (MusicGen)** — `pip install transformers torch soundfile`. `facebook/musicgen-small` (~300 MB) cached under `~/.cache/huggingface/` on first run.
- **Transcribe** — Whisper model size depending on choice (75 MB – 3.1 GB) in `whisper/`, downloaded from HuggingFace on first use. `whisper.cpp` itself is NOT bundled: the CLI resolves it from PATH, installs via Homebrew (macOS), or builds it from source with git+cmake on first use (`$HYPERFRAMES_WHISPER_PATH` overrides).
- **Remove-background** — `u2net_human_seg` (~168 MB ONNX) in `background-removal/models/`. Peak inference RAM ~1.5 GB.

Run `npx hyperframes doctor` if a command fails because of a missing dependency.
