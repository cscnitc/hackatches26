// Bug #16: AES data_out_reg — data survives reset when write-enable is active
// Source: new-opentitan/opentitan/hw/ip/aes/rtl/aes_core.sv lines 872-878
// MD5 verified identical to actual RTL
//
// Buggy logic (replicated exactly):
//   always_ff @(posedge clk_i or negedge rst_ni) begin : data_out_reg
//     if (!rst_ni && data_out_we != SP2V_HIGH)   
//       data_out_q <= '0;          // reset ONLY when WE != HIGH
//     else if (data_out_we == SP2V_HIGH)
//       data_out_q <= data_out_d;  // writes during reset!
//   end
// SP2V_HIGH = 3'b011 (sparse enum from aes_pkg)

module top (
  input clk_i,
  input rst_ni,           // AFL bit 0
  input [2:0] data_out_we, // AFL bits 3:1 — 3'b011 = SP2V_HIGH
  input [127:0] data_in,   // AFL bits 131:4
  output logic bug_found_o
);
  localparam logic [2:0] SP2V_HIGH = 3'b011;  // from aes_pkg
  logic [127:0] data_out_q;
  
  // Exact replication of aes_core.sv:872-878
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni && data_out_we != SP2V_HIGH)
      data_out_q <= '0;
    else if (data_out_we == SP2V_HIGH)
      data_out_q <= data_in;
  end
  
  // Detection: data_out_q non-zero right after reset deassertion
  // Fast: check on first cycle after reset rises
  logic rst_was_low;
  always_ff @(posedge clk_i) begin
    rst_was_low <= !rst_ni;
    bug_found_o <= rst_was_low && rst_ni && (|data_out_q);
  end

endmodule
