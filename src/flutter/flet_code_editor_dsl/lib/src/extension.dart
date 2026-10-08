import 'package:flet/flet.dart';
import 'package:flutter/widgets.dart';

import 'code_editor.dart';
import 'flet_code_editor_dsl.dart';

class Extension extends FletExtension {
  @override
  Widget? createWidget(Key? key, Control control) {
    switch (control.type) {
      case "FletCodeField":
        return FletCodeFieldControl(control: control);
      case "FletCodeEditor":
        return FletCodeEditorControl(control: control);
      default:
        return null;
    }
  }
}
