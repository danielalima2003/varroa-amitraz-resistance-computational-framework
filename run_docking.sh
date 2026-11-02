#!/usr/bin/env bash
# ==============================================================================
#  molecular docking pipeline using AutoDock Vina.
# ==============================================================================

# Exit immediately if a command exits with a non-zero status
set -euo pipefail

# --- CONFIGURATION & PATHS ---
OUTPUT_DIR="results/outputs"
LOG_DIR="results/logs"

# Grid Box Parameters (Update these for your specific binding site)
CENTER_X=15.652
CENTER_Y=-3.187
CENTER_Z=-7.756
SIZE_X=25
SIZE_Y=25
SIZE_Z=25

# Vina Search Parameters
EXHAUSTIVENESS=64
NUM_MODES=20
ENERGY_RANGE=5

# --- DEPENDENCY CHECK ---
if ! command -v vina &> /dev/null; then
    echo "Error: AutoDock Vina ('vina') is not installed or not in your PATH." >&2
    exit 1
fi

# --- CREATE DIRECTORIES ---
mkdir -p "$OUTPUT_DIR" "$LOG_DIR"

# --- DEFINE INPUT FILES ---
RECEPTORS=(
    "A0A7M7KR48_relax_CM_rosie_pyMOL.pdbqt"
    "87_new_relax_CM.pdbqt"
    "215_new_relax_CM.pdbqt"
    "290_new_relax_CM.pdbqt"
    "337_new_relax_CM.pdbqt"
)

LIGANDS=(
    "Amitraz_5000.pdbqt"
    "DPMF_5000.pdbqt"
    "Octopamine_5000.pdbqt"
)

# --- MAIN EXECUTION LOOP ---
total_runs=$(( ${#RECEPTORS[@]} * ${#LIGANDS[@]} ))
current_run=0

echo "=================================================="
echo "Starting Vina Batch Docking Pipeline"
echo "Total Receptors: ${#RECEPTORS[@]}"
echo "Total Ligands:   ${#LIGANDS[@]}"
echo "Total Combinations: $total_runs"
echo "=================================================="

for receptor in "${RECEPTORS[@]}"; do
    rec_name="${receptor%.pdbqt}"
    rec_path="$receptor"

    if [ ! -f "$rec_path" ]; then
        echo "Warning: Receptor file '$rec_path' not found. Skipping." >&2
        continue
    fi

    for ligand in "${LIGANDS[@]}"; do
        lig_name="${ligand%.pdbqt}"
        lig_path="$ligand"

        if [ ! -f "$lig_path" ]; then
            echo "Warning: Ligand file '$lig_path' not found. Skipping." >&2
            continue
        fi

        current_run=$((current_run + 1))
        config_file="config_${rec_name}_${lig_name}.txt"
        out_file="$OUTPUT_DIR/${rec_name}+${lig_name}_out.pdbqt"
        log_file="$LOG_DIR/${rec_name}+${lig_name}_log.txt"

        # Generate temporary config file dynamically
        cat <<EOF > "$config_file"
receptor = $rec_path
ligand = $lig_path

center_x = $CENTER_X
center_y = $CENTER_Y
center_z = $CENTER_Z

size_x = $SIZE_X
size_y = $SIZE_Y
size_z = $SIZE_Z

exhaustiveness = $EXHAUSTIVENESS
num_modes = $NUM_MODES
energy_range = $ENERGY_RANGE

out = $out_file
EOF

        echo "--------------------------------------------------"
        echo "[$current_run/$total_runs] Running: $rec_name vs $lig_name"
        echo "--------------------------------------------------"

        # Execute AutoDock Vina and capture output via tee
        vina --config "$config_file" | tee "$log_file"

        # Cleanup temporary config file
        rm -f "$config_file"

    done
done

echo "=================================================="
echo "Done! All docking combinations finished successfully."
echo "Outputs stored in: $OUTPUT_DIR/"
echo "Logs stored in:    $LOG_DIR/"
echo "=================================================="