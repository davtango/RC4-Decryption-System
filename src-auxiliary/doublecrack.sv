
// STATE INSTANTIATIONS FOR DOUBLECRACK

`define READY 3'b000
`define CT1 3'b001 
`define CT2 3'b010 
`define EN_CRACKS 3'b011 
`define IN_CRACKS 3'b100 
`define PT1 3'b101 
`define PT2 3'b110 

module doublecrack(input logic clk, input logic rst_n,
             input logic en, output logic rdy,
             output logic [23:0] key, output logic key_valid,
             output logic [7:0] ct_addr, input logic [7:0] ct_rddata);

    // Logic Instantiations

    // controlled by dc

    logic [7:0] dc_pt_addr, dc_pt_wrdata, dc_pt_rddata;
    logic dc_pt_wren;

    logic [7:0] dc_ct_addr_c1, dc_ct_addr_c2; // to be surrendered to the cores in `IN_CRACKS
    logic [7:0] dc_ct_wrdata;
    logic dc_ct_wren;

    // ---

    logic [7:0] pt_addr_c1, pt_addr_c2; // driven in `PT_LOAD
    logic [7:0] pt_rddata_c1, pt_rddata_c2;

    logic [7:0] ct_addr_c1, ct_addr_c2; // driven by the cores, given control in `IN_CRACKS
    logic [7:0] ct_rddata_c1, ct_rddata_c2; 

    logic [23:0] key_c1, key_c2;

    logic [23:0] dc_initial_key_c1, dc_initial_key_c2, dc_key_inc;
    logic key_valid_c1, key_valid_c2;

    logic rst_n_c1, rst_n_c2; // used to properly implement rdy/en microprotocol
    logic en_c1, en_c2;
    logic rdy_c1, rdy_c2;

    // States and Incrementers

    logic [2:0] present_state, next_state;
    logic [7:0] current_c, next_c; // iterator for CT[c]
    logic [7:0] current_p, next_p; // iterator for PT[p]

    // Signal to stop all cores upon decryption 

    logic stop_flag, next_stop_flag;

    // Module Instantiations

    // this memory must have the length-prefixed plaintext if key_valid
    pt_mem pt( .address(dc_pt_addr), .clock(clk), .data(dc_pt_wrdata), .wren(dc_pt_wren), .q(dc_pt_rddata));
    
    // additional ciphertext memory instantiations for c1 and c2
    
    ct_mem ct_c1( .address(dc_ct_addr_c1), .clock(clk), .data(dc_ct_wrdata), .wren(dc_ct_wren), .q(ct_rddata_c1));
    ct_mem ct_c2( .address(dc_ct_addr_c2), .clock(clk), .data(dc_ct_wrdata), .wren(dc_ct_wren), .q(ct_rddata_c2));

    // for this task only, you may ADD ports to crack
    crack c1( .clk(clk), .rst_n(rst_n_c1), .en(en_c1), .rdy(rdy_c1), .key(key_c1), .key_valid(key_valid_c1), .ct_addr(ct_addr_c1), .ct_rddata(ct_rddata_c1),
              .dc_initial_key(dc_initial_key_c1), .dc_key_inc(dc_key_inc), .dc_pt_addr(pt_addr_c1), .dc_pt_rddata(pt_rddata_c1), .stop_flag(stop_flag));

    crack c2( .clk(clk), .rst_n(rst_n_c2), .en(en_c2), .rdy(rdy_c2), .key(key_c2), .key_valid(key_valid_c2), .ct_addr(ct_addr_c2), .ct_rddata(ct_rddata_c2),
              .dc_initial_key(dc_initial_key_c2), .dc_key_inc(dc_key_inc), .dc_pt_addr(pt_addr_c2), .dc_pt_rddata(pt_rddata_c2), .stop_flag(stop_flag));

    // Logic Assignments

    assign dc_initial_key_c1 = 24'd0;
    assign dc_initial_key_c2 = 24'd1;
    assign dc_key_inc = 24'd2;
    
    assign key_valid = key_valid_c1 || key_valid_c2; 

    // State Output Logic

    always_comb begin 

        // doublecrack initializations
        
        dc_pt_addr = 8'd0;
        dc_pt_wrdata = 8'd0; 
        dc_pt_wren = 1'b0; 
        
        dc_ct_addr_c1 = 8'd0;
        dc_ct_addr_c2 = 8'd0;
        dc_ct_wrdata = 8'd0;
        dc_ct_wren = 1'b0;

        ct_addr = 8'd0;

        // ---

        pt_addr_c1 = 8'd0; 
        pt_addr_c2 = 8'd0;

        // 
        
        rst_n_c1 = 1'b1; // de-assert reset
        rst_n_c2 = 1'b1; // de-assert reset
        en_c1 = 1'b0; // de-assert enable for core 1
        en_c2 = 1'b0; // de-assert enable for core 2
        
        next_c = current_c; // initialize c counter 
        next_p = current_p;

        rdy = 1'b0;

        key = 24'b0;

        next_stop_flag = stop_flag; // flag

        case(present_state) 
            `READY: begin
                rdy = 1'b1;

                if(key_valid_c1 == 1'b1) key = key_c1; 
                else if(key_valid_c2 == 1'b1) key = key_c2; 
                else key = 24'b0;

            end
            `CT1: begin 
                ct_addr = current_c; // set address of the top module CT mem
                next_stop_flag = 1'b0; // reset the stop_flag on second & onward runs of doublecrack 
                rst_n_c1 = 1'b0; // reset both cores on second & onward runs of doublecrack
                rst_n_c2 = 1'b0;
            end
            `CT2: begin 
                dc_ct_wrdata = ct_rddata; // write top module CT[c] to CT cores 1 & 2
                dc_ct_wren = 1'b1; // enable wren to CT cores 1 & 2 
                dc_ct_addr_c1 = current_c; // set address to current_c for CT core 1 
                dc_ct_addr_c2 = current_c; // set address to current_c for CT core 2 
                next_c = current_c + 8'd1; // increment current_c
            end
            `EN_CRACKS: begin 
                en_c1 = 1'b1; // enable core 1
                en_c2 = 1'b1; // enable core 2 
            end
            `IN_CRACKS: begin 
                dc_ct_addr_c1 = ct_addr_c1; // surrender control to core 1 
                dc_ct_addr_c2 = ct_addr_c2; // surrender control to core 2 
            end
            `PT1: begin 
                pt_addr_c1 = current_p;
                pt_addr_c2 = current_p;
                next_stop_flag = 1'b1; // if we're here, stop all other cores
            end
            `PT2: begin 
                if(key_valid_c1 == 1'b1) begin 
                    dc_pt_wrdata = pt_rddata_c1; 
                    dc_pt_wren = 1'b1; 
                    dc_pt_addr = current_p; 
                    next_p = current_p + 8'd1; 
                end
                else if(key_valid_c2 == 1'b1) begin 
                    dc_pt_wrdata = pt_rddata_c2; 
                    dc_pt_wren = 1'b1; 
                    dc_pt_addr = current_p; 
                    next_p = current_p + 8'd1;
                end
                else next_p = current_p + 8'd1;
            end
            default: ;
        endcase
    end

    // State Transition Logic

    always_comb begin 
        case(present_state)
        `READY: begin 
            if(en == 1'b1) next_state = `CT1;
            else next_state = `READY;
        end
        `CT1: next_state = `CT2;
        `CT2: begin 
            if(current_c == 8'd255) next_state = `EN_CRACKS;
            else next_state = `CT1;
        end
        `EN_CRACKS: next_state = `IN_CRACKS;
        `IN_CRACKS: begin 
            if(rdy_c1 == 1'b0 && rdy_c2 == 1'b0) next_state = `IN_CRACKS;
            else next_state = `PT1;
        end
        `PT1: next_state = `PT2;
        `PT2: begin 
            if(current_p == 8'd255) next_state = `READY;
            else next_state = `PT1;
        end
        default: next_state = `READY;
        endcase
    end

    // State Register Logic 

    always_ff@(posedge clk) begin 
        if(rst_n == 1'b0) begin 
            present_state <= `READY;
            current_c <= 8'd0; 
            current_p <= 8'd0; 
            stop_flag <= 1'b0;
        end
        else begin 
            present_state <= next_state;
            current_c <= next_c;
            current_p <= next_p;
            stop_flag <= next_stop_flag;
        end
    end

endmodule: doublecrack
