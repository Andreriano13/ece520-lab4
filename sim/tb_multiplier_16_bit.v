`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 10/25/2026 02:54:23 PM
// Design Name: 
// Module Name: tb_multiplier_16_bit
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module tb_multiplier_16_bit;
    localparam CLK_PERIOD = 8;            // 125 MHz ? 1 / 125e6 = 8 ns
    reg         clk = 0, rst_n = 0;
    reg  [15:0] a = 0, b = 0;
    wire [31:0] prod;
    integer     i;

    multiplier_16_bit dut (.clk(clk), .rst_n(rst_n), .a(a), .b(b), .prod(prod));

    always #(CLK_PERIOD/2) clk = ~clk;    // flip every half period

    initial begin
        #(2*CLK_PERIOD) rst_n = 1;        // reset for 2 clocks, then release
        for (i = 1; i <= 32; i = i + 1) begin
            @(posedge clk);
            a = i;
            b = i;
        end
        #(4*CLK_PERIOD) $finish;
    end
endmodule
