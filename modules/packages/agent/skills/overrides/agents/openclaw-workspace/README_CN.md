# openclaw-workspace

OpenCode v2 工作区管理：`AGENTS.md`、`opencode.json`、agents、commands、
plugins、skills，以及 NeuraKeep 记忆库。

技能 ID 保留为 `openclaw-workspace`（兼容已有安装），内容面向 Linux 上的
OpenCode v2。

## 工作区位置

| 用途 | 路径 |
|---|---|
| 指令文件 | `~/.config/opencode/AGENTS.md`、项目根目录 `AGENTS.md` |
| 配置 | `~/.config/opencode/opencode.json`、项目 `opencode.json` |
| Agents | `~/.config/opencode/agents/*.md` |
| Commands | `~/.config/opencode/commands/*.md` |
| Plugins | `~/.config/opencode/plugins/*.js` |
| Skills | `~/.config/opencode/skills/`、`~/.agents/skills/` |
| 会话数据库 | `~/.local/share/opencode/opencode.db` |
| 持久记忆 | `~/.local/share/neurakeep/vault` |

## 本技能做什么

1. **审计**指令文件的体积、重复、矛盾、密钥和失效路径。
2. **搭建**全新工作区：配置、`AGENTS.md`、agents。
3. **提炼**记忆：把该常驻上下文的内容放进 `AGENTS.md`，其余留在记忆库。
4. **交叉检查**出现在多个文件里的规则、路径和命令。

## 文件

- `SKILL.md` — 技能正文。
- `references/workspace-files.md` — 各工作区表面详解。
- `references/optimization-guide.md` — 上下文预算、审计、精炼。
