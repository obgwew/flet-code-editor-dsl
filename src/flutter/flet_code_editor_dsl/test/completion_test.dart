import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:re_editor/re_editor.dart';

import '../lib/src/completion.dart';
import '../lib/src/regex_highlighter.dart';
import '../lib/src/tokenizer.dart';

void main() {
  group('sigil completion', () {
    test('a bare trigger and ordinary text do not produce candidates', () {
      expect(completionPrefixAt(r'$', 1), isEmpty);
      expect(
          completionCandidates(
            prefix: '',
            words: const ['delete', 'discord'],
            trigger: r'$',
          ),
          isEmpty);
      expect(
          completionHasTriggerAt(
            line: 'delete',
            offset: 6,
            prefix: 'delete',
            trigger: r'$',
          ),
          isFalse);
      expect(
          completionHasTriggerAt(
            line: r'$',
            offset: 1,
            prefix: '',
            trigger: r'$',
          ),
          isFalse);
    });

    test('opens only after the sigil and one identifier character', () {
      const line = r'$d';
      final prefix = completionPrefixAt(line, line.length);
      expect(prefix, 'd');
      expect(
          completionHasTriggerAt(
            line: line,
            offset: line.length,
            prefix: prefix,
            trigger: r'$',
          ),
          isTrue);
      expect(
          completionCandidates(
            prefix: prefix,
            words: const ['delete', 'discord', 'day'],
            trigger: r'$',
          ),
          [r'$day', r'$delete', r'$discord']);
    });

    test('requires the sigil immediately before the command word', () {
      for (final line in ['plain d', r'$-d', r'$ d']) {
        final prefix = completionPrefixAt(line, line.length);
        expect(
            completionHasTriggerAt(
              line: line,
              offset: line.length,
              prefix: prefix,
              trigger: r'$',
            ),
            isFalse,
            reason: line);
      }
      for (final line in [r'call($d', r'other.$d']) {
        final prefix = completionPrefixAt(line, line.length);
        expect(
            completionHasTriggerAt(
              line: line,
              offset: line.length,
              prefix: prefix,
              trigger: r'$',
            ),
            isTrue,
            reason: line);
      }
    });

    test('accepts vocabularies with or without the sigil and inserts once', () {
      final withSigils = completionCandidates(
        prefix: 'del',
        words: const [r'$delete', 'delegate'],
        trigger: r'$',
      );
      expect(withSigils, [r'$delegate', r'$delete']);
      expect(
          completionInsertion(
            suggestion: r'$delete',
            trigger: r'$',
            hasTrigger: true,
          ),
          'delete');
    });

    test('remembers selected items ahead of alphabetical order', () {
      expect(
          completionCandidates(
            prefix: 'd',
            words: const ['delete', 'discord', 'day'],
            trigger: r'$',
            recent: const {'discord': 4},
            limit: 2,
          ),
          [r'$discord', r'$day']);
    });

    test('returns every matching command unless a limit is requested', () {
      final candidates = completionCandidates(
        prefix: 'd',
        words: const [
          'dance',
          'day',
          'delete',
          'dinner',
          'disable',
          'discord',
        ],
        trigger: r'$',
      );
      expect(candidates.toSet(), {
        r'$dance',
        r'$day',
        r'$delete',
        r'$dinner',
        r'$disable',
        r'$discord',
      });
    });
  });

  group('highlighting scope', () {
    CodeLineEditingController controller(String text) =>
        CodeLineEditingController.fromText(text);

    Color? tokenColor(TextSpan span, String token) {
      for (final child in span.children ?? const <InlineSpan>[]) {
        if (child is TextSpan) {
          final color = tokenColor(child, token);
          if (color != null) return color;
        }
      }
      if (span.text?.contains(token) == true && span.style?.color != null) {
        return span.style!.color;
      }
      return null;
    }

    test('current_line keeps the unchanged line colored after an edit', () {
      final lang = CodeLanguage.fromJson({
        'words': [
          {
            'words': ['const'],
            'color': '#FF0000'
          },
          {
            'words': ['return'],
            'color': '#0000FF'
          },
        ],
      });
      final highlighter = LineHighlighter(lang);
      final before = controller('const x\nreturn y');
      final baseStyle = const TextStyle(color: Color(0xFFCCCCCC));
      final beforeLine1 = before.codeLines[1];
      final original = highlighter.build(
        before.codeLines,
        1,
        beforeLine1,
        baseStyle,
        TextSpan(text: beforeLine1.text),
      );
      expect(tokenColor(original, 'return'), const Color(0xFF0000FF));

      final after = controller('let x\nreturn y');
      highlighter.onLinesChanged(after.codeLines, currentLineOnly: true);
      final unchangedLine = after.codeLines[1];
      final retained = highlighter.build(
        after.codeLines,
        1,
        unchangedLine,
        baseStyle,
        TextSpan(text: unchangedLine.text),
      );
      expect(tokenColor(retained, 'return'), const Color(0xFF0000FF));
      before.dispose();
      after.dispose();
    });

    test('multiline token state is recomputed below an edited opener', () {
      final lang = CodeLanguage.fromJson({
        'block_comments': [
          {'start': '/*', 'end': '*/'},
        ],
        'colors': {'comment': '#FF0000'},
      });
      final highlighter = LineHighlighter(lang);
      final before = controller('/* open\ninside\n*/ let');
      const baseStyle = TextStyle(color: Color(0xFFCCCCCC));
      final inside = before.codeLines[1];
      final oldSpan = highlighter.build(
        before.codeLines,
        1,
        inside,
        baseStyle,
        TextSpan(text: inside.text),
      );
      expect(tokenColor(oldSpan, 'inside'), const Color(0xFFFF0000));

      final after = controller('plain  \ninside\n*/ let');
      highlighter.onLinesChanged(after.codeLines, currentLineOnly: true);
      final newInside = after.codeLines[1];
      final newSpan = highlighter.build(
        after.codeLines,
        1,
        newInside,
        baseStyle,
        TextSpan(text: newInside.text),
      );
      expect(tokenColor(newSpan, 'inside'), isNull);
      before.dispose();
      after.dispose();
    });

    test('regex mode keeps colors on unedited lines in current_line scope', () {
      final spec = RegexSpec.fromValues(
        rules: [
          {'pattern': r'\bconst\b', 'color': '#FF0000'},
          {'pattern': r'\breturn\b', 'color': '#0000FF'},
        ],
        errorRules: const [],
        folds: const [],
        errorColor: '#F44747',
        wavy: true,
        foldByIndent: false,
      );
      final highlighter = RegexHighlighter(spec);
      final before = controller('const x\nreturn y');
      const baseStyle = TextStyle(color: Color(0xFFCCCCCC));
      final first = before.codeLines[1];
      final original = highlighter.build(
        before.codeLines,
        1,
        first,
        baseStyle,
        TextSpan(text: first.text),
      );
      expect(tokenColor(original, 'return'), const Color(0xFF0000FF));

      final after = controller('let x\nreturn y');
      highlighter.onLinesChanged(after.codeLines, currentLineOnly: true);
      final unchanged = after.codeLines[1];
      final retained = highlighter.build(
        after.codeLines,
        1,
        unchanged,
        baseStyle,
        TextSpan(text: unchanged.text),
      );
      expect(tokenColor(retained, 'return'), const Color(0xFF0000FF));
      before.dispose();
      after.dispose();
    });
  });
}
