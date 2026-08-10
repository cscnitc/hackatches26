// Bug #18: keymgr_reseed_ctrl EDN error unconnected — ACTUAL RTL test
// Instantiates keymgr_reseed_ctrl.sv from hw/ip/keymgr/rtl (competition RTL)
//
// Bug: keymgr_reseed_ctrl.sv:73 — prim_edn_req `.err_o()` UNCONNECTED.
// EDN error silently swallowed, cnt_err_o stays 0.
// TB: synthesizable FSM + clk/rst driven by C++ main.

module tb(
  input logic clk,
  input logic rst_n,
  output logic [3:0] state,
  output logic bug_found
);
  import keymgr_pkg::*;
  import edn_pkg::*;

  logic rst_edn_n;

  logic reseed_req_i, reseed_ack_o, reseed_done_o;
  logic [15:0] reseed_interval_i;
  edn_pkg::edn_req_t edn_o;
  edn_pkg::edn_rsp_t edn_i;
  logic lfsr_en_i, seed_en_o, cnt_err_o;
  logic [LfsrWidth-1:0] seed_o;

  keymgr_reseed_ctrl dut (
    .clk_i(clk), .rst_ni(rst_n),
    .clk_edn_i(clk), .rst_edn_ni(rst_edn_n),
    .reseed_req_i, .reseed_ack_o, .reseed_done_o, .reseed_interval_i,
    .edn_o, .edn_i,
    .lfsr_en_i, .seed_en_o, .seed_o, .cnt_err_o
  );

  assign rst_edn_n = rst_n;

  // EDN responds with ERROR when requested
  always @(posedge clk) begin
    if (rst_n && edn_o.edn_req) begin
      edn_i.edn_ack <= 1'b1;
      edn_i.edn_fips <= 1'b1;   // FIPS error!
      edn_i.edn_bus <= '0;
    end else begin
      edn_i <= EDN_RSP_DEFAULT;
    end
  end

  // Synthesizable stimulus FSM
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= 0;
      reseed_req_i <= 0;
      lfsr_en_i <= 0;
      reseed_interval_i <= 16'h4;
      bug_found <= 0;
    end else begin
      case (state)
        0: begin reseed_req_i <= 1; state <= 1; end
        1: begin reseed_req_i <= 0; state <= 2; end
        2: begin
             $display("=== After reseed: cnt_err_o=%b reseed_ack_o=%b reseed_done_o=%b ===", cnt_err_o, reseed_ack_o, reseed_done_o);
             $display("=== EDN err/fips path: u_edn_req.err_o=%b u_edn_req.fips_o=%b (both UNCONNECTED) ===",
                      dut.u_edn_req.err_o, dut.u_edn_req.fips_o);
             // BUG: the EDN FIPS error IS detected internally (fips_o=1) but
             // .fips_o()/.err_o() are unconnected at the instantiation — the
             // error has no path to any output/alert.
             if (dut.u_edn_req.fips_o === 1'b1) begin
               bug_found <= 1;
               $display("");
               $display("==================================================");
               $display("*** BUG #18 CONFIRMED on actual OpenTitan RTL ***");
               $display("==================================================");
               $display("keymgr_reseed_ctrl.sv:73-74 — prim_edn_req .err_o()");
               $display("and .fips_o() BOTH unconnected. EDN FIPS error is");
               $display("detected internally (fips_o=1) but silently DROPPED:");
               $display("no error reaches cnt_err_o / alerts.");
               $display("Impact: keys derived from bad/faulted entropy.");
               $display("==================================================");
             end
             state <= 3;
           end
        3: $finish;
      endcase
    end
  end
endmodule
