# Local patch to re_editor 0.10.0

This directory contains the `lib/` source and `LICENSE` from upstream `re_editor` 0.10.0 (https://github.com/reqable/re-editor, Apache-2.0).

The vendored source has two narrowly scoped changes:

1. In `lib/src/_code_scroll.dart`, `_CodeScrollable` resolves its explicit physics from the nearest `ScrollConfiguration`, rather than hard-coding `ClampingScrollPhysics`. This allows the Flet extension to apply editor/page drag hand-off physics. The default Material configuration still supplies platform physics; `editor_first` transfers only overscroll at the editor's edge, while `page_first` is an opt-in alternative.
2. In `lib/src/code_scroll.dart`, `CodeScrollController.globalRectForPosition()` exposes the global caret rectangle computed from the actual laid-out text render object.
3. In `lib/src/code_scroll.dart`, `CodeScrollController.showPositionOnScreen()` passes the actual caret-line rectangle to Flutter's `RenderObject.showOnScreen`, allowing enclosing viewports to reveal the caret rather than the full editor box. The extension calls this after the editor's own viewport has made the caret visible.

Keep these patches small and re-check them against upstream before upgrading re_editor. The parent extension uses a relative path dependency so both changes travel with its wheel/zip and are not silently replaced by a cached pub.dev copy.
