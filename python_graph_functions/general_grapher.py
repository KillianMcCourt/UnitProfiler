import pandas as pd
import matplotlib
matplotlib.use('Agg')  # Use non-interactive backend for headless environments
import matplotlib.pyplot as plt
import numpy as np
from pathlib import Path

def load_and_process_data():
    """Load the CSV data and process it for graphing"""
    # Read the CSV file
    df = pd.read_csv('../reports/area_timing_summary.csv')
    
    # Create a combined operator-bitwidth identifier
    df['Op_Bitwidth'] = df['Operator'] + '_' + df['Bitwidth'].astype(str)
    
    # Calculate weighted hardware resources
    # Weights based on typical FPGA resource costs:
    # LUTs: 1 (base unit)
    # Registers: 0.5 (typically less constraining than LUTs)
    # DSPs: 10 (high-value, limited resources)
    # BRAMs: 20 (very limited, high-value resources)
    # SRLs: 2 (shift register LUTs, more valuable than regular LUTs)
    df['Weighted_HW_Resources'] = (
        df['LUTs'] * 1.0 +
        df['Registers'] * 0.5 +
        df['DSPs'] * 10.0 +
        df['BRAMs'] * 20.0 +
        df['SRLs'] * 2.0
    )
    
    return df

def create_latency_vs_clock_period_graphs(df):
    """Create graphs of required clock period vs latency for each (operator, bitwidth) pair"""
    # Get unique operator-bitwidth combinations
    op_bitwidth_pairs = df['Op_Bitwidth'].unique()
    
    # Create subplots
    n_pairs = len(op_bitwidth_pairs)
    n_cols = min(3, n_pairs)
    n_rows = (n_pairs + n_cols - 1) // n_cols
    
    fig, axes = plt.subplots(n_rows, n_cols, figsize=(5*n_cols, 4*n_rows))
    if n_pairs == 1:
        axes = [axes]
    elif n_rows == 1:
        axes = axes.reshape(1, -1)
    
    # Flatten axes for easier indexing
    axes_flat = axes.flatten() if n_pairs > 1 else axes
    
    for idx, op_bitwidth in enumerate(op_bitwidth_pairs):
        subset = df[df['Op_Bitwidth'] == op_bitwidth].copy()
        subset = subset.sort_values('max_latency')
        
        ax = axes_flat[idx]
        ax.scatter(subset['max_latency'], subset['Real_Required_Clock_Period_ns'], 
                  alpha=0.7, s=60, color='blue')
        
        # Connect the points with lines
        if len(subset) > 1:
            ax.plot(subset['max_latency'], subset['Real_Required_Clock_Period_ns'], 
                   "r--", alpha=0.8, linewidth=2)
        
        ax.set_xlabel('Max Latency (cycles)')
        ax.set_ylabel('Required Clock Period (ns)')
        ax.set_title(f'{op_bitwidth}')
        ax.grid(True, alpha=0.3)
        
        # Add frequency labels for reference
        for _, row in subset.iterrows():
            freq_mhz = 1000 / row['Real_Required_Clock_Period_ns']
            ax.annotate(f'{freq_mhz:.0f}MHz', 
                       (row['max_latency'], row['Real_Required_Clock_Period_ns']),
                       xytext=(5, 5), textcoords='offset points', 
                       fontsize=8, alpha=0.7)
    
    # Hide unused subplots
    for idx in range(n_pairs, len(axes_flat)):
        axes_flat[idx].set_visible(False)
    
    plt.tight_layout()
    plt.suptitle('Required Clock Period vs Latency by Operator and Bitwidth', 
                 fontsize=14, y=1.02)
    
    # Save the figure
    output_dir = Path('../reports/graphs')
    output_dir.mkdir(exist_ok=True)
    plt.savefig(output_dir / 'latency_vs_clock_period.png', dpi=300, bbox_inches='tight')
    print(f"Saved latency vs clock period graph to: {output_dir / 'latency_vs_clock_period.png'}")
    
    # plt.show()  # Commented out for headless environments

def create_hw_resources_vs_clock_period_graphs(df):
    """Create graphs of required clock period vs hardware resources for each (operator, bitwidth) pair"""
    # Get unique operator-bitwidth combinations
    op_bitwidth_pairs = df['Op_Bitwidth'].unique()
    
    # Create subplots
    n_pairs = len(op_bitwidth_pairs)
    n_cols = min(3, n_pairs)
    n_rows = (n_pairs + n_cols - 1) // n_cols
    
    fig, axes = plt.subplots(n_rows, n_cols, figsize=(5*n_cols, 4*n_rows))
    if n_pairs == 1:
        axes = [axes]
    elif n_rows == 1:
        axes = axes.reshape(1, -1)
    
    # Flatten axes for easier indexing
    axes_flat = axes.flatten() if n_pairs > 1 else axes
    
    for idx, op_bitwidth in enumerate(op_bitwidth_pairs):
        subset = df[df['Op_Bitwidth'] == op_bitwidth].copy()
        subset = subset.sort_values('Weighted_HW_Resources')
        
        ax = axes_flat[idx]
        scatter = ax.scatter(subset['Weighted_HW_Resources'], 
                           subset['Real_Required_Clock_Period_ns'], 
                           c=subset['max_latency'], cmap='viridis', 
                           alpha=0.7, s=60)
        
        # Add colorbar for latency
        cbar = plt.colorbar(scatter, ax=ax)
        cbar.set_label('Latency (cycles)', fontsize=8)
        
        # Connect the points with lines
        if len(subset) > 1:
            ax.plot(subset['Weighted_HW_Resources'], 
                   subset['Real_Required_Clock_Period_ns'], 
                   "r--", alpha=0.8, linewidth=2)
        
        ax.set_xlabel('Weighted HW Resources')
        ax.set_ylabel('Required Clock Period (ns)')
        ax.set_title(f'{op_bitwidth}')
        ax.grid(True, alpha=0.3)
        
        # Add frequency labels for reference
        for _, row in subset.iterrows():
            freq_mhz = 1000 / row['Real_Required_Clock_Period_ns']
            ax.annotate(f'{freq_mhz:.0f}MHz', 
                       (row['Weighted_HW_Resources'], row['Real_Required_Clock_Period_ns']),
                       xytext=(5, 5), textcoords='offset points', 
                       fontsize=8, alpha=0.7)
    
    # Hide unused subplots
    for idx in range(n_pairs, len(axes_flat)):
        axes_flat[idx].set_visible(False)
    
    plt.tight_layout()
    plt.suptitle('Required Clock Period vs Weighted HW Resources by Operator and Bitwidth', 
                 fontsize=14, y=1.02)
    
    # Save the figure
    output_dir = Path('../reports/graphs')
    output_dir.mkdir(exist_ok=True)
    plt.savefig(output_dir / 'hw_resources_vs_clock_period.png', dpi=300, bbox_inches='tight')
    print(f"Saved HW resources vs clock period graph to: {output_dir / 'hw_resources_vs_clock_period.png'}")
    
    # plt.show()  # Commented out for headless environments

def print_resource_weights_info():
    """Print information about the resource weighting scheme"""
    print("Hardware Resource Weighting Scheme:")
    print("- LUTs: 1.0 (base unit)")
    print("- Registers: 0.5 (typically less constraining)")
    print("- DSPs: 10.0 (high-value, limited resources)")
    print("- BRAMs: 20.0 (very limited, high-value resources)")
    print("- SRLs: 2.0 (shift register LUTs, more valuable than regular LUTs)")
    print()

def main():
    """Main function to run the analysis"""
    print("Loading and processing area timing data...")
    df = load_and_process_data()
    
    print(f"Loaded {len(df)} data points")
    print(f"Found {len(df['Op_Bitwidth'].unique())} unique (Operator, Bitwidth) pairs:")
    for pair in sorted(df['Op_Bitwidth'].unique()):
        count = len(df[df['Op_Bitwidth'] == pair])
        print(f"  - {pair}: {count} configurations")
    print()
    
    print_resource_weights_info()
    
    print("Creating latency vs clock period graphs...")
    create_latency_vs_clock_period_graphs(df)
    
    print("Creating hardware resources vs clock period graphs...")
    create_hw_resources_vs_clock_period_graphs(df)
    
    print("Analysis complete!")

if __name__ == "__main__":
    main()