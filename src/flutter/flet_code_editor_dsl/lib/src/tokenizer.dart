import 'package:flutter/material.dart';
import 'package:re_editor/re_editor.dart';

/// Parses "#RRGGBB" / "#AARRGGBB". Returns null for missing/invalid values.
Color? parseHexColor(String? hex) {
  if (hex == null || hex.isEmpty) return null;
  try {
    var clean = hex.replaceAll("#", "");
    if (clean.length == 6) clean = "FF$clean";
    return Color(int.parse(clean, radix: 16));
  } catch (_) {
    return null;
  }
}

class LexToken {
  final int start;
  final int end;
  final Color? color; // null = default text color
  const LexToken(this.start, this.end, this.color);
}

class LexError {
  final int start;
  final int end;
  final String message;
  const LexError(this.start, this.end, this.message);
}

class LexResult {
  final List<LexToken> tokens;
  final int endState;
  final List<LexError> errors;
  const LexResult(this.tokens, this.endState, this.errors);
}

class StringRule {
  final String open;
  final String close;
  final String? escape;
  final bool multiline;
  const StringRule(this.open, this.close, this.escape, this.multiline);
}

class BlockRule {
  final String start;
  final String end;
  const BlockRule(this.start, this.end);
}

class Sigil {
  final String prefix;
  final Color color;
  const Sigil(this.prefix, this.color);
}

/// User-defined, optional error checks (all of them work inside one line).
class ErrorConfig {
  final bool unterminatedStrings;
  final Map<int, int> openToClose; // bracket pairs (single characters)
  final Set<int> closers;
  final bool unknownWords;
  final Set<String> allowed;
  final Set<String> forbidden;
  final Color color;
  final bool wavy;

  ErrorConfig({
    required this.unterminatedStrings,
    required this.openToClose,
    required this.closers,
    required this.unknownWords,
    required this.allowed,
    required this.forbidden,
    required this.color,
    required this.wavy,
  });

  bool get hasBrackets => openToClose.isNotEmpty;
}

class FoldRuleSpec {
  final String start;
  final String? end;
  final int? length;
  const FoldRuleSpec(this.start, this.end, this.length);
}

bool _isDigit(int c) => c >= 48 && c <= 57;
bool _isHex(int c) =>
    _isDigit(c) || (c >= 65 && c <= 70) || (c >= 97 && c <= 102);
bool _isSpace(int c) => c == 32 || c == 9 || c == 13 || c == 160;
bool _isIdentStart(int c) =>
    (c >= 65 && c <= 90) || (c >= 97 && c <= 122) || c == 95 || c >= 128;

/// A hand-written, stateful lexer described declaratively (no regex).
///
/// Lexer state at the start of a line:
///   0                         normal
///   1 .. blocks.length        inside block comment `blocks[state - 1]`
///   blocks.length + 1 + i     inside multi-line string `strings[i]`
class CodeLanguage {
  final bool caseInsensitive;
  final bool numbers;
  final Map<String, Color> words;
  final List<String> lineComments;
  final List<BlockRule> blocks;
  final List<StringRule> strings;
  final List<Sigil> sigils;
  final Set<int> operators;
  final Set<int> punctuation;
  final Set<int> identExtra;
  final Color? cComment;
  final Color? cString;
  final Color? cNumber;
  final Color? cFunction;
  final Color? cIdentifier;
  final Color? cOperator;
  final Color? cPunct;
  final Color? cEscape;
  final ErrorConfig? errors;
  final List<FoldRuleSpec> folds;
  final bool foldByIndent;

  final Map<Color, TextStyle> _styles = {};
  final Map<Color?, TextStyle> _errStyles = {};

  CodeLanguage({
    required this.caseInsensitive,
    required this.numbers,
    required this.words,
    required this.lineComments,
    required this.blocks,
    required this.strings,
    required this.sigils,
    required this.operators,
    required this.punctuation,
    required this.identExtra,
    required this.folds,
    required this.foldByIndent,
    this.errors,
    this.cComment,
    this.cString,
    this.cNumber,
    this.cFunction,
    this.cIdentifier,
    this.cOperator,
    this.cPunct,
    this.cEscape,
  });

  bool get hasMultiline =>
      blocks.isNotEmpty || strings.any((s) => s.multiline);

  bool get hasFolding => folds.isNotEmpty || foldByIndent;

  TextStyle styleFor(Color c) =>
      _styles.putIfAbsent(c, () => TextStyle(color: c));

  /// Style of an erroneous range: the token color plus a red underline.
  TextStyle errorStyle(Color? base) => _errStyles.putIfAbsent(base, () {
        final e = errors!;
        return TextStyle(
          color: base,
          decoration: TextDecoration.underline,
          decorationColor: e.color,
          decorationStyle:
              e.wavy ? TextDecorationStyle.wavy : TextDecorationStyle.solid,
          decorationThickness: 1.5,
        );
      });

  factory CodeLanguage.fromJson(Map<String, dynamic> j) {
    Color? col(dynamic v) => parseHexColor(v?.toString());
    Set<int> codes(dynamic v) => (v?.toString() ?? "").codeUnits.toSet();

    final ci = j["case_insensitive"] == true;
    String norm(String s) => ci ? s.toLowerCase() : s;

    final words = <String, Color>{};
    for (final g in (j["words"] as List? ?? const [])) {
      if (g is! Map) continue;
      final color = col(g["color"]);
      if (color == null) continue;
      for (final w in (g["words"] as List? ?? const [])) {
        final k = w.toString();
        if (k.isEmpty) continue;
        words[norm(k)] = color;
      }
    }

    final lineComments = <String>[
      for (final s in (j["line_comments"] as List? ?? const []))
        if (s.toString().isNotEmpty) s.toString()
    ]..sort((a, b) => b.length.compareTo(a.length));

    final blocks = <BlockRule>[
      for (final b in (j["block_comments"] as List? ?? const []))
        if (b is Map &&
            b["start"].toString().isNotEmpty &&
            b["end"].toString().isNotEmpty)
          BlockRule(b["start"].toString(), b["end"].toString())
    ]..sort((a, b) => b.start.length.compareTo(a.start.length));

    final strings = <StringRule>[
      for (final s in (j["strings"] as List? ?? const []))
        if (s is Map && s["open"].toString().isNotEmpty)
          StringRule(
            s["open"].toString(),
            (s["close"] == null || s["close"].toString().isEmpty)
                ? s["open"].toString()
                : s["close"].toString(),
            (s["escape"] == null || s["escape"].toString().isEmpty)
                ? null
                : s["escape"].toString(),
            s["multiline"] == true,
          )
    ]..sort((a, b) => b.open.length.compareTo(a.open.length));

    final sigils = <Sigil>[
      for (final s in (j["sigils"] as List? ?? const []))
        if (s is Map &&
            s["prefix"].toString().isNotEmpty &&
            col(s["color"]) != null)
          Sigil(s["prefix"].toString(), col(s["color"])!)
    ]..sort((a, b) => b.prefix.length.compareTo(a.prefix.length));

    // ---- folding ----
    final folds = <FoldRuleSpec>[
      for (final f in (j["folds"] as List? ?? const []))
        if (f is Map && f["start"].toString().isNotEmpty)
          FoldRuleSpec(
            f["start"].toString(),
            (f["end"] == null || f["end"].toString().isEmpty)
                ? null
                : f["end"].toString(),
            f["length"] is int ? f["length"] as int : null,
          )
    ];

    // ---- errors (optional) ----
    ErrorConfig? errors;
    final e = j["errors"];
    if (e is Map) {
      final open = <int, int>{};
      final closers = <int>{};
      for (final p in (e["brackets"] as List? ?? const [])) {
        if (p is Map) {
          final o = p["open"]?.toString() ?? "";
          final c = p["close"]?.toString() ?? "";
          if (o.length == 1 && c.length == 1) {
            open[o.codeUnitAt(0)] = c.codeUnitAt(0);
            closers.add(c.codeUnitAt(0));
          }
        }
      }
      errors = ErrorConfig(
        unterminatedStrings: e["unterminated_strings"] != false,
        openToClose: open,
        closers: closers,
        unknownWords: e["unknown_words"] == true,
        allowed: {
          for (final w in (e["allowed_words"] as List? ?? const []))
            norm(w.toString())
        },
        forbidden: {
          for (final w in (e["forbidden_words"] as List? ?? const []))
            norm(w.toString())
        },
        color: col(e["color"]) ?? const Color(0xFFF44747),
        wavy: e["wavy"] != false,
      );
    }

    final colors = (j["colors"] as Map?) ?? const {};

    return CodeLanguage(
      caseInsensitive: ci,
      numbers: j["numbers"] != false,
      words: words,
      lineComments: lineComments,
      blocks: blocks,
      strings: strings,
      sigils: sigils,
      operators: codes(j["operators"]),
      punctuation: codes(j["punctuation"]),
      identExtra: codes(j["identifier_extra"]),
      folds: folds,
      foldByIndent: j["fold_by_indent"] == true,
      errors: errors,
      cComment: col(colors["comment"]),
      cString: col(colors["string"]),
      cNumber: col(colors["number"]),
      cFunction: col(colors["function"]),
      cIdentifier: col(colors["identifier"]),
      cOperator: col(colors["operator"]),
      cPunct: col(colors["punctuation"]),
      cEscape: col(colors["escape"]),
    );
  }

  bool _isIdentPart(int c) =>
      _isIdentStart(c) || _isDigit(c) || identExtra.contains(c);

  /// Scans a string body starting at [from]; [segStart] is where the colored
  /// segment begins (so the opening delimiter is included). Returns the new
  /// position and whether the closing delimiter was found.
  (int, bool) _scanString(
    String line,
    int from,
    int segStart,
    StringRule r,
    void Function(int, int, Color?) add,
  ) {
    final n = line.length;
    var i = from;
    var seg = segStart;
    final esc = r.escape;
    while (i < n) {
      if (esc != null && line.startsWith(esc, i)) {
        add(seg, i, cString);
        final end = (i + esc.length + 1) > n ? n : (i + esc.length + 1);
        add(i, end, cEscape ?? cString);
        i = end;
        seg = i;
        continue;
      }
      if (line.startsWith(r.close, i)) {
        i += r.close.length;
        add(seg, i, cString);
        return (i, true);
      }
      i++;
    }
    add(seg, n, cString);
    return (n, false);
  }

  /// Lexes one line. [startState] is the state at the beginning of the line.
  LexResult lexLine(String line, int startState) {
    final out = <LexToken>[];
    final errs = <LexError>[];
    final ec = errors;

    void add(int s, int e, Color? c) {
      if (e <= s) return;
      if (out.isNotEmpty) {
        final l = out.last;
        if (l.end == s && l.color == c) {
          out[out.length - 1] = LexToken(l.start, e, c);
          return;
        }
      }
      out.add(LexToken(s, e, c));
    }

    final brackets = <(int, int)>[]; // (char, position)

    final n = line.length;
    var pos = 0;
    var state = startState;
    if (state < 0 || state > blocks.length + strings.length) state = 0;

    while (pos < n) {
      // ---- continuing a multi-line construct ----
      if (state != 0) {
        if (state <= blocks.length) {
          final b = blocks[state - 1];
          final idx = line.indexOf(b.end, pos);
          if (idx < 0) {
            add(pos, n, cComment);
            pos = n;
          } else {
            add(pos, idx + b.end.length, cComment);
            pos = idx + b.end.length;
            state = 0;
          }
        } else {
          final si = state - blocks.length - 1;
          final (np, closed) = _scanString(line, pos, pos, strings[si], add);
          pos = np;
          if (closed) state = 0;
        }
        continue;
      }

      final ch = line.codeUnitAt(pos);

      // ---- whitespace ----
      if (_isSpace(ch)) {
        var e = pos + 1;
        while (e < n && _isSpace(line.codeUnitAt(e))) {
          e++;
        }
        add(pos, e, null);
        pos = e;
        continue;
      }

      var matched = false;

      // ---- line comments ----
      for (final lc in lineComments) {
        if (line.startsWith(lc, pos)) {
          add(pos, n, cComment);
          pos = n;
          matched = true;
          break;
        }
      }
      if (matched) continue;

      // ---- block comments ----
      for (var b = 0; b < blocks.length; b++) {
        final rule = blocks[b];
        if (line.startsWith(rule.start, pos)) {
          final bodyFrom = pos + rule.start.length;
          final idx = line.indexOf(rule.end, bodyFrom);
          if (idx < 0) {
            add(pos, n, cComment);
            pos = n;
            state = b + 1;
          } else {
            add(pos, idx + rule.end.length, cComment);
            pos = idx + rule.end.length;
          }
          matched = true;
          break;
        }
      }
      if (matched) continue;

      // ---- strings ----
      for (var si = 0; si < strings.length; si++) {
        final r = strings[si];
        if (line.startsWith(r.open, pos)) {
          final pos0 = pos;
          final (np, closed) =
              _scanString(line, pos + r.open.length, pos, r, add);
          pos = np;
          if (!closed && !r.multiline && ec != null && ec.unterminatedStrings) {
            errs.add(LexError(pos0, n, "Unterminated string"));
          }
          state = (!closed && r.multiline) ? blocks.length + 1 + si : 0;
          matched = true;
          break;
        }
      }
      if (matched) continue;

      // ---- sigils ($name, @user, ...) ----
      for (final s in sigils) {
        if (line.startsWith(s.prefix, pos)) {
          final bodyFrom = pos + s.prefix.length;
          var e = bodyFrom;
          while (e < n && _isIdentPart(line.codeUnitAt(e))) {
            e++;
          }
          if (e > bodyFrom) {
            add(pos, e, s.color);
            pos = e;
            matched = true;
          }
          break;
        }
      }
      if (matched) continue;

      // ---- numbers ----
      if (numbers &&
          (_isDigit(ch) ||
              (ch == 46 && pos + 1 < n && _isDigit(line.codeUnitAt(pos + 1))))) {
        var e = pos;
        final next = pos + 1 < n ? line.codeUnitAt(pos + 1) : 0;
        if (ch == 48 &&
            (next == 120 || next == 88 || next == 98 || next == 66 ||
                next == 111 || next == 79)) {
          e += 2;
          while (e < n && (_isHex(line.codeUnitAt(e)) || line.codeUnitAt(e) == 95)) {
            e++;
          }
        } else {
          while (e < n && (_isDigit(line.codeUnitAt(e)) || line.codeUnitAt(e) == 95)) {
            e++;
          }
          if (e + 1 < n &&
              line.codeUnitAt(e) == 46 &&
              _isDigit(line.codeUnitAt(e + 1))) {
            e++;
            while (e < n && (_isDigit(line.codeUnitAt(e)) || line.codeUnitAt(e) == 95)) {
              e++;
            }
          }
          if (e < n && (line.codeUnitAt(e) == 101 || line.codeUnitAt(e) == 69)) {
            var k = e + 1;
            if (k < n && (line.codeUnitAt(k) == 43 || line.codeUnitAt(k) == 45)) {
              k++;
            }
            if (k < n && _isDigit(line.codeUnitAt(k))) {
              e = k;
              while (e < n && _isDigit(line.codeUnitAt(e))) {
                e++;
              }
            }
          }
        }
        add(pos, e, cNumber);
        pos = e;
        continue;
      }

      // ---- identifiers / words ----
      if (_isIdentStart(ch)) {
        var e = pos + 1;
        while (e < n && _isIdentPart(line.codeUnitAt(e))) {
          e++;
        }
        final word = line.substring(pos, e);
        final key = caseInsensitive ? word.toLowerCase() : word;
        final wordColor = words[key];
        var color = wordColor;
        if (color == null) {
          var k = e;
          while (k < n && (line.codeUnitAt(k) == 32 || line.codeUnitAt(k) == 9)) {
            k++;
          }
          final isCall = k < n && line.codeUnitAt(k) == 40;
          color = (isCall && cFunction != null) ? cFunction : cIdentifier;
        }
        if (ec != null) {
          if (ec.forbidden.contains(key)) {
            errs.add(LexError(pos, e, "Not allowed: $word"));
          } else if (ec.unknownWords &&
              wordColor == null &&
              !ec.allowed.contains(key)) {
            errs.add(LexError(pos, e, "Unknown word: $word"));
          }
        }
        add(pos, e, color);
        pos = e;
        continue;
      }

      // ---- bracket checks (per line) ----
      if (ec != null &&
          ec.hasBrackets &&
          (ec.openToClose.containsKey(ch) || ec.closers.contains(ch))) {
        if (ec.openToClose.containsKey(ch)) {
          brackets.add((ch, pos));
        } else if (brackets.isNotEmpty &&
            ec.openToClose[brackets.last.$1] == ch) {
          brackets.removeLast();
        } else {
          errs.add(LexError(pos, pos + 1, "Unmatched '${line[pos]}'"));
        }
        add(pos, pos + 1, cPunct);
        pos++;
        continue;
      }

      // ---- operators (runs) ----
      if (operators.contains(ch)) {
        var e = pos + 1;
        while (e < n && operators.contains(line.codeUnitAt(e))) {
          e++;
        }
        add(pos, e, cOperator);
        pos = e;
        continue;
      }

      // ---- punctuation ----
      if (punctuation.contains(ch)) {
        add(pos, pos + 1, cPunct);
        pos++;
        continue;
      }

      // ---- anything else ----
      add(pos, pos + 1, null);
      pos++;
    }

    for (final b in brackets) {
      errs.add(LexError(b.$2, b.$2 + 1, "Unclosed '${line[b.$2]}'"));
    }
    errs.sort((a, b) => a.start.compareTo(b.start));

    return LexResult(out, state, errs);
  }
}

class _Cached {
  final String text;
  final int startState;
  final int endState;
  final List<LexToken> tokens;
  final List<LexError> errors;
  const _Cached(
      this.text, this.startState, this.endState, this.tokens, this.errors);
}

/// Per-line highlighter with caching. Only lines that are actually painted are
/// lexed. For languages with multi-line constructs, the start state of a line
/// is derived from the lines above it and cached, so an edit only invalidates
/// the lines from the edited one downward (lazily).
class LineHighlighter {
  final CodeLanguage language;
  final bool showErrors;
  final Map<int, _Cached> _cache = {};
  int _validThrough = 0; // lines [0, _validThrough) have a consistent chain

  LineHighlighter(this.language, {this.showErrors = true});

  /// Call whenever the editor content changes.
  void onLinesChanged(CodeLines lines) {
    if (_cache.length > 20000) {
      _cache.clear();
      _validThrough = 0;
    }
    if (!language.hasMultiline) return;
    var d = 0;
    final limit = _validThrough < lines.length ? _validThrough : lines.length;
    while (d < limit) {
      final c = _cache[d];
      if (c == null) break;
      if (c.text != lines[d].text) break;
      d++;
    }
    if (d < _validThrough) _validThrough = d;
  }

  _Cached _lex(int i, String text, int startState) {
    final c = _cache[i];
    if (c != null && c.startState == startState && c.text == text) return c;
    final r = language.lexLine(text, startState);
    final e = _Cached(text, startState, r.endState, r.tokens, r.errors);
    _cache[i] = e;
    return e;
  }

  int _startState(CodeLines lines, int i) {
    if (!language.hasMultiline || i == 0) return 0;
    var j = _validThrough < i ? _validThrough : i;
    var state = 0;
    if (j > 0) {
      final prev = _cache[j - 1];
      if (prev == null) {
        j = 0;
      } else {
        state = prev.endState;
      }
    }
    while (j < i && j < lines.length) {
      final e = _lex(j, lines[j].text, state);
      state = e.endState;
      j++;
    }
    if (_validThrough < j) _validThrough = j;
    return state;
  }

  List<TextSpan> _spans(
      String text, List<LexToken> toks, List<LexError> errs) {
    final out = <TextSpan>[];
    for (final t in toks) {
      final base = t.color == null ? null : language.styleFor(t.color!);
      if (errs.isEmpty) {
        out.add(TextSpan(text: text.substring(t.start, t.end), style: base));
        continue;
      }
      final cuts = <int>{t.start, t.end};
      for (final er in errs) {
        if (er.start > t.start && er.start < t.end) cuts.add(er.start);
        if (er.end > t.start && er.end < t.end) cuts.add(er.end);
      }
      final pts = cuts.toList()..sort();
      for (var k = 0; k + 1 < pts.length; k++) {
        final s = pts[k];
        final e = pts[k + 1];
        final bad = errs.any((er) => s >= er.start && e <= er.end);
        out.add(TextSpan(
          text: text.substring(s, e),
          style: bad ? language.errorStyle(t.color) : base,
        ));
      }
    }
    return out;
  }

  TextSpan build(
    CodeLines lines,
    int index,
    CodeLine codeLine,
    TextStyle style,
    TextSpan base,
  ) {
    final text = codeLine.text;

    // The span must cover exactly the text of the line (optionally followed by
    // a line break). Otherwise leave the editor's own span untouched.
    final plainLength = base.toPlainText().length;
    final trailingNewline = plainLength == text.length + 1;
    if (plainLength != text.length && !trailingNewline) return base;

    final start = _startState(lines, index);
    final e = _lex(index, text, start);
    if (language.hasMultiline && _validThrough == index) {
      _validThrough = index + 1;
    }

    final errs = (showErrors && language.errors != null)
        ? e.errors
        : const <LexError>[];
    final children = <TextSpan>[
      ..._spans(text, e.tokens, errs),
      if (trailingNewline) const TextSpan(text: "\n"),
    ];
    return TextSpan(style: style, children: children);
  }
}

bool _markerMatch(String t, String m) {
  if (!t.startsWith(m)) return false;
  if (t.length == m.length) return true;
  final last = m.codeUnitAt(m.length - 1);
  if (!_isIdentStart(last) && !_isDigit(last)) return true;
  final next = t.codeUnitAt(m.length);
  return !(_isIdentStart(next) || _isDigit(next));
}

/// Folding regions defined by the user:
///  - start marker + end marker (a line beginning with `start` opens a region,
///    a line beginning with `end` closes it; nesting is supported),
///  - start marker + fixed `length` (that many lines after the start line),
///  - optionally by indentation.
/// Markers match at the beginning of a line (after indentation) and, for word
/// markers, only as whole words.
class FoldAnalyzer implements CodeChunkAnalyzer {
  final List<FoldRuleSpec> rules;
  final bool byIndent;

  FoldAnalyzer(this.rules, this.byIndent);

  int _indentOf(String text) {
    var w = 0;
    for (var i = 0; i < text.length; i++) {
      final c = text.codeUnitAt(i);
      if (c == 32) {
        w++;
      } else if (c == 9) {
        w += 4;
      } else {
        break;
      }
    }
    return w;
  }

  @override
  List<CodeChunk> run(CodeLines codeLines) {
    final n = codeLines.length;
    final chunks = <CodeChunk>[];
    final stacks = List.generate(rules.length, (_) => <int>[]);

    for (var i = 0; i < n; i++) {
      final t = codeLines[i].text.trimLeft();
      if (t.isEmpty) continue;
      for (var r = 0; r < rules.length; r++) {
        final rule = rules[r];
        final end = rule.end;
        var closed = false;
        if (end != null && stacks[r].isNotEmpty && _markerMatch(t, end)) {
          final start = stacks[r].removeLast();
          if (i > start) chunks.add(CodeChunk(start, i));
          closed = true;
        }
        if (closed && rule.start == end) continue;
        if (_markerMatch(t, rule.start)) {
          if (end != null) {
            stacks[r].add(i);
          } else if (rule.length != null && rule.length! > 0) {
            final last = (i + rule.length!) < n ? i + rule.length! : n - 1;
            if (last > i) chunks.add(CodeChunk(i, last));
          }
        }
      }
    }

    if (byIndent) {
      final stack = <(int, int)>[]; // (indent, line)
      var lastNonEmpty = -1;
      void closeTop() {
        final top = stack.removeLast();
        if (lastNonEmpty > top.$2) chunks.add(CodeChunk(top.$2, lastNonEmpty));
      }

      for (var i = 0; i < n; i++) {
        final text = codeLines[i].text;
        if (text.trim().isEmpty) continue;
        final ind = _indentOf(text);
        while (stack.isNotEmpty && stack.last.$1 >= ind) {
          closeTop();
        }
        stack.add((ind, i));
        lastNonEmpty = i;
      }
      while (stack.isNotEmpty) {
        closeTop();
      }
    }

    chunks.sort((a, b) =>
        a.index != b.index ? a.index.compareTo(b.index) : b.end.compareTo(a.end));
    return chunks;
  }
}