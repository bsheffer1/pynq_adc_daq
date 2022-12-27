/*
Author: Ben Sheffer
Date: 12/14/2022
last Update: 12/18/2022
Description: 
This module is an implementation of a circular memory FIFO using a 32x4096 BRAM. The write and read data are controlled/accessed using
a ready-valid handshake. FIFO empty and full signals are also provided as outputs to monitor the status of the FIFO. This module
requires out-of-context synthesis for the BRAM module.

*/


module fifo( 
    input clk_in,
    input rst_in,
    //signals for write data
    input [31:0] in_data,
    input in_valid,
    output wire in_ready,
     
    //signals for the read data
    output wire [31:0] out_data,
    output reg out_valid,
    input out_ready,
     
    //status signals
    output wire full,
    output reg empty
);
    
    //declare write and read pointers
    reg [12:0] write_pointer = 12'd0;
    reg [12:0] read_pointer = 12'd0;
    
    wire write_enable;
    reg [1:0] read_state = 0;
    wire empty_unpiped;
    
    parameter read_idle = 0;
    parameter read_incr_pointer = 1;
    
    //declare a 32x4096 BRAM to store data for the FIFO (Block Memory Generator IP)
    //Port A is the write port, Port B is the read port
    blk_mem_32x4096 fifo_mem(    
                        .clka(clk_in),
                        .ena(1'b1),
                        .wea(write_enable),
                        .addra(write_pointer[11:0]),
                        .dina(in_data),
                        .clkb(clk_in),
                        .enb(1'b1),
                        .addrb(read_pointer[11:0]),
                        .doutb(out_data)
    );
    
    //assign status signals
    assign full = write_pointer[12] != read_pointer[12] && write_pointer[11:0] == read_pointer[11:0];
    assign empty_unpiped = write_pointer == read_pointer;
    
    //if the FIFO isn't full, the FIFO can accept more data
    assign in_ready = ~full;
    
    //assign write_enable
    assign write_enable = in_ready & in_valid;
    
    always @ (posedge clk_in) begin
        if(~rst_in) begin
            write_pointer <= 12'd0;
            read_pointer <= 12'd0;
            read_state <= read_idle;
            out_valid <= 1'b0;
            empty <= 1'b1;
        end else begin
             /*** write logic ***/             
             if (write_enable == 1'b1) begin
                write_pointer   <= write_pointer + 12'd1;
             end
             
             /*** read logic ***/
             empty <= empty_unpiped;
             case(read_state)
                //if the fifo is not empty, and the user is requesting a value,
                //wait 1 clock cycle to ensure the BRAM has readout the address at the read_pointer
                read_idle: begin
                    //don't set outvalid unless you have not been empty for at least
                    //one clock cycle. Must wait a clock cycle for the BRAM to read
                    //the current read_pointer
                    if (empty == 1'b0)  begin
                        out_valid <= 1'b1;
                        read_state <= read_incr_pointer;
                    end
                end
                
                read_incr_pointer: begin
                    if (out_ready == 1'b1) begin
                        if (empty == 1'b0) read_pointer <= read_pointer + 12'd1;
                        read_state <= read_idle;
                        out_valid <= 0;
                    end
                end
                
             endcase
         end
    end
  
endmodule
