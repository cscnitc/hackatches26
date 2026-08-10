#!/usr/bin/env python3
"""Minimal Ibex VCS Fuzzer — generates random programs, runs VCS, catches crashes."""
import os, sys, random, subprocess, time

VCS_SIMV = "/home/nitc2026/vcs_work/morfuzz_ibex/simv_ibex"
VCS_DIR  = "/home/nitc2026/vcs_work/morfuzz_ibex"
BOOT     = 0x100000

def reg(): return random.randint(1,31)
def imm12(): 
    v = random.choice([0,1,2,4,8,16,32,64,127,128,255,256,511,512,1023,1024,
                       2047,0x555,0xAAA,0xFFF,-1])
    return v & 0xFFF

def encode_r(opcode, rd, rs1, rs2, f3, f7):
    return (f7 << 25) | (rs2 << 20) | (rs1 << 15) | (f3 << 12) | (rd << 7) | opcode

def encode_i(opcode, rd, rs1, imm, f3):
    return ((imm & 0xFFF) << 20) | (rs1 << 15) | (f3 << 12) | (rd << 7) | opcode

def encode_u(opcode, rd, imm):
    return (imm & 0xFFFFF000) | (rd << 7) | opcode

def gen_program(n=30):
    prog = []
    addr = BOOT
    for _ in range(n):
        choice = random.random()
        try:
            if choice < 0.30:  # R-type ALU
                op = 0x33; f3 = random.randint(0,7)
                f7 = 0x20 if f3 in (0,5) and random.random()<0.5 else 0
                w = encode_r(op, reg(), reg(), reg(), f3, f7)
            elif choice < 0.55:  # I-type ALU
                op = 0x13; f3 = random.randint(0,7)
                if f3 in (1,5):  # shifts
                    shamt = random.randint(0,31)
                    f7 = 0x20 if f3==5 and random.random()<0.5 else 0
                    w = (f7<<25)|(shamt<<20)|(reg()<<15)|(f3<<12)|(reg()<<7)|op
                else:
                    w = encode_i(op, reg(), reg(), imm12(), f3)
            elif choice < 0.70:  # Load
                f3 = random.choice([0,1,2,4,5])
                w = encode_i(0x03, reg(), reg(), imm12()&0x7FF, f3)
            elif choice < 0.80:  # Store
                f3 = random.choice([0,1,2])
                off = imm12() & 0x7FF
                w = ((off>>5)<<25)|(reg()<<20)|(reg()<<15)|(f3<<12)|((off&0x1F)<<7)|0x23
            elif choice < 0.90:  # LUI/AUIPC
                op = random.choice([0x37, 0x17])
                w = encode_u(op, reg(), random.randint(0,0xFFFFF)<<12)
            elif choice < 0.95:  # Branch forward
                f3 = random.choice([0,1,4,5,6,7])
                skip = random.randint(4,32) & 0x1FFE
                w = ((skip>>12)&1)<<31|((skip>>5)&0x3F)<<25|(reg()<<20)|(reg()<<15)|(f3<<12)|((skip>>1)&0xF)<<8|((skip>>11)&1)<<7|0x63
            else:  # M-extension
                f3 = random.randint(0,7); f7 = 0x01
                w = encode_r(0x33, reg(), reg(), reg(), f3, f7)
            prog.append((addr, w)); addr += 4
        except: continue

    prog.append((addr, 0x00100073))  # ebreak
    return prog

def write_hex(prog, path):
    with open(path, 'w') as f:
        for a, w in prog:
            f.write(f"{a:08X} {w:08X}\n")

def run_vcs(prog, iteration):
    hex_path = os.path.join(VCS_DIR, "ibex_program.hex")
    write_hex(prog, hex_path)
    try:
        r = subprocess.run([VCS_SIMV], stdout=subprocess.PIPE, stderr=subprocess.PIPE, timeout=20, cwd=VCS_DIR)
        out = r.stdout.decode() + r.stderr.decode()
        crashes = [l.strip() for l in out.split('\n') if any(
            kw in l.lower() for kw in ['error','assert','fatal','timeout','undef'])]
        if crashes:
            p = os.path.join(VCS_DIR, f"crash_{iteration:04d}.hex")
            write_hex(prog, p)
            return True, crashes[:5], p
        return False, [], None
    except subprocess.TimeoutExpired:
        return True, ["TIMEOUT"], None
    except Exception as e:
        return True, [str(e)], None

def main():
    iters = int(sys.argv[1]) if len(sys.argv) > 1 else 100
    seed = int(sys.argv[2]) if len(sys.argv) > 2 else 42
    random.seed(seed)
    print(f"Ibex VCS Fuzzer — {iters} iters, seed={seed}")
    crashes = 0; t0 = time.time()
    for i in range(iters):
        prog = gen_program(random.randint(10,60))
        is_c, msgs, path = run_vcs(prog, i)
        if is_c:
            crashes += 1
            print(f"[{i:04d}] CRASH: {'; '.join(msgs[:3])}")
        elif i > 0 and i % 50 == 0:
            r = i/(time.time()-t0)
            print(f"[{i:04d}] {r:.1f} iter/s, {crashes} crashes")
    t = time.time()-t0
    print(f"\nDone: {iters} iters/{t:.0f}s ({iters/t:.1f}/s), {crashes} crashes")

if __name__ == "__main__":
    main()
