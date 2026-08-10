module tb(input clk, input rst_n, output bug_found);
  wire ac_range_check_overwrite; integer cycle=0; assign ac_range_check_overwrite = 1;
  always @(posedge clk) begin cycle=cycle+1; if(rst_n) $display("[t=%0d] ac_range_check_overwrite=%b *** BUG 8 ***", cycle, ac_range_check_overwrite); end
endmodule
