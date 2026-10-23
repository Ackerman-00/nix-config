# Setup and providers — install, auth, RAM ladders, forcing a provider

## Setup — local and keyless by default

Nothing here needs an account. music and sound effects come from Openverse
(CC0 / CC BY, no key) with the bundled offline library behind them; voice runs
on local Kokoro; images and video run on the local model ladders. A project
`.env` is read automatically (walking up ≤5 dirs) and the shell environment
always wins over it.

Before resolving anything, verify the local dependencies with:

```bash
npx hyperframes media-use resolve --doctor
```

## Cloud providers (optional, your own key)

Two optional cloud providers exist, and each owns its own auth — media-use
never stores a key:

- **ElevenLabs** (`$ELEVENLABS_API_KEY`) — TTS. The engine picks it
  automatically when the key is set; local Kokoro is the fallback.
- **Gemini** (`$GEMINI_API_KEY` / `$GOOGLE_API_KEY`, or a service-account file
  at `$GOOGLE_APPLICATION_CREDENTIALS` / `$GCS_CREDS`) — TTS when asked for by
  name, and Lyria music generation when the recipe is present.

Lyria needs `pip install google-genai`; ElevenLabs needs `pip install elevenlabs`.

## Providers

media-use holds no keys; every external tool owns its auth. Generation is
centered on the local, free, on-device paths. music and sound effects from
a host app's own tools need none of it. Local tools are the default where they
exist: Kokoro for voice, MusicGen for music, Parakeet for transcription, mflux
for images and LTX for local video generation. `resolve` spec-checks
AVAILABLE RAM for those local ladders inside the CLI (the image tiers are listed
in `references/operations.md`).

| Type      | Provider / path                                                                                                                                                               |
| --------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| bgm       | Openverse music search (CC0 / CC BY, no account); a host app's own music tools come first                                                                                      |
| sfx       | Openverse (CC0 / CC BY, no account), bundled library offline; a host app's own sound tools come first                                                                         |
| image     | local mflux (RAM-graded); codex `image_gen` upsell                                                                                                                            |
| voice     | local **Kokoro** (free, on-device); ElevenLabs or Gemini when configured                                          |
| icon      | local generation                                                                                                  |
| logo      | theSVG (thesvg.org), then GitHub org avatar, then domain favicon (all free)                                                                                                   |
| grade/lut | local core-preset map, params/CDN look index, deterministic `buildCube` fallback                                                                                              |
| video     | local LTX (`videogen` ladder), RAM-graded                                                                                                                                     |

Local Kokoro (voice), MusicGen (music), Parakeet (transcription), mflux
(image), and LTX (video) run on-device (free, private, offline once cached).
The `codex` CLI remains the ChatGPT-sub image upsell. Cost rule (X4): the agent
confirms before an agent-initiated paid call; a user-requested one just runs.

To force a specific generator (e.g. a user says "make this image with codex"),
pass `--provider codex`: it pins resolution to that provider. See
`references/operations.md` for the RAM ladders and provider recipes.

`--local-only` skips every network provider, leaving the project + global cache
and any installed local provider.

## CLI tools used (what to run, and how to enable each)

`resolve` auto-cascades; each provider shells one CLI. Only
`ffmpeg`/`ffprobe` are strictly required for the tool to run at all.

| Tool               | Serves                                                                      | Install                                                                                                                                                                                     |
| ------------------ | --------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `ffmpeg`/`ffprobe` | adopt probing, smart-grade signalstats, cut, duck bake, loudnorm            | system package (`brew install ffmpeg`)                                                                                                                                                      |
| `mflux-generate`   | local image gen (FLUX), best-for-RAM                                        | `uv venv ~/.venvs/mflux && VIRTUAL_ENV=~/.venvs/mflux uv pip install mflux==0.9.6`                                                                                                          |
| `codex`            | image gen upsell (ChatGPT sub)                                              | Codex CLI, logged in via ChatGPT (owns its own auth)                                                                                                                                        |
| `parakeet-mlx`     | local transcription (default ASR, best) on Apple Silicon                    | `uv venv ~/.venvs/parakeet && VIRTUAL_ENV=~/.venvs/parakeet uv pip install parakeet-mlx`                                                                                                    |
| `ltx-2-mlx`        | local video gen                                                             | `git clone https://github.com/dgrauet/ltx-2-mlx && cd ltx-2-mlx && uv sync --all-extras`                                                                                                    |
| `npx hyperframes`  | Kokoro TTS (voice), Parakeet or whisper.cpp (transcribe), remove-background | via the hyperframes CLI; Parakeet on macOS, Windows and glibc 2.32+ Linux: `npx hyperframes models install parakeet`; whisper.cpp is built on first use (Homebrew on macOS, else git+cmake) |

The RAM-graded local-model shortlist + exact per-tier install/invoke lives in
the CLI's bundled media-use engine, not in the standalone skill. Without a tool on PATH, its provider
prints a one-line diagnostic to stderr and resolve falls through where another
provider exists (e.g. no `mflux` -> codex image upsell; no `parakeet-mlx` -> whisper.cpp).
