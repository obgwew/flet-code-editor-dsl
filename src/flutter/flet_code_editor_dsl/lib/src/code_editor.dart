import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flet/flet.dart';
import 'package:re_editor/re_editor.dart';

import 'tokenizer.dart';

/// FletCodeEditor: a fully custom editor (re_editor). Each line is laid out
/// and painted independently and only visible lines are built. Highlighting,
/// error underlines and folding are driven by the `Language` description
/// (see tokenizer.dart); no regexes are involved.
class FletCodeEditorControl extends StatefulWidget {
  final Control control;

  FletCodeEditorControl({Key? key, required this.control})
      : super(key: key ?? ValueKey("control_${control.id}"));

  @override
  State<FletCodeEditorControl> createState() => _FletCodeEditorControlState();
}

class _FletCodeEditorControlState extends State<FletCodeEditorControl> {
  late final CodeLineEditingController _controller;
  Timer? _debounce;

  // Last value read from the Flet control (detects changes made from Python).
  String _propValue = "";
  // Last text pushed to Python (ignores our own echo).
  String _lastSent = "";

  // Language / feature state.
  String _sig = "";
  String _languageJson = "";
  CodeLanguage? _language;
  LineHighlighter? _highlighter;
  CodeChunkAnalyzer _chunkAnalyzer = NonCodeChunkAnalyzer();
  bool _showFoldIndicator = false;
  int _epoch = 0; // bumped when language/flags change, to repaint every line

  int _lineCount = 1;
  double _lineHeightFor = -1;
  String _lineHeightFamily = "";
  double _lineHeight = 16;

  @override
  void initState() {
    super.initState();
    _propValue = widget.control.getString("value", "")!;
    _lastSent = _propValue;
    _controller = CodeLineEditingController(spanBuilder: _spanBuilder);
    if (_propValue.isNotEmpty) {
      _controller.text = _propValue;
    }
    _lineCount = _controller.codeLines.length;
    _controller.addListener(_onControllerChanged);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.removeListener(_onControllerChanged);
    _controller.dispose();
    super.dispose();
  }

  // Called by the editor for every line it paints.
  TextSpan _spanBuilder({
    required CodeLine codeLine,
    required BuildContext context,
    required int index,
    required TextStyle style,
    required TextSpan textSpan,
  }) {
    final h = _highlighter;
    if (h == null) return textSpan;
    return h.build(_controller.codeLines, index, codeLine, style, textSpan);
  }

  void _onControllerChanged() {
    if (!mounted) return;
    _highlighter?.onLinesChanged(_controller.codeLines);

    // Resize in "bounded"/"unlimited" modes.
    final mode = widget.control.getString("vertical_mode", "fixed")!;
    if (mode == "fixed") return;
    final n = _controller.codeLines.length;
    if (n != _lineCount) setState(() => _lineCount = n);
  }

  // Called by the editor on every text change.
  void _handleChanged(CodeLineEditingValue value) {
    final text = _controller.text;
    if (text == _lastSent) return;
    _debounce?.cancel();
    final ms = widget.control.getInt("debounce_ms", 150)!;
    _debounce = Timer(Duration(milliseconds: ms < 0 ? 0 : ms), () {
      if (!mounted) return;
      final current = _controller.text;
      if (current == _lastSent) return;
      _lastSent = current;
      widget.control.updateProperties({"value": current});
      if (widget.control.getBool("on_change", false)!) {
        widget.control.triggerEvent("change", current);
      }
    });
  }

  CodeLanguage? _parseLanguage(String json) {
    if (json.isEmpty) return null;
    try {
      final data = jsonDecode(json);
      if (data is! Map<String, dynamic>) return null;
      return CodeLanguage.fromJson(data);
    } catch (_) {
      return null; // invalid language spec: no highlighting
    }
  }

  double _measureLineHeight(String family, double size) {
    if (_lineHeightFor == size && _lineHeightFamily == family) {
      return _lineHeight;
    }
    final painter = TextPainter(
      text: TextSpan(
        text: "Ag",
        style: TextStyle(fontFamily: family, fontSize: size),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    _lineHeightFor = size;
    _lineHeightFamily = family;
    _lineHeight = painter.height;
    return _lineHeight;
  }

  /// Visible size from a level 1..30: level / 30 of the available space
  /// (level 30 covers it, level 1 is a small box), with a small minimum.
  double _levelSize(int level, double available) {
    final l = level < 1 ? 1 : (level > 30 ? 30 : level);
    return math.max(48.0, available * l / 30.0);
  }

  @override
  Widget build(BuildContext context) {
    final control = widget.control;

    // Value changed from Python -> update the editor.
    final value = control.getString("value", "")!;
    if (value != _propValue) {
      _propValue = value;
      if (value != _lastSent && value != _controller.text) {
        _lastSent = value;
        _controller.text = value;
      }
    }

    // Language and feature flags: re-created only when something changed.
    final languageJson = control.getString("language", "")!;
    final enabled = control.getBool("syntax_highlighting", true)!;
    final showErrors = control.getBool("show_errors", true)!;
    final folding = control.getBool("code_folding", true)!;
    final sig = "$enabled|$showErrors|$folding|$languageJson";
    if (sig != _sig) {
      _sig = sig;
      if (languageJson != _languageJson || _language == null) {
        _languageJson = languageJson;
        _language = _parseLanguage(languageJson);
      }
      final lang = _language;
      _highlighter = (enabled && lang != null)
          ? LineHighlighter(lang, showErrors: showErrors)
          : null;
      _highlighter?.onLinesChanged(_controller.codeLines);
      if (folding && lang != null && lang.hasFolding) {
        _chunkAnalyzer = FoldAnalyzer(lang.folds, lang.foldByIndent);
        _showFoldIndicator = true;
      } else {
        _chunkAnalyzer = NonCodeChunkAnalyzer();
        _showFoldIndicator = false;
      }
      _epoch++; // forces every line to be rebuilt
    }

    final fontFamily = control.getString("font_family", "Consolas")!;
    final fontSize = control.getDouble("font_size", 12.0)!;
    final textColor = parseHexColor(control.getString("default_color"));
    final bgColor = parseHexColor(control.getString("background_color"));
    final lineNumbers = control.getBool("line_numbers", true)!;
    final wrap = control.getBool("wrap", false)!;
    final readOnly = control.getBool("read_only", false)!;
    final showFold = _showFoldIndicator;

    Widget editor = CodeEditor(
      key: ValueKey("editor_$_epoch"),
      controller: _controller,
      readOnly: readOnly,
      wordWrap: wrap,
      padding: const EdgeInsets.all(4),
      onChanged: _handleChanged,
      chunkAnalyzer: _chunkAnalyzer,
      style: CodeEditorStyle(
        fontFamily: fontFamily,
        fontSize: fontSize,
        textColor: textColor,
        backgroundColor: bgColor,
      ),
      indicatorBuilder: (lineNumbers || showFold)
          ? (context, editingController, chunkController, notifier) {
              return Row(
                children: [
                  if (lineNumbers)
                    DefaultCodeLineNumber(
                      controller: editingController,
                      notifier: notifier,
                    ),
                  if (showFold)
                    DefaultCodeChunkIndicator(
                      width: 20,
                      controller: chunkController,
                      notifier: notifier,
                    ),
                ],
              );
            }
          : null,
    );

    // Vertical size from the number of lines ("bounded"/"unlimited").
    final vMode = control.getString("vertical_mode", "fixed")!;
    final heightFromLines = vMode == "bounded" || vMode == "unlimited";
    if (heightFromLines) {
      var lines = _lineCount < 1 ? 1 : _lineCount;
      if (vMode == "bounded") {
        final minL = control.getInt("min_lines") ?? 1;
        final maxL = control.getInt("max_lines") ?? 10;
        lines = lines.clamp(minL, maxL < minL ? minL : maxL);
      }
      final lineH = _measureLineHeight(fontFamily, fontSize);
      editor = SizedBox(height: lines * lineH + 8 + 2, child: editor);
    }

    // Visible box size (levels 1..30). Skipped when the size is given
    // explicitly (width/height/expand) or derived from the line count.
    final expandValue = control.get("expand");
    final expanded =
        expandValue == true || (expandValue is num && expandValue > 0);
    final explicitW = control.getDouble("width") != null;
    final explicitH = control.getDouble("height") != null;
    final wl = (explicitW || expanded) ? null : control.getInt("width_level");
    final hl = (explicitH || expanded || heightFromLines)
        ? null
        : control.getInt("height_level");

    if (wl != null || hl != null) {
      final inner = editor;
      editor = LayoutBuilder(builder: (ctx, c) {
        final screen = MediaQuery.sizeOf(ctx);
        final aw = c.maxWidth.isFinite ? c.maxWidth : screen.width;
        final ah = c.maxHeight.isFinite ? c.maxHeight : screen.height;
        return SizedBox(
          width: wl == null ? null : _levelSize(wl, aw),
          height: hl == null ? null : _levelSize(hl, ah),
          child: inner,
        );
      });
    }

    return LayoutControl(control: control, child: editor);
  }
}