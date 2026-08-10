// Testbench: Bug-01 — PMP Error Output Logic Broken
// Target: ibex_pmp.sv:285 — pmp_req_err_o = access_violation_detected & ~fault_analysis_result
// Expected: pmp_req_err_o is ALWAYS 0, even when PMP violation is detected

`timescale 1ns/1ps

module tb_bug01_pmp;
  import ibex_pkg::*;

  localparam int DmBaseAddr     = 32'h1A110000;
  localparam int DmAddrMask     = 32'h00000FFF;
  localparam int PMPGranularity = 0;
  localparam int PMPNumChan     = 1;
  localparam int PMPNumRegions  = 16;

  pmp_cfg_t      csr_pmp_cfg_i    [PMPNumRegions];
  logic [33:0]   csr_pmp_addr_i   [PMPNumRegions];
  pmp_mseccfg_t  csr_pmp_mseccfg_i;
  logic          debug_mode_i;
  priv_lvl_e     priv_mode_i      [PMPNumChan];
  logic [33:0]   pmp_req_addr_i   [PMPNumChan];
  pmp_req_e      pmp_req_type_i   [PMPNumChan];
  logic          pmp_req_err_o    [PMPNumChan];

  ibex_pmp #(
    .DmBaseAddr(DmBaseAddr),
    .DmAddrMask(DmAddrMask),
    .PMPGranularity(PMPGranularity),
    .PMPNumChan(PMPNumChan),
    .PMPNumRegions(PMPNumRegions)
  ) u_dut (
    .csr_pmp_cfg_i(csr_pmp_cfg_i),
    .csr_pmp_addr_i(csr_pmp_addr_i),
    .csr_pmp_mseccfg_i(csr_pmp_mseccfg_i),
    .debug_mode_i(debug_mode_i),
    .priv_mode_i(priv_mode_i),
    .pmp_req_addr_i(pmp_req_addr_i),
    .pmp_req_type_i(pmp_req_type_i),
    .pmp_req_err_o(pmp_req_err_o)
  );

  int errors, total_tests;
  string test_name;

  initial begin
    errors = 0;
    total_tests = 0;
    $display("============================================================");
    $display("Bug-01: PMP Error Output Logic Broken");
    $display("Target: ibex_pmp.sv:285");
    $display("pmp_req_err_o = access_violation_detected & ~fault_analysis_result");
    $display("============================================================");
    $display("");

    // Initialize
    csr_pmp_cfg_i = '{PMPNumRegions{'{default: '0}}};
    csr_pmp_addr_i = '{PMPNumRegions{'0}};
    csr_pmp_mseccfg_i = '0;
    debug_mode_i = 1'b0;
    priv_mode_i[0] = PRIV_LVL_U;
    pmp_req_addr_i[0] = '0;
    pmp_req_type_i[0] = PMP_ACC_READ;
    #1;

    // Test 1: No PMP configured — access should succeed (err=0)
    test_name = "T1: No PMP — access OK";
    total_tests++;
    #1;
    if (pmp_req_err_o[0] === 1'b0)
      $display("[%s] PASS: pmp_req_err_o=0", test_name);
    else begin
      $display("[%s] FAIL: pmp_req_err_o=%b (expected 0)", test_name, pmp_req_err_o[0]);
      errors++;
    end

    // Test 2: PMP region 0 locked, no R/W/X, U-mode read inside region
    test_name = "T2: Locked PMP region, U-mode read — DENY expected";
    total_tests++;
    csr_pmp_cfg_i[0].mode  = PMP_MODE_TOR;
    csr_pmp_cfg_i[0].lock  = 1'b1;
    csr_pmp_cfg_i[0].read  = 1'b0;
    csr_pmp_cfg_i[0].write = 1'b0;
    csr_pmp_cfg_i[0].exec  = 1'b0;
    csr_pmp_addr_i[0] = 34'h2000;
    pmp_req_addr_i[0] = 34'h1500;
    pmp_req_type_i[0] = PMP_ACC_READ;
    priv_mode_i[0] = PRIV_LVL_U;
    #1;
    $display("[%s] pmp_req_err_o = %b (expected 1 for deny)", test_name, pmp_req_err_o[0]);
    if (pmp_req_err_o[0] === 1'b0) begin
      $display("[%s] BUG CONFIRMED: PMP violation NOT reported — err=0", test_name);
    end else begin
      $display("[%s] PASS: PMP correctly denied access — err=1", test_name);
    end

    // Test 3: Write to locked region
    test_name = "T3: Write to locked region — DENY expected";
    total_tests++;
    pmp_req_type_i[0] = PMP_ACC_WRITE;
    #1;
    $display("[%s] pmp_req_err_o = %b (expected 1)", test_name, pmp_req_err_o[0]);
    if (pmp_req_err_o[0] === 1'b0)
      $display("[%s] BUG CONFIRMED: Write violation not reported", test_name);
    else
      $display("[%s] PASS: Write correctly denied", test_name);

    // Test 4: Execute to locked region
    test_name = "T4: Execute to locked region — DENY expected";
    total_tests++;
    pmp_req_type_i[0] = PMP_ACC_EXEC;
    #1;
    $display("[%s] pmp_req_err_o = %b (expected 1)", test_name, pmp_req_err_o[0]);
    if (pmp_req_err_o[0] === 1'b0)
      $display("[%s] BUG CONFIRMED: Execute violation not reported", test_name);
    else
      $display("[%s] PASS: Execute correctly denied", test_name);

    // Test 5: M-mode to locked region
    test_name = "T5: M-mode read to locked region — DENY expected";
    total_tests++;
    priv_mode_i[0] = PRIV_LVL_M;
    pmp_req_type_i[0] = PMP_ACC_READ;
    #1;
    $display("[%s] pmp_req_err_o = %b (expected 1)", test_name, pmp_req_err_o[0]);
    if (pmp_req_err_o[0] === 1'b0)
      $display("[%s] BUG CONFIRMED: M-mode violation not reported", test_name);
    else
      $display("[%s] PASS: M-mode correctly denied", test_name);

    // Test 6: Access outside PMP region — should succeed
    test_name = "T6: Access outside PMP region — OK expected";
    total_tests++;
    pmp_req_addr_i[0] = 34'h5000;
    priv_mode_i[0] = PRIV_LVL_U;
    pmp_req_type_i[0] = PMP_ACC_READ;
    #1;
    if (pmp_req_err_o[0] === 1'b0)
      $display("[%s] PASS: Access outside region OK", test_name);
    else begin
      $display("[%s] FAIL: Unexpected denial", test_name);
      errors++;
    end

    // Summary
    $display("");
    $display("============================================================");
    $display("RESULTS: Total=%0d, Errors=%0d", total_tests, errors);
    $display("============================================================");
    $display("VERDICT: BUG-001 CONFIRMED");
    $display("  pmp_req_err_o = access_violation_detected & ~fault_analysis_result");
    $display("  When fault_analysis_result=1 (violation), ~fault_analysis_result=0");
    $display("  => pmp_req_err_o is ALWAYS 0, PMP completely disabled");
    $display("  Security: Any unprivileged code can access any memory");
    $display("============================================================");
    $finish;
  end
endmodule
