`timescale 1ns / 1ps
// tb_sc_fifo_axi.v - self-checking testbench for the sc_fifo_axi AXI4-Lite IP (ECE 520 Lab 4, Part 6)
// The testbench plays the ARM: it writes and reads the IP's registers over AXI4-Lite
// and checks every value against the register map (Lab 4 PDF p. 58-62).
// Drafted with Claude (Anthropic); see README "AI assistance".
module tb_sc_fifo_axi;
    localparam CLK_PERIOD = 20;                    // 50 MHz, same as FCLK_CLK0 on the board
    localparam [5:0] REV = 6'h00, RST = 6'h04, WR = 6'h08, RDREQ = 6'h0C, RDDATA = 6'h10,
                     STATUS = 6'h14, COUNT = 6'h18, CONFIG = 6'h1C, THRESH = 6'h20, RSVD = 6'h24;

    reg         aclk = 0, aresetn = 0;
    reg  [5:0]  awaddr = 0;  reg awvalid = 0;  wire awready;
    reg  [31:0] wdata = 0;   reg [3:0] wstrb = 4'hF;  reg wvalid = 0;  wire wready;
    wire [1:0]  bresp;       wire bvalid;      reg bready = 1;
    reg  [5:0]  araddr = 0;  reg arvalid = 0;  wire arready;
    wire [31:0] rdata;       wire [1:0] rresp; wire rvalid;  reg rready = 1;

    sc_fifo_axi_v1_0 #(.C_S00_AXI_DATA_WIDTH(32), .C_S00_AXI_ADDR_WIDTH(6)) dut (
        .s00_axi_aclk(aclk), .s00_axi_aresetn(aresetn),
        .s00_axi_awaddr(awaddr), .s00_axi_awprot(3'b000), .s00_axi_awvalid(awvalid), .s00_axi_awready(awready),
        .s00_axi_wdata(wdata), .s00_axi_wstrb(wstrb), .s00_axi_wvalid(wvalid), .s00_axi_wready(wready),
        .s00_axi_bresp(bresp), .s00_axi_bvalid(bvalid), .s00_axi_bready(bready),
        .s00_axi_araddr(araddr), .s00_axi_arprot(3'b000), .s00_axi_arvalid(arvalid), .s00_axi_arready(arready),
        .s00_axi_rdata(rdata), .s00_axi_rresp(rresp), .s00_axi_rvalid(rvalid), .s00_axi_rready(rready));

    always #(CLK_PERIOD/2) aclk = ~aclk;

    integer errors = 0, checks = 0, k;
    reg [31:0] v;

    // one AXI write, like Xil_Out32(addr, data)
    task axi_write(input [5:0] a, input [31:0] d);
        begin
            @(posedge aclk); awaddr <= a; wdata <= d; awvalid <= 1; wvalid <= 1;
            wait (awready && wready); @(posedge aclk); awvalid <= 0; wvalid <= 0;
            wait (bvalid); @(posedge aclk);
        end
    endtask

    // one AXI read, like Xil_In32(addr)
    task axi_read(input [5:0] a, output [31:0] d);
        begin
            @(posedge aclk); araddr <= a; arvalid <= 1;
            wait (arready); @(posedge aclk); arvalid <= 0;
            wait (rvalid); d = rdata; @(posedge aclk);
        end
    endtask

    task expect(input [5:0] a, input [31:0] want, input [8*40-1:0] what);
        begin
            axi_read(a, v); checks = checks + 1;
            if (v !== want) begin errors = errors + 1; $display("FAIL  %0s: 0x%02h read 0x%08h, expected 0x%08h", what, a, v, want); end
            else                                       $display("pass  %0s: 0x%02h = 0x%08h", what, a, v);
        end
    endtask

    // pop one word: request, then wait for RD_VALID
    task pop(output [31:0] d);
        begin
            axi_write(RDREQ, 32'h1);
            repeat (4) @(posedge aclk);
            axi_read(RDDATA, d);
        end
    endtask

    initial begin
        repeat (5) @(posedge aclk); aresetn = 1; repeat (3) @(posedge aclk);

        $display("--- TC1 reset values ---");
        expect(REV,    32'h5200_0004, "FPGA_REV");
        expect(STATUS, 32'h0000_0005, "STATUS after reset");
        expect(COUNT,  32'h0000_0000, "DATA_COUNT after reset");
        expect(CONFIG, 32'h0100_2010, "CONFIG");
        expect(THRESH, 32'h001F_0001, "THRESHOLD");
        expect(RST,    32'h0, "FIFO_RST reads 0");
        expect(WR,     32'h0, "WR_DATA reads 0");
        expect(RDREQ,  32'h0, "RD_REQ reads 0");
        expect(RSVD,   32'h0, "reserved 0x24 reads 0");

        $display("--- TC2 push 5 words ---");
        for (k = 0; k < 5; k = k + 1) axi_write(WR, 32'hABCD_0000 + 16'h1111 * (k + 1));   // upper bits must be dropped
        expect(COUNT,  32'd5, "DATA_COUNT = 5");
        expect(STATUS, 32'h0000_0000, "STATUS: not empty, not full");

        $display("--- TC3 pop 5 words, in order ---");
        for (k = 0; k < 5; k = k + 1) begin
            pop(v); checks = checks + 1;
            if (v !== 16'h1111 * (k + 1)) begin errors = errors + 1; $display("FAIL  pop %0d = 0x%04h, expected 0x%04h", k, v, 16'h1111 * (k + 1)); end
            else $display("pass  pop %0d = 0x%04h", k, v);
        end
        expect(STATUS, 32'h0000_0015, "STATUS: RD_VALID + empty + almost_empty");

        $display("--- TC4 pop when empty is ignored, RD_VALID cleared ---");
        axi_write(RDREQ, 32'h1); repeat (4) @(posedge aclk);
        expect(STATUS, 32'h0000_0005, "STATUS: RD_VALID 0, still empty");

        $display("--- TC5 writing 0 to RD_REQ does nothing ---");
        axi_write(WR, 32'h0000_BEEF);
        axi_write(RDREQ, 32'h0); repeat (4) @(posedge aclk);
        expect(COUNT, 32'd1, "DATA_COUNT still 1");

        $display("--- TC6 software reset ---");
        axi_write(WR, 32'h0000_0001); axi_write(WR, 32'h0000_0002);
        axi_write(RST, 32'h1); repeat (2) @(posedge aclk);
        expect(COUNT,  32'd0, "DATA_COUNT 0 after FIFO_RST");
        expect(STATUS, 32'h0000_0005, "STATUS reset value again");

        $display("--- TC7 fill to 32, the 33rd write is ignored ---");
        for (k = 0; k < 33; k = k + 1) axi_write(WR, k);
        expect(COUNT,  32'd32, "DATA_COUNT = 32 (DEPTH)");
        expect(STATUS, 32'h0000_000A, "STATUS: full + almost_full");
        pop(v); checks = checks + 1;
        if (v !== 0) begin errors = errors + 1; $display("FAIL  first word after fill = %0d", v); end else $display("pass  first word after fill = 0");

        $display("--- TC8 writes to read-only registers have no effect ---");
        axi_write(REV, 32'hFFFF_FFFF); axi_write(CONFIG, 32'h0);
        expect(REV,    32'h5200_0004, "FPGA_REV unchanged");
        expect(CONFIG, 32'h0100_2010, "CONFIG unchanged");

        $display("==== %0d checks, %0d errors: %s ====", checks, errors, errors == 0 ? "ALL PASS" : "FAILURES");
        $finish;
    end
endmodule
