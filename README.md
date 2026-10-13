# flet-code-editor-dsl

> Two native Flutter code-editing controls for [Flet](https://flet.dev) — **`EditorTokens`** (hand-written tokenizer) and **`EditorRegex`** (regular expressions) — plus a small Python DSL (`Language`) that describes a language declaratively: keywords, strings, comments, numbers, sigils, error underlines and code folding, without writing a single regular expression. Includes touch-screen helpers: a cut/copy/paste menu at the caret, a magnifier, a cursor pad and page/editor scroll hand-off.

![Python](https://img.shields.io/badge/python-%3E%3D3.10-blue)
![Flet](https://img.shields.io/badge/flet-%3E%3D0.85.2-informational)
[![PyPI](https://img.shields.io/pypi/v/flet-code-editor-dsl)](https://pypi.org/project/flet-code-editor-dsl/)
![License](https://img.shields.io/badge/license-Apache%202.0-blue)

---

## Table of Contents

1. [Overview](#overview)
2. [What's New in 0.3.0 / Migration](#whats-new-in-030--migration)
3. [Features](#features)
4. [Requirements](#requirements)
5. [Installation](#installation)
6. [Quick Start](#quick-start)
7. [Choosing a Control: `EditorTokens` vs `EditorRegex`](#choosing-a-control-editortokens-vs-editorregex)
8. [Editor Reference (both controls)](#editor-reference-both-controls)
   - [Common properties](#common-properties)
   - [Engine properties](#engine-properties)
   - [Sizing the editor (important)](#sizing-the-editor-important)
   - [Vertical modes](#vertical-modes)
   - [Reading and writing text, `on_change` and debounce](#reading-and-writing-text-on_change-and-debounce)
   - [Colors](#colors)
   - [Changing things at runtime](#changing-things-at-runtime)
9. [Mobile / Touch Features](#mobile--touch-features)
   - [Selection menu (cut / copy / paste at the caret)](#selection-menu-cut--copy--paste-at-the-caret)
   - [Extra toolbar and cursor pad](#extra-toolbar-and-cursor-pad)
   - [Magnifier](#magnifier)
   - [Scroll hand-off (`scroll_mode`)](#scroll-hand-off-scroll_mode)
   - [Paste behavior](#paste-behavior)
10. [The `Language` DSL (for `EditorTokens`)](#the-language-dsl-for-editortokens)
    - [`Language`](#language)
    - [`WordGroup`](#wordgroup)
    - [`StringRule`](#stringrule)
    - [`BlockComment` and `line_comments`](#blockcomment-and-line_comments)
    - [`Sigil`](#sigil)
    - [Numbers, operators, punctuation, identifiers](#numbers-operators-punctuation-identifiers)
    - [`TokenColors`](#tokencolors)
    - [`ErrorRules` (error underlines)](#errorrules-error-underlines)
    - [`FoldRule` and `fold_by_indent` (code folding)](#foldrule-and-fold_by_indent-code-folding)
    - [`case_insensitive`](#case_insensitive)
    - [`Language.to_json()`](#languageto_json)
11. [How the Lexer Works](#how-the-lexer-works)
12. [`EditorRegex` Reference (regex engine)](#editorregex-reference-regex-engine)
13. [Performance Notes](#performance-notes)
14. [Complete Examples](#complete-examples)
15. [Important: First Build Required](#important-first-build-required)
16. [Building Your App](#building-your-app)
17. [Developing and Testing Locally](#developing-and-testing-locally)
18. [Project Structure](#project-structure)
19. [Known Limitations](#known-limitations)
20. [Troubleshooting](#troubleshooting)
21. [Contributing](#contributing)
22. [Sponsors](#sponsors)
23. [License](#license)

---

## Overview

`flet-code-editor-dsl` is a Flet extension that ships **two** Flutter controls. Both are built on [`re_editor`](https://pub.dev/packages/re_editor) (a fully custom editor: each line is laid out and painted independently and only visible lines are built), and both offer the same features. **The only difference is the highlighting engine:**

| Control | Highlighting engine | Configured with | Best for |
|---------|---------------------|-----------------|----------|
| **`EditorTokens`** | Hand-written, stateful **tokenizer** (no regex) | A `Language` object (`language=lang.to_json()`) | Large documents, multi-line strings/comments, languages with real structure |
| **`EditorRegex`** | **Regular expressions**, matched per line and cached | `rules`, `error_rules`, `folds` | Quick regex-driven coloring when you already have patterns |

Instead of shipping fixed grammars, you describe your language in Python:

```python
import flet_code_editor_dsl as ce

lang = ce.Language(
    words=[ce.WordGroup(["let", "if", "else"], "#C586C0")],
    line_comments=["#"],
    strings=[ce.StringRule('"')],
    colors=ce.TokenColors(comment="#6A9955", string="#CE9178", number="#B5CEA8"),
)
```

and hand `lang.to_json()` to `EditorTokens`.

## What's New in 0.3.0 / Migration

### 0.3.0

| Change | Details |
|--------|---------|
| **Controls renamed** | `FletCodeEditor` → **`EditorTokens`**, `FletCodeField` → **`EditorRegex`**. The old names still work as deprecated aliases in `__init__.py` (delete them if you do not need them). |
| **`EditorRegex` rebuilt** | It now runs on `re_editor` instead of `code_text_field` (that dependency was removed). It has the **same feature set** as `EditorTokens`: line numbers, error underlines (`error_rules`), code folding (`folds`, `fold_by_indent`), read-only, fonts, colors, size levels, debounce. |
| **`incremental_highlighting` removed** | `EditorRegex` always highlights line by line. Passing the old `incremental_highlighting=` argument raises a `TypeError`. |
| **Touch support** | New selection menu at the caret/handles, optional toolbar and cursor pad, magnifier, `scroll_mode`. See [Mobile / Touch Features](#mobile--touch-features). |
| **Paste fix** | Cut/copy/paste from the new menu/toolbar read the clipboard directly and normalize line endings and control characters before inserting. |
| **New Dart files** | `regex_highlighter.dart` (regex engine). `code_editor.dart` is now shared by both controls. The old `src/flet_code_editor_dsl.dart` (`CodeField` widget) was deleted. |

Rename in your code:

```python
# before                                  # after
ce.FletCodeEditor(language=...)           ce.EditorTokens(language=...)
ce.FletCodeField(rules=[...])             ce.EditorRegex(rules=[...])
```

Because the Dart side changed, **rebuild your app** after upgrading.

### 0.2.0 (from the original `CodeEditor` API)

The earlier regex-based `CodeEditor` control and its `rule()` / `group()` / `pair()` helpers no longer exist.

| Original API | 0.2.0+ |
|-------|-------|
| Control `CodeEditor` | `EditorTokens` (tokenizer) and `EditorRegex` (regex) |
| `rule()`, `group()` + `rules_json()` | `Language(words=[WordGroup(...)], strings=..., ...)` + `Language.to_json()`; `HighlightRule` list for `EditorRegex` |
| `pair()` + `pairs_json()` | `ErrorRules(brackets=[BracketPair(...)])` and `StringRule` |
| `strict` / `error_color` | `ErrorRules(unknown_words=True, allowed_words=[...], forbidden_words=[...])` |
| `before` / `after` / `ignore_if` | Not needed: the lexer understands strings, comments, calls, sigils |
| Flet `>= 0.80` | Flet `>= 0.85.2` |

## Features

- Native Flutter rendering through the Flet extension mechanism.
- Two engines with the same features: declarative `Language` tokenizer (**no regex**) or regex rules.
- Virtualized rendering: only visible lines are built and highlighted.
- Per-line caching; correct multi-line state (block comments, multi-line strings) in the tokenizer engine.
- Strings with escapes, custom delimiters and optional multi-line support.
- Line and block comments, sigils (`$name`, `@user`), numbers (decimal, float, exponent, `_`, `0x`/`0b`/`0o`), function-call detection.
- Optional error underlines (wavy or straight) and user-defined folding regions.
- Line numbers, word wrap, read-only, font family/size, text and background colors.
- **Touch helpers:** cut/copy/paste menu at the caret, optional toolbar with a cursor pad, long-press magnifier, page/editor scroll hand-off.
- Standard `ft.LayoutControl` properties (`width`, `height`, `expand`, `margin`, `visible`, `opacity`, ...).

## Requirements

| Component | Version |
|-----------|---------|
| Python | `>= 3.10` |
| Flet (Python) | `>= 0.85.2` |
| Flet (Flutter side) | `flet: ^0.85.2` |
| Dart SDK | `>= 3.3.0 < 4.0.0` (the tokenizer uses Dart 3 records) |
| Flutter packages | `re_editor ^0.10.0` (pulled in automatically) |
| Git | Only for installing from GitHub |

> The package contains a Flutter extension, so your app must declare it in `pyproject.toml` and be built with `flet build`. See [Important: First Build Required](#important-first-build-required).

---

## Installation

### Option 1: PyPI (recommended)

```bash
pip install flet-code-editor-dsl
```

Declare it in your app's `pyproject.toml`:

```toml
[project]
name = "my-flet-app"
version = "1.0.0"
requires-python = ">=3.10"
dependencies = [
  "flet>=0.85.2",
  "flet-code-editor-dsl>=0.3.0",
]
```

Pin an exact version for reproducible builds: `"flet-code-editor-dsl==0.3.0"`. Upgrade with `pip install --upgrade flet-code-editor-dsl`.

### Option 2: GitHub

```bash
pip install "git+https://github.com/obgwew/flet-code-editor-dsl.git"
pip install "git+https://github.com/obgwew/flet-code-editor-dsl.git@v0.3.0"   # pinned
```

Inside `pyproject.toml`:

```toml
dependencies = [
  "flet>=0.85.2",
  "flet-code-editor-dsl @ git+https://github.com/obgwew/flet-code-editor-dsl.git",
]
```

### Option 3: Local checkout or wheel

See [Developing and Testing Locally](#developing-and-testing-locally). Note that `flet build` does **not** read `[tool.uv.sources]`; point `dependencies` at a wheel file instead.

### Verifying the installation

```bash
python -c "import flet_code_editor_dsl as m; print(m.__all__)"
```

---

## Quick Start

```python
import flet as ft
import flet_code_editor_dsl as ce

LANG = ce.Language(
    words=[
        ce.WordGroup(["let", "if", "else", "while", "return"], "#C586C0"),  # keywords
        ce.WordGroup(["true", "false", "null"], "#569CD6"),                 # constants
    ],
    line_comments=["#"],
    strings=[ce.StringRule('"')],
    colors=ce.TokenColors(
        comment="#6A9955", string="#CE9178", escape="#D7BA7D", number="#B5CEA8",
        function="#DCDCAA", identifier="#9CDCFE", operator="#D4D4D4", punctuation="#D4D4D4",
    ),
)


def main(page: ft.Page):
    page.title = "Code Editor"
    page.theme_mode = ft.ThemeMode.DARK

    editor = ce.EditorTokens(
        value='let x = add(1, 2)  # sum\nprint("done\\n")',
        language=LANG.to_json(),          # <-- JSON string, not the object
        default_color="#D4D4D4",
        background_color="#1E1E1E",
        expand=True,
    )
    page.add(editor)


ft.run(main)
```

Same thing with the regex engine:

```python
editor = ce.EditorRegex(
    value='let x = add(1, 2)  # sum',
    rules=[
        ce.HighlightRule(r"#.*", "#6A9955"),                     # comments first
        ce.HighlightRule(r'"[^"\n]*"', "#CE9178"),               # strings
        ce.HighlightRule(r"\b(?:let|if|else)\b", "#C586C0"),     # keywords
        ce.HighlightRule(r"\b\d+(?:\.\d+)?\b", "#B5CEA8"),       # numbers
    ],
    default_color="#D4D4D4",
    background_color="#1E1E1E",
    expand=True,
)
```

> **Two things that surprise people on first use:**
> 1. For `EditorTokens`, `language` expects the **JSON string** returned by `Language(...).to_json()`, not the `Language` object.
> 2. By default the editor box is only `13/30` of the available space. Use `expand=True` (or `width`/`height`) to control the size. See [Sizing the editor](#sizing-the-editor-important).

---

## Choosing a Control: `EditorTokens` vs `EditorRegex`

Both controls share the same widget, so everything outside highlighting is identical.

| Feature | `EditorTokens` | `EditorRegex` |
|---------|:--------------:|:-------------:|
| Highlighting engine | Tokenizer (`Language`) | Regex (`HighlightRule`) |
| Multi-line strings / block comments | Yes (state carried across lines) | No (each line is highlighted alone) |
| Error underlines | Yes (`Language.errors`) | Yes (`error_rules`, regex based) |
| Code folding | Yes (`Language.folds`, `fold_by_indent`) | Yes (`folds`, `fold_by_indent`) |
| Line numbers, `wrap`, `read_only` | Yes | Yes |
| `font_family`, `font_size`, `default_color`, `background_color` | Yes | Yes |
| `width_level` / `height_level`, `vertical_mode`, `min_lines`, `max_lines` | Yes | Yes |
| `debounce_ms`, `on_change` | Yes | Yes |
| Mobile: selection menu, toolbar, magnifier, `scroll_mode` | Yes | Yes |

Rule of thumb: use **`EditorTokens`** for real languages (especially with multi-line constructs); use **`EditorRegex`** when you already have regular expressions or only need a few colors.

---

## Editor Reference (both controls)

```python
@ft.control("EditorTokens")
class EditorTokens(ft.LayoutControl): ...

@ft.control("EditorRegex")
class EditorRegex(ft.LayoutControl): ...
```

### Common properties

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `value` | `str` | `""` | Editor text. Assigning from Python replaces the content. |
| `line_numbers` | `bool` | `True` | Show the line-number gutter. |
| `syntax_highlighting` | `bool` | `True` | Master switch for highlighting (and the error underlines that depend on it). |
| `show_errors` | `bool` | `True` | Draw error underlines (needs `Language.errors` or `error_rules`). |
| `code_folding` | `bool` | `True` | Show fold markers (needs folds or `fold_by_indent`). |
| `wrap` | `bool` | `False` | Soft-wrap long lines. |
| `read_only` | `bool` | `False` | Disable editing (selection and scrolling still work). |
| `width_level` | `int \| None` | `13` | Visible width as `level/30` of the available width. See [Sizing](#sizing-the-editor-important). |
| `height_level` | `int \| None` | `13` | Visible height as `level/30` of the available height. |
| `vertical_mode` | `VerticalMode` | `FIXED` | `FIXED`, `BOUNDED` or `UNLIMITED`. |
| `min_lines` / `max_lines` | `int \| None` | `None` | Bounds in `BOUNDED` mode (fall back to `1` / `10`). |
| `font_family` | `str` | `"Consolas"` | Font family (use a monospace font). |
| `font_size` | `float` | `12.0` | Font size in logical pixels. |
| `default_color` | `str \| None` | `None` | Color for text with no token color. |
| `background_color` | `str \| None` | `None` | Editor background. |
| `debounce_ms` | `int` | `150` | Delay before the text is pushed to Python and `on_change` fires. |
| `on_change` | handler | `None` | Called after the debounce delay; `e.data` is the full text. |

Touch-related properties are listed in [Mobile / Touch Features](#mobile--touch-features). All `ft.LayoutControl` properties are available as well.

### Engine properties

**`EditorTokens`**

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `language` | `str` | `""` | JSON from `Language(...).to_json()`. `""` means no highlighting. Invalid JSON is silently treated as "no highlighting". |

Error underlines and folding for this control are configured **inside** the `Language` (`errors=`, `folds=`, `fold_by_indent=`).

**`EditorRegex`**

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `rules` | `list[HighlightRule]` | `[]` | Regex highlighting rules. First matching rule wins per character. |
| `error_rules` | `list[ErrorPattern]` | `[]` | Regexes whose matches are underlined as errors. |
| `error_color` | `str` | `"#F44747"` | Underline color. |
| `wavy` | `bool` | `True` | Wavy underline (`False` = straight). |
| `folds` | `list[FoldRule]` | `[]` | Folding regions (same `FoldRule` as the DSL). |
| `fold_by_indent` | `bool` | `False` | Also fold by indentation. |

### Sizing the editor (important)

There are three independent ways to size the control, evaluated in this order:

1. **Explicit layout** — `width=`, `height=` or `expand=`. When given, the level properties are ignored for that axis:
   - `width` or `expand` set → `width_level` is ignored.
   - `height`, `expand` set, or `vertical_mode != FIXED` → `height_level` is ignored.
2. **Line-count height** — `vertical_mode="bounded"` / `"unlimited"` computes the height from the number of lines.
3. **Levels** — otherwise the box is `level / 30` of the available space on that axis, with a **minimum of 48 px**. Level `30` covers the available space. If the parent gives unbounded constraints, the screen size is used.

Because both levels default to `13`, an editor placed in a layout **without** `expand`, `width` or `height` will look small. This is the most common "why is my editor tiny?" question:

```python
ce.EditorTokens(...)                                     # ~13/30 x 13/30 of the space
ce.EditorTokens(..., width_level=30, height_level=30)    # fills the space
ce.EditorTokens(..., expand=True)                        # fills the parent (levels ignored)
ce.EditorTokens(..., width=600, height=400)              # fixed size (levels ignored)
```

Values outside `1..30` are clamped.

> When the optional toolbar is shown (`mobile_controls=True`) in `FIXED` mode, the editor and the toolbar share the given height (the toolbar takes 44 px).

### Vertical modes

```python
class VerticalMode(str, Enum):
    FIXED = "fixed"          # fills the given height, scrolls internally
    BOUNDED = "bounded"      # grows between min_lines and max_lines, then scrolls
    UNLIMITED = "unlimited"  # grows with the text, no limit
```

| Mode | Behavior |
|------|----------|
| `FIXED` | Fills the height it is given (explicit height, `expand`, or `height_level`) and scrolls internally. |
| `BOUNDED` | Height follows the line count, clamped to `[min_lines, max_lines]` (defaults `1` and `10`), then scrolls. |
| `UNLIMITED` | Height follows the line count with no limit. Put it inside a scrollable parent. |

```python
# A chat-input style box: starts at 3 lines, grows to 12, then scrolls
ce.EditorTokens(
    language=LANG.to_json(),
    vertical_mode=ce.VerticalMode.BOUNDED,
    min_lines=3,
    max_lines=12,
    width=500,
)
```

### Reading and writing text, `on_change` and debounce

```python
def on_change(e: ft.ControlEvent):
    print("Current text:", e.data)

editor = ce.EditorTokens(on_change=on_change, debounce_ms=300)
```

- Typing does **not** send every keystroke. After the user stops typing for `debounce_ms` milliseconds, the full text is written to `editor.value` and `on_change` fires (only if you assigned a handler).
- `debounce_ms=0` sends immediately; negative values are treated as `0`.
- If nothing really changed (only the cursor moved, or the text equals what was already sent), nothing is sent.
- `editor.value = "..."` followed by `editor.update()` replaces the content. Your own echo is ignored, so there is no feedback loop.
- Because of the debounce, `editor.value` may be slightly stale right after typing. Use `on_change` for the latest value, or lower `debounce_ms`.

### Colors

Colors for `default_color`, `background_color`, `error_color` and everything in the DSL are **hex strings**:

| Format | Example | Meaning |
|--------|---------|---------|
| `#RRGGBB` | `#FF8800` | Opaque (alpha `FF` added automatically) |
| `#AARRGGBB` | `#80FF8800` | Explicit alpha |

- Plain strings, **not** `ft.Colors.*` values or color names.
- Invalid or empty values are treated as "not set" instead of raising an error.
- Set `default_color` explicitly when you set a dark `background_color`, otherwise un-styled text may be unreadable.

### Changing things at runtime

```python
editor.language = OTHER_LANG.to_json()      # EditorTokens
editor.rules = NEW_RULES                    # EditorRegex
editor.show_errors = False
editor.code_folding = False
editor.syntax_highlighting = False
editor.read_only = True
editor.wrap = True
editor.font_size = 16
editor.background_color = "#0D1117"
editor.update()
```

Changing the language/rules, `syntax_highlighting`, `show_errors` or `code_folding` rebuilds the highlighter; the internal editor widget is re-created so every line repaints. The text is kept, but the scroll position may reset. No rebuild of the Flutter client is needed for any of these changes.

---

## Mobile / Touch Features

New in 0.3.0. They apply to both controls. Properties that take `None` mean **automatic**: enabled on Android/iOS, disabled elsewhere.

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `selection_menu` | `bool` | `True` | Show the cut/copy/paste menu at the caret and selection handles (Android/iOS only). |
| `selection_menu_items` | `list[str]` | `["cut","copy","paste","select_all"]` | Buttons of that menu. Also accepts `"undo"`, `"redo"`. |
| `mobile_controls` | `bool \| None` | `None` (hidden) | Show the extra toolbar. Opt-in: `True` to show. |
| `toolbar_items` | `list[str]` | all items | Toolbar buttons, see below. |
| `toolbar_position` | `ToolbarPosition` | `BOTTOM` | `BOTTOM` or `TOP`. |
| `cursor_pad` | `bool \| None` | `None` (auto) | Draggable pad inside the toolbar. Only visible when the toolbar is shown. |
| `magnifier` | `bool \| None` | `None` (auto) | Magnifier while a finger is held. |
| `magnifier_size` | `float` | `110.0` | Magnifier diameter. |
| `magnifier_zoom` | `float` | `1.6` | Magnification factor. |
| `scroll_mode` | `ScrollMode` | `PAGE_FIRST` | Page/editor scroll hand-off. |

### Selection menu (cut / copy / paste at the caret)

On Android and iOS, `re_editor` shows no menu unless it is given a toolbar controller. The library provides one built on Flutter's `AdaptiveTextSelectionToolbar`, so the menu looks native to the platform and appears when you tap the caret, long-press, or select text.

```python
ce.EditorTokens(
    language=LANG.to_json(),
    selection_menu=True,
    selection_menu_items=["cut", "copy", "paste", "select_all", "undo", "redo"],
)
```

- *Cut* and *Copy* appear only when something is selected. *Cut*, *Paste*, *Undo* and *Redo* are hidden in `read_only` mode.
- The menu is shown on **Android and iOS only**. On desktop, the usual keyboard shortcuts apply.
- Set `selection_menu=False` to disable it.

### Extra toolbar and cursor pad

An optional bar next to the editor, useful when you want explicit controls on a phone:

```python
ce.EditorTokens(
    language=LANG.to_json(),
    mobile_controls=True,
    toolbar_position=ce.ToolbarPosition.BOTTOM,
    toolbar_items=["undo", "redo", "cut", "copy", "paste", "select_all", "left", "right"],
    cursor_pad=True,
)
```

Available `toolbar_items` (default is all of them, in this order; see `ce.DEFAULT_TOOLBAR_ITEMS`):

| Item | Action |
|------|--------|
| `undo`, `redo` | Undo / redo |
| `cut`, `copy`, `paste`, `select_all` | Clipboard and selection |
| `select_mode` | Toggle: arrows, pad and line start/end **extend the selection** instead of moving the caret |
| `left`, `right`, `up`, `down` | Move the caret |
| `home`, `end` | Start / end of the line |
| `tab` | Insert two spaces |

**Cursor pad.** A small pad at the left of the toolbar: drag horizontally to move the caret one character per ~9 px, drag vertically to move one line per ~22 px. With `select_mode` on, dragging extends the selection.

### Magnifier

While a finger is held on the text (after ~0.4 s) a round magnifier appears above it and follows the finger until it is released.

- **Touch only** — it does not appear with a mouse.
- It magnifies the area under the finger; it is a visual aid and does not move the caret by itself.
- It is shown for a long press **inside the text area**. It is not shown while dragging the selection handles, because those live in a separate layer owned by `re_editor`.
- Disable with `magnifier=False`; tune with `magnifier_size` and `magnifier_zoom`.

### Scroll hand-off (`scroll_mode`)

When the editor sits inside a scrollable page, a drag on the editor normally scrolls only the editor and the page stays still. `scroll_mode` decides who moves:

```python
class ScrollMode(str, Enum):
    PAGE_FIRST = "page_first"      # the page scrolls first; the editor moves once the page reached its limit
    EDITOR_FIRST = "editor_first"  # the editor scrolls first; the rest of the drag goes to the page
    EDITOR_ONLY = "editor_only"    # no hand-off
```

- `PAGE_FIRST` (default): a vertical drag moves the nearest vertical scrollable above the editor until it reaches its end in that direction; only then does the editor scroll. Reversing the drag moves the page first again.
- `EDITOR_FIRST`: once the editor hits its top/bottom, the remaining drag distance is passed to the page.
- If the editor is not inside a vertical scrollable, all modes behave like `EDITOR_ONLY`.
- Only direct drags are handed off; fling (inertia) is not forwarded. In `PAGE_FIRST` mode the editor uses clamping scroll physics (no iOS bounce).

### Paste behavior

Cut, copy and paste from the selection menu and the toolbar use the library's own implementation: the clipboard is read directly, `\r\n` / `\r` / Unicode line separators become `\n`, and NUL characters are removed before the text is inserted. Empty clipboards insert nothing. Keyboard shortcuts on desktop still use `re_editor`'s built-in handling.

---

## The `Language` DSL (for `EditorTokens`)

All classes are plain Python `dataclasses` importable from the top-level package:

```python
from flet_code_editor_dsl import (
    Language, WordGroup, StringRule, BlockComment, Sigil,
    TokenColors, FoldRule, ErrorRules, BracketPair,
)
```

### `Language`

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `words` | `list[WordGroup]` | `[]` | Exact words grouped by color (keywords, constants, builtins...). |
| `line_comments` | `list[str]` | `[]` | Markers that start a comment running to the end of the line (`"//"`, `"#"`, `"--"`). |
| `block_comments` | `list[BlockComment]` | `[]` | Multi-line comments (`/* ... */`). |
| `strings` | `list[StringRule]` | `[]` | String literal styles. |
| `sigils` | `list[Sigil]` | `[]` | Prefix + name tokens (`$var`, `@user`). |
| `numbers` | `bool` | `True` | Recognize numeric literals. |
| `operators` | `str` | `"+-*/%=<>!&\|^~?:"` | Each character in this string is an operator character. |
| `punctuation` | `str` | `"(){}[],;."` | Each character is a punctuation character. |
| `identifier_extra` | `str` | `""` | Extra characters allowed **inside** names (for example `"-"`). |
| `case_insensitive` | `bool` | `False` | Match words (and error word lists) ignoring case. |
| `colors` | `TokenColors` | `TokenColors()` | Colors for the built-in token kinds. |
| `folds` | `list[FoldRule]` | `[]` | User-defined folding regions. |
| `fold_by_indent` | `bool` | `False` | Also fold by indentation. |
| `errors` | `ErrorRules \| None` | `None` | Error underlines. `None` disables all error checking. |

### `WordGroup`

```python
WordGroup(words: list[str], color: str)
```

A set of **whole words** sharing one color. Matching is exact against the full identifier, so `end` does **not** match `endpoint`, and `if` does not match inside `iffy`. A word is only matched if it consists of identifier characters (letters, digits, `_`, non-ASCII characters and anything in `identifier_extra`); a "word" such as `"->"` never matches — use `operators` for symbols.

```python
words=[
    ce.WordGroup(["if", "else", "while", "for", "return"], "#C586C0"),
    ce.WordGroup(["True", "False", "None"], "#569CD6"),
    ce.WordGroup(["print", "len", "range"], "#4EC9B0"),
]
```

If the same word appears in several groups, the **last** group wins. Entries with empty text or an invalid color are ignored.

### `StringRule`

```python
StringRule(open: str, close: str | None = None, escape: str | None = "\\", multiline: bool = False)
```

| Field | Description |
|-------|-------------|
| `open` | Opening delimiter (any length). |
| `close` | Closing delimiter. Defaults to `open`. |
| `escape` | Escape character (default backslash) or `None`. The escape character and the **one character after it** form an escape sequence, colored with `TokenColors.escape` (falls back to the string color). A closing delimiter preceded by the escape does not end the string. |
| `multiline` | If `True`, an unclosed string continues on the following lines. If `False`, it ends at the end of the line (and is reported as an error if `ErrorRules.unterminated_strings` is on). |

Rules are tried **longest `open` first**, so `'"""'` wins over `'"'` regardless of list order.

```python
strings=[
    ce.StringRule('"'),
    ce.StringRule("'"),
    ce.StringRule('"""', multiline=True),                      # Python docstrings
    ce.StringRule("`", multiline=True, escape=None),           # JS template / SQL identifiers
    ce.StringRule("[[", "]]", escape=None, multiline=True),    # Lua long strings
    ce.StringRule("'", escape="'"),                            # SQL-style '' escaping
]
```

The delimiters themselves are part of the colored string token.

### `BlockComment` and `line_comments`

```python
BlockComment(start: str, end: str)
```

```python
line_comments=["//", "#"],
block_comments=[ce.BlockComment("/*", "*/"), ce.BlockComment("<!--", "-->")]
```

- Line comments run to the end of the line. Longer markers are tried first.
- Block comments carry their state across lines: a line that starts inside a block comment is colored correctly even if the opening marker is far above.
- Block comments are **not nested**: the first end marker closes the comment. The end marker is searched only after the start marker, so `/*/` does not close itself.
- Comments are recognized before strings, so a comment marker inside a string is **not** a comment, and a quote inside a comment is **not** a string (the lexer reads left to right).

### `Sigil`

```python
Sigil(prefix: str, color: str)
```

A prefix followed by a name, e.g. `Sigil("$", "#9CDCFE")` colors `$name`, `$_x1`. The whole token (prefix + name) gets the color. A prefix with **no** name after it (a lone `$`) is not a sigil and falls through to the other rules.

```python
sigils=[ce.Sigil("$", "#9CDCFE"), ce.Sigil("@", "#4FC1FF"), ce.Sigil("%", "#D7BA7D")]
```

### Numbers, operators, punctuation, identifiers

**Numbers** (`numbers=True`): integers and decimals (`42`, `3.14`, `.5`), digit separators (`1_000_000`), exponents (`1e10`, `2.5E-3`), prefixed literals (`0x1F`, `0b1010`, `0o755`). A number ends where it ends: `10px` is the number `10` followed by the identifier `px`. Identifiers cannot start with a digit. Set `numbers=False` if digits should not be treated specially.

**Operators** — each character in `Language.operators` is an operator character; a *run* of operator characters (`==`, `<=`, `&&`) becomes **one** token with `TokenColors.operator`.

**Punctuation** — each character in `Language.punctuation` becomes its own token with `TokenColors.punctuation`. Characters in neither set are drawn with the default color.

> Because comments and strings are recognized first, `//` is a comment, not two operators, as long as you listed `//` in `line_comments`.

**Identifiers** — a name starts with an ASCII letter, `_`, or **any non-ASCII character** (Arabic, Chinese, accented letters and emoji count as name characters), and continues with letters, digits, `_`, non-ASCII characters and `identifier_extra`.

- An identifier found in `words` gets that group's color.
- Otherwise, if it is directly followed by `(` (spaces and tabs allowed in between) **and** `TokenColors.function` is set, it is a **function call**.
- Otherwise it gets `TokenColors.identifier`.

### `TokenColors`

```python
TokenColors(
    comment=None, string=None, escape=None, number=None,
    function=None, identifier=None, operator=None, punctuation=None,
)
```

| Field | Applies to |
|-------|------------|
| `comment` | Line and block comments |
| `string` | String literals (including delimiters) |
| `escape` | Escape sequences inside strings; falls back to `string` |
| `number` | Numeric literals |
| `function` | Identifiers followed by `(` that are not in `words` |
| `identifier` | All other names |
| `operator` | Operator runs |
| `punctuation` | Punctuation characters and the bracket characters used in `ErrorRules.brackets` |

`None` = default text color (`default_color`). If you leave `function` as `None`, function calls look like ordinary identifiers.

### `ErrorRules` (error underlines)

```python
ErrorRules(
    unterminated_strings=True,
    brackets=[],              # list[BracketPair]
    unknown_words=False,
    allowed_words=[],
    forbidden_words=[],
    color="#F44747",
    wavy=True,
)
```

Enable by passing an instance: `Language(errors=ce.ErrorRules(...))`. The default `errors=None` turns every check off. The underlines can be hidden at runtime with `show_errors=False`. **All checks work inside a single line.**

| Check | Behavior |
|-------|----------|
| `unterminated_strings` | A non-multiline string not closed before the end of the line is underlined from its opening delimiter. Multi-line strings are never flagged. |
| `brackets` | Each `BracketPair(open, close)` must be **single characters**. An unmatched closer, or an opener never closed on the same line, is underlined. Brackets inside strings and comments are not counted. |
| `unknown_words` | Every identifier **not** in `words` and not in `allowed_words` is underlined. Function-call names count as identifiers too. |
| `forbidden_words` | Words that are **always** underlined, even if they are in `words`. |

```python
errors=ce.ErrorRules(
    unterminated_strings=True,
    brackets=[ce.BracketPair("(", ")"), ce.BracketPair("[", "]"), ce.BracketPair("{", "}")],
    unknown_words=True,
    allowed_words=["x", "y", "total", "price", "print"],
    forbidden_words=["goto"],
    color="#F44747",
    wavy=True,
)
```

> The lexer builds a message for each error (*Unterminated string*, *Unknown word: foo*, *Unmatched ')'*, *Unclosed '('*), but the editor only draws the underline; messages are not shown as tooltips yet. Brackets spanning several lines are **not** matched across lines; for a language where `{` and `}` regularly sit on different lines, leave the `{}` pair out.

### `FoldRule` and `fold_by_indent` (code folding)

```python
FoldRule(start: str, end: str | None = None, length: int | None = None)
```

Folding adds fold markers in the gutter. It is active when `code_folding=True` **and** at least one `FoldRule` is defined or `fold_by_indent=True`. `FoldRule` and `fold_by_indent` are used the same way by `EditorRegex` (as the `folds=` / `fold_by_indent=` properties of the control).

1. **Start/end markers** — a line starting with `start` opens a region and a line starting with `end` closes it. Nesting is supported (each rule keeps its own stack).

   ```python
   folds=[ce.FoldRule("class", "end"), ce.FoldRule("def", "end"), ce.FoldRule("if", "end")]
   ```

2. **Fixed length** — fold the next `length` lines after a line starting with `start` (clamped to the last line). If both `end` and `length` are given, `end` is used.

   ```python
   folds=[ce.FoldRule("on", length=5)]
   ```

Matching rules:

- Markers match at the **beginning of a line, after indentation**.
- If the marker ends with a letter, digit or `_`, it matches **whole words only**: `end` does not match `endpoint`.
- If the marker ends with a symbol (`{`, `#region`...), it matches as a plain prefix.
- Matching is case-sensitive and ignores `case_insensitive`.
- A region is foldable only if it has at least one line inside it. An opener without a closer folds nothing; a bare `FoldRule("{")` with neither `end` nor `length` does nothing.
- Folding is purely line-based and **not aware of strings or comments**.
- If `start == end`, the same marker toggles open/closed.

**`fold_by_indent=True`** additionally creates a region for every line followed by more-indented lines (Python/YAML style). A tab counts as 4 spaces, blank lines are skipped, and a region ends at the last non-empty line still indented deeper. It can be combined with `folds`.

### `case_insensitive`

When `True`, words in `WordGroup`, `allowed_words` and `forbidden_words` are compared in lower case, and the identifier found in the text is lower-cased before lookup (ideal for SQL, BASIC, Pascal). It does **not** affect comment markers, string delimiters, sigil prefixes or `FoldRule` markers.

```python
sql = ce.Language(
    case_insensitive=True,
    words=[ce.WordGroup(["select", "from", "where", "and", "or", "insert", "into"], "#C586C0")],
)
```

### `Language.to_json()`

```python
def to_json(self) -> str
```

Serializes the whole description into a compact JSON string. Pass it to `EditorTokens(language=...)`. The editor compares the string, so **re-assigning an identical JSON string does not rebuild anything**; build it once at module level and reuse it:

```python
PY_LANG = ce.Language(...).to_json()
a = ce.EditorTokens(language=PY_LANG)
b = ce.EditorTokens(language=PY_LANG, read_only=True)
```

---

## How the Lexer Works

For every line the lexer scans left to right and at each position tries the following, **stopping at the first match**:

| # | Step | Notes |
|---|------|-------|
| 0 | Continue a multi-line construct | If the line starts inside a block comment or multi-line string, finish it first. |
| 1 | Whitespace | Spaces, tabs, `\r` and non-breaking space. Never colored. |
| 2 | Line comments | Longest marker first. Consumes the rest of the line. |
| 3 | Block comments | Longest start marker first. May stay open to the next line. |
| 4 | Strings | Longest `open` first. May stay open for `multiline=True`. |
| 5 | Sigils | Prefix + at least one name character. |
| 6 | Numbers | Only if `numbers=True`. |
| 7 | Identifiers / words / calls | Also applies `forbidden_words` and `unknown_words`. |
| 8 | Bracket check | Only for characters listed in `ErrorRules.brackets`. |
| 9 | Operators | A run of operator characters is one token. |
| 10 | Punctuation | One character per token. |
| 11 | Anything else | Default color. |

Practical consequences:

- **Order inside lists does not matter** for strings, comments and sigils (the longest marker wins). It matters only for duplicate words (last group wins).
- Comments beat strings and strings beat everything else, because these are tested first while scanning left to right.
- There is **no rule-priority system** like in regex highlighters; the structure of the language decides the color.
- Bracket characters listed in `ErrorRules.brackets` always get the punctuation color.
- Adjacent tokens with the same color are merged into one span.

**Multi-line state.** The lexer keeps a small integer state at the start of each line: `0` = normal, `1..N` = inside block comment *N*, then one state per multi-line string rule. A line's start state is derived from the lines above it and cached, so editing a line only re-lexes the lines below it **when they become visible**.

---

## `EditorRegex` Reference (regex engine)

```python
@dataclass
class HighlightRule:
    pattern: str    # Dart RegExp pattern
    color: str      # "#RRGGBB" or "#AARRGGBB"

@dataclass
class ErrorPattern:
    pattern: str    # Dart RegExp pattern; every match is underlined
    message: str = ""
```

Properties: see [Engine properties](#engine-properties) and [Common properties](#common-properties).

How it works:

- Each line is matched separately against every rule; the result is cached by line text (the cache is cleared when it exceeds 5000 entries).
- **The first matching rule wins** for each character: a character already colored by an earlier rule is not recolored by later ones. Put your most specific rules (comments, strings) **first** and general rules (identifiers) **last**. (This is the opposite of the original `CodeEditor` engine, where later rules overrode earlier ones.)
- Zero-length matches are ignored.
- `error_rules` matches are underlined with `error_color` (wavy by default) on top of the token color. They can be hidden with `show_errors=False`.
- Patterns use the **Dart `RegExp`** engine. Use `(?<name>...)` instead of Python's `(?P<name>...)`, and raw strings (`r"..."`) in Python. Patterns or colors that fail to parse are silently skipped.
- Rules are re-compiled only when the lists change; ordinary typing never recompiles regexes.
- Because every line is matched alone, patterns cannot span lines: multi-line comments and triple-quoted strings **cannot** be highlighted. Use `EditorTokens` for those.

```python
import flet as ft
import flet_code_editor_dsl as ce

RULES = [
    ce.HighlightRule(r"//.*$", "#6A9955"),                          # comments first
    ce.HighlightRule(r'"(?:[^"\\]|\\.)*"?', "#CE9178"),             # strings
    ce.HighlightRule(r"\b(?:func|let|if|else|return)\b", "#C586C0"),
    ce.HighlightRule(r"\b\d+(?:\.\d+)?\b", "#B5CEA8"),
    ce.HighlightRule(r"\b[A-Za-z_]\w*(?=\()", "#DCDCAA"),           # function calls
]
ERRORS = [
    ce.ErrorPattern(r'"[^"\\]*(?:\\.[^"\\]*)*$', "Unterminated string"),
]

def main(page: ft.Page):
    page.add(
        ce.EditorRegex(
            value='func main() {\n    print("hi\n}',
            rules=RULES,
            error_rules=ERRORS,
            folds=[ce.FoldRule("func", length=20)],
            fold_by_indent=True,
            vertical_mode=ce.VerticalMode.BOUNDED,
            min_lines=3,
            max_lines=10,
            width=500,
        )
    )

ft.run(main)
```

---

## Performance Notes

- Only the lines that are actually painted are highlighted (the editor is virtualized).
- **Tokenizer:** each line's result is cached by `(index, text, start state)`. For languages **without** multi-line constructs an edit invalidates only that line; with multi-line constructs it invalidates the chain from the edited line downward, lazily. The cache is cleared beyond 20 000 cached lines.
- **Regex:** each line's result is cached by its text; cleared beyond 5000 entries.
- Changing the language/rules, `syntax_highlighting`, `show_errors` or `code_folding` forces a repaint of all visible lines; changing colors/fonts of the control itself does not re-highlight.
- Folding analysis runs on the entire document when the text changes; it is cheap line-prefix checking but O(lines × fold rules).

---

## Complete Examples

### 1. A tiny scripting language with errors and folding

```python
import flet as ft
import flet_code_editor_dsl as ce

SAMPLE = '''\
# Example program
let total = (price * 3) + 12
if (total > 100) {
    print("expensive")
} else {
    print("cheap")
}
/* multi-line
   comment */
let broken = (1 + 2
let s = "unterminated
'''

LANG = ce.Language(
    words=[
        ce.WordGroup(["let", "if", "else"], "#C586C0"),
        ce.WordGroup(["true", "false"], "#569CD6"),
    ],
    line_comments=["#"],
    block_comments=[ce.BlockComment("/*", "*/")],
    strings=[ce.StringRule('"')],
    colors=ce.TokenColors(
        comment="#6A9955", string="#CE9178", escape="#D7BA7D",
        number="#B5CEA8", function="#DCDCAA", identifier="#9CDCFE",
        operator="#D4D4D4", punctuation="#FFD700",
    ),
    folds=[ce.FoldRule("if", "}")],
    errors=ce.ErrorRules(
        unterminated_strings=True,
        brackets=[ce.BracketPair("(", ")")],
        unknown_words=True,
        allowed_words=["total", "price", "print", "broken", "s"],
    ),
)


def main(page: ft.Page):
    page.title = "flet-code-editor-dsl demo"
    page.theme_mode = ft.ThemeMode.DARK

    status = ft.Text(f"Characters: {len(SAMPLE)}")

    def on_change(e: ft.ControlEvent):
        status.value = f"Characters: {len(e.data or '')}"
        status.update()

    def toggle_errors(e: ft.ControlEvent):
        editor.show_errors = e.control.value
        editor.update()

    editor = ce.EditorTokens(
        value=SAMPLE,
        language=LANG.to_json(),
        default_color="#D4D4D4",
        background_color="#1E1E1E",
        font_family="Consolas",
        font_size=15,
        expand=True,
        on_change=on_change,
        debounce_ms=200,
    )

    page.add(
        ft.Row([ft.Switch(label="Show errors", value=True, on_change=toggle_errors), status]),
        editor,
    )


ft.run(main)
```

### 2. Python-like language (docstrings, `fold_by_indent`)

```python
PYTHON_LIKE = ce.Language(
    words=[
        ce.WordGroup(["def", "class", "if", "elif", "else", "for", "while", "return",
                      "import", "from", "as", "in", "not", "and", "or", "with", "try",
                      "except", "finally", "raise", "lambda"], "#C586C0"),
        ce.WordGroup(["True", "False", "None", "self"], "#569CD6"),
    ],
    line_comments=["#"],
    strings=[
        ce.StringRule('"""', multiline=True),
        ce.StringRule("'''", multiline=True),
        ce.StringRule('"'),
        ce.StringRule("'"),
    ],
    colors=ce.TokenColors(comment="#6A9955", string="#CE9178", escape="#D7BA7D",
                          number="#B5CEA8", function="#DCDCAA", identifier="#9CDCFE"),
    fold_by_indent=True,
)
```

### 3. SQL (case-insensitive, `--` and `/* */` comments, `''` escaping)

```python
SQL = ce.Language(
    case_insensitive=True,
    words=[
        ce.WordGroup(["select", "from", "where", "join", "left", "right", "inner", "on",
                      "group", "by", "order", "having", "insert", "into", "values",
                      "update", "set", "delete", "create", "table", "and", "or", "not",
                      "null", "as", "limit"], "#C586C0"),
        ce.WordGroup(["count", "sum", "avg", "min", "max"], "#DCDCAA"),
    ],
    line_comments=["--"],
    block_comments=[ce.BlockComment("/*", "*/")],
    strings=[ce.StringRule("'", escape="'"), ce.StringRule('"', escape=None)],
    colors=ce.TokenColors(comment="#6A9955", string="#CE9178", number="#B5CEA8",
                          identifier="#9CDCFE"),
)
```

### 4. Config / templating language with sigils and dashed names

```python
TEMPLATE = ce.Language(
    identifier_extra="-",                       # allows names like font-size
    sigils=[ce.Sigil("$", "#4FC1FF"), ce.Sigil("@", "#D7BA7D")],
    line_comments=["//"],
    strings=[ce.StringRule('"'), ce.StringRule("'")],
    words=[ce.WordGroup(["include", "define", "if", "endif"], "#C586C0")],
    colors=ce.TokenColors(comment="#6A9955", string="#CE9178", number="#B5CEA8",
                          identifier="#9CDCFE"),
    folds=[ce.FoldRule("if", "endif"), ce.FoldRule("define", length=3)],
)
```

### 5. Read-only viewer that grows with its content

```python
log_view = ce.EditorTokens(
    value=log_text,
    language=LOG_LANG.to_json(),
    read_only=True,
    line_numbers=False,
    vertical_mode=ce.VerticalMode.BOUNDED,
    min_lines=1,
    max_lines=20,
    width=700,
)
```

### 6. Phone-friendly editor inside a scrolling page

```python
page.add(
    ft.ListView(
        expand=True,
        controls=[
            ft.Text("Notes"),
            ce.EditorTokens(
                value=text,
                language=LANG.to_json(),
                height=360,
                width_level=30,
                height_level=None,
                # touch helpers
                selection_menu=True,
                selection_menu_items=["cut", "copy", "paste", "select_all"],
                magnifier=True,
                mobile_controls=True,          # optional toolbar + cursor pad
                cursor_pad=True,
                scroll_mode=ce.ScrollMode.PAGE_FIRST,
            ),
            ft.Text("More page content below..."),
        ],
    )
)
```

### 7. Switching languages from a dropdown

```python
LANGUAGES = {"Python": PYTHON_LIKE.to_json(), "SQL": SQL.to_json(), "Plain": ""}

def on_pick(e):
    editor.language = LANGUAGES[e.control.value]
    editor.update()

page.add(
    ft.Dropdown(options=[ft.dropdown.Option(k) for k in LANGUAGES],
                value="Python", on_select=on_pick),   # on_select / on_change depends on your Flet version
    editor,
)
```

---

## Important: First Build Required

`flet-code-editor-dsl` is not a pure-Python package. Its widgets are written in Dart/Flutter and must be **compiled into the Flet client**. The stock Flet client does not include them, so running an app against the stock client fails with `Unknown control: EditorTokens` / `Unknown control: EditorRegex`.

1. **Declare the library in your app's `pyproject.toml`** under `[project] dependencies`.
2. **Build your app** with `flet build <platform>`.
3. **Run the built app** (or the build output on a device/emulator).

> If the library is only installed with `pip` and not declared in `pyproject.toml`, Flet will not include the extension and the controls will not appear.

| Change | Rebuild needed? |
|--------|-----------------|
| Editing Python code, `value`, `language` / `Language(...)`, `rules`, colors, fonts, flags, sizes, layout, mobile options | No — sent to the client at runtime. |
| Updating `flet-code-editor-dsl` to a version whose Dart code changed (for example 0.2.x → 0.3.0) | **Yes** |
| Upgrading Flet itself to a new major/minor version | Yes |
| Adding or removing other Flet extensions | Yes |

## Building Your App

```bash
# Desktop
flet build windows
flet build macos
flet build linux

# Mobile
flet build apk
flet build ipa

# Web
flet build web
```

`flet build` detects the Flutter package bundled in `flutter/flet_code_editor_dsl/` and adds it to the generated Flutter project. A Flutter SDK is required; Flet downloads one if missing. The extension registers two control types — `EditorTokens` and `EditorRegex` — in `extension.dart`.

> The touch features (selection menu, magnifier, scroll hand-off) only matter on a touch device, so test them with an Android/iOS build rather than a desktop build.

---

## Developing and Testing Locally

To test the library **before publishing it**:

1. Build a wheel from the repository root (the version number can stay as is):

   ```bash
   pip wheel . --no-deps -w dist
   ```

   Check that it contains both the Python code and the Flutter files (`flutter/...` entries):

   ```bash
   python -c "import zipfile,glob; z=zipfile.ZipFile(glob.glob('dist/*.whl')[0]); n=z.namelist(); print(b'EditorRegex' in z.read('flet_code_editor_dsl/__init__.py'), len([x for x in n if x.startswith('flutter/')]))"
   ```

2. In your test app's `pyproject.toml`, reference the wheel file directly:

   ```toml
   dependencies = [
     "flet>=0.85.2",
     "flet-code-editor-dsl @ file:///C:/path/to/repo/dist/flet_code_editor_dsl-0.3.0-py3-none-any.whl",
   ]
   ```

   Do **not** rely on `[tool.uv.sources]`: `flet build` passes the dependency names to its packaging step and ignores that table, so it would install the version published on PyPI instead of your local one.

3. Delete the old build output and build again:

   ```bash
   rm -rf build        # PowerShell: Remove-Item -Recurse -Force .\build
   flet build apk -v
   ```

4. Confirm the right version was packaged before running:

   ```bash
   grep EditorRegex build/site-packages/flet_code_editor_dsl/__init__.py
   ```

Repeat step 1 (and delete `build`) after every change to the library.

**Publishing:** bump `version` in `pyproject.toml` (PyPI never accepts the same version twice), then:

```bash
pip install -U build twine
python -m build
twine check dist/*
twine upload dist/*          # try `--repository testpypi` first
```

---

## Project Structure

```text
flet-code-editor-dsl/
├── README.md
├── LICENSE
├── FUNDING.yml
├── .gitignore
├── MANIFEST.in
├── pyproject.toml
├── example/                               # test app (see "Developing and Testing Locally")
│   ├── pyproject.toml
│   └── src/main.py
└── src/
    ├── flet_code_editor_dsl/
    │   ├── __init__.py                    # Public exports (+ deprecated aliases)
    │   ├── flet_code_editor_dsl.py        # EditorTokens, EditorRegex, HighlightRule, ErrorPattern, VerticalMode, ScrollMode, ToolbarPosition
    │   └── language.py                    # Language DSL dataclasses + to_json()
    └── flutter/
        ├── __init__.py
        └── flet_code_editor_dsl/
            ├── __init__.py
            ├── pubspec.yaml               # Flutter package (v0.3.0)
            └── lib/
                ├── flet_code_editor_dsl.dart      # Exports Extension
                └── src/
                    ├── extension.dart             # Maps control types to the shared widget
                    ├── code_editor.dart           # Shared editor widget (re_editor): sync, sizing, selection menu, toolbar, magnifier, scroll hand-off
                    ├── regex_highlighter.dart     # Regex engine (EditorRegex)
                    └── tokenizer.dart             # Tokenizer engine (EditorTokens): CodeLanguage, LineHighlighter, FoldAnalyzer
```

| File | Responsibility |
|------|----------------|
| `flet_code_editor_dsl.py` | Declares the two Flet controls and their helper types. |
| `language.py` | Declarative language description; produces the JSON consumed by Dart. |
| `extension.dart` | Registers `EditorRegex` and `EditorTokens` with Flet. |
| `code_editor.dart` | The widget both controls share: value sync and debounce, engine selection, sizing, line numbers, fold indicator, selection menu, toolbar/cursor pad, magnifier, scroll hand-off, clipboard actions. |
| `regex_highlighter.dart` | `RegexSpec` / `RegexHighlighter`: per-line regex highlighting and error underlines. |
| `tokenizer.dart` | `CodeLanguage.fromJson`, the stateful lexer, the cached `LineHighlighter`, the `FoldAnalyzer`, and the `CodeHighlighter` interface both engines implement. |
| `pyproject.toml` | Packaging metadata (setuptools). Includes `flutter.flet_code_editor_dsl` (`**/*`) as package data so `flet build` can find the Flutter code. |

> Keep generated files out of the repository:
>
> ```gitignore
> __pycache__/
> *.pyc
> *.egg-info/
> build/
> dist/
> ```

---

## Known Limitations

- **Touch features are new in 0.3.0** and have had limited testing on real devices; please report problems with your device, OS version and Flet version.
- **The magnifier does not follow the selection handles** (they are owned by `re_editor`); it appears on a long press inside the text and follows the finger, not the caret.
- **The selection menu is Android/iOS only.** Desktop keeps `re_editor`'s keyboard shortcuts.
- **Pasting with the platform's built-in shortcut/menu inside `re_editor`** still uses its own code path; the library's paste normalization applies to its own menu and toolbar.
- **`scroll_mode` forwards drags only**, not fling; `PAGE_FIRST` uses clamping physics inside the editor.
- **No nested block comments.** The first end marker closes a block comment.
- **Error checks are per line.** Unmatched brackets are not tracked across lines; the unterminated-string check does not apply to multi-line strings.
- **Error messages are not shown yet.** Errors are drawn as underlines only.
- **Folding is line-based.** It is not aware of strings and comments; markers are recognized only at the start of a line. A `FoldRule` needs `end` or `length` to produce a region.
- **`EditorRegex` highlights line by line**: no multi-line constructs, first-rule-wins.
- **No autocompletion, auto-indent or search UI** is provided by the DSL.
- **Colors are hex strings** (`#RRGGBB` / `#AARRGGBB`), not `ft.Colors.*` values.
- **Debounced value.** `editor.value` on the Python side may lag by up to `debounce_ms` behind what is on screen.
- **First build required.** As with all Flet extensions, the controls are not available in the stock Flet client.

## Troubleshooting

| Symptom | Likely cause and fix |
|---------|----------------------|
| `Unknown control: EditorRegex` / `EditorTokens` | The app is not running with the extension compiled in. Declare the library in `pyproject.toml` and run a build made with `flet build`. |
| `ImportError: cannot import name 'EditorRegex'` in the built app | The build packaged an older version (for example 0.2.0 from PyPI). See [Developing and Testing Locally](#developing-and-testing-locally): use a wheel file in `dependencies`, delete `build/`, rebuild, and check `build/site-packages/flet_code_editor_dsl/__init__.py`. |
| `TypeError` about `incremental_highlighting` | The argument was removed in 0.3.0; `EditorRegex` always highlights per line. Remove it. |
| `FletCodeEditor` / `FletCodeField` not found | They remain as deprecated aliases of `EditorTokens` / `EditorRegex`. If you removed the aliases, use the new names. |
| No cut/copy/paste menu on the phone | Make sure `selection_menu=True` (default), the app was **rebuilt** with 0.3.0, and the app runs on Android/iOS. The menu appears when you tap the caret, long-press, or select text. |
| Pasted text does not appear | Use *Paste* from the selection menu or the toolbar (they sanitize the clipboard text). Check that the editor is not `read_only`. |
| Magnifier does not appear | It is touch-only, needs a ~0.4 s long press inside the text area, and `magnifier` must not be `False`. |
| Cursor pad is missing | It lives in the toolbar: set `mobile_controls=True` (and keep `cursor_pad` not `False`). |
| The page does not scroll when dragging over the editor | Check `scroll_mode`. `PAGE_FIRST` (default) moves the page first; `EDITOR_ONLY` disables hand-off. The editor must be inside a vertical scrollable (`ListView`, `Column(scroll=...)`). |
| The editor is tiny | `width_level` / `height_level` default to 13 (of 30). Set `expand=True`, `width`/`height`, or levels up to 30. |
| No colors at all | `EditorTokens`: `language` is empty or not valid JSON — pass `Language(...).to_json()` (a string). `EditorRegex`: `rules` is empty or the patterns are invalid for Dart. Also check `syntax_highlighting=True`. |
| Text is hard to see on a dark background | Set `default_color` (for example `"#D4D4D4"`) together with `background_color`. |
| Function calls look like normal names | `TokenColors.function` is not set. |
| A word is not highlighted as a keyword | Not an exact whole-word match (case, or it contains non-identifier characters). Use `case_insensitive=True`, or `identifier_extra` for dashed words. |
| Error underlines do not appear | `EditorTokens`: `Language.errors` is `None`. `EditorRegex`: `error_rules` is empty. Or `show_errors=False` / `syntax_highlighting=False`. |
| Red underline under every variable | `unknown_words=True` flags everything not in `words`/`allowed_words`. Add the names to `allowed_words` or turn it off. |
| No fold markers | `code_folding=False`, or no `FoldRule` (with `end` or `length`) and `fold_by_indent=False`. |
| `on_change` seems late | It is debounced by `debounce_ms` (default 150 ms). Lower it, or set `0`. |
| An `EditorRegex` rule has no effect | An earlier rule already colored those characters (first match wins), or the regex is invalid for Dart. |
| Changes made from Python are not visible | Call `editor.update()` after modifying a property. |
| `pip install` from GitHub fails | Confirm Git is installed, the URL is correct, and (private repos) that you are authenticated. |

## Contributing

Contributions are welcome.

1. Fork the repository.
2. Create a feature branch: `git checkout -b feature/my-feature`.
3. Commit your changes with clear messages.
4. Push the branch and open a Pull Request describing the change and its motivation.

Please open an issue first for larger changes or new features so the design can be discussed. See [Developing and Testing Locally](#developing-and-testing-locally) for how to try your changes in an app.

## Sponsors

Development of `flet-code-editor-dsl` is supported by its sponsors. Their contributions help cover maintenance time, testing across platforms, and new features.

### Our Sponsors

<!--
  Add sponsors below. Suggested format:

  <a href="https://example.com"><img src="https://example.com/logo.png" alt="Sponsor Name" height="60"></a>
-->

*Your logo could be here. [Become the first sponsor!](https://github.com/sponsors/obgwew)*

### Become a Sponsor

If this library saves you time, please consider supporting it:

- [Sponsor on GitHub](https://github.com/sponsors/obgwew)

| Tier | Benefit |
|------|---------|
| **Supporter** | Your name listed in this section. |
| **Silver** | Your name and link listed in this section. |
| **Gold** | Your logo and link displayed prominently at the top of this section. |

Sponsorship is entirely optional and does not affect the [license](#license) or the features available to anyone. Thank you to everyone who supports open-source work.

---

## License

This project is licensed under the **Apache License, Version 2.0**. See the [LICENSE](LICENSE) file for the full text.

```text
Copyright 2026 obgwew

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
```

By contributing to this repository, you agree that your contributions will be licensed under the same Apache 2.0 license.
