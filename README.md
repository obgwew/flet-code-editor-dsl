# flet-code-editor-dsl

> Two native Flutter code-editing controls for [Flet](https://flet.dev), plus a small Python DSL (`Language`) that describes a language declaratively — keywords, strings, comments, numbers, sigils, error underlines and code folding — without writing a single regular expression.

![Python](https://img.shields.io/badge/python-%3E%3D3.10-blue)
![Flet](https://img.shields.io/badge/flet-%3E%3D0.85.2-informational)
[![PyPI](https://img.shields.io/pypi/v/flet-code-editor-dsl)](https://pypi.org/project/flet-code-editor-dsl/)
![License](https://img.shields.io/badge/license-Apache%202.0-blue)

---

## Table of Contents

1. [Overview](#overview)
2. [What's New in 0.2.1 / Migration from the Previous API](#whats-new-in-020--migration-from-the-previous-api)
3. [Features](#features)
4. [Requirements](#requirements)
5. [Installation](#installation)
6. [Quick Start](#quick-start)
7. [Choosing a Control: `FletCodeEditor` vs `FletCodeField`](#choosing-a-control-fletcodeeditor-vs-fletcodefield)
8. [`FletCodeEditor` Reference](#fletcodeeditor-reference)
   - [Properties](#properties)
   - [Sizing the editor (important)](#sizing-the-editor-important)
   - [Vertical modes](#vertical-modes)
   - [Reading and writing text, `on_change` and debounce](#reading-and-writing-text-on_change-and-debounce)
   - [Colors](#colors)
   - [Changing things at runtime](#changing-things-at-runtime)
9. [The `Language` DSL](#the-language-dsl)
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
10. [How the Lexer Works](#how-the-lexer-works)
11. [Performance Notes](#performance-notes)
12. [`FletCodeField` Reference (regex based)](#fletcodefield-reference-regex-based)
13. [Complete Examples](#complete-examples)
14. [Important: First Build Required](#important-first-build-required)
15. [Building Your App](#building-your-app)
16. [Project Structure](#project-structure)
17. [Known Limitations](#known-limitations)
18. [Troubleshooting](#troubleshooting)
19. [Contributing](#contributing)
20. [Sponsors](#sponsors)
21. [License](#license)

---

## Overview

`flet-code-editor-dsl` is a Flet extension that ships **two** Flutter controls:

| Control | Built on | Highlighting | Best for |
|---------|----------|--------------|----------|
| **`FletCodeEditor`** | [`re_editor`](https://pub.dev/packages/re_editor) (fully custom editor; each line is laid out and painted independently, only visible lines are built) | Hand-written, stateful **tokenizer** configured by a `Language` object | Large documents, custom languages, error underlines, code folding |
| **`FletCodeField`** | [`code_text_field`](https://pub.dev/packages/code_text_field) (`TextField` based) | **Regular expressions** (`HighlightRule`), cached per line | Small snippets, quick regex-driven coloring |

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

and hand `lang.to_json()` to the editor.

## What's New in 0.2.0 / Migration from the Previous API

Version 0.2.0 is a **rewrite of the public API**. The earlier regex-based `CodeEditor` control and its `rule()` / `group()` / `pair()` helpers no longer exist.

| Previous API | 0.2.0 |
|-------|-------|
| Control `CodeEditor` (type `flet_code_editor_dsl`) | `FletCodeEditor` (new, tokenizer based) and `FletCodeField` (regex based) |
| `rule()`, `group()` + `rules_json()` | `Language(words=[WordGroup(...)], strings=..., ...)` + `Language.to_json()` for the editor; `HighlightRule` list for `FletCodeField` |
| `pair()` + `pairs_json()` (bracket/quote coloring) | `ErrorRules(brackets=[BracketPair(...)])` (unmatched brackets get an underline) and `StringRule` (quotes are part of the string token) |
| `strict` / `error_color` (paint unknown text red) | `ErrorRules(unknown_words=True, allowed_words=[...], forbidden_words=[...])` with a colored (wavy) underline |
| `before` / `after` / `ignore_if` context regexes | Not needed: the lexer natively understands strings, comments, calls (`name(`), sigils, etc. |
| Dart `RegExp` for everything | No regex in `FletCodeEditor` at all. Regex is only used by `FletCodeField` |
| Flet `>= 0.80` | Flet `>= 0.85.2` |

New in 0.2.0:

- Line numbers, **code folding**, read-only mode, word wrap.
- Multi-line strings and block comments with state carried across lines.
- Per-token-kind colors (`TokenColors`) including escape sequences inside strings.
- Error underlines (unterminated strings, unmatched brackets, unknown/forbidden words).
- Size control by level (`width_level` / `height_level`) or by line count (`vertical_mode`).
- Debounced synchronization of the text back to Python (`debounce_ms`).

## Features

- Native Flutter rendering through the Flet extension mechanism.
- Declarative `Language` description — **no regular expressions**.
- Virtualized rendering: only visible lines are built and lexed.
- Incremental, per-line caching with correct multi-line state (block comments, multi-line strings).
- Strings with escape characters, custom delimiters and optional multi-line support.
- Line comments and block comments (multiple styles at once).
- Sigils such as `$name` or `@user`.
- Numbers: decimal, floats, exponents, `_` separators, `0x` / `0b` / `0o` prefixes.
- Function-call detection (`name(`) with its own color.
- Optional error underlines (wavy or straight) and user-defined folding regions.
- Configurable font, size, text color, background, line numbers, wrapping, read-only.
- Standard `ft.LayoutControl` properties (`width`, `height`, `expand`, `margin`, `visible`, `opacity`, ...).

## Requirements

| Component | Version |
|-----------|---------|
| Python | `>= 3.10` (the dataclasses use `str \| None` syntax) |
| Flet (Python) | `>= 0.85.2` (see `requires.txt`) |
| Flet (Flutter side) | `flet: ^0.85.2` |
| Dart SDK | `>= 3.3.0 < 4.0.0` (the tokenizer uses Dart 3 records) |
| Flutter | `>= 1.17.0` (practically: the version Flet 0.85 uses) |
| Flutter packages | `re_editor ^0.10.0`, `code_text_field ^1.1.0` (pulled in automatically) |
| Git | Only for installing from GitHub |

> **Note:** the package contains a Flutter extension, so your app must declare it in `pyproject.toml` and be built once with `flet build`. See [Important: First Build Required](#important-first-build-required).

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
  "flet-code-editor-dsl",
]
```

Pin an exact version for reproducible builds:

```toml
dependencies = ["flet>=0.85.2", "flet-code-editor-dsl==0.2.0"]
```

Upgrade:

```bash
pip install --upgrade flet-code-editor-dsl
```

### Option 2: GitHub

```bash
pip install "git+https://github.com/obgwew/flet-code-editor-dsl.git"
# pinned:
pip install "git+https://github.com/obgwew/flet-code-editor-dsl.git@v0.2.0"
```

Inside `pyproject.toml`:

```toml
dependencies = [
  "flet>=0.85.2",
  "flet-code-editor-dsl @ git+https://github.com/obgwew/flet-code-editor-dsl.git",
]
```

### Option 3: Local editable install

```bash
git clone https://github.com/obgwew/flet-code-editor-dsl.git
cd flet-code-editor-dsl
pip install -e .
```

### Verifying the installation

```bash
python -c "import flet_code_editor_dsl as m; print(m.__all__)"
```

Expected output:

```text
['FletCodeEditor', 'FletCodeField', 'HighlightRule', 'VerticalMode', 'Language', 'WordGroup', 'StringRule', 'BlockComment', 'Sigil', 'TokenColors', 'FoldRule', 'ErrorRules', 'BracketPair']
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
        comment="#6A9955",
        string="#CE9178",
        escape="#D7BA7D",
        number="#B5CEA8",
        function="#DCDCAA",
        identifier="#9CDCFE",
        operator="#D4D4D4",
        punctuation="#D4D4D4",
    ),
)


def main(page: ft.Page):
    page.title = "Code Editor"
    page.theme_mode = ft.ThemeMode.DARK

    editor = ce.FletCodeEditor(
        value='let x = add(1, 2)  # sum\nprint("done\\n")',
        language=LANG.to_json(),          # <-- JSON string, not the object
        default_color="#D4D4D4",
        background_color="#1E1E1E",
        expand=True,
    )
    page.add(editor)


ft.run(main)
```

> On Flet versions that still use the older entry point, replace `ft.run(main)` with `ft.app(main)`.

> **Two things that surprise people on first use:**
> 1. `language` expects the **JSON string** returned by `Language(...).to_json()`, not the `Language` object itself.
> 2. By default the editor box is only `13/30` of the available space. Use `expand=True` (or `width`/`height`) to control the size. See [Sizing the editor](#sizing-the-editor-important).

---

## Choosing a Control: `FletCodeEditor` vs `FletCodeField`

| Feature | `FletCodeEditor` | `FletCodeField` |
|---------|:----------------:|:---------------:|
| Highlighting engine | Tokenizer (`Language`) | Regex (`HighlightRule`) |
| Multi-line strings / block comments | Yes (state carried across lines) | No (each line is highlighted alone in incremental mode) |
| Only visible lines are built | Yes | No |
| Error underlines | Yes (`ErrorRules`) | No |
| Code folding | Yes (`FoldRule`, `fold_by_indent`) | No |
| Read-only mode | Yes | No |
| `font_family`, `font_size` | Yes | No (fixed to Consolas 12) |
| `default_color`, `background_color` | Yes | No |
| `width_level` / `height_level` | Yes | No |
| `debounce_ms` | Yes | No (text is sent on every change) |
| Line numbers, `wrap`, `vertical_mode`, `min_lines`, `max_lines` | Yes | Yes |
| `on_change` | Yes | Yes |

Rule of thumb: use **`FletCodeEditor`** unless you only need a few regex-based colors.

---

## `FletCodeEditor` Reference

```python
@ft.control("FletCodeEditor")
class FletCodeEditor(ft.LayoutControl): ...
```

### Properties

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `value` | `str` | `""` | Editor text. Assigning from Python replaces the content. |
| `language` | `str` | `""` | JSON produced by `Language(...).to_json()`. `""` means no highlighting. Invalid JSON is silently treated as "no highlighting". |
| `line_numbers` | `bool` | `True` | Show the line-number gutter. |
| `syntax_highlighting` | `bool` | `True` | Master switch for highlighting (and the error underlines that depend on it). |
| `show_errors` | `bool` | `True` | Draw error underlines. Requires `Language.errors` to be set. |
| `code_folding` | `bool` | `True` | Show fold markers. Requires `Language.folds` or `fold_by_indent=True`. |
| `wrap` | `bool` | `False` | Soft-wrap long lines. |
| `read_only` | `bool` | `False` | Disable editing (selection and scrolling still work). |
| `width_level` | `int \| None` | `13` | Visible width as `level/30` of the available width. See [Sizing](#sizing-the-editor-important). |
| `height_level` | `int \| None` | `13` | Visible height as `level/30` of the available height. |
| `vertical_mode` | `VerticalMode` | `FIXED` | `FIXED`, `BOUNDED` or `UNLIMITED`. See [Vertical modes](#vertical-modes). |
| `min_lines` | `int \| None` | `None` | Lower bound in `BOUNDED` mode (falls back to `1`). |
| `max_lines` | `int \| None` | `None` | Upper bound in `BOUNDED` mode (falls back to `10`). |
| `font_family` | `str` | `"Consolas"` | Font family. Use a monospace font for correct alignment. |
| `font_size` | `float` | `12.0` | Font size in logical pixels. |
| `default_color` | `str \| None` | `None` | Color for text with no token color (see [Colors](#colors)). |
| `background_color` | `str \| None` | `None` | Editor background. |
| `debounce_ms` | `int` | `150` | Delay before the text is pushed to Python and `on_change` fires. |
| `on_change` | `ft.ControlEventHandler \| None` | `None` | Called after the debounce delay; `e.data` is the full text. |

All `ft.LayoutControl` properties are available as well.

### Sizing the editor (important)

There are three independent ways to size the control. They are evaluated in this order:

1. **Explicit layout** — `width=`, `height=` or `expand=` (any truthy / positive value). When given, the level properties are ignored for that axis:
   - `width` or `expand` set → `width_level` is ignored.
   - `height`, `expand` set, or `vertical_mode != FIXED` → `height_level` is ignored.
2. **Line-count height** — `vertical_mode="bounded"` / `"unlimited"` computes the height from the number of lines (see below).
3. **Levels** — otherwise the box is `level / 30` of the available space on that axis, with a **minimum of 48 px**. Level `30` covers the available space, level `1` gives a small box. If the parent gives unbounded constraints, the screen size is used as the reference.

Because both levels default to `13`, an editor placed in a layout **without** `expand`, `width` or `height` will look small (about 43% of the space). This is by design but is the most common "why is my editor tiny?" question:

```python
ce.FletCodeEditor(...)                              # ~13/30 x 13/30 of the space
ce.FletCodeEditor(..., width_level=30, height_level=30)   # fills the space
ce.FletCodeEditor(..., expand=True)                 # fills the parent (levels ignored)
ce.FletCodeEditor(..., width=600, height=400)       # fixed size (levels ignored)
```

Values outside `1..30` are clamped.

### Vertical modes

```python
class VerticalMode(str, Enum):
    FIXED = "fixed"          # fills the given height, scrolls internally
    BOUNDED = "bounded"      # grows between min_lines and max_lines, then scrolls
    UNLIMITED = "unlimited"  # grows with the text, no limit
```

| Mode | Behavior |
|------|----------|
| `FIXED` | The editor fills the height it is given (explicit height, `expand`, or `height_level`) and scrolls internally. |
| `BOUNDED` | Height follows the line count, clamped to `[min_lines, max_lines]` (defaults `1` and `10`), then scrolls. |
| `UNLIMITED` | Height follows the line count with no limit. Put it inside a scrollable parent. |

In `BOUNDED` and `UNLIMITED` modes the height is measured from the font (`line height × lines + padding`), so changing `font_size` or `font_family` updates it automatically. Use `UNLIMITED` only inside a scrollable container, otherwise very long text can overflow.

```python
# A chat-input style box: starts at 3 lines, grows to 12, then scrolls
ce.FletCodeEditor(
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

editor = ce.FletCodeEditor(on_change=on_change, debounce_ms=300)
```

How synchronization works:

- Typing inside the editor does **not** send every keystroke. After the user stops typing for `debounce_ms` milliseconds, the full text is written to `editor.value` and `on_change` fires (only if you assigned a handler).
- `debounce_ms=0` sends immediately; negative values are treated as `0`.
- If nothing really changed (for example, only the cursor moved, or the text equals what was already sent), nothing is sent.
- Setting `editor.value = "..."` and calling `editor.update()` replaces the editor content. Your own echo is ignored, so there is no feedback loop.
- Because of the debounce, reading `editor.value` right after the user types may return slightly stale text. Use `on_change` for the latest value, or lower `debounce_ms`.

```python
editor.value = "new content"
editor.update()
```

### Colors

Colors for `default_color`, `background_color` and everything in the DSL are **hex strings**:

| Format | Example | Meaning |
|--------|---------|---------|
| `#RRGGBB` | `#FF8800` | Opaque (alpha `FF` added automatically) |
| `#AARRGGBB` | `#80FF8800` | Explicit alpha |

- They are plain strings, **not** `ft.Colors.*` values or color names.
- Invalid or empty values are treated as "not set" instead of raising an error.
- For tokens, `None` means "use `default_color`". If `default_color` is also `None`, Flutter's own theme text color is used.
- Always set `default_color` explicitly when you set a dark `background_color`, otherwise un-styled text may be unreadable.

### Changing things at runtime

```python
# Swap the language (e.g. when the user picks another file type)
editor.language = OTHER_LANG.to_json()
editor.update()

# Toggle features
editor.show_errors = False
editor.code_folding = False
editor.syntax_highlighting = False
editor.read_only = True
editor.wrap = True
editor.update()

# Appearance
editor.font_size = 16
editor.font_family = "Courier New"
editor.background_color = "#0D1117"
editor.default_color = "#C9D1D9"
editor.line_numbers = False
editor.update()
```

Only `language`, `syntax_highlighting`, `show_errors` and `code_folding` rebuild the highlighter. When any of them changes, the internal editor widget is re-created so every line repaints; the text is kept, but the scroll position may reset. No rebuild of the Flutter client is needed for any of these changes.

---

## The `Language` DSL

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
| `identifier_extra` | `str` | `""` | Extra characters allowed **inside** names (for example `"-"` for CSS/Lisp-style names). |
| `case_insensitive` | `bool` | `False` | Match words (and error word lists) ignoring case. |
| `colors` | `TokenColors` | `TokenColors()` | Colors for the built-in token kinds. |
| `folds` | `list[FoldRule]` | `[]` | User-defined folding regions. |
| `fold_by_indent` | `bool` | `False` | Also fold by indentation. |
| `errors` | `ErrorRules \| None` | `None` | Error underlines. `None` disables all error checking. |

### `WordGroup`

```python
WordGroup(words: list[str], color: str)
```

A set of **whole words** sharing one color. Matching is exact against the full identifier, so `end` does **not** match `endpoint`, and `if` does not match inside `iffy`. A word is only ever matched if it consists of identifier characters (letters, digits, `_`, non-ASCII characters and anything listed in `identifier_extra`); a "word" such as `"->"` will never match — use `operators` for symbols.

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

- Line comments run to the end of the line. Longer markers are tried first (so `///` can win over `//` — they share the same color, so this only matters for correctness of matching).
- Block comments carry their state across lines: a line that starts inside a block comment is colored correctly even if the opening marker is far above.
- Block comments are **not nested**: the first end marker closes the comment. The end marker is searched only after the start marker, so `/*/` does not close itself.
- Comments are recognized before strings, so a comment marker inside a string is **not** a comment, and a quote inside a comment is **not** a string (the lexer reads left to right).

### `Sigil`

```python
Sigil(prefix: str, color: str)
```

A prefix followed by a name, e.g. `Sigil("$", "#9CDCFE")` colors `$name`, `$_x1`. The whole token (prefix + name) gets the color. A prefix with **no** name after it (a lone `$`) is not a sigil and falls through to the other rules. Characters allowed in the name are the usual identifier characters plus `identifier_extra`.

```python
sigils=[ce.Sigil("$", "#9CDCFE"), ce.Sigil("@", "#4FC1FF"), ce.Sigil("%", "#D7BA7D")]
```

### Numbers, operators, punctuation, identifiers

**Numbers** (`numbers=True`):

- Integers and decimals: `42`, `3.14`, `.5`
- Digit separators: `1_000_000`
- Exponents: `1e10`, `2.5E-3`
- Prefixed literals: `0x1F`, `0b1010`, `0o755` (prefix characters `x`, `b`, `o` in either case; hex digits and `_` follow)
- A number ends where it ends: `10px` is the number `10` followed by the identifier `px`.
- Identifiers cannot start with a digit.

Set `numbers=False` if digits should not be treated specially (they are then colored as part of identifiers or "anything else").

**Operators** — each character in `Language.operators` is an operator character; a *run* of operator characters (`==`, `<=`, `&&`, `->` if both `-` and `>` are listed) becomes **one** token with `TokenColors.operator`.

**Punctuation** — each character in `Language.punctuation` becomes its own token with `TokenColors.punctuation`.

Characters belonging to neither set (and not part of anything else, e.g. `@`, `#`, `\`, `` ` ``) are drawn with the default color.

> Because comments and strings are recognized first, a character such as `/` in `//` is a comment, not an operator, as long as you listed `//` in `line_comments`.

**Identifiers** — a name starts with an ASCII letter, `_`, or **any non-ASCII character** (so Arabic, Chinese, accented letters and emoji are treated as name characters), and continues with letters, digits, `_`, non-ASCII characters and `identifier_extra`.

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
| `escape` | Escape sequences inside strings (`\n`, `\"`); falls back to `string` |
| `number` | Numeric literals |
| `function` | Identifiers followed by `(` that are not in `words` |
| `identifier` | All other names |
| `operator` | Operator runs |
| `punctuation` | Punctuation characters and bracket characters used in `ErrorRules.brackets` |

`None` = default text color (`FletCodeEditor.default_color`). Sigils and word groups carry their own colors. If you leave `function` as `None`, function calls look like ordinary identifiers.

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

Enable by passing an instance: `Language(errors=ce.ErrorRules(...))`. The default `errors=None` turns every check off. The underlines can be hidden at runtime with `show_errors=False`.

**All checks work inside a single line.** Errors are drawn as an underline (wavy by default, `wavy=False` for straight) in `color`; the token keeps its own text color.

| Check | Behavior |
|-------|----------|
| `unterminated_strings` | A non-multiline string that is not closed before the end of the line is underlined from its opening delimiter to the end of the line. Multi-line strings are never flagged. |
| `brackets` | Each `BracketPair(open, close)` must be **single characters**. An unmatched closer, or an opener never closed on the same line, is underlined. Mismatched nesting (`(]`) is detected. Brackets inside strings and comments are not counted because the lexer consumes those first. Bracket characters are colored with `TokenColors.punctuation`. |
| `unknown_words` | Every identifier that is **not** in `words` and not in `allowed_words` is underlined. Function-call names and sigil-less variables count as identifiers too, so list the names you want to accept in `allowed_words`. |
| `forbidden_words` | Words that are **always** underlined, even if they are in `words`. |

```python
errors=ce.ErrorRules(
    unterminated_strings=True,
    brackets=[
        ce.BracketPair("(", ")"),
        ce.BracketPair("[", "]"),
        ce.BracketPair("{", "}"),
    ],
    unknown_words=True,
    allowed_words=["x", "y", "total", "price", "print"],
    forbidden_words=["goto"],
    color="#F44747",
    wavy=True,
)
```

> The lexer builds a human-readable message for each error (for example *Unterminated string*, *Unknown word: foo*, *Unmatched ')'*, *Unclosed '('*), but the current editor only draws the underline; messages are not displayed as tooltips yet.

> Brackets spanning several lines are **not** matched across lines; each line is checked on its own. For a language where `{` and `}` regularly sit on different lines, leave the `{}` pair out of `brackets`.

### `FoldRule` and `fold_by_indent` (code folding)

```python
FoldRule(start: str, end: str | None = None, length: int | None = None)
```

Folding adds fold markers in the gutter (a 20 px column next to the line numbers). It is active when `code_folding=True` **and** the language defines at least one `FoldRule` or sets `fold_by_indent=True`.

Two kinds of rules:

1. **Start/end markers** — a line starting with `start` opens a region and a line starting with `end` closes it. Nesting is supported (each rule keeps its own stack).

   ```python
   folds=[ce.FoldRule("class", "end"), ce.FoldRule("def", "end"), ce.FoldRule("if", "end")]
   ```

2. **Fixed length** — fold the next `length` lines after a line starting with `start`.

   ```python
   folds=[ce.FoldRule("on", length=5)]     # fold the 5 lines after every line starting with "on"
   ```

   If the region would run past the end of the document it is clamped to the last line. If both `end` and `length` are given, `end` is used.

Matching rules:

- Markers are matched at the **beginning of a line, after indentation**.
- If the marker ends with a letter, digit or `_`, it matches **whole words only**: `end` does not match `endpoint`, `class` does not match `classify`.
- If the marker ends with a symbol (`{`, `#region`...), it matches as a plain prefix.
- Marker matching is case-sensitive and ignores `case_insensitive`.
- A region is only foldable if it has at least one line inside it. An opener without a closer produces no fold.
- Folding analysis is purely line-based and is **not aware of strings or comments**: a line inside a block comment that begins with `end` will still close a region.
- If `start == end` (for example `"```"` to `"```"`), the same marker toggles open/closed.

```python
folds=[
    ce.FoldRule("{"),                    # NOTE: without end/length this does nothing
    ce.FoldRule("#region", "#endregion"),
    ce.FoldRule("function", "end"),
]
```

**`fold_by_indent=True`** additionally creates a region for every line that is followed by more-indented lines (Python/YAML style). A tab counts as 4 spaces, blank lines are skipped, and a region ends at the last non-empty line that is still indented deeper. It can be combined with `folds`.

### `case_insensitive`

When `True`, the words in `WordGroup`, `ErrorRules.allowed_words` and `ErrorRules.forbidden_words` are compared in lower case, and the identifier found in the text is lower-cased before lookup. This is ideal for SQL, BASIC, Pascal and similar languages:

```python
sql = ce.Language(
    case_insensitive=True,
    words=[ce.WordGroup(["select", "from", "where", "and", "or", "insert", "into"], "#C586C0")],
)
# SELECT, Select and select are all keywords
```

It does **not** affect comment markers, string delimiters, sigil prefixes or `FoldRule` markers.

### `Language.to_json()`

```python
def to_json(self) -> str
```

Serializes the whole description (nested dataclasses included) into a compact JSON string (`ensure_ascii=False`, no extra spaces). Pass it to `FletCodeEditor(language=...)`. Because the editor compares the string, **re-assigning an identical JSON string does not cause a rebuild**, so it is safe to build it once at module level and reuse it for many editors:

```python
PY_LANG = ce.Language(...).to_json()
a = ce.FletCodeEditor(language=PY_LANG)
b = ce.FletCodeEditor(language=PY_LANG, read_only=True)
```

---

## How the Lexer Works

Understanding the order helps when two features seem to "fight". For every line the lexer scans left to right and at each position tries the following, **stopping at the first match**:

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

- **Order inside lists does not matter** for strings, comments and sigils (the longest marker wins automatically). It only matters for duplicate words (last group wins).
- Comments beat strings and strings beat everything else, because the scan is left-to-right and these are tested first.
- There is **no rule-priority/override system** like in regex highlighters; the structure of the language decides the color.
- Bracket characters listed in `ErrorRules.brackets` always get the punctuation color, even if they are also in `operators`.
- Adjacent tokens with the same color are merged into one span.

**Multi-line state.** The lexer keeps a small integer state at the start of each line: `0` = normal, `1..N` = inside block comment *N*, then one state per multi-line string rule. A line's start state is derived from the lines above it and cached, so editing a line only re-lexes the lines below it **when they become visible**.

---

## Performance Notes

- Only the lines that are actually painted are lexed (the editor is virtualized).
- Each line's result is cached by `(index, text, start state)`. Unchanged lines are never lexed again.
- For languages **without** multi-line constructs (no block comments and no `multiline=True` strings) there is no dependency between lines, so an edit invalidates only that line.
- For languages **with** multi-line constructs, an edit invalidates the chain from the edited line downward, lazily.
- The cache is cleared when it grows beyond 20 000 cached lines.
- Changing `language`, `syntax_highlighting`, `show_errors` or `code_folding` forces a repaint of all visible lines; changing colors/fonts of the control itself does not re-lex.
- Folding analysis (`FoldAnalyzer`) runs on the entire document when the text changes; it is cheap line-prefix checking but is O(lines × fold rules).

---

## `FletCodeField` Reference (regex based)

A lighter control based on a `TextField`-style code field. Highlighting is regex based and cached **per line**.

```python
@dataclass
class HighlightRule:
    pattern: str    # Dart RegExp pattern
    color: str      # "#RRGGBB" or "#AARRGGBB"
```

```python
@ft.control("FletCodeField")
class FletCodeField(ft.LayoutControl): ...
```

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `value` | `str` | `""` | Text. |
| `rules` | `list[HighlightRule]` | `[]` | Regex highlighting rules. |
| `line_numbers` | `bool` | `True` | Show line numbers. |
| `syntax_highlighting` | `bool` | `True` | Master switch. |
| `incremental_highlighting` | `bool` | `True` | Highlight line by line with a per-line cache. If `False`, the whole text is highlighted as a single chunk (patterns can then span several lines, but every edit re-highlights everything). |
| `wrap` | `bool` | `False` | Soft-wrap long lines. |
| `vertical_mode` | `VerticalMode` | `FIXED` | `FIXED` expands to fill the given height; `BOUNDED` uses `min_lines`/`max_lines` (defaults `1` / `10`); `UNLIMITED` grows with the text. |
| `min_lines` / `max_lines` | `int \| None` | `None` | Line limits for `BOUNDED`. |
| `on_change` | handler | `None` | Fired on **every** text change; `e.data` is the text. |

Behavior and gotchas:

- Patterns use the **Dart `RegExp`** engine (ECMAScript-style, `multiLine` on). Use `(?<name>...)` instead of Python's `(?P<name>...)`, and raw strings (`r"..."`) in Python.
- Patterns or colors that fail to parse are silently skipped.
- **The first matching rule wins** for each character: a character already colored by an earlier rule is not recolored by later ones. Put your most specific rules (strings, comments) **first** and general rules (identifiers) **last**. This is the opposite of the previous `CodeEditor` engine, where later rules overrode earlier ones.
- Rules are re-compiled only when the list changes; ordinary typing never recompiles regexes.
- In incremental mode every line is highlighted independently, so multi-line constructs (block comments, triple-quoted strings) cannot be highlighted. Use `FletCodeEditor` for those.
- The font is fixed to Consolas, size 12. There are no `font_*` or color properties.

```python
import flet as ft
import flet_code_editor_dsl as ce

RULES = [
    ce.HighlightRule(r"#.*", "#6A9955"),                      # comments first
    ce.HighlightRule(r'"[^"\n]*"', "#CE9178"),                # strings
    ce.HighlightRule(r"\b(?:let|if|else)\b", "#C586C0"),      # keywords
    ce.HighlightRule(r"\b\d+(?:\.\d+)?\b", "#B5CEA8"),        # numbers
]

def main(page: ft.Page):
    page.add(
        ce.FletCodeField(
            value='let x = 1  # one',
            rules=RULES,
            vertical_mode=ce.VerticalMode.BOUNDED,
            min_lines=3,
            max_lines=10,
            width=500,
        )
    )

ft.run(main)
```

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
    folds=[ce.FoldRule("if", "}")],            # fold from `if` to a line starting with `}`
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

    editor = ce.FletCodeEditor(
        value=SAMPLE,
        language=LANG.to_json(),
        default_color="#D4D4D4",
        background_color="#1E1E1E",
        font_family="Consolas",
        font_size=15,
        line_numbers=True,
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
log_view = ce.FletCodeEditor(
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

### 6. Switching languages from a dropdown

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

`flet-code-editor-dsl` is not a pure-Python package. Its widgets are written in Dart/Flutter and must be **compiled into the Flet client**. The stock Flet client does not include them.

1. **Declare the library in your app's `pyproject.toml`** under `[project] dependencies`.
2. **Build your app once** with `flet build <platform>`.
3. **Run normally afterwards.** After the first build, the controls also work with `flet run` as long as `pyproject.toml` still declares the library.

> **Key requirement:** if the library is only installed with `pip` and not declared in `pyproject.toml`, Flet will not include the extension and the controls will not appear.

| Change | Rebuild needed? |
|--------|-----------------|
| Editing Python code, `value`, `language` / `Language(...)`, colors, fonts, flags, sizes, layout | No — sent to the client at runtime. |
| Updating `flet-code-editor-dsl` to a version whose Dart code changed (for example when upgrading to 0.2.0 from the previous API) | **Yes** |
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

`flet build` detects the Flutter package bundled in `flutter/flet_code_editor_dsl/` and adds it to the generated Flutter project automatically. A Flutter SDK is required; Flet downloads one if missing. The extension registers two control types — `FletCodeEditor` and `FletCodeField` — in `extension.dart`.

---

## Project Structure

```text
flet-code-editor-dsl/
├── README.md
├── LICENSE
├── FUNDING.yml
├── .gitignore
├── pyproject.toml
└── src/
    ├── flet_code_editor_dsl/
    │   ├── __init__.py                    # Public exports
    │   ├── flet_code_editor_dsl.py        # FletCodeEditor, FletCodeField, HighlightRule, VerticalMode
    │   └── language.py                    # Language DSL dataclasses + to_json()
    └── flutter/
        ├── __init__.py
        └── flet_code_editor_dsl/
            ├── pubspec.yaml               # Flutter package (v0.2.0)
            └── lib/
                ├── flet_code_editor_dsl.dart      # Exports Extension
                └── src/
                    ├── extension.dart             # Maps control types to widgets
                    ├── code_editor.dart           # FletCodeEditor widget (re_editor)
                    ├── flet_code_editor_dsl.dart  # FletCodeField widget (regex, per-line cache)
                    └── tokenizer.dart             # CodeLanguage lexer, LineHighlighter, FoldAnalyzer
```

| File | Responsibility |
|------|----------------|
| `flet_code_editor_dsl.py` | Declares the two Flet controls, `HighlightRule` and `VerticalMode`. |
| `language.py` | Declarative description of a language; produces the JSON consumed by Dart. |
| `extension.dart` | Registers `FletCodeField` and `FletCodeEditor` with Flet. |
| `code_editor.dart` | Editor widget: value sync and debounce, language parsing, sizing logic, line numbers, fold indicator. |
| `tokenizer.dart` | `CodeLanguage.fromJson`, the stateful lexer (`lexLine`), the cached `LineHighlighter` and the `FoldAnalyzer`. |
| `flet_code_editor_dsl.dart` (Flutter) | `FletCodeField` widget and its per-line cached regex controller. |
| `pyproject.toml` | Packaging metadata (setuptools). Includes everything under the `flutter.flet_code_editor_dsl` package (`**/*`, i.e. `pubspec.yaml` and `lib/`) as package data so `flet build` can find the Flutter code. |

> `__pycache__/`, `*.pyc` and `*.egg-info/` are generated automatically (by Python and by `pip install -e .` / the build) and are not part of the source. Keep them out of the repository with a `.gitignore`:
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

- **No nested block comments.** The first end marker closes a block comment.
- **Error checks are per line.** Unmatched brackets are not tracked across lines; unterminated-string checking does not apply to multi-line strings.
- **Error messages are not shown yet.** Errors are drawn as underlines only (no tooltips).
- **Folding is line-based.** It is not aware of strings and comments, and markers are only recognized at the start of a line.
- **`FoldRule` needs `end` or `length`** to produce a region (a bare start marker folds nothing).
- **No autocompletion, auto-indent or search UI** is provided by the DSL.
- **`FletCodeField` is regex-based**: no multi-line constructs in incremental mode, first-rule-wins, fixed font.
- **Colors are hex strings** (`#RRGGBB` / `#AARRGGBB`), not `ft.Colors.*` values.
- **Debounced value.** `editor.value` on the Python side may lag by up to `debounce_ms` behind what is on screen.
- **First build required.** As with all Flet extensions, the controls are not available in the stock Flet client.

## Troubleshooting

| Symptom | Likely cause and fix |
|---------|----------------------|
| "Unknown control" error or the editor does not appear | The library is not declared in `pyproject.toml`, or the app was not built with it. Add it to `dependencies` and run `flet build`. |
| Error after upgrading (`CodeEditor`, `rule`, `rules_json` not found) | These were removed in 0.2.0. See [Migration](#whats-new-in-020--migration-from-the-previous-api). Rebuild the app. |
| The editor is tiny | `width_level` / `height_level` default to 13 (of 30). Set `expand=True`, `width`/`height`, or levels up to 30. |
| No colors at all | `language` is empty or not valid JSON — make sure you passed `Language(...).to_json()` (a string), not the object. Also check `syntax_highlighting=True`. |
| Text is hard to see on a dark background | Set `default_color` (for example `"#D4D4D4"`) together with `background_color`. |
| Function calls look like normal names | `TokenColors.function` is not set. |
| A word is not highlighted as a keyword | The word was not an exact whole-word match (case, or it contains non-identifier characters). Use `case_insensitive=True`, or `identifier_extra` for dashed words. |
| Error underlines do not appear | `Language.errors` is `None`, or `show_errors=False`, or `syntax_highlighting=False`. |
| Red underline under every variable | `unknown_words=True` flags everything not in `words`/`allowed_words`. Add the names to `allowed_words` or turn it off. |
| No fold markers | `code_folding=False`, or the language has no `FoldRule` (with `end` or `length`) and `fold_by_indent=False`. |
| `on_change` seems late | It is debounced by `debounce_ms` (default 150 ms). Lower it, or set `0`. |
| Colors look different from what I typed | Colors are `#RRGGBB` / `#AARRGGBB`; `AA` is the **first** pair. Named colors are not supported. |
| `FletCodeField` rule has no effect | An earlier rule already colored those characters (first match wins), or the regex is invalid for Dart. |
| Changes made from Python are not visible | Call `editor.update()` after modifying a property. |
| `pip install` from GitHub fails | Confirm Git is installed, the URL is correct, and (private repos) that you are authenticated. |

## Contributing

Contributions are welcome.

1. Fork the repository.
2. Create a feature branch: `git checkout -b feature/my-feature`.
3. Commit your changes with clear messages.
4. Push the branch and open a Pull Request describing the change and its motivation.

Please open an issue first for larger changes or new features so the design can be discussed.

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
