import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, TargetPlatform;
import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:flet/flet.dart';
import 'package:re_editor/re_editor.dart';

import 'regex_highlighter.dart';
import 'tokenizer.dart';

/// Shared editor widget (re_editor). The only difference between
/// `EditorTokens` and `EditorRegex` is the highlighting engine:
///   regexMode == false -> hand-written tokenizer (`Language` JSON)
///   regexMode == true  -> regular expressions (`rules` / `error_rules`)
/// Everything else (line numbers, errors, folding, mobile controls,
/// magnifier, scroll hand-off, cut/copy/paste) is common.
class FletEditorControl extends StatefulWidget {
  final Control control;
  final bool regexMode;

  FletEditorControl({Key? key, required this.control, required this.regexMode})
      : super(key: key ?? ValueKey("control_${control.id}"));

  @override
  State<FletEditorControl> createState() => _FletEditorControlState();
}

/// "page_first": the page (nearest vertical Scrollable above the editor)
/// consumes a vertical drag until it reaches its limit in that direction;
/// only then does the editor scroll.
class _PageFirstPhysics extends ClampingScrollPhysics {
  final ScrollPosition? Function() page;
  const _PageFirstPhysics(this.page, {super.parent});

  @override
  _PageFirstPhysics applyTo(ScrollPhysics? ancestor) =>
      _PageFirstPhysics(page, parent: buildParent(ancestor));

  @override
  double applyPhysicsToUserOffset(ScrollMetrics position, double offset) {
    if (position.axis == Axis.vertical && offset != 0) {
      final p = page();
      if (p != null) {
        final canPage = offset > 0
            ? p.pixels > p.minScrollExtent + 0.5
            : p.pixels < p.maxScrollExtent - 0.5;
        if (canPage) {
          final target =
              (p.pixels - offset).clamp(p.minScrollExtent, p.maxScrollExtent);
          p.jumpTo(target.toDouble());
          return 0; // the editor itself does not move
        }
      }
    }
    return super.applyPhysicsToUserOffset(position, offset);
  }
}

const Map<String, IconData> _toolbarIcons = {
  "undo": Icons.undo,
  "redo": Icons.redo,
  "cut": Icons.content_cut,
  "copy": Icons.content_copy,
  "paste": Icons.content_paste,
  "select_all": Icons.select_all,
  "select_mode": Icons.highlight_alt,
  "left": Icons.keyboard_arrow_left,
  "right": Icons.keyboard_arrow_right,
  "up": Icons.keyboard_arrow_up,
  "down": Icons.keyboard_arrow_down,
  "home": Icons.first_page,
  "end": Icons.last_page,
  "tab": Icons.keyboard_tab,
};

const List<String> _defaultToolbar = [
  "undo", "redo", "cut", "copy", "paste", "select_all", "select_mode",
  "left", "right", "up", "down", "home", "end", "tab",
];

const List<String> _defaultSelectionMenu = ["cut", "copy", "paste", "select_all"];

class _FletEditorControlState extends State<FletEditorControl> {
  late final CodeLineEditingController _controller;
  Timer? _debounce;

  String _propValue = "";
  String _lastSent = "";

  // Language / feature state.
  String _sig = "";
  String _languageJson = "";
  CodeLanguage? _language;
  CodeHighlighter? _highlighter;
  CodeChunkAnalyzer _chunkAnalyzer = NonCodeChunkAnalyzer();
  bool _showFoldIndicator = false;
  int _epoch = 0;

  int _lineCount = 1;
  double _lineHeightFor = -1;
  String _lineHeightFamily = "";
  double _lineHeight = 16;

  // Mobile helpers.
  bool _selectMode = false; // cursor pad / arrows extend the selection
  Timer? _lpTimer;
  Offset? _down;
  int? _pointer;
  final ValueNotifier<Offset?> _magnifierAt = ValueNotifier<Offset?>(null);

  // Floating cut/copy/paste menu (re_editor only shows one when it is given a
  // toolbar controller). Only used on Android/iOS.
  late final MobileSelectionToolbarController _menuController =
      MobileSelectionToolbarController(builder: _menuBuilder);

  Widget _menuBuilder({
    required BuildContext context,
    required TextSelectionToolbarAnchors anchors,
    required CodeLineEditingController controller,
    required VoidCallback onDismiss,
    required VoidCallback onRefresh,
  }) {
    final readOnly = widget.control.getBool("read_only", false)!;
    final raw = widget.control.get("selection_menu_items");
    final ids = raw is List
        ? [for (final i in raw) i.toString()]
        : _defaultSelectionMenu;
    final loc = MaterialLocalizations.of(context);
    final hasSelection = controller.selectedText.isNotEmpty;

    final items = <ContextMenuButtonItem>[];
    void add(String label, VoidCallback run) {
      items.add(ContextMenuButtonItem(
        label: label,
        onPressed: () {
          run();
          onDismiss();
        },
      ));
    }

    for (final id in ids) {
      switch (id) {
        case "cut":
          if (!readOnly && hasSelection) add(loc.cutButtonLabel, () => _cut());
          break;
        case "copy":
          if (hasSelection) add(loc.copyButtonLabel, () => _copy());
          break;
        case "paste":
          if (!readOnly) add(loc.pasteButtonLabel, () => _paste());
          break;
        case "select_all":
          add(loc.selectAllButtonLabel, () => _controller.selectAll());
          break;
        case "undo":
          if (!readOnly) add("Undo", () => _controller.undo());
          break;
        case "redo":
          if (!readOnly) add("Redo", () => _controller.redo());
          break;
      }
    }
    if (items.isEmpty) return const SizedBox.shrink();
    return AdaptiveTextSelectionToolbar.buttonItems(
      anchors: anchors,
      buttonItems: items,
    );
  }

  bool get _isMobilePlatform =>
      defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS;

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
    _lpTimer?.cancel();
    _menuController.hide(context);
    _magnifierAt.dispose();
    _controller.removeListener(_onControllerChanged);
    _controller.dispose();
    super.dispose();
  }

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
    final mode = widget.control.getString("vertical_mode", "fixed")!;
    if (mode == "fixed") return;
    final n = _controller.codeLines.length;
    if (n != _lineCount) setState(() => _lineCount = n);
  }

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
      return null;
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

  double _levelSize(int level, double available) {
    final l = level < 1 ? 1 : (level > 30 ? 30 : level);
    return math.max(48.0, available * l / 30.0);
  }

  // ------------------------------------------------------------------
  // Clipboard / cursor actions (used by the mobile toolbar).
  // Paste is implemented here instead of relying on the built-in path:
  // text is read straight from the platform clipboard, line endings are
  // normalised and control characters are removed before insertion.
  // ------------------------------------------------------------------
  Future<void> _copy() async {
    final t = _controller.selectedText;
    if (t.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: t));
  }

  Future<void> _cut() async {
    if (widget.control.getBool("read_only", false)!) return _copy();
    final t = _controller.selectedText;
    if (t.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: t));
    _controller.replaceSelection("");
  }

  Future<void> _paste() async {
    if (widget.control.getBool("read_only", false)!) return;
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    var t = data?.text;
    if (t == null || t.isEmpty) return;
    t = t
        .replaceAll("\r\n", "\n")
        .replaceAll("\r", "\n")
        .replaceAll("\u0000", "")
        .replaceAll("\u2028", "\n")
        .replaceAll("\u2029", "\n");
    if (t.isEmpty) return;
    _controller.replaceSelection(t);
  }

  void _step(AxisDirection d) {
    if (_selectMode) {
      _controller.extendSelection(d);
    } else {
      _controller.moveCursor(d);
    }
  }

  void _lineEdge(bool toEnd) {
    final s = _controller.selection;
    final idx = s.extentIndex;
    final off = toEnd ? _controller.codeLines[idx].text.length : 0;
    if (_selectMode) {
      _controller.selection = CodeLineSelection(
        baseIndex: s.baseIndex,
        baseOffset: s.baseOffset,
        extentIndex: idx,
        extentOffset: off,
      );
    } else {
      _controller.selection = CodeLineSelection.collapsed(
        index: idx,
        offset: off,
      );
    }
  }

  Future<void> _act(String id) async {
    final readOnly = widget.control.getBool("read_only", false)!;
    switch (id) {
      case "undo":
        if (!readOnly) _controller.undo();
        break;
      case "redo":
        if (!readOnly) _controller.redo();
        break;
      case "cut":
        await _cut();
        break;
      case "copy":
        await _copy();
        break;
      case "paste":
        await _paste();
        break;
      case "select_all":
        _controller.selectAll();
        break;
      case "select_mode":
        setState(() => _selectMode = !_selectMode);
        break;
      case "left":
        _step(AxisDirection.left);
        break;
      case "right":
        _step(AxisDirection.right);
        break;
      case "up":
        _step(AxisDirection.up);
        break;
      case "down":
        _step(AxisDirection.down);
        break;
      case "home":
        _lineEdge(false);
        break;
      case "end":
        _lineEdge(true);
        break;
      case "tab":
        if (!readOnly) _controller.replaceSelection("  ");
        break;
    }
  }

  // ------------------------------------------------------------------
  // Magnifier: shown while a touch is held (long press) inside the editor.
  // ------------------------------------------------------------------
  void _onPointerDown(PointerDownEvent e) {
    if (e.kind != PointerDeviceKind.touch) return;
    if (_pointer != null) return;
    _pointer = e.pointer;
    _down = e.localPosition;
    _lpTimer?.cancel();
    _lpTimer = Timer(const Duration(milliseconds: 420), () {
      if (!mounted || _down == null) return;
      _magnifierAt.value = _down;
    });
  }

  void _onPointerMove(PointerMoveEvent e) {
    if (e.pointer != _pointer || _down == null) return;
    if (_magnifierAt.value != null) {
      _magnifierAt.value = e.localPosition;
    } else if ((e.localPosition - _down!).distance > 14) {
      _lpTimer?.cancel(); // it is a scroll/drag, not a long press
      _down = null;
    }
  }

  void _onPointerEnd(PointerEvent e) {
    if (e.pointer != _pointer) return;
    _pointer = null;
    _down = null;
    _lpTimer?.cancel();
    _magnifierAt.value = null;
  }

  Widget _magnifierLayer(double size, double zoom) {
    return ValueListenableBuilder<Offset?>(
      valueListenable: _magnifierAt,
      builder: (context, p, _) {
        if (p == null) return const SizedBox.shrink();
        const gap = 28.0;
        return Positioned(
          left: p.dx - size / 2,
          top: p.dy - size - gap,
          child: IgnorePointer(
            child: RawMagnifier(
              size: Size(size, size),
              magnificationScale: zoom,
              focalPointOffset: Offset(0, size / 2 + gap),
              decoration: const MagnifierDecoration(
                shape: CircleBorder(
                  side: BorderSide(color: Colors.white70, width: 2),
                ),
                shadows: [
                  BoxShadow(blurRadius: 8, color: Colors.black38),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // ------------------------------------------------------------------
  // Scroll hand-off between the editor and the page around it.
  // ------------------------------------------------------------------
  ScrollPosition? _pageScroll() {
    if (!mounted) return null;
    final p = Scrollable.maybeOf(context)?.position;
    if (p == null || p.axis != Axis.vertical) return null;
    return p;
  }

  Widget _withScrollMode(Widget editor, String mode) {
    if (mode == "editor_only") return editor;

    if (mode == "page_first") {
      final base = ScrollConfiguration.of(context);
      return ScrollConfiguration(
        behavior: base.copyWith(physics: _PageFirstPhysics(_pageScroll)),
        child: editor,
      );
    }

    // "editor_first": when the editor hits its limit, the remaining drag
    // is passed on to the page.
    return NotificationListener<OverscrollNotification>(
      onNotification: (n) {
        if (n.metrics.axis != Axis.vertical || n.dragDetails == null) {
          return false;
        }
        final p = _pageScroll();
        if (p == null) return false;
        final target = (p.pixels + n.overscroll)
            .clamp(p.minScrollExtent, p.maxScrollExtent)
            .toDouble();
        if (target != p.pixels) p.jumpTo(target);
        return false;
      },
      child: editor,
    );
  }

  // ------------------------------------------------------------------
  Widget _buildToolbar({
    required List<String> items,
    required bool pad,
    required Color bg,
    required Color fg,
  }) {
    final buttons = <Widget>[];
    for (final id in items) {
      final icon = _toolbarIcons[id];
      if (icon == null) continue;
      final active = id == "select_mode" && _selectMode;
      buttons.add(InkResponse(
        onTap: () => _act(id),
        radius: 22,
        child: Container(
          width: 44,
          height: 44,
          alignment: Alignment.center,
          decoration: active
              ? BoxDecoration(
                  color: fg.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(8),
                )
              : null,
          child: Icon(icon, size: 22, color: fg),
        ),
      ));
    }
    return ExcludeFocus(
      child: Material(
        color: bg,
        child: SizedBox(
          height: 44,
          child: Row(
            children: [
              if (pad)
                _CursorPad(
                  color: fg,
                  onStep: _step,
                ),
              Expanded(
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: buttons,
                ),
              ),
            ],
          ),
        ),
      ),
    );
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

    // Engine / feature flags: re-created only when something changed.
    final enabled = control.getBool("syntax_highlighting", true)!;
    final showErrors = control.getBool("show_errors", true)!;
    final folding = control.getBool("code_folding", true)!;

    final String languageJson =
        widget.regexMode ? "" : control.getString("language", "")!;
    final dynamic rxRules = widget.regexMode ? control.get("rules") : null;
    final dynamic rxErrs = widget.regexMode ? control.get("error_rules") : null;
    final dynamic rxFolds = widget.regexMode ? control.get("folds") : null;
    final String? rxErrColor =
        widget.regexMode ? control.getString("error_color") : null;
    final bool rxWavy = control.getBool("wavy", true)!;
    final bool rxFoldIndent = control.getBool("fold_by_indent", false)!;

    final sig = widget.regexMode
        ? "$enabled|$showErrors|$folding|$rxRules|$rxErrs|$rxFolds|$rxErrColor|$rxWavy|$rxFoldIndent"
        : "$enabled|$showErrors|$folding|$languageJson";

    if (sig != _sig) {
      _sig = sig;
      List<FoldRuleSpec> folds = const [];
      var byIndent = false;
      CodeHighlighter? hl;

      if (widget.regexMode) {
        final spec = RegexSpec.fromValues(
          rules: rxRules,
          errorRules: rxErrs,
          folds: rxFolds,
          errorColor: rxErrColor,
          wavy: rxWavy,
          foldByIndent: rxFoldIndent,
        );
        hl = (enabled && spec.hasHighlighting)
            ? RegexHighlighter(spec, showErrors: showErrors)
            : null;
        folds = spec.folds;
        byIndent = spec.foldByIndent;
      } else {
        if (languageJson != _languageJson || _language == null) {
          _languageJson = languageJson;
          _language = _parseLanguage(languageJson);
        }
        final lang = _language;
        hl = (enabled && lang != null)
            ? LineHighlighter(lang, showErrors: showErrors)
            : null;
        folds = lang?.folds ?? const [];
        byIndent = lang?.foldByIndent ?? false;
      }

      _highlighter = hl;
      _highlighter?.onLinesChanged(_controller.codeLines);

      if (folding && (folds.isNotEmpty || byIndent)) {
        _chunkAnalyzer = FoldAnalyzer(folds, byIndent);
        _showFoldIndicator = true;
      } else {
        _chunkAnalyzer = NonCodeChunkAnalyzer();
        _showFoldIndicator = false;
      }
      _epoch++;
    }

    final fontFamily = control.getString("font_family", "Consolas")!;
    final fontSize = control.getDouble("font_size", 12.0)!;
    final textColor = parseHexColor(control.getString("default_color"));
    final bgColor = parseHexColor(control.getString("background_color"));
    final lineNumbers = control.getBool("line_numbers", true)!;
    final wrap = control.getBool("wrap", false)!;
    final readOnly = control.getBool("read_only", false)!;
    final showFold = _showFoldIndicator;

    // ---- mobile options (null = automatic by platform) ----
    final mobile = _isMobilePlatform;
    final showBar = control.getBool("mobile_controls") ?? mobile;
    final showPad = control.getBool("cursor_pad") ?? mobile;
    final showMag = control.getBool("magnifier") ?? mobile;
    final magSize = control.getDouble("magnifier_size", 110.0)!;
    final magZoom = control.getDouble("magnifier_zoom", 1.6)!;
    final barOnTop = control.getString("toolbar_position", "bottom") == "top";
    final itemsRaw = control.get("toolbar_items");
    final items = itemsRaw is List
        ? [for (final i in itemsRaw) i.toString()]
        : _defaultToolbar;
    final scrollMode = control.getString("scroll_mode", "page_first")!;
    final showMenu = mobile && control.getBool("selection_menu", true)!;

    Widget editor = CodeEditor(
      key: ValueKey("editor_$_epoch"),
      controller: _controller,
      readOnly: readOnly,
      wordWrap: wrap,
      padding: const EdgeInsets.all(4),
      onChanged: _handleChanged,
      toolbarController: showMenu ? _menuController : null,
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

    editor = _withScrollMode(editor, scrollMode);

    // Pointer tracking + magnifier overlay.
    Widget core = editor;
    if (showMag) {
      core = Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: Listener(
              behavior: HitTestBehavior.translucent,
              onPointerDown: _onPointerDown,
              onPointerMove: _onPointerMove,
              onPointerUp: _onPointerEnd,
              onPointerCancel: _onPointerEnd,
              child: editor,
            ),
          ),
          _magnifierLayer(magSize, magZoom),
        ],
      );
    }

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
      core = SizedBox(height: lines * lineH + 8 + 2, child: core);
    }

    // Toolbar (cut / copy / paste / cursor pad ...).
    Widget body = core;
    if (showBar) {
      final scheme = Theme.of(context).colorScheme;
      final bar = _buildToolbar(
        items: items,
        pad: showPad,
        bg: bgColor == null
            ? scheme.surfaceContainerHighest
            : Color.alphaBlend(Colors.white12, bgColor),
        fg: textColor ?? scheme.onSurface,
      );
      body = Column(
        mainAxisSize: heightFromLines ? MainAxisSize.min : MainAxisSize.max,
        children: [
          if (barOnTop) bar,
          heightFromLines ? core : Expanded(child: core),
          if (!barOnTop) bar,
        ],
      );
    }

    // Visible box size (levels 1..30).
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
      final inner = body;
      body = LayoutBuilder(builder: (ctx, c) {
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

    return LayoutControl(control: control, child: body);
  }
}

/// Draggable pad that moves the caret smoothly: horizontal drag = characters,
/// vertical drag = lines (like swiping on a space bar).
class _CursorPad extends StatefulWidget {
  final Color color;
  final void Function(AxisDirection) onStep;
  const _CursorPad({required this.color, required this.onStep});

  @override
  State<_CursorPad> createState() => _CursorPadState();
}

class _CursorPadState extends State<_CursorPad> {
  static const double _stepX = 9;
  static const double _stepY = 22;
  double _ax = 0;
  double _ay = 0;

  void _update(DragUpdateDetails d) {
    _ax += d.delta.dx;
    _ay += d.delta.dy;
    while (_ax.abs() >= _stepX) {
      widget.onStep(_ax > 0 ? AxisDirection.right : AxisDirection.left);
      _ax -= _ax > 0 ? _stepX : -_stepX;
    }
    while (_ay.abs() >= _stepY) {
      widget.onStep(_ay > 0 ? AxisDirection.down : AxisDirection.up);
      _ay -= _ay > 0 ? _stepY : -_stepY;
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onPanStart: (_) {
        _ax = 0;
        _ay = 0;
      },
      onPanUpdate: _update,
      child: Container(
        width: 84,
        height: 36,
        margin: const EdgeInsets.symmetric(horizontal: 6),
        decoration: BoxDecoration(
          color: widget.color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Icon(Icons.open_with, size: 20, color: widget.color),
      ),
    );
  }
}
