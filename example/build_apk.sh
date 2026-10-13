#!/usr/bin/env bash
# Needs internet. Do NOT use `flet run`: the stock Flet client does not contain
# the custom controls ("Unknown control: EditorRegex"). Build the app instead.
set -e
cd "$(dirname "$0")"
pip install -U "flet[all]>=0.85.2"
flet build apk -v        # -> build/apk/
