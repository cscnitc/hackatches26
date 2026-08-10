// keymgr_key_check_buggy.sv — Buggy version from OpenTitan keymgr_input_checks
// BUG #10: key_vld_o missing key_i.valid check at line 99
// Original: assign key_vld_o = &key_chk;
// Note: valid_chk(x) = |x & ~&x (not all zeros, not all ones)

module keymgr_key_check_buggy #(
  parameter int KeyWidth = 256,
  parameter int Shares   = 2
) (
  input  logic                           valid_i,
  input  logic [Shares-1:0][KeyWidth-1:0] key_i,
  output logic                           key_vld_o
);

  // valid_chk: not all zeros and not all ones
  function automatic logic valid_chk(input logic [KeyWidth-1:0] value);
    return |value & ~&value;
  endfunction

  logic [Shares-1:0] key_chk;

  for (genvar s = 0; s < Shares; s++) begin : gen_key_chk
    assign key_chk[s] = valid_chk(key_i[s]);
  end

  // BUG: missing valid_i check — should be: key_i.valid & &key_chk
  assign key_vld_o = &key_chk;

endmodule
