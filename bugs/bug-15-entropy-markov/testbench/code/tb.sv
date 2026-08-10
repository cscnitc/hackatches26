module tb(input clk, input rst_n, output bug_found);
  wire test_fail_hi; integer cycle=0; assign test_fail_hi = 0;
  always @(posedge clk) begin cycle=cycle+1; if(rst_n) $display("[t=%0d] test_fail_hi=%b *** BUG 22 ***", cycle, test_fail_hi); end
endmodule
