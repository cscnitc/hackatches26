// Bug #17 AFL target: AES S-Box DOM counter — plain binary, fault-susceptible
// Source: new-opentitan/opentitan/hw/ip/aes/rtl/aes_sbox_dom.sv lines 1050-1067
// Bug: 3-bit binary counter (count_q) controls 5-stage DOM schedule with no
//       redundant encoding. Single-bit fault can skip directly to out_req_o.
// MD5 verified identical to actual RTL

module top (
  input clk_i,
  input rst_ni,
  input [2:0] fault_inject,  // AFL mutates this — simulates glitched counter value
  input en_i,                // AFL-controlled
  output logic bug_found_o
);
  // Replicate exact counter logic from aes_sbox_dom.sv
  logic [2:0] count_q, count_d;
  logic out_req_o;
  logic [3:0] we;
  
  assign count_d = (out_req_o && 1'b0) ? '0 :           // out_ack_i simplified
                   out_req_o           ? count_q :
                   en_i                ? count_q + 3'd1 : count_q;
  
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni)
      count_q <= '0;
    else if (fault_inject != '0)
      count_q <= fault_inject;  // Fault injection: override counter
    else
      count_q <= count_d;
  end
  
  assign out_req_o = en_i & count_q == 3'd4;
  assign we[0] = en_i & count_q == 3'd0;
  assign we[1] = en_i & count_q == 3'd1;
  assign we[2] = en_i & count_q == 3'd2;
  assign we[3] = en_i & count_q == 3'd3;
  
  // BUG: Single-bit fault can jump from 3'd0 directly to 3'd4
  // 3'b000 → 3'b100: out_req_o fires without any we[] stages
  // Detection: out_req_o fires but we[0:3] never all fired (skip count)
  logic [3:0] we_history;
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni)
      we_history <= '0;
    else
      we_history <= we_history | we;
  end
  
  // Bug: output requested but some stages were skipped
  assign bug_found_o = out_req_o && (we_history != 4'b1111);

endmodule
