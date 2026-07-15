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


if __name__ == "__main__":
    unittest.main()
