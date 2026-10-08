from dataclasses import dataclass, field
from enum import Enum

import flet as ft


@dataclass
class HighlightRule:
    """Regex rule. Used by FletCodeField only (FletCodeEditor uses `Language`)."""
    pattern: str
    color: str


class VerticalMode(str, Enum):
    FIXED = "fixed"          # fills the given height, scrolls internally
    BOUNDED = "bounded"      # grows between min_lines and max_lines, then scrolls
    UNLIMITED = "unlimited"  # grows with the text, no limit


@ft.control("FletCodeField")
class FletCodeField(ft.LayoutControl):
    """
    TextField-based code field with regex highlighting (per-line cached).
    """
    value: str = ""
    rules: list[HighlightRule] = field(default_factory=list)

    line_numbers: bool = True
    syntax_highlighting: bool = True
    incremental_highlighting: bool = True
    wrap: bool = False
    vertical_mode: VerticalMode = VerticalMode.FIXED
    min_lines: int | None = None
    max_lines: int | None = None

    on_change: ft.ControlEventHandler["FletCodeField"] | None = None


@ft.control("FletCodeEditor")
class FletCodeEditor(ft.LayoutControl):
    """
    Custom code editor (not a TextField). Every line is laid out and painted
    independently and only visible lines are built. Highlighting uses a
    hand-written tokenizer configured by `language` (see `Language`).
    """
    value: str = ""
    # JSON produced by `Language(...).to_json()`; "" = no highlighting.
    language: str = ""

    line_numbers: bool = True
    syntax_highlighting: bool = True
    show_errors: bool = True              # error underlines (needs Language.errors)
    code_folding: bool = True             # fold markers (needs Language.folds)
    wrap: bool = False
    read_only: bool = False

    # Visible size of the editor box, 1..30: level/30 of the available space
    # (30 covers it, 1 is a small box). None = use width/height/expand.
    # Ignored when width/height/expand is set explicitly.
    width_level: int | None = 13
    height_level: int | None = 13

    vertical_mode: VerticalMode = VerticalMode.FIXED
    min_lines: int | None = None
    max_lines: int | None = None

    font_family: str = "Consolas"
    font_size: float = 12.0
    default_color: str | None = None      # text color for unstyled text
    background_color: str | None = None   # editor background

    # Delay (ms) before the text is sent back to Python / on_change fires.
    debounce_ms: int = 150

    on_change: ft.ControlEventHandler["FletCodeEditor"] | None = None
