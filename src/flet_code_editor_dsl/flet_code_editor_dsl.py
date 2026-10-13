from dataclasses import dataclass, field
from enum import Enum

import flet as ft

from .language import FoldRule


@dataclass
class HighlightRule:
    """Regex rule used by EditorRegex. The first rule that matches a character wins."""
    pattern: str
    color: str


@dataclass
class ErrorPattern:
    """Regex whose matches are underlined as errors (EditorRegex)."""
    pattern: str
    message: str = ""


class VerticalMode(str, Enum):
    FIXED = "fixed"          # fills the given height, scrolls internally
    BOUNDED = "bounded"      # grows between min_lines and max_lines, then scrolls
    UNLIMITED = "unlimited"  # grows with the text, no limit


class ScrollMode(str, Enum):
    PAGE_FIRST = "page_first"      # page scrolls first, the editor moves after the page reached its limit
    EDITOR_FIRST = "editor_first"  # editor scrolls first, the rest of the drag goes to the page
    EDITOR_ONLY = "editor_only"    # no hand-off


class ToolbarPosition(str, Enum):
    BOTTOM = "bottom"
    TOP = "top"


# Buttons of the floating selection menu (Android/iOS). Also accepted: "undo", "redo".
DEFAULT_SELECTION_MENU_ITEMS = ["cut", "copy", "paste", "select_all"]

DEFAULT_TOOLBAR_ITEMS = [
    "undo", "redo", "cut", "copy", "paste", "select_all", "select_mode",
    "left", "right", "up", "down", "home", "end", "tab",
]


@ft.control("EditorRegex")
class EditorRegex(ft.LayoutControl):
    """
    Code editor whose highlighting is driven by regular expressions.
    Same features as EditorTokens (line numbers, error underlines, folding,
    mobile controls...), different engine: rules are regexes matched per line.
    """
    value: str = ""

    # --- engine: regex ---
    rules: list[HighlightRule] = field(default_factory=list)
    error_rules: list[ErrorPattern] = field(default_factory=list)  # matches are underlined
    error_color: str = "#F44747"
    wavy: bool = True
    folds: list[FoldRule] = field(default_factory=list)
    fold_by_indent: bool = False

    # --- common ---
    line_numbers: bool = True
    syntax_highlighting: bool = True
    show_errors: bool = True
    code_folding: bool = True
    wrap: bool = False
    read_only: bool = False

    width_level: int | None = 13
    height_level: int | None = 13
    vertical_mode: VerticalMode = VerticalMode.FIXED
    min_lines: int | None = None
    max_lines: int | None = None

    font_family: str = "Consolas"
    font_size: float = 12.0
    default_color: str | None = None
    background_color: str | None = None
    debounce_ms: int = 150

    # --- mobile (None = automatic: on for Android/iOS, off elsewhere) ---
    selection_menu: bool = True           # floating cut/copy/paste menu at the caret (Android/iOS)
    selection_menu_items: list[str] = field(default_factory=lambda: list(DEFAULT_SELECTION_MENU_ITEMS))
    mobile_controls: bool | None = None   # toolbar: cut/copy/paste/undo/arrows...
    toolbar_items: list[str] = field(default_factory=lambda: list(DEFAULT_TOOLBAR_ITEMS))
    toolbar_position: ToolbarPosition = ToolbarPosition.BOTTOM
    cursor_pad: bool | None = None        # draggable pad to move the caret smoothly
    magnifier: bool | None = None         # magnifier while a finger is held (long press)
    magnifier_size: float = 110.0
    magnifier_zoom: float = 1.6
    scroll_mode: ScrollMode = ScrollMode.PAGE_FIRST

    on_change: ft.ControlEventHandler["EditorRegex"] | None = None


@ft.control("EditorTokens")
class EditorTokens(ft.LayoutControl):
    """
    Code editor whose highlighting is driven by a hand-written tokenizer
    (no regex) configured by `language` (see `Language`).
    """
    value: str = ""

    # --- engine: tokenizer ---
    language: str = ""   # JSON from `Language(...).to_json()`; "" = no highlighting

    # --- common ---
    line_numbers: bool = True
    syntax_highlighting: bool = True
    show_errors: bool = True
    code_folding: bool = True
    wrap: bool = False
    read_only: bool = False

    width_level: int | None = 13
    height_level: int | None = 13
    vertical_mode: VerticalMode = VerticalMode.FIXED
    min_lines: int | None = None
    max_lines: int | None = None

    font_family: str = "Consolas"
    font_size: float = 12.0
    default_color: str | None = None
    background_color: str | None = None
    debounce_ms: int = 150

    # --- mobile ---
    selection_menu: bool = True
    selection_menu_items: list[str] = field(default_factory=lambda: list(DEFAULT_SELECTION_MENU_ITEMS))
    mobile_controls: bool | None = None
    toolbar_items: list[str] = field(default_factory=lambda: list(DEFAULT_TOOLBAR_ITEMS))
    toolbar_position: ToolbarPosition = ToolbarPosition.BOTTOM
    cursor_pad: bool | None = None
    magnifier: bool | None = None
    magnifier_size: float = 110.0
    magnifier_zoom: float = 1.6
    scroll_mode: ScrollMode = ScrollMode.PAGE_FIRST

    on_change: ft.ControlEventHandler["EditorTokens"] | None = None
