// Stub: Generic flop — width-matched ResetValue (matches prim_generic_flop.sv)
// CRITICAL: ResetValue must be [Width-1:0], not 1-bit, or sparse-FSM reset
// values (e.g. 16-bit sparse encodings) get truncated and the FSM resets
// to a garbage state instead of ResetSt.
module prim_flop #(
  parameter int               Width      = 1,
  parameter logic [Width-1:0] ResetValue = '0
) (
  input  logic               clk_i,
  input  logic               rst_ni,
  input  logic [Width-1:0]   d_i,
  output logic [Width-1:0]   q_o
);
  always_ff @(posedge clk_i or negedge rst_ni)
    if (!rst_ni) q_o <= ResetValue;
    else         q_o <= d_i;
endmodule
