#!/bin/bash

echo "=== Real Delay Calculator ==="

INPUT_CSV="../reports/area_timing_summary.csv"
OUTPUT_CSV="../reports/area_timing_summary_with_real_delays.csv"

# Check if input CSV exists
if [ ! -f "$INPUT_CSV" ]; then
    echo "ERROR: $INPUT_CSV not found."
    exit 1
fi

echo "Reading from: $INPUT_CSV"
echo "Writing to:   $OUTPUT_CSV"

# Add new header to output CSV
awk -F',' 'NR==1 {print $0 ",Real_Required_Clock_Period_ns"}' "$INPUT_CSV" > "$OUTPUT_CSV"

# Process each data row
awk -F',' 'NR>1 {
    clock_period = $4
    slack = $6
    gsub(/ /, "", clock_period)  # remove any spaces
    gsub(/ /, "", slack)
    
    # Compute real required period
    real_period = clock_period - slack
    
    # Print row + real period
    print $0 "," real_period
}' "$INPUT_CSV" >> "$OUTPUT_CSV"

echo "Done. Output written to: $OUTPUT_CSV"
