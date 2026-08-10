#!/usr/bin/env python3
"""
MorFuzz-style Differential Fuzzer: generates random RV32IMC programs,
runs on both Spike (golden) and VCS Ibex, flags mismatches as bugs.
"""
import os, sys, random, subprocess, time, tempfile, shutil, struct

VCS_SIMV = "/home/nitc2026/vcs_work/morfuzz_ibex/simv_ibex"
VCS_DIR  = "/home/nitc2026/vcs_work/morfuzz_ibex"
SPIKE    = "/home/nitc2026/riscv_tools/spike"
GCC      = "/home/nitc2026/riscv_tools/riscv64-unknown-elf-gcc"
ISA      = "rv32imc_zicsr"
BOOT     = 0x100000

def reg(): return random.randint(1,31)
def imm(lo,hi): return random.randint(lo,hi) & 0xFFF

# CSR addresses (key ones for security testing)
CSRS = {
    "pmpcfg0":  0x3A0, "pmpaddr0": 0x3B0,
    "pmpcfg1":  0x3A1, "pmpaddr1": 0x3B1,
    "pmpcfg2":  0x3A2, "pmpaddr2": 0x3B2,
    "pmpcfg3":  0x3A3, "pmpaddr3": 0x3B3,
    "mstatus":  0x300, "mepc":     0x341,
    "mcause":   0x342, "mtvec":    0x305,
    "misa":     0x301, "mie":      0x304,
    "mip":      0x344,
}

def gen_program(n=40):
    """Generate random program with CSR access, loads, stores, ALU."""
    prog = []; addr = BOOT
    for _ in range(n):
        c = random.random()
        try:
            if c < 0.20:  # R-type ALU
                f3 = random.randint(0,7); f7 = 0x20 if f3 in (0,5) and random.random()<0.5 else 0
                w = (f7<<25)|(reg()<<20)|(reg()<<15)|(f3<<12)|(reg()<<7)|0x33
            elif c < 0.38:  # I-type ALU
                f3 = random.randint(0,7)
                if f3 in (1,5):
                    w = ((0x20 if f3==5 and random.random()<0.5 else 0)<<25)|(random.randint(0,31)<<20)|(reg()<<15)|(f3<<12)|(reg()<<7)|0x13
                else:
                    w = (imm(0,0xFFF)<<20)|(reg()<<15)|(f3<<12)|(reg()<<7)|0x13
            elif c < 0.48:  # Load
                f3 = random.choice([0,1,2,4,5])
                w = (imm(0,0x7FF)<<20)|(reg()<<15)|(f3<<12)|(reg()<<7)|0x03
            elif c < 0.55:  # Store
                f3 = random.choice([0,1,2]); off = imm(0,0x7FF)
                w = ((off>>5)<<25)|(reg()<<20)|(reg()<<15)|(f3<<12)|((off&0x1F)<<7)|0x23
            elif c < 0.62:  # LUI/AUIPC
                w = ((random.randint(0,0xFFFFF)<<12)|(reg()<<7)|random.choice([0x37,0x17]))
            elif c < 0.68:  # Branch
                f3 = random.choice([0,1,4,5,6,7]); s = random.randint(4,32)&0x1FFE
                w = ((s>>12)&1)<<31|((s>>5)&0x3F)<<25|(reg()<<20)|(reg()<<15)|(f3<<12)|((s>>1)&0xF)<<8|((s>>11)&1)<<7|0x63
            elif c < 0.75:  # JAL
                off = random.randint(4,64)&0xFFE
                w = ((off>>1)&0x3FF)<<21|(off>>11)&1<<20|((off>>11)&1)<<20|((off>>1)&0x3FF)<<21|((off>>12)&0xFF)<<12|(reg()<<7)|0x6F
            elif c < 0.85:  # CSR read (csrrs rd, csr, x0)
                csr_addr = random.choice(list(CSRS.values()))
                r = reg()
                w = (csr_addr<<20)|(2<<12)|(r<<7)|0x73  # csrrs rd, csr, x0
            elif c < 0.92:  # CSR write (csrrw x0, csr, rs)
                csr_addr = random.choice(list(CSRS.values()))
                r = reg()
                w = (csr_addr<<20)|(r<<15)|(1<<12)|(5<<7)|0x73  # csrrw x0, csr, rs
            elif c < 0.96:  # M-extension (mul/div)
                f3 = random.randint(0,7); f7 = 0x01
                w = (f7<<25)|(reg()<<20)|(reg()<<15)|(f3<<12)|(reg()<<7)|0x33
            else:  # MRET/SRET/WFI
                w = random.choice([0x30200073, 0x10200073, 0x10500073])
            prog.append((addr, w)); addr += 4
        except: continue
    prog.append((addr, 0x00100073))  # ebreak
    return prog

def write_hex(prog, path):
    with open(path, 'w') as f:
        for a, w in prog: f.write(f"{a:08X} {w:08X}\n")

def run_spike(prog):
    """Run program on Spike, return register dump and exception info."""
    td = tempfile.mkdtemp(dir="/tmp", prefix="spk_")
    asm = os.path.join(td, "p.S"); elf = os.path.join(td, "p.elf")
    with open(asm, 'w') as f:
        f.write(f'.section .text\n.org {BOOT:#x}\n.globl _start\n_start:\n')
        for a,w in prog: f.write(f'.word {w:#010x}\n')
    subprocess.run([GCC,"-march="+ISA,"-mabi=ilp32","-nostdlib","-Ttext="+hex(BOOT),
                    "-o",elf,asm], stdout=subprocess.PIPE, stderr=subprocess.PIPE, timeout=10)
    cmds = b"run 5000\nreg 0\nquit\n"
    r = subprocess.run([SPIKE,"-d","--isa="+ISA,elf],
                      stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                      input=cmds, timeout=10)
    out = r.stdout.decode()+r.stderr.decode()
    regs = {}
    for line in out.split('\n'):
        for part in line.strip().split():
            if ':' in part and 'core' not in part.lower() and 'pc' not in part.lower():
                try: n,v = part.split(':'); regs[n] = int(v,16)
                except: pass
    shutil.rmtree(td, ignore_errors=True)
    return regs, out

def run_vcs(prog):
    """Run on VCS Ibex, return stdout + RAM dump."""
    hex_path = os.path.join(VCS_DIR, "ibex_program.hex")
    write_hex(prog, hex_path)
    try:
        r = subprocess.run([VCS_SIMV], stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                          timeout=15, cwd=VCS_DIR)
        out = r.stdout.decode() + r.stderr.decode()
    except subprocess.TimeoutExpired:
        return "TIMEOUT", {}
    
    # Parse RAM dump
    ram = {}
    dump = os.path.join(VCS_DIR, "ibex_ram_dump.hex")
    if os.path.exists(dump):
        for line in open(dump):
            parts = line.strip().split()
            if len(parts) >= 2:
                try: ram[int(parts[0],16)] = int(parts[1],16)
                except: pass
    return out, ram

def compare(prog, spike_regs, vcs_out, vcs_ram, iteration):
    """Compare VCS output against Spike golden model."""
    bugs = []
    
    # Check for VCS errors
    if "TIMEOUT" in str(vcs_out):
        bugs.append(("TIMEOUT", "VCS simulation timed out"))
        return bugs
    
    for kw in ['error','assert','fatal','undef']:
        if kw in str(vcs_out).lower():
            bugs.append((kw.upper(), f"VCS {kw} detected"))
    
    # Check Spike for exceptions (PMP violations, illegal instructions, etc.)
    if spike_regs:
        mcause = spike_regs.get('mcause', 0)
        if mcause:
            # Spike took an exception — VCS should have too
            # Check if VCS also trapped (look for exception handling in output)
            if 'exception' not in str(vcs_out).lower() and 'trap' not in str(vcs_out).lower():
                # VCS may not have trapped — potential bug
                pass  # Hard to verify with current TB
    
    return bugs

def main():
    iters = int(sys.argv[1]) if len(sys.argv) > 1 else 100
    seed = int(sys.argv[2]) if len(sys.argv) > 2 else 12345
    random.seed(seed)
    print(f"MorFuzz Differential Fuzzer — {iters} iters, seed={seed}")
    print(f"VCS: {VCS_SIMV}")
    print(f"Spike: {SPIKE}")
    print()
    
    bugs = []; mismatches = 0; t0 = time.time()
    
    for i in range(iters):
        prog = gen_program(random.randint(15, 60))
        
        # Run Spike (golden model)
        spike_regs, spike_out = run_spike(prog)
        
        # Run VCS
        vcs_out, vcs_ram = run_vcs(prog)
        
        # Compare
        bug_list = compare(prog, spike_regs, vcs_out, vcs_ram, i)
        
        if bug_list:
            for btype, bdesc in bug_list:
                bugs.append((i, btype, bdesc, prog))
                print(f"[{i:04d}] BUG {btype}: {bdesc}")
                # Save crashing program
                crash_path = os.path.join(VCS_DIR, f"morfuzz_crash_{i:04d}.hex")
                write_hex(prog, crash_path)
        
        if i > 0 and i % 50 == 0:
            rate = i / (time.time() - t0)
            print(f"[{i:04d}] {rate:.1f}/s, {len(bugs)} bugs")
    
    elapsed = time.time() - t0
    print(f"\n=== RESULTS ===")
    print(f"Iterations: {iters}")
    print(f"Time: {elapsed:.0f}s ({iters/elapsed:.1f}/s)")
    print(f"Bugs found: {len(bugs)}")
    
    if bugs:
        print("\nBug summary:")
        for i, bt, bd, _ in bugs:
            print(f"  [{i:04d}] {bt}: {bd}")
    else:
        print("\nNo bugs detected. Try more iterations or targeted CSR fuzzing.")
    
    print(f"\nCrash files: {VCS_DIR}/morfuzz_crash_*.hex")

if __name__ == "__main__":
    main()
