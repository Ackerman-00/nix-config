import { existsSync } from "node:fs"
import { homedir } from "node:os"
import { join } from "node:path"

// Points the HyperFrames CLI at the local Kokoro venv so `hyperframes tts`
// finds kokoro-onnx. The system python has no kokoro-onnx, and opencode's
// config schema has no env map, so the export has to happen in-process.
const VENV_PYTHON = join(
  homedir(),
  ".local",
  "share",
  "hyperframes",
  "kokoro-venv",
  "bin",
  "python",
)

export default {
  id: "local-media-env",
  setup: async () => {
    if (process.env.HYPERFRAMES_PYTHON) return
    if (!existsSync(VENV_PYTHON)) return
    process.env.HYPERFRAMES_PYTHON = VENV_PYTHON
  },
}
