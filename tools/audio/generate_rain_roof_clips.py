#!/usr/bin/env python3
"""Compatibility entry point for rebuilding the interior rain-on-roof loop.

The recorded exterior and interior weather loops are now built together by
`tools/audio/generate_weather_rain_loops.py`; this legacy command keeps existing
scripts reproducible while forwarding to the recorded roof source.
"""

from __future__ import annotations

from generate_weather_rain_loops import main


if __name__ == "__main__":
    raise SystemExit(main(default_clip="roof"))
