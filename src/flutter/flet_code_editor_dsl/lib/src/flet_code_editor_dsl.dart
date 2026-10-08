import 'package:flutter/material.dart';
import 'package:flet/flet.dart';
import 'package:code_text_field/code_text_field.dart';

class _CompiledRule {
  final RegExp regex;
  final TextStyle style;
  _CompiledRule(this.regex, this.style);
}

/// A CodeController that highlights text line by line and caches the result
/// per line. When one line is edited, only that line is re-highlighted; the
/// spans of every unchanged line are reused as they are.
class _LineCachedController extends CodeController {
  _LineCachedController({String? text})
      : super(text: text ?? "", patternMap: const {});

  List<_CompiledRule> _rules = const [];
  String _signature = "";
  bool _incremental = true;
  bool _disposed = false;
  Map<String, List<TextSpan>> _cache = {};

  /// Applies rules only when their signature changed. [compile] is called
  /// lazily, so regexes are not rebuilt on ordinary rebuilds (typing).
  void configure(
    String signature,
    bool incremental,
    List<_CompiledRule> Function() compile,
  ) {
    if (signature == _signature) return;
    final first = _signature.isEmpty;
    _signature = signature;
    _incremental = incremental;
    _rules = compile();
    _cache = {};
    if (!first) {
      // Repaint with the new rules (cannot notify during build).
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_disposed) notifyListeners();
      });
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  List<TextSpan> _highlight(String line) {
    if (line.isEmpty) return const [];
    // For every character, the index of the first rule that matched it.
    final owner = List<int>.filled(line.length, -1);
    for (var i = 0; i < _rules.length; i++) {
      for (final m in _rules[i].regex.allMatches(line)) {
        for (var k = m.start; k < m.end; k++) {
          if (owner[k] == -1) owner[k] = i;
        }
      }
    }
    final spans = <TextSpan>[];
    var start = 0;
    for (var k = 1; k <= line.length; k++) {
      if (k == line.length || owner[k] != owner[start]) {
        final o = owner[start];
        spans.add(TextSpan(
          text: line.substring(start, k),
          style: o == -1 ? null : _rules[o].style,
        ));
        start = k;
      }
    }
    return spans;
  }

  @override
  TextSpan buildTextSpan({
    BuildContext? context,
    TextStyle? style,
    bool? withComposing,
  }) {
    if (_rules.isEmpty) {
      return TextSpan(style: style, text: text);
    }

    final chunks = _incremental ? text.split('\n') : <String>[text];
    final next = <String, List<TextSpan>>{};
    final children = <TextSpan>[];

    for (var i = 0; i < chunks.length; i++) {
      final line = chunks[i];
      final spans = next[line] ?? _cache[line] ?? _highlight(line);
      next[line] = spans;
      children.addAll(spans);
      if (_incremental && i < chunks.length - 1) {
        children.add(const TextSpan(text: "\n"));
      }
    }
    // Keep only the lines present in the current text (bounded cache).
    _cache = next;

    return TextSpan(style: style, children: children);
  }
}

class FletCodeFieldControl extends StatefulWidget {
  final Control control;

  FletCodeFieldControl({Key? key, required this.control})
      : super(key: key ?? ValueKey("control_${control.id}"));

  @override
  State<FletCodeFieldControl> createState() => _FletCodeFieldControlState();
}

class _FletCodeFieldControlState extends State<FletCodeFieldControl> {
  late _LineCachedController _controller;
  String _value = "";

  @override
  void initState() {
    super.initState();
    _value = widget.control.getString("value", "")!;
    _controller = _LineCachedController(text: _value);
    _applyRules();
    _controller.addListener(_handleControllerChange);
  }

  @override
  void dispose() {
    _controller.removeListener(_handleControllerChange);
    _controller.dispose();
    super.dispose();
  }

  void _handleControllerChange() {
    final text = _controller.text;
    if (_value == text) return; // selection-only change: nothing to do
    _value = text;
    widget.control.updateProperties({"value": text});
    if (widget.control.getBool("on_change", false)!) {
      widget.control.triggerEvent("change", text);
    }
  }

  void _applyRules() {
    final control = widget.control;
    final enabled = control.getBool("syntax_highlighting", true)!;
    final incremental = control.getBool("incremental_highlighting", true)!;
    final rules = enabled ? control.get("rules") : null;
    final signature = "$enabled|$incremental|$rules";
    _controller.configure(
      signature,
      incremental,
      () => _compileRules(rules),
    );
  }

  List<_CompiledRule> _compileRules(dynamic rules) {
    final compiled = <_CompiledRule>[];
    if (rules is List) {
      for (final rule in rules) {
        if (rule is Map) {
          final pattern = rule["pattern"]?.toString();
          final colorHex = rule["color"]?.toString();
          if (pattern == null || colorHex == null) continue;
          try {
            compiled.add(_CompiledRule(
              RegExp(pattern, multiLine: true),
              TextStyle(color: _parseColor(colorHex)),
            ));
          } catch (_) {
            // Invalid pattern or color: skip this rule.
          }
        }
      }
    }
    return compiled;
  }

  Color _parseColor(String hex) {
    var clean = hex.replaceAll("#", "");
    if (clean.length == 6) clean = "FF$clean";
    return Color(int.parse(clean, radix: 16));
  }

  @override
  Widget build(BuildContext context) {
    final control = widget.control;

    String value = control.getString("value", "")!;
    if (value != _controller.text) {
      _value = value;
      _controller.text = value;
    }
    _applyRules(); // cheap: does nothing unless rules/flags changed

    final lineNumbers = control.getBool("line_numbers", true)!;
    final wrap = control.getBool("wrap", false)!;

    final vMode = control.getString("vertical_mode", "fixed")!;
    final minLines = control.getInt("min_lines");
    final maxLines = control.getInt("max_lines");

    bool expands = false;
    int? minL;
    int? maxL;
    switch (vMode) {
      case "bounded":
        minL = minLines ?? 1;
        maxL = maxLines ?? 10;
        break;
      case "unlimited":
        break;
      case "fixed":
      default:
        expands = true;
    }

    Widget field = CodeField(
      controller: _controller,
      lineNumbers: lineNumbers,
      wrap: wrap,
      expands: expands,
      minLines: minL,
      maxLines: maxL,
      textStyle: const TextStyle(fontFamily: "Consolas", fontSize: 12),
    );

    return LayoutControl(control: control, child: field);
  }
}
