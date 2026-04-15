
// State Instantiations

`define READY 2'b00 
`define ENABLE_DOUBLECRACK 2'b01 
`define IN_DOUBLECRACK 2'b10 
`define DONE 2'b11 

`timescale 1ps / 1ps

module tb_rtl_task5();

logic TB_CLOCK_50;
    logic [3:0] TB_KEY;
    logic [9:0] TB_SW;
    logic [6:0] TB_HEX0, TB_HEX1, TB_HEX2, TB_HEX3, TB_HEX4, TB_HEX5;
    logic [9:0] TB_LEDR;

    task5 task5(.CLOCK_50(TB_CLOCK_50), .KEY(TB_KEY), .SW(TB_SW), .HEX0(TB_HEX0), .HEX1(TB_HEX1), .HEX2(TB_HEX2), .HEX3(TB_HEX3), .HEX4(TB_HEX4), .HEX5(TB_HEX5), .LEDR(TB_LEDR));

    logic [1:0] TB_task5_present_state; 

    assign TB_task5_present_state = task5.present_state;

    // Start continuous clock stimulus with 20 ps period

    int i;
    int j;
    int test_k[2:0];
    int lookup [0:45] = '{
    45, 73, 110, 32,
    97, 32, 104, 111, 108, 101, 32,
    105, 110, 32,
    116, 104, 101, 32,
    103, 114, 111, 117, 110, 100, 32,
    116, 104, 101, 114, 101, 32,
    108, 105, 118, 101, 100, 32,
    97, 32,
    104, 111, 98, 98, 105, 116, 46
};

    int lookup2 [0:76] = '{
    7,
    76, 84, 104, 101, 32,
    115, 107, 121, 32,
    97, 98, 111, 118, 101, 32,
    116, 104, 101, 32,
    112, 111, 114, 116, 32,
    119, 97, 115, 32,
    116, 104, 101, 32,
    99, 111, 108, 111, 114, 32,
    111, 102, 32,
    116, 101, 108, 101, 118, 105, 115, 105, 111, 110, 44, 32,
    116, 117, 110, 101, 100, 32,
    116, 111, 32,
    97, 32,
    100, 101, 97, 100, 32,
    99, 104, 97, 110, 110, 101, 108
    };

    int counter = 0;

    initial begin 
        forever begin 
            #10;
            TB_CLOCK_50 = 1'b0;
            #10;
            TB_CLOCK_50 = 1'b1;
            counter++;
        end
    end

    initial begin 

       #15; 

        $readmemh("test3.memh", task5.ct.altsyncram_component.m_default.altsyncram_inst.mem_data);

        // Initialize all inputs and reset 

        @(negedge TB_CLOCK_50) TB_KEY[3] = 1'b1; // de-assert ready

        @(negedge TB_CLOCK_50) TB_KEY[3] = 1'b0; // assert ready
        
        @(posedge TB_CLOCK_50) begin 
            #5;
            TB_KEY[3] = 1'b1; // de-assert ready
        end

        @(negedge TB_CLOCK_50);

        //check if we are initialized to the correct starting state
        assert(TB_task5_present_state == `READY)
            else $error("task5 state is not READY at the beginning");

        @(negedge TB_CLOCK_50);

        //check if we are initialized to the correct starting state
        assert(TB_task5_present_state == `ENABLE_DOUBLECRACK)
            else $error("task5 state is not ENABLE_DOUBLECRACK 2nd");

        @(negedge TB_CLOCK_50);

        //check if we are initialized to the correct starting state
        assert(TB_task5_present_state == `IN_DOUBLECRACK)
            else $error("task5 state is not IN_CRACK 3nd");

        while(TB_task5_present_state == `IN_DOUBLECRACK) begin
            @(negedge TB_CLOCK_50);
        end
        
        //out of cracking
        assert(TB_task5_present_state == `DONE)
            else $error("task5 state is not DONE last");

        //now we check the final answer
        assert(task5.key_valid == 1'b1)
            else $error("key_valid should be set high");  

        //check that the output key is correct
        assert(task5.key == 24'h1)
            else $error("key should be 1, not %d", task5.key);    

        //looping through the plain text memory to see if it matches the correct value
        for(i = 0; i < 46;i++) begin
            assert(task5.dc.pt.altsyncram_component.m_default.altsyncram_inst.mem_data[i] == lookup[i])
                else $error("pt value should be %d, not %d", lookup[i], task5.dc.pt.altsyncram_component.m_default.altsyncram_inst.mem_data[i]);  
        end

        //we check that all of the 7 segment displays are correctly lit up based on the key (1)
        assert(TB_HEX5 == 7'b1000000) 
            else $error("Hex 5 is incorrect");  

        //7 segment checking
        assert(TB_HEX4 == 7'b1000000) 
            else $error("Hex 4 is incorrect");  

        //7 segment checking
        assert(TB_HEX3 == 7'b1000000) 
            else $error("Hex 3 is incorrect");  

        //7 segment checking
        assert(TB_HEX2 == 7'b1000000) 
            else $error("Hex 2 is incorrect");  

        //7 segment checking
        assert(TB_HEX1 == 7'b1000000) 
            else $error("Hex 1 is incorrect");  

        //7 segment checking
        assert(TB_HEX0 == 7'b1111001) 
            else $error("Hex 0 is incorrect");  

        //7 segment checking
        assert(TB_LEDR[3] == 1'b1) 
            else $error("Valid LEDs should be set high");  

         //We can also check another file
        //We will decipher this simple example with a small key index
        $readmemh("test4.memh", task5.ct.altsyncram_component.m_default.altsyncram_inst.mem_data);

        @(negedge TB_CLOCK_50) TB_KEY[3] = 1'b1; // de-assert ready

        @(negedge TB_CLOCK_50) TB_KEY[3] = 1'b0; // assert ready

        @(posedge TB_CLOCK_50) begin 
            #5;
            TB_KEY[3] = 1'b1; // de-assert ready
        end

        @(negedge TB_CLOCK_50);

        //check if we are initialized to the correct starting state
        assert(TB_task5_present_state == `READY)
            else $error("task5 state is not READY at the beginning");

        while(~(TB_task5_present_state == `DONE)) begin
            @(negedge TB_CLOCK_50);
        end
        
        //out of cracking
        assert(TB_task5_present_state == `DONE)
            else $error("task5 state is not DONE last");

        //now we check the final answer
        assert(task5.key_valid == 1'b1)
            else $error("key_valid should be set high");  

        //check that the output key is correct
        assert(task5.key == 24'h7)
            else $error("key should be 7, not %d", task5.key);    

        //looping through the plain text memory to see if it matches the correct value
        for(i = 0; i < 76;i++) begin
            assert(task5.dc.pt.altsyncram_component.m_default.altsyncram_inst.mem_data[i] == lookup2[i+1])
                else $error("pt value be %d, not %d", lookup2[i+1], task5.dc.pt.altsyncram_component.m_default.altsyncram_inst.mem_data[i]);  
        end


        //we check that all of the 7 segment displays are correctly lit up based on the key (1)
        assert(TB_HEX5 == 7'b1000000) 
            else $error("Hex 5 is incorrect");  

        //7 segment checking
        assert(TB_HEX4 == 7'b1000000) 
            else $error("Hex 4 is incorrect");  

        //7 segment checking
        assert(TB_HEX3 == 7'b1000000) 
            else $error("Hex 3 is incorrect");  

        //7 segment checking
        assert(TB_HEX2 == 7'b1000000) 
            else $error("Hex 2 is incorrect");  

        //7 segment checking
        assert(TB_HEX1 == 7'b1000000) 
            else $error("Hex 1 is incorrect");  

        //7 segment checking
        assert(TB_HEX0 == 7'b1111000) 
            else $error("Hex 0 is incorrect");  

        //7 segment checking
        assert(TB_LEDR[3] == 1'b1) 
            else $error("Valid LEDs should be set high");


        $display("Cracking complete, took %d clock cycles", counter);
        $stop;

    end

endmodule: tb_rtl_task5
