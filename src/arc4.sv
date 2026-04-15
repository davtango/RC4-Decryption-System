
`define READY 3'b000
`define ENABLE_INIT 3'b001 
`define IN_INIT 3'b010 
`define ENABLE_KSA 3'b011 
`define IN_KSA 3'b100 
`define ENABLE_PRGA 3'b101
`define IN_PRGA 3'b110 

module arc4(input logic clk, input logic rst_n,
            input logic en, output logic rdy,
            input logic [23:0] key,
            output logic [7:0] ct_addr, input logic [7:0] ct_rddata,
            output logic [7:0] pt_addr, input logic [7:0] pt_rddata, output logic [7:0] pt_wrdata, output logic pt_wren);

    // Logic Instantiations

    // for S RAM block 

    logic [7:0] s_addr, s_addr_init, s_addr_ksa, s_addr_prga;
    logic [7:0] s_wrdata, s_wrdata_init, s_wrdata_ksa, s_wrdata_prga;
    logic s_wren, s_wren_init, s_wren_ksa, s_wren_prga;

    logic [7:0] s_rddata; // driven only by S block, shared as input by init, ksa, and prga

    // for CT, PT blocks (mainly for prga)

    logic [7:0] ct_addr_prga;
    logic [7:0] pt_addr_prga;
    logic [7:0] pt_wrdata_prga;
    logic pt_wren_prga;

    // Ready and Enable Signals

    logic rdy_init, rdy_ksa, rdy_prga;
    logic en_init, en_ksa, en_prga;

    // State Logic

    logic [2:0] present_state, next_state;

    // Module Instantiations

    s_mem s( .address(s_addr), .clock(clk), .data(s_wrdata), .wren(s_wren), .q(s_rddata));

    init i( .clk(clk), .rst_n(rst_n), .en(en_init), .rdy(rdy_init), .addr(s_addr_init), .wrdata(s_wrdata_init), .wren(s_wren_init));

    ksa k( .clk(clk), .rst_n(rst_n), .en(en_ksa), .rdy(rdy_ksa), .key(key), .addr(s_addr_ksa), .rddata(s_rddata), .wrdata(s_wrdata_ksa), .wren(s_wren_ksa));

    prga p( .clk(clk), .rst_n(rst_n), .en(en_prga), .rdy(rdy_prga), .key(key), .s_addr(s_addr_prga), .s_rddata(s_rddata), .s_wrdata(s_wrdata_prga), .s_wren(s_wren_prga),
            .ct_addr(ct_addr_prga), .ct_rddata(ct_rddata),
            .pt_addr(pt_addr_prga), .pt_rddata(pt_rddata), .pt_wrdata(pt_wrdata_prga), .pt_wren(pt_wren_prga));

            // bro -_-, fixed s_wren_prga typo and completed task 3

    // State Output Logic

    always_comb begin 

        rdy = 1'b0;

        // By default, tied to prga as they are not used by any other modules
        ct_addr = ct_addr_prga;
        pt_addr = pt_addr_prga;
        pt_wrdata = pt_wrdata_prga;
        pt_wren = pt_wren_prga;
        //-------------------------------------------------------------------

        s_addr = 8'b0;
        s_wrdata = 8'b0;
        s_wren = 1'b0; 

        en_init = 1'b0;
        en_ksa = 1'b0;
        en_prga = 1'b0;

        case(present_state)
        `READY: begin 
            rdy = 1'b1; // rdy is ON for ready-enable microprotocol
        end
        `ENABLE_INIT: begin 
            en_init = 1'b1;
        end
        `IN_INIT: begin 
            s_addr = s_addr_init;
            s_wrdata = s_wrdata_init;
            s_wren = s_wren_init; 
        end
        `ENABLE_KSA: begin 
            en_ksa = 1'b1; 
        end
        `IN_KSA: begin 
            s_addr = s_addr_ksa; 
            s_wrdata = s_wrdata_ksa;
            s_wren = s_wren_ksa;
        end
        `ENABLE_PRGA: begin 
            en_prga = 1'b1;
        end
        `IN_PRGA: begin 
            s_addr = s_addr_prga;
            s_wrdata = s_wrdata_prga; 
            s_wren = s_wren_prga;
        end
        default: ;
        endcase
    end

    // State Transition Logic

    always_comb begin 
        case(present_state)
        `READY: begin 
            if(en == 1'b1) next_state = `ENABLE_INIT;
            else next_state = `READY;
        end
        `ENABLE_INIT: next_state = `IN_INIT;
        `IN_INIT: begin 
            if(rdy_init == 1'b0) next_state = `IN_INIT;
            else next_state = `ENABLE_KSA;
        end
        `ENABLE_KSA: next_state = `IN_KSA;
        `IN_KSA: begin 
            if(rdy_ksa == 1'b0) next_state = `IN_KSA;
            else next_state = `ENABLE_PRGA;
        end
        `ENABLE_PRGA: next_state = `IN_PRGA;
        `IN_PRGA: begin
            if(rdy_prga == 1'b0) next_state = `IN_PRGA;
            else next_state = `READY;
        end
        default: next_state = `READY;
        endcase
    end

    // State Register Logic

    always_ff@(posedge clk) begin 
        if(rst_n == 1'b0) present_state <= `READY;
        else present_state <= next_state;
    end
    
endmodule: arc4
