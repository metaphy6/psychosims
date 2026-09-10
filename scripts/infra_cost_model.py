#!/usr/bin/env python3
"""Calculate the local USD infrastructure worksheet; default mode checks drift."""
import argparse
from decimal import Decimal as D, ROUND_CEILING, ROUND_HALF_UP
import hashlib
import json
from pathlib import Path
import re
import sys

ROOT = Path(__file__).resolve().parents[1]
SPEC = ROOT / 'docs/specs/INFRA-COST-MODEL.md'
REPORT = ROOT / 'docs/reports/2026-09-10-infrastructure-costs.md'
MAUS = (1000, 10000, 100000, 1000000)
AGES = (1, 12, 36)
USAGE_KEYS = frozenset("""
month_days sessions_per_mau new_accounts_per_mau_month signins_per_mau refreshes_per_mau
refresh_retention_days receipt_retention_days operational_retention_days
active_auth_sessions_per_mau concurrent_users_fraction session_minutes
presence_interval_seconds api_requests_per_session api_other_requests_per_mau
abandoned_start_fraction model_downloads_per_mau model_download_retry_factor
model_download_gb download_chunk_bytes manifest_fetches_per_session
manifest_fetches_per_mau manifest_bytes model_and_catalog_storage_gb
history_events_per_session history_fetches_per_session
moderation_incidents_per_mau_month macro_events_per_month db_index_bloat_multiplier
backup_copies backup_exports_per_month backup_compression_fraction
backup_object_chunk_bytes pitr_days wal_write_multiplier mutable_write_bytes_per_request
db_ops_per_request db_response_bytes_per_request db_outbound_query_bytes_per_request
api_response_bytes_per_request request_log_bytes peak_to_average_requests
db_ops_per_cu_second db_target_utilization db_working_set_fraction db_memory_utilization
db_memory_gb_per_cu db_min_cu db_cu_step launch_max_cu scale_max_cu
routine_request_seconds receipt_request_seconds app_vcpu app_memory_gib
app_min_instances cold_starts_per_mau cold_start_seconds
background_cpu_seconds_per_session background_cpu_seconds_base
db_backup_cpu_seconds_per_gb provider_auth_usd_per_mau_allowance observability_fixed_usd
observability_usd_per_log_gb_allowance ops_base_hours ops_hours_per_10k_mau
ops_usd_per_hour moderation_minutes_per_incident moderation_usd_per_hour
storage_bytes_per_gb
""".split())
RATE_KEYS = frozenset("""
cloud_active_vcpu_second cloud_idle_vcpu_second cloud_gib_second cloud_request_million
cloud_billing_quantum_seconds cloud_egress_first_gib cloud_egress_next_gib
cloud_egress_high_gib neon_launch_cu_hour neon_scale_cu_hour neon_storage_gb_month
neon_pitr_gb_month neon_included_transfer_gb neon_transfer_gb r2_storage_gb_month
r2_class_a_million r2_class_b_million r2_egress_gb
""".split())
MILLION = D(1000000)
GIB = D(2**30)


def unique_object(pairs):
    result = {}
    for key, value in pairs:
        if key in result:
            raise ValueError('duplicate input key')
        result[key] = value
    return result


def decode_inputs(text):
    return json.loads(text, parse_float=D, parse_int=D,
                      object_pairs_hook=unique_object,
                      parse_constant=lambda _: (_ for _ in ()).throw(ValueError('nonfinite input')))


def load_inputs(path=SPEC):
    blocks = re.findall(r'^```json\n(.*?)\n```', Path(path).read_text(), re.M | re.S)
    if len(blocks) != 1:
        raise ValueError('expected one canonical JSON input block')
    data = decode_inputs(blocks[0])
    validate(data)
    return data


def validate(data):
    if set(data) != {'schema_version', 'price_checked', 'usage', 'rates', 'datasets'} or isinstance(data['schema_version'], bool) or data['schema_version'] != 1:
        raise ValueError('unsupported input schema')
    if not re.fullmatch(r'\d{4}-\d{2}-\d{2}', data['price_checked']):
        raise ValueError('price observation date required')
    for group in ('usage', 'rates'):
        if not isinstance(data[group], dict) or set(data[group]) != (USAGE_KEYS if group == 'usage' else RATE_KEYS):
            raise ValueError('unknown or missing numeric input')
        for key, number in data[group].items():
            if not re.fullmatch('[a-z][a-z0-9_]{0,63}', key) or not isinstance(number, (int, D)) or isinstance(number, bool) or not D(number).is_finite() or number < 0 or number > 10**12:
                raise ValueError('invalid nonnegative numeric input')
    for key in ('month_days', 'presence_interval_seconds', 'download_chunk_bytes', 'backup_object_chunk_bytes', 'db_ops_per_cu_second', 'db_target_utilization', 'db_memory_gb_per_cu', 'db_memory_utilization', 'db_cu_step', 'storage_bytes_per_gb'):
        if data['usage'].get(key, 0) <= 0:
            raise ValueError('positive unit/capacity denominator required')
    if data['rates'].get('cloud_billing_quantum_seconds', 0) <= 0:
        raise ValueError('positive billing quantum required')
    for key in ('concurrent_users_fraction', 'abandoned_start_fraction', 'backup_compression_fraction', 'db_working_set_fraction', 'db_target_utilization', 'db_memory_utilization'):
        if data['usage'][key] > 1:
            raise ValueError('fraction outside zero to one')
    for key in ('model_download_retry_factor', 'db_index_bloat_multiplier', 'peak_to_average_requests'):
        if data['usage'][key] < 1:
            raise ValueError('overhead multiplier below one')
    if not isinstance(data['datasets'], list) or not 1 <= len(data['datasets']) <= 64:
        raise ValueError('bounded dataset list required')
    names = set()
    for row in data['datasets']:
        if set(row) != {'name', 'basis', 'rows_per_basis', 'bytes_per_row', 'retention', 'store'}:
            raise ValueError('invalid dataset fields')
        if not re.fullmatch('[a-z][a-z0-9_]{0,63}', row['name']) or row['name'] in names or row['store'] not in ('db', 'object') or row['retention'] not in ('live', 'permanent', '2d', '8d', '90d'):
            raise ValueError('invalid/duplicate dataset')
        names.add(row['name'])
        for key in ('rows_per_basis', 'bytes_per_row'):
            n = row[key]
            if not isinstance(n, (int, D)) or isinstance(n, bool) or not D(n).is_finite() or n < 0:
                raise ValueError('invalid dataset weight')


def ceil_units(value, unit):
    return (D(value) / D(unit)).to_integral_value(rounding=ROUND_CEILING)


def round_up(value, quantum):
    return ceil_units(value, quantum) * D(quantum)


def cloud_network_cost(gib, rates):
    """Gross premium North America tiers; deliberately omit free first GiB."""
    first = min(gib, D(1024))
    second = min(max(gib - 1024, D(0)), D(9216))
    third = max(gib - 10240, D(0))
    return first * rates['cloud_egress_first_gib'] + second * rates['cloud_egress_next_gib'] + third * rates['cloud_egress_high_gib']


def calculate(data, mau, months):
    validate(data)
    if not isinstance(mau, int) or isinstance(mau, bool) or not 1 <= mau <= 10000000 or not isinstance(months, int) or isinstance(months, bool) or not 1 <= months <= 120:
        raise ValueError('MAU/age outside worksheet bounds')
    u, p = data['usage'], data['rates']
    m, age = D(mau), D(months)
    days = u['month_days']
    seconds = days * 86400
    gb = u['storage_bytes_per_gb']
    sessions = m * u['sessions_per_mau']
    starts = sessions * (1 + u['abandoned_start_fraction'])
    accounts = m * (1 + u['new_accounts_per_mau_month'] * (age - 1))
    basis = {
        'mau': m, 'accounts': accounts,
        'active_auth_sessions': m * u['active_auth_sessions_per_mau'],
        'cumulative_sessions': sessions * age, 'cumulative_starts': starts * age,
        'cumulative_signins': m * u['signins_per_mau'] * age,
        'retained_refreshes': m * u['refreshes_per_mau'] * min(days * age, u['refresh_retention_days']) / days,
        'recent_signins': m * u['signins_per_mau'] * min(days * age, u['operational_retention_days']) / days,
        'retained_sessions': sessions * min(days * age, u['receipt_retention_days']) / days,
        'recent_sessions': sessions * min(days * age, u['operational_retention_days']) / days,
        'unused_starts': sessions * u['abandoned_start_fraction'] * min(days * age, u['operational_retention_days']) / days,
        'concurrent_users': m * u['concurrent_users_fraction'],
        'history_events': sessions * age * u['history_events_per_session'],
        'moderation_incidents': m * age * u['moderation_incidents_per_mau_month'],
        'macro_events': u['macro_events_per_month'] * age,
    }
    # Retained stock and this month's writes are different quantities. Account
    # churn appends only the current increment after the initial month.
    permanent_flows = {
        'accounts': m if months == 1 else m * u['new_accounts_per_mau_month'],
        'cumulative_sessions': sessions,
        'cumulative_starts': starts,
        'cumulative_signins': m * u['signins_per_mau'],
        'history_events': sessions * u['history_events_per_session'],
        'moderation_incidents': m * u['moderation_incidents_per_mau_month'],
        'macro_events': u['macro_events_per_month'],
    }
    datasets, logical, objects, permanent, permanent_append = {}, D(0), D(0), D(0), D(0)
    for row in data['datasets']:
        if row['basis'] not in basis:
            raise ValueError('unsupported dataset basis')
        amount = basis[row['basis']] * row['rows_per_basis'] * row['bytes_per_row']
        datasets[row['name']] = amount
        if row['store'] == 'db':
            logical += amount
            if row['retention'] == 'permanent':
                permanent += amount
                if row['basis'] not in permanent_flows:
                    raise ValueError('unsupported permanent-write basis')
                permanent_append += permanent_flows[row['basis']] * row['rows_per_basis'] * row['bytes_per_row']
        else:
            objects += amount
    # Validate the row used by the mutable append-volume model explicitly.
    receipt_rows = [r for r in data['datasets'] if r['name'] == 'structured_receipt_payloads']
    history_rows = [r for r in data['datasets'] if r['name'] == 'signed_history_objects']
    if len(receipt_rows) != 1 or len(history_rows) != 1:
        raise ValueError('receipt and history datasets required')
    physical_gb = logical / gb * u['db_index_bloat_multiplier']
    presence_calls = sessions * u['session_minutes'] * 60 / u['presence_interval_seconds']
    requests = sessions * u['api_requests_per_session'] + presence_calls + (starts - sessions) + m * (u['api_other_requests_per_mau'] + u['refreshes_per_mau'] + 2 * u['signins_per_mau'])
    if requests < sessions:
        raise ValueError('request model omits receipt delivery')
    peak_rps = requests / seconds * u['peak_to_average_requests']
    peak_db_ops = peak_rps * u['db_ops_per_request']
    cpu_cu = peak_db_ops / (u['db_ops_per_cu_second'] * u['db_target_utilization'])
    hot_gb = physical_gb * u['db_working_set_fraction']
    memory_cu = hot_gb / (u['db_memory_gb_per_cu'] * u['db_memory_utilization'])
    cu = round_up(max(u['db_min_cu'], cpu_cu, memory_cu), u['db_cu_step'])
    backup_gb = logical / gb * u['backup_compression_fraction'] * u['backup_copies']
    backup_read_gb = logical / gb * u['backup_exports_per_month']
    export_gb = backup_read_gb * u['backup_compression_fraction']
    monthly_append = permanent_append + sessions * receipt_rows[0]['bytes_per_row'] + requests * u['mutable_write_bytes_per_request']
    wal_gb = monthly_append / gb * u['wal_write_multiplier'] * u['pitr_days'] / days
    downloads = m * u['model_downloads_per_mau'] * u['model_download_retry_factor']
    download_gb = downloads * u['model_download_gb']
    manifest_gets = sessions * u['manifest_fetches_per_session'] + m * u['manifest_fetches_per_mau']
    history_gets = sessions * u['history_fetches_per_session']
    r2_transfer_gb = download_gb + (manifest_gets * u['manifest_bytes'] + history_gets * history_rows[0]['bytes_per_row']) / gb
    r2_b = downloads * ceil_units(u['model_download_gb'] * gb, u['download_chunk_bytes']) + manifest_gets + history_gets
    r2_a = sessions * u['history_events_per_session'] + u['macro_events_per_month'] + ceil_units(export_gb * gb, u['backup_object_chunk_bytes'])
    logs_gb = requests * u['request_log_bytes'] / gb
    object_gb = objects / gb + u['model_and_catalog_storage_gb'] + backup_gb + logs_gb
    # pg_dump compresses on the client, after SQL results leave the database.
    neon_transfer_gb = requests * u['db_response_bytes_per_request'] / gb + backup_read_gb
    cloud_transfer_gib = (requests * (u['api_response_bytes_per_request'] + u['db_outbound_query_bytes_per_request']) + export_gb * gb) / GIB
    quantum = p['cloud_billing_quantum_seconds']
    active_seconds = (requests - sessions) * round_up(u['routine_request_seconds'], quantum) + sessions * round_up(u['receipt_request_seconds'], quantum)
    active_seconds += m * u['cold_starts_per_mau'] * round_up(u['cold_start_seconds'], quantum)
    background_seconds = u['background_cpu_seconds_base'] + sessions * u['background_cpu_seconds_per_session'] + backup_read_gb * u['db_backup_cpu_seconds_per_gb']
    idle_seconds = max(seconds * u['app_min_instances'] - active_seconds, D(0))
    costs = {
        'cloud_cpu_active_jobs': (active_seconds + background_seconds) * u['app_vcpu'] * p['cloud_active_vcpu_second'],
        'cloud_cpu_idle': idle_seconds * u['app_vcpu'] * p['cloud_idle_vcpu_second'],
        'cloud_memory': (active_seconds + background_seconds + idle_seconds) * u['app_memory_gib'] * p['cloud_gib_second'],
        'cloud_requests': requests / MILLION * p['cloud_request_million'],
        'cloud_network': cloud_network_cost(cloud_transfer_gib, p),
        'db_compute_launch': cu * days * 24 * p['neon_launch_cu_hour'],
        'db_compute_scale': cu * days * 24 * p['neon_scale_cu_hour'],
        'db_storage': physical_gb * p['neon_storage_gb_month'],
        'db_pitr': wal_gb * p['neon_pitr_gb_month'],
        'db_network': max(neon_transfer_gb - p['neon_included_transfer_gb'], D(0)) * p['neon_transfer_gb'],
        'r2_storage_backups_logs': ceil_units(object_gb, 1) * p['r2_storage_gb_month'],
        'r2_class_a': ceil_units(r2_a, MILLION) * p['r2_class_a_million'],
        'r2_class_b': ceil_units(r2_b, MILLION) * p['r2_class_b_million'],
        'r2_egress': r2_transfer_gb * p['r2_egress_gb'],
        'provider_auth_allowance': m * u['provider_auth_usd_per_mau_allowance'],
        'observability_allowance': u['observability_fixed_usd'] + logs_gb * u['observability_usd_per_log_gb_allowance'],
        'operations_labor': (u['ops_base_hours'] + m / 10000 * u['ops_hours_per_10k_mau']) * u['ops_usd_per_hour'],
        'moderation_labor': m * u['moderation_incidents_per_mau_month'] * u['moderation_minutes_per_incident'] / 60 * u['moderation_usd_per_hour'],
    }
    technical = sum(value for key, value in costs.items() if key not in ('db_compute_scale', 'operations_labor', 'moderation_labor'))
    scale = technical + costs['db_compute_scale'] - costs['db_compute_launch']
    labor = costs['operations_labor'] + costs['moderation_labor']
    return {'mau': mau, 'months': months, 'datasets': datasets, 'costs': costs,
            'metrics': {'monthly_sessions': sessions, 'cumulative_sessions': sessions * age,
                        'registered_accounts': accounts, 'requests': requests, 'peak_rps': peak_rps,
                        'peak_db_ops_second': peak_db_ops, 'db_cu': cu, 'db_hot_gb': hot_gb,
                        'db_logical_gb': logical / gb, 'db_physical_gb': physical_gb,
                        'permanent_db_gb': permanent / gb, 'backup_gb': backup_gb,
                        'permanent_append_db_gb': permanent_append / gb,
                        'monthly_backup_read_gb': backup_read_gb,
                        'monthly_backup_export_gb': export_gb, 'pitr_gb': wal_gb,
                        'model_download_gb': download_gb, 'r2_transfer_gb': r2_transfer_gb,
                        'r2_class_a_requests': r2_a, 'r2_class_b_requests': r2_b,
                        'r2_storage_gb': object_gb, 'neon_transfer_gb': neon_transfer_gb,
                        'cloud_transfer_gib': cloud_transfer_gib, 'app_active_seconds': active_seconds,
                        'app_idle_seconds': idle_seconds, 'background_seconds': background_seconds},
            'technical_usd_launch': technical, 'technical_usd_scale': scale,
            'all_in_usd_launch': technical + labor, 'all_in_usd_scale': scale + labor,
            'launch_shape_fits_assumption': cu <= u['launch_max_cu'],
            'scale_shape_fits_assumption': cu <= u['scale_max_cu']}


def number(value, places=2):
    return f'{D(value).quantize(D(10) ** -places, rounding=ROUND_HALF_UP):,.{places}f}'


def render_report(data):
    results = [calculate(data, mau, age) for mau in MAUS for age in AGES]
    digest = hashlib.sha256(json.dumps(data, sort_keys=True, default=str).encode()).hexdigest()
    source = hashlib.sha256(Path(__file__).read_bytes()).hexdigest()
    lines = ['# Infrastructure cost worksheet — 2026-09-10', '',
             'Generated by `python3 scripts/infra_cost_model.py --write`; default mode checks drift.',
             '[Editable inputs, formulas, sources and limitations](../specs/INFRA-COST-MODEL.md).', '',
             f'Input SHA-256: `{digest}`. Calculator SHA-256: `{source}`.', '',
             'All figures are modeled USD per normalized 30-day month, before tax, with no free-tier credits.',
             'Months are retained-history horizons at constant MAU; this prices ending stock, not a growth forecast.',
             '**C-3 ship gate remains pending. These CU requirements and workloads are assumptions, not capacity measurements.**', '',
             '## Monthly run rates', '',
             '| MAU | History months | DB physical GB | Assumed CU | Launch technical USD | Scale technical USD | Launch incl. labor USD | Scale incl. labor USD | Shape check |',
             '| ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | --- |']
    for r in results:
        status = 'within listed sizes; unproven' if r['launch_shape_fits_assumption'] else ('Scale size only; unproven' if r['scale_shape_fits_assumption'] else '**exceeds both; extrapolation only**')
        lines.append(f"| {r['mau']:,} | {r['months']} | {number(r['metrics']['db_physical_gb'])} | {number(r['metrics']['db_cu'])} | {number(r['technical_usd_launch'])} | {number(r['technical_usd_scale'])} | {number(r['all_in_usd_launch'])} | {number(r['all_in_usd_scale'])} | {status} |")
    ten = [r for r in results if r['mau'] == 10000]
    lines += ['', '## 10,000 MAU: every cost component', '',
              'The two DB compute rows are alternative rate references; totals include only one.',
              'Provider-auth/observability are budget allowances; labor is separate from technical cost.', '',
              '| Component (USD/month) | Month 1 | Month 12 | Month 36 |', '| --- | ---: | ---: | ---: |']
    for key in ten[0]['costs']:
        lines.append('| '+key+' | '+' | '.join(number(r['costs'][key]) for r in ten)+' |')
    lines += ['', '## 10,000 MAU: workload, backups and network', '',
              '| Metric (unit in name) | Month 1 | Month 12 | Month 36 |', '| --- | ---: | ---: | ---: |']
    for key in ten[0]['metrics']:
        lines.append('| '+key+' | '+' | '.join(number(r['metrics'][key]) for r in ten)+' |')
    lines += ['', '## 10,000 MAU at month 12: full dataset stock', '',
              'GB below are logical allowances, before the DB overhead multiplier; object rows avoid that multiplier.', '',
              '| Dataset | Store | Retention model | Logical GB |', '| --- | --- | --- | ---: |']
    for row in data['datasets']:
        lines.append(f"| {row['name']} | {row['store']} | {row['retention']} | {number(ten[1]['datasets'][row['name']]/data['usage']['storage_bytes_per_gb'],4)} |")
    lines += ['', '## 10,000 MAU / month 12 sensitivity', '',
              'One input changes at a time. Download bytes still matter operationally with zero direct R2 egress pricing.', '',
              '| Variant | DB GB | Model delivery GB/month | R2 B requests/month | Assumed CU | Launch technical USD | Launch incl. labor USD |',
              '| --- | ---: | ---: | ---: | ---: | ---: | ---: |']
    variants = [('sessions/MAU=5', 'sessions_per_mau', D(5)), ('sessions/MAU=20', 'sessions_per_mau', D(20)), ('sessions/MAU=60', 'sessions_per_mau', D(60)), ('downloads/MAU=0.05', 'model_downloads_per_mau', D('.05')), ('downloads/MAU=1', 'model_downloads_per_mau', D(1)), ('working set=20%', 'db_working_set_fraction', D('.2')), ('ops rate=100 USD/h', 'ops_usd_per_hour', D(100))]
    import copy
    for label, key, value in variants:
        changed = copy.deepcopy(data)
        changed['usage'][key] = value
        r = calculate(changed, 10000, 12)
        a = r['metrics']
        lines.append(f"| {label} | {number(a['db_physical_gb'])} | {number(a['model_download_gb'])} | {number(a['r2_class_b_requests'],0)} | {number(a['db_cu'])} | {number(r['technical_usd_launch'])} | {number(r['all_in_usd_launch'])} |")
    changed = copy.deepcopy(data)
    for row in changed['datasets']:
        if row['name'] == 'structured_receipt_payloads': row['bytes_per_row'] = D(131072)
    r = calculate(changed, 10000, 12)
    a = r['metrics']
    lines.append(f"| receipt payload=128KiB | {number(a['db_physical_gb'])} | {number(a['model_download_gb'])} | {number(a['r2_class_b_requests'],0)} | {number(a['db_cu'])} | {number(r['technical_usd_launch'])} | {number(r['all_in_usd_launch'])} |")
    lines += ['', '## Interpretation and remaining gates', '',
              'Permanent records continue growing after the 90-day receipt window fills. Storage therefore becomes a larger line with account age.',
              'Under the direct R2 reference, model traffic dominates bytes but does not automatically dominate dollars; operations and assumed DB memory can outweigh it.',
              'A reference price times a CU estimate is not a deployment quote. A topology outside a published compute size needs a separately tested design.',
              'Before shipping: measure sustained DB operations, hot-set/cache behavior, receipt size distribution, WAL/bloat, connection pools, cold-start/concurrency billing, regional network paths and restore performance; choose providers and support/security terms; agree a staffed operations and revenue budget.', '',
              '## Price provenance', '',
              f"Checked {data['price_checked']}; workload and labor values are internal assumptions.",
              '- [Cloud Run billing rates](https://cloud.google.com/run/pricing) and [premium network tiers](https://cloud.google.com/vpc/network-pricing).',
              '- [R2 Standard storage/operations/rounding](https://developers.cloudflare.com/r2/pricing/).',
              '- [Current Neon prices](https://neon.com/pricing), [compute-rate change](https://neon.com/docs/changelog/2025-11-07), [CU/PITR explanation](https://neon.com/blog/new-usage-based-pricing), and [500GB paid transfer change](https://neon.com/blog/more-data-transfer-on-paid-plans).', '']
    return '\n'.join(lines)


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--write', action='store_true')
    parser.add_argument('--spec', type=Path, default=SPEC)
    parser.add_argument('--output', type=Path, default=REPORT)
    options = parser.parse_args(argv)
    try:
        expected = render_report(load_inputs(options.spec))
        if options.write:
            options.output.write_text(expected)
        elif not options.output.exists() or options.output.read_text() != expected:
            raise ValueError('cost report drift; regenerate and review')
        print('Cost worksheet '+('written' if options.write else 'verified'))
        return 0
    except (OSError, ValueError, KeyError, TypeError) as error:
        print(f'Cost worksheet failed: {error}', file=sys.stderr)
        return 1


if __name__ == '__main__':
    sys.exit(main())
