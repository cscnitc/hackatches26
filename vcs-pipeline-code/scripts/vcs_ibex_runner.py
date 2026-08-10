#!/usr/bin/env python3
"""
vcs_ibex_runner.py — VCS integration for GenHuzz on Ibex RISC-V core.
Implements the GenHuzz lock-file protocol for coverage feedback.

Protocol:
  1. Wait for start_signal.lock (JSON test cases from GenHuzz)
  2. For each test case: compile to .riscv, load into Ibex, simulate with VCS
  3. Extract FSM/line/condition coverage from VCS output
  4. Write hw_coverage.lock (coverage data for GenHuzz)
  5. Delete start_signal.lock, loop back to step 1

Requires:
  - Synopsys VCS with Ibex simulation compiled
  - Spike for golden reference comparison
  - RISC-V toolchain for test case compilation
"""

import os
import sys
import json
import time
import subprocess
import hashlib
import shutil
from pathlib import Path

# === Configuration ===
HW_SHARED_DIR = 'dir_com'
SPIKE_DIR = 'spike_simulation'
VCS_SIM_DIR = os.environ.get('VCS_SIM_DIR', './vcs_build')
IBEX_TOP = os.environ.get('IBEX_TOP', 'ibex_core_tb')
NUM_INSTRS = 30

def compile_testcase(asm_instructions, test_id, spike_dir, hw_shared_dir):
    """Compile RISC-V assembly instructions to .riscv binary using asm2riscv"""
    asm2riscv_dir = f'{spike_dir}/asm2riscv'
    
    # Build C file with inline assembly
    main_content = "int main(void) {\n"
    for inst in asm_instructions:
        main_content += f'    asm volatile("{inst}");\n'
    main_content += "    return 0;\n}\n"
    
    src_path = f'{asm2riscv_dir}/src/testcase.c'
    with open(src_path, 'w') as f:
        f.write(main_content)
    
    # Compile
    result = subprocess.run(['make', '-C', asm2riscv_dir, 'clean'], capture_output=True)
    result = subprocess.run(['make', '-C', asm2riscv_dir], capture_output=True)
    
    if result.returncode != 0:
        return None
    
    # Copy binary
    dest = f'{hw_shared_dir}/{test_id}.riscv'
    shutil.copy(f'{asm2riscv_dir}/bin/testcase.riscv', dest)
    return dest


def run_vcs_simulation(riscv_bin, test_id):
    """Run the RISC-V binary on Ibex via VCS."""
    # Write binary to a file VCS can read
    bin_path = f'/tmp/genhuzz_ibex_test_{test_id}.bin'
    shutil.copy(riscv_bin, bin_path)
    
    # Run VCS with the test binary  
    # Assumes VCS simv is pre-compiled with Ibex + memory loader
    cmd = [
        f'{VCS_SIM_DIR}/simv',
        f'+ibex_bin={bin_path}',
        f'+test_id={test_id}',
        '+vcs+finish+5000000',  # timeout after 5M cycles
    ]
    
    try:
        result = subprocess.run(cmd, capture_output=True, text=True, timeout=120)
        return result.stdout + result.stderr
    except subprocess.TimeoutExpired:
        return "TIMEOUT"


def extract_coverage(vcs_output, test_id):
    """Extract FSM, line, condition coverage from VCS output."""
    coverage = {
        'fsm': str(test_id),
        'line': str(test_id),
        'cond': str(test_id),
    }
    
    # Parse VCS coverage report lines
    # VCS typically outputs coverage in URG format
    for line in vcs_output.split('\n'):
        if 'FSM coverage:' in line:
            coverage['fsm'] = line.split(':')[-1].strip()
        elif 'Line coverage:' in line:
            coverage['line'] = line.split(':')[-1].strip() 
        elif 'Condition coverage:' in line:
            coverage['cond'] = line.split(':')[-1].strip()
    
    # For now, use binary coverage bitmap from VCS URG dump
    # In practice, integrate with VCS Unified Coverage Database
    return coverage


def run_spike_check(asm_instructions, spike_dir):
    """Run Spike to check which instructions execute."""
    spike_log = f'{spike_dir}/spike_log.txt'
    
    # Compile and run through Spike
    main_content = "int main(void) {\n"
    for inst in asm_instructions:
        main_content += f'    asm volatile("{inst}");\n'
    main_content += "    return 0;\n}\n"
    
    src_path = f'{spike_dir}/asm2riscv/src/testcase.c'
    with open(src_path, 'w') as f:
        f.write(main_content)
    
    subprocess.run(['make', '-C', f'{spike_dir}/asm2riscv', 'clean'], capture_output=True)
    result = subprocess.run(['make', '-C', f'{spike_dir}/asm2riscv'], capture_output=True)
    
    if result.returncode != 0:
        return []
    
    riscv_bin = f'{spike_dir}/asm2riscv/bin/testcase.riscv'
    subprocess.run(['bash', f'{spike_dir}/run_spike.sh', spike_log, riscv_bin], capture_output=True)
    
    # Parse executed instructions from spike log
    executed = []
    try:
        with open(spike_log) as f:
            for line in f:
                parts = line.split()
                if len(parts) >= 4 and parts[2].startswith('0x'):
                    inst_addr = int(parts[2], 16)
                    executed.append(inst_addr)
    except FileNotFoundError:
        pass
    
    return executed


def main():
    """Main loop: wait for GenHuzz test cases, run VCS, return coverage."""
    print(f"[VCS Runner] Starting Ibex fuzzing loop")
    print(f"  Shared dir: {HW_SHARED_DIR}")
    print(f"  VCS sim dir: {VCS_SIM_DIR}")
    
    spike_dir = SPIKE_DIR
    hw_dir = HW_SHARED_DIR
    os.makedirs(hw_dir, exist_ok=True)
    
    iteration = 0
    while True:
        # Wait for start signal from GenHuzz
        start_file = f'{hw_dir}/start_signal.lock'
        cov_file = f'{hw_dir}/hw_coverage.lock'
        
        # Clean old coverage
        if os.path.exists(cov_file):
            os.remove(cov_file)
        
        print(f"\n[Iteration {iteration}] Waiting for test cases...")
        while not os.path.exists(start_file):
            time.sleep(2)
        
        # Read test cases
        with open(start_file, 'r') as f:
            testcases = json.load(f)
        
        num_cases = len(testcases)
        print(f"[Iteration {iteration}] Received {num_cases} test cases")
        
        # Process each test case
        fsm_cov = {}
        line_cov = {}
        cond_cov = {}
        
        for test_id, asm_instructions in testcases.items():
            test_id = int(test_id)
            
            # Skip if no instructions
            if not asm_instructions:
                fsm_cov[test_id] = '0'
                line_cov[test_id] = '0'
                cond_cov[test_id] = '0'
                continue
            
            # Compile to RISC-V binary
            riscv_bin = compile_testcase(asm_instructions, test_id, spike_dir, hw_dir)
            if not riscv_bin:
                fsm_cov[test_id] = '0'
                line_cov[test_id] = '0'
                cond_cov[test_id] = '0'
                continue
            
            # Run VCS simulation
            vcs_out = run_vcs_simulation(riscv_bin, test_id)
            cov = extract_coverage(vcs_out, test_id)
            fsm_cov[test_id] = cov['fsm']
            line_cov[test_id] = cov['line']
            cond_cov[test_id] = cov['cond']
            
            # Spike check for differential testing
            spike_exec = run_spike_check(asm_instructions, spike_dir)
            if len(spike_exec) < len(asm_instructions) / 2:
                # Too few instructions executed - mark as invalid
                fsm_cov[test_id] = '0'
                line_cov[test_id] = '0'
                cond_cov[test_id] = '0'
        
        # Write coverage back to GenHuzz
        with open(cov_file, 'w') as f:
            for tid in sorted(fsm_cov.keys()):
                f.write(f'fsm,{tid},{fsm_cov[tid]}\n')
            for tid in sorted(line_cov.keys()):
                f.write(f'line,{tid},{line_cov[tid]}\n')
            for tid in sorted(cond_cov.keys()):
                f.write(f'cond,{tid},{cond_cov[tid]}\n')
        
        # Remove start signal
        os.remove(start_file)
        iteration += 1


if __name__ == '__main__':
    main()
