#!/usr/bin/env python3
"""VCS Fuzzer for OpenTitan — uses Synopsys VCS to fuzz RTL modules"""
import os, sys, random, subprocess, time

VCS_WORK = os.path.expanduser("~/vcs_work")
BIN = os.path.join(VCS_WORK, "bin/g++44")
ENV = {"PATH": f"/home/synopsys/tools/verdi_supp/U-2023.03-SP1/bin:{os.environ.get('PATH','')}",
       "HOME": os.path.expanduser("~")}

def run_vcs_sim(sim_bin, input_data, timeout=10):
    """Run a single VCS simulation with given input"""
    with open("/tmp/fuzz_input.bin", "wb") as f:
        f.write(input_data)
    try:
        result = subprocess.run([sim_bin], cwd="/tmp", env=ENV,
                              capture_output=True, text=True, timeout=timeout)
        return result.stdout + result.stderr
    except subprocess.TimeoutExpired:
        return "TIMEOUT"
    except Exception as e:
        return f"ERROR: {e}"

def generate_pmp_input():
    """Generate a random PMP configuration"""
    data = bytearray(random.getrandbits(8) for _ in range(64))
    # Bias toward interesting configurations
    if random.random() < 0.3:
        data[0] = 0x28  # TOR, locked, no perms
        data[4] = random.randint(0, 255)  # random addr bits
    return bytes(data)

def main():
    bugs = {"001": 0, "002": 0}
    iterations = 10000
    
    print("=" * 50)
    print("VCS Fuzzer for OpenTitan")
    print("=" * 50)
    
    # Use existing VCS sim binary from previous build
    sim_bug01 = f"{VCS_WORK}/results/sim_bug03"  # use existing binary
    
    if not os.path.exists(sim_bug01):
        # Try other existing sims
        for b in ["sim_bug03", "sim_bug06", "sim_bug08"]:
            p = f"{VCS_WORK}/results/{b}"
            if os.path.exists(p):
                sim_bug01 = p
                break
    
    if not os.path.exists(sim_bug01):
        print(f"No VCS sim binary found at {sim_bug01}")
        print("Available:", os.listdir(f"{VCS_WORK}/results/")[:10])
        return
    
    print(f"Using sim binary: {sim_bug01}")
    print(f"Running {iterations} fuzz iterations...")
    
    start = time.time()
    for i in range(iterations):
        inp = generate_pmp_input()
        out = run_vcs_sim(sim_bug01, inp)
        
        if "BUG" in out or "CRASH" in out or "CONFIRMED" in out:
            bugs["001"] += 1
            print(f"[{i}] BUG DETECTED! ({bugs['001']} total)")
        
        if i % 1000 == 0 and i > 0:
            elapsed = time.time() - start
            rate = i / elapsed
            print(f"[{i}/{iterations}] {rate:.0f} iter/sec, {bugs['001']} bugs")
    
    elapsed = time.time() - start
    print(f"\nDone: {iterations} iterations in {elapsed:.1f}s ({iterations/elapsed:.0f}/s)")
    print(f"Bugs found: {bugs['001']}")

if __name__ == "__main__":
    main()
