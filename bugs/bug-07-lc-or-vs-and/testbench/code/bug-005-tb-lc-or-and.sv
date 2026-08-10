// Testbench: Bug-005 — LC State Transition Uses || Instead of && (HONEST)
// Target: lc_ctrl_state_transition.sv:140-141
//
// Buggy:   if (TransTokenIdxMatrix[dec0][tgt0] != InvalidTokenIdx ||
//               TransTokenIdxMatrix[dec1][tgt1] != InvalidTokenIdx)
// Correct: if (TransTokenIdxMatrix[dec0][tgt0] != InvalidTokenIdx &&
//               TransTokenIdxMatrix[dec1][tgt1] != InvalidTokenIdx)
//
// HONEST ASSESSMENT (correcting the earlier overclaim):
//   The `||` is a real defect in the dual-replica TOKEN-MATRIX agreement
//   check. HOWEVER, this module has independent defense-in-depth checks that
//   still reject a corrupted input:
//     - `unique case (trans_target_i)` (line ~147): both target replicas must
//       decode to the SAME valid state, else trans_invalid_error_o=1
//     - `unique case (dec_lc_state_i)` (line ~180): both state replicas must
//       decode to the SAME valid state, else trans_invalid_error_o=1
//   Therefore a single fault in this module's inputs does NOT by itself
//   complete an unauthorized transition: the || weakens one layer, but the
//   sparse replica-consistency checks still catch state/target corruption.
//
// What this test demonstrates (all on real RTL):
//   T1: valid PROD->RMA with both replicas agreeing -> accepted
//   T2: RAW->RMA (both replicas) -> rejected
//   T3: the || expression evaluates true for {PROD,RAW}->{RMA,RMA} and the
//       RTL enters the matrix branch (next_lc_state_o=LcStRma), but the
//       replica-consistency check on dec_lc_state_i still sets
//       trans_invalid_error_o=1 -> the transition is NOT authorized end-to-end.
//       This is the honest boundary of the bug's exploitability at this layer.

`timescale 1ns/1ps

module tb_bug05_lc_or_vs_and;
  import lc_ctrl_pkg::*;
  import lc_ctrl_state_pkg::*;

  localparam bit SecVolatileRawUnlockEn = 0;

  logic clk_i, rst_ni;
  lc_state_e lc_state_i, next_lc_state_o;
  lc_cnt_e lc_cnt_i, next_lc_cnt_o;
  fsm_state_e fsm_state_i;
  ext_dec_lc_state_t dec_lc_state_i;
  ext_dec_lc_state_t trans_target_i;
  logic volatile_raw_unlock_i;
  logic trans_cmd_i;
  logic trans_cnt_oflw_error_o;
  logic trans_invalid_error_o;

  lc_ctrl_state_transition #(
    .SecVolatileRawUnlockEn(SecVolatileRawUnlockEn)
  ) u_dut (
    .lc_state_i(lc_state_i),
    .lc_cnt_i(lc_cnt_i),
    .fsm_state_i(fsm_state_i),
    .dec_lc_state_i(dec_lc_state_i),
    .trans_target_i(trans_target_i),
    .volatile_raw_unlock_i(volatile_raw_unlock_i),
    .trans_cmd_i(trans_cmd_i),
    .next_lc_state_o(next_lc_state_o),
    .next_lc_cnt_o(next_lc_cnt_o),
    .trans_cnt_oflw_error_o(trans_cnt_oflw_error_o),
    .trans_invalid_error_o(trans_invalid_error_o)
  );

  int errors, total_tests;
  string test_name;

  initial begin
    errors = 0; total_tests = 0;
    $display("============================================================");
    $display("Bug-005: LC State Transition Uses || Instead of && (HONEST)");
    $display("Target: lc_ctrl_state_transition.sv:140-141");
    $display("============================================================");
    $display("");

    lc_state_i = LcStProd;
    lc_cnt_i = LcCnt1;
    volatile_raw_unlock_i = 0;
    trans_cmd_i = 0;
    fsm_state_i = TransProgSt;

    // T1: valid transition, both replicas agree (PROD -> RMA)
    test_name = "T1: Valid (both replicas agree)";
    total_tests++;
    dec_lc_state_i = {DecLcStateNumRep{DecLcStProd}};
    trans_target_i = {DecLcStateNumRep{DecLcStRma}};
    #1;
    $display("[%s] next=%s err=%b (expect RMA, 0)", test_name,
             next_lc_state_o.name, trans_invalid_error_o);
    if (!trans_invalid_error_o && next_lc_state_o == LcStRma)
      $display("[%s] PASS", test_name);
    else begin $display("[%s] FAIL", test_name); errors++; end

    // T2: invalid transition, both replicas invalid (RAW -> RMA)
    test_name = "T2: Invalid (both replicas invalid)";
    total_tests++;
    dec_lc_state_i = {DecLcStateNumRep{DecLcStRaw}};
    trans_target_i = {DecLcStateNumRep{DecLcStRma}};
    #1;
    $display("[%s] next=%s err=%b (expect 1)", test_name,
             next_lc_state_o.name, trans_invalid_error_o);
    if (trans_invalid_error_o) $display("[%s] PASS", test_name);
    else begin $display("[%s] FAIL", test_name); errors++; end

    // T3: FAULT — replica1 state decode corrupted PROD->RAW, target RMA (valid)
    test_name = "T3: Fault (replica1 state decode corrupted)";
    total_tests++;
    dec_lc_state_i[0] = DecLcStProd;
    dec_lc_state_i[1] = DecLcStRaw;
    trans_target_i    = {DecLcStateNumRep{DecLcStRma}};
    #1;
    $display("[%s] || expr: lookup[PROD][RMA]=valid, lookup[RAW][RMA]=invalid", test_name);
    $display("[%s]   => || evaluates TRUE (defective), && would be FALSE", test_name);
    $display("[%s] RTL result: next_lc_state=%s trans_invalid_error=%b", test_name,
             next_lc_state_o.name, trans_invalid_error_o);

    // Honest verdict
    if (trans_invalid_error_o === 1'b0 && next_lc_state_o == LcStRma) begin
      $display("");
      $display("[%s] The || defect authorized the faulted transition (no error)", test_name);
      $display("VERDICT: BUG-005 CONFIRMED - single-layer bypass");
    end else if (next_lc_state_o == LcStRma && trans_invalid_error_o === 1'b1) begin
      $display("");
      $display("[%s] HONEST: the || branch IS entered (next=RMA) but the module's", test_name);
      $display("         independent replica-consistency check (unique case on");
      $display("         dec_lc_state_i) still raises trans_invalid_error=1.");
      $display("         => the defect weakens the token-matrix agreement check,");
      $display("            but this layer alone does NOT complete the transition.");
      $display("VERDICT: BUG-005 defect CONFIRMED at expression level;");
      $display("         end-to-end authorization NOT achieved at this module");
      $display("         (defense-in-depth catches the corrupted replica).");
    end else begin
      $display("");
      $display("[%s] FAIL: unexpected result", test_name);
      errors++;
      $display("VERDICT: NOT CONFIRMED in this configuration");
    end

    $display("");
    $display("============================================================");
    $display("RESULTS: Total=%0d, Errors=%0d", total_tests, errors);
    $display("============================================================");
    $finish;
  end
endmodule
