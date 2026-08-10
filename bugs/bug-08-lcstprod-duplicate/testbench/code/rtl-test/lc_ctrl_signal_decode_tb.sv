// Bug #7: LC signal decode — LcStProd in TWO unique case branches — ACTUAL RTL test
// Instantiates lc_ctrl_signal_decode.sv from hw/ip/lc_ctrl/rtl (competition RTL)
//
// Bug: lc_ctrl_signal_decode.sv:116 and :139 — LcStProd appears in TWO branches
// of a `unique case`. In LcStProd (PRODUCTION), the first branch (116) enables
// lc_raw_test_rma, lc_dft_en, lc_nvm_debug_en — debug/DFT features that MUST be
// OFF in production. The unique-case overlap is a violation; synthesis picks one
// branch, and the security-relevant enable signals become wrong.

module tb(
  input logic clk,
  input logic rst_n,
  output logic [3:0] state,
  output logic bug_found
);
  import lc_ctrl_pkg::*;
  import lc_ctrl_state_pkg::*;

  logic lc_state_valid_i;
  lc_state_e lc_state_i;
  fsm_state_e fsm_state_i;
  lc_tx_t secrets_valid_i;
  lc_tx_t lc_raw_test_rma_o;
  lc_tx_t lc_dft_en_o;
  lc_tx_t lc_nvm_debug_en_o;
  lc_tx_t lc_hw_debug_en_o;
  lc_tx_t lc_cpu_en_o;
  lc_tx_t lc_creator_seed_sw_rw_en_o;
  lc_tx_t lc_owner_seed_sw_rw_en_o;
  lc_tx_t lc_iso_part_sw_rd_en_o;
  lc_tx_t lc_iso_part_sw_wr_en_o;
  lc_tx_t lc_seed_hw_rd_en_o;
  lc_tx_t lc_keymgr_en_o;
  lc_tx_t lc_escalate_en_o;
  lc_keymgr_div_t lc_keymgr_div_o;

  lc_ctrl_signal_decode dut (
    .clk_i(clk), .rst_ni(rst_n),
    .lc_state_valid_i, .lc_state_i, .fsm_state_i, .secrets_valid_i,
    .lc_raw_test_rma_o, .lc_dft_en_o, .lc_nvm_debug_en_o, .lc_hw_debug_en_o,
    .lc_cpu_en_o, .lc_creator_seed_sw_rw_en_o, .lc_owner_seed_sw_rw_en_o,
    .lc_iso_part_sw_rd_en_o, .lc_iso_part_sw_wr_en_o, .lc_seed_hw_rd_en_o,
    .lc_keymgr_en_o, .lc_escalate_en_o, .lc_keymgr_div_o
  );

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= 0;
      lc_state_valid_i <= 0;
      lc_state_i <= LcStRaw;
      fsm_state_i <= InvalidSt;
      secrets_valid_i <= Off;
      bug_found <= 0;
    end else begin
      case (state)
        0: begin
             // Put device in PRODUCTION state
             lc_state_valid_i <= 1;
             lc_state_i <= LcStProd;
             fsm_state_i <= PostTransSt;
             secrets_valid_i <= Off;
             state <= 1;
           end
        1: begin
             state <= 2;
           end
        2: begin
             $display("=== LC state = LcStProd (PRODUCTION) ===");
             $display("  lc_raw_test_rma_o   = %b (should be OFF in prod)", lc_raw_test_rma_o);
             $display("  lc_dft_en_o         = %b (should be OFF in prod)", lc_dft_en_o);
             $display("  lc_nvm_debug_en_o   = %b (should be OFF in prod)", lc_nvm_debug_en_o);
             $display("  lc_hw_debug_en_o    = %b (should be OFF in prod)", lc_hw_debug_en_o);
             $display("  lc_cpu_en_o         = %b (should be ON in prod)", lc_cpu_en_o);
             $display("  lc_keymgr_en_o      = %b (should be ON in prod)", lc_keymgr_en_o);
             // BUG: unique case has LcStProd in TWO branches — production
             // gets debug/DFT features enabled (raw_test_rma, dft, nvm_debug)
             // lc_tx_t: On = 4'b1010, Off = 4'b0101
             if (lc_dft_en_o === 4'b1010 || lc_nvm_debug_en_o === 4'b1010 || lc_raw_test_rma_o === 4'b1010) begin
               bug_found <= 1;
               $display("");
               $display("==================================================");
               $display("*** BUG #7 CONFIRMED on actual OpenTitan RTL ***");
               $display("==================================================");
               $display("LcStProd (PRODUCTION) in TWO unique case branches");
               $display("(lc_ctrl_signal_decode.sv:116 and :139).");
               $display("Production device has DFT/debug/raw-test features");
               $display("ENABLED (dft_en/nvm_debug_en/raw_test_rma = On).");
               $display("");
               $display("Impact: debug & test access open in production,");
               $display("enabling readout of secrets / debug attacks.");
               $display("==================================================");
             end else begin
               $display("Debug features OFF — branch selection differs (check)");
             end
             state <= 3;
           end
        3: $finish;
      endcase
    end
  end
endmodule
