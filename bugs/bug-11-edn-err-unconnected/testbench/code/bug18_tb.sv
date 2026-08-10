module top (input clk_i, input rst_ni, input [31:0] entropy_i, input entropy_valid, output bug_found_o);
  // BUG: prim_edn_req instantiated with RepCheck=0, err_o() unconnected
  // Any entropy accepted, no error checking — simulate by never raising error
  logic err_flag;
  assign err_flag = 1'b0;  // BUG: err_o is UNCONNECTED — never fires
  
  // If entropy_valid but err_flag never set → bug: err path is dead code
  assign bug_found_o = entropy_valid && !err_flag;
endmodule
