"""Deterministic cost arithmetic and report drift acceptance; no paid services."""
import copy
from decimal import Decimal as D
from pathlib import Path
import subprocess
import tempfile
import unittest

from scripts import infra_cost_model as model

ROOT = Path(__file__).resolve().parents[2]


class InfrastructureCosts(unittest.TestCase):
    def setUp(self):
        Path('/tmp/agent-runs').mkdir(exist_ok=True)
        self.inputs = model.load_inputs()

    def test_hand_calculated_session_stock_and_physical_overhead(self):
        result = model.calculate(self.inputs, 10000, 12)
        self.assertEqual(result['metrics']['monthly_sessions'], D(200000))
        self.assertEqual(result['metrics']['cumulative_sessions'], D(2400000))
        self.assertEqual(result['datasets']['structured_receipt_payloads'], D(600000 * 32768))
        self.assertEqual(result['datasets']['accepted_grants_hashes_verdicts'], D(2400000 * 8192))
        self.assertEqual(result['metrics']['db_physical_gb'], result['metrics']['db_logical_gb'] * D('2.5'))

    def test_retained_receipts_plateau_but_permanent_data_and_accounts_grow(self):
        a = model.calculate(self.inputs, 10000, 3)
        b = model.calculate(self.inputs, 10000, 36)
        self.assertEqual(a['datasets']['structured_receipt_payloads'], b['datasets']['structured_receipt_payloads'])
        self.assertEqual(b['datasets']['audit_records'], a['datasets']['audit_records'] * 12)
        self.assertGreater(b['datasets']['profiles'], a['datasets']['profiles'])

    def test_provider_billing_rounding_and_gross_no_free_tier(self):
        self.assertEqual(model.ceil_units(D('1000000.01'), D(1000000)), 2)
        self.assertEqual(model.ceil_units(D(0), D(1000000)), 0)
        self.assertEqual(model.round_up(D('0.10001'), D('.1')), D('.2'))
        self.assertEqual(model.cloud_network_cost(D(1025), self.inputs['rates']), D('122.99'))
        result = model.calculate(self.inputs, 1000, 1)
        self.assertGreater(result['costs']['cloud_requests'], 0)
        self.assertEqual(result['costs']['r2_class_a'], D('4.50'))

    def test_download_sensitivity_counts_bytes_and_operations_with_free_r2_egress(self):
        a = model.calculate(self.inputs, 10000, 12)
        changed = copy.deepcopy(self.inputs)
        changed['usage']['model_downloads_per_mau'] *= 10
        b = model.calculate(changed, 10000, 12)
        self.assertEqual(b['metrics']['model_download_gb'], a['metrics']['model_download_gb'] * 10)
        self.assertGreater(b['metrics']['r2_class_b_requests'], a['metrics']['r2_class_b_requests'])
        self.assertEqual(b['costs']['r2_egress'], 0)
        self.assertEqual(b['metrics']['db_physical_gb'], a['metrics']['db_physical_gb'])

    def test_session_sensitivity_includes_permanent_and_runtime_cost(self):
        a = model.calculate(self.inputs, 10000, 12)
        changed = copy.deepcopy(self.inputs)
        changed['usage']['sessions_per_mau'] *= 2
        b = model.calculate(changed, 10000, 12)
        self.assertEqual(b['datasets']['ledger_events'], a['datasets']['ledger_events'] * 2)
        self.assertGreater(b['metrics']['requests'], a['metrics']['requests'])
        self.assertGreater(b['all_in_usd_launch'], a['all_in_usd_launch'])

    def test_cost_total_does_not_double_count_database_plans_or_labor(self):
        r = model.calculate(self.inputs, 10000, 12)
        self.assertEqual(r['costs']['db_compute_launch'], D('190.80'))  # 2.5 CU × 720h × $0.106
        self.assertEqual(r['costs']['db_compute_scale'], D('399.60'))
        self.assertEqual(r['costs']['operations_labor'], D(1320))  # 22h × $60
        expected = sum(v for k, v in r['costs'].items() if k not in {'db_compute_scale', 'operations_labor', 'moderation_labor'})
        self.assertEqual(r['technical_usd_launch'], expected)
        self.assertEqual(r['all_in_usd_launch'], expected + r['costs']['operations_labor'] + r['costs']['moderation_labor'])
        self.assertEqual(r['technical_usd_scale'] - r['technical_usd_launch'], r['costs']['db_compute_scale'] - r['costs']['db_compute_launch'])

    def test_invalid_and_ambiguous_inputs_fail(self):
        for value in [D(-1), D('NaN'), D('Infinity')]:
            changed = copy.deepcopy(self.inputs)
            changed['usage']['sessions_per_mau'] = value
            with self.assertRaises(ValueError): model.calculate(changed, 10000, 12)
        with self.assertRaises(ValueError): model.calculate(self.inputs, 0, 12)
        with self.assertRaises(ValueError): model.calculate(self.inputs, 10000, 0)
        with self.assertRaises(ValueError): model.calculate(self.inputs, 10000, True)
        with self.assertRaises(ValueError): model.decode_inputs('{"schema_version":1,"schema_version":1}')
        changed = copy.deepcopy(self.inputs)
        changed['usage']['silently_ignored_typo'] = 1
        with self.assertRaises(ValueError): model.calculate(changed, 10000, 12)
        changed = copy.deepcopy(self.inputs)
        changed['usage']['db_target_utilization'] = D('1.01')
        with self.assertRaises(ValueError): model.calculate(changed, 10000, 12)

    def test_capacity_extrapolation_is_flagged_and_auth_setting_is_effective(self):
        large = model.calculate(self.inputs, 1000000, 36)
        self.assertFalse(large['scale_shape_fits_assumption'])
        before = model.calculate(self.inputs, 10000, 12)
        changed = copy.deepcopy(self.inputs)
        changed['usage']['active_auth_sessions_per_mau'] = 4
        after = model.calculate(changed, 10000, 12)
        self.assertEqual(after['datasets']['active_auth_claims'], before['datasets']['active_auth_claims'] * 2)

    def test_refresh_frequency_changes_request_and_write_workload(self):
        before = model.calculate(self.inputs, 10000, 12)
        changed = copy.deepcopy(self.inputs)
        changed['usage']['refreshes_per_mau'] = D(400)
        after = model.calculate(changed, 10000, 12)
        extra_requests = D(3600000)  # 10k accounts × (400 − 40)
        self.assertEqual(after['metrics']['requests'] - before['metrics']['requests'], extra_requests)
        self.assertEqual(after['metrics']['pitr_gb'] - before['metrics']['pitr_gb'], extra_requests * 1024 / 1000000000 * 3 * 7 / 30)
        self.assertGreater(after['costs']['cloud_requests'], before['costs']['cloud_requests'])

    def test_client_side_dump_compression_does_not_reduce_neon_transfer(self):
        compressed = model.calculate(self.inputs, 1000000, 36)
        changed = copy.deepcopy(self.inputs)
        changed['usage']['backup_compression_fraction'] = D(1)
        plain = model.calculate(changed, 1000000, 36)
        self.assertEqual(compressed['metrics']['neon_transfer_gb'], plain['metrics']['neon_transfer_gb'])
        self.assertEqual(compressed['costs']['db_network'], plain['costs']['db_network'])
        self.assertLess(compressed['metrics']['cloud_transfer_gib'], plain['metrics']['cloud_transfer_gib'])
        expected = compressed['metrics']['db_logical_gb'] * 4 + compressed['metrics']['requests'] * 4096 / 1000000000
        self.assertEqual(compressed['metrics']['neon_transfer_gb'], expected)

    def test_permanent_writes_use_current_month_increment_not_lifetime_average(self):
        changed = copy.deepcopy(self.inputs)
        for row in changed['datasets']:
            row['rows_per_basis'] = 0
            if row['name'] == 'device_keys_and_operation_markers':
                row['rows_per_basis'] = 1
                row['bytes_per_row'] = D(1000000000)
        for key in ('sessions_per_mau', 'signins_per_mau', 'refreshes_per_mau', 'api_other_requests_per_mau', 'mutable_write_bytes_per_request'):
            changed['usage'][key] = 0
        month_one = model.calculate(changed, 10000, 1)
        month_two = model.calculate(changed, 10000, 2)
        self.assertEqual(month_two['metrics']['permanent_db_gb'] - month_one['metrics']['permanent_db_gb'], D(1000))
        self.assertEqual(month_two['metrics']['pitr_gb'], D(700))  # 1000 GB new × 3 WAL × 7/30 days

    def test_report_is_deterministic_and_check_detects_actual_drift(self):
        expected = model.render_report(self.inputs)
        self.assertEqual(expected, model.render_report(self.inputs))
        with tempfile.TemporaryDirectory(dir='/tmp/agent-runs') as directory:
            target = Path(directory) / 'costs.md'
            command = ['python3', str(ROOT/'scripts/infra_cost_model.py'), '--output', str(target)]
            write = subprocess.run(command + ['--write'], capture_output=True, text=True)
            self.assertEqual(write.returncode, 0, write.stderr)
            self.assertEqual(target.read_text(), expected)
            self.assertEqual(subprocess.run(command, capture_output=True).returncode, 0)
            target.write_text(expected.replace('10,000', '10,001', 1))
            failed = subprocess.run(command, capture_output=True, text=True)
            self.assertNotEqual(failed.returncode, 0)
            self.assertIn('drift', failed.stderr)
            self.assertIn('10,001', target.read_text())


if __name__ == '__main__':
    unittest.main()
