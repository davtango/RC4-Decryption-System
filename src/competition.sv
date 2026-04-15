
// State Instantiations

`define READY 3'b000 
`define EN_MC 3'b001 
`define IN_MC 3'b010 
`define MBOX1 3'b011 
`define WAIT1 3'b100
`define WAIT2 3'b101 
`define WAIT3 3'b110

module competition(input logic CLOCK_50, input logic [3:0] KEY, input logic [9:0] SW,
             output logic [6:0] HEX0, output logic [6:0] HEX1, output logic [6:0] HEX2,
             output logic [6:0] HEX3, output logic [6:0] HEX4, output logic [6:0] HEX5,
             output logic [9:0] LEDR);

    // Logic Instantiations

    logic [7:0] ct_addr, ct_rddata, ct_wrdata;
    logic ct_wren;

    // Logic Instantiations for MBOX & protocol compliance

    logic [7:0] mbox_addr, mbox_rddata, mbox_wrdata; 
    logic mbox_wren;

    // MBOX Iterators

    logic [7:0] current_m, next_m;
    logic [7:0] current_w3, next_w3; // incrementer to repeatedly write 00 for MBOX[1] into `WAIT3

    // Other Logic Instantiations

    logic clk, rst_n, en_doublecrack, rdy_doublecrack; 
    logic [23:0] key;
    logic key_valid;

    logic [2:0] present_state, next_state;

    // Module Instantiations

    ct_mem ct( .address(ct_addr), .clock(clk), .data(ct_wrdata), .wren(ct_wren), .q(ct_rddata));

    mbox_mem mbox(.address(mbox_addr), .clock(clk), .data(mbox_wrdata), .wren(mbox_wren), .q(mbox_rddata)); 

    multicrack mc( .clk(clk), .rst_n(rst_n), .en(en_doublecrack), .rdy(rdy_doublecrack), .key(key), .key_valid(key_valid), .ct_addr(ct_addr), .ct_rddata(ct_rddata));

    // Logic Assignments

    assign clk = CLOCK_50; 
    assign rst_n = KEY[3];
    assign LEDR = {key_valid,key_valid,key_valid,key_valid,key_valid,key_valid,key_valid,key_valid,key_valid,key_valid};

    /*
    assign HEX0 = 7'b1;
    assign HEX1 = 7'b1;
    assign HEX2 = 7'b1;
    assign HEX3 = 7'b1;
    assign HEX4 = 7'b1;
    assign HEX5 = 7'b1;
    */

    // State Output Logic (refer to final always_comb block for HEX outputs)

    always_comb begin 
        mbox_addr = 8'd0; 
        mbox_wrdata = 8'd0; 
        mbox_wren = 1'b0; 

        en_doublecrack = 1'b0; 

        next_m = current_m;
        next_w3 = current_w3;

        case(present_state) 

        `READY: begin 
            next_m = 8'd4; // start at 4 
            next_w3 = 8'd0; // reset back to 0
        end
        `EN_MC: en_doublecrack = 1'b1; 
        `IN_MC: ;
        `MBOX1: begin 
            mbox_addr = current_m;
            mbox_wren = 1'b1;
            case(current_m) 
            8'd4: mbox_wrdata = key[7:0]; 
            8'd3: mbox_wrdata = key[15:8];
            8'd2: mbox_wrdata = key[23:16];
            8'd1: mbox_wrdata = 8'hFF;
            default: mbox_wrdata = 8'h0;
            endcase

            next_m = current_m - 8'd1;
        end
        `WAIT1: ;
        `WAIT2: ;
        `WAIT3: begin 
            mbox_addr = 8'd1; // change done signal MBOX[1] back to 8'h0
            mbox_wrdata = 8'h00; 
            mbox_wren = 1'b1; 
            next_w3 = current_w3 + 8'd1;
        end
        default: ;
        endcase
    end

    // State Transition Logic

    always_comb begin 
        case(present_state) 
            `READY: begin 
                if(mbox_rddata == 8'hFF) next_state = `EN_MC;
                else next_state = `READY;
            end
            `EN_MC: next_state = `IN_MC;
            `IN_MC: begin 
                if(rdy_doublecrack == 1'b0) next_state = `IN_MC; 
                else next_state = `MBOX1;
            end
            `MBOX1: begin 
                if(current_m == 8'd1) next_state = `WAIT1;
                else next_state = `MBOX1;
            end 
            `WAIT1: next_state = `WAIT2;
            `WAIT2: begin 
                if(mbox_rddata == 8'hFF) next_state = `WAIT2; 
                else next_state = `WAIT3;
            end
            `WAIT3: begin 
                if(current_w3 == 8'd100) next_state = `READY; // 30 does not work, 50 works. Set to 100 just to be safe :)
                else next_state = `WAIT3;
            end 
            default: next_state = `READY;
        endcase
    end

    always_ff@(posedge clk) begin 
        if(rst_n == 1'b0) begin 
            present_state <= `READY;
            current_m <= 8'd4; 
            current_w3 <= 8'd0;
        end
        else begin 
            present_state <= next_state; 
            current_m <= next_m;
            current_w3 <= next_w3;
        end
    end

    always_comb begin 

        HEX0 = 7'b111_1111;
        HEX1 = 7'b111_1111;
        HEX2 = 7'b111_1111;
        HEX3 = 7'b111_1111;
        HEX4 = 7'b111_1111;
        HEX5 = 7'b111_1111; 

        case(present_state) 
        `READY: ;
        `EN_MC: ;
        `IN_MC: ;
        `MBOX1: begin 
            if(key_valid == 1'b1) begin
                case(key[23:20])
                    4'h0: HEX5 = 7'b100_0000; // 0 
                    4'h1: HEX5 = 7'b111_1001; // 1
                    4'h2: HEX5 = 7'b010_0100; // 2
                    4'h3: HEX5 = 7'b011_0000; // 3
                    4'h4: HEX5 = 7'b001_1001; // 4
                    4'h5: HEX5 = 7'b001_0010; // 5
                    4'h6: HEX5 = 7'b000_0010; // 6
                    4'h7: HEX5 = 7'b111_1000; // 7
                    4'h8: HEX5 = 7'b000_0000; // 8
                    4'h9: HEX5 = 7'b001_0000; // 9
                    4'hA: HEX5 = 7'b000_1000; // A
                    4'hb: HEX5 = 7'b000_0011; // b
                    4'hC: HEX5 = 7'b100_0110; // C
                    4'hd: HEX5 = 7'b010_0001; // d
                    4'hE: HEX5 = 7'b000_0110; // E
                    4'hF: HEX5 = 7'b000_1110; // F
                    default: HEX5 = 7'b111_1111; // turn off
                endcase
                case(key[19:16])
                    4'h0: HEX4 = 7'b100_0000; // 0 
                    4'h1: HEX4 = 7'b111_1001; // 1
                    4'h2: HEX4 = 7'b010_0100; // 2
                    4'h3: HEX4 = 7'b011_0000; // 3
                    4'h4: HEX4 = 7'b001_1001; // 4
                    4'h5: HEX4 = 7'b001_0010; // 5
                    4'h6: HEX4 = 7'b000_0010; // 6
                    4'h7: HEX4 = 7'b111_1000; // 7
                    4'h8: HEX4 = 7'b000_0000; // 8
                    4'h9: HEX4 = 7'b001_0000; // 9
                    4'hA: HEX4 = 7'b000_1000; // A
                    4'hb: HEX4 = 7'b000_0011; // b
                    4'hC: HEX4 = 7'b100_0110; // C
                    4'hd: HEX4 = 7'b010_0001; // d
                    4'hE: HEX4 = 7'b000_0110; // E
                    4'hF: HEX4 = 7'b000_1110; // F
                    default: HEX4 = 7'b111_1111; // turn off
                endcase
                case(key[15:12])
                    4'h0: HEX3 = 7'b100_0000; // 0 
                    4'h1: HEX3 = 7'b111_1001; // 1
                    4'h2: HEX3 = 7'b010_0100; // 2
                    4'h3: HEX3 = 7'b011_0000; // 3
                    4'h4: HEX3 = 7'b001_1001; // 4
                    4'h5: HEX3 = 7'b001_0010; // 5
                    4'h6: HEX3 = 7'b000_0010; // 6
                    4'h7: HEX3 = 7'b111_1000; // 7
                    4'h8: HEX3 = 7'b000_0000; // 8
                    4'h9: HEX3 = 7'b001_0000; // 9
                    4'hA: HEX3 = 7'b000_1000; // A
                    4'hb: HEX3 = 7'b000_0011; // b
                    4'hC: HEX3 = 7'b100_0110; // C
                    4'hd: HEX3 = 7'b010_0001; // d
                    4'hE: HEX3 = 7'b000_0110; // E
                    4'hF: HEX3 = 7'b000_1110; // F
                    default: HEX3 = 7'b111_1111; // turn off
                endcase
                case(key[11:8])
                    4'h0: HEX2 = 7'b100_0000; // 0 
                    4'h1: HEX2 = 7'b111_1001; // 1
                    4'h2: HEX2 = 7'b010_0100; // 2
                    4'h3: HEX2 = 7'b011_0000; // 3
                    4'h4: HEX2 = 7'b001_1001; // 4
                    4'h5: HEX2 = 7'b001_0010; // 5
                    4'h6: HEX2 = 7'b000_0010; // 6
                    4'h7: HEX2 = 7'b111_1000; // 7
                    4'h8: HEX2 = 7'b000_0000; // 8
                    4'h9: HEX2 = 7'b001_0000; // 9
                    4'hA: HEX2 = 7'b000_1000; // A
                    4'hb: HEX2 = 7'b000_0011; // b
                    4'hC: HEX2 = 7'b100_0110; // C
                    4'hd: HEX2 = 7'b010_0001; // d
                    4'hE: HEX2 = 7'b000_0110; // E
                    4'hF: HEX2 = 7'b000_1110; // F
                    default: HEX2 = 7'b111_1111; // turn off
                endcase
                case(key[7:4])
                    4'h0: HEX1 = 7'b100_0000; // 0 
                    4'h1: HEX1 = 7'b111_1001; // 1
                    4'h2: HEX1 = 7'b010_0100; // 2
                    4'h3: HEX1 = 7'b011_0000; // 3
                    4'h4: HEX1 = 7'b001_1001; // 4
                    4'h5: HEX1 = 7'b001_0010; // 5
                    4'h6: HEX1 = 7'b000_0010; // 6
                    4'h7: HEX1 = 7'b111_1000; // 7
                    4'h8: HEX1 = 7'b000_0000; // 8
                    4'h9: HEX1 = 7'b001_0000; // 9
                    4'hA: HEX1 = 7'b000_1000; // A
                    4'hb: HEX1 = 7'b000_0011; // b
                    4'hC: HEX1 = 7'b100_0110; // C
                    4'hd: HEX1 = 7'b010_0001; // d
                    4'hE: HEX1 = 7'b000_0110; // E
                    4'hF: HEX1 = 7'b000_1110; // F
                    default: HEX1 = 7'b111_1111; // turn off
                endcase
                case(key[3:0])
                    4'h0: HEX0 = 7'b100_0000; // 0 
                    4'h1: HEX0 = 7'b111_1001; // 1
                    4'h2: HEX0 = 7'b010_0100; // 2
                    4'h3: HEX0 = 7'b011_0000; // 3
                    4'h4: HEX0 = 7'b001_1001; // 4
                    4'h5: HEX0 = 7'b001_0010; // 5
                    4'h6: HEX0 = 7'b000_0010; // 6
                    4'h7: HEX0 = 7'b111_1000; // 7
                    4'h8: HEX0 = 7'b000_0000; // 8
                    4'h9: HEX0 = 7'b001_0000; // 9
                    4'hA: HEX0 = 7'b000_1000; // A
                    4'hb: HEX0 = 7'b000_0011; // b
                    4'hC: HEX0 = 7'b100_0110; // C
                    4'hd: HEX0 = 7'b010_0001; // d
                    4'hE: HEX0 = 7'b000_0110; // E
                    4'hF: HEX0 = 7'b000_1110; // F
                    default: HEX0 = 7'b111_1111; // turn off
                endcase
            end
            else begin // if key_valid == 1'b0, or no possible 24-bit key resulted in a cracked message 
                HEX5 = 7'b011_1111;
                HEX4 = 7'b011_1111;
                HEX3 = 7'b011_1111;
                HEX2 = 7'b011_1111;
                HEX1 = 7'b011_1111;
                HEX0 = 7'b011_1111;
            end
        end
        `WAIT1: begin 
            if(key_valid == 1'b1) begin
            // HEX outputs when we are in the DONE state
                case(key[23:20])
                    4'h0: HEX5 = 7'b100_0000; // 0 
                    4'h1: HEX5 = 7'b111_1001; // 1
                    4'h2: HEX5 = 7'b010_0100; // 2
                    4'h3: HEX5 = 7'b011_0000; // 3
                    4'h4: HEX5 = 7'b001_1001; // 4
                    4'h5: HEX5 = 7'b001_0010; // 5
                    4'h6: HEX5 = 7'b000_0010; // 6
                    4'h7: HEX5 = 7'b111_1000; // 7
                    4'h8: HEX5 = 7'b000_0000; // 8
                    4'h9: HEX5 = 7'b001_0000; // 9
                    4'hA: HEX5 = 7'b000_1000; // A
                    4'hb: HEX5 = 7'b000_0011; // b
                    4'hC: HEX5 = 7'b100_0110; // C
                    4'hd: HEX5 = 7'b010_0001; // d
                    4'hE: HEX5 = 7'b000_0110; // E
                    4'hF: HEX5 = 7'b000_1110; // F
                    default: HEX5 = 7'b111_1111; // turn off
                endcase
                case(key[19:16])
                    4'h0: HEX4 = 7'b100_0000; // 0 
                    4'h1: HEX4 = 7'b111_1001; // 1
                    4'h2: HEX4 = 7'b010_0100; // 2
                    4'h3: HEX4 = 7'b011_0000; // 3
                    4'h4: HEX4 = 7'b001_1001; // 4
                    4'h5: HEX4 = 7'b001_0010; // 5
                    4'h6: HEX4 = 7'b000_0010; // 6
                    4'h7: HEX4 = 7'b111_1000; // 7
                    4'h8: HEX4 = 7'b000_0000; // 8
                    4'h9: HEX4 = 7'b001_0000; // 9
                    4'hA: HEX4 = 7'b000_1000; // A
                    4'hb: HEX4 = 7'b000_0011; // b
                    4'hC: HEX4 = 7'b100_0110; // C
                    4'hd: HEX4 = 7'b010_0001; // d
                    4'hE: HEX4 = 7'b000_0110; // E
                    4'hF: HEX4 = 7'b000_1110; // F
                    default: HEX4 = 7'b111_1111; // turn off
                endcase
                case(key[15:12])
                    4'h0: HEX3 = 7'b100_0000; // 0 
                    4'h1: HEX3 = 7'b111_1001; // 1
                    4'h2: HEX3 = 7'b010_0100; // 2
                    4'h3: HEX3 = 7'b011_0000; // 3
                    4'h4: HEX3 = 7'b001_1001; // 4
                    4'h5: HEX3 = 7'b001_0010; // 5
                    4'h6: HEX3 = 7'b000_0010; // 6
                    4'h7: HEX3 = 7'b111_1000; // 7
                    4'h8: HEX3 = 7'b000_0000; // 8
                    4'h9: HEX3 = 7'b001_0000; // 9
                    4'hA: HEX3 = 7'b000_1000; // A
                    4'hb: HEX3 = 7'b000_0011; // b
                    4'hC: HEX3 = 7'b100_0110; // C
                    4'hd: HEX3 = 7'b010_0001; // d
                    4'hE: HEX3 = 7'b000_0110; // E
                    4'hF: HEX3 = 7'b000_1110; // F
                    default: HEX3 = 7'b111_1111; // turn off
                endcase
                case(key[11:8])
                    4'h0: HEX2 = 7'b100_0000; // 0 
                    4'h1: HEX2 = 7'b111_1001; // 1
                    4'h2: HEX2 = 7'b010_0100; // 2
                    4'h3: HEX2 = 7'b011_0000; // 3
                    4'h4: HEX2 = 7'b001_1001; // 4
                    4'h5: HEX2 = 7'b001_0010; // 5
                    4'h6: HEX2 = 7'b000_0010; // 6
                    4'h7: HEX2 = 7'b111_1000; // 7
                    4'h8: HEX2 = 7'b000_0000; // 8
                    4'h9: HEX2 = 7'b001_0000; // 9
                    4'hA: HEX2 = 7'b000_1000; // A
                    4'hb: HEX2 = 7'b000_0011; // b
                    4'hC: HEX2 = 7'b100_0110; // C
                    4'hd: HEX2 = 7'b010_0001; // d
                    4'hE: HEX2 = 7'b000_0110; // E
                    4'hF: HEX2 = 7'b000_1110; // F
                    default: HEX2 = 7'b111_1111; // turn off
                endcase
                case(key[7:4])
                    4'h0: HEX1 = 7'b100_0000; // 0 
                    4'h1: HEX1 = 7'b111_1001; // 1
                    4'h2: HEX1 = 7'b010_0100; // 2
                    4'h3: HEX1 = 7'b011_0000; // 3
                    4'h4: HEX1 = 7'b001_1001; // 4
                    4'h5: HEX1 = 7'b001_0010; // 5
                    4'h6: HEX1 = 7'b000_0010; // 6
                    4'h7: HEX1 = 7'b111_1000; // 7
                    4'h8: HEX1 = 7'b000_0000; // 8
                    4'h9: HEX1 = 7'b001_0000; // 9
                    4'hA: HEX1 = 7'b000_1000; // A
                    4'hb: HEX1 = 7'b000_0011; // b
                    4'hC: HEX1 = 7'b100_0110; // C
                    4'hd: HEX1 = 7'b010_0001; // d
                    4'hE: HEX1 = 7'b000_0110; // E
                    4'hF: HEX1 = 7'b000_1110; // F
                    default: HEX1 = 7'b111_1111; // turn off
                endcase
                case(key[3:0])
                    4'h0: HEX0 = 7'b100_0000; // 0 
                    4'h1: HEX0 = 7'b111_1001; // 1
                    4'h2: HEX0 = 7'b010_0100; // 2
                    4'h3: HEX0 = 7'b011_0000; // 3
                    4'h4: HEX0 = 7'b001_1001; // 4
                    4'h5: HEX0 = 7'b001_0010; // 5
                    4'h6: HEX0 = 7'b000_0010; // 6
                    4'h7: HEX0 = 7'b111_1000; // 7
                    4'h8: HEX0 = 7'b000_0000; // 8
                    4'h9: HEX0 = 7'b001_0000; // 9
                    4'hA: HEX0 = 7'b000_1000; // A
                    4'hb: HEX0 = 7'b000_0011; // b
                    4'hC: HEX0 = 7'b100_0110; // C
                    4'hd: HEX0 = 7'b010_0001; // d
                    4'hE: HEX0 = 7'b000_0110; // E
                    4'hF: HEX0 = 7'b000_1110; // F
                    default: HEX0 = 7'b111_1111; // turn off
                endcase
            end
            else begin // if key_valid == 1'b0, or no possible 24-bit key resulted in a cracked message 
                HEX5 = 7'b011_1111;
                HEX4 = 7'b011_1111;
                HEX3 = 7'b011_1111;
                HEX2 = 7'b011_1111;
                HEX1 = 7'b011_1111;
                HEX0 = 7'b011_1111;
            end
        end
        `WAIT2: begin 
            if(key_valid == 1'b1) begin
            // HEX outputs when we are in the DONE state
                case(key[23:20])
                    4'h0: HEX5 = 7'b100_0000; // 0 
                    4'h1: HEX5 = 7'b111_1001; // 1
                    4'h2: HEX5 = 7'b010_0100; // 2
                    4'h3: HEX5 = 7'b011_0000; // 3
                    4'h4: HEX5 = 7'b001_1001; // 4
                    4'h5: HEX5 = 7'b001_0010; // 5
                    4'h6: HEX5 = 7'b000_0010; // 6
                    4'h7: HEX5 = 7'b111_1000; // 7
                    4'h8: HEX5 = 7'b000_0000; // 8
                    4'h9: HEX5 = 7'b001_0000; // 9
                    4'hA: HEX5 = 7'b000_1000; // A
                    4'hb: HEX5 = 7'b000_0011; // b
                    4'hC: HEX5 = 7'b100_0110; // C
                    4'hd: HEX5 = 7'b010_0001; // d
                    4'hE: HEX5 = 7'b000_0110; // E
                    4'hF: HEX5 = 7'b000_1110; // F
                    default: HEX5 = 7'b111_1111; // turn off
                endcase
                case(key[19:16])
                    4'h0: HEX4 = 7'b100_0000; // 0 
                    4'h1: HEX4 = 7'b111_1001; // 1
                    4'h2: HEX4 = 7'b010_0100; // 2
                    4'h3: HEX4 = 7'b011_0000; // 3
                    4'h4: HEX4 = 7'b001_1001; // 4
                    4'h5: HEX4 = 7'b001_0010; // 5
                    4'h6: HEX4 = 7'b000_0010; // 6
                    4'h7: HEX4 = 7'b111_1000; // 7
                    4'h8: HEX4 = 7'b000_0000; // 8
                    4'h9: HEX4 = 7'b001_0000; // 9
                    4'hA: HEX4 = 7'b000_1000; // A
                    4'hb: HEX4 = 7'b000_0011; // b
                    4'hC: HEX4 = 7'b100_0110; // C
                    4'hd: HEX4 = 7'b010_0001; // d
                    4'hE: HEX4 = 7'b000_0110; // E
                    4'hF: HEX4 = 7'b000_1110; // F
                    default: HEX4 = 7'b111_1111; // turn off
                endcase
                case(key[15:12])
                    4'h0: HEX3 = 7'b100_0000; // 0 
                    4'h1: HEX3 = 7'b111_1001; // 1
                    4'h2: HEX3 = 7'b010_0100; // 2
                    4'h3: HEX3 = 7'b011_0000; // 3
                    4'h4: HEX3 = 7'b001_1001; // 4
                    4'h5: HEX3 = 7'b001_0010; // 5
                    4'h6: HEX3 = 7'b000_0010; // 6
                    4'h7: HEX3 = 7'b111_1000; // 7
                    4'h8: HEX3 = 7'b000_0000; // 8
                    4'h9: HEX3 = 7'b001_0000; // 9
                    4'hA: HEX3 = 7'b000_1000; // A
                    4'hb: HEX3 = 7'b000_0011; // b
                    4'hC: HEX3 = 7'b100_0110; // C
                    4'hd: HEX3 = 7'b010_0001; // d
                    4'hE: HEX3 = 7'b000_0110; // E
                    4'hF: HEX3 = 7'b000_1110; // F
                    default: HEX3 = 7'b111_1111; // turn off
                endcase
                case(key[11:8])
                    4'h0: HEX2 = 7'b100_0000; // 0 
                    4'h1: HEX2 = 7'b111_1001; // 1
                    4'h2: HEX2 = 7'b010_0100; // 2
                    4'h3: HEX2 = 7'b011_0000; // 3
                    4'h4: HEX2 = 7'b001_1001; // 4
                    4'h5: HEX2 = 7'b001_0010; // 5
                    4'h6: HEX2 = 7'b000_0010; // 6
                    4'h7: HEX2 = 7'b111_1000; // 7
                    4'h8: HEX2 = 7'b000_0000; // 8
                    4'h9: HEX2 = 7'b001_0000; // 9
                    4'hA: HEX2 = 7'b000_1000; // A
                    4'hb: HEX2 = 7'b000_0011; // b
                    4'hC: HEX2 = 7'b100_0110; // C
                    4'hd: HEX2 = 7'b010_0001; // d
                    4'hE: HEX2 = 7'b000_0110; // E
                    4'hF: HEX2 = 7'b000_1110; // F
                    default: HEX2 = 7'b111_1111; // turn off
                endcase
                case(key[7:4])
                    4'h0: HEX1 = 7'b100_0000; // 0 
                    4'h1: HEX1 = 7'b111_1001; // 1
                    4'h2: HEX1 = 7'b010_0100; // 2
                    4'h3: HEX1 = 7'b011_0000; // 3
                    4'h4: HEX1 = 7'b001_1001; // 4
                    4'h5: HEX1 = 7'b001_0010; // 5
                    4'h6: HEX1 = 7'b000_0010; // 6
                    4'h7: HEX1 = 7'b111_1000; // 7
                    4'h8: HEX1 = 7'b000_0000; // 8
                    4'h9: HEX1 = 7'b001_0000; // 9
                    4'hA: HEX1 = 7'b000_1000; // A
                    4'hb: HEX1 = 7'b000_0011; // b
                    4'hC: HEX1 = 7'b100_0110; // C
                    4'hd: HEX1 = 7'b010_0001; // d
                    4'hE: HEX1 = 7'b000_0110; // E
                    4'hF: HEX1 = 7'b000_1110; // F
                    default: HEX1 = 7'b111_1111; // turn off
                endcase
                case(key[3:0])
                    4'h0: HEX0 = 7'b100_0000; // 0 
                    4'h1: HEX0 = 7'b111_1001; // 1
                    4'h2: HEX0 = 7'b010_0100; // 2
                    4'h3: HEX0 = 7'b011_0000; // 3
                    4'h4: HEX0 = 7'b001_1001; // 4
                    4'h5: HEX0 = 7'b001_0010; // 5
                    4'h6: HEX0 = 7'b000_0010; // 6
                    4'h7: HEX0 = 7'b111_1000; // 7
                    4'h8: HEX0 = 7'b000_0000; // 8
                    4'h9: HEX0 = 7'b001_0000; // 9
                    4'hA: HEX0 = 7'b000_1000; // A
                    4'hb: HEX0 = 7'b000_0011; // b
                    4'hC: HEX0 = 7'b100_0110; // C
                    4'hd: HEX0 = 7'b010_0001; // d
                    4'hE: HEX0 = 7'b000_0110; // E
                    4'hF: HEX0 = 7'b000_1110; // F
                    default: HEX0 = 7'b111_1111; // turn off
                endcase
            end
            else begin // if key_valid == 1'b0, or no possible 24-bit key resulted in a cracked message 
                HEX5 = 7'b011_1111;
                HEX4 = 7'b011_1111;
                HEX3 = 7'b011_1111;
                HEX2 = 7'b011_1111;
                HEX1 = 7'b011_1111;
                HEX0 = 7'b011_1111;
            end
        end
        `WAIT3: begin 
            if(key_valid == 1'b1) begin
            // HEX outputs when we are in the DONE state
                case(key[23:20])
                    4'h0: HEX5 = 7'b100_0000; // 0 
                    4'h1: HEX5 = 7'b111_1001; // 1
                    4'h2: HEX5 = 7'b010_0100; // 2
                    4'h3: HEX5 = 7'b011_0000; // 3
                    4'h4: HEX5 = 7'b001_1001; // 4
                    4'h5: HEX5 = 7'b001_0010; // 5
                    4'h6: HEX5 = 7'b000_0010; // 6
                    4'h7: HEX5 = 7'b111_1000; // 7
                    4'h8: HEX5 = 7'b000_0000; // 8
                    4'h9: HEX5 = 7'b001_0000; // 9
                    4'hA: HEX5 = 7'b000_1000; // A
                    4'hb: HEX5 = 7'b000_0011; // b
                    4'hC: HEX5 = 7'b100_0110; // C
                    4'hd: HEX5 = 7'b010_0001; // d
                    4'hE: HEX5 = 7'b000_0110; // E
                    4'hF: HEX5 = 7'b000_1110; // F
                    default: HEX5 = 7'b111_1111; // turn off
                endcase
                case(key[19:16])
                    4'h0: HEX4 = 7'b100_0000; // 0 
                    4'h1: HEX4 = 7'b111_1001; // 1
                    4'h2: HEX4 = 7'b010_0100; // 2
                    4'h3: HEX4 = 7'b011_0000; // 3
                    4'h4: HEX4 = 7'b001_1001; // 4
                    4'h5: HEX4 = 7'b001_0010; // 5
                    4'h6: HEX4 = 7'b000_0010; // 6
                    4'h7: HEX4 = 7'b111_1000; // 7
                    4'h8: HEX4 = 7'b000_0000; // 8
                    4'h9: HEX4 = 7'b001_0000; // 9
                    4'hA: HEX4 = 7'b000_1000; // A
                    4'hb: HEX4 = 7'b000_0011; // b
                    4'hC: HEX4 = 7'b100_0110; // C
                    4'hd: HEX4 = 7'b010_0001; // d
                    4'hE: HEX4 = 7'b000_0110; // E
                    4'hF: HEX4 = 7'b000_1110; // F
                    default: HEX4 = 7'b111_1111; // turn off
                endcase
                case(key[15:12])
                    4'h0: HEX3 = 7'b100_0000; // 0 
                    4'h1: HEX3 = 7'b111_1001; // 1
                    4'h2: HEX3 = 7'b010_0100; // 2
                    4'h3: HEX3 = 7'b011_0000; // 3
                    4'h4: HEX3 = 7'b001_1001; // 4
                    4'h5: HEX3 = 7'b001_0010; // 5
                    4'h6: HEX3 = 7'b000_0010; // 6
                    4'h7: HEX3 = 7'b111_1000; // 7
                    4'h8: HEX3 = 7'b000_0000; // 8
                    4'h9: HEX3 = 7'b001_0000; // 9
                    4'hA: HEX3 = 7'b000_1000; // A
                    4'hb: HEX3 = 7'b000_0011; // b
                    4'hC: HEX3 = 7'b100_0110; // C
                    4'hd: HEX3 = 7'b010_0001; // d
                    4'hE: HEX3 = 7'b000_0110; // E
                    4'hF: HEX3 = 7'b000_1110; // F
                    default: HEX3 = 7'b111_1111; // turn off
                endcase
                case(key[11:8])
                    4'h0: HEX2 = 7'b100_0000; // 0 
                    4'h1: HEX2 = 7'b111_1001; // 1
                    4'h2: HEX2 = 7'b010_0100; // 2
                    4'h3: HEX2 = 7'b011_0000; // 3
                    4'h4: HEX2 = 7'b001_1001; // 4
                    4'h5: HEX2 = 7'b001_0010; // 5
                    4'h6: HEX2 = 7'b000_0010; // 6
                    4'h7: HEX2 = 7'b111_1000; // 7
                    4'h8: HEX2 = 7'b000_0000; // 8
                    4'h9: HEX2 = 7'b001_0000; // 9
                    4'hA: HEX2 = 7'b000_1000; // A
                    4'hb: HEX2 = 7'b000_0011; // b
                    4'hC: HEX2 = 7'b100_0110; // C
                    4'hd: HEX2 = 7'b010_0001; // d
                    4'hE: HEX2 = 7'b000_0110; // E
                    4'hF: HEX2 = 7'b000_1110; // F
                    default: HEX2 = 7'b111_1111; // turn off
                endcase
                case(key[7:4])
                    4'h0: HEX1 = 7'b100_0000; // 0 
                    4'h1: HEX1 = 7'b111_1001; // 1
                    4'h2: HEX1 = 7'b010_0100; // 2
                    4'h3: HEX1 = 7'b011_0000; // 3
                    4'h4: HEX1 = 7'b001_1001; // 4
                    4'h5: HEX1 = 7'b001_0010; // 5
                    4'h6: HEX1 = 7'b000_0010; // 6
                    4'h7: HEX1 = 7'b111_1000; // 7
                    4'h8: HEX1 = 7'b000_0000; // 8
                    4'h9: HEX1 = 7'b001_0000; // 9
                    4'hA: HEX1 = 7'b000_1000; // A
                    4'hb: HEX1 = 7'b000_0011; // b
                    4'hC: HEX1 = 7'b100_0110; // C
                    4'hd: HEX1 = 7'b010_0001; // d
                    4'hE: HEX1 = 7'b000_0110; // E
                    4'hF: HEX1 = 7'b000_1110; // F
                    default: HEX1 = 7'b111_1111; // turn off
                endcase
                case(key[3:0])
                    4'h0: HEX0 = 7'b100_0000; // 0 
                    4'h1: HEX0 = 7'b111_1001; // 1
                    4'h2: HEX0 = 7'b010_0100; // 2
                    4'h3: HEX0 = 7'b011_0000; // 3
                    4'h4: HEX0 = 7'b001_1001; // 4
                    4'h5: HEX0 = 7'b001_0010; // 5
                    4'h6: HEX0 = 7'b000_0010; // 6
                    4'h7: HEX0 = 7'b111_1000; // 7
                    4'h8: HEX0 = 7'b000_0000; // 8
                    4'h9: HEX0 = 7'b001_0000; // 9
                    4'hA: HEX0 = 7'b000_1000; // A
                    4'hb: HEX0 = 7'b000_0011; // b
                    4'hC: HEX0 = 7'b100_0110; // C
                    4'hd: HEX0 = 7'b010_0001; // d
                    4'hE: HEX0 = 7'b000_0110; // E
                    4'hF: HEX0 = 7'b000_1110; // F
                    default: HEX0 = 7'b111_1111; // turn off
                endcase
            end
            else begin // if key_valid == 1'b0, or no possible 24-bit key resulted in a cracked message 
                HEX5 = 7'b011_1111;
                HEX4 = 7'b011_1111;
                HEX3 = 7'b011_1111;
                HEX2 = 7'b011_1111;
                HEX1 = 7'b011_1111;
                HEX0 = 7'b011_1111;
            end
        end
        endcase
    end

// TASK 5.SV TOP MODULE
// SHELVED for competition

/*
    always_comb begin 
        en_doublecrack = 1'b0;

        HEX0 = 7'b111_1111;
        HEX1 = 7'b111_1111;
        HEX2 = 7'b111_1111;
        HEX3 = 7'b111_1111;
        HEX4 = 7'b111_1111;
        HEX5 = 7'b111_1111; 

        case(present_state)
        `READY: ;
        `ENABLE_DOUBLECRACK: en_doublecrack = 1'b1; 
        `IN_DOUBLECRACK: ;
        `DONE: begin 
            if(key_valid == 1'b1) begin
            // HEX outputs when we are in the DONE state
                case(key[23:20])
                    4'h0: HEX5 = 7'b100_0000; // 0 
                    4'h1: HEX5 = 7'b111_1001; // 1
                    4'h2: HEX5 = 7'b010_0100; // 2
                    4'h3: HEX5 = 7'b011_0000; // 3
                    4'h4: HEX5 = 7'b001_1001; // 4
                    4'h5: HEX5 = 7'b001_0010; // 5
                    4'h6: HEX5 = 7'b000_0010; // 6
                    4'h7: HEX5 = 7'b111_1000; // 7
                    4'h8: HEX5 = 7'b000_0000; // 8
                    4'h9: HEX5 = 7'b001_0000; // 9
                    4'hA: HEX5 = 7'b000_1000; // A
                    4'hb: HEX5 = 7'b000_0011; // b
                    4'hC: HEX5 = 7'b100_0110; // C
                    4'hd: HEX5 = 7'b010_0001; // d
                    4'hE: HEX5 = 7'b000_0110; // E
                    4'hF: HEX5 = 7'b000_1110; // F
                    default: HEX5 = 7'b111_1111; // turn off
                endcase

                case(key[19:16])
                    4'h0: HEX4 = 7'b100_0000; // 0 
                    4'h1: HEX4 = 7'b111_1001; // 1
                    4'h2: HEX4 = 7'b010_0100; // 2
                    4'h3: HEX4 = 7'b011_0000; // 3
                    4'h4: HEX4 = 7'b001_1001; // 4
                    4'h5: HEX4 = 7'b001_0010; // 5
                    4'h6: HEX4 = 7'b000_0010; // 6
                    4'h7: HEX4 = 7'b111_1000; // 7
                    4'h8: HEX4 = 7'b000_0000; // 8
                    4'h9: HEX4 = 7'b001_0000; // 9
                    4'hA: HEX4 = 7'b000_1000; // A
                    4'hb: HEX4 = 7'b000_0011; // b
                    4'hC: HEX4 = 7'b100_0110; // C
                    4'hd: HEX4 = 7'b010_0001; // d
                    4'hE: HEX4 = 7'b000_0110; // E
                    4'hF: HEX4 = 7'b000_1110; // F
                    default: HEX4 = 7'b111_1111; // turn off
                endcase

                case(key[15:12])
                    4'h0: HEX3 = 7'b100_0000; // 0 
                    4'h1: HEX3 = 7'b111_1001; // 1
                    4'h2: HEX3 = 7'b010_0100; // 2
                    4'h3: HEX3 = 7'b011_0000; // 3
                    4'h4: HEX3 = 7'b001_1001; // 4
                    4'h5: HEX3 = 7'b001_0010; // 5
                    4'h6: HEX3 = 7'b000_0010; // 6
                    4'h7: HEX3 = 7'b111_1000; // 7
                    4'h8: HEX3 = 7'b000_0000; // 8
                    4'h9: HEX3 = 7'b001_0000; // 9
                    4'hA: HEX3 = 7'b000_1000; // A
                    4'hb: HEX3 = 7'b000_0011; // b
                    4'hC: HEX3 = 7'b100_0110; // C
                    4'hd: HEX3 = 7'b010_0001; // d
                    4'hE: HEX3 = 7'b000_0110; // E
                    4'hF: HEX3 = 7'b000_1110; // F
                    default: HEX3 = 7'b111_1111; // turn off
                endcase

                case(key[11:8])
                    4'h0: HEX2 = 7'b100_0000; // 0 
                    4'h1: HEX2 = 7'b111_1001; // 1
                    4'h2: HEX2 = 7'b010_0100; // 2
                    4'h3: HEX2 = 7'b011_0000; // 3
                    4'h4: HEX2 = 7'b001_1001; // 4
                    4'h5: HEX2 = 7'b001_0010; // 5
                    4'h6: HEX2 = 7'b000_0010; // 6
                    4'h7: HEX2 = 7'b111_1000; // 7
                    4'h8: HEX2 = 7'b000_0000; // 8
                    4'h9: HEX2 = 7'b001_0000; // 9
                    4'hA: HEX2 = 7'b000_1000; // A
                    4'hb: HEX2 = 7'b000_0011; // b
                    4'hC: HEX2 = 7'b100_0110; // C
                    4'hd: HEX2 = 7'b010_0001; // d
                    4'hE: HEX2 = 7'b000_0110; // E
                    4'hF: HEX2 = 7'b000_1110; // F
                    default: HEX2 = 7'b111_1111; // turn off
                endcase

                case(key[7:4])
                    4'h0: HEX1 = 7'b100_0000; // 0 
                    4'h1: HEX1 = 7'b111_1001; // 1
                    4'h2: HEX1 = 7'b010_0100; // 2
                    4'h3: HEX1 = 7'b011_0000; // 3
                    4'h4: HEX1 = 7'b001_1001; // 4
                    4'h5: HEX1 = 7'b001_0010; // 5
                    4'h6: HEX1 = 7'b000_0010; // 6
                    4'h7: HEX1 = 7'b111_1000; // 7
                    4'h8: HEX1 = 7'b000_0000; // 8
                    4'h9: HEX1 = 7'b001_0000; // 9
                    4'hA: HEX1 = 7'b000_1000; // A
                    4'hb: HEX1 = 7'b000_0011; // b
                    4'hC: HEX1 = 7'b100_0110; // C
                    4'hd: HEX1 = 7'b010_0001; // d
                    4'hE: HEX1 = 7'b000_0110; // E
                    4'hF: HEX1 = 7'b000_1110; // F
                    default: HEX1 = 7'b111_1111; // turn off
                endcase

                case(key[3:0])
                    4'h0: HEX0 = 7'b100_0000; // 0 
                    4'h1: HEX0 = 7'b111_1001; // 1
                    4'h2: HEX0 = 7'b010_0100; // 2
                    4'h3: HEX0 = 7'b011_0000; // 3
                    4'h4: HEX0 = 7'b001_1001; // 4
                    4'h5: HEX0 = 7'b001_0010; // 5
                    4'h6: HEX0 = 7'b000_0010; // 6
                    4'h7: HEX0 = 7'b111_1000; // 7
                    4'h8: HEX0 = 7'b000_0000; // 8
                    4'h9: HEX0 = 7'b001_0000; // 9
                    4'hA: HEX0 = 7'b000_1000; // A
                    4'hb: HEX0 = 7'b000_0011; // b
                    4'hC: HEX0 = 7'b100_0110; // C
                    4'hd: HEX0 = 7'b010_0001; // d
                    4'hE: HEX0 = 7'b000_0110; // E
                    4'hF: HEX0 = 7'b000_1110; // F
                    default: HEX0 = 7'b111_1111; // turn off
                endcase
            end
            else begin // if key_valid == 1'b0, or no possible 24-bit key resulted in a cracked message 
                HEX5 = 7'b011_1111;
                HEX4 = 7'b011_1111;
                HEX3 = 7'b011_1111;
                HEX2 = 7'b011_1111;
                HEX1 = 7'b011_1111;
                HEX0 = 7'b011_1111;
            end
        end
        default: ;
        endcase
    end

    // State Transition Logic

    always_comb begin 
        case(present_state)
        `READY: next_state = `ENABLE_DOUBLECRACK;
        `ENABLE_DOUBLECRACK: next_state = `IN_DOUBLECRACK;
        `IN_DOUBLECRACK: begin 
            if(rdy_doublecrack == 1'b0) next_state = `IN_DOUBLECRACK;
            else next_state = `DONE;
        end
        `DONE: next_state = `DONE;
        default: next_state = `READY;
        endcase
    end

    always_ff@(posedge clk) begin 
        if(rst_n == 1'b0) present_state <= `READY;
        else present_state <= next_state;
    end
*/

endmodule: competition
