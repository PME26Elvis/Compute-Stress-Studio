from __future__ import annotations

import unittest
from pathlib import Path

import gpu_stress_background as background


class BackgroundLauncherArgumentTests(unittest.TestCase):
    def test_empty_arguments_get_personal_defaults_and_csv(self) -> None:
        csv_path = Path("P2200-Runs/gpu-stress-p2200.csv")
        self.assertEqual(
            background._build_worker_arguments([], csv_path),
            [
                "--duration",
                "345600",
                "--load",
                "87",
                "--csv",
                str(csv_path),
            ],
        )

    def test_explicit_values_are_not_overridden(self) -> None:
        csv_path = Path("custom.csv")
        self.assertEqual(
            background._build_worker_arguments(
                ["--duration=120", "--load=55", "--csv=other.csv"], csv_path
            ),
            ["--duration=120", "--load=55", "--csv=other.csv"],
        )

    def test_profile_suppresses_load_default(self) -> None:
        csv_path = Path("run.csv")
        self.assertEqual(
            background._build_worker_arguments(["--profile", "ramp"], csv_path),
            [
                "--profile",
                "ramp",
                "--duration",
                "345600",
                "--csv",
                str(csv_path),
            ],
        )

    def test_informational_commands_do_not_get_run_defaults(self) -> None:
        csv_path = Path("run.csv")
        self.assertEqual(background._build_worker_arguments(["--help"], csv_path), ["--help"])
        self.assertEqual(
            background._build_worker_arguments(["--diagnose"], csv_path), ["--diagnose"]
        )


if __name__ == "__main__":
    unittest.main()
