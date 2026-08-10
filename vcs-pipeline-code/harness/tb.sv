`timescale 1ns/1ps
module tb;
  import ibex_pkg::*;

  logic clk=0, rst_n=0;
  logic [31:0] hart_id_i=0, boot_addr_i=32'h100000;
  logic instr_gnt_i=1, instr_rvalid_i=1, instr_err_i=0;
  logic [31:0] instr_rdata_i;
  logic data_gnt_i=1, data_rvalid_i=1, data_err_i=0;
  logic [31:0] data_rdata_i;
  logic [31:0] ic_tag_rdata_i=0, ic_data_rdata_i=0;
  logic ic_scr_key_valid_i=0;
  logic [14:0] irq_fast_i=0;
  logic irq_software_i=0, irq_timer_i=0, irq_external_i=0, irq_nm_i=0;
  logic debug_req_i=0;
  logic [3:0] fetch_enable_i = 4'b0101; // IbexMuBiOn = 4'b0101

  // RVFI tie-offs
  logic [31:0] rvfi_ext_mhpmcounters [10] = '{default:'0};
  logic [31:0] rvfi_ext_mhpmcountersh [10] = '{default:'0};

  // Memory
  logic [31:0] imem[0:16383], dmem[0:16383], regs[0:31];
  logic instr_req_o, instr_addr_o_32;
  logic data_req_o, data_we_o, data_be_o_4;
  logic [31:0] data_addr_o, data_wdata_o;
  logic [4:0] rf_raddr_a_o, rf_raddr_b_o, rf_waddr_wb_o;
  logic rf_we_wb_o;
  logic [31:0] rf_wdata_wb_ecc_o;

  assign instr_rdata_i = imem[instr_req_o ? instr_addr_o_32[17:2] : 0];
  assign data_rdata_i = dmem[data_addr_o[17:2]];
  always_ff @(posedge clk) begin
    if (rst_n && data_req_o && data_we_o) begin
      for (int i=0; i<4; i++)
        if (data_be_o_4[i]) dmem[data_addr_o[17:2]][i*8+:8] <= data_wdata_o[i*8+:8];
    end
    regs[rf_waddr_wb_o] <= (rst_n && rf_we_wb_o && rf_waddr_wb_o!=0) ? rf_wdata_wb_ecc_o : regs[rf_waddr_wb_o];
  end
  logic [31:0] rf_rdata_a_ecc_i, rf_rdata_b_ecc_i;
  assign rf_rdata_a_ecc_i = regs[rf_raddr_a_o];
  assign rf_rdata_b_ecc_i = regs[rf_raddr_b_o];

  // Instantiate — use .* for autoconnect + explicit overrides
  ibex_core #(
    .PMPEnable(0), .PMPGranularity(0), .PMPNumRegions(4),
    .MHPMCounterNum(0), .RV32E(0), .RV32M(RV32MFast), .RV32B(RV32BNone),
    .BranchTargetALU(0), .WritebackStage(0), .ICache(0), .ICacheECC(0),
    .BranchPredictor(0), .DbgTriggerEn(0), .SecureIbex(0),
    .DummyInstructions(0), .RegFileECC(0), .MemECC(0),
    .RegFileDataWidth(32), .MemDataWidth(32),
    .DmHaltAddr(32'h1A110800), .DmExceptionAddr(32'h1A110808)
  ) u (.*);

  always #5 clk=~clk;
  integer cyc=0;
  always @(posedge clk) if(rst_n) cyc<=cyc+1;

  initial begin
    $display("Ibex TB start");
    imem[32'h100000>>2]=32'h02a00093;
    imem[(32'h100000+4)>>2]=32'h00100073;
    #20 rst_n=1;
    #50000;
    $display("Done: %0d cycles, x1=%0d", cyc, $signed(regs[1]));
    $finish;
  end
endmodule
