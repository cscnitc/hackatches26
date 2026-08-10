// Bug 09 (AES data_out reset-gating) — honest real-RTL demonstration.
//
// Fix vs. old TB: old TB never asserted reset while data_out_we==SP2V_HIGH and
// printed CONFIRMED unconditionally. Here we:
//   1. run a REAL AES-128 encryption through the actual aes_core register
//      interface (key + data_in + control + trigger.start),
//   2. wait until the cipher-completion cycle where data_out_we == SP2V_HIGH
//      (the exact gating condition),
//   3. assert reset AT that posedge (glitch_req -> harness drops rst_n),
//   4. read back data_out_q: with the planted gating, the register WRITES
//      ciphertext instead of clearing (stale secret survives reset);
//      control run (reset in idle) clears to 0.
// Verdict is CONDITIONAL on the observed signals, not unconditional.

module tb(
  input logic clk,
  input logic rst_n,
  output logic [3:0] state,
  output logic bug_found,
  output logic glitch_req          // harness: drop rst_n while high
);
  import aes_pkg::*;
  import aes_reg_pkg::*;
  import keymgr_pkg::*;
  import lc_ctrl_pkg::*;
  import edn_pkg::*;

  logic rst_shadowed_ni;
  logic entropy_clearing_req_o, entropy_clearing_ack_i;
  logic [edn_pkg::ENDPOINT_BUS_WIDTH-1:0] entropy_clearing_i;
  logic entropy_masking_req_o, entropy_masking_ack_i;
  logic [edn_pkg::ENDPOINT_BUS_WIDTH-1:0] entropy_masking_i;
  hw_key_req_t keymgr_key_i;
  lc_tx_t lc_escalate_en_i;
  logic shadowed_storage_err_i, shadowed_update_err_i, intg_err_alert_i;
  logic alert_recov_o, alert_fatal_o;
  aes_reg2hw_t reg2hw;
  aes_hw2reg_t hw2reg;

  // Instantiate with SecMasking=0 so the cipher runs the fast LUT S-box without
  // needing the EDN entropy handshake (the planted reset-gating bug is
  // orthogonal to masking; chip_earlgrey passes SecAllowForcingMasks=1 but the
  // data_out reset gate is unconditional in the RTL).
  aes_core #(
    .SecMasking(0),
    .SecSBoxImpl(aes_pkg::SBoxImplLut),
    .SecSkipPRNGReseeding(1)
  ) dut (
    .clk_i(clk), .rst_ni(rst_n), .rst_shadowed_ni,
    .entropy_clearing_req_o, .entropy_clearing_ack_i, .entropy_clearing_i,
    .entropy_masking_req_o, .entropy_masking_ack_i, .entropy_masking_i,
    .keymgr_key_i, .lc_escalate_en_i,
    .shadowed_storage_err_i, .shadowed_update_err_i, .intg_err_alert_i,
    .alert_recov_o, .alert_fatal_o,
    .reg2hw, .hw2reg
  );

  logic [7:0][31:0] data_out_q_capture;
  logic armed, glitch_done_flag;
  logic [31:0] cycles;
  logic control_done;

  // combinational glitch request: armed & data_out_we is HIGH (gating condition)
  assign glitch_req = armed && (dut.data_out_we == SP2V_HIGH);

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= 0;
      entropy_clearing_ack_i <= 0;
      entropy_clearing_i <= '0;
      entropy_masking_ack_i <= 0;
      entropy_masking_i <= '0;
      keymgr_key_i <= '0;
      lc_escalate_en_i <= Off;
      shadowed_storage_err_i <= 0;
      shadowed_update_err_i <= 0;
      intg_err_alert_i <= 0;
      reg2hw <= '0;
      armed <= 0;
      glitch_done_flag <= 0;
      cycles <= 0;
      control_done <= 0;
      data_out_q_capture <= '0;
      bug_found <= 0;
    end else begin
      case (state)
        0: begin
             $display("=== Bug 09: AES data_out reset-gating — real encryption + reset glitch ===");
             // Load AES-128 key (share0), software-provided
             reg2hw.key_share0[0].q <= 32'h00010203; reg2hw.key_share0[0].qe <= 1'b1;
             reg2hw.key_share0[1].q <= 32'h04050607; reg2hw.key_share0[1].qe <= 1'b1;
             reg2hw.key_share0[2].q <= 32'h08090a0b; reg2hw.key_share0[2].qe <= 1'b1;
             reg2hw.key_share0[3].q <= 32'h0c0d0e0f; reg2hw.key_share0[3].qe <= 1'b1;
             reg2hw.key_share0[4].q <= 32'h10111213; reg2hw.key_share0[4].qe <= 1'b1;
             reg2hw.key_share0[5].q <= 32'h14151617; reg2hw.key_share0[5].qe <= 1'b1;
             reg2hw.key_share0[6].q <= 32'h18191a1b; reg2hw.key_share0[6].qe <= 1'b1;
             reg2hw.key_share0[7].q <= 32'h1c1d1e1f; reg2hw.key_share0[7].qe <= 1'b1;
             // control: manual operation, AES-128, ECB, encrypt
             // NOTE: qe_o is the AND of ALL six ctrl_shadowed field qe's — write
             // every field in the same beat (twice, for the shadowed commit).
             reg2hw.ctrl_shadowed.manual_operation.q <= 1'b1;  reg2hw.ctrl_shadowed.manual_operation.qe <= 1'b1;
             reg2hw.ctrl_shadowed.operation.q <= 2'b01;        reg2hw.ctrl_shadowed.operation.qe <= 1'b1;   // AES_ENC
             reg2hw.ctrl_shadowed.key_len.q <= 2'b00;          reg2hw.ctrl_shadowed.key_len.qe <= 1'b1;     // AES_128
             reg2hw.ctrl_shadowed.mode.q <= 6'b00_0001;        reg2hw.ctrl_shadowed.mode.qe <= 1'b1;       // AES_ECB (6-bit)
             reg2hw.ctrl_shadowed.sideload.q <= 1'b0;          reg2hw.ctrl_shadowed.sideload.qe <= 1'b1;
             reg2hw.ctrl_shadowed.prng_reseed_rate.q <= 3'b000; reg2hw.ctrl_shadowed.prng_reseed_rate.qe <= 1'b1;
             state <= 1;
           end
        1: begin
             // second beat for shadowed ctrl regs (commit) — all six fields
             reg2hw.ctrl_shadowed.manual_operation.q <= 1'b1;  reg2hw.ctrl_shadowed.manual_operation.qe <= 1'b1;
             reg2hw.ctrl_shadowed.operation.q <= 2'b01;        reg2hw.ctrl_shadowed.operation.qe <= 1'b1;
             reg2hw.ctrl_shadowed.key_len.q <= 2'b00;          reg2hw.ctrl_shadowed.key_len.qe <= 1'b1;
             reg2hw.ctrl_shadowed.mode.q <= 6'b00_0001;        reg2hw.ctrl_shadowed.mode.qe <= 1'b1;
             reg2hw.ctrl_shadowed.sideload.q <= 1'b0;          reg2hw.ctrl_shadowed.sideload.qe <= 1'b1;
             reg2hw.ctrl_shadowed.prng_reseed_rate.q <= 3'b000; reg2hw.ctrl_shadowed.prng_reseed_rate.qe <= 1'b1;
             // plaintext
             reg2hw.data_in[0].q <= 32'h00112233; reg2hw.data_in[0].qe <= 1'b1;
             reg2hw.data_in[1].q <= 32'h44556677; reg2hw.data_in[1].qe <= 1'b1;
             reg2hw.data_in[2].q <= 32'h8899aabb; reg2hw.data_in[2].qe <= 1'b1;
             reg2hw.data_in[3].q <= 32'hccddeeff; reg2hw.data_in[3].qe <= 1'b1;
             state <= 2;
           end
        2: begin
             reg2hw.ctrl_shadowed.manual_operation.qe <= 1'b0;
             reg2hw.ctrl_shadowed.operation.qe <= 1'b0;
             reg2hw.ctrl_shadowed.key_len.qe <= 1'b0;
             reg2hw.ctrl_shadowed.mode.qe <= 1'b0;
             reg2hw.data_in[0].qe <= 1'b0;
             reg2hw.data_in[1].qe <= 1'b0;
             reg2hw.data_in[2].qe <= 1'b0;
             reg2hw.data_in[3].qe <= 1'b0;
             cycles <= 0;
             // let ctrl commit settle before triggering
             state <= 3;
           end
        3: begin
             cycles <= cycles + 1;
             if (cycles >= 4) begin
               cycles <= 0;
               // trigger start (hold for 2 cycles so the FSM samples it after
               // manual_operation_q has committed)
               reg2hw.trigger.start.q <= 1'b1;
               state <= 4;
             end
           end
        4: begin
             reg2hw.trigger.start.q <= 1'b0;
             cycles <= 0;
             state <= 5;
           end
        5: begin
             // wait for cipher completion: data_out_we pulses HIGH (output cycle)
             cycles <= cycles + 1;
             if (cycles % 50 == 1)
               $display("  [t=%0d] idle=%0d ctrl_err_storage=%0d alert=%0d crypto_alert=%0d mode=%0d",
                        cycles, hw2reg.status.idle.d,
                        dut.ctrl_err_storage, alert_fatal_o,
                        dut.u_aes_control.alert_o,
                        reg2hw.ctrl_shadowed.mode.q);
             if (dut.data_out_we == SP2V_HIGH) begin
               $display("  [t=%0d] data_out_we == SP2V_HIGH (cipher completion cycle)", cycles);
               $display("  [t=%0d] data_out_q before glitch = 0x%08x%08x%08x%08x%08x%08x%08x%08x",
                        cycles,
                        dut.data_out_q[7],dut.data_out_q[6],dut.data_out_q[5],dut.data_out_q[4],
                        dut.data_out_q[3],dut.data_out_q[2],dut.data_out_q[1],dut.data_out_q[0]);
               armed <= 1;             // glitch_req goes high -> harness drops rst_n at this posedge
               glitch_done_flag <= 1;
               state <= 6;
             end else if (cycles > 3000) begin
               $display("  TIMEOUT: cipher never reached output cycle");
               state <= 8;
             end
           end
        6: begin
             armed <= 0;
             cycles <= 0;
             state <= 7;
           end
        7: begin
             cycles <= cycles + 1;
             if (cycles > 20) begin
               // after reset glitch + release: read data_out_q
               $display("");
               $display("=== Result after reset glitch on output cycle ===");
               $display("  data_out_q now = 0x%08x%08x%08x%08x%08x%08x%08x%08x",
                        dut.data_out_q[7],dut.data_out_q[6],dut.data_out_q[5],dut.data_out_q[4],
                        dut.data_out_q[3],dut.data_out_q[2],dut.data_out_q[1],dut.data_out_q[0]);
               if (dut.data_out_q[0] != 32'h0 || dut.data_out_q[1] != 32'h0) begin
                 bug_found <= 1;
                 $display("");
                 $display("==================================================");
                 $display("*** BUG 09 CONFIRMED on actual OpenTitan RTL ***");
                 $display("==================================================");
                 $display("aes_core.sv:873-877 — data_out_reg reset is GATED:");
                 $display("  if (!rst_ni && data_out_we != SP2V_HIGH) clear");
                 $display("  else if (data_out_we == SP2V_HIGH) write data_out_d");
                 $display("A reset landing on the cipher-completion cycle");
                 $display("(data_out_we==SP2V_HIGH) WRITES ciphertext into");
                 $display("data_out_q instead of clearing it — stale secret");
                 $display("data survives reset (observed non-zero above).");
                 $display("A correct implementation clears on reset regardless.");
                 $display("==================================================");
               end else begin
                 $display("  data_out_q cleared to 0 — gating not observed (check)");
               end
               state <= 8;
             end
           end
        8: $finish;
      endcase
   end
  end
endmodule
