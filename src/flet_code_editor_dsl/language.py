"""Declarative description of a language for the FletCodeEditor tokenizer.

The editor scans the text with a hand-written lexer (no regular expressions).
You only describe *what* the language contains; the lexer takes care of
strings with escapes, nested multi-line comments state, numbers, identifiers,
function calls, sigils, operators and punctuation.
"""
import json
from dataclasses import asdict, dataclass, field


@dataclass
class WordGroup:
    """A group of exact words that share one color (keywords, constants...)."""
    words: list[str]
    color: str


@dataclass
class StringRule:
    """A string literal, e.g. StringRule('"') or StringRule('\"\"\"', multiline=True)."""
    open: str
    close: str | None = None        # defaults to `open`
    escape: str | None = "\\"       # escape character, or None
    multiline: bool = False


@dataclass
class BlockComment:
    start: str
    end: str


@dataclass
class Sigil:
    """A prefix followed by a name, e.g. Sigil("$", color) matches $name."""
    prefix: str
    color: str


@dataclass
class FoldRule:
    """A foldable region, defined by the user.

    - `FoldRule("class", "end")`: a line starting with `class` opens a region and
      a line starting with `end` closes it (nesting is supported).
    - `FoldRule("on", length=5)`: fold the 5 lines after a line starting with `on`.

    Markers match at the beginning of a line (after indentation); word markers
    match whole words only (`end` does not match `endpoint`).
    """
    start: str
    end: str | None = None
    length: int | None = None


@dataclass
class BracketPair:
    open: str
    close: str


@dataclass
class ErrorRules:
    """Optional error underlines. All checks work inside a single line.

    `Language(errors=None)` (the default) disables error checking.
    """
    unterminated_strings: bool = True
    brackets: list[BracketPair] = field(default_factory=list)  # unmatched in a line
    unknown_words: bool = False          # flag names not in `words` / `allowed_words`
    allowed_words: list[str] = field(default_factory=list)
    forbidden_words: list[str] = field(default_factory=list)   # always flagged
    color: str = "#F44747"
    wavy: bool = True                    # False = straight underline


@dataclass
class TokenColors:
    """Colors of the built-in token kinds. `None` = default text color."""
    comment: str | None = None
    string: str | None = None
    escape: str | None = None       # escape sequences inside strings (\n)
    number: str | None = None
    function: str | None = None     # identifier directly followed by "("
    identifier: str | None = None
    operator: str | None = None
    punctuation: str | None = None


@dataclass
class Language:
    words: list[WordGroup] = field(default_factory=list)
    line_comments: list[str] = field(default_factory=list)
    block_comments: list[BlockComment] = field(default_factory=list)
    strings: list[StringRule] = field(default_factory=list)
    sigils: list[Sigil] = field(default_factory=list)
    numbers: bool = True
    operators: str = "+-*/%=<>!&|^~?:"
    punctuation: str = "(){}[],;."
    identifier_extra: str = ""      # extra characters allowed inside names, e.g. "-"
    case_insensitive: bool = False
    colors: TokenColors = field(default_factory=TokenColors)
    folds: list[FoldRule] = field(default_factory=list)
    fold_by_indent: bool = False         # also fold by indentation
    errors: ErrorRules | None = None     # None = no error checking

    def to_json(self) -> str:
        """Value to pass to FletCodeEditor(language=...)."""
        return json.dumps(asdict(self), ensure_ascii=False, separators=(",", ":"))
