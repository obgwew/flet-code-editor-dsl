import unittest

from flet_code_editor_dsl import EditorRegex, EditorTokens, ScrollMode


class FontDefaultTests(unittest.TestCase):
    def test_both_editors_default_to_sixteen(self):
        self.assertEqual(EditorRegex().font_size, 16.0)
        self.assertEqual(EditorTokens().font_size, 16.0)

    def test_application_can_override_default_font_size(self):
        self.assertEqual(EditorRegex(font_size=18).font_size, 18)
        self.assertEqual(EditorTokens(font_size=18).font_size, 18)

    def test_editor_first_is_the_default_scroll_mode(self):
        self.assertEqual(EditorRegex().scroll_mode, ScrollMode.EDITOR_FIRST)
        self.assertEqual(EditorTokens().scroll_mode, ScrollMode.EDITOR_FIRST)

    def test_horizontal_scroll_padding_is_optional_and_configurable(self):
        self.assertEqual(EditorRegex().horizontal_scroll_padding, 0.0)
        self.assertEqual(EditorTokens().horizontal_scroll_padding, 0.0)
        self.assertEqual(
            EditorRegex(horizontal_scroll_padding=48).horizontal_scroll_padding,
            48,
        )
        self.assertEqual(
            EditorTokens(horizontal_scroll_padding=60).horizontal_scroll_padding,
            60,
        )


if __name__ == "__main__":
    unittest.main()
