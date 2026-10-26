`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 10/25/2026 02:27:49 PM
// Design Name: 
// Module Name: multiplier_16_bit
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


module multiplier_16_bit(
    input       clk,
    input       rst_n,
    input       [15:0] a,
    input       [15:0] b,
    output reg  [31:0] prod
    );
    always @(posedge clk) begin
        if(rst_n == 0)
            prod <= 32'd0;
        else
            prod <= (a * b);
        end
endmodule
