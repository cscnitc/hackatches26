// Bug #8: CTN access-range check permanently overridden — ACTUAL RTL test
// Instantiates ac_range_check.sv from hw/top_darjeeling/ip_autogen/ac_range_check/rtl
// (competition RTL — the chiplevel.sv.tpl:844 hardcodes MuBi8True)
//
// Bug: chiplevel.sv.tpl:844 — `ac_range_check_overwrite_i = MuBi8True`
// ("TODO: Over/ride/ all access range checks for now"). This forces
// range_check_overwrite_i = MuBi8True, so the CTN access-range check ALWAYS
// grants access regardless of address range / RACL policy — the
// resource-access-control (RACL) range protection is bypassed.

module tb(
  input logic clk,
  input logic rst_n,
  output logic [3:0] state,
  output logic bug_found
);
  import prim_mubi_pkg::*;
  import top_racl_pkg::*;
  import tlul_pkg::*;
  import prim_alert_pkg::*;

  localparam int NumAlerts = 1;

  logic rst_shadowed_ni;
  alert_rx_t [NumAlerts-1:0] alert_rx_i;
  alert_tx_t [NumAlerts-1:0] alert_tx_o;
  racl_policy_vec_t racl_policies_i;
  racl_error_log_t racl_error_o;
  logic intr_deny_cnt_reached_o;
  tl_h2d_t tl_i, ctn_tl_h2d_i, ctn_filtered_tl_h2d_o;
  tl_d2h_t tl_o, ctn_tl_d2h_o, ctn_filtered_tl_d2h_i;
  mubi8_t range_check_overwrite_i;

  ac_range_check dut (
    .clk_i(clk), .rst_ni(rst_n), .rst_shadowed_ni,
    .alert_rx_i, .alert_tx_o,
    .racl_policies_i, .racl_error_o, .intr_deny_cnt_reached_o,
    .tl_i, .tl_o,
    .range_check_overwrite_i,
    .ctn_tl_h2d_i, .ctn_tl_d2h_o,
    .ctn_filtered_tl_h2d_o, .ctn_filtered_tl_d2h_i
  );

  logic range_check_grant_probe;
  assign range_check_grant_probe = dut.range_check_grant;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= 0;
      rst_shadowed_ni <= 0;
      alert_rx_i <= '{default: '0};
      racl_policies_i <= '0;
      tl_i <= TL_H2D_DEFAULT;
      ctn_tl_h2d_i <= TL_H2D_DEFAULT;
      ctn_filtered_tl_d2h_i <= TL_D2H_DEFAULT;
      // BUG: hardcoded MuBi8True (chiplevel.sv.tpl:844)
      range_check_overwrite_i <= MuBi8True;
      bug_found <= 0;
    end else begin
      case (state)
        0: begin
             rst_shadowed_ni <= 1;
             state <= 1;
           end
        1: begin
             // send a request to an address OUTSIDE any allowed range
             // (racl_policies_i = 0 => no ranges allowed)
             ctn_tl_h2d_i.a_valid <= 1'b1;
             ctn_tl_h2d_i.a_address <= 32'hDEADBEEF;  // out-of-range addr
             ctn_tl_h2d_i.a_opcode <= tlul_pkg::Get;
             state <= 2;
           end
        2: begin
             state <= 3;
           end
        3: begin
             $display("=== CTN access-range check ===");
             $display("  range_check_overwrite_i = 0x%08x (MuBi8True=%b)",
                      range_check_overwrite_i, mubi8_test_true_strict(range_check_overwrite_i));
             $display("  a_valid=%b addr=0x%08x (OUTSIDE allowed ranges, policy=0)",
                      ctn_tl_h2d_i.a_valid, ctn_tl_h2d_i.a_address);
             $display("  range_check_grant (internal) = %b (BUG: should be 0 — request denied)",
                      range_check_grant_probe);
             // BUG: with overwrite=MuBi8True, grant=1 even for out-of-range
             if (range_check_grant_probe === 1'b1) begin
               bug_found <= 1;
               $display("");
               $display("==================================================");
               $display("*** BUG #8 CONFIRMED on actual OpenTitan RTL ***");
               $display("==================================================");
               $display("chiplevel.sv.tpl:844 hardcodes range_check_overwrite");
               $display("= MuBi8True — CTN access-range check ALWAYS grants.");
               $display("Out-of-range access (addr 0xDEADBEEF) is GRANTED");
               $display("despite no RACL policy allowing it.");
               $display("");
               $display("Impact: RACL range protection bypassed — arbitrary");
               $display("memory/peripheral access from the CTN domain.");
               $display("==================================================");
             end else begin
               $display("grant=0 — overwrite not effective (check)");
             end
             state <= 4;
           end
        4: $finish;
      endcase
    end
  end
endmodule
