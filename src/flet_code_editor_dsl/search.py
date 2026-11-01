from dataclasses import dataclass


@dataclass(frozen=True)
class SearchMatch:
    """A text match, with zero-based offsets and a zero-based line number."""

    start: int
    end: int
    line: int


def find_matches(
    text: str,
    query: str,
    *,
    case_sensitive: bool = False,
    whole_word: bool = False,
    current_line: int | None = None,
) -> list[SearchMatch]:
    """Find literal query occurrences without imposing any search UI.

    Applications can use this helper from their own search field, then decide
    how to display or navigate the returned matches. If ``current_line`` is
    supplied, only that zero-based line is searched.
    """
    if not query:
        return []

    lines = text.splitlines(keepends=True)
    if not lines:
        lines = [""]
    wanted_lines = range(len(lines)) if current_line is None else [current_line]
    if current_line is not None and not 0 <= current_line < len(lines):
        return []

    needle = query if case_sensitive else query.casefold()
    matches: list[SearchMatch] = []
    seen_matches: set[SearchMatch] = set()
    base = 0
    for line_number, line in enumerate(lines):
        content = line.rstrip("\r\n")
        if line_number in wanted_lines:
            if case_sensitive:
                haystack = content
                source_offsets = list(range(len(content)))
            else:
                folded = [char.casefold() for char in content]
                haystack = "".join(folded)
                source_offsets = [i for i, part in enumerate(folded) for _ in part]
            offset = 0
            while True:
                found = haystack.find(needle, offset)
                if found < 0:
                    break
                end_folded = found + len(needle)
                start_original = source_offsets[found]
                end_original = source_offsets[end_folded - 1] + 1
                if not whole_word or (
                    (start_original == 0 or not _is_word_char(content[start_original - 1]))
                    and (end_original == len(content) or not _is_word_char(content[end_original]))
                ):
                    match = SearchMatch(
                        base + start_original, base + end_original, line_number
                    )
                    if match not in seen_matches:
                        matches.append(match)
                        seen_matches.add(match)
                offset = found + max(1, len(needle))
        base += len(line)
    return matches


def _is_word_char(char: str) -> bool:
    return char == "_" or char.isalnum()
