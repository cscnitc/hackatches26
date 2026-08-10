// Bug #2: Debug Module DMSTATUS.authenticated hardwired — ACTUAL RTL test
// Instantiates dm_csrs.sv from hw/vendor/pulp_riscv_dbg/src (competition RTL)
//
// Bug: dm_csrs.sv:231 — `dmstatus.authenticated = 1'b1;` hardwires the
// "debugger is authenticated" bit to TRUE with comment "no authentication
// implemented". A DMI read of DMSTATUS returns authenticated=1 with NO
// AuthData handshake performed.

module tb(
  input logic clk,
  input logic rst_n,
  output logic [3:0] state,
  output logic bug_found
);
  import dm::*;

  logic [31:0] next_dm_addr_i;
  logic testmode_i;
  logic dmi_rst_ni;
  logic dmi_req_valid_i, dmi_req_ready_o;
  dm::dmi_req_t dmi_req_i;
  logic dmi_resp_valid_o, dmi_resp_ready_i;
  dm::dmi_resp_t dmi_resp_o;
  logic ndmreset_o, ndmreset_ack_i;
  logic dmactive_o;
  dm::hartinfo_t [1:0] hartinfo_i;
  logic [1:0] halted_i, unavailable_i, resumeack_i;
  logic [19:0] hartsel_o;
  logic [1:0] haltreq_o, resumereq_o;
  logic clear_resumeack_o;
  logic cmd_valid_o;
  dm::command_t cmd_o;
  logic cmderror_valid_i;
  dm::cmderr_e cmderror_i;
  logic cmdbusy_i;
  logic [dm::ProgBufSize-1:0][31:0] progbuf_o;
  logic [dm::DataCount-1:0][31:0] data_o, data_i;
  logic data_valid_i;
  logic [31:0] sbaddress_o, sbaddress_i;
  logic sbaddress_write_valid_o, sbreadonaddr_o, sbautoincrement_o;
  logic [2:0] sbaccess_o;
  logic sbreadondata_o;
  logic [31:0] sbdata_o;
  logic sbdata_read_valid_o;

  dm_csrs dut (
    .clk_i(clk), .rst_ni(rst_n),
    .next_dm_addr_i, .testmode_i,
    .dmi_rst_ni, .dmi_req_valid_i, .dmi_req_ready_o,
    .dmi_req_i, .dmi_resp_valid_o, .dmi_resp_ready_i, .dmi_resp_o,
    .ndmreset_o, .ndmreset_ack_i, .dmactive_o,
    .hartinfo_i, .halted_i, .unavailable_i, .resumeack_i,
    .hartsel_o, .haltreq_o, .resumereq_o, .clear_resumeack_o,
    .cmd_valid_o, .cmd_o,
    .cmderror_valid_i, .cmderror_i, .cmdbusy_i,
    .progbuf_o, .data_o, .data_i, .data_valid_i,
    .sbaddress_o, .sbaddress_i, .sbaddress_write_valid_o,
    .sbreadonaddr_o, .sbautoincrement_o, .sbaccess_o,
    .sbreadondata_o, .sbdata_o, .sbdata_read_valid_o
  );

  // Synthesizable DMI-read FSM
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= 0;
      dmi_req_valid_i <= 0;
      dmi_req_i <= '0;
      dmi_rst_ni <= 0;
      bug_found <= 0;
      testmode_i <= 0;
      next_dm_addr_i <= '0;
      ndmreset_ack_i <= 0;
      hartinfo_i <= '{default: '0};
      halted_i <= 0; unavailable_i <= 0; resumeack_i <= 0;
      cmderror_valid_i <= 0; cmderror_i <= dm::CmdErrNone; cmdbusy_i <= 0;
      data_i <= '0; data_valid_i <= 0;
      sbaddress_i <= '0;
    end else begin
      case (state)
        0: begin
             dmi_rst_ni <= 1;
             state <= 1;
           end
        1: begin
             // issue DMI READ of DMSTATUS (0x11)
             dmi_req_i.addr <= 32'h11;
             dmi_req_i.op <= dm::DTM_READ;
             dmi_req_i.data <= '0;
             dmi_req_valid_i <= 1;
             state <= 2;
           end
        2: begin
             dmi_req_valid_i <= 0;
             state <= 3;
           end
        3: begin
             // wait for response
             state <= 4;
           end
        4: begin
             state <= 5;
           end
        5: begin
             $display("=== DMI read DMSTATUS: resp_valid=%b data=0x%08x ===",
                      dmi_resp_valid_o, dmi_resp_o.data);
             if (dmi_resp_valid_o && dmi_resp_o.data[10] === 1'b1) begin
               bug_found <= 1;
               $display("");
               $display("==================================================");
               $display("*** BUG #2 CONFIRMED on actual OpenTitan RTL ***");
               $display("==================================================");
               $display("dm_csrs.sv:231 hardwires dmstatus.authenticated=1");
               $display("DMI read of DMSTATUS returns authenticated=1");
               $display("with NO AuthData handshake performed.");
               $display("");
               $display("Impact: any DMI/JTAG debugger gains authenticated");
               $display("debug access without authentication.");
               $display("==================================================");
             end else begin
               $display("authenticated bit = %b (resp_valid=%b)",
                        dmi_resp_o.data[10], dmi_resp_valid_o);
             end
             state <= 6;
           end
        6: $finish;
      endcase
    end
  end
endmodule
