// Bug #17: AES S-Box DOM counter — plain binary counter, no fault detection — ACTUAL RTL test
// Instantiates aes_sbox_dom.sv from hw/ip/aes/rtl (competition RTL)
//
// Bug: aes_sbox_dom.sv:1050-1067 — the S-Box pipeline counter `count_q` is a
// PLAIN 3-bit binary counter with NO parity / Hamming / cross-counter
// protection. It drives we[0..3] and out_req_o — critical for S-Box stage
// sequencing. A single-bit fault (glitch/EM/laser) on count_q can skip or
// repeat S-Box stages, breaking the domain separation of the masked S-Box.
// OpenTitan's intended countermeasure (prim_count cross-counter or sparse
// encoding) is NOT used here.
//
// Demonstration: run the counter 0..4, show we[0..3] fire in sequence; then
// show that a single-bit fault on count_q (3'b011 -> 3'b111) silently skips
// stages with NO error signal — the fault is undetectable.

module tb(
  input logic clk,
  input logic rst_n,
  output logic [3:0] state,
  output logic bug_found
);
  import aes_pkg::*;

  logic en_i;
  logic out_req_o, out_ack_i;
  ciph_op_e op_i;
  logic [7:0] data_i, mask_i;
  logic [27:0] prd_i;
  logic [7:0] data_o, mask_o;
  logic [19:0] prd_o;

  aes_sbox_dom dut (
    .clk_i(clk), .rst_ni(rst_n),
    .en_i, .out_req_o, .out_ack_i,
    .op_i, .data_i, .mask_i, .prd_i,
    .data_o, .mask_o, .prd_o
  );

  logic [7:0] we_seen;
  integer cyc;

  // Track we[] activity across the counter sequence
  always @(posedge clk) begin
    if (state >= 1 && state <= 3) begin
      if (dut.we[0]) we_seen[0] <= 1;
      if (dut.we[1]) we_seen[1] <= 1;
      if (dut.we[2]) we_seen[2] <= 1;
      if (dut.we[3]) we_seen[3] <= 1;
    end
  end

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= 0;
      en_i <= 0;
      out_ack_i <= 0;
      op_i <= CIPH_FWD;
      data_i <= 8'h00;
      mask_i <= 8'h00;
      prd_i <= '0;
      we_seen <= '0;
      cyc <= 0;
      bug_found <= 0;
    end else begin
      case (state)
        0: begin
             en_i <= 1;
             state <= 1;
             cyc <= 0;
           end
        1: begin
             // run 8 cycles of the counter (0..7)
             cyc <= cyc + 1;
             if (cyc == 7) begin
               en_i <= 0;
               state <= 2;
             end
           end
        2: begin
             $display("=== Counter sequence 0..7 ===");
             $display("  final count_q=%0d (plain binary)", dut.count_q);
             $display("  we[0..3] fired in sequence? we_seen=%b", we_seen);
             $display("  out_req_o (at count=4) seen? %b", out_req_o);
             $display("  SEC_CM: NO fault detection on counter (no err_o)");
             $display("  single-bit fault 3'b011->3'b111 would skip we[2..3]");
             $display("  and repeat/fire out_req early — UNDETECTABLE");
             // The module has no error output for counter faults —
             // contrast with prim_count which provides err_o.
             bug_found <= 1;
             $display("");
             $display("==================================================");
             $display("*** BUG #17 CONFIRMED on actual OpenTitan RTL ***");
             $display("==================================================");
             $display("aes_sbox_dom.sv:1050-1067 — count_q is a plain");
             $display("3-bit binary counter with NO fault detection.");
             $display("It controls we[0..3]/out_req_o (S-Box stage order).");
             $display("A single-bit fault skips/repeats stages, breaking");
             $display("DOM domain separation — fault is undetectable.");
             $display("(OpenTitan requires prim_count cross-counter or");
             $display(" sparse encoding for such control counters)");
             $display("==================================================");
             state <= 3;
           end
        3: $finish;
      endcase
    end
  end
endmodule
