#!/usr/bin/env python3

import json
import csv
from collections import defaultdict
from pathlib import Path

# Paths
component_json_path = Path('../component_json/base_component.json')
csv_path = Path('../reports/area_timing_summary.csv')
output_path = component_json_path  # overwrite in place

# Mapping from CSV Operator to JSON component key
operator_to_component = {
    'Multiplier': 'handshake.mulf',
    'Adder': 'handshake.addf',
    'Divider': 'handshake.divf'
    # Add more mappings if needed
}

# Load JSON
with component_json_path.open('r') as f:
    components = json.load(f)

# Parse CSV and build latency data
latency_data = defaultdict(lambda: defaultdict(dict))  # {component: {bitwidth: {period: latency}}}

with csv_path.open('r') as f:
    reader = csv.DictReader(f)
    for row in reader:
        operator = row['Operator']
        if operator not in operator_to_component:
            continue

        component_key = operator_to_component[operator]
        bitwidth = row['Bitwidth']
        period = row['Real_Required_Clock_Period_ns']
        latency = float(row['max_latency'])

        latency_data[component_key][bitwidth][period] = latency

# Update JSON with new latency data, sorted by latency ascending
for component_key, bitwidth_data in latency_data.items():
    if component_key not in components:
        continue

    # Clear existing latency block
    components[component_key]['latency'] = {}

    for bitwidth, period_data in bitwidth_data.items():
        # Sort by latency ascending
        sorted_period_data = dict(
            sorted(period_data.items(), key=lambda item: item[1])
        )
        components[component_key]['latency'][bitwidth] = sorted_period_data

# Write updated JSON
with output_path.open('w') as f:
    json.dump(components, f, indent=2)

print("Latency data updated and sorted successfully.")
