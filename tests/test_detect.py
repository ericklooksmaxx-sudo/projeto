"""`.detect` must give a real answer even when the optional ML model file is not installed."""
import unittest
from unittest import mock

import classifier

MOONSEC_V3 = "--[[ This file was protected with MoonSec V3 ]]\nlocal a = 1\n"
CLEAN = (
    "local function greet(name)\n"
    "    if name then\n"
    "        print('hello ' .. name)\n"
    "    end\n"
    "    return name\n"
    "end\n"
    "for i = 1, 3 do\n"
    "    greet(tostring(i))\n"
    "end\n"
)


class DetectBestTests(unittest.TestCase):
    def test_uses_the_ml_model_when_it_is_installed(self):
        with mock.patch.object(classifier, "get_model", return_value={"fake": "model"}), \
                mock.patch.object(classifier, "detect_full", return_value={"verdict": "from-ml"}) as full:
            result = classifier.detect_best("local x = 1")
        full.assert_called_once_with("local x = 1")
        self.assertEqual(result, {"verdict": "from-ml"})

    def test_without_a_model_it_does_not_claim_everything_is_clean(self):
        with mock.patch.object(classifier, "get_model", return_value=None):
            result = classifier.detect_best(MOONSEC_V3)
        self.assertEqual(result["display_name"], "MoonSec V3")
        self.assertEqual(result["name"], "MoonSec V3")
        self.assertGreaterEqual(result["confidence"], 95)
        self.assertEqual(result["verdict"], "Obfuscated with MoonSec V3")

    def test_clean_code_is_reported_as_clean(self):
        with mock.patch.object(classifier, "get_model", return_value=None):
            result = classifier.detect_best(CLEAN)
        self.assertEqual(result["display_name"], "Clean (Unobfuscated)")
        self.assertEqual(result["verdict"], "Likely Clean (Unobfuscated)")

    def test_no_known_signature_is_not_called_obfuscated(self):
        with mock.patch.object(classifier, "get_model", return_value=None):
            result = classifier.detect_best("print('hi')")
        self.assertEqual(result["display_name"], "Unknown / Custom")
        self.assertEqual(result["verdict"], "No known obfuscator signature found")

    def test_empty_input(self):
        with mock.patch.object(classifier, "get_model", return_value=None):
            result = classifier.detect_best("   ")
        self.assertEqual(result["display_name"], "Empty")
        self.assertEqual(result["confidence"], 0.0)


if __name__ == "__main__":
    unittest.main()
