
// State Definitions for CRACK module

`define READY 3'b000
`define GET_ML 3'b001
`define ENABLE_ARC4 3'b010 
`define IN_ARC4 3'b011
`define PT_WAIT 3'b100
`define PT_CHECKER 3'b101
`define KEY_INC 3'b110 // key incrementer 

module crack(input logic clk, input logic rst_n,
             input logic en, output logic rdy,
             output logic [23:0] key, output logic key_valid,
             output logic [7:0] ct_addr, input logic [7:0] ct_rddata,
             input logic [23:0] dc_initial_key, input logic [23:0] dc_key_inc, input logic [7:0] dc_pt_addr, output logic [7:0] dc_pt_rddata,
             input logic stop_flag);

             // MODIFIED PORTS FOR DOUBLECRACK.SV & MULTICRACK.SV
             // 1. dc_initial_key -> Sets initial reset value for the key, specified by doublecrack. (originally hardcoded 1 for task 4)
             // 2. dc_key_inc -> Sets key incrementing value, specified by doublecrack.(originally hardcoded 1 for task 4)
             // 3. dc_pt_addr -> Sets address for pt mem, specified by doublecrack. control of pt_addr is surrendered to doublecrack in state `READY
             // 4. dc_pt_rddata -> wired as an output so that it can be read by doublecrack

             // 5. stop_flag -> wired as an input, asserted by double_crack. forces all cores to return to `READY

    // Logic instantiations b/t Modules

    logic [7:0] pt_addr, pt_rddata, pt_wrdata;
    logic pt_wren;
    
    logic en_arc4, rst_n_arc4, rdy_arc4;
    logic [7:0] ct_addr_arc4;
    logic [7:0] pt_addr_arc4, pt_wrdata_arc4;
    logic pt_wren_arc4;

    // other Logic Instantiations

    logic [2:0] present_state, next_state; 

    logic [23:0] current_key, next_key;
    logic [7:0] current_pt_i, next_pt_i;
    logic [7:0] message_length, next_message_length;

    logic current_flag, next_flag; // flag indicates whether to set key_valid ON or OFF

    // Module Instantiations

    // this memory must have the length-prefixed plaintext if key_valid
    ptcore_mem pt( .address(pt_addr), .clock(clk), .data(pt_wrdata), .wren(pt_wren), .q(pt_rddata));

    arc4 a4( .clk(clk), .rst_n(rst_n_arc4), .en(en_arc4), .rdy(rdy_arc4), .key(current_key), .ct_addr(ct_addr_arc4), .ct_rddata(ct_rddata), .pt_addr(pt_addr_arc4), .pt_rddata(pt_rddata),
                        .pt_wrdata(pt_wrdata_arc4), .pt_wren(pt_wren_arc4));

    // Assignments

    assign key = current_key;
    assign dc_pt_rddata = pt_rddata; // to be read by doublecrack

    // State Output Logic 

    always_comb begin 

        en_arc4 = 1'b0; // disable en_arc4 by default
        rst_n_arc4 = 1'b1; // disable reset arc4 by default

        next_key = current_key; // Initialize key as 24'h0
        next_pt_i = current_pt_i; // Start at 1 - we know length is not encrpyted, so we start at PT[1]
        next_message_length = message_length;
        next_flag = current_flag; // flag logic moved to this block

        key_valid = 1'b0;
        rdy = 1'b0;

        ct_addr = 8'b0;
        pt_addr = 8'b0; 
        pt_wrdata = 8'b0;
        pt_wren = 1'b0;

        case(present_state)
        `READY: begin 
            rdy = 1'b1; // indicates that crack module is ready
            rst_n_arc4 = 1'b0; // enable reset for arc4 module
            if(current_flag == 1'b1) key_valid = 1'b1; 
            else key_valid = 1'b0;
            pt_addr = dc_pt_addr; // in `READY. pt_addr is surrendered to doublecrack. before crack in `READY, this is always initialized to 0. utilized after crack by doublecrack.
        end
        `GET_ML: begin 
            next_message_length = ct_rddata;
        end
        `ENABLE_ARC4: begin 
            en_arc4 = 1'b1; // enable en-arc4 
        end
        `IN_ARC4: begin 
            ct_addr = ct_addr_arc4;
            pt_addr = pt_addr_arc4; 
            pt_wrdata = pt_wrdata_arc4;
            pt_wren = pt_wren_arc4;
        end
        `PT_WAIT: begin 
            pt_addr = current_pt_i;
        end
        `PT_CHECKER: begin 
            pt_addr = current_pt_i + 8'd1; // lookie lookie ahead
            next_pt_i = current_pt_i + 8'd1; // NEEDS TO BE RESET IN KEY_INC
            if(current_pt_i == message_length && pt_rddata >= 8'h20 && pt_rddata <= 8'h7E) begin 
                next_flag = 1'b1;
            end
            else next_flag = 1'b0;
        end
        `KEY_INC: begin 
            rst_n_arc4 = 1'b0; // enable reset for arc4 module
            next_key = current_key + dc_key_inc; // 
            next_pt_i = 8'd1; // reset pt_i to index 1 after PT_CHECKER confirms that key is incorrect
            if(current_key >= 24'hFFFFFE) begin 
                next_flag = 1'b0;
            end
            else next_flag = 1'b0;
        end
        default: ;
        endcase
    end

    // State Transition Logic

    always_comb begin 

        case(present_state)
        `READY: begin 
            if(en == 1'b1) next_state = `GET_ML;
            else if(stop_flag == 1'b1) next_state = `READY;
            else next_state = `READY;
        end
        `GET_ML: begin 
            if(stop_flag == 1'b1) next_state = `READY;
            else next_state = `ENABLE_ARC4;
        end
        `ENABLE_ARC4: begin 
            if(stop_flag == 1'b1) next_state = `READY;
            else next_state = `IN_ARC4;
        end
        `IN_ARC4: begin 
            if(stop_flag == 1'b1) next_state = `READY;
            else if(rdy_arc4 == 1'b0) next_state = `IN_ARC4;
            else next_state = `PT_WAIT;
        end
        `PT_WAIT: begin 
            if(stop_flag == 1'b1) next_state = `READY;
            else next_state = `PT_CHECKER;
        end
        `PT_CHECKER: begin 
            if(stop_flag == 1'b1) next_state = `READY;
            else if(current_pt_i == message_length && pt_rddata >= 8'h20 && pt_rddata <= 8'h7E) begin 
                next_state = `READY;
            end
            else if(pt_rddata >= 8'h20 && pt_rddata <= 8'h7E) next_state = `PT_CHECKER;
            else next_state = `KEY_INC;
        end
        `KEY_INC: begin 
            if(stop_flag == 1'b1) next_state = `READY;
            else if(current_key >= 24'hFFFFFE) begin 
                next_state = `READY;
            end
            else next_state = `ENABLE_ARC4;
        end
        default: begin 
            if(stop_flag == 1'b1) next_state = `READY;
            else next_state = `READY;
        end
        endcase
    end

    // State Register Logic

    always_ff@(posedge clk) begin 
        if(rst_n == 1'b0) begin 
            present_state <= `READY; // active low-sync reset
            message_length <= 8'd0; 
            current_pt_i <= 8'd1;
            current_flag <= 1'b0; 
            current_key <= dc_initial_key;
        end
        else begin 
            present_state <= next_state;
            message_length <= next_message_length;
            current_pt_i <= next_pt_i; 
            current_key <= next_key;
            current_flag <= next_flag;
        end
    end

endmodule: crack
