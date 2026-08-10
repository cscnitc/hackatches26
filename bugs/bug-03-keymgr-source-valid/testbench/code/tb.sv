module tb(input clk, input rst_n, output logic bug_found);
  logic key_valid_in; logic [3:0] key_chk; logic key_vld_o; integer cycle=0;
  assign key_valid_in = 0; assign key_chk = 15; assign key_vld_o = &key_chk;
  always @(posedge clk) begin cycle=cycle+1; if(rst_n && key_vld_o && !key_valid_in) begin bug_found<=1; $display("[t=%0d] valid_in=%b key_vld_o=%b *** BUG 10 ***", cycle, key_valid_in, key_vld_o); end end
endmodule
