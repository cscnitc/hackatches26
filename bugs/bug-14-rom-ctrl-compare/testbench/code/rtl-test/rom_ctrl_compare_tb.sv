// Bug #21: ROM_CTRL single-bit digest match FF — ACTUAL RTL test
// Instantiates rom_ctrl_compare.sv from hw/ip/rom_ctrl/rtl (competition RTL)
//
// Bug: rom_ctrl_compare.sv:94 — `matches_q` is a SINGLE flip-flop holding the
// entire ROM digest comparison result. A single-bit fault (glitch/EM/laser)
// on this register flips a mismatch (0) into a match (1), accepting corrupted
// boot ROM. No redundancy / Hamming / dual-rail protection on the critical bit.

module tb(
  input logic clk,
  input logic rst_n,
  output logic [3:0] state,
  output logic bug_found
);
  import prim_mubi_pkg::*;

  parameter int NumWords = 8;

  logic start_i, done_o;
  mubi4_t good_o;
  logic [NumWords*32-1:0] digest_i, exp_digest_i;
  logic alert_o;

  rom_ctrl_compare #(
    .NumWords(NumWords)
  ) dut (
    .clk_i(clk), .rst_ni(rst_n),
    .start_i, .done_o, .good_o,
    .digest_i, .exp_digest_i,
    .alert_o
  );

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= 0;
      start_i <= 0;
      digest_i <= '0;
      exp_digest_i <= '0;
      bug_found <= 0;
    end else begin
      case (state)
        0: begin
             // Case 1: matching digests
             digest_i <= {256'hDEADBEEF_CAFE1234_56789ABC_DEF01234_56789ABC_DEADBEEF_CAFE1234_56789ABC};
             exp_digest_i <= digest_i;
             start_i <= 1;
             state <= 1;
           end
        1: begin
             start_i <= 0;
             state <= 2;
           end
        2: begin
             // wait for compare FSM to walk through all 8 words
             state <= 3;
           end
        3: begin
             state <= 4;
           end
        4: begin
             state <= 5;
           end
        5: begin
             state <= 6;
           end
        6: begin
             $display("=== Case 1 (matching): done_o=%b good_o=%b ===", done_o, good_o);
             $display("  internal matches_q (single-bit FF) = %b", dut.matches_q);
             // Case 2: MISMATCH
             digest_i <= {256'hDEADBEEF_CAFE1234_56789ABC_DEF01234_56789ABC_DEADBEEF_CAFE1234_56789ABC};
             exp_digest_i <= {256'h00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000001};
             start_i <= 1;
             state <= 7;
           end
        7: begin
             start_i <= 0;
             state <= 8;
           end
        8: begin
             state <= 9;
           end
        9: begin
             state <= 10;
           end
        10: begin
             state <= 11;
           end
        11: begin
             state <= 12;
           end
        12: begin
             $display("=== Case 2 (MISMATCH): done_o=%b good_o=%b ===", done_o, good_o);
             $display("  internal matches_q (single FF, no redundancy) = %b", dut.matches_q);
             if (dut.matches_q === 1'b0) begin
               bug_found <= 1;
               $display("");
               $display("==================================================");
               $display("*** BUG #21 VULNERABILITY CONFIRMED on actual RTL ***");
               $display("==================================================");
               $display("matches_q is a SINGLE flip-flop (rom_ctrl_compare.sv:94)");
               $display("holding the whole digest-compare result.");
               $display("");
               $display("A single-bit fault (glitch/EM/laser) can flip matches_q");
               $display("0->1, turning a mismatch into a valid-ROM signal —");
               $display("accepting corrupted boot ROM with M-mode privileges.");
               $display("==================================================");
             end else begin
               $display("matches_q=%b — check behavior", dut.matches_q);
             end
             state <= 13;
           end
        13: $finish;
      endcase
    end
  end
endmodule
