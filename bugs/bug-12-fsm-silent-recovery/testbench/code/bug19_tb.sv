module top (input clk_i, input rst_ni, input [9:0] state_in, input state_load, output bug_found_o);
  localparam StIdle=10h001, StAdv=10h002, StGetE=10h004, StProc=10h008, StWait=10h010, StDone=10h020, StErr=10h040;
  logic [9:0] state_q;
  logic fsm_err_o;
  logic was_illegal;
  
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin state_q<=StIdle; was_illegal<=0; end
    else begin
      if (state_load) state_q <= state_in;
      case (state_q)
        StIdle,StAdv,StGetE,StProc,StWait,StDone,StErr: ;
        default: was_illegal <= 1;
      endcase
    end
  end
  
  assign fsm_err_o = 1'b0;  // BUG: never set
  assign bug_found_o = was_illegal && !fsm_err_o;
endmodule
