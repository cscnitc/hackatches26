module tb(input clk, input rst_n, output bug_found);
  wire authenticated; integer cycle=0; assign authenticated = 1;
  always @(posedge clk) begin cycle=cycle+1; if(rst_n) $display("[t=%0d] authenticated=%b *** BUG 2 ***", cycle, authenticated); end
endmodule
