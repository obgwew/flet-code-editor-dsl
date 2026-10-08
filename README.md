# flet-code-editor-dsl

> A code editor control for [Flet](https://flet.dev) with regex-based syntax highlighting, optional line numbers, toggleable colors and configurable scrolling.

![Python](https://img.shields.io/badge/python-%3E%3D3.10-blue)
![Flet](https://img.shields.io/badge/flet-%3E%3D0.85.2-informational)
![License](https://img.shields.io/badge/license-Apache%202.0-blue)

---

## Table of Contents

1. [Overview](#overview)
2. [Features](#features)
3. [Requirements](#requirements)
4. [Installation](#installation)
5. [Quick Start](#quick-start)
6. [API Reference](#api-reference)
7. [Line Numbers](#line-numbers)
8. [Enabling and Disabling Colors](#enabling-and-disabling-colors)
9. [Scrolling and Size Modes](#scrolling-and-size-modes)
10. [Controlling the Editor at Runtime](#controlling-the-editor-at-runtime)
11. [Complete Example](#complete-example)
12. [Important: First Build Required](#important-first-build-required)
13. [Building Your App](#building-your-app)
14. [Project Structure](#project-structure)
15. [Known Limitations](#known-limitations)
16. [Troubleshooting](#troubleshooting)
17. [Contributing](#contributing)
18. [License](#license)

---

## Overview

`flet-code-editor-dsl` is a Flet extension that embeds code editors for Flutter. You describe how text is colored with a list of `HighlightRule` objects, each one a regular expression paired with a color. Two controls are provided:

| Control | Built on | Use it when |
|---------|----------|-------------|
| **`FletCodeEditor`** (recommended) | [`re_editor`](https://pub.dev/packages/re_editor), a custom editor that lays out and paints each line independently and builds only the visible lines. Highlighting uses a hand-written **tokenizer** (no regex), configured with `Language`. | You edit large scripts, or typing must stay fast. |
| `FletCodeField` | Flutter `TextField` ([`code_text_field`](https://pub.dev/packages/code_text_field)) with per-line highlight caching | Small texts, or you want the platform's native text field behavior. |

## Features

- Native Flutter rendering through the Flet extension mechanism.
- Regex-based highlighting rules defined from Python.
- **Line numbers** that can be shown or hidden.
- **Colors** that can be enabled or disabled without losing your rules.
- **Scroll modes**: fixed size, bounded growth, or unlimited growth, plus horizontal scrolling or line wrapping.
- `on_change` event for reading the current text.
- Inherits standard layout properties from `ft.LayoutControl` (`width`, `height`, `expand`, `margin`, etc.).

## Requirements

| Component | Version |
|-----------|---------|
| Python    | `>= 3.10` |
| Flet      | `>= 0.85.2` |
| Dart SDK  | `>= 3.3.0 < 4.0.0` |
| Flutter   | A version compatible with Flet 0.85 |

> **Note:** Because this package contains a Flutter extension, your app must declare it in `pyproject.toml` and be built once with `flet build`. See [Important: First Build Required](#important-first-build-required).

---

## Installation

### From PyPI

```bash
pip install flet-code-editor-dsl
```

Declare it in your app's `pyproject.toml`:

```toml
[project]
name = "my-flet-app"
version = "0.1.0"
requires-python = ">=3.10"
dependencies = [
  "flet",
  "flet-code-editor-dsl",
]
```

### From GitHub

```bash
pip install "git+https://github.com/obgwew/flet-code-editor-dsl.git"
```

```toml
dependencies = [
  "flet",
  "flet-code-editor-dsl @ git+https://github.com/obgwew/flet-code-editor-dsl.git",
]
```

Append `@<branch|tag|commit>` to the URL to pin a version.

### Local editable install

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
['FletCodeEditor', 'FletCodeField', 'HighlightRule', 'VerticalMode']
```

---

## Quick Start

```python
import flet as ft
from flet_code_editor_dsl import FletCodeField, HighlightRule


def main(page: ft.Page):
    editor = FletCodeField(
        value="let x = 42",
        rules=[
            HighlightRule(pattern=r"\b(let|if|else)\b", color="#C586C0"),
            HighlightRule(pattern=r"\d+", color="#B5CEA8"),
        ],
        height=300,
    )
    page.add(editor)


ft.run(main)
```

### `FletCodeEditor`

```python
import flet as ft
from flet_code_editor_dsl import (
    FletCodeEditor, Language, WordGroup, StringRule, BlockComment, Sigil, TokenColors,
)

LANG = Language(
    words=[WordGroup(["let", "if", "else", "while", "return"], "#C586C0")],
    line_comments=["#"],
    block_comments=[BlockComment("/*", "*/")],
    strings=[StringRule('"'), StringRule("'")],
    sigils=[Sigil("$", "#9CDCFE")],
    colors=TokenColors(
        comment="#6A9955", string="#CE9178", escape="#D7BA7D",
        number="#B5CEA8", function="#DCDCAA", operator="#D4D4D4",
    ),
)


def main(page: ft.Page):
    page.add(
        FletCodeEditor(
            value='let x = 42  /* note */\nprint("hi\\n", $name)',
            language=LANG.to_json(),
            default_color="#D4D4D4",
            background_color="#1E1E1E",
            height=300,
        )
    )


ft.run(main)
```

---

## API Reference

```python
from flet_code_editor_dsl import FletCodeField, HighlightRule, VerticalMode
```

### `HighlightRule`

| Field | Type | Description |
|-------|------|-------------|
| `pattern` | `str` | Regular expression selecting the text to color. Uses the Dart `RegExp` engine. |
| `color` | `str` | `#RRGGBB` or `#AARRGGBB`. |

`HighlightRule` is used by **`FletCodeField`** only. `FletCodeEditor` uses a tokenizer described by [`Language`](#tokenizer-and-language) instead of regex rules.

### `FletCodeEditor`

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `value` | `str` | `""` | The text. Setting it from Python replaces the editor content. |
| `language` | `str` | `""` | Tokenizer configuration: `Language(...).to_json()`. Empty = no highlighting. |
| `line_numbers` | `bool` | `True` | Show line numbers. |
| `syntax_highlighting` | `bool` | `True` | `False` disables all colors (rules are kept). |
| `wrap` | `bool` | `False` | `False`: horizontal scrolling. `True`: long lines wrap. |
| `read_only` | `bool` | `False` | Disable editing. |
| `vertical_mode` | `VerticalMode` | `FIXED` | `FIXED`, `BOUNDED` or `UNLIMITED` (see below). |
| `min_lines` / `max_lines` | `int \| None` | `None` | Limits for `BOUNDED` (fall back to 1 and 10). |
| `font_family` | `str` | `"Consolas"` | Editor font. |
| `font_size` | `float` | `12.0` | Font size. |
| `default_color` | `str \| None` | `None` | Color of text not matched by any rule (library default if `None`). |
| `background_color` | `str \| None` | `None` | Editor background (library default if `None`). |
| `debounce_ms` | `int` | `150` | Delay before the text is sent back to Python and `on_change` fires. Keeps typing fast in large documents. `value` on the Python side can lag by this delay. |
| `show_errors` | `bool` | `True` | Show error underlines (needs `Language(errors=ErrorRules(...))`). |
| `code_folding` | `bool` | `True` | Show fold markers (needs `Language(folds=[...])` or `fold_by_indent`). |
| `width_level` / `height_level` | `int \| None` | `13` | Visible size of the editor box, 1 to 30. See [Visible size](#visible-size). |
| `on_change` | handler | `None` | Called with the new text in `e.data` (after `debounce_ms`). |

Vertical modes for `FletCodeEditor`: `FIXED` fills the given height (set `height`, or `expand=True` inside a bounded parent) and scrolls inside. `BOUNDED` and `UNLIMITED` size the editor from the number of **lines** (wrapped lines are not counted), between `min_lines` and `max_lines` or without limit. The height is computed from the font metrics, so it can be off by a few pixels.

### `FletCodeField`

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `value` | `str` | `""` | The text shown in the editor. |
| `rules` | `list[HighlightRule]` | `[]` | Regex highlighting rules (single-line). |
| `line_numbers` | `bool` | `True` | Show a line-number gutter. |
| `syntax_highlighting` | `bool` | `True` | When `False`, `rules` are ignored and no colors are applied. |
| `incremental_highlighting` | `bool` | `True` | Highlight line by line and re-highlight only the edited line. Set `False` to highlight the whole text at once (needed for patterns that span several lines). See [Performance](#performance). |
| `wrap` | `bool` | `False` | `False`: long lines scroll horizontally. `True`: long lines wrap. |
| `vertical_mode` | `VerticalMode` | `FIXED` | `FIXED`, `BOUNDED` or `UNLIMITED`. See [Scrolling and Size Modes](#scrolling-and-size-modes). |
| `min_lines` | `int \| None` | `None` | Minimum visible lines in `BOUNDED` mode (falls back to 1). |
| `max_lines` | `int \| None` | `None` | Maximum visible lines in `BOUNDED` mode (falls back to 10). |
| `on_change` | `ft.ControlEventHandler \| None` | `None` | Called whenever the text changes. |

All `ft.LayoutControl` properties (`width`, `height`, `expand`, `margin`, `visible`, `opacity`, ...) are supported.

### Color format

| Format | Example | Meaning |
|--------|---------|---------|
| `#RRGGBB` | `#FF8800` | Opaque color (alpha `FF` is added automatically). |
| `#AARRGGBB` | `#80FF8800` | Color with an explicit alpha channel. |

---

## Line Numbers

```python
FletCodeField(line_numbers=True)    # default: gutter with line numbers
FletCodeField(line_numbers=False)   # no gutter
```

## Enabling and Disabling Colors

`syntax_highlighting` switches coloring on or off while keeping your `rules`, so you can toggle it back at any time.

```python
editor = FletCodeField(rules=[...], syntax_highlighting=False)   # plain text

editor.syntax_highlighting = True
editor.update()
```

## Scrolling and Size Modes

Vertical behavior is controlled by `vertical_mode`; horizontal behavior by `wrap`.

| `vertical_mode` | Behavior |
|-----------------|----------|
| `FIXED` (`"fixed"`) | The editor fills the height it is given (`height=...`, or `expand=True` inside a `Column`) and scrolls internally. |
| `BOUNDED` (`"bounded"`) | The editor grows with the text between `min_lines` and `max_lines`, then scrolls. |
| `UNLIMITED` (`"unlimited"`) | The editor grows with the text without limit. It does not scroll by itself, so place it inside a scrollable parent. |

| `wrap` | Behavior |
|--------|----------|
| `False` | Long lines are not wrapped; the editor scrolls horizontally. |
| `True` | Long lines wrap to the next visual line. |

```python
# Fixed height with internal scrolling
FletCodeField(height=300, vertical_mode="fixed")

# Between 5 and 15 lines, then scrolls
FletCodeField(vertical_mode="bounded", min_lines=5, max_lines=15)

# Grows without limit inside a scrollable column
ft.Column([FletCodeField(vertical_mode="unlimited", wrap=True)], scroll=ft.ScrollMode.AUTO)
```

> `FIXED` mode needs a bounded height. Without `height` or a bounded parent, Flutter reports an unbounded-constraints error.

---

## Tokenizer and `Language`

`FletCodeEditor` does not use regular expressions. It scans each line with a hand-written, stateful lexer, and you describe the language with `Language`:

```python
Language(
    words=[WordGroup(["let", "if"], "#C586C0")],   # exact words sharing a color
    line_comments=["#", "//"],
    block_comments=[BlockComment("/*", "*/")],      # may span lines
    strings=[StringRule('"'), StringRule('"""', multiline=True)],
    sigils=[Sigil("$", "#9CDCFE"), Sigil("@", "#4EC9B0")],   # $name, @user
    numbers=True,
    operators="+-*/%=<>!&|^~?:",
    punctuation="(){}[],;.",
    identifier_extra="",          # e.g. "-" to allow my-command
    case_insensitive=False,
    colors=TokenColors(comment=..., string=..., escape=..., number=...,
                       function=..., identifier=..., operator=..., punctuation=...),
)
```

| Field | Meaning |
|-------|---------|
| `words` | Groups of exact words (keywords, constants, commands), each group with one color. |
| `line_comments` | Prefixes that comment out the rest of the line. |
| `block_comments` | Start/end pairs; they can span several lines. |
| `strings` | `StringRule(open, close=None, escape="\\", multiline=False)`. The escape character and the character after it are colored with `colors.escape`. An unterminated single-line string ends at the end of the line. |
| `sigils` | A prefix followed by a name, colored as one token (`$var`, `@user`). |
| `numbers` | Integers, decimals, exponents, `_` separators and `0x` / `0b` / `0o` literals. |
| `operators` / `punctuation` | Character sets. Runs of operator characters form one token (`==`, `&&`). |
| `identifier_extra` | Extra characters allowed inside names. Letters from any script (including Arabic) are accepted. |
| `colors` | Colors for the built-in kinds. `function` colors a name directly followed by `(`. `None` keeps the default text color. |

**Order of matching** at each position: whitespace, line comments, block comments, strings, sigils, numbers, words/identifiers, operators, punctuation. Within a kind, the longest opener wins (`"""` before `"`). A word listed in `words` always wins over the `function` or `identifier` colors.

Pass the result with `language=LANG.to_json()`. Changing `language` at runtime repaints the editor; the editor view may reset its scroll position when you do.

---

## Visible size

`width_level` and `height_level` set the **visible box** of the editor (not its inner content, which scrolls). Each is a number from 1 to 30:

```text
size = level / 30 x available space        (minimum 48 px)
```

| Level | Result |
|-------|--------|
| 30 | Covers all the available space |
| 13 (default) | About 43% of the available space |
| 1 | A small box (about 3%, at least 48 px) |

The two levels are independent, so you can enlarge only the width or only the height. The available space is the parent's size (or the screen, when the parent is unbounded).

```python
FletCodeEditor(width_level=20, height_level=8)
```

The levels are ignored when you set `width`, `height` or `expand` yourself, and `height_level` is ignored in `bounded`/`unlimited` modes (the height then follows the number of lines).

## Error underlines

Errors are **optional and user-defined**. Without `errors`, nothing is checked. The highlighter colors text as usual, and the checks only add a red underline under the faulty part:

```python
from flet_code_editor_dsl import ErrorRules, BracketPair

Language(
    ...,
    errors=ErrorRules(
        unterminated_strings=True,                       # "text without a closing quote
        brackets=[BracketPair("(", ")"), BracketPair("[", "]")],   # unmatched in a line
        unknown_words=True,                              # names not in `words` / `allowed_words`
        allowed_words=["print", "len"],
        forbidden_words=["goto"],                        # always flagged
        color="#F44747",
        wavy=True,                                       # False = straight underline
    ),
)
```

All checks work **inside one line**, so brackets must balance within the same line (do not enable `brackets` for `{` `}` blocks that span lines). Hover messages are not shown yet; only the underline. Turn the underlines off at runtime with `show_errors=False`.

## Code folding

Foldable regions are defined by you in `Language`, which suits small or unusual DSLs:

```python
from flet_code_editor_dsl import FoldRule

Language(
    ...,
    folds=[
        FoldRule("class", "end"),       # from a line starting with `class` to a line starting with `end`
        FoldRule("on", length=5),       # the 5 lines after a line starting with `on`
        FoldRule("{", "}"),
    ],
    fold_by_indent=False,               # True: also fold by indentation
)
```

- A marker matches at the beginning of a line (after indentation). Word markers match whole words only (`end` does not match `endpoint`).
- Start/end pairs can be nested.
- `length` folds a fixed number of lines after the start line.
- Without `folds` and `fold_by_indent`, no fold markers are shown. Turn folding off at runtime with `code_folding=False`.
- Whether the closing line stays visible when a region is folded is decided by `re_editor`.

---

## Performance

**`FletCodeEditor`** does not use a `TextField`. Each line is laid out and painted on its own and only the visible lines are built, so editing one line does not re-render the whole document. This is the recommended control for large scripts.

The rest of this section is about **`FletCodeField`**, which is a `TextField` that Flutter paints as a single block. By default (`incremental_highlighting=True`) the text is highlighted **line by line** and the result of every line is cached by its content. When you type, only the edited line is re-highlighted; all unchanged lines reuse their cached colors. Rules are also compiled only when `rules` or `syntax_highlighting` change, not on every keystroke.

Consequences:

- Each rule is matched **within a single line**. A pattern that spans lines (for example a `/* ... */` block comment) will not match. Set `incremental_highlighting=False` to match against the whole text, at the cost of re-highlighting everything on each change.
- When matches from several rules overlap, the **earlier rule in the list wins** for each character.
- Flutter still lays out and paints the editor as a single text block; the saving comes from not re-running the regexes and not rebuilding spans for unchanged lines.

---

## Controlling the Editor at Runtime

### Reading the text

```python
def on_change(e):
    print("Current text:", e.data)

editor = FletCodeField(on_change=on_change)
```

### Setting the text or changing options

```python
editor.value = "new content"
editor.line_numbers = False
editor.syntax_highlighting = False
editor.vertical_mode = "bounded"
editor.max_lines = 20
editor.update()
```

### Updating rules

```python
editor.rules = [HighlightRule(pattern=r"\bTODO\b", color="#FFCC00")]
editor.update()
```

---

## Complete Example

```python
import flet as ft
from flet_code_editor_dsl import FletCodeField, HighlightRule

SAMPLE = '''\
# Example program
let total = (price * 3) + 12
if (total > 100) {
    print("expensive")
} else {
    print("cheap")
}
'''

RULES = [
    HighlightRule(r"\b(let|if|else)\b", "#C586C0"),
    HighlightRule(r"\b\d+(?:\.\d+)?\b", "#B5CEA8"),
    HighlightRule(r'"[^"\n]*"', "#CE9178"),
    HighlightRule(r"#.*", "#6A9955"),
]


def main(page: ft.Page):
    page.title = "flet-code-editor-dsl demo"
    page.theme_mode = ft.ThemeMode.DARK

    def toggle(prop):
        def handler(e):
            setattr(editor, prop, e.control.value)
            editor.update()
        return handler

    def on_mode(e):
        editor.vertical_mode = e.control.value
        editor.update()

    editor = FletCodeField(value=SAMPLE, rules=RULES, height=300)

    page.add(
        ft.Row([
            ft.Switch(label="Line numbers", value=True, on_change=toggle("line_numbers")),
            ft.Switch(label="Colors", value=True, on_change=toggle("syntax_highlighting")),
            ft.Switch(label="Wrap", value=False, on_change=toggle("wrap")),
        ]),
        editor,
    )


ft.run(main)
```

---

## Important: First Build Required

This package is not pure Python. Its editor widget is written in Dart/Flutter and must be **compiled into the Flet client** before the control can be displayed.

1. **Declare the library in your app's `pyproject.toml`** under `[project] dependencies`.
2. **Build your app once** with `flet build <platform>`.
3. **Run normally afterwards.** After the first build the control also works with `flet run`, as long as `pyproject.toml` still declares the library.

| Change | Rebuild needed? |
|--------|-----------------|
| Python code, `value`, `rules`, `line_numbers`, `syntax_highlighting`, `wrap`, `vertical_mode`, layout | No |
| Updating `flet-code-editor-dsl` to a version whose Dart code changed | Yes |
| Upgrading Flet to a new major/minor version | Yes |
| Adding or removing other Flet extensions | Yes |

---

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

---

## Project Structure

```text
flet-code-editor-dsl/
├── pyproject.toml
├── README.md
└── src/
    ├── flet_code_editor_dsl/
    │   ├── __init__.py
    │   ├── flet_code_editor_dsl.py        # FletCodeEditor, FletCodeField, HighlightRule, VerticalMode
    │   └── language.py                    # Language, WordGroup, StringRule, ...
    └── flutter/
        └── flet_code_editor_dsl/
            ├── pubspec.yaml
            └── lib/
                ├── flet_code_editor_dsl.dart
                └── src/
                    ├── extension.dart             # registers both controls
                    ├── code_editor.dart           # FletCodeEditor (re_editor)
                    ├── tokenizer.dart             # lexer + per-line cache
                    └── flet_code_editor_dsl.dart  # FletCodeField (TextField)
```

Generated files such as `*.egg-info/`, `__pycache__/`, `pubspec.lock`, `.dart_tool/`, `package_config.json` and `package_graph.json` should not be committed; add them to `.gitignore`.

---

## Known Limitations

- **Single-line rules by default.** See [Performance](#performance).
- **Regex highlighting only.** There is no language parsing, so delimiters inside strings or comments are not treated specially.
- **Dart regex semantics.** Patterns must be valid for Dart's `RegExp`; avoid Python-only syntax such as `(?P<name>...)`.
- **`FletCodeField` font.** It uses a fixed style (`Consolas`, size 12). Use `FletCodeEditor` to change font and size.
- **`FletCodeEditor` and multi-line constructs.** Opening a block comment or multi-line string on one line changes the state of the lines below. Those lines are recolored when the editor repaints them; if re_editor keeps already-painted lines as they are, they may keep their old colors until they are redrawn (scrolling, editing them). Test this in your app.
- **Errors and folding.** Error checks work per line; fold markers ignore strings and comments (a `{` inside a string still counts).
- **`FletCodeEditor` input.** It implements its own text input handling; test Arabic (RTL) input and mobile keyboards in your app.
- **First build required.** The control is not available in the stock Flet client.

## Troubleshooting

| Symptom | Likely cause and fix |
|---------|----------------------|
| The editor does not appear, or an "unknown control" error is shown | The library is not declared in `pyproject.toml`, or the app was not rebuilt. Add it to `dependencies` and run `flet build`. |
| Unbounded height/constraints error | `vertical_mode="fixed"` without a bounded height. Set `height`, use `expand=True` inside a `Column`, or switch to `bounded`/`unlimited`. |
| A rule has no effect | The regex may be invalid for Dart, or `syntax_highlighting` is `False`. |
| Changes made from Python are not visible | Call `editor.update()` after modifying a property. |
| Compile error in `code_editor.dart` or `tokenizer.dart` | `re_editor` APIs change between versions (`CodeLineSpanBuilder`, `CodeLineEditingController`); check the version in `pubspec.yaml` and the error message. |
| No error underlines or fold markers | `Language.errors` / `Language.folds` is not set, or `show_errors` / `code_folding` is `False`. |
| `FletCodeEditor` shows no colors | `language` is empty or not valid JSON, or `syntax_highlighting=False`. Pass `Language(...).to_json()`. |
| Compile error in `CodeField` after upgrading | Parameter names depend on the `code_text_field` version; check `pubspec.yaml`. |

## Contributing

1. Fork the repository.
2. Create a feature branch: `git checkout -b feature/my-feature`.
3. Commit your changes with clear messages.
4. Push the branch and open a Pull Request.

Please open an issue first for larger changes.

## License

Licensed under the **Apache License, Version 2.0**. See the `LICENSE` file for the full text.

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
