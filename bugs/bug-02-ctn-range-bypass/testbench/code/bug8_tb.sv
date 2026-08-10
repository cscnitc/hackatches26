module tb(input clk, input rst_n);
  wire ovr = 1'b1; integer cycle;
  always @(posedge clk) begin cycle <= cycle + 1; if(rst_n) $display("[t=%0d] ac_range_check_overwrite=%b *** BUG: MuBi8True ***", cycle, ovr); end
endmodule
