`timescale 1ns/1ps

module regfile_tb;

  // DUT ports
  logic        clk;
  logic        rst_n;
  logic [4:0]  rs1_addr;
  logic [31:0] rs1_data;
  logic [4:0]  rs2_addr;
  logic [31:0] rs2_data;
  logic        we;
  logic [4:0]  wa;
  logic [31:0] wd;

  // DUT
  regfile dut (
    .clk      (clk),
    .rst_n    (rst_n),
    .rs1_addr (rs1_addr),
    .rs1_data (rs1_data),
    .rs2_addr (rs2_addr),
    .rs2_data (rs2_data),
    .we       (we),
    .wa       (wa),
    .wd       (wd)
  );

  // clock
  initial clk = 0;
  always #5 clk = ~clk;  // 100 MHz

  // wave
  initial begin
    $dumpfile("waves/regfile_tb.vcd");
    $dumpvars(0, regfile_tb);
  end

  // helpers
  task automatic apply_reset();
    begin
      rst_n = 0; we = 0; wa = '0; wd = '0; rs1_addr = '0; rs2_addr = '0;
      repeat (2) @(posedge clk);
      rst_n = 1;
      @(posedge clk);
    end
  endtask

  task automatic write_reg(input [4:0] addr, input [31:0] data);
    begin
      // 写在 posedge 生效
      we = 1; wa = addr; wd = data;
      @(posedge clk);
      we = 0; wa = '0; wd = '0;
      // 给一拍让写入稳定
      @(negedge clk);
    end
  endtask

  task automatic check_eq(input [31:0] got, input [31:0] exp, input string msg);
    if (got !== exp) begin
      $display("[ERROR] %s exp=0x%08x got=0x%08x @%0t", msg, exp, got, $time);
      $fatal(1);
    end else begin
      $display("[PASS ] %s = 0x%08x", msg, got);
    end
  endtask

  // main
  initial begin
    $display("=== regfile_tb start ===");
    apply_reset();

    // 1) 复位后所有寄存器为 0，尤其是 x0=0
    rs1_addr = 5'd0; rs2_addr = 5'd1;
    #1;  // 异步读，给组合逻辑一个 delta
    check_eq(rs1_data, 32'h0, "reset x0==0");
    check_eq(rs2_data, 32'h0, "reset x1==0");

    // 2) 写 x0 应无效（硬连 0）
    write_reg(5'd0, 32'hDEADBEEF);
    rs1_addr = 5'd0; #1;
    check_eq(rs1_data, 32'h0, "x0 hardwired to zero after write attempt");

    // 3) 写 x5，随后异步读出
    write_reg(5'd5, 32'h12345678);
    rs1_addr = 5'd5; #1;
    check_eq(rs1_data, 32'h12345678, "write/read x5");

    // 4) 同周期读写检验：
    // 在一个 posedge 之前设置 rs1_addr=wa，并在同一个周期 we=1；
    // 因为写在 posedge 生效，异步读在 posedge 之前看到的是旧值。
    // 先给 x10 预写旧值
    write_reg(5'd10, 32'hAAAA5555);

    // 准备“同周期读写”
    rs1_addr = 5'd10;
    we = 1; wa = 5'd10; wd = 32'hCAFEBABE;
    // 现在处于写入的周期，但 posedge 尚未到来，异步读应看到旧值
    #1;
    check_eq(rs1_data, 32'hAAAA5555, "same-cycle read-before-write shows old value");
    // 到 posedge，写生效
    @(posedge clk);
    we = 0; wa = '0; wd = '0;
    // posedge 后再读，应为新值
    #1;
    check_eq(rs1_data, 32'hCAFEBABE, "post-write read shows new value");

    // 5) 双口读：分别读不同寄存器
    write_reg(5'd2, 32'h11111111);
    write_reg(5'd3, 32'h22222222);
    rs1_addr = 5'd2; rs2_addr = 5'd3; #1;
    check_eq(rs1_data, 32'h11111111, "dual read rs1=x2");
    check_eq(rs2_data, 32'h22222222, "dual read rs2=x3");

    // 6) 简单随机回归（可调次数）
    automatic int N = 100;
    for (int i = 0; i < N; i++) begin
      bit [4:0] addr = $urandom_range(1,31); // 不写 x0
      bit [31:0] val = $urandom();
      write_reg(addr, val);
      rs1_addr = addr; rs2_addr = 5'd0; #1;
      if (rs1_data !== val) begin
        $display("[ERROR] random wr/rd mismatch addr=%0d exp=0x%08x got=0x%08x", addr, val, rs1_data);
        $fatal(1);
      end
      // 确认 rs2 读 x0 始终为 0
      if (rs2_data !== 32'h0) begin
        $display("[ERROR] x0 not zero in random check, got=0x%08x", rs2_data);
        $fatal(1);
      end
    end
    $display("=== regfile_tb PASS ===");
    $finish;
  end

endmodule