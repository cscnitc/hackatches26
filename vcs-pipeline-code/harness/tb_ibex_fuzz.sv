`timescale 1ns/1ps

module tb_ibex_fuzz;
  reg clk = 0;
  reg rst_n = 0;
  wire core_sleep;

  // Memory
  reg [31:0] mem [0:65535];

  // Ibex signals
  wire [31:0] imem_addr;
  reg  [31:0] imem_rdata;
  wire        imem_req;
  wire [31:0] dmem_addr;
  wire [31:0] dmem_wdata;
  reg  [31:0] dmem_rdata;
  wire [3:0]  dmem_be;
  wire        dmem_req;
  wire        dmem_we;

  // Tie-offs for top ports
  wire [31:0] unused_ram_rsp;

  // Memory reads
  always @(*) begin
    imem_rdata = mem[imem_addr[17:2]];
    dmem_rdata = mem[dmem_addr[17:2]];
  end

  // Memory writes
  always @(posedge clk) begin
    if (rst_n && dmem_req && dmem_we) begin
      if (dmem_be[0]) mem[dmem_addr[17:2]][7:0]   <= dmem_wdata[7:0];
      if (dmem_be[1]) mem[dmem_addr[17:2]][15:8]  <= dmem_wdata[15:8];
      if (dmem_be[2]) mem[dmem_addr[17:2]][23:16] <= dmem_wdata[23:16];
      if (dmem_be[3]) mem[dmem_addr[17:2]][31:24] <= dmem_wdata[31:24];
    end
  end

  ibex_top #(
    .DmHaltAddr(32'h1A110000),
    .DmExceptionAddr(32'h1A110000)
  ) u_ibex (
    .clk_i(clk), .rst_ni(rst_n), .test_en_i(1'b0),
    .hart_id_i(32'h0), .boot_addr_i(32'h100000),
    .instr_req_o(imem_req), .instr_addr_o(imem_addr),
    .instr_rdata_i(imem_rdata), .instr_rvalid_i(1'b1), .instr_err_i(1'b0),
    .data_req_o(dmem_req), .data_addr_o(dmem_addr),
    .data_wdata_o(dmem_wdata), .data_we_o(dmem_we), .data_be_o(dmem_be),
    .data_rdata_i(dmem_rdata), .data_rvalid_i(1'b1), .data_err_i(1'b0),
    .irq_software_i(1'b0), .irq_timer_i(1'b0), .irq_external_i(1'b0),
    .debug_req_i(1'b0), .fetch_enable_i(1'b1),
    .core_sleep_o(core_sleep),
    .ram_cfg_icache_tag_i(32'd0), .ram_cfg_rsp_icache_tag_o(unused_ram_rsp),
    .ram_cfg_icache_data_i(32'd0), .ram_cfg_rsp_icache_data_o(unused_ram_rsp)
  );

  always #5 clk = ~clk;

  integer cycle = 0;
  always @(posedge clk) if (rst_n) cycle <= cycle + 1;

  // Load program from file
  integer fd, r;
  reg [31:0] addr, data;
  initial begin
    $display("Ibex Fuzz TB starting...");
    // Default program: addi x1, x0, 42; ebreak
    mem[32'h100000>>2] = 32'h02a00093;
    mem[(32'h100000+4)>>2] = 32'h00100073;

    // Try to load from file
    fd = $fopen("ibex_program.hex", "r");
    if (fd != 0) begin
      while (!$feof(fd)) begin
        r = $fscanf(fd, "%h %h\n", addr, data);
        if (r == 2 && addr[1:0] == 0) mem[addr>>2] = data;
      end
      $fclose(fd);
      $display("Program loaded from ibex_program.hex");
    end

    #20 rst_n = 1;
    #20000;
    $display("Done: %0d cycles", cycle);
    $writememh("ibex_ram_dump.hex", mem);
    $finish;
  end

endmodule
