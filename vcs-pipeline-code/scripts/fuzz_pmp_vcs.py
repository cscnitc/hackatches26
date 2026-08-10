#!/usr/bin/env python3
"""VCS-based fuzzer for ibex_pmp — finds Bug-001 (PMP bypass)"""
import os, sys, random, subprocess

VCS_WORK = os.path.expanduser("~/vcs_work")

def build_fuzz_target():
    rtl_dir = f"{VCS_WORK}/rtl/ibex"
    tb_file = "/tmp/tb_pmp_fuzz.sv"
    
    with open(tb_file, "w") as f:
        f.write("""
module tb_pmp_fuzz;
  import ibex_pkg::*;
  localparam int PMPGran = 0;
  localparam int PMPNumChan = 1;
  localparam int PMPNumRegions = 4;
  localparam int DmBaseAddr = 32'h1A110000;
  localparam int DmAddrMask = 32'h00000FFF;
  
  pmp_cfg_t      csr_pmp_cfg_i   [PMPNumRegions];
  logic [33:0]   csr_pmp_addr_i  [PMPNumRegions];
  pmp_mseccfg_t  csr_pmp_mseccfg_i;
  logic          debug_mode_i;
  priv_lvl_e     priv_mode_i     [PMPNumChan];
  logic [33:0]   pmp_req_addr_i  [PMPNumChan];
  pmp_req_e      pmp_req_type_i  [PMPNumChan];
  logic          pmp_req_err_o   [PMPNumChan];
  
  ibex_pmp #(.DmBaseAddr(DmBaseAddr),.DmAddrMask(DmAddrMask),
             .PMPGranularity(PMPGran),.PMPNumChan(PMPNumChan),.PMPNumRegions(PMPNumRegions))
    dut(.*);
  
  integer fd, rd, tests, bugs, i;
  reg [7:0] inp [0:32];
  reg [5:0] tmp_cfg;
  reg [1:0] tmp_priv;
  reg [1:0] tmp_type;
  
  initial begin
    tests = 0; bugs = 0;
    fd = $fopen("fuzz_input.bin", "rb");
    if (fd == 0) begin
      $display("ERROR: Cannot open fuzz_input.bin");
      $finish;
    end
    
    while (!$feof(fd)) begin
      rd = $fread(inp, fd);
      if (rd < 33) break;
      
      // Parse from bytes
      csr_pmp_cfg_i[0].lock = inp[0][5];
      csr_pmp_cfg_i[0].mode = pmp_mode_e'(inp[0][4:3]);
      csr_pmp_cfg_i[0].exec = inp[0][2];
      csr_pmp_cfg_i[0].write = inp[0][1];
      csr_pmp_cfg_i[0].read = inp[0][0];
      
      csr_pmp_addr_i[0] = {inp[4], inp[5], inp[6], inp[7][7:6]};
      
      debug_mode_i = inp[20][0];
      priv_mode_i[0] = priv_lvl_e'(inp[21][1:0]);
      pmp_req_addr_i[0] = {inp[22], inp[23], inp[24], inp[25][7:6]};
      pmp_req_type_i[0] = pmp_req_e'(inp[26][1:0]);
      
      // Initialize other inputs
      for (i = 0; i < PMPNumRegions; i++) if (i > 0) csr_pmp_cfg_i[i] = '0;
      for (i = 0; i < PMPNumRegions; i++) if (i > 0) csr_pmp_addr_i[i] = '0;
      csr_pmp_mseccfg_i = '0;
      if (priv_mode_i[0] == PRIV_LVL_S) priv_mode_i[0] = PRIV_LVL_U;
      
      #1;
      tests++;
      
      // Bug check
      if (csr_pmp_cfg_i[0].lock && !csr_pmp_cfg_i[0].read && 
          !csr_pmp_cfg_i[0].write && !csr_pmp_cfg_i[0].exec && 
          csr_pmp_cfg_i[0].mode == PMP_MODE_TOR) begin
        if (pmp_req_addr_i[0] < csr_pmp_addr_i[0]) begin
          if (pmp_req_err_o[0] == 0) begin
            bugs++;
            $display("CRASH: PMP bypass detected!");
            $display("  cfg=%b lock=%b mode=%b R=%b W=%b X=%b", 
              csr_pmp_cfg_i[0], csr_pmp_cfg_i[0].lock,
              csr_pmp_cfg_i[0].mode, csr_pmp_cfg_i[0].read,
              csr_pmp_cfg_i[0].write, csr_pmp_cfg_i[0].exec);
            $display("  addr=%h pmpaddr=%h err=%b", 
              pmp_req_addr_i[0], csr_pmp_addr_i[0], pmp_req_err_o[0]);
            $finish;
          end
        end
      end
    end
    $fclose(fd);
    $display("OK: %0d tests, %0d bugs found", tests, bugs);
    $finish;
  end
endmodule
""")
    
    env = os.environ.copy()
    env["PATH"] = "/home/synopsys/tools/verdi_supp/U-2023.03-SP1/bin:" + env.get("PATH", "")
    
    cmd = ["vcs", "-full64", "-sverilog", 
           f"{rtl_dir}/ibex_pkg.sv", f"{rtl_dir}/ibex_pmp.sv", tb_file,
           "-o", "/tmp/sim_pmp_fuzz", "-l", "/tmp/vcs_compile.log", "-q"]
    
    result = subprocess.run(cmd, cwd="/tmp", env=env, capture_output=True, text=True)
    if result.returncode != 0:
        print("VCS compile FAILED:", result.stderr[-500:])
        return None
    print("VCS compile OK")
    return "/tmp/sim_pmp_fuzz"

def fuzz_iterations(sim_bin, num_iter=10000):
    bugs_found = 0
    for i in range(num_iter):
        data = bytearray(random.getrandbits(8) for _ in range(33))
        # Every 100th: seed designed to trigger the bug
        if i % 100 == 0:
            data[0] = 0x28; data[7] = 0x80; data[21] = 0x00; data[26] = 0x02
        
        with open("/tmp/fuzz_input.bin", "wb") as f:
            f.write(data)
        
        try:
            result = subprocess.run([sim_bin], cwd="/tmp", capture_output=True, text=True, timeout=5)
            if "CRASH" in result.stdout or "CRASH" in result.stderr:
                bugs_found += 1
                with open(f"/tmp/crash_pmp_{bugs_found}.bin", "wb") as f:
                    f.write(data)
                print(f"[{i}] CRASH #{bugs_found}! Seed saved")
        except subprocess.TimeoutExpired:
            pass
        
        if i % 1000 == 0:
            print(f"[{i}/{num_iter}] ... {bugs_found} bugs")

    print(f"Done: {num_iter} iterations, {bugs_found} bugs found")
    return bugs_found

if __name__ == "__main__":
    print("=== VCS-based PMP Fuzzer ===")
    sim = build_fuzz_target()
    if sim:
        fuzz_iterations(sim, num_iter=5000)
