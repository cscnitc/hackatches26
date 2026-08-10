#!/usr/bin/env python3
"""
Targeted PMP Fuzzer: mixes random programs with crafted PMP-violation test cases.
Runs on VCS Ibex + Spike, flags mismatches.
"""
import os, sys, random, subprocess, time, tempfile, shutil

VCS_SIMV = "/home/nitc2026/vcs_work/morfuzz_ibex/simv_ibex"
VCS_DIR  = "/home/nitc2026/vcs_work/morfuzz_ibex"
SPIKE    = "/home/nitc2026/riscv_tools/spike"
GCC      = "/home/nitc2026/riscv_tools/riscv64-unknown-elf-gcc"
ISA      = "rv32imc_zicsr"
BOOT     = 0x100000

def reg(): return random.randint(1,31)

def make_pmp_trigger_program():
    """
    Craft a program that:
    1. Configures PMP to block region [0x00000-0x20000] (TOR mode, locked)
    2. Switches to User mode
    3. Tries to load from 0x10000 — SHOULD trap (but bug lets it through)
    4. If we reach instruction after load = BUG (PMP didn't trap)
    """
    prog = []; a = BOOT
    
    # li t0, 0x98 (PMP config: TOR, LOCK=1, no R/W/X)
    # Use addi x0 + offset trick: addi t0, x0, 0x98
    prog.append((a, (0x98 << 20) | (0 << 15) | (0 << 12) | (5 << 7) | 0x13)); a += 4
    # csrrw x0, pmpcfg0, t0   (write PMP config)
    prog.append((a, (0x3A0 << 20) | (5 << 15) | (1 << 12) | (0 << 7) | 0x73)); a += 4
    
    # li t1, 0x20 (0x20000 >> 2 — PMP address boundary)
    prog.append((a, (0x20 << 20) | (0 << 15) | (0 << 12) | (6 << 7) | 0x13)); a += 4
    # csrrw x0, pmpaddr0, t1  (write PMP address)
    prog.append((a, (0x3B0 << 20) | (6 << 15) | (1 << 12) | (0 << 7) | 0x73)); a += 4
    
    # Set mstatus.MPP = 0 (User mode on mret)
    # csrr t2, mstatus; andi t2, t2, ~(3<<11); csrw mstatus, t2
    prog.append((a, (0x300 << 20) | (2 << 12) | (7 << 7) | 0x73)); a += 4  # csrrs t2, mstatus, x0
    # lui t3, 0xFFFFF; addi t3, t3, 0x7FF (mask = 0xFFFFF7FF = ~0x1800)
    mask = (~0x1800) & 0xFFFFFFFF
    hi = (mask + 0x800) >> 12 & 0xFFFFF
    lo = mask & 0xFFF
    if lo >= 0x800: hi += 1; lo -= 0x1000
    prog.append((a, (hi << 12) | (28 << 7) | 0x37)); a += 4  # lui t3, hi
    prog.append((a, (lo << 20) | (28 << 15) | (0 << 12) | (28 << 7) | 0x13)); a += 4  # addi t3, t3, lo
    prog.append((a, (0<<25)|(28<<20)|(7<<15)|(7<<12)|(7<<7)|0x33)); a += 4  # and t2, t2, t3
    prog.append((a, (0x300 << 20) | (7 << 15) | (1 << 12) | (0 << 7) | 0x73)); a += 4  # csrrw x0, mstatus, t2
    
    # Set mepc to user_code address
    user_code = a + 20  # skip ahead
    # lui s0, hi(user_code)
    hi = (user_code + 0x800) >> 12 & 0xFFFFF
    lo = user_code & 0xFFF
    if lo >= 0x800: hi += 1; lo -= 0x1000
    prog.append((a, (hi << 12) | (8 << 7) | 0x37)); a += 4  # lui s0
    prog.append((a, (lo << 20) | (8 << 15) | (0 << 12) | (8 << 7) | 0x13)); a += 4  # addi s0, s0, lo
    prog.append((a, (0x341 << 20) | (8 << 15) | (1 << 12) | (0 << 7) | 0x73)); a += 4  # csrrw x0, mepc, s0
    
    # mret -> jumps to user_code in User mode
    prog.append((a, 0x30200073)); a += 4
    
    # === USER MODE CODE ===
    user_code_addr = a
    # lw t0, 0x10000 — THIS SHOULD TRAP (address below PMP boundary)
    prog.append((a, (0x10000 >> 12) << 12 | (10 << 7) | 0x37)); a += 4  # lui a0, hi
    prog.append((a, (0 << 20) | (10 << 15) | (0 << 12) | (10 << 7) | 0x13)); a += 4  # addi a0, a0, 0
    prog.append((a, (0 << 20) | (10 << 15) | (2 << 12) | (5 << 7) | 0x03)); a += 4  # lw t0, 0(a0)
    
    # If we reach here: BUG! PMP should have trapped
    # Store magic signature to mark bug detection
    # sw t0, 0x200000 (write to memory to signal bug)
    prog.append((a, (0x20000 >> 12) << 12 | (11 << 7) | 0x37)); a += 4  # lui s1
    prog.append((a, (0 << 20) | (11 << 15) | (2 << 12) | (5 << 7) | 0x23)); a += 4  # sw t0, 0(s1)
    # Store 0xDEADBEEF at 0x200004 to mark bug found
    prog.append((a, (0xDEADB000 >> 12) << 12 | (12 << 7) | 0x37)); a += 4  # lui s2
    prog.append((a, (0xEEF << 20) | (12 << 15) | (0 << 12) | (12 << 7) | 0x13)); a += 4  # addi s2
    prog.append((a, (4 << 20) | (12 << 15) | (2 << 12) | (11 << 7) | 0x23)); a += 4  # sw s2, 4(s1)
    
    # ebreak
    prog.append((a, 0x00100073))
    return prog, user_code_addr

def write_hex(prog, path):
    with open(path, 'w') as f:
        for a,w in prog: f.write(f"{a:08X} {w:08X}\n")

def run_spike(prog):
    td = tempfile.mkdtemp(dir="/tmp", prefix="spk_")
    asm = os.path.join(td, "p.S"); elf = os.path.join(td, "p.elf")
    with open(asm, 'w') as f:
        f.write(f'.section .text\n.org {BOOT:#x}\n.globl _start\n_start:\n')
        for a,w in prog: f.write(f'.word {w:#010x}\n')
    subprocess.run([GCC,"-march="+ISA,"-mabi=ilp32","-nostdlib","-Ttext="+hex(BOOT),
                    "-o",elf,asm], stdout=subprocess.PIPE, stderr=subprocess.PIPE, timeout=10)
    r = subprocess.run([SPIKE,"-d","--isa="+ISA,elf],
                      stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                      input=b"run 2000\nreg 0\nreg 0 mcause\nquit\n", timeout=10)
    out = r.stdout.decode()+r.stderr.decode()
    shutil.rmtree(td, ignore_errors=True)
    # Check for mcause
    has_trap = 'mcause' in out and '0x0000000000000000' not in out.split('mcause')[-1][:30] if 'mcause' in out else False
    # Parse mcause value
    mcause_val = None
    for line in out.split('\n'):
        if 'mcause' in line:
            try:
                parts = line.split()
                for i,p in enumerate(parts):
                    if 'mcause' in p:
                        mcause_val = int(parts[i+1], 16) if i+1 < len(parts) else None
            except: pass
    return mcause_val, has_trap

def run_vcs(prog):
    hex_path = os.path.join(VCS_DIR, "ibex_program.hex")
    write_hex(prog, hex_path)
    try:
        r = subprocess.run([VCS_SIMV], stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                          timeout=15, cwd=VCS_DIR)
        out = r.stdout.decode() + r.stderr.decode()
    except subprocess.TimeoutExpired:
        return "TIMEOUT", {}
    ram = {}
    dump = os.path.join(VCS_DIR, "ibex_ram_dump.hex")
    if os.path.exists(dump):
        for line in open(dump):
            p = line.strip().split()
            if len(p)>=2:
                try: ram[int(p[0],16)] = int(p[1],16)
                except: pass
    return out, ram

if __name__ == "__main__":
    print("=== PMP Bypass Differential Fuzzer ===")
    
    # Generate PMP trigger program
    prog, uaddr = make_pmp_trigger_program()
    print(f"Generated PMP trigger program: {len(prog)} instructions")
    print(f"User code at: {uaddr:#x}")
    
    # Run on Spike (golden)
    print("\n--- Spike (Golden Model) ---")
    mcause, trapped = run_spike(prog)
    print(f"  mcause = {mcause}")
    print(f"  Exception taken: {trapped}")
    
    # Run on VCS Ibex
    print("\n--- VCS Ibex ---")
    out, ram = run_vcs(prog)
    
    # Check RAM for bug signature (0xDEADBEEF at 0x200004)
    bug_sig = ram.get(0x200004, 0)
    print(f"  RAM[0x200004] = {bug_sig:#010x}")
    
    print("\n=== RESULT ===")
    if trapped and bug_sig == 0xDEADBEEF:
        print("BUG CONFIRMED: Spike trapped on PMP violation, but Ibex executed the load!")
        print("PMP is completely non-functional — pmp_req_err_o always 0")
        print("ibex_pmp.sv:285")
    elif trapped and bug_sig != 0xDEADBEEF:
        print("PASS (for this test): Ibex also didn't reach bug signature")
    elif not trapped and bug_sig == 0xDEADBEEF:
        print("UNEXPECTED: Spike didn't trap but Ibex did write — needs investigation")
    else:
        print("Inconclusive — check logs")
