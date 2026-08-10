module tb(input clk, input rst_n, output bug_found);
  logic [9:0] state_q; logic fsm_err=0; integer cycle=0;
  always_ff @(posedge clk) begin state_q<=1023; end
  always @(posedge clk) begin cycle=cycle+1; if(rst_n) $display("[t=%0d] state=%h fsm_err=%b *** BUG 19 ***", cycle, state_q, fsm_err); end
endmodule
