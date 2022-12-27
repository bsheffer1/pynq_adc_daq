`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 12/11/2022 02:17:42 PM
// Design Name: 
// Module Name: test_threshold_logic
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


module test_threshold_logic;

reg clk=0;
reg rst=1;

    wire [31:0] daq_control_reg = {18'd0,14'b1111111001110};

    reg [15:0] event_counter;           //counter value incremented everytime the adc triggers the daq
    reg        threshold_flag;          //this bit is set every time the adc triggers the daq and cleared as soon as it isn't
    reg        threshold_flag_sticky;   //this bit is set when the adc triggers the daq and only cleared by the reset_sticky_bits signal
    
    //declare auxillary signals for daq_status_register
    reg threshold_flag_old; //the value of the threshold_Flag from one clock cycle ago for edge detection
    
    //declare signals that will hold inputs from the daq_control_register
    wire signed [11:0]  threshold;              //threshold value used to trigger the daq (can be positive or negative
    wire                threshold_direction;    //determines whether the daq gets triggered when the adc value is above (0) or below (1) the threshold value
    wire                reset_sticky_bits;      //resets the sticky bits
    wire                reset_event_counter;    //resets the event counter
    
    reg signed [11:0] adc_value;
    reg [15:0] daq_adc_out;
    reg [15:0] daq_adc_out;
    reg [31:0] daq_status_reg;
    
    //assign the above registers based on the daq_control_reg value
    assign threshold           =    daq_control_reg[11:0];
    assign threshold_direction =    daq_control_reg[12];
    assign reset_sticky_bits   =    daq_control_reg[13];
    assign reset_event_counter =    daq_control_reg[14];

always begin
    #5
    clk=!clk;
end

initial begin
    rst=0;
    #100
    rst=1;
    daq_adc_out <= 16'b1111111111011001;
    #100;
    daq_adc_out <= 16'b0000000000001010;
end;


    always @ (posedge clk) begin
        if (~rst) begin
            
            
            //signals used in daq_status_register
            event_counter <= 16'd0;
            threshold_flag <= 1'b0;
            threshold_flag_sticky <= 1'b0;
            
            threshold_flag_old <= 1'b0;
            adc_value <= 12'd0;
            
            daq_status_reg <= 0;
            
        end else begin
            adc_value <= daq_adc_out[15:4];
            
            //assign the threshold flag
            if (threshold_direction == 1'b0) begin
                //threshold_direction=0 indicates greater than comparison
                threshold_flag <= (adc_value >= threshold) ? 1'b1:1'b0;
            end else begin
                //threshold_direction=1 indicates less than comparison
                threshold_flag <= (adc_value <= threshold) ? 1'b1:1'b0;
            end
            
            //set the theshold_flag_sticky
            if (reset_sticky_bits == 1'b1) begin
                threshold_flag_sticky <= 0;
            end else if (threshold_flag == 1'b1) begin
                threshold_flag_sticky <= 1'b1;
            end
            
            //increment the event counter if the threshold has just been met
            if (reset_event_counter == 1'b1) begin
                event_counter <= 16'd0;
            end else if (threshold_flag == 1'b1 && threshold_flag_old != threshold_flag) begin
                event_counter <= event_counter + 1'b1;
            end
            
            //save old threshold flag value for edge detection
            threshold_flag_old <= threshold_flag;
            
            //assign the daq_status_register
            daq_status_reg <= {14'd0, threshold_flag_sticky, threshold_flag, event_counter};
            
            //constantly read from the adc and report its value to the daq_adc_out register no matter what
        end
    end
endmodule
