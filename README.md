# flet-code-editor-dsl

Native Flutter code editors for [Flet](https://flet.dev), with syntax highlighting, error underlines, code folding, autocomplete and touch-screen helpers.

[![PyPI](https://img.shields.io/pypi/v/flet-code-editor-dsl)](https://pypi.org/project/flet-code-editor-dsl/)
![Python](https://img.shields.io/badge/python-%3E%3D3.10-blue)
![Flet](https://img.shields.io/badge/flet-%3E%3D0.85.2-informational)
![License](https://img.shields.io/badge/license-Apache%202.0-blue)

The package ships two controls built on the same editor. They differ only in how they highlight text:

| Control | Highlighting | You configure it with | Best for |
|---------|--------------|-----------------------|----------|
| **`EditorTokens`** | Hand-written tokenizer, no regex | A `Language` object | Real languages, multi-line strings and comments |
| **`EditorRegex`** | Regular expressions, matched line by line | `rules`, `error_rules`, `folds` | Quick coloring when you already have patterns |

```python
import flet_code_editor_dsl as ce

lang = ce.Language(
    words=[ce.WordGroup(["let", "if", "else"], "#C586C0")],
    line_comments=["#"],
    strings=[ce.StringRule('"')],
    colors=ce.TokenColors(comment="#6A9955", string="#CE9178", number="#B5CEA8"),
)
editor = ce.EditorTokens(language=lang.to_json(), expand=True)
```

> **This package contains a Flutter extension.** It only works in an app built with `flet build`, and the app must declare the package in its `pyproject.toml`. See [Installation](#installation).

## Features

- Native Flutter rendering through the Flet extension mechanism.
- Two engines with the same feature set: a declarative `Language` tokenizer (**no regex**) or regex rules.
- Virtualized rendering: only visible lines are built and highlighted, with per-line caching.
- Correct multi-line state (block comments, multi-line strings) in the tokenizer engine.
- Strings with escapes, custom delimiters and optional multi-line support.
- Line and block comments, sigils (`$name`, `@user`), numbers (decimal, float, exponent, `_`, `0x`/`0b`/`0o`) and function-call detection.
- Optional error underlines (wavy or straight) and user-defined folding regions.
- Line numbers, word wrap, read-only mode, font family and size, text and background colors.
- Autocomplete from your own word list, and a headless search helper.
- **Touch helpers:** cut/copy/paste menu at the caret, optional toolbar with a cursor pad, long-press magnifier, page/editor scroll hand-off.
- Standard `ft.LayoutControl` properties (`width`, `height`, `expand`, `margin`, `visible`, `opacity`, ...).

## Contents

- [Features](#features)
- [Installation](#installation)
- [Quick start](#quick-start)
- [Choosing a control](#choosing-a-control)
- [Sizing the editor](#sizing-the-editor)
- [Properties](#properties)
- [Reading and writing text](#reading-and-writing-text)
- [Highlighting with `EditorRegex`](#highlighting-with-editorregex)
- [Highlighting with `EditorTokens` (the `Language` DSL)](#highlighting-with-editortokens-the-language-dsl)
- [Complete examples](#complete-examples)
- [Autocomplete](#autocomplete)
- [Search helper](#search-helper)
- [Mobile and touch](#mobile-and-touch)
- [Performance notes](#performance-notes)
- [Building your app](#building-your-app)
- [Developing locally](#developing-locally)
- [Known limitations](#known-limitations)
- [Troubleshooting](#troubleshooting)
- [Changelog](#changelog)
- [Migrating from older versions](#migrating-from-older-versions)
- [Sponsors](#sponsors)
- [License](#license)

---

## Installation

Requirements:

| Component | Version |
|-----------|---------|
| Python | `>= 3.10` |
| Flet (Python) | `>= 0.85.2` |
| Flet (Flutter side) | `flet: ^0.85.2` |
| Dart SDK | `>= 3.3.0 < 4.0.0` (the tokenizer uses Dart 3 records) |
| Flutter SDK | Needed to build. Flet downloads one if it is missing. |
| `re_editor` | `0.10.0`, bundled in `vendor/re_editor`. Nothing to install. |
| Git | Only for installing from GitHub. |

Declare the package in your **app's** `pyproject.toml`:

```toml
[project]
dependencies = [
  "flet>=0.85.2",
  "flet-code-editor-dsl==0.4.0",
]
```

Pin an exact version for reproducible builds. Installing with `pip` alone is not enough: `flet build` only includes extensions that are listed in `dependencies`.

From GitHub instead of PyPI:

```toml
"flet-code-editor-dsl @ git+https://github.com/obgwew/flet-code-editor-dsl.git@v0.4.0"
```

Check the install:

```bash
python -c "import flet_code_editor_dsl as m; print(m.__all__)"
```

## Quick start

```python
import flet as ft
import flet_code_editor_dsl as ce

LANG = ce.Language(
    words=[
        ce.WordGroup(["let", "if", "else", "while", "return"], "#C586C0"),
        ce.WordGroup(["true", "false", "null"], "#569CD6"),
    ],
    line_comments=["#"],
    strings=[ce.StringRule('"')],
    colors=ce.TokenColors(
        comment="#6A9955", string="#CE9178", escape="#D7BA7D", number="#B5CEA8",
        function="#DCDCAA", identifier="#9CDCFE",
    ),
)


def main(page: ft.Page):
    page.theme_mode = ft.ThemeMode.DARK
    page.add(
        ce.EditorTokens(
            value='let x = add(1, 2)  # sum\nprint("done\\n")',
            language=LANG.to_json(),      # a JSON string, not the Language object
            default_color="#D4D4D4",
            background_color="#1E1E1E",
            expand=True,
        )
    )


ft.run(main)
```

The same with the regex engine:

```python
ce.EditorRegex(
    value='let x = add(1, 2)  # sum',
    rules=[
        ce.HighlightRule(r"#.*", "#6A9955"),                    # comments first
        ce.HighlightRule(r'"[^"\n]*"', "#CE9178"),
        ce.HighlightRule(r"\b(?:let|if|else)\b", "#C586C0"),
        ce.HighlightRule(r"\b\d+(?:\.\d+)?\b", "#B5CEA8"),
    ],
    default_color="#D4D4D4",
    background_color="#1E1E1E",
    expand=True,
)
```

Two things trip people up on first use:

1. `EditorTokens(language=...)` expects the **JSON string** from `Language(...).to_json()`.
2. Without `expand`, `width` or `height`, the editor is only `17/30` of the available space. See [Sizing](#sizing-the-editor).

---

## Choosing a control

Both controls share the same widget, so everything outside highlighting is identical.

| Feature | `EditorTokens` | `EditorRegex` |
|---------|:--------------:|:-------------:|
| Highlighting engine | Tokenizer (`Language`) | Regex (`HighlightRule`) |
| Multi-line strings / block comments | Yes (state carried across lines) | No (each line is highlighted alone) |
| Error underlines | Yes (`Language.errors`) | Yes (`error_rules`, regex based) |
| Code folding | Yes (`Language.folds`, `fold_by_indent`) | Yes (`folds`, `fold_by_indent`) |
| Line numbers, `wrap`, `read_only` | Yes | Yes |
| Fonts, colors, size levels, `vertical_mode` | Yes | Yes |
| `debounce_ms`, `on_change` | Yes | Yes |
| Autocomplete, mobile menu, toolbar, magnifier, `scroll_mode` | Yes | Yes |

Rule of thumb: use **`EditorTokens`** for real languages, especially with multi-line constructs. Use **`EditorRegex`** when you already have regular expressions or only need a few colors.

---

## Sizing the editor

Three mechanisms apply, in this order:

1. **Explicit layout.** `width`, `height` or `expand` win. `width` or `expand` disables `width_level`; `height`, `expand` or a `vertical_mode` other than `FIXED` disables `height_level`.
2. **Line-count height.** `vertical_mode="bounded"` or `"unlimited"` derives the height from the number of lines.
3. **Levels.** Otherwise the size is `level / 30` of the available space, with a minimum of 48 px. Values outside `1..30` are clamped. Both levels default to `17`.

```python
ce.EditorTokens(...)                                    # about 17/30 x 17/30
ce.EditorTokens(..., width_level=30, height_level=30)   # fills the space
ce.EditorTokens(..., expand=True)                       # fills the parent
ce.EditorTokens(..., width=600, height=400)             # fixed size
```

### Vertical modes

| Mode | Behavior |
|------|----------|
| `FIXED` (default) | Fills the height it is given and scrolls internally. |
| `BOUNDED` | Height follows the line count, clamped to `[min_lines, max_lines]` (defaults `1` and `10`), then scrolls. |
| `UNLIMITED` | Height follows the line count with no maximum. `min_lines` acts as a lower bound. Put it inside a scrollable parent. |

```python
# Chat-input style: starts at 3 lines, grows to 12, then scrolls
ce.EditorTokens(
    language=LANG.to_json(),
    vertical_mode=ce.VerticalMode.BOUNDED,
    min_lines=3, max_lines=12, width=500,
)

# Grows with its contents inside a scrollable page, with blank room after long lines
ce.EditorRegex(
    vertical_mode=ce.VerticalMode.UNLIMITED,
    min_lines=1,
    horizontal_scroll_padding=48,
    wrap=False,
)
```

---

## Properties

All properties exist on both controls unless noted. Standard `ft.LayoutControl` properties (`width`, `height`, `expand`, `margin`, `visible`, `opacity`, ...) are available too.

### Content and behavior

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `value` | `str` | `""` | Editor text. |
| `language` | `str` | `""` | **`EditorTokens` only.** JSON from `Language.to_json()`. Empty or invalid JSON means no highlighting, silently. |
| `line_numbers` | `bool` | `True` | Show the gutter. |
| `syntax_highlighting` | `bool` | `True` | Master switch for highlighting and error underlines. |
| `show_errors` | `bool` | `True` | Draw error underlines. |
| `code_folding` | `bool` | `True` | Show fold markers (needs folds or `fold_by_indent`). |
| `wrap` | `bool` | `False` | Soft-wrap long lines. |
| `horizontal_scroll_padding` | `float` | `0.0` | Blank room after the longest line when scrolling horizontally. |
| `read_only` | `bool` | `False` | Disable editing. Selection and scrolling still work. |
| `highlight_scope` | `str` | `"document"` | `"document"` re-highlights everything after an edit; `"current_line"` re-highlights only the edited line and keeps cached colors elsewhere. |
| `debounce_ms` | `int` | `150` | Delay before the text is sent to Python and `on_change` fires. |
| `on_change` | handler | `None` | `e.data` is the full text. |

### Appearance and size

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `font_family` | `str` | `"Consolas"` | Use a monospace font. |
| `font_size` | `float` | `16.0` | Logical pixels. |
| `default_color` | `str \| None` | `None` | Color of un-styled text. Set it whenever you set a dark `background_color`. |
| `background_color` | `str \| None` | `None` | Editor background. |
| `width_level`, `height_level` | `int \| None` | `17` | See [Sizing](#sizing-the-editor). |
| `vertical_mode` | `VerticalMode` | `FIXED` | `FIXED`, `BOUNDED`, `UNLIMITED`. |
| `min_lines`, `max_lines` | `int \| None` | `None` | Bounds for `BOUNDED`; `min_lines` also applies to `UNLIMITED`. |

### Autocomplete

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `autocomplete` | `bool` | `True` | Enable suggestions. Nothing appears until you supply `autocomplete_words`. |
| `autocomplete_words` | `list[str]` | `[]` | Your vocabulary. |
| `autocomplete_trigger` | `str` | `""` | Optional trigger prefix, for example `"$"`. |
| `remember_suggestions` | `bool` | `True` | Rank words you accepted earlier in this editor session first. |

### Touch

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `selection_menu` | `bool` | `True` | Cut/copy/paste menu at the caret. Android and iOS only. |
| `selection_menu_items` | `list[str]` | `["cut","copy","paste","select_all"]` | Also accepts `"undo"` and `"redo"`. |
| `mobile_controls` | `bool \| None` | `None` | Extra toolbar. `None` = automatic: **shown on Android/iOS, hidden elsewhere.** |
| `toolbar_items` | `list[str]` | all items | See [Mobile and touch](#mobile-and-touch). |
| `toolbar_position` | `ToolbarPosition` | `BOTTOM` | `BOTTOM` or `TOP`. |
| `cursor_pad` | `bool \| None` | `None` | Drag pad inside the toolbar. `None` = automatic (mobile). |
| `magnifier` | `bool \| None` | `None` | Magnifier on long press. `None` = automatic (mobile). |
| `magnifier_size`, `magnifier_zoom` | `float` | `110.0`, `1.6` | Diameter and zoom factor. |
| `scroll_mode` | `ScrollMode` | `EDITOR_FIRST` | Editor/page scroll hand-off. |

### `EditorRegex` only

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `rules` | `list[HighlightRule]` | `[]` | First matching rule wins per character. |
| `error_rules` | `list[ErrorPattern]` | `[]` | Matches are underlined as errors. |
| `error_color` | `str` | `"#F44747"` | Underline color. |
| `wavy` | `bool` | `True` | `False` for a straight underline. |
| `folds` | `list[FoldRule]` | `[]` | Folding regions. |
| `fold_by_indent` | `bool` | `False` | Also fold by indentation. |

### Colors

Every color is a hex string: `#RRGGBB` (opaque) or `#AARRGGBB`. Names and `ft.Colors.*` values are not accepted. Invalid or empty values are treated as "not set" instead of raising an error.

### Changing things at runtime

Assign the property, then call `update()`. No rebuild of the app is needed.

```python
editor.language = OTHER_LANG.to_json()   # EditorTokens
editor.rules = NEW_RULES                 # EditorRegex
editor.read_only = True
editor.background_color = "#0D1117"
editor.update()
```

Changing the language, rules, `syntax_highlighting`, `show_errors` or `code_folding` rebuilds the highlighter. The text is kept, but the scroll position may reset.

---

## Reading and writing text

```python
def on_change(e: ft.ControlEvent):
    print(e.data)          # the full text

editor = ce.EditorTokens(on_change=on_change, debounce_ms=300)
```

- Typing does not send every keystroke. After the user pauses for `debounce_ms`, the text is written to `editor.value` and `on_change` fires.
- `debounce_ms=0` sends immediately. Negative values count as `0`.
- Nothing is sent if the text did not actually change.
- `editor.value = "..."` followed by `editor.update()` replaces the content. Your own echo is ignored.
- Because of the debounce, `editor.value` can lag behind the screen by up to `debounce_ms`. Read the text from `on_change`, or lower the delay.

---

## Highlighting with `EditorRegex`

```python
@dataclass
class HighlightRule:
    pattern: str
    color: str
    ignore_case: bool = False

@dataclass
class ErrorPattern:
    pattern: str
    message: str = ""
    ignore_case: bool = False
```

- Each line is matched on its own and cached by line text.
- **The first matching rule wins** for each character. Put specific rules (comments, strings) first and general ones last.
- Zero-length matches are ignored.
- Patterns use the **Dart `RegExp`** engine. Use `(?<name>...)` rather than Python's `(?P<name>...)`, and raw strings in Python. A rule whose pattern or color fails to parse is skipped silently.
- Patterns cannot span lines, so multi-line comments and triple-quoted strings cannot be highlighted. Use `EditorTokens` for those.
- Rules are recompiled only when the list changes, never while typing.

```python
RULES = [
    ce.HighlightRule(r"//.*$", "#6A9955"),
    ce.HighlightRule(r'"(?:[^"\\]|\\.)*"?', "#CE9178"),
    ce.HighlightRule(r"\b(?:func|let|if|else|return)\b", "#C586C0"),
    ce.HighlightRule(r"\b\d+(?:\.\d+)?\b", "#B5CEA8"),
    ce.HighlightRule(r"\b[A-Za-z_]\w*(?=\()", "#DCDCAA"),      # function calls
]
ERRORS = [ce.ErrorPattern(r'"[^"\\]*(?:\\.[^"\\]*)*$', "Unterminated string")]

ce.EditorRegex(
    value='func main() {\n    print("hi\n}',
    rules=RULES,
    error_rules=ERRORS,
    folds=[ce.FoldRule("func", length=20)],
    fold_by_indent=True,
    vertical_mode=ce.VerticalMode.BOUNDED, min_lines=3, max_lines=10,
    width=500,
)
```

---

## Highlighting with `EditorTokens` (the `Language` DSL)

You describe what the language contains; the lexer handles escapes, multi-line state, numbers, identifiers, calls, sigils, operators and punctuation.

```python
from flet_code_editor_dsl import (
    Language, WordGroup, StringRule, BlockComment, Sigil,
    TokenColors, FoldRule, ErrorRules, BracketPair,
)
```

### `Language`

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `words` | `list[WordGroup]` | `[]` | Exact words grouped by color. |
| `line_comments` | `list[str]` | `[]` | Comment markers running to end of line (`"//"`, `"#"`, `"--"`). |
| `block_comments` | `list[BlockComment]` | `[]` | Multi-line comments. Not nested. |
| `strings` | `list[StringRule]` | `[]` | String literal styles. |
| `sigils` | `list[Sigil]` | `[]` | Prefix + name tokens (`$var`, `@user`). |
| `numbers` | `bool` | `True` | Recognize numeric literals. |
| `operators` | `str` | `"+-*/%=<>!&\|^~?:"` | Each character is an operator character. |
| `punctuation` | `str` | `"(){}[],;."` | Each character is punctuation. |
| `identifier_extra` | `str` | `""` | Extra characters allowed inside names, e.g. `"-"`. |
| `case_insensitive` | `bool` | `False` | Compare words ignoring case. |
| `colors` | `TokenColors` | `TokenColors()` | Colors of the built-in token kinds. |
| `folds` | `list[FoldRule]` | `[]` | Folding regions. |
| `fold_by_indent` | `bool` | `False` | Also fold by indentation. |
| `errors` | `ErrorRules \| None` | `None` | Error underlines. `None` turns every check off. |

### Building blocks

**`WordGroup(words, color)`**: whole-word matches only, so `end` does not match `endpoint`. Symbols such as `"->"` never match; use `operators` for those. If a word is in several groups, the last group wins.

**`StringRule(open, close=None, escape="\\", multiline=False)`**: the escape character plus the character after it forms an escape sequence, colored with `TokenColors.escape`. With `multiline=True`, an unclosed string continues on the next lines. The longest `open` is tried first, so `'"""'` beats `'"'` regardless of order.

```python
strings=[
    ce.StringRule('"'),
    ce.StringRule('"""', multiline=True),                    # Python docstrings
    ce.StringRule("`", multiline=True, escape=None),         # JS templates
    ce.StringRule("[[", "]]", escape=None, multiline=True),  # Lua long strings
    ce.StringRule("'", escape="'"),                          # SQL '' escaping
]
```

**`BlockComment(start, end)`**: state carries across lines, so a line that starts inside a comment is colored correctly. Comments are recognized before strings, so a comment marker inside a string is not a comment.

**`Sigil(prefix, color)`**: `Sigil("$", color)` colors `$name`. A lone `$` with no name after it is not a sigil.

**Numbers** (`numbers=True`): integers and decimals (`42`, `3.14`, `.5`), digit separators (`1_000_000`), exponents (`1e10`, `2.5E-3`) and prefixed literals (`0x1F`, `0b1010`, `0o755`). A number ends where it ends: `10px` is the number `10` followed by the identifier `px`. Identifiers cannot start with a digit. Set `numbers=False` if digits should not be treated specially.

**Operators**: each character in `Language.operators` is an operator character, and a *run* of them (`==`, `<=`, `&&`) becomes **one** token with `TokenColors.operator`.

**Punctuation**: each character in `Language.punctuation` becomes its own token with `TokenColors.punctuation`. Characters in neither set are drawn with the default color. Because comments and strings are recognized first, `//` is a comment, not two operators, as long as you listed it in `line_comments`.

**Identifiers**: a name starts with an ASCII letter, `_` or **any non-ASCII character** (Arabic, Chinese, accented letters and emoji count as name characters) and continues with letters, digits, `_`, non-ASCII characters and `identifier_extra`.

- A name found in `words` gets that group's color.
- Otherwise, if it is directly followed by `(` (spaces and tabs allowed in between) **and** `TokenColors.function` is set, it is a **function call**.
- Otherwise it gets `TokenColors.identifier`.

**`TokenColors`**:

| Field | Applies to |
|-------|------------|
| `comment` | Line and block comments |
| `string` | String literals, including their delimiters |
| `escape` | Escape sequences inside strings. Falls back to `string`. |
| `number` | Numeric literals |
| `function` | Names followed by `(` that are not in `words` |
| `identifier` | All other names |
| `operator` | Operator runs |
| `punctuation` | Punctuation characters and the bracket characters listed in `ErrorRules.brackets` |

`None` means `default_color`. If you leave `function` as `None`, function calls look like ordinary identifiers. Entries with an empty word or an invalid color are ignored.

### Error underlines: `ErrorRules`

```python
errors=ce.ErrorRules(
    unterminated_strings=True,
    brackets=[ce.BracketPair("(", ")"), ce.BracketPair("[", "]")],
    unknown_words=False,
    allowed_words=[],
    forbidden_words=["goto"],
    color="#F44747",
    wavy=True,
)
```

| Check | Behavior |
|-------|----------|
| `unterminated_strings` | A non-multiline string not closed by end of line. |
| `brackets` | Unmatched closer, or opener never closed **on the same line**. Single characters only. |
| `unknown_words` | Every name not in `words` or `allowed_words`. |
| `forbidden_words` | Always underlined, even if listed in `words`. |

All checks work within a single line. Details:

- An unterminated string is underlined from its opening delimiter.
- Brackets inside strings and comments are not counted.
- Function-call names count as identifiers for `unknown_words`.
- Errors can be hidden at runtime with `show_errors=False`.

Only the underline is drawn. The lexer builds a message for each error (*Unterminated string*, *Unknown word: foo*, *Unmatched ')'*, *Unclosed '('*), but messages are not shown as tooltips yet. For languages where `{` and `}` sit on different lines, leave that pair out of `brackets`.

### Folding: `FoldRule` and `fold_by_indent`

```python
folds=[ce.FoldRule("class", "end"), ce.FoldRule("on", length=5)]
```

- `FoldRule(start, end)`: a line starting with `start` opens a region, a line starting with `end` closes it. Nesting works.
- `FoldRule(start, length=N)`: folds the next `N` lines. If both `end` and `length` are given, `end` is used.
- Markers match at the start of a line after indentation. A marker ending in a letter, digit or `_` matches whole words only.
- If the marker ends with a symbol (`{`, `#region`), it matches as a plain prefix.
- Matching is case-sensitive and ignores `case_insensitive`.
- A region is foldable only if it has at least one line inside it. An opener without a closer folds nothing.
- If `start == end`, the same marker toggles open and closed.
- Folding is line-based and unaware of strings and comments. A rule with neither `end` nor `length` does nothing.
- `fold_by_indent=True` also folds every line followed by more-indented lines (Python/YAML style). A tab counts as 4 spaces. It can be combined with `folds`. Both work the same on `EditorRegex`.

### `case_insensitive`

When `True`, words in `WordGroup`, `allowed_words` and `forbidden_words` are compared in lower case, and the name found in the text is lower-cased before lookup (useful for SQL, BASIC, Pascal). It does **not** affect comment markers, string delimiters, sigil prefixes or `FoldRule` markers.

### `to_json()`

`Language.to_json()` returns the compact JSON string the editor consumes. The editor compares strings, so re-assigning an identical value rebuilds nothing. Build it once and reuse it:

```python
PY_LANG = ce.Language(...).to_json()
a = ce.EditorTokens(language=PY_LANG)
b = ce.EditorTokens(language=PY_LANG, read_only=True)
```

### How the lexer decides

For every line the lexer scans left to right and at each position tries the steps below, **stopping at the first match**:

| # | Step | Notes |
|---|------|-------|
| 0 | Continue a multi-line construct | A line that starts inside a block comment or multi-line string finishes it first. |
| 1 | Whitespace | Spaces, tabs, `\r` and non-breaking space. Never colored. |
| 2 | Line comments | Longest marker first. Consumes the rest of the line. |
| 3 | Block comments | Longest start marker first. May stay open to the next line. |
| 4 | Strings | Longest `open` first. May stay open for `multiline=True`. |
| 5 | Sigils | Prefix plus at least one name character. |
| 6 | Numbers | Only if `numbers=True`. |
| 7 | Identifiers, words, calls | Also applies `forbidden_words` and `unknown_words`. |
| 8 | Bracket check | Only for characters listed in `ErrorRules.brackets`. |
| 9 | Operators | A run of operator characters is one token. |
| 10 | Punctuation | One character per token. |
| 11 | Anything else | Default color. |

Consequences:

- **Order inside lists does not matter** for strings, comments and sigils (the longest marker wins). It matters only for duplicate words (last group wins).
- Comments beat strings, and strings beat everything else, because they are tested first while scanning left to right.
- There is no rule-priority system as in regex highlighters; the structure of the language decides the color.
- Adjacent tokens with the same color are merged into one span.

**Multi-line state.** The lexer keeps a small integer state at the start of each line: `0` is normal, `1..N` is inside block comment *N*, followed by one state per multi-line string rule. A line's start state is derived from the lines above it and cached, so editing a line re-lexes the lines below it only **when they become visible**.

### More examples

```python
# SQL: case-insensitive, -- and /* */ comments, '' escaping
SQL = ce.Language(
    case_insensitive=True,
    words=[ce.WordGroup(["select", "from", "where", "join", "and", "or"], "#C586C0")],
    line_comments=["--"],
    block_comments=[ce.BlockComment("/*", "*/")],
    strings=[ce.StringRule("'", escape="'")],
    colors=ce.TokenColors(comment="#6A9955", string="#CE9178", number="#B5CEA8"),
)

# Python-like: docstrings and indentation folding
PYLIKE = ce.Language(
    words=[ce.WordGroup(["def", "class", "if", "else", "for", "return"], "#C586C0")],
    line_comments=["#"],
    strings=[ce.StringRule('"""', multiline=True), ce.StringRule('"'), ce.StringRule("'")],
    colors=ce.TokenColors(comment="#6A9955", string="#CE9178", function="#DCDCAA"),
    fold_by_indent=True,
)

# Command language: $sigils, dashed names, fold pairs
CMD = ce.Language(
    identifier_extra="-",
    sigils=[ce.Sigil("$", "#4FC1FF")],
    line_comments=["#"],
    words=[ce.WordGroup(["if", "endif"], "#C586C0")],
    folds=[ce.FoldRule("if", "endif")],
)
```

---

## Complete examples

### 1. A small scripting language with errors and folding

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

### 2. Read-only viewer that grows with its content

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

### 3. Phone-friendly editor inside a scrolling page

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
                selection_menu=True,
                selection_menu_items=["cut", "copy", "paste", "select_all"],
                magnifier=True,
                mobile_controls=True,       # toolbar + cursor pad (automatic on phones anyway)
                cursor_pad=True,
                scroll_mode=ce.ScrollMode.PAGE_FIRST,
            ),
            ft.Text("More page content below..."),
        ],
    )
)
```

### 4. Switching languages from a dropdown

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

## Autocomplete

Suggestions come only from the `autocomplete_words` list you provide. There is no semantic parsing and no auto-indent.

```python
ce.EditorRegex(
    autocomplete=True,
    autocomplete_words=["print", "private", "property"],
    remember_suggestions=True,
)
```

### Trigger prefix

For command editors, set `autocomplete_trigger="$"`:

- Suggestions stay hidden for ordinary words and for a bare `$`.
- After `$` plus at least one character (for example `$d`), matches appear labeled with the sigil (`$day`).
- Write the vocabulary without the sigil. Accepting a suggestion replaces only the typed name and keeps the `$` that is already in the text.
- A word identical to what you already typed is not suggested.

```python
ce.EditorRegex(
    autocomplete_trigger="$",
    autocomplete_words=["day", "dayOfWeek", "date"],
)
```

### Where suggestions appear

- **Mobile:** a full-width rectangular strip directly above the software keyboard, listing all matches. Swipe it horizontally if the list is long. Tap an item to insert it.
- **Desktop:** a compact row of chips below the editor.

Usage ranking lives in memory for the lifetime of the control. Nothing is stored or sent anywhere.

---

## Search helper

There is no built-in search field. Use `find_matches` from your own UI:

```python
matches = ce.find_matches(editor.value, "widget", case_sensitive=False)
on_line = ce.find_matches(editor.value, "widget", current_line=4)
```

Each result is `SearchMatch(start, end, line)` with zero-based offsets and a zero-based line number. Options: `case_sensitive`, `whole_word`, `current_line`. The query is matched literally, not as a regex.

---

## Mobile and touch

Properties documented as `None` mean **automatic**: on for Android and iOS, off elsewhere. This applies to `mobile_controls`, `cursor_pad` and `magnifier`.

> **The toolbar appears by default on phones.** If you do not want it, set `mobile_controls=False`.

### Selection menu

On Android and iOS the editor shows a native cut/copy/paste menu at the caret and selection handles. *Cut* and *Copy* appear only when text is selected; *Cut*, *Paste*, *Undo* and *Redo* are hidden in `read_only` mode. Disable it with `selection_menu=False`. It never appears on desktop, where keyboard shortcuts apply.

### Toolbar and cursor pad

```python
ce.EditorTokens(
    mobile_controls=True,
    toolbar_position=ce.ToolbarPosition.BOTTOM,
    toolbar_items=["undo", "redo", "cut", "copy", "paste", "select_all", "left", "right"],
    cursor_pad=True,
)
```

Available `toolbar_items` (the default is all of them, in this order; see `ce.DEFAULT_TOOLBAR_ITEMS`):

| Item | Action |
|------|--------|
| `undo`, `redo` | Undo / redo |
| `cut`, `copy`, `paste`, `select_all` | Clipboard and selection |
| `select_mode` | Toggle: arrows, pad and home/end **extend the selection** instead of moving the caret |
| `left`, `right`, `up`, `down` | Move the caret |
| `home`, `end` | Start / end of the line |
| `tab` | Insert two spaces |

The cursor pad sits at the left of the toolbar: drag horizontally to move one character per ~9 px, vertically to move one line per ~22 px. In `FIXED` mode the editor and toolbar share the given height (the toolbar takes 44 px).

### Magnifier

A round magnifier appears after a ~0.4 s long press inside the text and follows the finger. It is touch-only and visual only: it does not move the caret and does not follow the selection handles.

### Scroll hand-off

When the editor is inside a vertically scrollable page, `scroll_mode` decides who moves:

| Mode | Behavior |
|------|----------|
| `EDITOR_FIRST` (default) | The editor consumes the drag until its edge; only the leftover is passed to the page. |
| `PAGE_FIRST` | The page scrolls first; the editor moves once the page reaches its limit. |
| `EDITOR_ONLY` | No hand-off. |

If the editor is not inside a vertical scrollable, every mode behaves like `EDITOR_ONLY`. When the software keyboard opens, the editor reveals the actual caret rectangle and asks enclosing scrollables to reveal it too.

### Paste

Paste from the menu or toolbar reads the clipboard directly, normalizes `\r\n`, `\r` and Unicode line separators to `\n`, and removes NUL characters.

---

## Performance notes

- Only the lines that are actually painted are highlighted (the editor is virtualized).
- **Tokenizer:** each line's result is cached by `(index, text, start state)`. For languages without multi-line constructs an edit invalidates only that line; with multi-line constructs it invalidates the chain from the edited line downward, lazily. The cache is cleared beyond 20 000 cached lines.
- **Regex:** each line's result is cached by its text and cleared beyond 5000 entries.
- `highlight_scope="current_line"` re-processes only the edited line after a change and keeps cached colors elsewhere.
- Changing the language or rules, `syntax_highlighting`, `show_errors` or `code_folding` repaints all visible lines. Changing colors or fonts of the control itself does not re-highlight.
- Folding analysis runs over the whole document when the text changes. It is cheap line-prefix checking, but O(lines x fold rules).

---

## Building your app

```bash
flet build apk        # or: ipa, windows, macos, linux, web
```

`flet build` finds the Flutter package bundled in `flutter/flet_code_editor_dsl/` and adds it to the generated project. Running an app against the stock Flet client fails with `Unknown control: EditorTokens`.

| Change | Rebuild needed? |
|--------|:---------------:|
| Python code, `value`, `Language`, `rules`, colors, fonts, flags, sizes, mobile options | No |
| Upgrading to a version whose Dart code changed | **Yes** |
| Upgrading Flet itself | Yes |
| Adding or removing other Flet extensions | Yes |

Test touch features on a real Android or iOS build, not on desktop.

---

## Developing locally

`flet build` ignores `[tool.uv.sources]`, so point your test app at a wheel file.

1. From the library root, **raise `version`** in `pyproject.toml` and build:

   ```bash
   pip wheel . --no-deps -w dist
   ```

2. Reference the wheel in the test app's `pyproject.toml`:

   ```toml
   "flet-code-editor-dsl @ file:///C:/path/to/repo/dist/flet_code_editor_dsl-0.4.1-py3-none-any.whl"
   ```

3. Delete the old build output and rebuild:

   ```bash
   rm -rf build          # PowerShell: Remove-Item -Recurse -Force .\build
   flet build apk -v
   ```

4. Confirm the packaged copy is the one you expect:

   ```bash
   grep -r autocomplete_trigger build/site-packages/flet_code_editor_dsl/
   ```

> **Always change the version number when you change the library.** Reusing a version lets pip/uv or `flet build` reuse a cached copy, and the app then fails at runtime with errors like `EditorRegex.__init__() got an unexpected keyword argument ...`.

Run the Python tests from the library root:

```bash
PYTHONPATH=src python -m unittest discover -s tests -v
```

Flutter tests live in `src/flutter/flet_code_editor_dsl/test/`.

### Publishing

PyPI never accepts the same version twice.

```bash
pip install -U build twine
rm -rf dist && python -m build
twine check dist/*
twine upload dist/*        # try --repository testpypi first
```

### Project layout

```text
flet-code-editor-dsl/
├── pyproject.toml
├── README.md
├── LICENSE
├── tests/
└── src/
    ├── flet_code_editor_dsl/
    │   ├── __init__.py                 # public exports
    │   ├── flet_code_editor_dsl.py     # EditorTokens, EditorRegex, enums, rules
    │   ├── language.py                 # Language DSL + to_json()
    │   └── search.py                   # find_matches, SearchMatch
    └── flutter/flet_code_editor_dsl/
        ├── pubspec.yaml
        ├── lib/src/
        │   ├── extension.dart          # registers both control types
        │   ├── code_editor.dart        # shared widget: sync, sizing, touch, completion
        │   ├── regex_highlighter.dart  # EditorRegex engine
        │   ├── tokenizer.dart          # EditorTokens engine, folding
        │   └── completion.dart         # completion helpers
        ├── test/
        └── vendor/re_editor/           # bundled re_editor 0.10.0 (MIT) with a small patch
```

| File | Responsibility |
|------|----------------|
| `flet_code_editor_dsl.py` | Declares the two Flet controls and their helper types. |
| `language.py` | Declarative language description; produces the JSON consumed by Dart. |
| `search.py` | `find_matches` and `SearchMatch`. |
| `extension.dart` | Registers `EditorRegex` and `EditorTokens` with Flet. |
| `code_editor.dart` | The widget both controls share: value sync and debounce, engine selection, sizing, line numbers, fold indicator, selection menu, toolbar and cursor pad, magnifier, scroll hand-off, clipboard actions, completion overlay. |
| `regex_highlighter.dart` | Per-line regex highlighting and error underlines. |
| `tokenizer.dart` | `CodeLanguage.fromJson`, the stateful lexer, the cached `LineHighlighter`, the `FoldAnalyzer`, and the highlighter interface both engines implement. |
| `completion.dart` | Pure completion helpers shared by the editor and its unit tests. |
| `pyproject.toml` | Packaging metadata. Includes `flutter.flet_code_editor_dsl` (`**/*`) as package data so `flet build` can find the Flutter code. |

`re_editor` is bundled locally with a small scroll-physics and caret-rectangle patch, described in `vendor/re_editor/UPSTREAM_PATCH.md`. Re-check the patch against upstream before upgrading it.

---

## Known limitations

- Touch features have had limited testing on real devices. Please report problems with your device, OS and Flet versions.
- The magnifier does not follow the selection handles.
- The selection menu is Android and iOS only.
- No nested block comments: the first end marker closes the comment.
- Error checks are per line. Brackets are not matched across lines, and multi-line strings are never flagged as unterminated.
- Error messages are not shown, only underlines.
- Folding is line-based and ignores strings and comments.
- `EditorRegex` highlights line by line: no multi-line constructs, first rule wins.
- Autocomplete uses only your word list.
- Colors must be hex strings.
- `editor.value` can lag behind the screen by up to `debounce_ms`.
- Pasting with the platform's own shortcut or menu inside `re_editor` still uses its code path. The library's paste normalization applies to its own menu and toolbar.
- Scroll hand-off depends on the enclosing scrollable's physics. `PAGE_FIRST` uses clamping physics inside the editor.
- As with all Flet extensions, the controls are not available in the stock Flet client. A build is required.

## Troubleshooting

| Symptom | Cause and fix |
|---------|---------------|
| `Unknown control: EditorRegex` / `EditorTokens` | The app does not include the extension. Declare the package in `pyproject.toml` and build with `flet build`. |
| `got an unexpected keyword argument '...'` at runtime | The built app contains an older copy of the package than your code expects. Raise the version, rebuild the wheel, delete `build/`, rebuild, uninstall the old app from the device. See [Developing locally](#developing-locally). |
| `ImportError: cannot import name 'EditorRegex'` | Same cause: an old version was packaged (0.2.x has no `EditorRegex`). |
| `TypeError` about `incremental_highlighting` | Removed in 0.3.0. Delete the argument. |
| The editor is tiny | Levels default to `17/30`. Use `expand=True`, `width`/`height`, or levels up to `30`. |
| No colors | `EditorTokens`: `language` is empty or not a JSON string. `EditorRegex`: `rules` is empty or invalid for Dart. Also check `syntax_highlighting=True`. |
| Text hard to read on a dark background | Set `default_color` together with `background_color`. |
| Function calls look like plain names | `TokenColors.function` is not set. |
| A word is not colored as a keyword | It is not an exact whole-word match. Try `case_insensitive=True` or `identifier_extra`. |
| An `EditorRegex` rule has no effect | An earlier rule already colored those characters, or the pattern is invalid for Dart. |
| No error underlines | `EditorTokens`: `errors` is `None`. `EditorRegex`: `error_rules` is empty. Or `show_errors=False`. |
| Underline under every variable | `unknown_words=True` flags everything not in `words`/`allowed_words`. |
| No fold markers | `code_folding=False`, or no `FoldRule` with `end`/`length` and `fold_by_indent=False`. |
| No suggestions | `autocomplete_words` is empty, or `autocomplete_trigger` is set and the text before the cursor has no trigger. |
| Toolbar or magnifier appears on phones when you did not ask for it | Automatic mode is on. Set `mobile_controls=False`, `cursor_pad=False`, `magnifier=False`. |
| Editor does not scroll the page | Check `scroll_mode`, and make sure the editor is inside a vertical scrollable (`ListView`, `Column(scroll=...)`). |
| `on_change` seems late | It is debounced. Lower `debounce_ms` or set `0`. |
| Changes from Python are not visible | Call `editor.update()`. |
| `FletCodeEditor` / `FletCodeField` not found | They remain as deprecated aliases of `EditorTokens` / `EditorRegex`. If you removed the aliases from `__init__.py`, use the new names. |
| No cut/copy/paste menu on the phone | Keep `selection_menu=True` (default), rebuild the app after upgrading, and run on Android/iOS. The menu appears when you tap the caret, long-press or select text. |
| Pasted text does not appear | Use *Paste* from the selection menu or the toolbar (they sanitize the clipboard text), and check that the editor is not `read_only`. |
| Magnifier does not appear | It is touch-only, needs a ~0.4 s long press inside the text area, and `magnifier` must not be `False`. |
| Cursor pad is missing | It lives in the toolbar. It is shown on phones by default; `mobile_controls=False` or `cursor_pad=False` hides it. On desktop set `mobile_controls=True`. |
| `pip install` from GitHub fails | Confirm Git is installed, the URL is correct, and (for private repositories) that you are authenticated. |

---

## Changelog

### 0.4.0

- `highlight_scope`: `"document"` or `"current_line"`.
- Autocomplete from a developer-supplied word list, with optional `autocomplete_trigger` and `remember_suggestions`. Mobile strip above the keyboard.
- `find_matches` / `SearchMatch` headless search helper.
- `horizontal_scroll_padding`; default font size `16`; default `scroll_mode` is `EDITOR_FIRST`.
- `ignore_case` on `HighlightRule` and `ErrorPattern`.
- Mobile scroll hand-off and caret reveal reworked. `re_editor 0.10.0` is bundled with a small patch.
- Safer parsing of an empty or invalid `language`, unique fold regions.
- **Rebuild your app after upgrading.**

### 0.3.0

- `FletCodeEditor` is now `EditorTokens` and `FletCodeField` is now `EditorRegex`. The old names still work as deprecated aliases.
- `EditorRegex` rebuilt on `re_editor` with the same feature set as `EditorTokens`.
- `incremental_highlighting` removed.
- Touch support: selection menu, toolbar, cursor pad, magnifier, `scroll_mode`.

### 0.2.0

The original regex-based `CodeEditor` and its `rule()` / `group()` / `pair()` helpers were replaced by `EditorTokens`, `EditorRegex` and the `Language` DSL.

---

## Migrating from older versions

### To 0.3.0 (from 0.2.x)

| Change | Details |
|--------|---------|
| Controls renamed | `FletCodeEditor` is now `EditorTokens`, `FletCodeField` is now `EditorRegex`. The old names still work as deprecated aliases in `__init__.py`. |
| `EditorRegex` rebuilt | It runs on `re_editor` instead of `code_text_field` and has the same feature set as `EditorTokens`: line numbers, error underlines, folding, read-only, fonts, colors, size levels, debounce. |
| `incremental_highlighting` removed | `EditorRegex` always highlights line by line. Passing the old argument raises a `TypeError`. |
| Touch support | Selection menu, toolbar, cursor pad, magnifier, `scroll_mode`. |
| Paste fix | Menu and toolbar paste read the clipboard directly and normalize line endings and control characters. |
| Dart files | `regex_highlighter.dart` added. `code_editor.dart` is shared by both controls. The old `CodeField` widget was deleted. |

```python
# before                                  # after
ce.FletCodeEditor(language=...)           ce.EditorTokens(language=...)
ce.FletCodeField(rules=[...])             ce.EditorRegex(rules=[...])
```

Because the Dart side changed, **rebuild your app** after upgrading.

### To 0.2.0 (from the original `CodeEditor` API)

The earlier regex-based `CodeEditor` control and its `rule()` / `group()` / `pair()` helpers no longer exist.

| Original API | 0.2.0 and later |
|--------------|-----------------|
| Control `CodeEditor` | `EditorTokens` (tokenizer) and `EditorRegex` (regex) |
| `rule()`, `group()` + `rules_json()` | `Language(words=[WordGroup(...)], strings=..., ...)` + `Language.to_json()`; a `HighlightRule` list for `EditorRegex` |
| `pair()` + `pairs_json()` | `ErrorRules(brackets=[BracketPair(...)])` and `StringRule` |
| `strict` / `error_color` | `ErrorRules(unknown_words=True, allowed_words=[...], forbidden_words=[...])` |
| `before` / `after` / `ignore_if` | Not needed: the lexer understands strings, comments, calls and sigils |
| Flet `>= 0.80` | Flet `>= 0.85.2` |

In the original `CodeEditor`, later rules overrode earlier ones. In `EditorRegex` the **first** matching rule wins.

---

## Contributing

Contributions are welcome.

1. Fork the repository.
2. Create a feature branch: `git checkout -b feature/my-feature`.
3. Commit your changes with clear messages.
4. Push the branch and open a Pull Request describing the change and its motivation.

Please open an issue first for larger changes so the design can be discussed. See [Developing locally](#developing-locally) for how to try your changes in an app.

## Sponsors

Development of `flet-code-editor-dsl` is supported by its sponsors. Their contributions help cover maintenance time, testing across platforms and new features.

<!--
  Add sponsors below. Suggested format:

  <a href="https://example.com"><img src="https://example.com/logo.png" alt="Sponsor Name" height="60"></a>
-->

*Your logo could be here. [Become the first sponsor!](https://github.com/sponsors/obgwew)*

If this library saves you time, please consider [sponsoring it on GitHub](https://github.com/sponsors/obgwew).

| Tier | Benefit |
|------|---------|
| **Supporter** | Your name listed in this section. |
| **Silver** | Your name and link listed in this section. |
| **Gold** | Your logo and link displayed prominently at the top of this section. |

Sponsorship is entirely optional and does not affect the [license](#license) or the features available to anyone.

---

## License

This project is licensed under the **Apache License, Version 2.0**. See [LICENSE](LICENSE) for the full text. The bundled `re_editor` source in `vendor/re_editor` is MIT-licensed; its license file is included.

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
