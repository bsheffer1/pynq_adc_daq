`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 12/15/2022 07:13:01 PM
// Design Name: 
// Module Name: fifo_test
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


module fifo_test;

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

reg [31:0] read_data;

wire full;
wire empty;

fifo my_fifo(
    .clk_in(clk),
    .rst_in(rst),

    .in_data(in_data_piped),
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

// the full and empty flags should never be asserted at the same time
assert property (@(posedge clk)(full == 1 && empty == 1));

initial begin
    rst=0;
    #100
    rst=1;
    #100;
    
    //after reset, we should see the following: empty=1, full=0
    assert (empty == 1) $display("empty = 1 upon reset, good to go!");
        else $error("empty = 0 upon reset, something went wrong");
    assert (full == 0) $display("full = 0 upon reset, good to go!");
        else $error("full = 1 upon reset, something went wrong");
end;

/* test a sequential write and then read */
/* test that I can write to the FIFO until it's full */
/* once full, readback the fifo and check the data */
reg [31:0] in_data_piped;

reg [1:0] state;
parameter write_state = 0;
parameter read_state = 1;
parameter write_read_state = 2;
always @ (posedge clk) begin
    if (~rst) begin
        in_data <= 0;
        in_valid <= 0;
        in_data_piped <= 0;
        out_ready <= 0;
        state <= write_state;
    end else begin
        case (state)
            write_state: begin
                
                in_data_piped <= in_data;
                if (~full & in_ready) begin
                    in_data <= in_data + 1;
                    in_valid <= 1;
                end
                
                if (full) begin
                    state <= read_state;
                    in_valid <= 0;
                end             
            end       
              
            read_state: begin
            //once the fifo has been filled, read the data back
                in_valid <= 0;
                out_ready <= 1;
                if (out_valid == 1'b1) begin
                    read_data <= out_data;
                end
                
                if (out_valid == 1'b0 && empty == 1'b1) begin
                    in_data <= 0;
                    state <= write_read_state;
                    out_ready <= 0;
                end
            end
            
            write_read_state: begin
            //now test reading while writing simultaneously
                in_data_piped <= in_data;
                if (~full & in_ready) begin
                    in_data <= in_data + 1;
                    in_valid <= 1;
                end
                
                out_ready <= 1;
                if (out_valid == 1'b1) begin
                    read_data <= out_data;
                end
                
            end
        endcase
    end
end

endmodule
