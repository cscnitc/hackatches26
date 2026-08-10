`timescale 1ns/1ps
module tb_ibex_core_fuzz;
  import ibex_pkg::*;

  logic clk = 0, rst_n = 0;
  logic [31:0] hart_id_i = 0, boot_addr_i = 32'h100000;

  // Memories
  logic [31:0] imem [0:16383];
  logic [31:0] dmem [0:16383];
  logic [31:0] regfile [0:31];

  // Ibex interfaces — names must match ibex_core ports
  logic        instr_req_o, instr_gnt_i=1, instr_rvalid_i=1, instr_err_i=0;
  logic [31:0] instr_addr_o, instr_rdata_i;
  logic        data_req_o, data_gnt_i=1, data_rvalid_i=1, data_we_o, data_err_i=0;
  logic [3:0]  data_be_o;
  logic [31:0] data_addr_o, data_wdata_o, data_rdata_i;

  // Register file interface
  logic        dummy_instr_id_o, dummy_instr_wb_o;
  logic [4:0]  rf_raddr_a_o, rf_raddr_b_o, rf_waddr_wb_o;
  logic        rf_we_wb_o;
  logic [31:0] rf_wdata_wb_ecc_o, rf_rdata_a_ecc_i, rf_rdata_b_ecc_i;

  // ICache — tie off
  logic ic_tag_req_o, ic_tag_write_o, ic_data_req_o, ic_data_write_o;
  logic [31:0] ic_tag_addr_o, ic_tag_wdata_o, ic_data_addr_o, ic_data_wdata_o;
  logic ic_scr_key_req_o;

  // Interrupts — tie off
  logic irq_pending_o;

  // RVFI — leave unconnected (.name syntax handles this)
  // Alerts, busy, crash
  
  // Fetch enable needs ibex_mubi_t type
  ibex_mubi_t fetch_enable_i;
  ibex_mubi_t core_busy_o;
  logic alert_minor_o, alert_major_internal_o, alert_major_bus_o;
  logic crash_dump_o, double_fault_seen_o;

  assign fetch_enable_i = ibex_mubi_t'(MuBi4True);
  
  // Memory connections
  always_comb begin
    instr_rdata_i = imem[instr_addr_o[17:2]];
    data_rdata_i  = dmem[data_addr_o[17:2]];
  end

  always_ff @(posedge clk) begin
    if (rst_n && data_req_o && data_we_o) begin
      if (data_be_o[0]) dmem[data_addr_o[17:2]][7:0]   <= data_wdata_o[7:0];
      if (data_be_o[1]) dmem[data_addr_o[17:2]][15:8]  <= data_wdata_o[15:8];
      if (data_be_o[2]) dmem[data_addr_o[17:2]][23:16] <= data_wdata_o[23:16];
      if (data_be_o[3]) dmem[data_addr_o[17:2]][31:24] <= data_wdata_o[31:24];
    end
  end

  // Register file
  assign rf_rdata_a_ecc_i = regfile[rf_raddr_a_o];
  assign rf_rdata_b_ecc_i = regfile[rf_raddr_b_o];
  always_ff @(posedge clk)
    if (rst_n && rf_we_wb_o && rf_waddr_wb_o != 0)
      regfile[rf_waddr_wb_o] <= rf_wdata_wb_ecc_o;

  // Instantiate ibex_core with wildcard .name connections
  ibex_core #(
    .PMPEnable(0), .PMPGranularity(0), .PMPNumRegions(4),
    .MHPMCounterNum(0), .RV32E(0), .RV32M(RV32MFast), .RV32B(RV32BNone),
    .BranchTargetALU(0), .WritebackStage(0), .ICache(0), .ICacheECC(0),
    .BranchPredictor(0), .DbgTriggerEn(0), .SecureIbex(0),
    .DummyInstructions(0), .RegFileECC(0), .MemECC(0),
    .RegFileDataWidth(32), .MemDataWidth(32),
    .DmHaltAddr(32'h1A110800), .DmExceptionAddr(32'h1A110808)
  ) u_ibex (
    .clk_i(clk), .rst_ni(rst_n),
    .hart_id_i, .boot_addr_i,
    .instr_req_o, .instr_gnt_i, .instr_rvalid_i, .instr_addr_o,
    .instr_rdata_i, .instr_err_i,
    .data_req_o, .data_gnt_i, .data_rvalid_i, .data_we_o,
    .data_be_o, .data_addr_o, .data_wdata_o, .data_rdata_i, .data_err_i,
    .dummy_instr_id_o, .dummy_instr_wb_o,
    .rf_raddr_a_o, .rf_raddr_b_o, .rf_waddr_wb_o, .rf_we_wb_o,
    .rf_wdata_wb_ecc_o, .rf_rdata_a_ecc_i, .rf_rdata_b_ecc_i,
    .ic_tag_req_o, .ic_tag_write_o, .ic_tag_addr_o, .ic_tag_wdata_o,
    .ic_tag_rdata_i('0), .ic_data_req_o, .ic_data_write_o,
    .ic_data_addr_o, .ic_data_wdata_o, .ic_data_rdata_i('0),
    .ic_scr_key_valid_i(1'b0), .ic_scr_key_req_o,
    .irq_software_i(1'b0), .irq_timer_i(1'b0), .irq_external_i(1'b0),
    .irq_fast_i('0), .irq_nm_i(1'b0), .irq_pending_o,
    .debug_req_i(1'b0), .fetch_enable_i,
    .crash_dump_o, .double_fault_seen_o,
    .alert_minor_o, .alert_major_internal_o, .alert_major_bus_o,
    .core_busy_o,
    // RVFI ports — auto by name (.* doesn't work with explicit list,
    // so wildcard .* covers RVFI)
    .*
  );

  always #5 clk = ~clk;

  integer cycle = 0;
  always @(posedge clk) if (rst_n) cycle <= cycle + 1;

  initial begin
    $display("Ibex Core Fuzz TB starting...");
    imem[32'h100000>>2] = 32'h02a00093; // addi x1, x0, 42
    imem[(32'h100000+4)>>2] = 32'h00100073; // ebreak
    #20 rst_n = 1;
    #50000;
    $display("Sim done: %0d cycles, x1=%0d", cycle, $signed(regfile[1]));
    if ($signed(regfile[1]) == 42)
      $display("TEST PASSED: x1 == 42");
    else
      $display("TEST FAILED: x1 != 42");
    $finish;
  end
endmodule
