import argparse
import time
import unittest
from unittest import mock

import gpu_stress_cli as gpu


class MatrixSizingTests(unittest.TestCase):
    def test_matrix_size_is_aligned_and_bounded(self):
        size = gpu.choose_matrix_size(256, 2)
        self.assertEqual(size % 256, 0)
        self.assertGreaterEqual(size, 512)
        self.assertLessEqual(size, 8192)

    def test_small_budget_uses_minimum(self):
        self.assertEqual(gpu.choose_matrix_size(1, 4), 512)

    def test_memory_budget_keeps_reserve(self):
        self.assertEqual(gpu._resolve_budget_mib(256, 2048, 8192), 256)
        with self.assertRaises(gpu.BackendUnavailable):
            gpu._resolve_budget_mib(256, 130, 4096)


class ProfileTests(unittest.TestCase):
    def make_args(self, **changes):
        values = dict(
            profile="constant",
            load=70.0,
            high_load=90.0,
            low_load=10.0,
            on_time=2.0,
            off_time=1.0,
            start_load=20.0,
            end_load=80.0,
            duration=10.0,
        )
        values.update(changes)
        return argparse.Namespace(**values)

    def test_constant_profile(self):
        self.assertEqual(gpu.profile_target(self.make_args(), 4.0), 70.0)

    def test_pulsed_profile(self):
        args = self.make_args(profile="pulsed")
        self.assertEqual(gpu.profile_target(args, 1.5), 90.0)
        self.assertEqual(gpu.profile_target(args, 2.5), 10.0)

    def test_ramp_profile(self):
        args = self.make_args(profile="ramp")
        self.assertAlmostEqual(gpu.profile_target(args, 5.0), 50.0)
        self.assertAlmostEqual(gpu.profile_target(args, 20.0), 80.0)


class ControllerTests(unittest.TestCase):
    def test_duty_mode_tracks_target_directly(self):
        controller = gpu.UtilizationController("duty")
        controller.reset(60)
        self.assertAlmostEqual(controller.update(40, 99, 1), 0.4)

    def test_feedback_increases_duty_when_below_target(self):
        controller = gpu.UtilizationController("feedback")
        controller.reset(80)
        duty = controller.update(80, 20, 1)
        self.assertGreater(duty, 0.8)

    def test_feedback_decreases_duty_when_above_target(self):
        controller = gpu.UtilizationController("feedback")
        controller.reset(50)
        duty = controller.update(50, 90, 1)
        self.assertLess(duty, 0.5)

    def test_missing_measurement_falls_back_to_open_loop(self):
        controller = gpu.UtilizationController("feedback")
        controller.reset(75)
        self.assertAlmostEqual(controller.update(30, None, 1), 0.3)

    def test_small_retarget_preserves_feedback_offset(self):
        controller = gpu.UtilizationController("feedback")
        controller.reset(50)
        controller.duty = 0.6
        self.assertAlmostEqual(controller.retarget(55), 0.65)

    def test_large_retarget_resets_controller(self):
        controller = gpu.UtilizationController("feedback")
        controller.reset(90)
        controller.duty = 1.0
        self.assertAlmostEqual(controller.retarget(10), 0.1)


class ParserTests(unittest.TestCase):
    def test_list_gpus_does_not_require_duration(self):
        args = gpu.build_parser().parse_args(["--list-gpus"])
        self.assertTrue(args.list_gpus)
        self.assertIsNone(args.duration)

    def test_percent_validation(self):
        parser = gpu.build_parser()
        with self.assertRaises(SystemExit):
            parser.parse_args(["--duration", "1", "--load", "101"])


class SchedulerSmokeTests(unittest.TestCase):
    class FakeMonitor:
        source = "fake"

        def sample(self):
            return gpu.GpuMetrics(
                timestamp=time.time(),
                name="Fake GPU",
                utilization_gpu=50.0,
                temperature_c=40.0,
                power_w=25.0,
            )

        def list_devices(self):
            return [(0, "Fake GPU")]

        def close(self):
            pass

    class FakeBackend(gpu.StressBackend):
        name = "fake"
        workload_name = "fake compute"
        dtype_name = "float32"
        device_name = "Fake GPU"
        resident_memory_mib = 1.0
        problem_size = 1
        chunk_seconds = 0.001

        def run_chunk(self):
            time.sleep(0.0005)
            self.chunk_seconds = 0.0005
            return self.chunk_seconds

    def test_short_run_without_cuda(self):
        args = gpu.build_parser().parse_args([
            "--duration", "0.03",
            "--load", "50",
            "--period-ms", "10",
            "--status-interval", "0.01",
        ])
        with mock.patch.object(gpu, "make_monitor", return_value=self.FakeMonitor()), mock.patch.object(
            gpu, "make_backend", return_value=(self.FakeBackend(), [])
        ):
            self.assertEqual(gpu.run(args), 0)


if __name__ == "__main__":
    unittest.main()
