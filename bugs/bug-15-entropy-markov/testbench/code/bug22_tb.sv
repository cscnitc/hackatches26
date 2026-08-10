module tb(input clk, input rst_n);
  wire test_fail_hi = 1'b0; integer cycle;
  always @(posedge clk) begin cycle <= cycle + 1; if(rst_n) $display("[t=%0d] test_fail_hi=%b *** BUG: hardwired 0 ***", cycle, test_fail_hi); end
endmodule
