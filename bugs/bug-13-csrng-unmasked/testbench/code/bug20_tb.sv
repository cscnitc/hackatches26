module tb(input clk, input rst_n);
  localparam bit SecMasking = 1'b0; integer cycle;
  always @(posedge clk) begin cycle <= cycle + 1; if(rst_n) $display("[t=%0d] SecMasking=%b *** BUG: AES unmasked ***", cycle, SecMasking); end
endmodule
