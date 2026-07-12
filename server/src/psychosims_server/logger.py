"""Cross-stack logger for the Python server.

Emits the canonical log-line schema defined in ``docs/code/LOGGING.md``.
Mode (text vs JSON) and minimum level are read from the config authority at
import time; in tests they default to text/info.
"""

from __future__ import annotations

import json
import os
import sys
from datetime import datetime, timezone
from enum import Enum
from typing import Any, Mapping


class Level(str, Enum):
    DEBUG = "debug"
    INFO = "info"
    SUCCESS = "success"
    WARN = "warn"
    ERROR = "error"
    FATAL = "fatal"


_LEVEL_EMOJI = {
    Level.DEBUG: "🔍",
    Level.INFO: "ℹ️",
    Level.SUCCESS: "✅",
    Level.WARN: "⚠️",
    Level.ERROR: "❌",
    Level.FATAL: "🛑",
}


class ErrorKind(str, Enum):
    USER = "user"
    SYSTEM = "system"
    EXTERNAL = "external"
    OFFLINE = "offline"


class PsyLogger:
    """Structured logger that matches the Dart/C++ logger output exactly."""

    def __init__(
        self,
        min_level: Level = Level.INFO,
        json_mode: bool = False,
        correlation_id: str = "none",
    ) -> None:
        self.min_level = min_level
        self.json_mode = json_mode
        self.correlation_id = correlation_id

    def _emit(self, line: str) -> None:
        sys.stderr.write(line + "\n")

    def _level_index(self, level: Level) -> int:
        return list(Level).index(level)

    def log(
        self,
        level: Level,
        scope: str,
        event: str,
        kv: Mapping[str, Any] | None = None,
        error_kind: ErrorKind | None = None,
        message: str | None = None,
    ) -> None:
        if self._level_index(level) < self._level_index(self.min_level):
            return

        ts = datetime.now(timezone.utc).isoformat()
        safe_scope = scope.lower()
        safe_event = event.lower()

        if self.json_mode:
            payload: dict[str, Any] = {
                "ts": ts,
                "level": level.value,
                "scope": safe_scope,
                "event": safe_event,
                "correlation_id": self.correlation_id,
            }
            if kv:
                payload["kv"] = dict(kv)
            if error_kind:
                payload["error_kind"] = error_kind.value
            self._emit(json.dumps(payload, separators=(",", ":"), sort_keys=True))
        else:
            parts = [
                f"{_LEVEL_EMOJI[level]} {level.value.upper():7} "
                f"[{ts}] [{safe_scope}] {safe_event:24}",
                f"corr={self.correlation_id}",
            ]
            if kv:
                parts.append("| " + " ".join(f"{k}={v}" for k, v in kv.items()))
            if error_kind:
                parts.append(f"| error_kind={error_kind.value}")
            if message:
                parts.append(f"| {message}")
            self._emit(" ".join(parts))

    def debug(self, scope: str, event: str, **kwargs: Any) -> None:
        self.log(Level.DEBUG, scope, event, **kwargs)

    def info(self, scope: str, event: str, **kwargs: Any) -> None:
        self.log(Level.INFO, scope, event, **kwargs)

    def success(self, scope: str, event: str, **kwargs: Any) -> None:
        self.log(Level.SUCCESS, scope, event, **kwargs)

    def warn(self, scope: str, event: str, **kwargs: Any) -> None:
        self.log(Level.WARN, scope, event, **kwargs)

    def error(
        self, scope: str, event: str, error_kind: ErrorKind | None = None, **kwargs: Any
    ) -> None:
        self.log(Level.ERROR, scope, event, error_kind=error_kind or ErrorKind.SYSTEM, **kwargs)

    def fatal(
        self, scope: str, event: str, error_kind: ErrorKind | None = None, **kwargs: Any
    ) -> None:
        self.log(Level.FATAL, scope, event, error_kind=error_kind or ErrorKind.SYSTEM, **kwargs)


def default_logger() -> PsyLogger:
    """Build a logger from environment; used until the config authority is wired."""
    min_level = Level(os.environ.get("PSY_LOG_LEVEL", "info"))
    json_mode = os.environ.get("PSY_LOG_MODE", "text").lower() == "json"
    correlation_id = os.environ.get("PSY_CORRELATION_ID", "none")
    return PsyLogger(min_level=min_level, json_mode=json_mode, correlation_id=correlation_id)


# Module-level default instance for convenience. Prefer injecting a configured
# instance once the config authority is available.
logger = default_logger()

# Do not expose a plain logging.Logger that could bypass the schema.
__all__ = ["PsyLogger", "Level", "ErrorKind", "default_logger", "logger"]
