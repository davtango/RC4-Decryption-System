// State Definitions

`define READY 3'b000
`define FETCH_I 3'b001
`define CALC_J 3'b010 
`define WRITE_SJ 3'b011
`define WRITE_SI_INCREMENT 3'b100

module ksa(input logic clk, input logic rst_n,
           input logic en, output logic rdy,
           input logic [23:0] key,
           output logic [7:0] addr, input logic [7:0] rddata, output logic [7:0] wrdata, output logic wren);

    // State Instantiations
    logic [2:0] next_state, present_state;

    // Increment Wires Instantiations
    logic [7:0] current_i, next_i;
    logic [7:0] current_j, next_j;

    // Data Instantiations (wires that hold values of S[i] and S[j] for swapping)

    logic [7:0] data_i, next_data_i;
    logic [7:0] data_j, next_data_j; 

    // Key Byte Instantiations - The key is divided in 24 bits or 3 bytes.
    // In the task 2 pseudocode, all variables in "j=(j+s[i] + key[i mod keylength)] mod 256" are 8 bits, including key[i...]
    // therefore, current_i % 2'b11 determines the byte in key (big endian), not the index

    logic [7:0] key_byte;

    // Key Byte Logic - sorts out which byte of the key to use, in big endian

    always_comb begin 
        case(current_i % 2'b11) // % 3 replaced with %2'b11, recall 08a-timing-2.pdf
        2'd0: key_byte = key[23:16];
        2'd1: key_byte = key[15:8];
        2'd2: key_byte = key[7:0];
        default: key_byte = key[7:0];
        endcase
    end

    // State Output Logic 

    always_comb begin 

        rdy = 1'b0;
        addr = 8'b0;
        wrdata = 8'b0;
        wren = 8'b0;

        next_i = current_i;
        next_j = current_j;
        next_data_i = data_i;
        next_data_j = data_j;

        case(present_state) 
        `READY: begin 
            rdy = 1'b1;
            next_i = 8'd0;
            next_j = 8'd0;
            next_data_i = 8'd0;
            next_data_j = 8'd0;
        end
        `FETCH_I: begin 
            addr = current_i;
        end
        `CALC_J: begin 
            next_data_i = rddata;
            next_j = (current_j + rddata + key_byte) % 9'd256; // key_byte determined in Key Byte Logic. % 9'd256 == taking 8 order LSB by compiler/synthesizer
            addr = (current_j +rddata +key_byte) % 9'd256;
        end
        `WRITE_SJ: begin 
            next_data_j = rddata;
            addr = current_j;
            wren = 1'b1; 
            wrdata = data_i;
        end
        `WRITE_SI_INCREMENT: begin 
            addr = current_i; 
            wren = 1'b1;
            wrdata = data_j;
            next_i = current_i + 8'd1;
        end
        default: ;
        endcase

    end

    // State Transition Logic 

    always_comb begin 

        case(present_state)

        `READY: begin 
            if(en == 1'b1) next_state = `FETCH_I;
            else next_state = `READY;
        end
        `FETCH_I: begin 
            // if(current_i == 8'd255) next_state = `READY;
            next_state = `CALC_J;
        end
        `CALC_J: begin 
            next_state = `WRITE_SJ;
        end
        `WRITE_SJ: begin 
            next_state = `WRITE_SI_INCREMENT;
        end
        `WRITE_SI_INCREMENT: begin
            if(current_i == 8'd255) next_state = `READY; 
            else next_state = `FETCH_I;
        end
        default: next_state = `READY;
        endcase
    end

    // State and Incremental Register Logic 

    always_ff@(posedge clk) begin
        if(rst_n == 1'b0) begin 
            present_state <= `READY;
            current_i <= 8'd0;
            current_j <= 8'd0;
            data_i <= 8'd0;
            data_j <= 8'd0;
        end
        else begin 
            present_state <= next_state;
            data_i <= next_data_i;
            current_j <= next_j; 
            data_j <= next_data_j; 
            current_i <= next_i;
        end
    end

endmodule: ksa
