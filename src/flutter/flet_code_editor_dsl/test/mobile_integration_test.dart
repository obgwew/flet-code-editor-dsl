import 'package:flet/flet.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:re_editor/re_editor.dart';

import '../lib/src/code_editor.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FletBackend backend;
  late Control control;
  late ScrollController pageScroll;

  setUp(() {
    backend = FletBackend(
      pageUri: Uri.parse('http://localhost'),
      assetsDir: '',
      multiView: false,
      extensions: const [],
    );
    pageScroll = ScrollController();
  });

  tearDown(() {
    pageScroll.dispose();
    backend.dispose();
  });

  Control createControl({
    required String value,
    int id = 42,
    String scrollMode = 'editor_first',
    List<String> suggestions = const [],
    String trigger = '',
    String verticalMode = 'fixed',
    int? minLines,
    int? maxLines,
    double? height = 220.0,
    double horizontalScrollPadding = 0.0,
  }) {
    control = Control(
      id: id,
      type: 'EditorRegex',
      properties: {
        'value': value,
        'width': 360.0,
        if (height != null) 'height': height,
        'font_size': 16.0,
        'line_numbers': false,
        'width_level': 0,
        'height_level': 0,
        'vertical_mode': verticalMode,
        if (minLines != null) 'min_lines': minLines,
        if (maxLines != null) 'max_lines': maxLines,
        'horizontal_scroll_padding': horizontalScrollPadding,
        'mobile_controls': false,
        'cursor_pad': false,
        'magnifier': false,
        'selection_menu': false,
        'autocomplete': true,
        'autocomplete_words': suggestions,
        'autocomplete_trigger': trigger,
        'debounce_ms': 30000,
        'scroll_mode': scrollMode,
      },
      backend: backend,
    );
    return control;
  }

  Widget host(Widget editor, {required double before, required double after}) {
    return MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          controller: pageScroll,
          child: Column(
            children: [
              SizedBox(height: before),
              editor,
              SizedBox(height: after),
            ],
          ),
        ),
      ),
    );
  }

  testWidgets(
    'unlimited editor expands to its lines and the page scrolls through it',
    (tester) async {
      tester.view.physicalSize = const Size(400, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final code = List.generate(80, (i) => 'line_$i = value_$i').join('\n');
      final editor = FletEditorControl(
        control: createControl(
          value: code,
          height: null,
          verticalMode: 'unlimited',
          minLines: 1,
        ),
        regexMode: true,
      );
      await tester.pumpWidget(host(editor, before: 100, after: 300));
      await tester.pumpAndSettle();

      final editorFinder = find.byType(CodeEditor);
      expect(tester.getSize(editorFinder).height, greaterThan(1000));
      final vertical = tester
          .stateList<ScrollableState>(
            find.descendant(
              of: editorFinder,
              matching: find.byType(Scrollable),
            ),
          )
          .where((state) => state.position.axis == Axis.vertical)
          .first;
      expect(vertical.position.maxScrollExtent, closeTo(0, 0.5));

      await tester.dragFrom(const Offset(180, 150), const Offset(0, -160));
      await tester.pumpAndSettle();
      expect(pageScroll.offset, greaterThan(0));
      expect(vertical.position.pixels, closeTo(0, 0.5));
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );

  testWidgets(
    'horizontal scroll padding adds trailing blank space after the line',
    (tester) async {
      tester.view.physicalSize = const Size(400, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final code = List.filled(200, 'x').join();

      Future<double> maxHorizontalExtent(
        WidgetTester tester, {
        required int id,
        required double padding,
      }) async {
        final editor = FletEditorControl(
          control: createControl(
            id: id,
            value: code,
            height: null,
            verticalMode: 'unlimited',
            minLines: 1,
            horizontalScrollPadding: padding,
          ),
          regexMode: true,
        );
        await tester.pumpWidget(host(editor, before: 0, after: 300));
        await tester.pumpAndSettle();
        final editorFinder = find.byType(CodeEditor);
        final horizontal = tester
            .stateList<ScrollableState>(
              find.descendant(
                of: editorFinder,
                matching: find.byType(Scrollable),
              ),
            )
            .where((state) => state.position.axis == Axis.horizontal)
            .first;
        return horizontal.position.maxScrollExtent;
      }

      final withoutTail = await maxHorizontalExtent(
        tester,
        id: 42,
        padding: 0,
      );
      final withTail = await maxHorizontalExtent(
        tester,
        id: 43,
        padding: 48,
      );
      expect(withTail - withoutTail, closeTo(48, 1));
      final renderedEditor = tester.widget<CodeEditor>(find.byType(CodeEditor));
      expect(
        renderedEditor.padding!.resolve(TextDirection.ltr).right,
        closeTo(52, 0.1),
      );
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );

  testWidgets(
      'page_first moves the Flet page before the editor, then hands off at its edge',
      (tester) async {
    tester.view.physicalSize = const Size(400, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final code = List.generate(80, (i) => 'line_$i = value_$i').join('\n');
    final editor = FletEditorControl(
      control: createControl(value: code, scrollMode: 'page_first'),
      regexMode: true,
    );
    await tester.pumpWidget(host(editor, before: 420, after: 100));
    await tester.pumpAndSettle();

    final editorFinder = find.byType(CodeEditor);
    expect(editorFinder, findsOneWidget);
    await tester.drag(editorFinder, const Offset(0, -140));
    await tester.pumpAndSettle();
    expect(pageScroll.offset, greaterThan(0));

    pageScroll.jumpTo(pageScroll.position.maxScrollExtent);
    await tester.pumpAndSettle();
    final inner = tester
        .stateList<ScrollableState>(
          find.descendant(of: editorFinder, matching: find.byType(Scrollable)),
        )
        .where((state) => state.position.axis == Axis.vertical)
        .first;
    final beforeInner = inner.position.pixels;
    final pageAtEnd = pageScroll.offset;
    await tester.drag(editorFinder, const Offset(0, -120));
    await tester.pumpAndSettle();
    expect(pageScroll.offset, closeTo(pageAtEnd, 0.5));
    expect(inner.position.pixels, greaterThan(beforeInner));
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets(
    'default editor_first scrolls only the editor until its edge, then the page',
    (tester) async {
      tester.view.physicalSize = const Size(400, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final code = List.generate(80, (i) => 'line_$i = value_$i').join('\n');
      final editor = FletEditorControl(
        control: createControl(value: code),
        regexMode: true,
      );
      await tester.pumpWidget(host(editor, before: 100, after: 1200));
      await tester.pumpAndSettle();

      final editorFinder = find.byType(CodeEditor);
      final inner = tester
          .stateList<ScrollableState>(
            find.descendant(
                of: editorFinder, matching: find.byType(Scrollable)),
          )
          .where((state) => state.position.axis == Axis.vertical)
          .first;
      final pageAtStart = pageScroll.offset;
      await tester.drag(editorFinder, const Offset(0, -70));
      await tester.pumpAndSettle();
      expect(inner.position.pixels, greaterThan(0));
      expect(pageScroll.offset, closeTo(pageAtStart, 0.5));

      inner.position.jumpTo(inner.position.maxScrollExtent);
      await tester.pumpAndSettle();
      final editorAtEnd = inner.position.pixels;
      final pageBefore = pageScroll.offset;

      await tester.drag(editorFinder, const Offset(0, -140));
      await tester.pumpAndSettle();
      expect(pageScroll.offset, greaterThan(pageBefore));
      expect(inner.position.pixels, closeTo(editorAtEnd, 0.5));
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );

  testWidgets(
    'editor_first hands off one continuous drag only after reaching the edge',
    (tester) async {
      tester.view.physicalSize = const Size(400, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final code = List.generate(100, (i) => 'line_$i = value_$i').join('\n');
      final editor = FletEditorControl(
        control: createControl(value: code),
        regexMode: true,
      );
      await tester.pumpWidget(host(editor, before: 100, after: 1200));
      await tester.pumpAndSettle();

      final editorFinder = find.byType(CodeEditor);
      final inner = tester
          .stateList<ScrollableState>(
            find.descendant(
              of: editorFinder,
              matching: find.byType(Scrollable),
            ),
          )
          .where((state) => state.position.axis == Axis.vertical)
          .first;
      final gesture = await tester.startGesture(
        tester.getRect(editorFinder).center,
        kind: PointerDeviceKind.touch,
      );
      await tester.pump();

      var pageStarted = false;
      for (var i = 0; i < 60; i++) {
        await gesture.moveBy(
          const Offset(0, -40),
          timeStamp: Duration(milliseconds: 16 * (i + 1)),
        );
        await tester.pump(const Duration(milliseconds: 16));
        if (pageScroll.offset > 0.5) {
          expect(
            inner.position.pixels,
            closeTo(inner.position.maxScrollExtent, 0.5),
          );
          pageStarted = true;
          break;
        }
        expect(
          inner.position.pixels,
          lessThanOrEqualTo(inner.position.maxScrollExtent + 0.5),
        );
      }
      expect(pageStarted, isTrue);

      final editorAtEdge = inner.position.pixels;
      final pageBeforeNextDelta = pageScroll.offset;
      await gesture.moveBy(
        const Offset(0, -50),
        timeStamp: const Duration(milliseconds: 1000),
      );
      await tester.pump(const Duration(milliseconds: 16));
      expect(inner.position.pixels, closeTo(editorAtEdge, 0.5));
      expect(pageScroll.offset, greaterThan(pageBeforeNextDelta));
      await gesture.up(timeStamp: const Duration(milliseconds: 1016));
      await tester.pumpAndSettle();
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );

  testWidgets(
    'editor fling reaching its edge hands ballistic motion to the page once',
    (tester) async {
      tester.view.physicalSize = const Size(400, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final code = List.generate(100, (i) => 'line_$i = value_$i').join('\n');
      final editor = FletEditorControl(
        control: createControl(value: code),
        regexMode: true,
      );
      await tester.pumpWidget(host(editor, before: 100, after: 1200));
      await tester.pumpAndSettle();

      final editorFinder = find.byType(CodeEditor);
      final inner = tester
          .stateList<ScrollableState>(
            find.descendant(
              of: editorFinder,
              matching: find.byType(Scrollable),
            ),
          )
          .where((state) => state.position.axis == Axis.vertical)
          .first;
      inner.position.jumpTo(inner.position.maxScrollExtent - 30);
      await tester.pumpAndSettle();
      final gesture = await tester.startGesture(
        tester.getRect(editorFinder).center,
        kind: PointerDeviceKind.touch,
      );
      await gesture.moveBy(
        const Offset(0, -10),
        timeStamp: const Duration(milliseconds: 5),
      );
      await tester.pump(const Duration(milliseconds: 5));
      await gesture.moveBy(
        const Offset(0, -10),
        timeStamp: const Duration(milliseconds: 6),
      );
      await tester.pump(const Duration(milliseconds: 1));
      await gesture.up(timeStamp: const Duration(milliseconds: 7));
      await tester.pumpAndSettle();

      expect(pageScroll.offset, greaterThan(0));
      expect(
        inner.position.pixels,
        closeTo(inner.position.maxScrollExtent, 0.5),
      );
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );

  testWidgets(
      'mobile completion strip shows all matching commands above keyboard',
      (tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    tester.view.viewInsets = const FakeViewPadding(bottom: 280);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewInsets);

    final editor = FletEditorControl(
      control: createControl(
        value: r'$d',
        suggestions: const ['delete', 'discord', 'dinner'],
        trigger: r'$',
      ),
      regexMode: true,
    );
    await tester.pumpWidget(host(editor, before: 8, after: 500));
    await tester.pumpAndSettle();
    final editorFinder = find.byType(CodeEditor);
    final editorRect = tester.getRect(editorFinder);
    await tester.tapAt(Offset(editorRect.left + 80, editorRect.top + 14));
    await tester.pumpAndSettle();
    expect(tester.testTextInput.isRegistered, isTrue);

    expect(find.text(r'$delete'), findsOneWidget);
    expect(find.text(r'$discord'), findsOneWidget);
    expect(find.text(r'$dinner'), findsOneWidget);
    final suggestion = tester.getRect(find.text(r'$delete'));
    final keyboardTop = tester.view.physicalSize.height - 280;
    expect(suggestion.bottom, lessThanOrEqualTo(keyboardTop));
    expect(suggestion.bottom, greaterThan(keyboardTop - 48));
    final barFinder = find
        .ancestor(of: find.text(r'$delete'), matching: find.byType(Material))
        .first;
    final bar = tester.getRect(barFinder);
    expect(bar.left, closeTo(0, 0.5));
    expect(bar.width, closeTo(400, 0.5));
    expect(tester.widget<Material>(barFinder).borderRadius, BorderRadius.zero);

    await tester.tap(find.text(r'$discord'));
    await tester.pumpAndSettle();
    final codeEditor = tester.widget<CodeEditor>(editorFinder);
    expect(codeEditor.controller!.text, r'$discord');
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets(
    'keyboard reveal does not move a safe caret just to expose the whole editor',
    (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1;
      tester.view.viewInsets = const FakeViewPadding(bottom: 280);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetViewInsets);

      final editor = FletEditorControl(
        control: createControl(value: 'first line\nsecond line'),
        regexMode: true,
      );
      await tester.pumpWidget(host(editor, before: 350, after: 1000));
      await tester.pumpAndSettle();
      final editorFinder = find.byType(CodeEditor);
      final editorRect = tester.getRect(editorFinder);
      await tester.tapAt(Offset(editorRect.left + 40, editorRect.top + 14));
      await tester.pumpAndSettle();

      // The editor extends behind the keyboard, but the active first line is
      // already visible, so the page should not jump to align the whole box.
      expect(pageScroll.offset, closeTo(0, 0.5));
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );

  testWidgets(
    'keyboard reveal scrolls only the small amount needed for an obscured caret',
    (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1;
      tester.view.viewInsets = const FakeViewPadding(bottom: 280);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetViewInsets);

      final editor = FletEditorControl(
        control: createControl(value: 'first line\nsecond line'),
        regexMode: true,
      );
      await tester.pumpWidget(host(editor, before: 505, after: 1000));
      await tester.pumpAndSettle();
      final editorRect = tester.getRect(find.byType(CodeEditor));
      await tester.tapAt(Offset(editorRect.left + 40, editorRect.top + 14));
      await tester.pumpAndSettle();

      expect(pageScroll.offset, greaterThan(0));
      expect(pageScroll.offset, lessThan(100));
      final activeEditor = tester.widget<CodeEditor>(find.byType(CodeEditor));
      final selection = activeEditor.controller!.selection;
      final line =
          activeEditor.controller!.codeLines[selection.extentIndex].text;
      final caretRect = activeEditor.scrollController!.globalRectForPosition(
        CodeLinePosition(
          index: selection.extentIndex,
          offset: selection.extentOffset.clamp(0, line.length).toInt(),
        ),
      );
      final keyboardTop = tester.view.physicalSize.height - 280;
      expect(caretRect, isNotNull);
      expect(caretRect!.bottom, lessThanOrEqualTo(keyboardTop - 7));

      // Reset the page to put the caret under the keyboard again, then verify
      // that the RenderObject.showOnScreen request alone reveals that caret.
      pageScroll.jumpTo(0);
      await tester.pumpAndSettle();
      expect(
        activeEditor.scrollController!.showPositionOnScreen(
          CodeLinePosition(
            index: selection.extentIndex,
            offset: selection.extentOffset.clamp(0, line.length).toInt(),
          ),
          padding: const EdgeInsets.only(top: 8, bottom: 8),
        ),
        isTrue,
      );
      await tester.pumpAndSettle();
      expect(pageScroll.offset, greaterThan(0));
      final visibleCaretRect =
          activeEditor.scrollController!.globalRectForPosition(
        CodeLinePosition(
          index: selection.extentIndex,
          offset: selection.extentOffset.clamp(0, line.length).toInt(),
        ),
      );
      expect(visibleCaretRect, isNotNull);
      expect(visibleCaretRect!.bottom, lessThanOrEqualTo(keyboardTop - 7));
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );
}
