#!/usr/bin/env python3
"""Concat MCP bridge.

Concat (https://github.com/jub0t/Concat) ships a JSON-RPC 2.0 API over a
loopback socket (127.0.0.1:7420) but no MCP server yet -- upstream is
building one on the Rust `rmcp` SDK (see docs/transports/mcp.md in the
source tree). Until it ships, this is the documented bridge: a stdio MCP
server that turns tool calls into JSON-RPC method calls.

Token resolution, first match wins:
  1. CONCAT_API_TOKEN environment variable
  2. Concat's own settings: $XDG_CONFIG_HOME/app.concat.editor/settings.json
     -> server.token, when non-empty (pin a token in the Concat window's
     Settings > Remote page; a token the window mints itself rotates every
     launch)
  3. ~/.config/concat-mcp/token (plain text, trailing newline OK)

The connection to Concat is made lazily on the first tool call and is
fully synchronous -- no background threads, no output on stdout/stderr.
Stdout carries only the MCP protocol.
"""

import itertools
import json
import os
import socket
import sys
import time
from pathlib import Path

DEFAULT_HOST = "127.0.0.1"
DEFAULT_PORT = 7420
CONNECT_TIMEOUT = 10
CALL_TIMEOUT = 30
JOB_TIMEOUT = 6 * 3600

JOB_ENDS = frozenset({"export.done", "export.failed", "cutout.failed"})


class ApiError(Exception):
    """A JSON-RPC error reply. message is the sentence the window shows."""

    def __init__(self, error):
        data = error.get("data") or {}
        self.code = data.get("code", "unknown")
        super().__init__(f"{self.code}: {error.get('message', 'no message')}")


def resolve_token():
    """Return (token, source) or (None, None)."""
    token = (os.environ.get("CONCAT_API_TOKEN") or "").strip()
    if token:
        return token, "CONCAT_API_TOKEN"

    xdg = os.environ.get("XDG_CONFIG_HOME", str(Path.home() / ".config"))
    prefs = Path(xdg) / "app.concat.editor" / "settings.json"
    try:
        pinned = (
            json.loads(prefs.read_text(encoding="utf-8"))
            .get("server", {})
            .get("token", "")
            .strip()
        )
    except Exception:
        pinned = ""
    if pinned:
        return pinned, str(prefs)

    local = Path.home() / ".config" / "concat-mcp" / "token"
    try:
        token = local.read_text(encoding="utf-8").strip()
    except Exception:
        token = ""
    if token:
        return token, str(local)

    return None, None


class Concat:
    """Synchronous JSON-RPC client over the loopback socket.

    One request at a time; notification lines (job events) are skipped
    while waiting for the matching response. The socket is opened lazily
    on the first call and kept for the process lifetime.
    """

    def __init__(self, host=DEFAULT_HOST, port=DEFAULT_PORT, token=""):
        self.host = host
        self.port = int(port)
        self.token = token
        self._ids = itertools.count(1)
        self._sock = None
        self._reader = None

    def _connect(self):
        self._sock = socket.create_connection(
            (self.host, self.port), timeout=CONNECT_TIMEOUT
        )
        self._send_raw(
            {"jsonrpc": "2.0", "id": 0, "method": "auth",
             "params": {"token": self.token}}
        )
        deadline = time.monotonic() + CONNECT_TIMEOUT
        while time.monotonic() < deadline:
            line = self._recv_line()
            if line is None:
                raise ConnectionError("no auth reply from the Concat server")
            try:
                msg = json.loads(line)
            except ValueError:
                continue
            if msg.get("id") == 0:
                if "error" in msg:
                    raise ConnectionError(
                        f"auth failed: {msg['error'].get('message', 'unauthorized')}"
                    )
                self._reader = self._sock.makefile("r", encoding="utf-8")
                return
        raise ConnectionError("auth handshake timed out")

    def call(self, method, **params):
        """One method call; returns the reply's result. Raises ApiError."""
        if self._sock is None:
            self._connect()
        rid = next(self._ids)
        self._send(
            {"jsonrpc": "2.0", "id": rid, "method": method, "params": params}
        )
        deadline = time.monotonic() + CALL_TIMEOUT
        while time.monotonic() < deadline:
            line = self._recv_line()
            if line is None:
                raise ConnectionError("connection to Concat closed")
            try:
                msg = json.loads(line)
            except ValueError:
                continue
            if msg.get("id") == rid:
                if "error" in msg:
                    raise ApiError(msg["error"])
                return msg.get("result", {})
            # a notification/event for another job: skip it
        raise TimeoutError(f"{method}: no reply in {CALL_TIMEOUT}s")

    def wait_for_job(self, job, timeout=JOB_TIMEOUT):
        """Block until an end event for `job`; returns the event message."""
        deadline = time.monotonic() + timeout
        while time.monotonic() < deadline:
            line = self._recv_line()
            if line is None:
                raise ConnectionError("connection to Concat closed")
            try:
                msg = json.loads(line)
            except ValueError:
                continue
            params = msg.get("params") or {}
            if params.get("job") == job and msg.get("method") in JOB_ENDS:
                return msg
        raise TimeoutError(f"job {job}: no end event in {timeout}s")

    def close(self):
        if self._sock is not None:
            try:
                self._sock.close()
            except OSError:
                pass
            self._sock = None
            self._reader = None

    def _send(self, obj):
        self._sock.sendall((json.dumps(obj) + "\n").encode("utf-8"))

    def _send_raw(self, obj):
        self._sock.sendall((json.dumps(obj) + "\n").encode("utf-8"))

    def _recv_line(self):
        buf = b""
        while not buf.endswith(b"\n"):
            chunk = self._sock.recv(4096)
            if not chunk:
                return None
            buf += chunk
        return buf.decode("utf-8").strip()


# ---- MCP tools ----

def build_server(api):
    from mcp.server.fastmcp import FastMCP
    from mcp.types import ImageContent

    mcp = FastMCP(
        "concat",
        instructions=(
            "Concat video editor control. Workflow: version -> "
            "project.open/project.create -> media.import -> edit.apply "
            "(command union, see docs/api/edits.md) -> export.run. "
            "Projects are folder paths; every call needs the project path. "
            "edit.apply takes {\"op\": ...} commands; prefer {\"op\": "
            "\"batch\", \"commands\": [...]} for multi-step edits. Read "
            "replies for created ids -- never guess them."
        ),
    )

    @mcp.tool()
    def version() -> dict:
        """What this Concat build serves: apiVersion, capabilities, dirs."""
        return api.call("version")

    @mcp.tool()
    def project_create(location: str, name: str) -> dict:
        """Create a project folder under `location` and open it. Returns the editor view."""
        return api.call("project.create", location=location, name=name)

    @mcp.tool()
    def project_open(path: str) -> dict:
        """Open a project folder. Returns the editor view."""
        return api.call("project.open", path=path)

    @mcp.tool()
    def project_get(path: str) -> dict:
        """Get the current editor view of an open project: clips, tracks, playhead."""
        return api.call("project.get", path=path)

    @mcp.tool()
    def project_list(location: str) -> list:
        """List recent projects under `location`."""
        return api.call("project.list", location=location)

    @mcp.tool()
    def project_save(path: str) -> dict:
        """Save the project. Save before close, or pass save on close."""
        return api.call("project.save", path=path)

    @mcp.tool()
    def project_close(path: str) -> dict:
        """Close the project. Pass save=True to save on the way out."""
        return api.call("project.close", path=path)

    @mcp.tool()
    def media_import(path: str, file: str) -> dict:
        """Probe a file and add it to the project's bin. createdId is the new media id."""
        return api.call("media.import", path=path, file=file)

    @mcp.tool()
    def edit_apply(path: str, command: dict) -> dict:
        """Apply one edit command ({"op": ...}) or a batch. Returns the editor view after the edit."""
        return api.call("edit.apply", path=path, command=command)

    @mcp.tool()
    def edit_undo(path: str) -> dict:
        """Step the project's history back one edit."""
        return api.call("edit.undo", path=path)

    @mcp.tool()
    def edit_redo(path: str) -> dict:
        """Step the project's history forward one edit."""
        return api.call("edit.redo", path=path)

    @mcp.tool()
    def catalogue_list(kind: str | None = None) -> list:
        """List effect packages and their parameters. kind filters (e.g. "filter")."""
        params = {"kind": kind} if kind else {}
        return api.call("catalogue.list", **params)

    @mcp.tool()
    def export_run(
        path: str,
        output: str,
        crf: int | None = None,
        preset: str | None = None,
        width: int | None = None,
        height: int | None = None,
        codec: str | None = None,
        ten_bit: bool | None = None,
        color_range: str | None = None,
    ) -> dict:
        """Render the timeline to a file and WAIT for the export to finish. One export at a time."""
        params = {"path": path, "output": output}
        if crf is not None:
            params["crf"] = crf
        if preset is not None:
            params["preset"] = preset
        if width is not None:
            params["width"] = width
        if height is not None:
            params["height"] = height
        if codec is not None:
            params["codec"] = codec
        if ten_bit is not None:
            params["tenBit"] = ten_bit
        if color_range is not None:
            params["colorRange"] = color_range
        started = api.call("export.run", **params)
        event = api.wait_for_job(started["job"])
        params = event.get("params", {})
        if event.get("method", "").endswith("failed"):
            raise ApiError({"message": params.get("error", {}).get("message",
                          "export failed"), "data": {"code": "failed"}})
        return params

    @mcp.tool()
    def export_cancel(job: str) -> dict:
        """Stop a running export at its next frame."""
        return api.call("export.cancel", job=job)

    @mcp.tool()
    def preview_frame(path: str, time: float, width: int | None = None,
                      height: int | None = None) -> ImageContent:
        """Composite the true frame at `time` (seconds), titles and effects included, as a PNG image."""
        params = {"path": path, "time": time}
        if width is not None:
            params["width"] = width
        if height is not None:
            params["height"] = height
        picture = api.call("preview.frame", **params)
        png = picture.get("png")
        if not png:
            raise ApiError({"message": "preview.frame returned no picture",
                            "data": {"code": "failed"}})
        return ImageContent(type="image", data=png, mimeType="image/png")

    return mcp


def main():
    token, _source = resolve_token()
    if not token:
        sys.exit(1)
    port = int(os.environ.get("CONCAT_PORT", DEFAULT_PORT))
    api = Concat(host=DEFAULT_HOST, port=port, token=token)
    server = build_server(api)
    try:
        server.run()
    except KeyboardInterrupt:
        pass
    finally:
        api.close()


if __name__ == "__main__":
    main()
