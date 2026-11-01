from dataclasses import dataclass, field
from enum import Enum

import flet as ft

from .language import FoldRule


@dataclass
class HighlightRule:
    """Regex rule used by EditorRegex. The first rule that matches a character wins."""
    pattern: str
    color: str
    ignore_case: bool = False


@dataclass
class ErrorPattern:
    """Regex whose matches are underlined as errors (EditorRegex)."""
    pattern: str
    message: str = ""
    ignore_case: bool = False


class VerticalMode(str, Enum):
    FIXED = "fixed"
    BOUNDED = "bounded"
    UNLIMITED = "unlimited"


class ScrollMode(str, Enum):
    PAGE_FIRST = "page_first"
    EDITOR_FIRST = "editor_first"
    EDITOR_ONLY = "editor_only"


class ToolbarPosition(str, Enum):
    BOTTOM = "bottom"
    TOP = "top"


DEFAULT_SELECTION_MENU_ITEMS = ["cut", "copy", "paste", "select_all"]
DEFAULT_TOOLBAR_ITEMS = [
    "undo", "redo", "cut", "copy", "paste", "select_all", "select_mode",
    "left", "right", "up", "down", "home", "end", "tab",
]


@ft.control("EditorRegex")
class EditorRegex(ft.LayoutControl):
    """Regex-highlighted Flet code editor."""
    value: str = ""
    rules: list[HighlightRule] = field(default_factory=list)
    error_rules: list[ErrorPattern] = field(default_factory=list)
    error_color: str = "#F44747"
    wavy: bool = True
    folds: list[FoldRule] = field(default_factory=list)
    fold_by_indent: bool = False

    line_numbers: bool = True
    syntax_highlighting: bool = True
    show_errors: bool = True
    code_folding: bool = True
    wrap: bool = False
    horizontal_scroll_padding: float = 0.0
    read_only: bool = False
    highlight_scope: str = "document"  # "document" or "current_line"
    autocomplete: bool = True
    autocomplete_words: list[str] = field(default_factory=list)
    remember_suggestions: bool = True
    autocomplete_trigger: str = ""

    width_level: int | None = 17
    height_level: int | None = 17
    vertical_mode: VerticalMode = VerticalMode.FIXED
    min_lines: int | None = None
    max_lines: int | None = None

    font_family: str = "Consolas"
    font_size: float = 16.0
    default_color: str | None = None
    background_color: str | None = None
    debounce_ms: int = 150

    selection_menu: bool = True
    selection_menu_items: list[str] = field(default_factory=lambda: list(DEFAULT_SELECTION_MENU_ITEMS))
    mobile_controls: bool | None = None
    toolbar_items: list[str] = field(default_factory=lambda: list(DEFAULT_TOOLBAR_ITEMS))
    toolbar_position: ToolbarPosition = ToolbarPosition.BOTTOM
    cursor_pad: bool | None = None
    magnifier: bool | None = None
    magnifier_size: float = 110.0
    magnifier_zoom: float = 1.6
    scroll_mode: ScrollMode = ScrollMode.EDITOR_FIRST

    on_change: ft.ControlEventHandler["EditorRegex"] | None = None


@ft.control("EditorTokens")
class EditorTokens(ft.LayoutControl):
    """Tokenizer-highlighted Flet code editor."""
    value: str = ""
    language: str = ""

    line_numbers: bool = True
    syntax_highlighting: bool = True
    show_errors: bool = True
    code_folding: bool = True
    wrap: bool = False
    horizontal_scroll_padding: float = 0.0
    read_only: bool = False
    highlight_scope: str = "document"
    autocomplete: bool = True
    autocomplete_words: list[str] = field(default_factory=list)
    remember_suggestions: bool = True
    autocomplete_trigger: str = ""

    width_level: int | None = 17
    height_level: int | None = 17
    vertical_mode: VerticalMode = VerticalMode.FIXED
    min_lines: int | None = None
    max_lines: int | None = None

    font_family: str = "Consolas"
    font_size: float = 16.0
    default_color: str | None = None
    background_color: str | None = None
    debounce_ms: int = 150

    selection_menu: bool = True
    selection_menu_items: list[str] = field(default_factory=lambda: list(DEFAULT_SELECTION_MENU_ITEMS))
    mobile_controls: bool | None = None
    toolbar_items: list[str] = field(default_factory=lambda: list(DEFAULT_TOOLBAR_ITEMS))
    toolbar_position: ToolbarPosition = ToolbarPosition.BOTTOM
    cursor_pad: bool | None = None
    magnifier: bool | None = None
    magnifier_size: float = 110.0
    magnifier_zoom: float = 1.6
    scroll_mode: ScrollMode = ScrollMode.EDITOR_FIRST

    on_change: ft.ControlEventHandler["EditorTokens"] | None = None
