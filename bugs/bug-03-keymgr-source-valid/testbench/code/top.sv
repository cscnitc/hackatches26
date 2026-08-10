// top.sv — Differential fuzzing wrapper
// Instantiates both buggy and fixed keymgr_key_check modules,
// feeds identical inputs, exposes both outputs for comparison.

module top #(
  parameter int KeyWidth = 256,
  parameter int Shares   = 2
) (
  input  logic                           clk,
  input  logic                           valid_i,
  input  logic [Shares-1:0][KeyWidth-1:0] key_i,
  output logic                           buggy_vld_o,
  output logic                           fixed_vld_o
);

  keymgr_key_check_buggy #(
    .KeyWidth(KeyWidth),
    .Shares(Shares)
  ) u_buggy (
    .valid_i  (valid_i),
    .key_i    (key_i),
    .key_vld_o(buggy_vld_o)
  );

  keymgr_key_check_fixed #(
    .KeyWidth(KeyWidth),
    .Shares(Shares)
  ) u_fixed (
    .valid_i  (valid_i),
    .key_i    (key_i),
    .key_vld_o(fixed_vld_o)
  );

endmodule
