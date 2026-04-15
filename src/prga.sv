// 8 States

`define READY 3'b000
`define ML_PT 3'b001 
`define READ_I 3'b010 
`define READ_J 3'b011
`define WRITE_I 3'b100 
`define WRITE_J 3'b101 
`define READ_PAD 3'b110 
`define WRITE_PT 3'b111 

module prga(input logic clk, input logic rst_n,
            input logic en, output logic rdy,
            input logic [23:0] key,
            output logic [7:0] s_addr, input logic [7:0] s_rddata, output logic [7:0] s_wrdata, output logic s_wren,
            output logic [7:0] ct_addr, input logic [7:0] ct_rddata,
            output logic [7:0] pt_addr, input logic [7:0] pt_rddata, output logic [7:0] pt_wrdata, output logic pt_wren);

    // Logic Instantiations

    logic [7:0] current_i, next_i;
    logic [7:0] current_j, next_j;
    logic [7:0] current_k, next_k;

    logic [7:0] sdata_i, next_sdata_i;
    logic [7:0] sdata_j, next_sdata_j;

    logic [2:0] present_state, next_state;

    logic [7:0] message_length, next_message_length;

    // State Output Logic

    always_comb begin 

        rdy = 1'b0; // true for all states but `READY
        s_addr = 8'b0;
        s_wrdata = 8'b0;
        s_wren = 8'b0;
        ct_addr = 8'b0;
        pt_addr = 8'b0;
        pt_wrdata = 8'b0;
        pt_wren = 8'b0; 

        next_i = current_i;
        next_j = current_j;
        next_k = current_k; // Starting value for k is always 8'b1
        next_sdata_i = sdata_i;
        next_sdata_j = sdata_j;

        next_message_length = message_length;

        case(present_state)
        `READY: begin 
            rdy = 1'b1; 
            ct_addr = 8'b0; // need to have ct MEM block spitting out message_length on the get-go
            next_i = 8'd0; 
            next_j = 8'd0; 
            next_k = 8'd1; 
            next_sdata_i = 8'd0;
            next_sdata_j = 8'd0;
        end
        `ML_PT: begin 
            next_message_length = ct_rddata;    // record message length
            pt_wrdata = ct_rddata;
            pt_addr = 8'b0;
            pt_wren = 1'b1;
        end
        `READ_I: begin 
            next_i = (current_i + 8'd1); // % 9'd256; 
            s_addr = (current_i + 8'd1); // % 9'd256; // snatching s[i] as we acquire current_i
        end
        `READ_J: begin 
            next_sdata_i = s_rddata;
            next_j = (current_j + s_rddata); // % 9'd256;
            s_addr = (current_j + s_rddata); // % 9'd256; // snatching s[j] as we acquire current_j
        end
        `WRITE_I: begin 
            next_sdata_j = s_rddata;
            s_addr = current_j;
            s_wrdata = sdata_i;
            s_wren = 1'b1;
        end
        `WRITE_J: begin 
            s_addr = current_i;
            s_wrdata = sdata_j;
            s_wren = 1'b1;
        end
        `READ_PAD: begin 
            s_addr = (sdata_i + sdata_j); // % 9'd256;
            ct_addr = current_k;
        end
        `WRITE_PT: begin 
            pt_addr = current_k;
            pt_wrdata = s_rddata ^ ct_rddata; // pad[k] XOR ciphertext[k]
            pt_wren = 1'b1;
            next_k = current_k + 8'd1;
        end
        default: ;
        endcase
    end

    // State Transition Logic

    always_comb begin 
        case(present_state)
        `READY: begin 
            if(en == 1'b1) next_state = `ML_PT;
            else next_state = `READY;
        end
        `ML_PT: next_state = `READ_I;
        `READ_I: next_state = `READ_J;
        `READ_J: next_state = `WRITE_I;
        `WRITE_I: next_state = `WRITE_J;
        `WRITE_J: next_state = `READ_PAD;
        `READ_PAD: next_state = `WRITE_PT;
        `WRITE_PT: begin 
            if( current_k == message_length) next_state = `READY;
            else next_state = `READ_I;
        end
        default: next_state = `READY;
        endcase
    end

    // State Register and Incrementing Logic 

    always_ff@( posedge clk ) begin 
        if(rst_n == 1'b0) begin 
            present_state <= `READY;
            current_i <= 8'b0;
            current_j <= 8'b0;
            current_k <= 8'b1; // Index k always starts at 1 
            sdata_i <= 8'b0;
            sdata_j <= 8'b0;
            message_length <= 8'b0;
        end
        else begin 
            present_state <= next_state;
            message_length <= next_message_length; 
            current_i <= next_i; 
            sdata_i <= next_sdata_i; 
            current_j <= next_j; 
            sdata_j <= next_sdata_j; 
            current_k <= next_k;
        end
    end

endmodule: prga
