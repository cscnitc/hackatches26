module tb(input clk, input rst_n);
  localparam LcStProd=4;
  logic [2:0] state = LcStProd;
  logic dft, dbg, keymgr;
  integer cycle;
  always @(posedge clk) begin cycle <= cycle + 1; if(rst_n) begin
    dft=0;dbg=0;keymgr=0;
    unique case(state) 2: begin dft=1;dbg=1; end 4: begin end 4: begin keymgr=1; end default: ; endcase
    $display("[t=%0d] state=%0d dft=%b dbg=%b keymgr=%b *** BUG ***", cycle, state, dft, dbg, keymgr);
  end end
endmodule
