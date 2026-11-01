part of re_editor;

typedef CodeScrollbarBuilder = Widget Function(
    BuildContext context, Widget child, ScrollableDetails details);

class CodeScrollController {
  final ScrollController verticalScroller;
  final ScrollController horizontalScroller;

  GlobalKey? _editorKey;

  CodeScrollController({
    ScrollController? verticalScroller,
    ScrollController? horizontalScroller,
  })  : verticalScroller = verticalScroller ?? ScrollController(),
        horizontalScroller = horizontalScroller ?? ScrollController();

  void makeCenterIfInvisible(CodeLinePosition position) {
    _render?.makePositionCenterIfInvisible(position);
  }

  void makeVisible(CodeLinePosition position) {
    _render?.makePositionVisible(position);
  }

  /// Requests that ancestor viewports reveal the actual laid-out caret.
  /// Mirrors Flutter EditableText's RenderEditable.showOnScreen path while
  /// keeping the target to the caret line instead of the whole editor box.
  bool showPositionOnScreen(
    CodeLinePosition position, {
    EdgeInsets padding = EdgeInsets.zero,
    Duration duration = Duration.zero,
    Curve curve = Curves.ease,
  }) {
    final render = _render;
    if (render == null) return false;
    final caret = render.calculateTextPositionViewportOffset(position);
    if (caret == null) return false;
    render.showOnScreen(
      rect: Rect.fromLTRB(
        caret.dx - padding.left,
        caret.dy - padding.top,
        caret.dx + 1 + padding.right,
        caret.dy + render._preferredLineHeight + padding.bottom,
      ),
      duration: duration,
      curve: curve,
    );
    return true;
  }

  /// Returns the caret's global rectangle using the laid-out text metrics.
  /// This is more accurate than estimating a line from the editor's font size,
  /// especially with variable line heights, padding, folds, or toolbars.
  Rect? globalRectForPosition(CodeLinePosition position) {
    final render = _render;
    if (render == null) return null;
    final top = render.calculateTextPositionScreenOffset(position, false);
    final bottom = render.calculateTextPositionScreenOffset(position, true);
    if (top == null || bottom == null) return null;
    return Rect.fromLTRB(
      top.dx,
      top.dy,
      top.dx + 1,
      bottom.dy > top.dy ? bottom.dy : top.dy + 1,
    );
  }

  void bindEditor(GlobalKey key) {
    _editorKey = key;
  }

  _CodeFieldRender? get _render =>
      _editorKey?.currentContext?.findRenderObject() as _CodeFieldRender?;

  void dispose() {
    _editorKey = null;
  }
}
