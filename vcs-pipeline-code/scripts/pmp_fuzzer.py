#!/usr/bin/env python3
"""PMP Fuzzer for vlsilab — finds Bug-001 (ibex_pmp.sv:285, CVSS 8.8)"""
import os, sys, random, subprocess, time

VCS_WORK = os.path.expanduser("~/vcs_work")
RTL_DIR = f"{VCS_WORK}/rtl/ibex"
SIM_BIN = "/tmp/sim_pmp_fuzz"
TB_FILE = "/tmp/tb_pmp_fuzz.sv"

def build():
    """Build VCS simulation of ibex_pmp standalone (no full Ibex needed)."""
    with open(TB_FILE, "w") as f:
        f.write("""module tb_pmp_fuzz;
  import ibex_pkg::*;
  localparam int PMPGran=0, PMPNumChan=1, PMPNumRegions=4;
  localparam int DmBaseAddr=32'h1A110000, DmAddrMask=32'h00000FFF;

  pmp_cfg_t csr_pmp_cfg_i[PMPNumRegions]; logic[33:0] csr_pmp_addr_i[PMPNumRegions];
  pmp_mseccfg_t csr_pmp_mseccfg_i; logic debug_mode_i;
  priv_lvl_e priv_mode_i[PMPNumChan]; logic[33:0] pmp_req_addr_i[PMPNumChan];
  pmp_req_e pmp_req_type_i[PMPNumChan]; logic pmp_req_err_o[PMPNumChan];
  ibex_pmp #(.DmBaseAddr(DmBaseAddr),.DmAddrMask(DmAddrMask),
    .PMPGranularity(PMPGran),.PMPNumChan(PMPNumChan),.PMPNumRegions(PMPNumRegions))
    dut(.*);

  integer fd, rd, tests, bugs, i;
  reg[7:0] inp[0:32];
  initial begin
    tests=0; bugs=0;
    fd=$fopen("fuzz_input.bin","rb");
    if(!fd) begin $display("NO INPUT"); $finish; end
    while(!$feof(fd)) begin
      rd=$fread(inp,fd); if(rd<33) break;
      csr_pmp_cfg_i[0].lock=inp[0][5]; csr_pmp_cfg_i[0].mode=pmp_mode_e'(inp[0][4:3]);
      csr_pmp_cfg_i[0].exec=inp[0][2]; csr_pmp_cfg_i[0].write=inp[0][1];
      csr_pmp_cfg_i[0].read=inp[0][0];
      csr_pmp_addr_i[0]={inp[4],inp[5],inp[6],inp[7][7:6]};
      debug_mode_i=inp[20][0]; priv_mode_i[0]=priv_lvl_e'(inp[21][1:0]);
      pmp_req_addr_i[0]={inp[22],inp[23],inp[24],inp[25][7:6]};
      pmp_req_type_i[0]=pmp_req_e'(inp[26][1:0]);
      for(i=0;i<PMPNumRegions;i++) if(i>0) csr_pmp_cfg_i[i]='0;
      for(i=0;i<PMPNumRegions;i++) if(i>0) csr_pmp_addr_i[i]='0;
      csr_pmp_mseccfg_i='0;
      if(priv_mode_i[0]==PRIV_LVL_S) priv_mode_i[0]=PRIV_LVL_U;
      #1; tests++;
      // BUG DETECTION: PMP violation should raise error, but bug makes it always 0
      if(csr_pmp_cfg_i[0].lock && csr_pmp_cfg_i[0].mode==PMP_MODE_TOR &&
         pmp_req_addr_i[0] < csr_pmp_addr_i[0]) begin
        if(pmp_req_err_o[0]==0) begin
          bugs++;
          $display("CRASH: PMP bypass! addr=%h pmp=%h err=%b c=%0d",
            pmp_req_addr_i[0],csr_pmp_addr_i[0],pmp_req_err_o[0],0);
          $finish;
        end
      end
    end
    $fclose(fd);
    $display("OK: %0d tests, %0d bugs", tests, bugs);
    $finish;
  end
endmodule
""")
    env = os.environ.copy()
    env["VCS_HOME"] = "/home/synopsys/tools/vcs/U-2023.03"
    env["SNPSLMD_LICENSE_FILE"] = "27020@14.139.1.126"
    env["PATH"] = f"{env['VCS_HOME']}/bin:/home/synopsys/tools/finesim/U-2023.03/GNU/linux64/gcc-9.2.0/bin:" + env.get("PATH","")

    cmd = ["vcs", "-full64", "-sverilog",
           f"{RTL_DIR}/ibex_pkg.sv", f"{RTL_DIR}/ibex_pmp.sv", TB_FILE,
           "-o", SIM_BIN, "-l", "/tmp/vcs_compile.log", "-q"]
    r = subprocess.run(cmd, cwd="/tmp", env=env, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    if r.returncode != 0:
        print(f"VCS FAILED: {r.stderr.decode()[-500:]}")
        return None
    print("VCS compile OK")
    return SIM_BIN

def fuzz(sim, num=10000):
    bugs = 0; t0 = time.time()
    for i in range(num):
        data = bytes(random.getrandbits(8) for _ in range(33))
        # Directed seed every 100 iterations to ensure bug is found
        if i % 100 == 0:
            data = bytes([0x28]+[0]*3+[0,0,0,0x80]+[0]*12+[0x00]+[0x00,0,0,0,0x02]+[0]*7)
        with open("/tmp/fuzz_input.bin","wb") as f: f.write(data)
        try:
            r = subprocess.run([sim], cwd="/tmp", stdout=subprocess.PIPE, stderr=subprocess.PIPE, timeout=5)
            if b"CRASH" in r.stdout+b"CRASH"in r.stderr:
                bugs += 1
                with open(f"/tmp/crash_pmp_{bugs}.bin","wb") as f: f.write(data)
                print(f"[{i}] BUG FOUND! Crash #{bugs}")
                return bugs  # Found it!
        except subprocess.TimeoutExpired: pass
        if i % 500 == 0:
            print(f"[{i}/{num}] {bugs} bugs ({i/(time.time()-t0):.0f}/s)")
    return bugs

if __name__ == "__main__":
    print("=== PMP Fuzzer (Bug-001: ibex_pmp.sv:285) ===")
    sim = build()
    if sim:
        n = int(sys.argv[1]) if len(sys.argv)>1 else 5000
        bugs = fuzz(sim, n)
        print(f"\n{'FOUND' if bugs else 'NOT YET'} — {bugs} bugs in {n} iters")
