from __future__ import annotations

import unittest

import gpu_stress_portable as portable


class PortableBackendArgumentTests(unittest.TestCase):
    def test_adds_cupy_backend_when_missing(self) -> None:
        self.assertEqual(
            portable._force_cupy_backend(["--duration", "10", "--load", "80"]),
            ["--duration", "10", "--load", "80", "--backend", "cupy"],
        )

    def test_replaces_split_backend_value(self) -> None:
        self.assertEqual(
            portable._force_cupy_backend(["--backend", "torch", "--diagnose"]),
            ["--backend", "cupy", "--diagnose"],
        )

    def test_replaces_equals_backend_value(self) -> None:
        self.assertEqual(
            portable._force_cupy_backend(["--backend=numba", "--diagnose"]),
            ["--backend=cupy", "--diagnose"],
        )

    def test_does_not_mutate_input(self) -> None:
        original = ["--duration", "5"]
        portable._force_cupy_backend(original)
        self.assertEqual(original, ["--duration", "5"])


class PersonalDefaultTests(unittest.TestCase):
    def test_empty_arguments_get_96_hour_and_87_percent_defaults(self) -> None:
        self.assertEqual(
            portable._apply_personal_defaults([]),
            ["--duration", "345600", "--load", "87.0"],
        )

    def test_explicit_duration_and_load_are_preserved(self) -> None:
        self.assertEqual(
            portable._apply_personal_defaults(["--duration", "60", "--load", "50"]),
            ["--duration", "60", "--load", "50"],
        )

    def test_equals_style_options_are_preserved(self) -> None:
        self.assertEqual(
            portable._apply_personal_defaults(["--duration=120", "--load=70"]),
            ["--duration=120", "--load=70"],
        )

    def test_profile_suppresses_constant_load_default(self) -> None:
        self.assertEqual(
            portable._apply_personal_defaults(["--profile", "ramp"]),
            ["--profile", "ramp", "--duration", "345600"],
        )

    def test_informational_commands_do_not_get_long_run_defaults(self) -> None:
        self.assertEqual(portable._apply_personal_defaults(["--diagnose"]), ["--diagnose"])
        self.assertEqual(portable._apply_personal_defaults(["--list-gpus"]), ["--list-gpus"])
        self.assertEqual(portable._apply_personal_defaults(["--help"]), ["--help"])

    def test_final_arguments_include_defaults_and_cupy(self) -> None:
        self.assertEqual(
            portable.build_portable_arguments([]),
            ["--duration", "345600", "--load", "87.0", "--backend", "cupy"],
        )


if __name__ == "__main__":
    unittest.main()
