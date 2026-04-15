
// State Instantiations

`define READY 2'b00 
`define ENABLE_DOUBLECRACK 2'b01 
`define IN_DOUBLECRACK 2'b10 
`define DONE 2'b11 

module task5(input logic CLOCK_50, input logic [3:0] KEY, input logic [9:0] SW,
             output logic [6:0] HEX0, output logic [6:0] HEX1, output logic [6:0] HEX2,
             output logic [6:0] HEX3, output logic [6:0] HEX4, output logic [6:0] HEX5,
             output logic [9:0] LEDR);

    // Logic Instantiations

    logic [7:0] ct_addr, ct_rddata, ct_wrdata;
    logic ct_wren;

    logic clk, rst_n, en_doublecrack, rdy_doublecrack; 
    logic [23:0] key;
    logic key_valid;

    logic [1:0] present_state, next_state;

    // Module Instantiations

    ct_mem ct( .address(ct_addr), .clock(clk), .data(ct_wrdata), .wren(ct_wren), .q(ct_rddata));
    doublecrack dc( .clk(clk), .rst_n(rst_n), .en(en_doublecrack), .rdy(rdy_doublecrack), .key(key), .key_valid(key_valid), .ct_addr(ct_addr), .ct_rddata(ct_rddata));

    // Logic Assignments

    assign clk = CLOCK_50; 
    assign rst_n = KEY[3];
    assign LEDR = {key_valid,key_valid,key_valid,key_valid,key_valid,key_valid,key_valid,key_valid,key_valid,key_valid};

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


endmodule: task5
