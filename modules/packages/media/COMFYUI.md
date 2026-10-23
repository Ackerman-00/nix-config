# ComfyUI on NixOS 26.11 — free/local, and what to use instead

Research date: 2026-10-21. Host: `quietcraft` (Ryzen 5 5600G, Radeon Vega 7 / Cezanne,
`gfx908`, 15 GB RAM, no ROCm installed, Mesa RADV Vulkan 1.4.354 present).

> **The short version.** ComfyUI is free but it is the wrong shape: a node canvas, and
> unusable on this GPU. The equivalent of "Remotion/HyperFrames for images" is
> **Diffusers + Modular Diffusers** — a code-first framework with first-class agent
> skills, Apache-2.0, 34.8k★. For actual pixels on this box, the engine is
> **stable-diffusion.cpp** (MIT, Vulkan) or **LocalAI** (MIT, OpenAI-compatible API)
> wrapping it. See §5 and §7.

## 1. Is ComfyUI free?

Yes, the software is free and self-hostable. What is *not* free is Comfy Cloud, the
partner-model APIs, and some model weights.

| Component | License | Free locally? | Source |
|---|---|---|---|
| ComfyUI | GPL-3.0 | Yes | [LICENSE](https://raw.githubusercontent.com/Comfy-Org/ComfyUI/master/LICENSE) |
| `comfy-cli` | GPL-3.0-only | Yes | [pypi](https://pypi.org/project/comfy-cli/) 1.23.0 |
| `comfy-mcp` (official local MCP) | **AGPL-3.0-or-later OR Commercial** | Yes for local runs | [github](https://github.com/Comfy-Org/comfy-mcp), pypi 0.10.0 |
| Comfy Cloud MCP (`cloud.comfy.org/mcp`) | hosted | No — needs an active subscription; 5 free runs for new users | [docs](https://docs.comfy.org/agent-tools/mcp) |
| Comfy Cloud `partner_generate` / partner API nodes | hosted | No — spends Comfy credits | same |

Model weights carry their own terms, which is where "fully free" gets muddy:

- `FLUX.1-schnell` — Apache-2.0, commercial use allowed.
- `FLUX.1-dev` — non-commercial unless a licence is bought.
- SDXL — OpenRAIL++ (commercial allowed with the use restriction).
- Qwen-Image / Z-Image / most current models — Apache-2.0.

## 2. Can OpenCode drive it without the desktop app?

Yes. The app is optional; the engine is a local HTTP server.

- `comfy-mcp` (official, `pip install comfy-mcp`) is a **stdio** MCP server that drives the
  local ComfyUI on `127.0.0.1:8188`. 40 tools, including `run_workflow`, `generate_image`,
  `fetch_outputs`, `search_models`, `search_nodes`, `validate_workflow`.
  The docs' own wording: *"the local connection is the open-source connection: your client
  launches the server on your machine and it drives the ComfyUI installed there."*
- `comfy-cli` gives the same thing from a shell: `comfy run --workflow <path> [--wait]`.
- `ComfyScript` (MIT) exposes ComfyUI nodes as Python functions — the closest thing to a
  code-first ComfyUI.

OpenCode entry (stdio, local):

```json
{
  "mcp": {
    "comfy-mcp": {
      "type": "local",
      "command": ["comfy-mcp"],
      "environment": { "COMFY_BIN": "/home/ackerman/.local/bin/comfy" },
      "enabled": true
    }
  }
}
```

Do **not** set `COMFY_API_KEY` unless partner-API nodes are wanted: with it unset, every
tool stays local and free.

**Remote ComfyUI is a first-class option.** `comfy-cli` accepts `http://host:port`,
`host:port`, or `http://host`, with a documented precedence: a per-command
`--host`/`--port` flag wins, then the configured host, then the local default. So the same
CLI and the same `comfy-mcp` tool surface can drive a ComfyUI on a rented GPU while the
code, workflows and skills stay local and free. That is the escape hatch if the local
Vulkan path turns out too slow for real work: author locally, execute on a GPU you rent
for the hour, keep every artifact on this machine.

## 3. NixOS 26.11 status

- 26.11 is codename **"Zokor"**, release **2026-11-23**
  ([schedule issue #567567](https://github.com/NixOS/nixpkgs/issues/567567)). Branch-off
  2026-11-09/16, so `nixos-26.11` does not exist yet — `nixos-unstable` is the branch to
  track until then.
- **nixpkgs already ships ComfyUI**:
  - `pkgs/by-name/co/comfyui/package.nix` → `pkgs.comfyui`, ComfyUI 0.39.2, GPL-3.0.
  - `nixos/modules/services/misc/comfyui.nix` → `services.comfyui` with
    `enable`, `package`, `dataDir`, `port`, `listen`, `extraArgs`, `extraPackages`,
    `models` (declarative `fetchurl` + hash + `installPaths` → symlinked into
    `models/<path>`), and a hardened systemd unit (`ProtectSystem=strict`, `PrivateUsers`,
    `NoNewPrivileges`, …).
  - First landed **2026-08-04**; present in `nixos-unstable`, **absent in `nixos-26.05`**.
    Because the 26.11 branch is cut from master *after* that date, both will be in 26.11.
- Also relevant to this host: `pkgs.stable-diffusion-cpp` (with `vulkanSupport`),
  `python3Packages.torchWithVulkan`, and `rocmPackages` with a `gfx9` scope that includes
  `gfx908`.

The nixpkgs `comfyui` package builds its own Python env from `python3Packages` and pins
`torch`/`torchvision` from nixpkgs — i.e. **CPU or CUDA, not ROCm by default**. For AMD the
package would need a torch built against ROCm, which nixpkgs does not ship prebuilt for
consumer gfx908.

### What nixpkgs has for the alternatives

| Package | Version | Licence | Notes |
|---|---|---|---|
| `python3Packages.diffusers` | 0.38.0 | Apache-2.0 | `mainProgram = "diffusers-cli"`. Upstream is 0.41+, so nixpkgs lags |
| `python3Packages.torchWithVulkan` | — | BSD-3 | `torch.override { vulkanSupport = true; }`. Experimental upstream |
| `pkgs.stable-diffusion-cpp` | master-951-f89d9b1 | MIT | `vulkanSupport` argument; needs the `spirv-headers` install fix (§5) |
| `pkgs.local-ai` | 2.28.0 | MIT | **`broken = true`** — needs an override and a real build |
| `pkgs.comfyui` | 0.39.2 | GPL-3.0 | CPU by default: nixpkgs torch takes `cudaSupport ? config.cudaSupport` and `rocmSupport ? config.rocmSupport`, both false unless the config sets them |
| `rocmPackages` | 7.2.x | — | has a `gfx9` scope with `gfx908`, but it is a build target, not support |

## 4. The hardware problem: gfx908 is not a supported ROCm target

This is the decisive finding, and it is why ComfyUI is the wrong tool on this box.

- AMD's ROCm supported-GPU table lists `gfx908` **only** as Instinct **MI100**. The Radeon
  table has no `gfx908` row at all — consumer Vega/Cezanne is simply absent.
  ([system requirements](https://rocm.docs.amd.com/projects/install-on-linux/en/docs-7.2.2/reference/system-requirements.html))
- [TheRock SUPPORTED_GPUS.md](https://raw.githubusercontent.com/ROCm/TheRock/main/SUPPORTED_GPUS.md)
  puts `gfx908` under *AMD Instinct – Linux*; the *AMD Radeon – Linux* table lists
  gfx906/gfx900/90c and RDNA1–4, but not gfx908.
- ROCm 7.2's Ryzen-APU matrix supports **gfx1150 and gfx1151 only**.
- nixpkgs' `rocmModules.clr.gpuTargets` does include `"908"`, but that is a **build** target
  list, not a support statement — the comment in `clr/default.nix` says
  `"908" # MI100 - adds MFMA (matrix fused multiply-add) ops`.
- PyTorch ROCm wheels *do* contain gfx908 kernels, so the ISA matches. The blocker is
  support, tuning, and driver validation, not instruction encoding.

Verdict per stack:

| Stack | On this host | Why |
|---|---|---|
| ComfyUI + ROCm | **No** | consumer gfx908 unsupported by AMD; no prebuilt nixpkgs torch for it |
| ComfyUI `--cpu` | Works, slow | official flag; ~3.4 s/it for SD1.5 @384²/12 steps measured elsewhere, host CPU unspecified |
| Diffusers CPU | Works, slowest | PyTorch CPU + Python overhead |
| **stable-diffusion.cpp + Vulkan (Mesa RADV)** | **Yes — the only accelerated local path** | no torch, no ROCm; ggml's Vulkan backend needs instance ≥1.2 and `storageBuffer16BitAccess` |

## 5. The recommendation: stable-diffusion.cpp + Vulkan

`leejet/stable-diffusion.cpp` (MIT, 7.7k★, pushed 2026-10-21) is the "llama.cpp of
images": a self-contained C/C++ engine with a Vulkan backend, GGUF quantisation, and an
HTTP server. This is the closest local analogue to what HyperFrames is for video — a
deterministic, scriptable, fully-local pipeline with an HTTP surface an agent can drive.

- **Vulkan gates** (`ggml-vulkan.cpp`): instance ≥ 1.2 required; `storageBuffer16BitAccess`
  required; `shaderFloat16` optional — GCN/Vega falls back to f32 math, so expect slower
  than RDNA cards.
- **AMD iGPU gotchas**:
  - UMA/GTT accounting is broken — the model manager reports *"available 0.00 MB device"*
    because it counts only the VRAM carve-out ([#2022](https://github.com/leejet/stable-diffusion.cpp/issues/2022)).
  - `--offload-to-cpu` pins host-visible buffers past the GTT budget and can device-loss
    the GPU ([#2015](https://github.com/leejet/stable-diffusion.cpp/issues/2015)). With 15 GB
    RAM, GTT ≈ 7.5 GB — **avoid `--offload-to-cpu`**; use `--params-backend disk`.
  - `--conv-direct auto` measured ~7× slower on RDNA2 — pin `--conv-direct off`
    ([#2137](https://github.com/leejet/stable-diffusion.cpp/issues/2137)).
- **Model fit in 15 GB shared RAM** (sizes from the HF API on `leejet/*-GGUF`):

| Model | Total | Fits? | Notes |
|---|---|---|---|
| Z-Image-Turbo Q4_K | ≈6.3 GiB | comfortable | 8 steps, cfg 1.0; upstream says it runs in 4 GB VRAM |
| SDXL Illustrious XL Q4 | ≈6.5 GiB | yes | 3–5 min/image at 768×1024 LCM-7 on a 3200G (gfx906) |
| SD1.5 q4 | ≈2.3 GB | yes | fastest sanity check |
| FLUX.1-schnell Q4_K | ≈10.3 GiB | marginal | ~4 GB left for OS+swap |

  Timings are from a sibling gfx906 APU; **5600G-specific numbers are unverified**.
- **API surfaces** for agent driving: OpenAI-compatible `POST /v1/images/generations`,
  A1111-compatible `POST /sdapi/v1/txt2img`, and a native async job API
  (`POST /sdcpp/v1/img_gen` → `GET /sdcpp/v1/jobs/{id}`), plus model management
  (`POST /sdcpp/v1/models/load`) driven by declarative JSON "recipes".

### nixpkgs expression (Vulkan build)

nixpkgs pins `master-951-f89d9b1` and exposes `vulkanSupport`. Two build blockers:

1. ggml's Vulkan CMake does `find_package(Vulkan COMPONENTS glslc REQUIRED)` — satisfied by
   nixpkgs `shaderc` (ships `glslc`) — **and** `find_package(SPIRV-Headers CONFIG REQUIRED)`.
   nixpkgs' `spirv-headers` installs nothing, so that config package is missing.
2. `spirv-tools` passes `-DSPIRV-Headers_SOURCE_DIR=${spirv-headers}`, so the fix is to give
   `spirv-headers` a real install.

```nix
let
  pkgs = import nixpkgs { system = "x86_64-linux"; };
in
{
  stable-diffusion-cpp-vulkan = pkgs.stable-diffusion-cpp.override {
    vulkanSupport = true;
    spirv-tools = pkgs.spirv-tools.overrideAttrs (prev: {
      propagatedBuildInputs = (prev.propagatedBuildInputs or [ ]) ++ [ spirvHeaders ];
    });
  };
  spirvHeaders = pkgs.spirv-headers.overrideAttrs (prev: {
    nativeBuildInputs = [ pkgs.cmake ];
    cmakePhase = ''
      cmake -S . -B build \
        -DSPIRV_HEADERS_ENABLE_INSTALL=ON \
        -DSPIRV_HEADERS_ENABLE_TESTS=OFF \
        -DCMAKE_INSTALL_INCLUDEDIR=include
    '';
    installPhase = "cmake --install build";
    dontFixup = true;
  });
}
```

**UNVERIFIED — not built here** (per the no-local-build rule). Two nixpkgs quirks to expect:
`meta.mainProgram = "sd"` is stale (only `sd-cli` and `sd-server` are installed, so use
`$out/bin/sd-cli`), and the nixpkgs `sd-server` has no embedded web UI (the upstream
`frontend/dist/gen_index_html.h` is not committed) — the HTTP API works regardless.

### Zero-build alternative

Upstream release `master-982-0518b34` (2026-10-20) ships
`sd-master-0518b34-bin-Linux-Ubuntu-24.04-x86_64-vulkan.zip` (35.1 MiB).

### First-run recipe

```sh
sd-cli --backend vulkan0 \
  --diffusion-model z_image_turbo-Q4_K.gguf \
  --vae ae.sft \
  --llm Qwen3-4B-Instruct-2507-Q4_K_M.gguf \
  --cfg-scale 1.0 --steps 8 --conv-direct off -W 1024 -H 1024
```

Set a large BIOS UMA frame buffer (≥8 GB of 16 GB) first, and dual-channel RAM.

## 6. Model catalogue — what is actually free to use

Verified from the Hugging Face model repos and their LICENSE files. This is where "fully
free" mostly breaks: the *software* is free, the *weights* often are not.

**Truly permissive (Apache-2.0 / MIT, no revenue cap, no registration, no territory carve-out):**

| Model | Params | Licence | Notes |
|---|---|---|---|
| **FLUX.2 klein-4B** / klein-base-4B | 3.88B / 3.9B | Apache-2.0 | The *only* BFL release with a true permissive licence. GGUF Q4_1 = 2.69 GB |
| **MOSS-Image** Base/SFT | 5.08B | Apache-2.0 | Newest permissive model (2026-10-11). GGUF Q2_K 2.21 GB → Q8 5.71 GB |
| **Z-Image** / **Z-Image-Turbo** | 6.15B | Apache-2.0 | Best quality/size ratio. Turbo GGUF Q4_K_M 5.02 GB |
| **Qwen-Image** / `-Edit-2509` / `-Edit-2511` / `-2512` | 20.4B | Apache-2.0 | ⚠️ **not** the 2.1 generation (see below) |
| **Wan2.2** family (TI2V-5B, T2V-A14B, I2V-A14B, Animate) | 5B / 14B | Apache-2.0 | Best fully-free video. TI2V-5B GGUF Q4_K_S 3.12 GB |
| **Sana 1600M** | 1.6B | Apache-2.0 | Smallest viable permissive model |
| **Chroma** / Chroma1-HD / Chroma1-Flash | 8.9B | Apache-2.0 | FLUX-schnell-derived |
| **LongCat-Image**, **Ovis-Image-7B**, **Boogu-Image-0.1**, **Lumina-Image-2.0** | 2.6–19B | Apache-2.0 | |
| **SDXL base 1.0** | 2.57B | CreativeML Open RAIL++-M | Permissive-with-use-restrictions; easiest CPU fallback |

**Free for commercial use, but with a cap or condition:**

- **FLUX.3 Image Klein** (2026-10-13, newest BFL open-weights release) — FLUX Kommunity
  v1.0: commercial outputs allowed under **US$5M** gross annual revenue. Inference code
  Apache-2.0. GGUF Q3_K_M 3.01 GB.
- **LTX-2.5 / LTX-2.3** — LTX-2.x Community License: free under **$10M** revenue.
  At 15.6 GB minimum for Q5_K_M it does **not** fit 15 GB anyway.
- **SD 3.5 Medium / Large** — Stability AI Community License: free commercial under
  **$1M** revenue, but you must **register**. Not "fully free" in the zero-friction sense.

**Avoid if "fully free" is the requirement:**

- ❌ **FLUX.1-dev**, **FLUX.2-dev**, **FLUX.2 klein-9B** / base-9B — Non-Commercial
  v1.1.1 / v2.1. (BFL split the licence by size: the **4B** siblings are Apache-2.0.)
- ❌ **Qwen-Image-2.1 / -2.1-Turbo** — Qwen **Research** Licence (2026-09-20):
  "FOR NON-COMMERCIAL PURPOSES ONLY". Note this is a *regression*: the older
  `Qwen-Image` / `-Edit-2511` / `-2512` are still Apache-2.0. If commercial use matters,
  pin to the 2511/2512 generation.
- ⚠️ **MiniMax-H3** — excludes the **USA** (plus EU/UK/South Korea).
- ⚠️ **HunyuanImage-2.1/3.0, HunyuanVideo-1.5** — Tencent Community Licence, excludes
  EU/UK/South Korea. HunyuanVideo-1.5 720p GGUF Q4_K_S is 4.92 GB, so it does fit.
- ⚠️ **CogVideoX-5b** — commercial requires registration at open.bigmodel.cn.

**Fits 15 GB shared RAM** (GGUF sizes read from the HF tree API, not estimated):

| Pick | DiT | Text encoder | Total | Licence |
|---|---|---|---|---|
| FLUX.2 klein-4B Q4_1 | 2.69 GB | Qwen3-4B GGUF | ~7–10 GB | ✅ Apache-2.0 |
| Z-Image-Turbo Q4_K_M | 5.02 GB | Qwen3-4B GGUF | ~9–11 GB | ✅ Apache-2.0 |
| Sana 1600M | ~3.2 GB | small | ~4–5 GB | ✅ Apache-2.0 |
| SDXL base 1.0 | ~3.3 GB | CLIP-L + CLIP-G | ~4–5 GB | ✅ RAIL++-M |
| MOSS-Image-SFT Q4_K | 3.33 GB | Qwen3.5-9B w4a8 ≈ 6.7 GB | ~10 GB | ✅ Apache-2.0 |
| Wan2.2 TI2V-5B Q4_K_S | 3.12 GB | umt5_xxl fp8 6.27 GB | ~10 GB | ✅ Apache-2.0 (video) |
| FLUX.3 Image Klein Q3_K_M | 3.01 GB | Qwen3-VL-4B + 9B upsampler | ~12–15 GB | ⚠️ Kommunity, tight |
| LTX-2.5 | 15.6 GB min | Gemma4-12B | **> 20 GB** | ❌ does not fit |

**ComfyUI's own current defaults** (from `Comfy-Org/workflow_templates` — note the repo
is `workflow_templates`, *not* `comfyui-workflow-templates`; 1.3k★, MIT): local templates
default to FLUX.3 klein (int8-convrot 5.8 GB), MOSS-Image, Qwen-Image-2.1, Z-Image, and
FLUX.2 klein. ComfyUI's native quantisation convention is `int8-convrot` (rotated int8),
not GGUF.

**Two corrections worth knowing:** *Wan 2.5 does not exist* in any public repo — Wan-AI's
newest public release is Wan2.2-Animate-2 (2026-08-06). And *FLUX.3 Image Klein
(2026-10-13) has superseded FLUX.2*.

## 7. The framework-level answer: Diffusers + Modular Diffusers

This is the Remotion/HyperFrames analogue, verified from the diffusers repo and docs.

**Scale and licence, side by side with the projects it should be compared to:**

| Project | Stars | Licence | Last push | Declaring style | Agent integration |
|---|---|---|---|---|---|
| **huggingface/diffusers** | 34,777 | **Apache-2.0** | 2026-10-21 | **Python code** | `.ai/skills/` + `diffusers-cli skills` |
| ComfyUI | 141,300 | GPL-3.0 | 2026-10-21 | node graph | `comfy-mcp` (AGPL-or-commercial) |
| remotion-dev/remotion | 65,945 | source-available | 2026-10-21 | React/TS | `remotion-dev/skills` (5,476★) |
| heygen-com/hyperframes | 68,978 | Apache-2.0 | 2026-10-21 | HTML/CSS | skills + CLI |
| mudler/LocalAI | 49,829 | MIT | 2026-10-21 | HTTP/OpenAI API | MCP (server-side) |
| leejet/stable-diffusion.cpp | 7,747 | MIT | 2026-10-21 | C++ / HTTP | none first-party |

Diffusers is the same *class* of thing as Remotion and HyperFrames: a library you write
code against, that renders locally, with agent skills shipped in the repo. The node canvas
is the only thing ComfyUI has that it does not.

### Modular Diffusers — the declarative pipeline DSL

Officially documented at
[modular_diffusers/quickstart](https://huggingface.co/docs/diffusers/en/modular_diffusers/quickstart).
A pipeline is a graph of **blocks** you can inspect, re-order, swap, and extend in Python:

```py
import torch
from diffusers import ModularPipeline, ComponentsManager

manager = ComponentsManager()
manager.enable_auto_cpu_offload(device="cuda:0")

pipe = ModularPipeline.from_pretrained("Qwen/Qwen-Image", components_manager=manager)
pipe.load_components(dtype=torch.bfloat16)

image = pipe(prompt="a cat wizard, detailed, fantasy").images[0]
```

The structure is introspectable at runtime, which is what makes it composable:

```py
print(pipe.blocks)
# QwenImageAutoBlocks(
#   Class: SequentialPipelineBlocks
#   Supported workflows: text2image, image2image, inpainting, controlnet_text2image
#   Sub-Blocks: [text_encoder, vae_encoder, controlnet_vae_encoder, denoise, decode]
# )
```

And you can rewrite the graph — insert a block, change what the pipeline accepts as input:

```py
from diffusers.modular_pipelines import ModularPipelineBlocks

canny = ModularPipelineBlocks.from_pretrained(
    "diffusers-internal-dev/canny-filtering", trust_remote_code=True
)
blocks = pipe.blocks.get_workflow("controlnet_text2image")
blocks.sub_blocks.insert("canny", canny_block, 0)   # pipeline now takes `image`, not `control_image`
pipeline = blocks.init_pipeline("Qwen/Qwen-Image", components_manager=manager)
```

**Status: experimental** — the docs label Modular Diffusers "an experimental feature we are
actively developing". Treat the API as moving.

### Agent integration — the part that matters for this setup

The repo ships a `.ai/` directory:

```
.ai/
  AGENTS.md
  plugin.json
  .claude-plugin/     .codex-plugin/
  skills/
    custom-blocks/
    diffusers-cli/
    model-integration/
    self-review/
  references/
```

`diffusers-cli skills` installs those bundles as **Agent Skills**. The install target is
chosen from the env var the agent sets (`src/diffusers/commands/skills.py`):

| Env var | Install dir |
|---|---|
| `CLAUDECODE`, `CLAUDE_CODE` | `.claude/skills/` |
| `CODEX_SANDBOX`, `CURSOR_AI` | `.agents/skills/` |
| none set | both (`.claude/skills/` **and** `.agents/skills/`) |

`.agents/skills/` is the portable choice and is exactly where this machine's skills
already live (`~/.agents/skills/`), so `diffusers-cli skills` drops straight into the
existing skill tree.

The `diffusers-cli` skill documents the subcommands an agent should use rather than
writing ad-hoc Python: `run` (any `DiffusionPipeline` or `ModularPipeline`),
`schema` (print a pipeline's input schema **without downloading weights**),
`custom-blocks` (package a local block for the Hub), `env` (versions + GPU info).

Output format auto-selects: `--format {auto,human,agent,json}`, where `auto` picks
`agent` (TSV tables and `key=value` lines, token-cheap for LLMs) when an agent env var
is present, else `human`. `stdout` carries data, `stderr` carries hints.

**Note:** `OPENCODE` is not in diffusers' env-var table. Running with no agent env var
installs to *both* `.claude/skills/` and `.agents/skills/`, which covers OpenCode anyway —
or install the skills explicitly into `~/.agents/skills/`.

### The catch: Diffusers needs PyTorch, and PyTorch is the problem

Modular Diffusers is excellent, but it runs on PyTorch, and on this host PyTorch means
CPU (no ROCm for consumer gfx908, see §4). So:

- **Diffusers + Modular Diffusers** = the right *shape* — code-first, declarative,
  agent-driven, Apache-2.0, and it is where new models land first. On a bigger GPU, or
  via a rented one, this is the answer.
- **stable-diffusion.cpp / LocalAI** = the right *engine* for this box. Vulkan, MIT,
  GGUF, 15 GB-friendly.

They compose: `diffusers-cli` for authoring and inspection, `sd-server` or LocalAI for the
pixels on hardware that can actually run them.

**Diffusers does support GGUF directly**, which is what makes the 15 GB constraint
survivable. Per the [GGUF docs](https://huggingface.co/docs/diffusers/en/quantization/gguf):
`pip install -U gguf`, then load with `from_single_file` + `GGUFQuantizationConfig` —
the dequantisation code is city96's, the same person behind ComfyUI-GGUF, and the weights
stay in a low-memory `torch.uint8` dtype and are dequantized on the fly.

```py
from diffusers import FluxPipeline, FluxTransformer2DModel, GGUFQuantizationConfig

transformer = FluxTransformer2DModel.from_single_file(
    "https://huggingface.co/city96/FLUX.1-dev-gguf/blob/main/flux1-dev-Q2_K.gguf",
    quantization_config=GGUFQuantizationConfig(compute_dtype=torch.bfloat16),
)
pipe = FluxPipeline.from_pretrained("black-forest-labs/FLUX.1-dev", transformer=transformer)
```

One limitation to know: GGUF in Diffusers is a **model-level** loader only —
*"pipeline-level loading is not supported"* — so you load the transformer via
`from_single_file` and the rest of the pipeline normally.

### What ships in the pip package

`diffusers-cli` is a real console entry point (`setup.py`:
`entry_points={"console_scripts": ["diffusers-cli=diffusers.commands.diffusers_cli:main"]}`),
so `pip install diffusers` gives you `run`, `schema`, `custom-blocks`, `env` and `skills`.

The `examples/server` FastAPI app is **repo-only** — `MANIFEST.in` ships only `LICENSE` and
`model_card_template.md`, and `package_data` is just `py.typed`. So the OpenAI-shaped
`POST /v1/images/generations` endpoint has to come from a source checkout, not from PyPI.
For a service that OpenCode calls over HTTP, use LocalAI or `sd-server` instead.

### nixpkgs packaging

- `python3Packages.diffusers` — **0.38.0**, Apache-2.0, `mainProgram = "diffusers-cli"`.
  (Upstream is at 0.41+; nixpkgs lags, and `doCheck = false` because the test suite
  "takes a few hours". The `torch` extra is an optional dependency, so the base package
  is CPU-usable with `python3Packages.torch` added.)
- `python3Packages.torchWithVulkan` — `self.torch.override { vulkanSupport = true; }`.
  This is the nixpkgs route to a **Vulkan PyTorch**, which would sidestep the ROCm
  problem entirely — but see the caveat below.
- `pkgs.stable-diffusion-cpp` with `vulkanSupport = true` — the sd.cpp engine (§5).
- `pkgs.local-ai` — LocalAI, but `broken = true` (see §7).

**Caveat on `torchWithVulkan`:** PyTorch's Vulkan backend is upstream-experimental and
much less exercised than CUDA/ROCm — the ComfyUI discussion thread on a Vulkan backend is
still open, and ComfyUI upstream's `model_management.py` contains **zero** references to
`vulkan` (checked against master). So a `torchWithVulkan` ComfyUI is not a supported
configuration; `stable-diffusion.cpp`'s Vulkan backend is the mature one.

### LocalAI — the OpenAI-compatible server around sd.cpp

LocalAI (mudler/LocalAI, 49,829★, **MIT**, pushed 2026-10-21) wraps stable-diffusion.cpp
in a `stablediffusion-ggml` backend and serves it over an OpenAI-shaped API:
`POST /v1/images/generations`, `POST /v1/images/upscale`, plus the full text/audio/video
surface. It is a real, large, actively-maintained project — the same class as ComfyUI.

Its per-model YAML exposes exactly the three knobs that sd.cpp needs on an AMD APU:

```yaml
name: z-image-turbo
backend: stablediffusion-ggml
parameters:
  model: z_image_turbo-Q4_K.gguf
  step: 8
  cfg_scale: 1.0
options:
  - "backend:te=cpu,vae=vulkan0,diffusion=vulkan0"   # per-component compute backend
  - "params_backend:diffusion=disk"                     # mmap weights, dodge the GTT budget
  - "vae_tiling:true"                                   # tiled decode
  - "vae_tile_size:512"
```

The LocalAI docs call out the exact failure this prevents: *"Mesa RADV reports a 4 GiB
`maxMemoryAllocationSize`, so a large decode fails there even with tens of GB free"*.
That is a full-frame VAE decode on your Vega 7. `vae_tiling` is the fix.

**Two important caveats, both verified:**

1. **nixpkgs' `local-ai` is `broken = true`** (`pkgs/by-name/lo/local-ai/package.nix`:
   *"Doesn't build with >buildGo123Module. 'cp: cannot stat 'bin/rpc-server'"*). Using it
   from the flake needs `local-ai.override { broken = false; }` and a real build attempt.
2. **nixpkgs' `with_vulkan` only affects llama.cpp, not the image backend.** In that
   package, `with_vulkan` is passed to the `llama-cpp-grpc` override; the
   `stable-diffusion` derivation is built from `richiejp/stable-diffusion.cpp` (an MIT
   fork of leejet's) with no Vulkan cmake flag at all. So the nixpkgs `local-ai` cannot
   do Vulkan image generation as packaged. Upstream LocalAI's own build is where the
   Vulkan ggml backend lives.

**LocalAI's MCP is the wrong direction for this use.** It is *server-side* MCP: LocalAI's
own models call *your* MCP servers (`mcp.remote` / `mcp.stdio` in a model YAML). It does
not expose image generation as an MCP server for OpenCode to call. To drive LocalAI from
OpenCode you use its HTTP API, or a thin MCP wrapper.

**Its own `local-ai mcp-server` is admin-only.** Verified by grepping `pkg/mcp/`: 38 tools,
every one of them administrative — `install_model`, `install_backend`, `edit_model_config`,
`load_model`, `vram_estimate`, `list_backends`, `system_info`, and so on. `grep -rn
"images/generations" pkg/mcp/` returns **zero hits**. It is also **stdio-only**
(`mcp.StdioTransport{}`), so no `type: "remote"` entry is possible. Useful for managing
models; useless for generating images.

### nixpkgs' `local-ai` is a trap — three separate reasons

1. `broken = true` since 2025-08-21 (*"Doesn't build with >buildGo123Module"*).
2. It is **v2.28.0, ~18 months behind** current LocalAI (v4.11.0). `mcp-server` does not
   exist in v2.28.0's `core/cli/cli.go` at all.
3. **`with_vulkan` cannot enable Vulkan for the image backend.** The `BUILD_TYPE` derivation
   only ever yields `"openblas" | "cublas" | "clblas" | ""` — there is no `vulkan` branch.
   `with_vulkan` is wired only to the llama.cpp dependency. The SD backend is built from
   `richiejp/stable-diffusion.cpp` (a fork), not `leejet/stable-diffusion.cpp`, with no
   `SD_VULKAN` flag.

Upstream's mechanism is `BUILD_TYPE=vulkan` → `-DSD_VULKAN=ON -DGGML_VULKAN=ON` in
`backend/go/stablediffusion-ggml/Makefile`, and there are prebuilt images:
`localai/localai:latest-gpu-vulkan` (1.47 GB) and
`localai/localai-backends:latest-gpu-vulkan-stablediffusion-ggml`.

**Gallery models for the SD backend** — all from public, ungated HF repos, no token:

| Gallery entry | Licence | Commercial? | Size |
|---|---|---|---|
| **`flux.2-klein-4b`** | Apache-2.0 | **Yes** | 2,346 MB (Q4_0) + 2,382 MB (Qwen3-4B) + 321 MB (VAE) ≈ 5.0 GB |
| **`Z-Image-Turbo`** | Apache-2.0 | **Yes** | 3,685 MB (Q4_K) + ~2.3 GB + 335 MB ≈ 6.3 GB |
| `flux.1-dev-ggml` | FLUX non-commercial | No | 3,846 MB + fp16 T5 |
| `qwen-image-2.1-q4_k-ggml` | Qwen Research | No | 4,003 MB + 5.8 GB |
| `flux.3-image-klein` | Kommunity | gated | 3,235 MB + 2.4 GB |

**Two gallery bugs to know about**: `Z-Image-Turbo` declares `filename: z_image_turbo-Q4_0.gguf`
but its `uri` points at `z_image_turbo-Q4_K.gguf` (both exist; which the sha256 matches is
UNVERIFIED). And the shared `z-image-ggml.yaml` template sets `offload_params_to_cpu:true`
but **no `vae_tiling`**, so the RADV allocation cap is unmitigated out of the box.

### MCP servers over sd.cpp — for the OpenCode entry

| Project | Licence | Last push | Stars | Transport | Notes |
|---|---|---|---|---|---|
| `tobert/sdcpppal` | MIT | 2026-04-16 | 3 | stdio | `uv tool install .`. Tools: `generate_image` + capabilities/samplers/schedulers/loras. Talks to sd-server's native `/sdcpp/v1/*` job API |
| `skeeto/sdmcp` | Unlicense | 2026-07-06 | 1 | HTTP `/mcp` | One Go binary, one `generate_image` tool, fixed size |
| `zavora-ai/mcp-imagegen` | Apache-2.0 | 2026-09-27 | 1 | stdio | Best ergonomics (job queue, cancel, progress, memory-headroom check). Needs Rust ≥1.94.1. Default weights are Qwen Research = non-commercial; disable its bundled cloud backend |
| `CLOUDWERX-DEV/diffugen` | MIT | 2025-04-07 | 20 | stdio + OpenAPI | **18 months stale**, bundles its own sd.cpp |

None of them bundle their own Vulkan sd-server — all but diffugen need *your* `sd-server`
built with `-DSD_VULKAN=ON`, or the prebuilt Vulkan zip.

**OpenCode gotcha that will bite you:** the MCP `timeout` defaults to **5000 ms**, which
will abort every single image generation. Raise it — `timeout: 300000` for a 5-minute
budget, `900000` for the job-queue server.

```json
{
  "$schema": "https://opencode.ai/config.json",
  "mcp": {
    "imagegen": {
      "type": "local",
      "command": ["sdcpppal"],
      "environment": { "SDCPP_HOST": "http://localhost:1234" },
      "timeout": 300000
    }
  }
}
```

### The rendering half, if you ever want the real thing

The gap is joinable — every ingredient but the glue exists, free:

- **kane50613/takumi** (3,138★, Apache-2.0, Rust, pushed today) — the HyperFrames-shaped
  half for images: JSX/HTML/CSS → PNG/JPEG/WebP/SVG/PDF, **no headless browser**,
  deterministic, local, free. But no diffusion, no MCP, no agent surface.
- **VidGuiCode/assemblash** (4★, Apache-2.0) — local-first visual document engine, Rust,
  structured layered docs, deterministic bit-identical PNG, CLI + HTTP + MCP. Explicitly
  *"contains no AI model"*.
- **vercel/satori** (14,120★, MPL-2.0) — HTML/CSS → SVG, pure JS.
- **dkackman/diffusers-workflow** (18★, Apache-2.0) — the one project that is
  declarative-JSON-first on top of Diffusers: `variable:` / `previous_result:` / `asset:` /
  `output:` references, ~50 MCP tools, `validate_workflow` against real pipeline signatures,
  git-diffable recipes, per-run manifest, CPU/CUDA/MPS. Architecturally the closest thing
  to the answer — at 18 stars it fails the adoption bar by ~55×.

Nobody has written "declarative image composition document + local diffusion model + agent
skill" as one product. That is the actual gap.

## 8. Does a HyperFrames-equivalent for images exist? **No.**

An exhaustive sweep (framework-class ≥1k★, real licence, recent activity, real render
pipeline) found the ecosystem split into two halves that nobody has joined:

| Half | Projects | Missing |
|---|---|---|
| **Declarative local renderer** — code-first, deterministic, free, no AI | takumi (3.1k★, Apache-2.0, Rust), satori (14.1k★), assemblash, resvg | no diffusion, no agent surface |
| **Local diffusion engine** — AI, but prompt/graph-shaped | sd.cpp (7.7k★), LocalAI (49.8k★), diffusers (34.8k★), ComfyUI (141.3k★) | not template/composition-shaped |

Confirmed absences, each from a primary source:

- **HeyGen ships no image framework.** The `heygen-com` org has 34 repos; `hyperframes` is
  the only framework. HyperFrames' own docs punt: *"Code-drawn HTML, CSS, and SVG excel
  where the medium is native… Illustration-led hero art is the exception… The hybrid:
  generate the art, animate it with code"* — image generation is an *input asset*, resolved
  by `media-use` to cloud assets or local FLUX via **mflux**, which is Apple MLX only.
- **Remotion has no local image pipeline.** Its AI story is `remotion-media` → KIE.ai and
  Replicate — both paid cloud APIs. No local model, no `render --image` analogue.
- **Every agent-first image tool that actually works routes to a paid cloud**: Scenario
  Labs' skills (KIE/Replicate), `shinpr/mcp-image` (hosted Gemini),
  `OpenMontage` (fal.ai/Veo/Kling), `mcp-image` wrappers, and ComfyUI's in-app agent
  (spends Comfy Credits).
- The nearest research artefact, `wuhaer/PosterVerse` (AAAI 2026 Oral — HTML-based
  typography poster diffusion, code + weights + dataset released), is 78★, **CC BY-NC-ND
  4.0** (non-commercial, no derivatives), and needs a CUDA GPU for its FLUX.1-dev stage.

## 9. The stack to actually build

Nothing here needs a paid service, and every layer is permissively licensed:

| Layer | Choice | Licence |
|---|---|---|
| Agent surface | `diffusers-cli skills` → your existing `~/.agents/skills` tree | Apache-2.0 |
| Authoring / pipeline | Diffusers + Modular Diffusers (code-first, declarative blocks) | Apache-2.0 |
| Inference engine | stable-diffusion.cpp with `SD_VULKAN=ON` (Mesa RADV) | MIT |
| HTTP serving | `sd-server` (native + OpenAI-compatible) or LocalAI | MIT |
| MCP for OpenCode | `tobert/sdcpppal` (stdio) or `skeeto/sdmcp` (HTTP) | MIT / Unlicense |
| Weights | **FLUX.2-klein-4B** (5.0 GB) or **Z-Image-Turbo** (6.3 GB) | **Apache-2.0** |

The engine is the part that differs from ComfyUI: **no torch, no ROCm, no CUDA, no node
canvas** — just a GGUF file, a Vulkan backend, and an HTTP surface. And if you ever want
the *authoring* half to be declarative, Diffusers' Modular Diffusers gives you a graph you
can inspect and rewrite in Python, with the same agent skills shipped in-repo.

## 10. What each medium actually gets you — and what it doesn't

Your HyperFrames is a **timeline renderer**: you declare time, it owns frame N, output is
MP4. That is a genuinely different shape from diffusion, and it is worth being clear about
which of your use cases HyperFrames already covers versus which need a model.

| What you want | Already solved? | Tool |
|---|---|---|
| **Video editing / motion graphics / titles / captions** | ✅ **yes** | HyperFrames (HTML/CSS → MP4). Already installed, 17 skills |
| **Thumbnail / still image** | ⚠️ gap | sd.cpp + FLUX.2-klein-4B (Apache-2.0) |
| **Photo editing / inpaint / retouch** | ⚠️ gap | sd.cpp img2img + mask, or InvokeAI/ComfyUI canvas |
| **2D animation (image → video)** | ⚠️ gap | Wan2.2 / LTX-2.5 — but CUDA-class models |
| **3D model from an image** | ⚠️ gap | **LocalAI TRELLIS.2** (`trellis2cpp`, MIT, ggml → Vulkan) — static mesh, not animated |
| **3D animation / text-to-motion** | ⚠️ gap | **LocalAI kimodo.cpp** (Apache-2.0, CPU **or** Vulkan) |
| **Talking avatar / lip-sync** | ⚠️ demo only | `talking-portrait.cpp` (MIT, CPU+Vulkan) — 512px, 25 fps, low quality. No serious local option |

**LocalAI turned out to cover far more than I expected**, and it is the single best answer
for the 3D half of your question. From its own docs (MIT, 49.8k★):

- **3D model generation** — `POST /3d/generations`, backed by `trellis2cpp` (localai-org,
  **MIT**), a C++/GGML port of Microsoft's **TRELLIS.2** (also **MIT**). Image-conditioned
  → textured glTF `.glb` with PBR materials. The ggml port means **CUDA / Metal / Vulkan**
  backends, so your Vega 7 is a real target.
  - Gallery `trellis2-4b` = full pipeline, ~18 GB of f16 GGUFs, and the 1024³ textured path
    wants ~10 GB VRAM — **too big for you**.
  - Gallery `trellis2-4b-geometry` = 512³ untextured only, ~7 GB. **This is your one.**
  - Actual file sizes (HF API): `ss_flow_f16.gguf` 2,494 MB, `slat_flow_f16.gguf` 2,494 MB,
    `shape_dec_f16.gguf` 905 MB, `shape_enc_f16.gguf` 676 MB, `ss_dec_f16.gguf` 141 MB.
    Geometry-only needs the shape + flow set, not the texture set.
  - `POST /3d/remesh` then makes it **watertight and printable** via CGAL Alpha Wrap —
    that is the 3D-printing path, and it is unusual to get for free.
  - 512³ takes ~2 min on a modern GPU. On your APU: **UNVERIFIED**.
- **3D animation / text-to-motion** — `POST /3d/animate`, backed by `kimodo.cpp`
  (localai-org, **Apache-2.0**). *"text-to-motion with kimodo.cpp on CPU or Vulkan"*. Exports an
  animated skeleton GLB (joint rotations + root motion, no mesh/skin). SOMA = 30 joints,
  G1 = 34. 60–150 frames at 30 FPS, 100 steps, guidance 2.
  - **Licence caveat**: the gallery says *"Motion and text weights retain their respective
    NVIDIA Open Model License and Llama 3 terms"* — the **code** is MIT, the **weights**
    are not permissive. Different from the image case.
  - Memory: BF16 text weights are ~14.1 GiB, so use the **Q8_0** encoder and drop
    `text_layer_chunk` from its default 32 to 8 on your 15 GB box.
- **Video generation** — `POST /video`. But: `mlx-video` is Apple-only, and
  `longcat-video` / `longcat-video-avatar-1.5` are explicitly *"a large, CUDA-only model
  family… CPU, ROCm, and macOS images are not available"*. MiniMax-H3 via `vllm-cpp` is
  ~40 GB and *"about 176 seconds per denoise step… a multi-hour request"*.
  **So: local video generation is not viable on this box.** That is exactly the hole
  HyperFrames fills — and it fills it well, because HyperFrames renders on CPU Chromium
  and doesn't need a diffusion model at all.

### The talking-avatar problem

`heygen-com/LiveAvatar` **does not exist as a repo** — verified 404. It is HeyGen's
commercial cloud API; the org ships an SDK, demos and agent skills for it, but no weights.

The academic `Alibaba-Quark/LiveAvatar` (Apache-2.0, 2,489★) needs 5×H800s. The open
alternatives are all CUDA: MuseTalk (MIT, 6,767★) needs a V100-class card, LatentSync
(Apache-2.0) needs 8 GB VRAM, LivePortrait (MIT, 19,280★) is CUDA, Wav2Lip has no licence
file and is research-only.

**There is exactly one local talking-avatar path:**
`localai-org/talking-portrait.cpp` (MIT, 12★) — a C++/GGML port of FLOAT with a
**`vulkan` preset**: 512×512 portrait + 16 kHz audio → 25 fps MP4. Low VRAM, low quality.
Treat it as a demo, not a product.

### The real 3D/3D-animation answer is bigger than one backend

LocalAI has ported **seven** PyTorch 3D/motion models to C++/GGML, all with CPU **and**
Vulkan presets, all pushed 2026-10-19:

| Backend | Repo | Licence | Stars | Does |
|---|---|---|---|---|
| `kimodocpp` | `localai-org/kimodo.cpp` | Apache-2.0 | 925 | text → motion, skeleton GLB (`POST /3d/animate`) |
| `motion-bricks.cpp` | `localai-org/motion-bricks.cpp` | Apache-2.0 | 310 | NVIDIA MotionBricks ported to GGML |
| `skin-tokens.cpp` | `localai-org/skin-tokens.cpp` | Apache-2.0 | 229 | auto skeleton + skin weights → **rigged** GLB |
| `animate-any-mesh.cpp` | `localai-org/animate-any-mesh.cpp` | Apache-2.0 | 12 | text → animated morph-target GLB |
| `gem-x.cpp` | `localai-org/gem-x.cpp` | Apache-2.0 | 58 | SOMA + SMPL pose streams (live mocap) |
| `free-splatter.cpp` | `localai-org/free-splatter.cpp` | Apache-2.0 | 42 | image → 3D scene |
| `trellis2cpp` | `localai-org/trellis2cpp` | MIT | 23 | image → textured mesh (`POST /3d/generations`) |

**Correction to my earlier note:** TRELLIS.2 does **not** output animation — it is
image-to-3D only, and the "video" it produces is a turntable render of a static mesh.
Motion comes from the separate kimodo/motion-bricks/skin-tokens family.

### Photo editing — Kokon is the pick, and it has a real MCP

`GabrieleLozupone/kokon` (AGPL-3.0, 180★, pushed 2026-10-20) is the one photo-editing
tool that is both local *and* agent-drivable on AMD: Qwen-Image 2.1 via stable-diffusion.cpp
with a **Vulkan build on AMD (beta)**, and it ships **both** an MCP stdio server
(`kokon-mcp`) and a local HTTP API (`http://127.0.0.1:39151/api/v1`). Tools:
`generate_image`, `edit_image`, `edit_images`, `inpaint_image`, `outpaint_image`,
`upscale_image`, `get_image_info`, `get_generator_status`.

It needs ~12 GB shared VRAM for the Qwen-Image 2.1 Turbo Q4_K preset plus 16 GB system
RAM — tight on 15 GB, and it will be slow. `scumble` (GPL-3.0, 144★) is the good second
choice if you want a layered GUI over a ComfyUI backend. GFPGAN (Apache-2.0, 37.7k★) is
the only thing that will retouch a face quickly on CPU.

### The 3D-animation surface you actually want: Blender + MCP

`ahujasid/mcp-for-blender` (MIT, **31,875★**, pushed 2026-10-20) drives Blender over
MCP — and Blender is CPU/Vulkan, so it works on your box. That is how you turn the raw
GLB assets from TRELLIS.2 and the motion from kimodo into a rigged, lit, animated scene.
Alternatives: `LiCinCan/blender-ai-mcp-addon` (MIT, 966★),
`HoldMyBeer-gg/blenderwright` (MIT, 175★, 191 tools),
`seehiong/blender-mcp-bridge` (MIT, 79★, 93 tools).

### 2D animation: no local answer, and that is fine

Every mainstream video model is CUDA: FramePack 6 GB → Wan2.2 → HunyuanVideo 45–60 GB →
Mochi ~60 GB. LocalAI's `/video` has **no CPU or Vulkan backend** — `longcat-video` is
NVIDIA-only, `mlx-video` is Metal-only. Render 2D animation as vector/compositing
(HyperFrames) rather than as a diffusion video model.

## 11. Other local options, ranked

1. **stable-diffusion.cpp + `sd-server`** — only stack that is free, local, scriptable *and*
   accelerated on this AMD box. Gap: no first-party MCP. The OpenAI-compatible endpoint is
   a ~100-line MCP server; the community wrappers (`tobert/sdcpppal`, `skeeto/sdmcp`,
   `zavora-ai/mcp-imagegen`) are 1–3★ hobby projects, so writing a small one is cheaper.
2. **Diffusers + Modular Diffusers + `diffusers-cli`** — the most genuinely code-first
   (declarative pipeline-block DSL), Apache-2.0, ships a `.ai/` directory with
   AGENTS.md + skills for LLM consumption, and a FastAPI server with an
   OpenAI-shaped endpoint. Trade-off: PyTorch, so AMD here means CPU.
3. **ComfyUI (headless) + `comfy-cli` + `comfy-mcp` + `ComfyScript`** — best MCP story and
   the only semi-portable workflow artifact (ComfyUI API-format JSON), but the node canvas
   is still the interface, ComfyUI is GPL-3.0, the official MCP is AGPL-or-commercial, and
   the AMD path is ROCm-only.
4. **z-image-studio** (Apache-2.0, active) — CLI + web UI + MCP in one small package,
   diffusers-backed, ROCm-aware. Least friction turnkey option; single model family
   (Z-Image-Turbo) is the limitation.

Not local — do not mistake for local: `shinpr/mcp-image` (hosted Gemini),
`ShalomObongo/codex-imagegen-mcp` (borrows a paid ChatGPT plan), Comfy Cloud MCP,
`comfy-skills`, and the ComfyUI in-app agent (spends Comfy Credits).

### The runners-up, and why they lose here

**SD.Next** (vladmandic/sdnext, Apache-2.0, 7.4k★) — A1111-fork, big feature set, and it
is the only ComfyUI-alternative with a genuinely broad platform matrix. But its README
lists the hardware paths as: CUDA, **ROCm**, ZLUDA (AMD on Windows), OneAPI XPU, OpenVINO,
Apple MPS. **No Vulkan path.** ZLUDA is a ROCm wrapper, so it does not dodge the
gfx908 driver gap either. It also stays a node-graph UI.

**InvokeAI** (invoke-ai/InvokeAI, Apache-2.0, 28.8k★) — Commercially-friendly licence,
excellent Unified Canvas, and the model list is current (FLUX.2 Klein 4B, Z-Image Turbo,
FLUX.1 Krea, Qwen Image, Wan API). But it is explicitly **node-based** ("Node-Based
Architecture"), it has **no generation CLI** (only `invokeai-web`), **no in-repo MCP**, and
its own docs say Comfy workflows cannot be imported directly. It also inherits the PyTorch
problem: ROCm on Linux only.

**SwarmUI** (mcmonkeyprojects/SwarmUI, MIT, 4.7k★) — a *wrapper* around ComfyUI or A1111,
not an engine. It has a good external API and can consume ComfyUI API-format JSON, but you
are still running ComfyUI underneath.

**Fooocus** (lllyasviel/Fooocus, GPL-3.0, 53.6k★) — its README says *"Limited Long-Term
Support (LTS) with Bug Fixes Only… no current plans to migrate to or incorporate newer model
architectures"*, last push 2025-12-01. No API, no CLI, no MCP. Dated.

**Krita AI Diffusion** (Acly/krita-ai-diffusion, GPL-3.0, 10.8k★) — a Krita plugin, and
also a ComfyUI wrapper. Excellent for artists; not a service.

None of these are wrong answers in general. They lose *here* because they are either
node canvases, or PyTorch-on-AMD stacks, and this box is a consumer APU with no ROCm.

## 12. Workflow-format interoperability — the honest answer

No hosted-agnostic standard exists.

- **ComfyUI API-format JSON** is the closest to a portable spec: numeric node ids,
  `class_type`, `inputs`, no layout. Consumed by SwarmUI, Krita AI Diffusion,
  `comfy-cli run --workflow`, and `comfy-mcp run_workflow`.
- **InvokeAI's graph format** (`nodes` with `type` + `edges`) is separate and incompatible;
  InvokeAI's docs state Comfy workflows cannot be imported directly.
- **PNG/JPEG embedded metadata** is the only truly cross-tool carrier, but it reproduces a
  generation rather than replaying a graph.
- Modular Diffusers is declarative in Python but serialises as Python objects.

## 13. Sources

ComfyUI docs: [index](https://docs.comfy.org/) · [agent tools](https://docs.comfy.org/agent-tools) ·
[MCP](https://docs.comfy.org/agent-tools/mcp) · [CLI](https://docs.comfy.org/agent-tools/cli) ·
[system requirements](https://docs.comfy.org/installation/system_requirements) ·
[manual install](https://docs.comfy.org/installation/manual_install) · [run workflows](https://docs.comfy.org/development/run-workflows/overview)
Repos: [ComfyUI](https://github.com/Comfy-Org/ComfyUI) · [comfy-cli](https://github.com/Comfy-Org/comfy-cli) ·
[comfy-mcp](https://github.com/Comfy-Org/comfy-mcp) · [comfy-skills](https://github.com/Comfy-Org/comfy-skills) ·
[ComfyScript](https://github.com/Chaoses-Ib/ComfyScript) · [stable-diffusion.cpp](https://github.com/leejet/stable-diffusion.cpp) ·
[diffusers](https://github.com/huggingface/diffusers) · [InvokeAI](https://github.com/invoke-ai/InvokeAI) ·
[SD.Next](https://github.com/vladmandic/sdnext) · [SwarmUI](https://github.com/mcmonkeyprojects/SwarmUI) ·
[comfyui-nix](https://github.com/utensils/comfyui-nix) · [z-image-studio](https://github.com/iconben/z-image-studio)
AMD: [ROCm system requirements](https://rocm.docs.amd.com/projects/install-on-linux/en/docs-7.2.2/reference/system-requirements.html) ·
[TheRock SUPPORTED_GPUS](https://raw.githubusercontent.com/ROCm/TheRock/main/SUPPORTED_GPUS.md) ·
[TheRock RELEASES (gfx target table)](https://raw.githubusercontent.com/ROCm/TheRock/main/RELEASES.md)
NixOS: [26.11 schedule](https://github.com/NixOS/nixpkgs/issues/567567) ·
[26.11 release notes](https://nixos.org/manual/nixpkgs/unstable/release-notes) ·
[nixpkgs comfyui package](https://raw.githubusercontent.com/NixOS/nixpkgs/master/pkgs/by-name/co/comfyui/package.nix) ·
[nixpkgs services.comfyui](https://raw.githubusercontent.com/NixOS/nixpkgs/master/nixos/modules/services/misc/comfyui.nix) ·
[nixpkgs stable-diffusion-cpp](https://raw.githubusercontent.com/NixOS/nixpkgs/master/pkgs/by-name/st/stable-diffusion-cpp/package.nix) ·
[nixpkgs rocm clr targets](https://raw.githubusercontent.com/NixOS/nixpkgs/master/pkgs/development/rocm-modules/clr/default.nix) ·
[nixpkgs spirv-headers](https://raw.githubusercontent.com/NixOS/nixpkgs/master/pkgs/by-name/sp/spirv-headers/package.nix) ·
[nixpkgs spirv-tools](https://raw.githubusercontent.com/NixOS/nixpkgs/master/pkgs/by-name/sp/spirv-tools/package.nix)
Diffusers: [repo](https://github.com/huggingface/diffusers) · [Modular Diffusers quickstart](https://huggingface.co/docs/diffusers/en/modular_diffusers/quickstart) ·
[ModularPipelineBlocks](https://huggingface.co/docs/diffusers/en/modular_diffusers/pipeline_block) ·
[SequentialPipelineBlocks](https://huggingface.co/docs/diffusers/en/modular_diffusers/sequential_pipeline_blocks) ·
[AutoPipelineBlocks](https://huggingface.co/docs/diffusers/en/modular_diffusers/auto_pipeline_blocks) ·
[end-to-end guide](https://huggingface.co/docs/diffusers/main/en/modular_diffusers/end_to_end_guide) ·
[`.ai/` skills on GitHub](https://github.com/huggingface/diffusers/tree/main/.ai) ·
[`diffusers-cli` skill](https://github.com/huggingface/diffusers/blob/main/.ai/skills/diffusers-cli/SKILL.md)
LocalAI: [repo](https://github.com/mudler/LocalAI) · [image generation docs](https://localai.io/docs/features/image-generation/) ·
[MCP docs](https://localai.io/docs/features/mcp/) · [nixpkgs local-ai](https://raw.githubusercontent.com/NixOS/nixpkgs/master/pkgs/by-name/lo/local-ai/package.nix)
Models: [FLUX.3 Image Klein](https://huggingface.co/black-forest-labs/flux-3-image-klein) ·
[MOSS-Image](https://huggingface.co/OpenMOSS-Team/MOSS-Image-SFT) ·
[FLUX.2 klein-4B](https://huggingface.co/black-forest-labs/FLUX.2-klein-4B) ·
[Z-Image-Turbo](https://huggingface.co/Tongyi-MAI/Z-Image-Turbo) ·
[Wan2.2](https://github.com/Wan-Video/Wan2.2) ·
[workflow_templates](https://github.com/Comfy-Org/workflow_templates) ·
[leejet GGUF repo](https://huggingface.co/leejet) ·
[unsloth GGUF repo](https://huggingface.co/unsloth)
