### 1. `profiler_executable_vivado.sh`

```bash
#!/bin/bash
# Profiler executable for Vivado Floating Point Units

echo "=== FPGA Implementation Script for Floating Point Units (Vivado) ==="
echo "Starting in directory: $(pwd)"

# Create necessary directories for Vivado results
mkdir -p ../vivado_reports
mkdir -p ../vivado_reports/utilization
mkdir -p ../vivado_reports/timing

# Get absolute path to current directory
SCRIPT_DIR="$(pwd)"
GENERATED_UNITS_DIR="${SCRIPT_DIR}/../vivado_units"

echo "Looking for unit directories in: ${GENERATED_UNITS_DIR}"

# Check if the vivado_units directory exists
if [ ! -d "${GENERATED_UNITS_DIR}" ]; then
    echo "ERROR: Directory ${GENERATED_UNITS_DIR} does not exist!"
    exit 1
fi

# List all directories in vivado_units for debugging
echo "All directories in ${GENERATED_UNITS_DIR}:"
find "${GENERATED_UNITS_DIR}" -type d -maxdepth 1 | sort

# Get a list of all unit directories
echo "Searching for FloatingPoint* directories..."
unit_dirs=$(find "${GENERATED_UNITS_DIR}" -type d -name "FloatingPoint*" | grep "noIO" | grep -E "Adder|Multiplier|Divider")
unit_count=$(echo "$unit_dirs" | grep -v "^$" | wc -l)

echo "Found $unit_count unit directories matching 'FloatingPoint*' pattern."
echo "Unit directories found:"
echo "$unit_dirs"

if [ $unit_count -eq 0 ]; then
    echo "ERROR: No floating point unit directories found! Check directory naming."
    exit 1
fi

# Create the CSV header with new max_latency and real delay fields
csv_file="../vivado_reports/vivado_results.csv"
echo "Operator,Bitwidth,Frequency_MHz,clock_period,Converters,Slack_ns,LUTs,Registers,DSPs,BRAMs,SRLs,max_latency,Real_Required_Clock_Period_ns" > $csv_file
echo "Created CSV report file: $csv_file"

# Function to extract maximum pipeline depth from operator.vhd
extract_max_pipeline_depth() {
    local vhd_file="$1"
    local max_depth=0
    
    echo "    Extracting pipeline depths from: $vhd_file" >&2
    
    # Find all lines containing "Pipeline depth:" and extract the numeric values
    while IFS= read -r line; do
        if [[ $line =~ --[[:space:]]*Pipeline[[:space:]]+depth:[[:space:]]*([0-9]+)[[:space:]]*cycles? ]]; then
            depth="${BASH_REMATCH[1]}"
            echo "    Found pipeline depth: $depth cycles" >&2
            if [ "$depth" -gt "$max_depth" ]; then
                max_depth="$depth"
            fi
        fi
    done < "$vhd_file"
    
    echo "    Maximum pipeline depth found: $max_depth cycles" >&2
    echo "$max_depth"
}

# Process each unit directory
unit_index=1
echo "$unit_dirs" | while read unit_dir; do
    # Skip empty lines
    if [ -z "$unit_dir" ]; then
        continue
    fi
    
    # Extract directory name and parse components
    dir_name=$(basename "$unit_dir")
    echo "[$unit_index/$unit_count] Processing directory: $dir_name (Full path: $unit_dir)"
    
    # List files in the directory for debugging
    echo "  Files in directory:"
    ls -la "$unit_dir"
    
    # Parse directory name to extract information
    if [[ $dir_name =~ FloatingPoint([A-Za-z]+)_([0-9]+)_([0-9]+)_([A-Za-z]+) ]]; then
        operator="${BASH_REMATCH[1]}"
        bitwidth="${BASH_REMATCH[2]}"
        frequency="${BASH_REMATCH[3]}"
        converters="${BASH_REMATCH[4]}"
        
        echo "  Extracted info: Operator=$operator, Bitwidth=$bitwidth, Frequency=${frequency}MHz, Converters=$converters"
        
        # Calculate clock period from frequency
        clock_period=$(bc -l <<< "1000/$frequency")
        echo "  Clock period: $clock_period ns"
        
        # Determine top module name based on operator
        case "$operator" in
            Adder)
                top_module="fadd_op"
                ;;
            Multiplier)
                top_module="fmul_op"
                ;;
            Divider)
                top_module="fdiv_op"
                ;;
            *)
                echo "  Skipping unknown operator type: $operator"
                continue
                ;;
        esac
        
        echo "  Using top module: $top_module"
        
        # Check if required files exist
        if [[ ! -f "$unit_dir/operator.vhd" || ! -f "$unit_dir/wrapper.vhd" ]]; then
            echo "  ERROR: Required VHDL files not found in $unit_dir"
            echo "  Files present in directory:"
            ls -la "$unit_dir"
            continue
        fi
        
        # Extract maximum pipeline depth from operator.vhd
        echo "  Extracting pipeline depth information..."
        max_latency=$(extract_max_pipeline_depth "$unit_dir/operator.vhd")
        echo "  Maximum latency found: $max_latency cycles"
        
        # Run Vivado with the appropriate environment variables
        echo "  Running Vivado synthesis and implementation..."
        export UNIT_NAME=$top_module
        export CLOCK_PERIOD=$clock_period
        export UNIT_DIR=$unit_dir
        export REPORT_DIR="${SCRIPT_DIR}/../vivado_reports"
        
        # Change to scripts directory to run Vivado
        pushd "${SCRIPT_DIR}/scripts" > /dev/null
        echo "  Running Vivado from: $(pwd)"
        echo "  Command: vitis-2023.2 vivado -mode batch -source operator_vivado.tcl"
        vitis-2023.2 vivado -mode batch -source operator_vivado.tcl
        popd > /dev/null
        
        # Check if report files exist
        util_report="../vivado_reports/utilization/${top_module}_${operator}_${frequency}MHz_${converters}.rpt"
        timing_report="../vivado_reports/timing/${top_module}_${operator}_${frequency}MHz_${converters}.rpt"
        
        if [[ ! -f "$util_report" || ! -f "$timing_report" ]]; then
            echo "  WARNING: Expected report files not found!"
            echo "  Utilization report should be: $util_report"
            echo "  Timing report should be: $timing_report"
            continue
        fi
        
        # Extract data for CSV
        echo "  Extracting report data for CSV..."
        
        # Extract slack from the timing file
        slack=$(grep -A 2 "Slack " "$timing_report" | grep -oP "\-?[0-9]+\.[0-9]+" | head -1)
        if [ -z "$slack" ]; then
            slack=$(grep -A 2 "Slack:" "$timing_report" | grep -oP "\-?[0-9]+\.[0-9]+" | head -1)
        fi
        
        # Extract area information from utilization file
        luts=$(grep -A 5 "CLB Logic" "$util_report" | grep "LUT as Logic" | grep -oP "[0-9]+" | head -1)
        regs=$(grep -A 3 "Register as" "$util_report" | grep "Register as Flip Flop" | grep -oP "[0-9]+" | head -1)
        dsps=$(grep -A 2 "DSP" "$util_report" | grep "DSPs" | grep -oP "[0-9]+" | head -1)
        brams=$(grep -A 2 "BLOCKRAM" "$util_report" | grep "Block RAM Tile" | grep -oP "[0-9]+" | head -1)
        srls=$(grep "LUT as Memory" "$util_report" | grep -oP "[0-9]+" | head -1)
        
        # Set defaults for empty values
        [ -z "$luts" ] && luts=0
        [ -z "$regs" ] && regs=0
        [ -z "$dsps" ] && dsps=0
        [ -z "$brams" ] && brams=0
        [ -z "$srls" ] && srls=0
        [ -z "$max_latency" ] && max_latency=0
        [ -z "$slack" ] && slack=0
        
        # Calculate real required clock period
        # Real period = clock_period - slack
        if [ -n "$slack" ] && [ -n "$clock_period" ]; then
            real_required_period=$(echo "$clock_period - ($slack)" | bc -l)
        else
            real_required_period="N/A"
        fi
        echo "  Real required clock period: $real_required_period ns (clock_period: $clock_period ns - slack: $slack ns)"
        
        # Add to CSV with new max_latency and real delay fields
        echo "$operator,$bitwidth,$frequency,$clock_period,$converters,$slack,$luts,$regs,$dsps,$brams,$srls,$max_latency,$real_required_period" >> $csv_file
        echo "  Data added to CSV report (max_latency: $max_latency cycles, real_required_period: $real_required_period ns)"
    else
        echo "  ERROR: Could not parse directory name format: $dir_name"
    fi
    
    unit_index=$((unit_index + 1))
    echo "----------------------------------------"
done

echo "All processing complete. Results saved to ../vivado_reports/"
```

### 2. `operator_vivado.tcl`

```tcl
# Updated operator_vivado.tcl - Works with vivado_units directory structure

# Get environment variables
set unit_name $env(UNIT_NAME)
set clock_period $env(CLOCK_PERIOD)
set unit_dir $env(UNIT_DIR)
set report_dir $env(REPORT_DIR)

# Extract operator type from directory name
set dir_name [file tail $unit_dir]
puts "Processing directory: $dir_name"

if {[regexp {FloatingPoint([A-Za-z]+)_([0-9]+)_([0-9]+)_([A-Za-z]+)} $dir_name -> operator bitwidth frequency converters]} {
    puts "Extracted info:"
    puts "  Operator: $operator"
    puts "  Bitwidth: $bitwidth"
    puts "  Frequency: ${frequency}MHz"
    puts "  Converters: $converters"
} else {
    puts "ERROR: Could not parse directory name format: $dir_name"
    exit 1
}

# Create report directories if they don't exist
file mkdir $report_dir/utilization
file mkdir $report_dir/timing

puts "Top module: $unit_name"
puts "Clock period: $clock_period ns"

# First, read all dependency files
puts "Reading dependency files from ./dependencies directory..."
set dependency_dir "../dependencies"
if {[file exists $dependency_dir]} {
    set dependency_files [glob -nocomplain "$dependency_dir/*.vhd"]
    if {[llength $dependency_files] > 0} {
        puts "Found [llength $dependency_files] dependency files"
        foreach dep_file $dependency_files {
            puts "Reading dependency file: $dep_file"
            read_vhdl -vhdl2008 $dep_file
        }
    } else {
        puts "WARNING: No dependency files found in $dependency_dir"
    }
} else {
    puts "WARNING: Dependencies directory not found: $dependency_dir"
}

# Then read the unit VHDL files
puts "Reading VHDL files from: $unit_dir"
set vhdl_files [list]
lappend vhdl_files "$unit_dir/operator.vhd"
lappend vhdl_files "$unit_dir/wrapper.vhd"
puts "VHDL files to process: $vhdl_files"

# Read VHDL files
foreach vhdl_file $vhdl_files {
    puts "Reading VHDL file: $vhdl_file"
    read_vhdl -vhdl2008 $vhdl_file
}

# Synthesize the design with the selected unit as the top-level module
puts "Synthesizing design with top module: $unit_name"
synth_design -top $unit_name -part xc7k160tfbg484-1 -no_iobuf -mode out_of_context

# Create the clock constraint
puts "Creating clock constraint with period: $clock_period ns"
create_clock -name clk -period $clock_period [get_ports clk]

# Set the clock source
puts "Setting clock source properties"
set_property HD.CLK_SRC BUFGCTRL_X0Y0 [get_ports clk]

# Run optimization, placement, and routing
puts "Running optimization..."
opt_design
puts "Running placement..."
place_design
puts "Running routing..."
route_design

# Generate reports
set util_report_path "$report_dir/utilization/${unit_name}_${operator}_${frequency}MHz_${converters}.rpt"
set timing_report_path "$report_dir/timing/${unit_name}_${operator}_${frequency}MHz_${converters}.rpt"

puts "Generating utilization report: $util_report_path"
report_utilization > $util_report_path
puts "Generating timing report: $timing_report_path"
report_timing > $timing_report_path

# Get WNS value from timing paths
set wns [get_property SLACK [get_timing_paths -max_paths 1 -nworst 1 -setup]]
puts "Worst Negative Slack (WNS): $wns ns"

# Append frequency information to the timing report
set timing_file [open $timing_report_path "a"]
puts $timing_file "\nClock Frequency: ${frequency} MHz"
puts $timing_file "Clock Period: ${clock_period} ns"
puts $timing_file "Worst Negative Slack (WNS): ${wns} ns"
close $timing_file

puts "Implementation complete for $unit_name ($operator ${frequency}MHz)"
```

### Summary of Changes
- The new scripts are designed to work with the `vivado_units` directory instead of `generated_units`.
- The CSV report file has been renamed to `vivado_results.csv` and is saved in the `vivado_reports` directory.
- The logic for processing and extracting information remains largely the same, ensuring that the functionality is preserved while adapting to the new directory structure.