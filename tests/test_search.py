import unittest

from flet_code_editor_dsl import SearchMatch, find_matches


class FindMatchesTests(unittest.TestCase):
    def test_returns_zero_based_offsets_and_lines(self):
        self.assertEqual(
            find_matches("one\ntwo two\n", "two"),
            [SearchMatch(4, 7, 1), SearchMatch(8, 11, 1)],
        )

    def test_case_sensitive_and_whole_word_options(self):
        text = "Cat catalog CAT"
        self.assertEqual(
            find_matches(text, "cat", case_sensitive=True),
            [SearchMatch(4, 7, 0)],
        )
        self.assertEqual(
            find_matches(text, "cat", whole_word=True),
            [SearchMatch(0, 3, 0), SearchMatch(12, 15, 0)],
        )

    def test_current_line_and_invalid_line(self):
        text = "needle\nno match\nneedle"
        self.assertEqual(
            find_matches(text, "needle", current_line=2),
            [SearchMatch(16, 22, 2)],
        )
        self.assertEqual(find_matches(text, "needle", current_line=3), [])

    def test_casefold_expansion_preserves_original_offsets(self):
        self.assertEqual(
            find_matches("Straße", "STRASSE"),
            [SearchMatch(0, 6, 0)],
        )
        self.assertEqual(
            find_matches("ß", "s"),
            [SearchMatch(0, 1, 0)],
        )

    def test_empty_query_matches_nothing(self):
        self.assertEqual(find_matches("anything", ""), [])


if __name__ == "__main__":
    unittest.main()
