# Build & test

Layout (keep it exactly like this):

    flet_code_editor_dsl_v0.3/
      pyproject.toml          <- library (new)
      MANIFEST.in             <- library (new)
      src/flet_code_editor_dsl/...   (Python)
      src/flutter/flet_code_editor_dsl/...   (Flutter extension)
      example/                <- test app (its pyproject points to ".." )

Steps (run inside `example/`):

    pip install -U "flet[all]>=0.85.2"
    flet build apk -v        # Android  -> build/apk/
    # quick desktop test (faster than APK):
    flet build windows -v    # -> build/windows/

Install the APK on the phone, or run the .exe on Windows.

Why `flet run` shows "Unknown control: EditorRegex":
the stock Flet client has no custom controls. They exist only in an app
built with `flet build`, because the build copies `src/flutter/...` into the
Flutter project.

If the build log never mentions `flet_code_editor_dsl` as a Flutter
dependency, the library was not picked up: check that
`example/pyproject.toml` contains
    [tool.uv.sources]
    flet-code-editor-dsl = { path = "..", editable = true }
