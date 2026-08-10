module tb(input clk, input rst_n, output bug_found);
  integer cycle=0;
  always @(posedge clk) begin cycle<=cycle+1; if(rst_n) $display("[t=%0d] LcStProd in two unique case branches *** BUG #7 ***", cycle); end
endmodule
