
// Two states: READY, INITIALIZING
// READY: Implements ready-enable microprotocol. It is the idle state where rdy is ON and awaits for a request. Transitions to INITIALIZING when enable is asserted.
// INITIALIZING: State where initialization happens (refer to task 1 pseudocode). Deasserts rdy. Returns back to READY upon completion.

`define READY 1'b0
`define INITIALIZING 1'b1

module init(input logic clk, input logic rst_n,
            input logic en, output logic rdy,
            output logic [7:0] addr, output logic [7:0] wrdata, output logic wren);

    // State Instantiations
    logic next_state, present_state;

    // Increment Wires Instantiations
    logic [7:0] current_i, next_i;

    // State Output Logic 

    always_comb begin 

        rdy = 1'b0;
        addr = 8'b0;
        wrdata = 8'b0;
        wren = 1'b0;
        next_i = current_i;

        case(present_state)
        `READY: begin 
            rdy = 1'b1;
        end
        `INITIALIZING: begin 
            rdy = 1'b0;
            addr = current_i;
            wrdata = current_i;
            wren = 1'b1;
            next_i = current_i + 8'd1; // Incrementing for current_i. Happens on every clock cycle with `INITIALIZING loops back to itself 
        end
        default: ;
        endcase
    end

    // State Transition Logic 

    always_comb begin 

        next_state = `READY;

        case(present_state) 
        `READY: begin 
            if(en == 1'b1) next_state = `INITIALIZING; 
            else next_state = `READY;
        end
        `INITIALIZING: begin 
            if(current_i == 8'd255) next_state = `READY;
            else next_state = `INITIALIZING;
        end
        default: next_state = `READY;
        endcase
    end

    // State Register Logic 

    always_ff@( posedge clk) begin  
        if(rst_n == 1'b0) begin 
            present_state <= `READY;
            current_i <= 8'd0;
        end
        else begin 
            present_state <= next_state;
            current_i <= next_i;
        end
    end


endmodule: init