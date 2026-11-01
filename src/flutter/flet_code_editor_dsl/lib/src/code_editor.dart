import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, TargetPlatform;
import 'package:flutter/gestures.dart'
    show
        Drag,
        DragEndDetails,
        DragStartDetails,
        DragUpdateDetails,
        PointerCancelEvent,
        PointerDownEvent,
        PointerEvent,
        PointerMoveEvent,
        PointerDeviceKind,
        VelocityTracker;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:flet/flet.dart';
import 'package:re_editor/re_editor.dart';

import 'completion.dart';
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

/// Drives a real Flutter drag on the ancestor page while the nested editor
/// wins the gesture arena. This keeps the page's activity and release velocity
/// on the normal ScrollPosition path instead of mutating pixels directly.
class _ScrollHandoffCoordinator {
  final ScrollPosition? Function() page;
  Drag? _pageDrag;
  int? _pointer;
  Offset _globalPosition = Offset.zero;
  Duration? _lastTimeStamp;
  VelocityTracker? _velocityTracker;
  bool _ballisticHandoffStarted = false;

  _ScrollHandoffCoordinator(this.page);

  void onPointerDown(PointerDownEvent event) {
    if (_pointer != null) return;
    _pointer = event.pointer;
    _globalPosition = event.position;
    _lastTimeStamp = event.timeStamp;
    _velocityTracker = VelocityTracker.withKind(event.kind)
      ..addPosition(event.timeStamp, event.position);
    _ballisticHandoffStarted = false;
  }

  void onPointerMove(PointerMoveEvent event) {
    if (event.pointer != _pointer) return;
    _globalPosition = event.position;
    _lastTimeStamp = event.timeStamp;
    _velocityTracker?.addPosition(event.timeStamp, event.position);
  }

  void onPointerUp(PointerEvent event) {
    if (event.pointer != _pointer) return;
    _globalPosition = event.position;
    _lastTimeStamp = event.timeStamp;
    _velocityTracker?.addPosition(event.timeStamp, event.position);
    final velocity = _velocityTracker?.getVelocity() ?? Velocity.zero;
    final drag = _pageDrag;
    _pageDrag = null;
    _pointer = null;
    _velocityTracker = null;
    if (event is PointerCancelEvent) {
      _ballisticHandoffStarted = true;
      drag?.cancel();
    } else {
      // If the page was already receiving overscroll, it owns the release
      // velocity. Do not hand the same fling off a second time later.
      if (drag != null) _ballisticHandoffStarted = true;
      drag?.end(
        DragEndDetails(
          velocity: velocity,
          primaryVelocity: velocity.pixelsPerSecond.dy,
          globalPosition: _globalPosition,
        ),
      );
    }
  }

  double consume(ScrollMetrics child, double offset) {
    // Only forward overscroll caused by the live pointer gesture here. A fling
    // is transferred separately from its ballistic velocity notification.
    if (_pointer == null) return 0;
    final p = page();
    if (p == null || child.axis != Axis.vertical || offset == 0) return 0;
    final target = (p.pixels - offset)
        .clamp(p.minScrollExtent, p.maxScrollExtent)
        .toDouble();
    final consumed = p.pixels - target;
    if (consumed.abs() <= 0.5) return 0;

    if (p is ScrollPositionWithSingleContext) {
      _pageDrag ??= p.drag(
        DragStartDetails(globalPosition: _globalPosition),
        () => _pageDrag = null,
      );
      _pageDrag?.update(
        DragUpdateDetails(
          globalPosition: _globalPosition,
          delta: Offset(0, consumed),
          primaryDelta: consumed,
          sourceTimeStamp: _lastTimeStamp,
        ),
      );
    } else {
      // Flet's SingleChildScrollView uses ScrollPositionWithSingleContext.
      // Keep custom host ScrollPosition implementations functional as well.
      p.jumpTo(target);
    }
    return consumed;
  }

  void onChildScrollUpdate(ScrollMetrics child) {
    if (_pointer == null || _pageDrag == null || child.axis != Axis.vertical) {
      return;
    }
    const tolerance = 0.5;
    final insideRange = child.pixels > child.minScrollExtent + tolerance &&
        child.pixels < child.maxScrollExtent - tolerance;
    if (insideRange) {
      final drag = _pageDrag;
      _pageDrag = null;
      drag?.cancel();
    }
  }

  void onChildOverscroll(OverscrollNotification notification) {
    if (notification.metrics.axis != Axis.vertical) return;
    if (_pointer != null && notification.dragDetails != null) {
      consume(notification.metrics, -notification.overscroll);
      return;
    }

    // If a finger fling reaches the editor edge after pointer-up, forward its
    // remaining ballistic velocity once. Never start a new page Drag from a
    // late OverscrollNotification: Flutter dispatches that after layout.
    if (_pointer != null ||
        _ballisticHandoffStarted ||
        notification.velocity.abs() < 1) {
      return;
    }
    final p = page();
    if (p == null || p.axis != Axis.vertical) return;
    final canMove = notification.velocity > 0
        ? p.pixels < p.maxScrollExtent
        : p.pixels > p.minScrollExtent;
    if (!canMove) return;
    _ballisticHandoffStarted = true;
    final pointerVelocity = -notification.velocity;
    final drag = p.drag(
      DragStartDetails(globalPosition: _globalPosition),
      () => _pageDrag = null,
    );
    drag.end(
      DragEndDetails(
        velocity: Velocity(
          pixelsPerSecond: Offset(0, pointerVelocity),
        ),
        primaryVelocity: pointerVelocity,
        globalPosition: _globalPosition,
      ),
    );
  }

  void dispose() {
    final drag = _pageDrag;
    _pageDrag = null;
    _pointer = null;
    _velocityTracker = null;
    _ballisticHandoffStarted = true;
    drag?.cancel();
  }
}

/// "page_first": the page (nearest vertical Scrollable above the editor)
/// consumes a vertical drag until it reaches its limit in that direction;
/// only then does the editor scroll.
class _PageFirstPhysics extends ClampingScrollPhysics {
  final _ScrollHandoffCoordinator coordinator;
  const _PageFirstPhysics(this.coordinator, {super.parent});

  @override
  _PageFirstPhysics applyTo(ScrollPhysics? ancestor) =>
      _PageFirstPhysics(coordinator, parent: buildParent(ancestor));

  @override
  double applyPhysicsToUserOffset(ScrollMetrics position, double offset) {
    if (position.axis == Axis.vertical && offset != 0) {
      final consumed = coordinator.consume(position, offset);
      if (consumed.abs() > 0.5) return offset - consumed;
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
  "undo",
  "redo",
  "cut",
  "copy",
  "paste",
  "select_all",
  "select_mode",
  "left",
  "right",
  "up",
  "down",
  "home",
  "end",
  "tab",
];

const List<String> _defaultSelectionMenu = [
  "cut",
  "copy",
  "paste",
  "select_all",
];

class _FletEditorControlState extends State<FletEditorControl>
    with WidgetsBindingObserver {
  late final CodeLineEditingController _controller;
  late final FocusNode _editorFocusNode;
  late final ScrollController _editorVerticalScrollController;
  late final ScrollController _editorHorizontalScrollController;
  late final CodeScrollController _editorScrollController;
  late final _ScrollHandoffCoordinator _scrollHandoff =
      _ScrollHandoffCoordinator(_pageScroll);
  Timer? _debounce;
  OverlayEntry? _completionOverlay;
  double _keyboardInset = 0.0;
  bool _keyboardRevealScheduled = false;

  String _propValue = "";
  String _lastSent = "";
  final Map<String, int> _recentSuggestions = <String, int>{};

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
      items.add(
        ContextMenuButtonItem(
          label: label,
          onPressed: () {
            run();
            onDismiss();
          },
        ),
      );
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

  double _keyboardInsetForView(BuildContext context) {
    final view = View.of(context);
    final ratio = view.devicePixelRatio;
    return ratio > 0 ? view.viewInsets.bottom / ratio : 0.0;
  }

  Size _logicalViewSize(BuildContext context) {
    final view = View.of(context);
    final ratio = view.devicePixelRatio;
    return ratio > 0 ? view.physicalSize / ratio : Size.zero;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _editorFocusNode = FocusNode()..addListener(_onEditorFocusChanged);
    _editorVerticalScrollController = ScrollController();
    _editorHorizontalScrollController = ScrollController();
    _editorScrollController = CodeScrollController(
      verticalScroller: _editorVerticalScrollController,
      horizontalScroller: _editorHorizontalScrollController,
    );
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
    WidgetsBinding.instance.removeObserver(this);
    _debounce?.cancel();
    _removeCompletionOverlay();
    _scrollHandoff.dispose();
    _lpTimer?.cancel();
    try {
      _menuController.hide(context);
    } catch (_) {
      // The overlay may already be detached while the control is disposing.
    }
    _magnifierAt.dispose();
    _editorFocusNode.removeListener(_onEditorFocusChanged);
    _editorFocusNode.dispose();
    _editorScrollController.dispose();
    _editorVerticalScrollController.dispose();
    _editorHorizontalScrollController.dispose();
    _controller.removeListener(_onControllerChanged);
    _controller.dispose();
    super.dispose();
  }

  @override
  void didChangeMetrics() {
    if (_isMobilePlatform && _editorFocusNode.hasFocus) {
      _scheduleKeyboardReveal();
    }
    _scheduleCompletionOverlaySync();
  }

  void _onEditorFocusChanged() {
    if (_isMobilePlatform && _editorFocusNode.hasFocus) {
      _scheduleKeyboardReveal();
    }
    _scheduleCompletionOverlaySync();
  }

  void _removeCompletionOverlay() {
    final entry = _completionOverlay;
    _completionOverlay = null;
    if (entry != null) {
      entry.remove();
      entry.dispose();
    }
  }

  void _scheduleCompletionOverlaySync() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // Focus and window-metrics changes do not always rebuild a Flet control.
      // Refresh the root-view inset here before deciding whether to show the
      // overlay, rather than relying only on the last build's cached value.
      _keyboardInset = _isMobilePlatform && _editorFocusNode.hasFocus
          ? _keyboardInsetForView(context)
          : 0.0;
      final candidates = _completionCandidates();
      if (!_isMobilePlatform ||
          !_editorFocusNode.hasFocus ||
          _keyboardInset <= 0 ||
          candidates.isEmpty) {
        _removeCompletionOverlay();
        return;
      }
      if (_completionOverlay != null) {
        _completionOverlay!.markNeedsBuild();
        return;
      }
      final overlay = Overlay.maybeOf(context, rootOverlay: true);
      if (overlay == null) return;
      final entry = OverlayEntry(
        builder: (overlayContext) {
          final words = _completionCandidates();
          if (words.isEmpty) return const SizedBox.shrink();
          final theme = Theme.of(overlayContext);
          return Positioned(
            left: 0,
            right: 0,
            bottom: _keyboardInset,
            child: SafeArea(
              left: false,
              right: false,
              top: false,
              bottom: false,
              child: CodeEditorTapRegion(
                child: Material(
                  elevation: 8,
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.zero,
                  clipBehavior: Clip.antiAlias,
                  child: SizedBox(
                    height: 48,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      itemCount: words.length,
                      separatorBuilder: (context, index) => Container(
                        width: 1,
                        margin: const EdgeInsets.symmetric(vertical: 14),
                        color: theme.colorScheme.outlineVariant,
                      ),
                      itemBuilder: (context, index) {
                        final word = words[index];
                        return InkWell(
                          key: ValueKey('completion-$word'),
                          onTap: () => _acceptCompletion(word),
                          child: Container(
                            constraints: const BoxConstraints(minWidth: 72),
                            alignment: Alignment.center,
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Text(
                              word,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurface,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      );
      _completionOverlay = entry;
      overlay.insert(entry);
    });
  }

  void _scheduleKeyboardReveal() {
    if (_keyboardRevealScheduled) return;
    _keyboardRevealScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _keyboardRevealScheduled = false;
      if (!mounted || !_editorFocusNode.hasFocus) return;
      final inset = _keyboardInsetForView(context);
      if (inset <= 0) return;
      _keyboardInset = inset;
      _makeCaretVisibleInternally();
      // re_editor first reveals the caret inside its own viewport. On the next
      // frame, ask every ancestor viewport to reveal that caret rectangle, as
      // Flutter EditableText does for its RenderEditable.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final selection = _controller.selection;
        if (selection.extentIndex >= 0 &&
            selection.extentIndex < _controller.codeLines.length) {
          final line = _controller.codeLines[selection.extentIndex].text;
          final offset = selection.extentOffset.clamp(0, line.length).toInt();
          _editorScrollController.showPositionOnScreen(
            CodeLinePosition(index: selection.extentIndex, offset: offset),
            padding: const EdgeInsets.only(top: 8, bottom: 8),
          );
        }
        // Keep a geometry-based fallback for hosts whose outer viewport is
        // not configured to respond to RenderObject.showOnScreen.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _adjustPageForKeyboard();
        });
        WidgetsBinding.instance.scheduleFrame();
      });
      WidgetsBinding.instance.scheduleFrame();
    });
  }

  void _makeCaretVisibleInternally() {
    final selection = _controller.selection;
    if (selection.extentIndex < 0 ||
        selection.extentIndex >= _controller.codeLines.length) {
      return;
    }
    final line = _controller.codeLines[selection.extentIndex].text;
    final offset = selection.extentOffset.clamp(0, line.length).toInt();
    _editorScrollController.makeVisible(
      CodeLinePosition(index: selection.extentIndex, offset: offset),
    );
  }

  void _adjustPageForKeyboard() {
    if (!mounted || !_editorFocusNode.hasFocus) return;
    final keyboardInset = _keyboardInsetForView(context);
    if (keyboardInset <= 0) return;

    final page = _pageScroll();
    if (page == null || !page.hasContentDimensions) return;
    final keyboardTop = _logicalViewSize(context).height - keyboardInset;
    final selection = _controller.selection;
    if (selection.extentIndex < 0 ||
        selection.extentIndex >= _controller.codeLines.length) {
      return;
    }
    final line = _controller.codeLines[selection.extentIndex].text;
    final offset = selection.extentOffset.clamp(0, line.length).toInt();
    final caretRect = _editorScrollController.globalRectForPosition(
      CodeLinePosition(index: selection.extentIndex, offset: offset),
    );
    if (caretRect == null) return;

    // Keep a small comfortable gap above the keyboard, but otherwise leave
    // the editor/page exactly where they are. This avoids aligning the whole
    // editor box when only a single caret line needs to be revealed.
    const caretGap = 8.0;
    final overlap = caretRect.bottom - (keyboardTop - caretGap);
    if (overlap <= 0) return;

    final target = (page.pixels + overlap)
        .clamp(page.minScrollExtent, page.maxScrollExtent)
        .toDouble();
    if ((target - page.pixels).abs() < 0.5) return;
    page
        .animateTo(
      target,
      duration: const Duration(milliseconds: 100),
      curve: Curves.easeOutCubic,
    )
        .then((_) {
      if (mounted && _editorFocusNode.hasFocus) {
        _makeCaretVisibleInternally();
      }
    });
  }

  TextSpan _spanBuilder({
    required CodeLine codeLine,
    required BuildContext context,
    required int index,
    required TextStyle style,
    required TextSpan textSpan,
  }) {
    // Non-active lines keep their cached colors. The highlighters reuse cached
    // spans for unchanged lines and only re-lex edited lines (except multiline
    // token state, which can invalidate downstream lines).
    final h = _highlighter;
    if (h == null) return textSpan;
    return h.build(_controller.codeLines, index, codeLine, style, textSpan);
  }

  void _onControllerChanged() {
    if (!mounted) return;
    final linesChanged = _controller.preValue != null &&
        _controller.preValue!.codeLines != _controller.codeLines;
    if (linesChanged) {
      final currentLineOnly =
          widget.control.getString("highlight_scope", "document") ==
              "current_line";
      _highlighter?.onLinesChanged(
        _controller.codeLines,
        currentLineOnly: currentLineOnly,
      );
    }
    // re_editor reveals the caret only inside its own viewport. Re-evaluate the
    // containing Flet page when the cursor or source line changes while the
    // software keyboard is already open.
    if (_isMobilePlatform && _editorFocusNode.hasFocus && _keyboardInset > 0) {
      _scheduleKeyboardReveal();
    }
    final mode = widget.control.getString("vertical_mode", "fixed")!;
    if (mode == "fixed") return;
    final n = _controller.codeLines.length;
    if (n != _lineCount) setState(() => _lineCount = n);
  }

  void _handleChanged(CodeLineEditingValue value) {
    final text = _controller.text;
    if (widget.control.getBool("autocomplete", true)!) {
      final sel = _controller.selection;
      if (sel.isCollapsed &&
          sel.extentIndex >= 0 &&
          sel.extentIndex < _controller.codeLines.length) {
        final line = _controller.codeLines[sel.extentIndex].text;
        final offset = sel.extentOffset.clamp(0, line.length).toInt();
        if (offset > 0 &&
            (line[offset - 1] == ' ' || line[offset - 1] == '\t')) {
          final left = line.substring(0, offset - 1).trimRight();
          final word =
              RegExp(r'[A-Za-z_][A-Za-z0-9_]*$').firstMatch(left)?.group(0);
          if (word != null &&
              widget.control.getBool("remember_suggestions", true)!) {
            _recentSuggestions[word] = (_recentSuggestions[word] ?? 0) + 1;
          }
        }
      }
      if (mounted) setState(() {});
    }
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

  String _completionPrefix() {
    final s = _controller.selection;
    if (!s.isCollapsed ||
        s.extentIndex < 0 ||
        s.extentIndex >= _controller.codeLines.length) return "";
    final line = _controller.codeLines[s.extentIndex].text;
    final end = s.extentOffset.clamp(0, line.length).toInt();
    return completionPrefixAt(line, end);
  }

  bool _completionHasTrigger(String trigger) {
    if (trigger.isEmpty) return false;
    final selection = _controller.selection;
    if (!selection.isCollapsed ||
        selection.extentIndex < 0 ||
        selection.extentIndex >= _controller.codeLines.length) {
      return false;
    }
    final prefix = _completionPrefix();
    final line = _controller.codeLines[selection.extentIndex].text;
    final end = selection.extentOffset.clamp(0, line.length).toInt();
    return completionHasTriggerAt(
      line: line,
      offset: end,
      prefix: prefix,
      trigger: trigger,
    );
  }

  List<String> _completionCandidates() {
    if (!widget.control.getBool("autocomplete", true)!) return const [];
    final prefix = _completionPrefix();
    final trigger = widget.control.getString("autocomplete_trigger", "")!;
    final hasTrigger = trigger.isNotEmpty && _completionHasTrigger(trigger);
    if (prefix.isEmpty || (trigger.isNotEmpty && !hasTrigger)) return const [];
    final raw = widget.control.get("autocomplete_words");
    final words = raw is List ? raw.map((w) => w.toString()) : const <String>[];
    return completionCandidates(
      prefix: prefix,
      words: words,
      trigger: hasTrigger ? trigger : "",
      recent: _recentSuggestions,
    );
  }

  void _acceptCompletion(String word) {
    final selection = _controller.selection;
    final index = selection.extentIndex;
    if (!selection.isCollapsed ||
        index < 0 ||
        index >= _controller.codeLines.length) {
      return;
    }
    final line = _controller.codeLines[index].text;
    final end = selection.extentOffset.clamp(0, line.length).toInt();
    final prefix = completionPrefixAt(line, end);
    if (prefix.isEmpty) return;

    final trigger = widget.control.getString("autocomplete_trigger", "")!;
    final hasTrigger = completionHasTriggerAt(
      line: line,
      offset: end,
      prefix: prefix,
      trigger: trigger,
    );
    final insertion = completionInsertion(
      suggestion: word,
      trigger: trigger,
      hasTrigger: hasTrigger,
    );
    final start = end - prefix.length;

    // Pass the exact range into re_editor in one operation. Updating the
    // selection first can race the platform text input connection when the
    // suggestion overlay is tapped, leaving the replacement unapplied.
    _controller.replaceSelection(
      insertion,
      CodeLineSelection(
        baseIndex: index,
        baseOffset: start,
        extentIndex: index,
        extentOffset: end,
      ),
    );
    _recentSuggestions[insertion] = (_recentSuggestions[insertion] ?? 0) + 1;
    _editorFocusNode.requestFocus();
    _scheduleCompletionOverlaySync();
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

  double _measureLineHeight(double size) {
    if (_lineHeightFor == size) {
      return _lineHeight;
    }
    _lineHeightFor = size;
    // re_editor's default CodeEditorStyle.fontHeight is 1.4 and its paragraph
    // provider forces that strut height. Measuring a sample glyph instead
    // yields a shorter value and leaves an internal scroll range.
    _lineHeight = size * 1.4;
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
                shadows: [BoxShadow(blurRadius: 8, color: Colors.black38)],
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
      return Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: _scrollHandoff.onPointerDown,
        onPointerMove: _scrollHandoff.onPointerMove,
        onPointerUp: _scrollHandoff.onPointerUp,
        onPointerCancel: _scrollHandoff.onPointerUp,
        child: ScrollConfiguration(
          behavior: base.copyWith(physics: _PageFirstPhysics(_scrollHandoff)),
          child: editor,
        ),
      );
    }

    // "editor_first": when the editor hits its limit, the remaining drag
    // is passed on to the page.
    return NotificationListener<ScrollNotification>(
      onNotification: (n) {
        if (n is ScrollUpdateNotification) {
          _scrollHandoff.onChildScrollUpdate(n.metrics);
        } else if (n is OverscrollNotification) {
          _scrollHandoff.onChildOverscroll(n);
        }
        return false;
      },
      child: Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: _scrollHandoff.onPointerDown,
        onPointerMove: _scrollHandoff.onPointerMove,
        onPointerUp: _scrollHandoff.onPointerUp,
        onPointerCancel: _scrollHandoff.onPointerUp,
        child: editor,
      ),
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
      buttons.add(
        InkResponse(
          onTap: () => _act(id),
          radius: 22,
          child: Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: active
                ? BoxDecoration(
                    color: fg.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(8),
                  )
                : null,
            child: Icon(icon, size: 22, color: fg),
          ),
        ),
      );
    }
    return ExcludeFocus(
      child: Material(
        color: bg,
        child: SizedBox(
          height: 44,
          child: Row(
            children: [
              if (pad) _CursorPad(color: fg, onStep: _step),
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
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted || widget.control.getString("value", "") != value)
            return;
          if (_controller.text == value) return;
          _lastSent = value;
          _controller.text = value;
        });
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
    final fontSize = control.getDouble("font_size", 16.0)!;
    final textColor = parseHexColor(control.getString("default_color"));
    final bgColor = parseHexColor(control.getString("background_color"));
    final lineNumbers = control.getBool("line_numbers", true)!;
    final wrap = control.getBool("wrap", false)!;
    final readOnly = control.getBool("read_only", false)!;
    final showFold = _showFoldIndicator;
    final requestedTailPadding =
        control.getDouble("horizontal_scroll_padding", 0.0)!;
    final tailPadding = requestedTailPadding.isFinite
        ? math.max(0.0, requestedTailPadding).toDouble()
        : 0.0;

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
    final scrollMode = control.getString("scroll_mode", "editor_first")!;
    final showMenu = mobile && control.getBool("selection_menu", true)!;

    Widget editor = CodeEditor(
      key: ValueKey("editor_$_epoch"),
      controller: _controller,
      focusNode: _editorFocusNode,
      autofocus: false,
      scrollController: _editorScrollController,
      readOnly: readOnly,
      wordWrap: wrap,
      padding: EdgeInsets.fromLTRB(4, 4, 4 + tailPadding, 4),
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
      } else if (vMode == "unlimited") {
        final minL = control.getInt("min_lines") ?? 1;
        if (minL > lines) lines = minL;
      }
      final lineH = _measureLineHeight(fontSize);
      core = SizedBox(height: lines * lineH + 8 + 2, child: core);
    }

    // Desktop keeps its compact inline completion row. On mobile the same
    // candidates are rendered in a root overlay above the software keyboard.
    final completions = _completionCandidates();
    if (!_isMobilePlatform && completions.isNotEmpty) {
      final scheme = Theme.of(context).colorScheme;
      final suggestions = Material(
        color: scheme.surfaceContainerHighest,
        child: SizedBox(
          height: 40,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              for (final word in completions)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 2,
                    vertical: 3,
                  ),
                  child: ActionChip(
                    label: Text(word),
                    onPressed: () => _acceptCompletion(word),
                  ),
                ),
            ],
          ),
        ),
      );
      core = heightFromLines
          ? Column(
              mainAxisSize: MainAxisSize.min,
              children: [suggestions, core],
            )
          : Column(
              children: [
                suggestions,
                Expanded(child: core),
              ],
            );
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
    final widthLevel = control.getInt("width_level", 17)!;
    final heightLevel = control.getInt("height_level", 17)!;
    final wl = (explicitW || expanded || widthLevel <= 0) ? null : widthLevel;
    final hl = (explicitH || expanded || heightFromLines || heightLevel <= 0)
        ? null
        : heightLevel;

    if (wl != null || hl != null) {
      final inner = body;
      body = LayoutBuilder(
        builder: (ctx, c) {
          final screen = MediaQuery.sizeOf(ctx);
          final aw = c.maxWidth.isFinite ? c.maxWidth : screen.width;
          final ah = c.maxHeight.isFinite ? c.maxHeight : screen.height;
          return SizedBox(
            width: wl == null ? null : _levelSize(wl, aw),
            height: hl == null ? null : _levelSize(hl, ah),
            child: inner,
          );
        },
      );
    }

    final keyboardInset = _isMobilePlatform && _editorFocusNode.hasFocus
        ? _keyboardInsetForView(context)
        : 0.0;
    _keyboardInset = keyboardInset;
    _scheduleCompletionOverlaySync();
    return LayoutControl(
      control: control,
      child: body,
    );
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
          color: widget.color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Icon(Icons.open_with, size: 20, color: widget.color),
      ),
    );
  }
}
