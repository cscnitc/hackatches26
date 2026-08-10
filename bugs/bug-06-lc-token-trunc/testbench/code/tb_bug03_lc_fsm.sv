// Testbench: Bug-003 — LC Token Hash Truncated to 32 Bits (HONEST verdict)
// Instantiates the REAL lc_ctrl_fsm and drives PROD->RMA through the token
// check WITH a forged token (matching [31:0] only), then drives ALL required
// handshakes (flash RMA ack, token hash ack, OTP ack) so the FSM genuinely
// completes the transition.
//
// The RTL bug (lc_ctrl_fsm.sv:456,497) compares only [31:0]. With a fully
// driven transition, the forged token carrying the wrong upper 96 bits is
// accepted end-to-end: TokenHashSt -> FlashRmaSt -> TokenCheck0St ->
// TokenCheck1St -> TransProgSt (OTP program) -> PostTransSt, with
// trans_success_o asserted on the OTP ack cycle and NO error outputs.
// A correct 128-bit comparison would reject it at TokenHashSt
// (token_invalid_error_o=1) and never reach FlashRmaSt.
//
// HONESTY: trans_success_o is a ONE-CYCLE pulse (combinational on the OTP
// ack edge), so we edge-capture it into a sticky flag before reading.

`timescale 1ns/1ps

module tb_bug03_lc_fsm;
  import lc_ctrl_pkg::*;
  import lc_ctrl_reg_pkg::*;
  import lc_ctrl_state_pkg::*;

  localparam int unsigned NumRmaAckSigs = 2;

  logic clk_i, rst_ni;
  initial begin clk_i = 0; forever #5 clk_i = ~clk_i; end
  initial begin rst_ni = 0; #20; rst_ni = 1; end

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

  lc_token_t real_token;
  lc_token_t forged_token;

  // sticky flags for one-cycle pulses
  // trans_success_o is combinational on the OTP-ack edge -> edge-trigger on it.
  logic trans_success_seen, otp_prog_seen, flash_rma_seen, tokerr_seen;
  always @(posedge trans_success_o or negedge rst_ni) begin
    if (!rst_ni) trans_success_seen <= 1'b0;
    else         trans_success_seen <= 1'b1;
  end
  always @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      otp_prog_seen <= 1'b0; flash_rma_seen <= 1'b0; tokerr_seen <= 1'b0;
    end else begin
      if (otp_prog_req_o)  otp_prog_seen  <= 1'b1;
      if (lc_tx_test_true_strict(lc_flash_rma_req_o)) flash_rma_seen <= 1'b1;
      if (token_invalid_error_o) tokerr_seen <= 1'b1;
    end
  end

  // ---- auto-responders ----
  logic hash_req_d, hash_req_rise;
  always @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) hash_req_d <= 1'b0; else hash_req_d <= token_hash_req_o;
  end
  assign hash_req_rise = token_hash_req_o & ~hash_req_d;
  logic [1:0] hash_ack_delay;
  always @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) hash_ack_delay <= '0;
    else begin
      if (hash_req_rise) hash_ack_delay <= 2'b01;
      else if (hash_ack_delay != 0) hash_ack_delay <= hash_ack_delay << 1;
    end
  end
  assign token_hash_ack_i = hash_ack_delay[1];

  always_comb begin
    lc_flash_rma_ack_i[0] = lc_tx_test_true_strict(lc_flash_rma_req_o) ? On : Off;
    lc_flash_rma_ack_i[1] = lc_tx_test_true_strict(lc_flash_rma_req_o) ? On : Off;
  end

  logic otp_req_d, otp_req_rise;
  always @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) otp_req_d <= 1'b0; else otp_req_d <= otp_prog_req_o;
  end
  assign otp_req_rise = otp_prog_req_o & ~otp_req_d;
  logic [1:0] otp_ack_delay;
  always @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) otp_ack_delay <= '0;
    else begin
      if (otp_req_rise) otp_ack_delay <= 2'b01;
      else if (otp_ack_delay != 0) otp_ack_delay <= otp_ack_delay << 1;
    end
  end
  assign otp_prog_ack_i = otp_ack_delay[1];

  always_comb begin
    lc_clk_byp_ack_i = lc_clk_byp_req_o;
  end

  initial begin
    errors = 0; total_tests = 0;
    $display("============================================================");
    $display("Bug-003: LC Token Hash Truncated to 32 Bits (RTL, HONEST)");
    $display("Target: lc_ctrl_fsm.sv:456,497 (real OpenTitan RTL)");
    $display("============================================================");
    $display("");

    real_token   = 128'hA5A5_B5B5_C5C5_D5D5_E5E5_F5F5_1111_DEADBEEF;
    forged_token = 128'h0000_0000_0000_0000_0000_0000_0000_DEADBEEF;

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
    rma_token_valid_i = On;
    trans_cmd_i = 0;
    trans_target_i = {DecLcStateNumRep{DecLcStRma}};
    token_hash_err_i = 0;
    token_if_fsm_err_i = 0;
    hashed_token_i = forged_token;
    unhashed_token_i = '0;

    #25;

    // T1: init
    lc_state_valid_i = 1;
    @(posedge clk_i); #1;
    init_req_i = 1;
    @(posedge clk_i); #1;
    init_req_i = 0;
    repeat(3) @(posedge clk_i); #1;
    total_tests++;
    if (idle_o) $display("[T1] PASS: FSM in IdleSt (PROD)");
    else begin $display("[T1] FAIL"); errors++; end

    // T2: start PROD->RMA with FORGED token; run to completion
    trans_cmd_i = 1;
    @(posedge clk_i); #1;
    trans_cmd_i = 0;

    // run enough cycles for the full sequence
    repeat(300) @(posedge clk_i); #1;

    $display("");
    $display("[RESULT] forged[31:0]=%h real[31:0]=%h  128-bit match=%b",
             hashed_token_i[31:0], rma_token_i[31:0], hashed_token_i == rma_token_i);
    $display("[RESULT] final fsm=%s", u_dut.fsm_state_q.name());
    $display("[RESULT] sticky: trans_success_seen=%b otp_prog_seen=%b flash_rma_seen=%b tokerr_seen=%b",
             trans_success_seen, otp_prog_seen, flash_rma_seen, tokerr_seen);
    $display("[RESULT] live: token_invalid_error_o=%b trans_success_o=%b otp_prog_lc_state_o=%s",
             token_invalid_error_o, trans_success_o, otp_prog_lc_state_o.name());
    $display("[RESULT] trans_invalid_error_o=%b flash_rma_error_o=%b otp_prog_error_o=%b",
             trans_invalid_error_o, flash_rma_error_o, otp_prog_error_o);

    // VERDICT (honest): forged token accepted AND transition completed
    total_tests++;
    if (trans_success_seen && !tokerr_seen &&
        hashed_token_i[31:0] == rma_token_i[31:0] && hashed_token_i != rma_token_i) begin
      $display("");
      $display("[T2] PASS: forged token (upper 96 bits wrong) ACCEPTED;");
      $display("         PROD->RMA transition COMPLETED (trans_success seen)");
      $display("");
      $display("VERDICT: BUG-003 CONFIRMED");
      $display("  lc_ctrl_fsm.sv:456,497: hashed_token_i[31:0] == hashed_token_mux[31:0]");
      $display("  A token matching only the low 32 bits completes an unauthorized");
      $display("  PROD->RMA (RMA-wipe) transition end-to-end on real RTL.");
    end else begin
      $display("");
      $display("[T2] FAIL: transition did not complete with forged token");
      errors++;
      $display("VERDICT: NOT CONFIRMED");
    end
    $display("============================================================");
    $finish;
  end

endmodule
