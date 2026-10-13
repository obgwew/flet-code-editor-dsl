import flet as ft

from flet_code_editor_dsl import (
    BlockComment, BracketPair, EditorRegex, EditorTokens, ErrorPattern,
    ErrorRules, FoldRule, HighlightRule, Language, ScrollMode, StringRule,
    TokenColors, WordGroup,
)

SAMPLE = '''// Test script - long press the text, then try cut / copy / paste
/* block
   comment */
func main(a, b) {
    let total = (a + b) * 3.14
    if total > 10 {
        print("total = ", total)
    } else {
        print("small" 
    }
    return total
}
'''

TOKENS = Language(
    words=[
        WordGroup(["func", "let", "if", "else", "return"], "#C586C0"),
        WordGroup(["true", "false", "null"], "#569CD6"),
    ],
    line_comments=["//"],
    block_comments=[BlockComment("/*", "*/")],
    strings=[StringRule('"')],
    colors=TokenColors(
        comment="#6A9955", string="#CE9178", escape="#D7BA7D",
        number="#B5CEA8", function="#DCDCAA", identifier="#9CDCFE",
        operator="#D4D4D4", punctuation="#808080",
    ),
    folds=[FoldRule("func", length=20)],
    fold_by_indent=True,
    errors=ErrorRules(brackets=[BracketPair("(", ")"), BracketPair("{", "}")]),
).to_json()

REGEX_RULES = [
    HighlightRule(r"//.*$", "#6A9955"),
    HighlightRule(r'"(?:[^"\\]|\\.)*"?', "#CE9178"),
    HighlightRule(r"\b(?:func|let|if|else|return)\b", "#C586C0"),
    HighlightRule(r"\b(?:true|false|null)\b", "#569CD6"),
    HighlightRule(r"\b\d+(?:\.\d+)?\b", "#B5CEA8"),
    HighlightRule(r"\b[A-Za-z_]\w*(?=\()", "#DCDCAA"),
]
REGEX_ERRORS = [
    ErrorPattern(r'"[^"\\]*(?:\\.[^"\\]*)*$', "Unterminated string"),
]


def main(page: ft.Page):
    page.title = "Editor test"
    state = {"engine": "tokens", "mobile": False, "pad": True, "mag": True,
             "scroll": ScrollMode.PAGE_FIRST, "value": SAMPLE}

    holder = ft.Container()
    info = ft.Text()

    def on_change(e):
        state["value"] = e.control.value
        info.value = f"engine={state['engine']}  scroll={state['scroll'].value}  chars={len(e.control.value)}"
        info.update()

    def build():
        common = dict(
            value=state["value"],
            height=360,
            width_level=30,
            height_level=None,
            font_family="monospace",
            font_size=14,
            background_color="#1E1E1E",
            default_color="#D4D4D4",
            mobile_controls=state["mobile"],
            cursor_pad=state["pad"],
            magnifier=state["mag"],
            scroll_mode=state["scroll"],
            on_change=on_change,
        )
        if state["engine"] == "tokens":
            holder.content = EditorTokens(language=TOKENS, **common)
        else:
            holder.content = EditorRegex(
                rules=REGEX_RULES, error_rules=REGEX_ERRORS,
                folds=[FoldRule("func", length=20)], fold_by_indent=True,
                **common,
            )
        info.value = f"engine={state['engine']}  scroll={state['scroll'].value}"
        page.update()

    def toggle(key):
        def h(e):
            state[key] = e.control.value
            build()
        return h

    def switch_engine(e):
        state["engine"] = "regex" if state["engine"] == "tokens" else "tokens"
        build()

    def cycle_scroll(e):
        order = [ScrollMode.PAGE_FIRST, ScrollMode.EDITOR_FIRST, ScrollMode.EDITOR_ONLY]
        state["scroll"] = order[(order.index(state["scroll"]) + 1) % 3]
        build()

    filler = [ft.Text(f"Page content above/below the editor - line {i}") for i in range(14)]

    page.add(
        ft.SafeArea(
            expand=True,
            content=ft.ListView(
                expand=True,
                spacing=8,
                controls=[
                    ft.Text("EditorTokens / EditorRegex test", size=20),
                    ft.Button("Switch engine (tokens <-> regex)", on_click=switch_engine),
                    ft.Button("Cycle scroll mode", on_click=cycle_scroll),
                    ft.Switch(label="Extra toolbar (optional)", value=False, on_change=toggle("mobile")),
                    ft.Switch(label="Cursor pad (only with toolbar)", value=True, on_change=toggle("pad")),
                    ft.Switch(label="Magnifier (hold finger)", value=True, on_change=toggle("mag")),
                    info,
                    *filler[:6],
                    holder,
                    *filler[6:],
                ],
            ),
        )
    )
    build()


ft.run(main)
