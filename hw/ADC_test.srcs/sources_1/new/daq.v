/*
Author: Ben Sheffer
Date: 11/1/2022
last Update: 12/18/2022
Description: 
This module is meant to interface with an XADC core via the axi-stream interface (the xadc core is the axi master).
Each ADC value read will be checked against a threshold/trigger condition. When the threshold condition has been met,
all ADC values will be stored in a FIFO. The behavior of this module can be controlled and data from it read out via
registers in the axi_registers.v module.

Reading the FIFO data into the PS requires a handshake between the PS and the PL using the fifo_data_req and fifo_data_ack
signals ont he PS side and the fifo_req_ack signal on the PL side. The handshake consists of the following steps:
    1. The PS sets the fifo_data_req signals and clears the fifo_data_ack signal to request a new value from the FIFO
    2. The PL reads the next value from the FIFO, assigns it to the fifo_data_reg, and sets the fifo_req_ack signal
       to indicate that the requested FIFO value has been written to the fifo_data_reg
    3. The PS reads the fifo_data_reg, clears the fifo_data_req signal, and asserts the fifo_data_ack signal to indicate
       that the new FIFO value has been read from the fifo_data_reg
    4. The PL clears the fifo_req_ack bit
    5. The PS clears the fifo_data_ack bit
The PL will not write a new value to the fifo_data_reg until the previous handshake has been completed and a new value is
requested by the PS.

The general operation of the DAQ is controlled by the following bits in the daq_control_reg (only 1 for now):
    daq_control_reg[11:0] - adc threshold value in twos-compliment. This controls which values above or below which the data from
                            the adc is considered valid
    daq_control_reg[12]   - adc threshold write enable, when set, the threshold value from this register will be written into the
                            daq threshold regisgers                        
    daq_control_reg[13]   - this controls whether valid data is above or below the threshold 0 indicates that data must be above
                            the threshold, while 1 indicates that it must be below the threshold.
    daq_control_reg[14]   - threshold direction write enable, when set the value from                      
    daq_control_reg[15]   - Setting this bit will clear all sticky bits in the daq_status_register (some targeted reset sticky bit might be used later
    daq_control_reg[16]   - Setting this bit will reset the trigger counter in the daq_status_register
    daq_control_reg[17]   - fifo_reset, setting this bit will reset the data fifo (i.e. reset write and read pointers)
    daq_control_reg[18]   - fifo_data_req, this bit is set by the PS when it wants to load a new value from the fifo into
                            fifo_data_reg
    daq_control_reg[19]   - fifo_data_ack, this bit is set to indicate the PS has read the value currently held in the
                            fifo_data_reg
    
The general status of the daq is communicated via the following bits in the daq_status_reg
    daq_status_reg[15:0] - daq_event_counter incremented every time an event is recorded. for right now, this will mean whenever the
                           the ADC exceeds the threshold value, but this should later be updated to something more meaningful
    daq_status_reg[16]   - threshold flag that is set if the adc value is triggering the daq (exceeding the threshold in the positive
                           or negative direction as defined by bits  13 and 11:0 in the daq_control_register), this bit will clear as soon as
                           the adc value is no longer triggering the daq
    daq_status_reg[17]   - threshold flag sticky bit that is set if the adc value triggers the daq and only cleared by the user via the
                           daq_control_reg
    daq_status_reg[18]   - fifo empty
    daq_status_reg[19]   - fifo full
    daq_status_reg[20]   - fifo_data_req_ack, this signal is set when the output fifo data is  updated following a new data req
                           from the PS
*/

module daq(
    //input clock and reset
    input clk_in,
    input rst_in,
    
    input s_axis_tvalid,
    output reg s_axis_tready,
    input [15:0] s_axis_tdata,
    input [4:0] s_axis_tid,
    
    //interface with registers
    output reg [31:0] daq_status_reg,
    output reg [31:0] daq_adc_out,
    input [31:0] daq_control_reg,
  
    output wire ready_out,
    output wire valid_out,
    
    //fifo data output
    output reg [31:0] fifo_data_reg
    
    );
    
    //declare registers that will be used to assign the daq status register
    reg [15:0] event_counter;           //counter value incremented everytime the adc triggers the daq
    wire        threshold_flag;          //this bit is set every time the adc triggers the daq and cleared as soon as it isn't
    reg        threshold_flag_sticky;   //this bit is set when the adc triggers the daq and only cleared by the reset_sticky_bits signal
    
    //declare auxillary signals for daq_status_register
    reg threshold_flag_old; //the value of the threshold_Flag from one clock cycle ago for edge detection
    
    //declare signals that will hold inputs from the daq_control_register
    reg signed [11:0]  threshold = 0;              //threshold value used to trigger the daq (can be positive or negative
    reg                threshold_direction = 0;    //determines whether the daq gets triggered when the adc value is above (0) or below (1) the threshold value
    wire               reset_sticky_bits;      //resets the sticky bits
    wire               reset_event_counter;    //resets the event counter
    wire               fifo_reset;             //resets the fifo write/read pointers
    wire               fifo_data_req;          //requests new data to be loaded into the fifo_data_reg
    wire               fifo_data_ack;          //acknowledges that current fifo_data_reg has been read and can be overwritten
    
    reg signed [11:0] adc_value = 0;
    reg new_value_flag = 0;
    reg new_value_flag_piped;
    reg fifo_data_req_ack;
    
    //assign the above registers based on the daq_control_reg value
    assign reset_sticky_bits   =    daq_control_reg[15];
    assign reset_event_counter =    daq_control_reg[16];
    assign fifo_reset          =    daq_control_reg[17];
    assign fifo_data_req       =    daq_control_reg[18];
    assign fifo_data_ack       =    daq_control_reg[19];
           
    //assign signals for the adc stream interface
    assign ready_out = s_axis_tready;
    assign valid_out = s_axis_tvalid;
    
    assign threshold_flag = (threshold_direction) ? (adc_value <= threshold): (adc_value >= threshold);
    
    wire fifo_in_valid = (new_value_flag & threshold_flag);
    wire fifo_in_ready;
    
    wire fifo_out_valid;
    wire [32:0] fifo_out_data;
    reg fifo_out_ready = 0;
    
    wire fifo_full;
    wire fifo_empty;
    
    //add FIFO to the daq
    fifo daq_fifo(
        .clk_in(clk_in),
        .rst_in(rst_in & ~fifo_reset),
    
        .in_data({20'd0, adc_value}),
        .in_valid(fifo_in_valid),
        .in_ready(fifo_in_ready),
        
        .out_data(fifo_out_data),
        .out_valid(fifo_out_valid),
        .out_ready(fifo_out_ready),
        
        .full(fifo_full),
        .empty(fifo_empty)
    );

    //declare states for fifo read state machine
    reg [1:0] fifo_read_state = 0;
    parameter fifo_read_idle_state = 0;
    parameter fifo_read_load_state = 1;
    parameter fifo_read_wait_state = 2;
    
    always @ (posedge clk_in) begin
        if (~rst_in) begin
            //reset adc stream interface and output register
            s_axis_tready <= 1'b0;
            daq_status_reg <= 32'd0;
            daq_adc_out <= 32'd0;
            
            //signals used in daq_status_register
            event_counter <= 16'd0;
            /*threshold_flag <= 1'b0;*/
            threshold_flag_sticky <= 1'b0;
            
            threshold_flag_old <= 1'b0;
            adc_value <= 12'd0;
            
            threshold <= 12'd0;
            threshold_direction <= 1'b0;
            
            new_value_flag <= 1'b0;
            new_value_flag_piped <= 1'b0;
            
            fifo_out_ready <= 1'b0;
            fifo_read_state <= fifo_read_idle_state;    
        end else begin
            //if write enable bits are set, assign threshold and/or threshold direction
            if (daq_control_reg[12] == 1'b1) threshold <= daq_control_reg[11:0];
            if (daq_control_reg[14] == 1'b1) threshold_direction <= daq_control_reg[13];
            
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
            daq_status_reg <= {11'd0, fifo_data_req_ack, fifo_full, fifo_empty, 
                               threshold_flag_sticky, threshold_flag, event_counter};
            
            //constantly read from the adc and report its value to the daq_adc_out register no matter what
            s_axis_tready <= 1'b1;
            
            new_value_flag_piped <= new_value_flag; 
            if(s_axis_tvalid) begin
                daq_adc_out <= {16'd0,s_axis_tdata};
                adc_value <= s_axis_tdata[15:4];
                new_value_flag <= 1'b1;
            end else begin
                daq_adc_out <= daq_adc_out;
                new_value_flag <= 1'b0;
            end
        end
        
        /*** fifo read state machine ***/
        case(fifo_read_state)
            fifo_read_idle_state: begin
                //wait for the PS to request new data via the daq_control_reg
                if (fifo_data_req == 1'b1 && fifo_data_ack == 1'b0 && fifo_out_valid == 1'b1) begin
                    fifo_out_ready <= 1'b1;
                    fifo_data_reg <= fifo_out_data;
                    fifo_read_state <= fifo_read_load_state;
                    fifo_data_req_ack <= 1'b1;
                end
            end
            
            fifo_read_load_state: begin
                //write latest data from FIFO to the fifo_data_reg, set the req_ack bit in the daq_status_reg
                fifo_out_ready <= 1'b0;
                fifo_read_state <= fifo_read_wait_state;
            end
            
            fifo_read_wait_state: begin
                //wait for the PS to acknowledge it has read the new data via the daq_control_reg
                if (fifo_data_ack == 1'b1 && fifo_data_req == 1'b0) begin
                    fifo_data_req_ack <= 1'b0;
                    fifo_read_state <= fifo_read_idle_state;
                end
            end
            
            default: fifo_read_state <= fifo_read_idle_state;
        endcase
    end
    
endmodule
