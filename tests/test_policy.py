import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parents[1] / "cron-scheduler"))

from policy import choose_replicas, parse_carbon_intensity


class CarbonPolicyTests(unittest.TestCase):
    def test_clean_grid_scales_up(self):
        self.assertEqual(choose_replicas(100), 5)

    def test_threshold_is_dirty(self):
        self.assertEqual(choose_replicas(150), 1)

    def test_custom_replica_bounds(self):
        self.assertEqual(choose_replicas(120, threshold=150, min_replicas=2, max_replicas=4), 4)

    def test_carbon_value_is_validated(self):
        self.assertEqual(parse_carbon_intensity("220"), 220)
        with self.assertRaises(ValueError):
            parse_carbon_intensity("not-a-number")
        with self.assertRaises(ValueError):
            parse_carbon_intensity(-1)


if __name__ == "__main__":
    unittest.main()