import os
import csv
import time
import matplotlib
import matplotlib.pyplot as plt
import numpy as np
import pandas as pd
from datetime import datetime

# Set non-interactive backend if no display is available
if os.environ.get('DISPLAY', '') == '':
    matplotlib.use('Agg')

start_time = datetime.now().strftime("%Y%m%d_%H%M%S")
output_dir = f"./reports/graphs/{start_time}"
os.makedirs(output_dir, exist_ok=True)

def calculate_real_frequency(freq_mhz, slack_ns):
    period_ns = 1000 / freq_mhz
    achievable_period = period_ns - slack_ns
    if achievable_period <= 0:
        return 0
    return 1000 / achievable_period

data = pd.read_csv("./reports/area_timing_summary.csv")
data['Real_Frequency_MHz'] = data.apply(lambda row: calculate_real_frequency(row['Frequency_MHz'], row['Slack_ns']), axis=1)
data['Total_Resources'] = data['LUTs'] + data['Registers'] + data['DSPs']*100 + data['BRAMs']*100 + data['SRLs']*10

operators = data['Operator'].unique()

for operator in operators:
    operator_data = data[data['Operator'] == operator]
    converters = operator_data['Converters'].unique()
    
    plt.figure(figsize=(10, 6))
    for converter in converters:
        subset = operator_data[operator_data['Converters'] == converter]
        subset = subset.sort_values('Frequency_MHz')
        plt.plot(subset['Frequency_MHz'], subset['Real_Frequency_MHz'], 'o-', label=converter)
    
    plt.title(f'{operator}: Real vs Listed Frequency')
    plt.xlabel('Listed Frequency (MHz)')
    plt.ylabel('Real Frequency (MHz)')
    plt.grid(True)
    plt.legend()
    output_path = os.path.join(output_dir, f"{operator}_freq_comparison.png")
    plt.savefig(output_path)
    plt.close()
    
    plt.figure(figsize=(10, 6))
    for converter in converters:
        subset = operator_data[operator_data['Converters'] == converter]
        subset = subset.sort_values('Total_Resources')
        plt.plot(subset['Total_Resources'], subset['Real_Frequency_MHz'], 'o-', label=converter)
    
    plt.title(f'{operator}: Real Frequency vs Resources')
    plt.xlabel('Resource Usage (Weighted Sum)')
    plt.ylabel('Real Frequency (MHz)')
    plt.grid(True)
    plt.legend()
    output_path = os.path.join(output_dir, f"{operator}_resource_comparison.png")
    plt.savefig(output_path)
    plt.close()

print(f"Graphs saved to {output_dir}")
