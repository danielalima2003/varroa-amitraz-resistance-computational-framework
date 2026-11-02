#!/bin/csh
# ==============================================================================
# Description: AMBER simulation pipeline (Minimization on CPU -> Equilibration/Production on CUDA)
# ==============================================================================

# --- CONFIGURATION ---
# Start with standard pmemd for stable minimization
set amber       = pmemd
set init        = step5_input
set mini_prefix = step6.0_minimization
set equi_prefix = step6.%d_equilibration
set prod_prefix = step7_production
set prod_step   = step7

echo "=================================================="
echo "Starting AMBER Simulation Pipeline"

# --- 1. MINIMIZATION (CPU) ---
echo "--- Phase 1: Minimization (using ${amber}) ---"

if (-e dihe.restraint) then
    sed -e "s/FC/250.0/g" dihe.restraint > ${mini_prefix}.rest
endif

set mini_prefix1 = step6.0_minimization1
${amber} -O -i ${mini_prefix1}.mdin -p ${init}.parm7 -c ${init}.rst7 -o ${mini_prefix1}.mdout -r ${mini_prefix1}.rst7 -inf ${mini_prefix1}.mdinfo -ref ${init}.rst7

set mini_prefix2 = step6.0_minimization2
${amber} -O -i ${mini_prefix2}.mdin -p ${init}.parm7 -c ${mini_prefix1}.rst7 -o ${mini_prefix2}.mdout -r ${mini_prefix2}.rst7 -inf ${mini_prefix2}.mdinfo -ref ${init}.rst7

${amber} -O -i ${mini_prefix2}.mdin -p ${init}.parm7 -c ${mini_prefix2}.rst7 -o ${mini_prefix}.mdout -r ${mini_prefix}.rst7 -inf ${mini_prefix}.mdinfo -ref ${init}.rst7
echo "Minimization completed successfully."


# --- SWITCH TO CUDA ---
echo "--- Switching execution engine to CUDA ---"
set amber = pmemd.cuda


# --- 2. EQUILIBRATION (GPU/CUDA) ---
echo "--- Phase 2: Equilibration Steps 1 to 6 (using ${amber}) ---"

set cnt = 1
set cntmax = 6
set fc = ('250.0' '100.0' '50.0' '50.0' '25.0')

while ( ${cnt} <= ${cntmax} )
    @ pcnt = ${cnt} - 1
    set istep = `printf ${equi_prefix} ${cnt}`
    set pstep = `printf ${equi_prefix} ${pcnt}`
    if ( ${cnt} == 1 ) set pstep = ${mini_prefix}

    if (-e dihe.restraint && ${cnt} < ${cntmax}) then
        sed -e "s/FC/${fc[${cnt}]}/g" dihe.restraint > ${istep}.rest
    endif
    
    echo "Running Equilibration Step ${cnt} of ${cntmax}..."
    ${amber} -O -i ${istep}.mdin -p ${init}.parm7 -c ${pstep}.rst7 -o ${istep}.mdout -r ${istep}.rst7 -inf ${istep}.mdinfo -ref ${init}.rst7 -x ${istep}.nc
    @ cnt += 1
end
echo "Equilibration completed successfully."


# --- 3. PRODUCTION (GPU/CUDA) ---
echo "--- Phase 3: Production Dynamics (using ${amber}) ---"

set cnt = 1
set cntmax = 15

while ( ${cnt} <= ${cntmax} )
    @ pcnt = ${cnt} - 1
    set istep = ${prod_step}_${cnt}
    set pstep = ${prod_step}_${pcnt}
    if ( ${cnt} == 1 ) set pstep = `printf ${equi_prefix} 6`

    echo "Running Production Run ${cnt} of ${cntmax}..."
    ${amber} -O -i ${prod_prefix}.mdin -p ${init}.parm7 -c ${pstep}.rst7 -o ${istep}.mdout -r ${istep}.rst7 -inf ${istep}.mdinfo -x ${istep}.nc
    @ cnt += 1
end

echo "=================================================="
echo "All simulation phases completed successfully!"
echo "=================================================="
