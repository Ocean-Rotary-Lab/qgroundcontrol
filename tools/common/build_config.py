"""Shared helpers for reading and exporting .github/build-config.json."""

from __future__ import annotations

import os
from pathlib import Path
from typing import Any

from .io import read_json

CONFIG_ENV_VAR = "CONFIG_FILE"
CONFIG_RELATIVE_PATH = Path(".github") / "build-config.json"
DEFAULT_EXPORT_KEYS = [
    "qt.version",
    "qt.minimum_version",
    "qt.modules",
    "gstreamer.version.minimum",
    "gstreamer.version.default",
    "build.cmake_minimum_version",
    "build.platform_workflows",
]


def find_build_config(
    start: Path | None = None,
    *,
    extra_candidates: list[Path] | None = None,
) -> Path:
    """Find build-config.json by env override, extra candidates, or repo search."""
    if env_path := os.environ.get(CONFIG_ENV_VAR):
        return Path(env_path)

    for candidate in extra_candidates or []:
        if candidate.exists():
            return candidate

    current = (start or Path(__file__).resolve()).resolve()
    if current.is_file():
        current = current.parent

    while current != current.parent:
        config_path = current / CONFIG_RELATIVE_PATH
        if config_path.exists():
            return config_path
        current = current.parent

    raise FileNotFoundError(f"Could not find {CONFIG_RELATIVE_PATH}")


def load_build_config(
    config_file: Path | None = None,
    *,
    start: Path | None = None,
    extra_candidates: list[Path] | None = None,
) -> dict[str, Any]:
    """Load and parse the build config JSON file."""
    path = config_file or find_build_config(start, extra_candidates=extra_candidates)
    data = read_json(path)
    if not isinstance(data, dict):
        raise ValueError(f"Expected JSON object in {path}")
    return data


def get_build_config_value(
    key: str,
    default: str = "",
    *,
    config_file: Path | None = None,
    start: Path | None = None,
    extra_candidates: list[Path] | None = None,
) -> str:
    """Return a string value from the build config or *default*.

    Dotted keys (e.g. "gstreamer.version.default") walk nested objects.

    File-missing / unreadable → silent default (callers may run outside the repo).
    Parse / schema errors → raise: an existing-but-corrupted config silently
    swapping defaults can produce wrong artifacts without warning.
    """
    try:
        config = load_build_config(config_file, start=start, extra_candidates=extra_candidates)
    except (FileNotFoundError, OSError):
        return default
    value: Any = config
    for part in key.split("."):
        if isinstance(value, dict) and part in value:
            value = value[part]
        else:
            return default
    return str(value) if value is not None else default


_EXPORT_KEY_ALIASES: dict[str, str] = {}

_GSTREAMER_VERSION_ENV_NAMES: dict[str, str] = {
    "gstreamer.version.default": "GSTREAMER_VERSION",
    "gstreamer.version.minimum": "GSTREAMER_MINIMUM_VERSION",
}


def export_build_config_values(
    config: dict[str, Any],
    *,
    keys: list[str] | None = None,
) -> dict[str, str]:
    """Return uppercase env-style values exported from the config."""
    exported: dict[str, str] = {}
    for key in keys or DEFAULT_EXPORT_KEYS:
        value: Any = config
        for part in key.split("."):
            if isinstance(value, dict) and part in value:
                value = value[part]
            else:
                value = None
                break
        if value is not None:
            primary = _GSTREAMER_VERSION_ENV_NAMES.get(key, key.replace(".", "_").upper())
            exported[primary] = str(value)
            alias = _EXPORT_KEY_ALIASES.get(key)
            if alias:
                exported[alias] = str(value)
    return exported


def github_output_values(values: dict[str, str]) -> dict[str, str]:
    """Lowercase-key outputs for $GITHUB_OUTPUT."""
    outputs = {key.lower(): value for key, value in sorted(values.items())}
    return outputs
