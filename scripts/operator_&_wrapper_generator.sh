#!/bin/bash

# filepath: ./operator_&_wrapper_generator.sh

# This script generates VHDL wrapper files for each operator type found in area_timing_summary.csv,
# and updates flopoco_ip_cores.vhd to instantiate the correct operator implementations.

CSV_FILE="./reports/area_timing_summary.csv"
WRAPPER_DIR="../operator_&_wrappers_vhd"
FLOPOCO_VHD="$WRAPPER_DIR/flopoco_ip_cores.vhd"
GENERATED_UNITS_DIR="../generated_units"

mkdir -p "$WRAPPER_DIR"

# 1. Parse CSV and collect operator info
declare -A operator_lines
declare -A operator_last_delay

tail -n +2 "$CSV_FILE" | while IFS=',' read -r Operator Bitwidth Frequency_MHz clock_period Converters Slack_ns LUTs Registers DSPs BRAMs SRLs max_latency Real_Required_Clock_Period_ns; do
    op=$(echo "$Operator" | tr '[:upper:]' '[:lower:]')
    key="${op}_${Bitwidth}"
    delay=$(printf "%.0f" "$Real_Required_Clock_Period_ns")
    operator_lines["$key"]+="$Operator,$Bitwidth,$delay"$'\n'
    operator_last_delay["$key"]=$delay
done

# 2. Generate wrapper files
for key in "${!operator_lines[@]}"; do
    op=$(echo "$key" | cut -d_ -f1)
    bitwidth=$(echo "$key" | cut -d_ -f2)
    wrapper_file="$WRAPPER_DIR/${op}f.vhd"
    delay=${operator_last_delay[$key]}
    arch_name="arch_${bitwidth}_${delay}"

    # Find the generated unit directory
    unit_dir=$(find "$GENERATED_UNITS_DIR" -type d -name "*${Operator}_${bitwidth}_*noIO" | grep "${delay}" | head -1)
    operator_vhd="$unit_dir/operator.vhd"

    # Write wrapper entity and architecture
    {
        echo "library ieee;"
        echo "use ieee.std_logic_1164.all;"
        echo "entity ${op}f is"
        echo "    port (clk, ce : in std_logic;"
        echo "          X, Y : in std_logic_vector(${bitwidth}-1 downto 0);"
        echo "          R : out std_logic_vector(${bitwidth}-1 downto 0));"
        echo "end entity;"
        echo ""
        echo "architecture $arch_name of ${op}f is"
        echo "    component ${Operator}_${bitwidth}_${delay}_impl"
        echo "        port (clk, ce : in std_logic;"
        echo "              X, Y : in std_logic_vector(${bitwidth}-1 downto 0);"
        echo "              R : out std_logic_vector(${bitwidth}-1 downto 0));"
        echo "    end component;"
        echo "begin"
        echo "    u_impl: ${Operator}_${bitwidth}_${delay}_impl"
        echo "        port map (clk => clk, ce => ce, X => X, Y => Y, R => R);"
        echo "end architecture;"
    } > "$wrapper_file"
done

# 3. Update flopoco_ip_cores.vhd
{
    echo "-- Auto-generated operator instantiations"
    for key in "${!operator_lines[@]}"; do
        op=$(echo "$key" | cut -d_ -f1)
        bitwidth=$(echo "$key" | cut -d_ -f2)
        delay=${operator_last_delay[$key]}
        arch_name="arch_${bitwidth}_${delay}"
        echo "component ${op}f"
        echo "    port (clk, ce : in std_logic;"
        echo "          X, Y : in std_logic_vector(${bitwidth}-1 downto 0);"
        echo "          R : out std_logic_vector(${bitwidth}-1 downto 0));"
        echo "end component;"
        echo ""
        echo "-- Instantiation example:"
        echo "-- u_${op}_${bitwidth}_${delay}: entity work.${op}f($arch_name)"
        echo "--     port map (...);"
        echo ""
    done
} >> "$FLOPOCO_VHD"

echo "Wrapper generation and flopoco_ip_cores.vhd update complete."