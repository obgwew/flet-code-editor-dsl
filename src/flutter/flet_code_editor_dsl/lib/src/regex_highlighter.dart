import 'package:flutter/material.dart';
import 'package:re_editor/re_editor.dart';

import 'tokenizer.dart';

class _RxRule {
  final RegExp re;
  final Color color;
  _RxRule(this.re, this.color);
}

class _RxErr {
  final RegExp re;
  final String message;
  _RxErr(this.re, this.message);
}

/// Everything the regex engine needs, parsed from the Flet control values.
class RegexSpec {
  final List<_RxRule> rules;
  final List<_RxErr> errors;
  final Color errorColor;
  final bool wavy;
  final List<FoldRuleSpec> folds;
  final bool foldByIndent;

  RegexSpec({
    required this.rules,
    required this.errors,
    required this.errorColor,
    required this.wavy,
    required this.folds,
    required this.foldByIndent,
  });

  bool get hasHighlighting => rules.isNotEmpty || errors.isNotEmpty;

  factory RegexSpec.fromValues({
    required dynamic rules,
    required dynamic errorRules,
    required dynamic folds,
    required String? errorColor,
    required bool wavy,
    required bool foldByIndent,
  }) {
    final r = <_RxRule>[];
    if (rules is List) {
      for (final m in rules) {
        if (m is! Map) continue;
        final pattern = m["pattern"]?.toString();
        final color = parseHexColor(m["color"]?.toString());
        if (pattern == null || pattern.isEmpty || color == null) continue;
        try {
          r.add(_RxRule(RegExp(pattern), color));
        } catch (_) {/* invalid pattern: skip */}
      }
    }
    final e = <_RxErr>[];
    if (errorRules is List) {
      for (final m in errorRules) {
        if (m is! Map) continue;
        final pattern = m["pattern"]?.toString();
        if (pattern == null || pattern.isEmpty) continue;
        try {
          e.add(_RxErr(RegExp(pattern), m["message"]?.toString() ?? ""));
        } catch (_) {}
      }
    }
    final f = <FoldRuleSpec>[];
    if (folds is List) {
      for (final m in folds) {
        if (m is! Map) continue;
        final start = m["start"]?.toString() ?? "";
        if (start.isEmpty) continue;
        final end = m["end"]?.toString();
        final len = m["length"];
        f.add(FoldRuleSpec(
          start,
          (end == null || end.isEmpty) ? null : end,
          len is num ? len.toInt() : null,
        ));
      }
    }
    return RegexSpec(
      rules: r,
      errors: e,
      errorColor: parseHexColor(errorColor) ?? const Color(0xFFF44747),
      wavy: wavy,
      folds: f,
      foldByIndent: foldByIndent,
    );
  }
}

class _RxLine {
  final List<LexToken> tokens;
  final List<LexError> errors;
  const _RxLine(this.tokens, this.errors);
}

/// Regex based highlighter. Same output as the tokenizer engine (colored
/// tokens + error underlines), but each line is matched with the user's
/// regular expressions. Rules work inside a single line; the first rule that
/// matches a character wins. Results are cached per line text.
class RegexHighlighter implements CodeHighlighter {
  final RegexSpec spec;
  final bool showErrors;
  final Map<String, _RxLine> _cache = {};
  final Map<Color, TextStyle> _styles = {};
  final Map<Color?, TextStyle> _errStyles = {};

  RegexHighlighter(this.spec, {this.showErrors = true});

  TextStyle _style(Color c) => _styles.putIfAbsent(c, () => TextStyle(color: c));

  TextStyle _errorStyle(Color? base) => _errStyles.putIfAbsent(
        base,
        () => TextStyle(
          color: base,
          decoration: TextDecoration.underline,
          decorationColor: spec.errorColor,
          decorationStyle:
              spec.wavy ? TextDecorationStyle.wavy : TextDecorationStyle.solid,
          decorationThickness: 1.5,
        ),
      );

  _RxLine _lex(String line) {
    final hit = _cache[line];
    if (hit != null) return hit;

    final tokens = <LexToken>[];
    if (line.isNotEmpty) {
      final owner = List<int>.filled(line.length, -1);
      for (var i = 0; i < spec.rules.length; i++) {
        for (final m in spec.rules[i].re.allMatches(line)) {
          if (m.end <= m.start) continue;
          for (var k = m.start; k < m.end; k++) {
            if (owner[k] == -1) owner[k] = i;
          }
        }
      }
      var start = 0;
      for (var k = 1; k <= line.length; k++) {
        if (k == line.length || owner[k] != owner[start]) {
          final o = owner[start];
          tokens.add(LexToken(start, k, o == -1 ? null : spec.rules[o].color));
          start = k;
        }
      }
    }

    final errs = <LexError>[];
    if (spec.errors.isNotEmpty && line.isNotEmpty) {
      for (final er in spec.errors) {
        for (final m in er.re.allMatches(line)) {
          if (m.end <= m.start) continue;
          errs.add(LexError(m.start, m.end, er.message));
        }
      }
      errs.sort((a, b) => a.start.compareTo(b.start));
    }

    final res = _RxLine(tokens, errs);
    _cache[line] = res;
    return res;
  }

  @override
  void onLinesChanged(CodeLines lines) {
    if (_cache.length > 5000) _cache.clear(); // keep the cache bounded
  }

  List<TextSpan> _spans(String text, _RxLine l, bool withErrors) {
    final out = <TextSpan>[];
    final errs = withErrors ? l.errors : const <LexError>[];
    for (final t in l.tokens) {
      final base = t.color == null ? null : _style(t.color!);
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
          style: bad ? _errorStyle(t.color) : base,
        ));
      }
    }
    return out;
  }

  @override
  TextSpan build(
    CodeLines lines,
    int index,
    CodeLine codeLine,
    TextStyle style,
    TextSpan base,
  ) {
    final text = codeLine.text;
    final plainLength = base.toPlainText().length;
    final trailingNewline = plainLength == text.length + 1;
    if (plainLength != text.length && !trailingNewline) return base;

    final l = _lex(text);
    return TextSpan(style: style, children: [
      ..._spans(text, l, showErrors),
      if (trailingNewline) const TextSpan(text: "\n"),
    ]);
  }
}
