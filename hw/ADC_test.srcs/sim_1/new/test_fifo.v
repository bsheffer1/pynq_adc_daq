`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 12/15/2022 07:01:24 PM
// Design Name: 
// Module Name: test_fifo
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


module test_fifo;

//declare clock and reset
reg clk = 0;
reg rst = 1;

//declare interface signals for the fifo
/*
input clk_in,
    input rst_in,
    //signals for write data
    input [31:0] in_data,
    input in_valid,
    output wire in_ready,
     
    //signals for the read data
    output reg [31:0] out_data,
    output reg out_valid,
    input out_ready,
     
    //status signals
    output wire full,
    output wire empty
*/
reg [31:0] in_data= 32'd0;
reg in_valid = 1'b0;
wire in_ready;

reg [31:0] out_data;
reg out_valid;
reg out_ready;

wire full;
wire empty;

fifo(
    .clk_in(clk),
    .rst_in(rst),

    .in_data(in_data),
    .in_valid(in_valid),
    .in_ready(in_ready),
    
    .out_data(out_data),
    .out_valid(out_valid),
    .out_ready(out_ready),
    
    .full(full),
    .empty(empty)
);

always begin
    #5
    clk=!clk;
end

initial begin
    rst=0;
    #100
    rst=1;
    #100;
    
    //after reset, we should see the following: empty=1, full=0
end;


endmodule
