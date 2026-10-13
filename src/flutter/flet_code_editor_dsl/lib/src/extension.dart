import 'package:flet/flet.dart';
import 'package:flutter/widgets.dart';

import 'code_editor.dart';

class Extension extends FletExtension {
  @override
  Widget? createWidget(Key? key, Control control) {
    switch (control.type) {
      case "EditorRegex":
        return FletEditorControl(control: control, regexMode: true);
      case "EditorTokens":
        return FletEditorControl(control: control, regexMode: false);
      default:
        return null;
    }
  }
}
