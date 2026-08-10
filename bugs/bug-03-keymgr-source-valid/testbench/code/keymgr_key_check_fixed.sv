// keymgr_key_check_fixed.sv — Fixed version
// Fix: key_vld_o = valid_i & &key_chk (includes key_i.valid)

module keymgr_key_check_fixed #(
  parameter int KeyWidth = 256,
  parameter int Shares   = 2
) (
  input  logic                           valid_i,
  input  logic [Shares-1:0][KeyWidth-1:0] key_i,
  output logic                           key_vld_o
);

  function automatic logic valid_chk(input logic [KeyWidth-1:0] value);
    return |value & ~&value;
  endfunction

  logic [Shares-1:0] key_chk;

  for (genvar s = 0; s < Shares; s++) begin : gen_key_chk
    assign key_chk[s] = valid_chk(key_i[s]);
  end

  // FIXED: includes valid_i
  assign key_vld_o = valid_i & &key_chk;

endmodule
