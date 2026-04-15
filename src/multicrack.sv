
// STATE INSTANTIATIONS FOR MULTICRACK

`define READY 3'b000
`define CT1 3'b001 
`define CT2 3'b010 
`define EN_CRACKS 3'b011 
`define IN_CRACKS 3'b100 
`define PT1 3'b101 
`define PT2 3'b110 

module multicrack(input logic clk, input logic rst_n,
             input logic en, output logic rdy,
             output logic [23:0] key, output logic key_valid,
             output logic [7:0] ct_addr, input logic [7:0] ct_rddata);

    // Parameter & Genvar Instantiations

    parameter int num_cores = 81; // usage of parameter to dictate # of cores, 81 is max. @ 82, 3224 LABs required but DE1SOC only has 3207!
    genvar i; // incrementer for generate blocks
    int j; // incrementer for for loops

    // Logic Instantiations

    // controlled by mc - exempt from automation 

    logic [7:0] dc_pt_addr, dc_pt_wrdata, dc_pt_rddata;
    logic dc_pt_wren;

    //--- 

    // logic [7:0] dc_ct_addr_c1, dc_ct_addr_c2; // to be surrendered to the cores in `IN_CRACKS - to be automated
    logic [num_cores-1:0][7:0] dc_ct_addr_c; // multidimensional packed array for dc_ct_addr_c

    logic [7:0] dc_ct_wrdata; // exempt from automation
    logic dc_ct_wren; // exempt from automation

    // ---

    // logic [7:0] pt_addr_c1, pt_addr_c2; // driven in `PT_LOAD
    logic [num_cores-1:0][7:0] pt_addr_c;
    // logic [7:0] pt_rddata_c1, pt_rddata_c2;
    logic [num_cores-1:0][7:0] pt_rddata_c;

    // logic [7:0] ct_addr_c1, ct_addr_c2; // driven by the cores, given control in `IN_CRACKS
    logic [num_cores-1:0][7:0] ct_addr_c;
    // logic [7:0] ct_rddata_c1, ct_rddata_c2; 
    logic [num_cores-1:0][7:0] ct_rddata_c; 

    // ---

    // logic [23:0] key_c1, key_c2;
    logic [num_cores-1:0][23:0] key_c;
    // logic [23:0] dc_initial_key_c1, dc_initial_key_c2 
    logic [num_cores-1:0][23:0] dc_initial_key_c;

    logic [23:0] dc_key_inc; // universal for all cores
    
    // logic key_valid_c1, key_valid_c2;
    logic [num_cores-1:0] key_valid_c;

    // logic rst_n_c1, rst_n_c2; // used to properly implemented rdy/en microprotocol
    logic [num_cores-1:0] rst_n_c;
    // logic en_c1, en_c2;
    logic [num_cores-1:0] en_c;
    // logic rdy_c1, rdy_c2;
    logic [num_cores-1:0] rdy_c;

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
    // OLD
    /*
    ctcore_mem ct_c1( .address(dc_ct_addr_c1), .clock(clk), .data(dc_ct_wrdata), .wren(dc_ct_wren), .q(ct_rddata_c1));
    ctcore_mem ct_c2( .address(dc_ct_addr_c2), .clock(clk), .data(dc_ct_wrdata), .wren(dc_ct_wren), .q(ct_rddata_c2));
    */

    generate 
        for(i = 0; i < num_cores; i = i + 1) begin: ctcores
            ctcore_mem ct_c( .address(dc_ct_addr_c[i]), .clock(clk), .data(dc_ct_wrdata), .wren(dc_ct_wren), .q(ct_rddata_c[i]));
        end
    endgenerate

    // ---------------------------------------------------------

    // Core Instantiations
    // OLD
    /*
    crack c1( .clk(clk), .rst_n(rst_n_c1), .en(en_c1), .rdy(rdy_c1), .key(key_c1), .key_valid(key_valid_c1), .ct_addr(ct_addr_c1), .ct_rddata(ct_rddata_c1),
              .dc_initial_key(dc_initial_key_c1), .dc_key_inc(dc_key_inc), .dc_pt_addr(pt_addr_c1), .dc_pt_rddata(pt_rddata_c1), .stop_flag(stop_flag));

    crack c2( .clk(clk), .rst_n(rst_n_c2), .en(en_c2), .rdy(rdy_c2), .key(key_c2), .key_valid(key_valid_c2), .ct_addr(ct_addr_c2), .ct_rddata(ct_rddata_c2),
              .dc_initial_key(dc_initial_key_c2), .dc_key_inc(dc_key_inc), .dc_pt_addr(pt_addr_c2), .dc_pt_rddata(pt_rddata_c2), .stop_flag(stop_flag));
    */

    generate 
        for(i = 0; i < num_cores; i = i + 1) begin: crackcores 
            crack c(.clk(clk), .rst_n(rst_n_c[i]), .en(en_c[i]), .rdy(rdy_c[i]), .key(key_c[i]), .key_valid(key_valid_c[i]), .ct_addr(ct_addr_c[i]), .ct_rddata(ct_rddata_c[i]),
                    .dc_initial_key(dc_initial_key_c[i]), .dc_key_inc(dc_key_inc), .dc_pt_addr(pt_addr_c[i]), .dc_pt_rddata(pt_rddata_c[i]), .stop_flag(stop_flag));
        end
    endgenerate

    // ---------------------------------------------------------

    // Logic Assignments
    /*
    assign dc_initial_key_c1 = 24'd0;
    assign dc_initial_key_c2 = 24'd1;
    assign dc_key_inc = 24'd2;
    */
    
    assign dc_key_inc = 24'(num_cores); // each core increments their key by the total number of cores
    assign key_valid = |key_valid_c; // bit-wise OR all core key_valid outputs

    // State Output Logic

    always_comb begin 

        // Instantiations for dc_initial_key_c 

        for( j = 0; j < num_cores; j = j + 1) begin 
            dc_initial_key_c[j] = 24'(j); 
        end

        // doublecrack initializations
        
        dc_pt_addr = 8'd0;
        dc_pt_wrdata = 8'd0; 
        dc_pt_wren = 1'b0; 
        
        // dc_ct_addr_c1 = 8'd0; // automated
        // dc_ct_addr_c2 = 8'd0; // automated

        for( j = 0; j < num_cores; j = j + 1) begin 
            dc_ct_addr_c[j] = 8'd0;
        end

        dc_ct_wrdata = 8'd0;
        dc_ct_wren = 1'b0;

        ct_addr = 8'd0; // interacts with CT in top module 

        // ---

        // pt_addr_c1 = 8'd0; // automated
        // pt_addr_c2 = 8'd0; // automated

        for( j = 0; j < num_cores; j = j + 1) begin 
            pt_addr_c[j] = 8'd0;
        end

        // ---
        
        // rst_n_c1 = 1'b1; // de-assert reset                     
        // rst_n_c2 = 1'b1; // de-assert reset
        for( j = 0; j < num_cores; j = j + 1) begin 
            rst_n_c[j] = 1'b1;
        end

        // en_c1 = 1'b0; // de-assert enable for core 1
        // en_c2 = 1'b0; // de-assert enable for core 2 
        for( j = 0; j < num_cores; j = j + 1) begin 
            en_c[j] = 1'b0;
        end

        // ---
        
        next_c = current_c; // initialize c counter 
        next_p = current_p;

        rdy = 1'b0;

        key = 24'b0;

        next_stop_flag = stop_flag; // flag

        case(present_state) 
            `READY: begin
                rdy = 1'b1;

                /*
                if(key_valid_c1 == 1'b1) key = key_c1; 
                else if(key_valid_c2 == 1'b1) key = key_c2; 
                else key = 24'b0;
                */
                for( j = 0; j < num_cores; j = j + 1) begin 
                    if(key == 24'b0 && key_valid_c[j] == 1'b1) key = key_c[j]; 
                    // no need for an else key = 24'b0, handled once state is left
                end

            end
            `CT1: begin 
                ct_addr = current_c; // set address of the top module CT mem
                next_stop_flag = 1'b0; // reset the stop_flag on second & onward runs of doublecrack 
                /*
                rst_n_c1 = 1'b0; // reset both cores on second & onward runs of doublecrack
                rst_n_c2 = 1'b0;
                */
                for( j = 0; j < num_cores; j = j + 1) begin 
                    rst_n_c[j] = 1'b0;
                end
            end
            `CT2: begin 
                dc_ct_wrdata = ct_rddata; // write top module CT[c] to CT cores 1 & 2
                dc_ct_wren = 1'b1; // enable wren to CT cores 1 & 2 
                next_c = current_c + 8'd1; // increment current_c
                /*
                dc_ct_addr_c1 = current_c; // set address to current_c for CT core 1 
                dc_ct_addr_c2 = current_c; // set address to current_c for CT core 2 
                */
                for( j = 0; j < num_cores; j = j + 1) begin 
                    dc_ct_addr_c[j] = current_c;
                end
            end
            `EN_CRACKS: begin 
                /*
                en_c1 = 1'b1; // enable core 1
                en_c2 = 1'b1; // enable core 2 
                */
                for( j = 0; j < num_cores; j = j + 1) begin 
                    en_c[j] = 1'b1;
                end
            end
            `IN_CRACKS: begin 
                /*
                dc_ct_addr_c1 = ct_addr_c1; // surrender control to core 1 
                dc_ct_addr_c2 = ct_addr_c2; // surrender control to core 2 
                */
                for( j = 0; j < num_cores; j = j + 1) begin 
                    dc_ct_addr_c[j] = ct_addr_c[j];
                end
            end
            `PT1: begin 
                /*
                pt_addr_c1 = current_p;
                pt_addr_c2 = current_p;
                */ 
                for( j = 0; j < num_cores; j = j + 1) begin 
                    pt_addr_c[j] = current_p;
                end
                next_stop_flag = 1'b1; // if we're here, stop all other cores
            end
            `PT2: begin 
                /*
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
                */
                for( j = 0; j < num_cores; j = j + 1) begin 
                    if(key_valid_c[j] == 1'b1) begin 
                        dc_pt_wrdata = pt_rddata_c[j]; 
                        dc_pt_wren = 1'b1; 
                        dc_pt_addr = current_p;
                        // next_p = current_p + 8'd1; 
                    end
                end

                next_p = current_p + 8'd1; 
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
            /*
            if(rdy_c1 == 1'b0 && rdy_c2 == 1'b0) next_state = `IN_CRACKS;
            else next_state = `PT1;
            */
            if(|rdy_c == 1'b0) next_state = `IN_CRACKS;
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

endmodule: multicrack
