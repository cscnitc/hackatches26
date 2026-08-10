// Bug #22: entropy_src_markov_ht health test dead — ACTUAL RTL test (CORRECTED)
// Instantiates entropy_src_markov_ht.sv from hw/ip/entropy_src/rtl (competition RTL)
//
// Bug: entropy_src_markov_ht.sv — `test_fail_hi_pulse_o` never fires even when
// the entropy stream genuinely violates the high threshold.
//
// CORRECTED STIMULUS (vs. earlier draft): the Markov hi counter counts PAIRS
// of differing bits (0b01 / 0b10 transitions) — see
// entropy_src_markov_ht.sv:59-60 and the `samples_no_match_pulse` term
// (`prev_sample_q == !entropy_bit_i`). Feeding 40 identical bits yields a
// pair count of 0 (it would only ever matter for the LO-repetition test), so
// the earlier draft's "repeated bits exceed thresh_hi" premise was wrong.
//
// A stream that genuinely violates thresh_hi is an ALTERNATING pattern
// (0101...): every pair is a 01/10 transition, so the pair counter climbs by
// 1 per valid bit. thresh_hi_i=4 means 4+ consecutive alternating pairs must
// trip the high-side failure. We feed 40 alternating bits (way past 4) and
// assert the failure pulse should fire — but the planted RTL keeps it at 0.

module tb(
  input logic clk,
  input logic rst_n,
  output logic [7:0] state,
  output logic bug_found
);
  import entropy_src_pkg::*;

  parameter int RegWidth = 16;
  parameter int RngBusWidth = 4;

  logic [RngBusWidth-1:0] entropy_bit_i;
  logic entropy_bit_vld_i;
  logic rng_bit_en_i;
  logic [1:0] rng_bit_sel_i;
  logic clear_i, active_i;
  logic [RegWidth-1:0] thresh_hi_i, thresh_lo_i;
  logic window_wrap_pulse_i, threshold_scope_i;
  logic [RegWidth-1:0] test_cnt_hi_o, test_cnt_lo_o;
  logic test_fail_hi_pulse_o, test_fail_lo_pulse_o, count_err_o;

  entropy_src_markov_ht dut (
    .clk_i(clk), .rst_ni(rst_n),
    .entropy_bit_i, .entropy_bit_vld_i,
    .rng_bit_en_i, .rng_bit_sel_i,
    .clear_i, .active_i,
    .thresh_hi_i, .thresh_lo_i,
    .window_wrap_pulse_i, .threshold_scope_i,
    .test_cnt_hi_o, .test_cnt_lo_o,
    .test_fail_hi_pulse_o, .test_fail_lo_pulse_o, .count_err_o
  );

  logic [7:0] bit_count;
  logic [3:0] cur_bit;

  // Feed an ALTERNATING stream (0101...) — each pair is a 01/10 transition,
  // so the hi pair-counter climbs 1/bit and exceeds thresh_hi=4 after 5 bits.
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= 0;
      entropy_bit_i <= '0;
      entropy_bit_vld_i <= 0;
      rng_bit_en_i <= 0;
      rng_bit_sel_i <= 2'b00;
      clear_i <= 0;
      active_i <= 0;
      thresh_hi_i <= 16'h4;
      thresh_lo_i <= 16'h1;
      window_wrap_pulse_i <= 0;
      threshold_scope_i <= 0;
      bit_count <= 0;
      cur_bit <= 4'b0;
      bug_found <= 0;
    end else begin
      case (state)
        0: begin
             active_i <= 1;
             rng_bit_en_i <= 1;
             rng_bit_sel_i <= 2'b00;
             bit_count <= 0;
             cur_bit <= 4'b0;
             state <= 1;
           end
        1: begin
             // alternating: value TOGGLES 0,1,0,1,... each valid bit — every
             // consecutive pair is a 01/10 transition (prev != current).
             entropy_bit_i <= ~entropy_bit_i;   // 4'b0000 -> 4'b1111 -> ...
             entropy_bit_vld_i <= 1;
             bit_count <= bit_count + 1;
             if (bit_count >= 40) state <= 2;   // 40 bits, far past thresh_hi=4
           end
        2: begin
             entropy_bit_vld_i <= 0;
             bit_count <= 0;
             state <= 3;
           end
        3: begin
             // settle: counters update a few cycles after the last valid bit
             bit_count <= bit_count + 1;
             if (bit_count >= 5) state <= 4;
           end
        4: begin
             $display("=== After 40-bit ALTERNATING stream (all 01/10 pairs) ===");
             $display("  thresh_hi_i=4 -> 40 alternating pairs should trip hi");
             $display("  test_cnt_hi_o=%0d test_fail_hi_pulse_o=%b test_fail_lo_pulse_o=%b",
                      test_cnt_hi_o, test_fail_hi_pulse_o, test_fail_lo_pulse_o);
             $display("  (pair_cntr[0] internal = %0d)", dut.pair_cntr[0]);
             if (test_cnt_hi_o > 4 && test_fail_hi_pulse_o === 1'b0) begin
               bug_found <= 1;
               $display("");
               $display("==================================================");
               $display("*** BUG #22 CONFIRMED on actual OpenTitan RTL ***");
               $display("==================================================");
               $display("entropy_src_markov_ht.sv hardwires/fails to raise");
               $display("test_fail_hi_pulse_o even though the hi pair counter");
               $display("exceeded thresh_hi (%0d > 4) — hi-side health test dead.",
                        test_cnt_hi_o);
               $display("");
               $display("Impact: high-threshold Markov (transition-count)");
               $display("violations are never reported; biased/cyclic entropy");
               $display("can pass the health check undetected.");
               $display("==================================================");
             end else if (test_cnt_hi_o <= 4) begin
               $display("  (counter did not exceed threshold — stimulus check)");
             end else begin
               $display("  test_fail_hi_pulse_o=%b — hi test fired (bug not present?)",
                        test_fail_hi_pulse_o);
             end
             state <= 5;
           end
        5: $finish;
      endcase
    end
  end
endmodule
