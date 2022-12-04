/*
A module to act as a simple register interface for ps
*/


module registers(
    //interface for axi reads
    input aclk,
    input aresetn,
    
    input [7:0] ps_read_addr,
    input read_req,
    output reg [31:0] ps_read_data,
    output reg ps_read_valid,
    output reg ps_read_addr_err/*,
    input [7:0] ps_write_address,
    input [31:0] ps_write_data,
    input       ps_write_request,
    output reg  ps_write_addr_err*/
    
    //define any inputs needed for PL to assign PS read-only registers
    );
    
    //define pl read only addresses (start from 128)
    parameter control_register_0_addr = 128; //first non-read only address will be a register for PS to control operation of PL
    
    //define ps read only addresses (start from 0)
    parameter heartbeat_counter_register_addr = 0;                 // first PL writeable register is used to store a constantly incrementing heartbeat value (verify operation)
    parameter data_status_register_addr = 1;              // second PL writeable register is used to store status information about fifo/ other data registers
    parameter data_register_0_addr = 2;                   // third PL writeable register is used to store data to transfer to the PS
    
    
    //pl read-only registers
    reg [31:0] control_register_0 = 32'd0;
    
    //ps readonly registers
    reg [31:0] heartbeat_counter_register = 32'd0;
    reg [31:0] data_status_register = 32'd0;
    reg [31:0] data_register_0 = 32'd0;
    
    //assign PS read output
    /*always @* begin
        case (ps_read_addr)
            control_register_0_addr: begin
                ps_read_data = control_register_0;
                ps_read_addr_err = 1'b0;
            end
            
            heartbeat_counter_register_addr: begin
                ps_read_data = heartbeat_counter_register;
                ps_read_addr_err = 1'b0;
            end
            
            data_status_register_addr: begin
                ps_read_data = data_status_register;
                ps_read_addr_err = 1'b0;
            end
            
            data_register_0_addr: begin
                ps_read_data = data_status_register;
                ps_read_addr_err = 1'b0;
            end
            
            default: begin
                ps_read_data = 32'd0;
                ps_read_addr_err = 1'b1;
            end
            
        endcase
    end*/
    
    always @ (posedge aclk) begin
        if (aresetn == 1'b0) begin
            heartbeat_counter_register <= 32'd10;
            data_status_register <= 32'd3;
            data_register_0 <= 32'd2;
            control_register_0 <= 32'd0;
        end else begin
            heartbeat_counter_register <= 32'd10;
            data_status_register <= 32'd3;
            data_register_0 <= 32'd2;
            control_register_0 <= control_register_0;
            
            case (ps_read_addr)
            
                control_register_0_addr: begin
                
                    if(read_req == 1'b1) begin
                        ps_read_data <= control_register_0;
                        ps_read_addr_err <= 1'b0;
                        ps_read_valid <= 1'b1;
                    end else begin
                        ps_read_data <= 31'd0;
                        ps_read_addr_err <= 1'b0;
                        ps_read_valid <= 1'b0;
                    end
                    
                end
                
                heartbeat_counter_register_addr: begin
                    if(read_req == 1'b1) begin
                        ps_read_data = control_register_0;
                        ps_read_addr_err = 1'b0;
                        ps_read_valid <= 1'b1;
                    end else begin
                        ps_read_data = 31'd0;
                        ps_read_addr_err = 1'b0;
                        ps_read_valid <= 1'b0;
                    end
                end
                
                data_status_register_addr: begin
                    if(read_req == 1'b1) begin
                        ps_read_data = control_register_0;
                        ps_read_addr_err = 1'b0;
                        ps_read_valid <= 1'b1;
                    end else begin
                        ps_read_data = 31'd0;
                        ps_read_addr_err = 1'b0;
                        ps_read_valid <= 1'b0;
                    end
                end
                
                data_register_0_addr: begin
                    if(read_req == 1'b1) begin
                        ps_read_data = control_register_0;
                        ps_read_addr_err = 1'b0;
                        ps_read_valid <= 1'b1;
                    end else begin
                        ps_read_data = 31'd0;
                        ps_read_addr_err = 1'b0;
                        ps_read_valid <= 1'b0;
                    end
                end
                
                default: begin
                    ps_read_data = 32'd0;
                    ps_read_addr_err = 1'b1;
                    ps_read_valid <= 1'b0;
                end
            endcase
        end
    end 
    
endmodule
