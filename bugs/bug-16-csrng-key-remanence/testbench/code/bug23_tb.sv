module tb(input clk, input rst_n);
  wire key_clear = 1'b0; integer cycle;
  always @(posedge clk) begin cycle <= cycle + 1; if(rst_n) $display("[t=%0d] key_clear=%b *** BUG: disabled ***", cycle, key_clear); end
endmodule
