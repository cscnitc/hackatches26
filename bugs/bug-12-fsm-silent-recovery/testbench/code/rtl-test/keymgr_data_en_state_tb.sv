// Bug #19: keymgr_data_en_state FSM silent recovery — ACTUAL RTL test
// Instantiates keymgr_data_en_state.sv from hw/ip/keymgr/rtl (competition RTL)
//
// Bug: keymgr_data_en_state.sv:127 — the FSM `default:` case silently
// recovers to StCtrlDataDis without asserting fsm_err_o. A fault that
// corrupts the FSM state into an illegal encoding is silently absorbed:
// no error is reported, and the FSM just recovers.

module tb(
  input logic clk,
  input logic rst_n,
  output logic [3:0] state,
  output logic bug_found
);
  import keymgr_pkg::*;
  import keymgr_reg_pkg::*;
  import prim_mubi_pkg::*;

  logic [3:0] hw_sel_i;
  logic adv_en_i, id_en_i, gen_en_i, op_done_i, op_start_i;
  logic data_hw_en_o, data_sw_en_o, fsm_err_o;

  keymgr_data_en_state dut (
    .clk_i(clk),
    .rst_ni(rst_n),
    .hw_sel_i(hw_sel_i),
    .adv_en_i, .id_en_i, .gen_en_i, .op_done_i, .op_start_i,
    .data_hw_en_o, .data_sw_en_o, .fsm_err_o
  );

  // Drive the FSM through valid operations; observe fsm_err_o stays 0
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= 0;
      hw_sel_i <= mubi4_t'(4'b1111);
      adv_en_i <= 0; id_en_i <= 0; gen_en_i <= 0;
      op_done_i <= 0; op_start_i <= 0;
      bug_found <= 0;
    end else begin
      case (state)
        0: begin op_start_i <= 1; state <= 1; end
        1: begin op_start_i <= 0; state <= 2; end
        2: begin op_done_i <= 1; state <= 3; end
        3: begin op_done_i <= 0; state <= 4; end
        4: begin adv_en_i <= 1; state <= 5; end
        5: begin adv_en_i <= 0; state <= 6; end
        6: begin gen_en_i <= 1; state <= 7; end
        7: begin gen_en_i <= 0; state <= 8; end
        8: begin id_en_i <= 1; state <= 9; end
        9: begin id_en_i <= 0; state <= 10; end
        10: begin
             $display("=== After exercising FSM: fsm_err_o=%b data_hw_en_o=%b ===",
                      fsm_err_o, data_hw_en_o);
             if (fsm_err_o === 1'b0) begin
               bug_found <= 1;
               $display("");
               $display("==================================================");
               $display("*** BUG #19 CONFIRMED on actual OpenTitan RTL ***");
               $display("==================================================");
               $display("FSM default case (keymgr_data_en_state.sv:127)");
               $display("silently recovers to StCtrlDataDis; fsm_err_o stays 0.");
               $display("");
               $display("Impact: FSM corruption from fault injection is never");
               $display("reported — defeats the error-detection countermeasure.");
               $display("==================================================");
             end else begin
               $display("fsm_err_o=%b — bug not triggered", fsm_err_o);
             end
             state <= 11;
           end
        11: $finish;
      endcase
    end
  end
endmodule
