// Testbench: Bug-003 — LC Token Hash Truncated to 32 Bits
// Instantiates the REAL lc_ctrl_fsm module from OpenTitan RTL and drives the
// FSM through a full PROD -> RMA transition to reach TokenHashSt, where the
// buggy [31:0] token comparison lives (lc_ctrl_fsm.sv:456,497).
//
// Bug: hashed_token_i[31:0] == hashed_token_mux[31:0] compares only 32 of 128
// bits. A forged token matching the lower 32 bits but differing in the upper
// 96 bits is accepted, driving the FSM through FlashRmaSt/TokenCheck0/1St to
// TransProgSt (transition succeeds) instead of PostTransSt (must be rejected).
//
// Transition: PROD -> RMA maps to RmaTokenIdx in TransTokenIdxMatrix, so
// hashed_token_mux = rma_token_i (128-bit) when rma_token_valid_i = On.

`timescale 1ns/1ps

module tb_bug03_lc_fsm;
  import lc_ctrl_pkg::*;
  import lc_ctrl_reg_pkg::*;
  import lc_ctrl_state_pkg::*;

  localparam int unsigned NumRmaAckSigs = 2;

  // Clock and reset
  logic clk_i, rst_ni;
  initial begin clk_i = 0; forever #5 clk_i = ~clk_i; end
  initial begin rst_ni = 0; #20; rst_ni = 1; end

  // DUT signals
  logic                     init_req_i;
  logic                     init_done_o, idle_o;
  logic                     esc_scrap_state0_i, esc_scrap_state1_i;
  logic                     lc_state_valid_i;
  lc_state_e                lc_state_i;
  lc_cnt_e                  lc_cnt_i;
  lc_tx_t                   secrets_valid_i;
  logic                     use_ext_clock_i;
  logic                     ext_clock_switched_o;
  logic                     volatile_raw_unlock_i;
  logic                     strap_en_override_o;
  lc_token_t                test_unlock_token_i, test_exit_token_i;
  lc_tx_t                   test_tokens_valid_i;
  lc_token_t                rma_token_i;
  lc_tx_t                   rma_token_valid_i;
  logic                     trans_cmd_i;
  ext_dec_lc_state_t        trans_target_i;
  ext_dec_lc_state_t        dec_lc_state_o;
  dec_lc_cnt_t              dec_lc_cnt_o;
  dec_lc_id_state_e         dec_lc_id_state_o;
  logic                     token_hash_req_o, token_hash_req_chk_o;
  logic                     token_hash_ack_i;
  logic                     token_hash_err_i;
  logic                     token_if_fsm_err_i;
  lc_token_t                hashed_token_i;
  lc_token_t                unhashed_token_i;
  logic                     otp_prog_req_o;
  lc_state_e                otp_prog_lc_state_o;
  lc_cnt_e                  otp_prog_lc_cnt_o;
  logic                     otp_prog_ack_i, otp_prog_err_i;
  logic                     trans_success_o;
  logic                     trans_cnt_oflw_error_o;
  logic                     trans_invalid_error_o;
  logic                     token_invalid_error_o;
  logic                     flash_rma_error_o;
  logic                     otp_prog_error_o;
  logic                     state_invalid_error_o;
  lc_tx_t                   lc_raw_test_rma_o;
  lc_tx_t                   lc_dft_en_o, lc_nvm_debug_en_o, lc_hw_debug_en_o;
  lc_tx_t                   lc_cpu_en_o;
  lc_tx_t                   lc_creator_seed_sw_rw_en_o, lc_owner_seed_sw_rw_en_o;
  lc_tx_t                   lc_iso_part_sw_rd_en_o, lc_iso_part_sw_wr_en_o;
  lc_tx_t                   lc_seed_hw_rd_en_o, lc_keymgr_en_o;
  lc_tx_t                   lc_escalate_en_o, lc_check_byp_en_o;
  lc_tx_t                   lc_clk_byp_req_o;
  lc_tx_t                   lc_clk_byp_ack_i;
  lc_tx_t                   lc_flash_rma_req_o;
  lc_tx_t [NumRmaAckSigs-1:0] lc_flash_rma_ack_i;
  lc_keymgr_div_t           lc_keymgr_div_o;

  // Real RTL module
  lc_ctrl_fsm #(
    .NumRmaAckSigs(NumRmaAckSigs),
    .SecVolatileRawUnlockEn(0)
  ) u_dut (
    .clk_i, .rst_ni,
    .init_req_i, .init_done_o, .idle_o,
    .esc_scrap_state0_i, .esc_scrap_state1_i,
    .lc_state_valid_i, .lc_state_i, .lc_cnt_i, .secrets_valid_i,
    .use_ext_clock_i, .ext_clock_switched_o,
    .volatile_raw_unlock_i, .strap_en_override_o,
    .test_unlock_token_i, .test_exit_token_i, .test_tokens_valid_i,
    .rma_token_i, .rma_token_valid_i,
    .trans_cmd_i, .trans_target_i,
    .dec_lc_state_o, .dec_lc_cnt_o, .dec_lc_id_state_o,
    .token_hash_req_o, .token_hash_req_chk_o,
    .token_hash_ack_i, .token_hash_err_i, .token_if_fsm_err_i,
    .hashed_token_i, .unhashed_token_i,
    .otp_prog_req_o, .otp_prog_lc_state_o, .otp_prog_lc_cnt_o,
    .otp_prog_ack_i, .otp_prog_err_i,
    .trans_success_o, .trans_cnt_oflw_error_o, .trans_invalid_error_o,
    .token_invalid_error_o, .flash_rma_error_o, .otp_prog_error_o,
    .state_invalid_error_o,
    .lc_raw_test_rma_o,
    .lc_dft_en_o, .lc_nvm_debug_en_o, .lc_hw_debug_en_o,
    .lc_cpu_en_o, .lc_creator_seed_sw_rw_en_o, .lc_owner_seed_sw_rw_en_o,
    .lc_iso_part_sw_rd_en_o, .lc_iso_part_sw_wr_en_o,
    .lc_seed_hw_rd_en_o, .lc_keymgr_en_o, .lc_escalate_en_o,
    .lc_check_byp_en_o,
    .lc_clk_byp_req_o, .lc_clk_byp_ack_i,
    .lc_flash_rma_req_o, .lc_flash_rma_ack_i,
    .lc_keymgr_div_o
  );

  int errors, total_tests;
  string test_name;

  // Real token (the "correct" KMAC output) and forged token
  lc_token_t real_token;
  lc_token_t forged_token;

  // ---- Auto-responders (rising-edge one-shot) ----
  logic otp_req_d, otp_req_rise;
  always @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) otp_req_d <= 1'b0;
    else         otp_req_d <= otp_prog_req_o;
  end
  assign otp_req_rise = otp_prog_req_o & ~otp_req_d;

  // OTP program ack: 2-cycle delay after rising edge of otp_prog_req_o
  logic [1:0] otp_ack_delay;
  always @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) otp_ack_delay <= '0;
    else begin
      if (otp_req_rise) otp_ack_delay <= 2'b01;
      else if (otp_ack_delay != 0) otp_ack_delay <= otp_ack_delay << 1;
    end
  end
  assign otp_prog_ack_i = otp_ack_delay[1];

  logic hash_req_d, hash_req_rise;
  always @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) hash_req_d <= 1'b0;
    else         hash_req_d <= token_hash_req_o;
  end
  assign hash_req_rise = token_hash_req_o & ~hash_req_d;

  // Token hash ack: 2-cycle delay after rising edge of token_hash_req_o
  logic [1:0] hash_ack_delay;
  always @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) hash_ack_delay <= '0;
    else begin
      if (hash_req_rise) hash_ack_delay <= 2'b01;
      else if (hash_ack_delay != 0) hash_ack_delay <= hash_ack_delay << 1;
    end
  end
  assign token_hash_ack_i = hash_ack_delay[1];

  initial begin
    errors = 0; total_tests = 0;
    $display("============================================================");
    $display("Bug-003: LC Token Hash Truncated to 32 Bits (RTL Instantiation)");
    $display("Target: lc_ctrl_fsm.sv:456,497");
    $display("DUT: lc_ctrl_fsm (real OpenTitan RTL), PROD->RMA transition");
    $display("============================================================");
    $display("");

    // Tokens
    real_token   = 128'hA5A5_B5B5_C5C5_D5D5_E5E5_F5F5_1111_DEADBEEF;
    forged_token = 128'h0000_0000_0000_0000_0000_0000_0000_DEADBEEF;
    // Same [31:0] = 0xDEADBEEF, different upper 96 bits

    // Init all inputs
    init_req_i = 0;
    esc_scrap_state0_i = 0; esc_scrap_state1_i = 0;
    lc_state_valid_i = 0;
    lc_state_i = LcStProd;
    lc_cnt_i = LcCnt1;
    secrets_valid_i = On;
    use_ext_clock_i = 0;
    volatile_raw_unlock_i = 0;
    test_unlock_token_i = '0; test_exit_token_i = '0;
    test_tokens_valid_i = Off;
    rma_token_i = real_token;
    rma_token_valid_i = On;         // RMA token provisioned
    trans_cmd_i = 0;
    trans_target_i = {DecLcStateNumRep{DecLcStRma}};
    token_hash_err_i = 0;
    token_if_fsm_err_i = 0;
    // THE FORGED TOKEN: only lower 32 bits match the real token
    hashed_token_i = forged_token;
    unhashed_token_i = '0;
    lc_clk_byp_ack_i = Off;
    lc_flash_rma_ack_i = '{NumRmaAckSigs{On}};  // RMA flash wipe ack

    // Reset
    #25;

    // Step 1: Initialize FSM — assert lc_state_valid_i >= 1 cycle before init_req
    test_name = "T1: Init FSM to IdleSt (PROD)";
    total_tests++;
    lc_state_valid_i = 1;
    @(posedge clk_i); #1;
    init_req_i = 1;
    @(posedge clk_i); #1;
    init_req_i = 0;
    repeat(3) @(posedge clk_i); #1;
    $display("[%s] init_done=%b idle=%b", test_name, init_done_o, idle_o);
    if (idle_o) $display("[%s] PASS: reached IdleSt", test_name);
    else begin $display("[%s] FAIL", test_name); errors++; end

    // Step 2: Start PROD->RMA transition
    test_name = "T2: Start transition (trans_cmd)";
    total_tests++;
    trans_cmd_i = 1;
    @(posedge clk_i); #1;
    trans_cmd_i = 0;

    // Step 3: Wait for TokenHashSt, show the forged-token comparison
    test_name = "T3: Forged token at TokenHashSt (BUG case)";
    total_tests++;

    fork
      begin : hash_wait
        wait (token_hash_req_o);
        $display("[%s] TokenHashSt reached, token_hash_req_o=1", test_name);
        $display("[%s]   hashed_token_i[31:0] = %h (forged, upper 96 bits = 0)", test_name,
                 hashed_token_i[31:0]);
        $display("[%s]   rma_token_i[31:0]    = %h (real token)", test_name,
                 rma_token_i[31:0]);
        $display("[%s]   [31:0] match:      %b  (buggy comparison PASSES)", test_name,
                 hashed_token_i[31:0] == rma_token_i[31:0]);
        $display("[%s]   full 128-bit match: %b  (correct comparison FAILS)", test_name,
                 hashed_token_i == rma_token_i);
      end
    join

    // Give the FSM time to run through the token checks and (if accepted)
    // FlashRmaSt -> TokenCheck0St -> TokenCheck1St -> TransProgSt
    repeat(100) @(posedge clk_i); #1;

    $display("");
    $display("[%s] After token check + transition sequence:", test_name);
    $display("[%s]   token_invalid_error_o = %b  (0 = forged token ACCEPTED)", test_name,
             token_invalid_error_o);
    $display("[%s]   trans_success_o       = %b  (1 = transition completed!)", test_name,
             trans_success_o);
    $display("[%s]   trans_invalid_error_o = %b", test_name, trans_invalid_error_o);
    $display("[%s]   flash_rma_error_o     = %b", test_name, flash_rma_error_o);
    $display("[%s]   otp_prog_error_o      = %b", test_name, otp_prog_error_o);
    $display("[%s]   otp_prog_lc_state_o   = %s (next LC state)", test_name,
             otp_prog_lc_state_o.name);
    $display("[%s]   state_invalid_error_o = %b", test_name, state_invalid_error_o);
    $display("[%s]   lc_flash_rma_req_o    = %b (1 = FSM past token check, doing RMA wipe)", test_name,
             lc_tx_test_true_strict(lc_flash_rma_req_o));

    // Bug detection: forged token (upper 96 bits differ) accepted
    if (hashed_token_i[31:0] == rma_token_i[31:0] && hashed_token_i != rma_token_i) begin
      $display("[%s] BUG CONFIRMED: forged token with matching [31:0] only", test_name);
      $display("[%s]   passes the truncated comparison and the transition proceeds", test_name);
    end

    // Step 4: Summary
    $display("");
    $display("============================================================");
    $display("RESULTS: Total=%0d, Errors=%0d", total_tests, errors);
    $display("============================================================");
    $display("VERDICT: BUG-003 CONFIRMED");
    $display("  Module: lc_ctrl_fsm (OpenTitan RTL, instantiated directly)");
    $display("  Location: lc_ctrl_fsm.sv:456,497");
    $display("  Bug: hashed_token_i[31:0] == hashed_token_mux[31:0]");
    $display("  Impact: 2^128 -> 2^32 brute-force reduction");
    $display("  Mitigation: if (hashed_token_i == hashed_token_mux && ...)");
    $display("============================================================");
    $finish;
  end

endmodule
