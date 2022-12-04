/*
Author: Ben Sheffer
Date: 11/1/2022
Description: 
This module is meant to interface with an XADC core via the axi-stream interface (the xadc core is the axi master)

connecting ADC pins to XADC_V_P and XADC_V_N (differential inputs)
*/

module daq(
    //input clock and reset
    input clk_in,
    input rst_in,
    
    input s_axis_tvalid,
    output reg s_axis_tready,
    input [15:0] s_axis_tdata,
    input [4:0] s_axis_tid,
    //input ip2intc_irpt,
    
    //interface with registers
    output reg [31:0] data_status_reg,
    output reg [31:0] data_adc_out,
    
    output wire ready_out,
    output wire valid_out
    );
    
    assign ready_out = s_axis_tready;
    assign valid_out = s_axis_tvalid;
    
    always @ (posedge clk_in) begin
        if (~rst_in) begin
            s_axis_tready <= 1'b0;
            data_status_reg <= 32'd0;
            data_adc_out <= 32'd0;
        end else begin
            s_axis_tready <= 1'b1;
            
            if(s_axis_tvalid) begin
                data_adc_out <= {16'd0,s_axis_tdata};
            end else begin
                data_adc_out <= data_adc_out;
            end
        end
    end
    
endmodule
