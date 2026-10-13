from flet_code_editor_dsl.flet_code_editor_dsl import (
    DEFAULT_SELECTION_MENU_ITEMS,
    DEFAULT_TOOLBAR_ITEMS,
    EditorRegex,
    EditorTokens,
    ErrorPattern,
    HighlightRule,
    ScrollMode,
    ToolbarPosition,
    VerticalMode,
)
from flet_code_editor_dsl.language import (
    BlockComment,
    BracketPair,
    ErrorRules,
    FoldRule,
    Language,
    Sigil,
    StringRule,
    TokenColors,
    WordGroup,
)

# Deprecated aliases (old names). Delete if you do not need them.
FletCodeEditor = EditorTokens
FletCodeField = EditorRegex

__all__ = [
    "EditorRegex", "EditorTokens",
    "HighlightRule", "ErrorPattern",
    "VerticalMode", "ScrollMode", "ToolbarPosition",
    "DEFAULT_TOOLBAR_ITEMS", "DEFAULT_SELECTION_MENU_ITEMS",
    "Language", "WordGroup", "StringRule", "BlockComment", "Sigil",
    "TokenColors", "FoldRule", "ErrorRules", "BracketPair",
    "FletCodeEditor", "FletCodeField",
]
