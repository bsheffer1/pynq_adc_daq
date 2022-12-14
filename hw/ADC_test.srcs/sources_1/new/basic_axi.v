/* Ben Sheffer - 
This module contains a simple axi-lite slave port that will echo the address value that was attempted to be read.
This is simply meant to test how to implement an AXI port in a custom HDL module to interface with the Zynq 7 PS block 

Note: from running this, it is clear that the pyn overlay.ip.read(addr) function uses axi_raddr = (addr << 2), thus I am >>2 (i.e. ommitting the 2 LSBs) 
in the function below to remap
 */

module simple_readback
#(  parameter addr_width = 32,
    parameter data_width = 32,
    parameter addr_offset = 2)
(
    //axi slave clock and reset signals
    input s0_axi_aclk,
    input s0_axi_aresetn,
    
    //axi read address bus and control signals
    input [addr_width-1:0] s0_axi_araddr,
    output reg s0_axi_arready,
    input s0_axi_arvalid,
    
    //axi write address bus and control signals
    input [addr_width-1:0] s0_axi_awaddr,
    output reg s0_axi_awready,
    input s0_axi_awvalid,
    input s0_axi_bready,
    
    //axi write resp bus and control signals
    output reg [1:0] s0_axi_bresp,
    output reg s0_axi_bvalid,
    
    //axi read data bus and control signals
    output reg [data_width-1:0] s0_axi_rdata,
    input s0_axi_rready,
    output reg [1:0] s0_axi_rresp,
    output reg s0_axi_rvalid,
    
    //axi write data bus and control signals
    input [data_width-1:0] s0_axi_wdata,
    output reg s0_axi_wready,
    input [3:0] s0_axi_wstrb,
    input s0_axi_wvalid,
    
    output reg [3:0] led
);
    //define read address
    reg [7:0] read_addr = 8'd0;
    
    //define read state variable
    parameter read_idle = 1'b0;
    parameter write_rdata = 1'b1;
    
    reg  read_state = 1'b0;
    
    //define the write address
    reg [7:0] write_addr = 8'd0;
    
    //declare the write state variables
    parameter write_idle_state = 2'b00;
    parameter write_data_wait_state = 2'b01;
    parameter write_addr_wait_state = 2'b10;
    parameter write_commit_state = 2'b11;
    
    reg [1:0] write_state = 2'b00;
    reg [31:0] write_data = 32'd0;
    
    //define PL writeable register addresses (0-127)
    parameter heartbeat_counter_addr = 8'd0;
    
    //define PL writeable registers
    reg [31:0] heartbeat_counter = 32'd0;
    
    //define PS writeable register addresses (128-255)
    parameter control_register_0_addr = 8'd128;
    
    reg [31:0] control_register_0 = 31'd0;
    
    //read data statemachine, note that this doesn't have any handling for bursts for now
    always @ (posedge s0_axi_aclk) begin
        //reset condition (active low)
        if (s0_axi_aresetn == 1'b0) begin
            read_state <= read_idle;
            read_addr <= 8'd0;
            
            write_state <= write_idle_state;
            write_addr <= 8'd0;
            write_data <= 32'd0;
            
            s0_axi_arready  <= 1'b0;
            s0_axi_awready  <= 1'b0;
            s0_axi_bresp    <= 2'b00;
            s0_axi_bvalid   <= 1'b0;
            s0_axi_rdata    <= 32'd0;
            s0_axi_rresp    <= 2'b00;
            s0_axi_rvalid   <= 1'b0;
            s0_axi_wready   <= 1'b0;
            heartbeat_counter <= 32'd0;
            control_register_0 <= 32'd0;
            
            led <= 4'b0000;
        end else begin
            //run read state machine if not in reset condition
            case (read_state)
                read_idle: begin
                //set arready signal low, wait for ARValid signal, once set, read raddr, set arready high, transition to write_rdata state
                    if (s0_axi_arvalid == 1'b1) begin
                        read_addr       <= s0_axi_araddr[9:2];
                        s0_axi_arready  <= 1'b1;
                        read_state      <= write_rdata;
                    end
                    //clear rvalid and data (should have already cleared, but...)
                    s0_axi_rdata    <= 32'd0;
                    s0_axi_rvalid   <= 1'b0;
                end //end of read_idle state
                
                write_rdata: begin
                    //clear arready
                    s0_axi_arready <= 1'b0;
                    read_addr <= read_addr;
                    
                    //set data and wait for rready to be asserted
                    if (s0_axi_rready == 1'b0) begin
                        //set set rvalid and set okay code for rresp
                        s0_axi_rvalid   <= 1'b1;
                        s0_axi_rresp    <= 2'b00;
                        //set read data, return address to help figure out how addresses are encoded in the axi_smc
                        case(read_addr)
                            heartbeat_counter_addr: s0_axi_rdata <= heartbeat_counter;//read_addr;
                            
                            control_register_0_addr: s0_axi_rdata <= control_register_0;//read_addr;
                            
                            //TODO: add any additional registers added in the future (all registers should be readable by PS)
                           
                            default: s0_axi_rdata <= 32'd0;
                        endcase
                        
                    end else begin
                        //clear read bus output signals and transition to the idle state once rready is asserted
                        s0_axi_rvalid   <= 1'b0;
                        s0_axi_rdata    <= 32'b0;
                        s0_axi_rresp    <= 2'b00; 
                        
                        read_state      <= read_idle;
                    end              
                end //end of write_rdata state
                
                default: read_state <= read_idle;
            endcase
            
            /**************************************************/
            /*axi write state machine logic                   */
            /**************************************************/
            led[0] <= read_state;
            led[1] <= write_state[1];
            led[2] <= s0_axi_bvalid;
            led[3] <= s0_axi_bready;
            case(write_state)
                write_idle_state: begin
                    //wait for a valid signal, keep ready asserted
                    s0_axi_bresp    <= 2'b00;
                    s0_axi_bvalid   <= 1'b0;
                    
                    if (s0_axi_awvalid == 1'b1 && s0_axi_wvalid == 1'b1) begin
                    //if address and data are valid simultaneously, we can go righ to the commit state
                        write_state     <= write_commit_state;
                        s0_axi_awready  <= 1'b1;
                        s0_axi_wready   <= 1'b1;
                        write_addr      <= s0_axi_awaddr[9:2];
                        write_data      <= s0_axi_wdata;
                    end else if (s0_axi_awvalid == 1'b1 && s0_axi_wvalid == 1'b0) begin
                    //if the address data is valid before data, we have to wait for data before committing
                        write_state     <= write_data_wait_state;
                        s0_axi_awready  <= 1'b1;
                        write_addr      <= s0_axi_awaddr[9:2];
                    end else if (s0_axi_awvalid == 1'b0 && s0_axi_wvalid == 1'b1) begin
                    //if the data is valid before the addr, we have to wait for addr before committing
                        write_state     <= write_addr_wait_state;
                        s0_axi_wready   <= 1'b1;
                        write_data      <= s0_axi_wdata;
                    end
                end
                
                write_data_wait_state: begin
                    s0_axi_awready  <= 1'b0;
                    s0_axi_bresp    <= 2'b00;
                    s0_axi_bvalid   <= 1'b0;

                    if (s0_axi_wvalid == 1'b1) begin
                    //the addr is already valid, so wait for data to be valid and then transition to the commit state
                        write_state     <= write_commit_state;
                        s0_axi_wready   <= 1'b1;
                        write_data      <= s0_axi_wdata;
                    end
                end
                
                write_addr_wait_state: begin
                    s0_axi_wready   <= 1'b0;
                    s0_axi_bresp    <= 2'b00;
                    s0_axi_bvalid   <= 1'b0;
                    
                    if (s0_axi_awvalid == 1'b1) begin
                    //the data is already valid so wait for the addr to ve valid and then transition to the commit state
                        write_state     <= write_commit_state;
                        s0_axi_awready  <= 1'b1;
                        write_addr      <= (s0_axi_awaddr >> addr_offset);
                    end
                end
                
                write_commit_state: begin
                    s0_axi_awready  <= 1'b0;
                    s0_axi_wready   <= 1'b0;
                    if (s0_axi_bready == 1'b0) begin
                        s0_axi_bresp                <= 2'b00;
                        s0_axi_bvalid               <= 1'b1;
                    end else begin
                        write_state <= write_idle_state;
                        s0_axi_bresp                <= 2'b00;
                        s0_axi_bvalid               <= 1'b0;
                    end
                    //write_state <= write_idle_state;
                    case (write_addr)
                        control_register_0_addr: control_register_0 <= write_data;
                        
                        //TODO: add additional PS writeable registers as necessary
                    endcase
                end
                
                default: write_state <= write_idle_state;
            endcase
        
            //user logic to define PL writeable registers
            heartbeat_counter <= heartbeat_counter + 32'd1;
            
        end //not in reset else block
    end

endmodule