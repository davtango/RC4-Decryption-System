
`define READY 3'b000
`define CT1 3'b001 
`define CT2 3'b010 
`define EN_CRACKS 3'b011 
`define IN_CRACKS 3'b100 
`define PT1 3'b101 
`define PT2 3'b110 

`timescale 1ps / 1ps


module tb_rtl_doublecrack();

    logic clk;
    logic rst_n; // rst_n is universal for both task 4 FSM and crack.sv, however a separate rst_n for crack can be implemented if need be
    logic en_crack, rdy_crack; 
    logic [23:0] key;
    logic key_valid; 

    logic [7:0] ct_addr, ct_rddata, ct_wrdata; // ct_wrdata, ct_wren are unused/not driven
    logic ct_wren;

    

    ct_mem ct( .address(ct_addr), .clock(clk), .data(ct_wrdata), .wren(ct_wren), .q(ct_rddata));
    doublecrack dc( .clk(clk), .rst_n(rst_n), .en(en_crack), .rdy(rdy_crack), .key(key), .key_valid(key_valid), .ct_addr(ct_addr), .ct_rddata(ct_rddata));


    int counter = 0;
    initial begin 
        forever begin 
            #2;
            clk = 1'b0;
            #2;
            clk = 1'b1;
            counter++;
        end
    end

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

    initial begin
        //resets the module
        en_crack = 1'b0;
        @(negedge clk) rst_n = 1'b0;
        @(negedge clk) rst_n = 1'b1;

        #20;

        //We will decipher this simple example with a small key index
        $readmemh("test.memh", ct.altsyncram_component.m_default.altsyncram_inst.mem_data);


        while(~rdy_crack) begin
            //wait for ready
        end

        //check that we begin in the ready state
        assert(dc.present_state == `READY)
            else $error("crack state is not READY");

        assert(rdy_crack == 1'b1)
            else $error("crack state is not READY");   

        //enables the module
        @(negedge clk) en_crack = 1'b1;

        @(negedge clk) en_crack = 1'b0;

        //check that we are no longer in the ready state
        assert(dc.present_state == `CT1)
            else $error("crack state is not CT1");

        assert(rdy_crack == 1'b0)
            else $error("ready did not go low");


        while((dc.present_state == `CT2) || (dc.present_state == `CT1)) begin
            @(negedge clk);
        end

        //check that we have filled in the memory
        for(i = 0; i < ct.altsyncram_component.m_default.altsyncram_inst.mem_data[0]; i++) begin
            assert(dc.ct_c1.altsyncram_component.m_default.altsyncram_inst.mem_data[i] == ct.altsyncram_component.m_default.altsyncram_inst.mem_data[i])
                else $error("The first memory is not equal to %d, as it is %d", ct.altsyncram_component.m_default.altsyncram_inst.mem_data[i], dc.ct_c1.altsyncram_component.m_default.altsyncram_inst.mem_data[i]);
        end

        //check that we have filled in the memory
        for(i = 0; i < ct.altsyncram_component.m_default.altsyncram_inst.mem_data[0]; i++) begin
            assert(dc.ct_c2.altsyncram_component.m_default.altsyncram_inst.mem_data[i] == ct.altsyncram_component.m_default.altsyncram_inst.mem_data[i])
                else $error("The second memory is not equal to %d, as it is %d", ct.altsyncram_component.m_default.altsyncram_inst.mem_data[i], dc.ct_c2.altsyncram_component.m_default.altsyncram_inst.mem_data[i]);
        end

        //check the control of the crackers
        assert(dc.en_c1 == 1'b1)
            else $error("first cracker not enabled");

        assert(dc.en_c2 == 1'b1)
            else $error("second cracker not enabled");

        @(negedge clk);

        //check movement through the cracker
        //check that we are no longer in the ready state
        assert(dc.c1.present_state == `GET_ML)
            else $error("crack state is not GET_ML");

        assert(rdy_crack == 1'b0)
            else $error("ready did not go low");

        //now we can just test the state transitions

        @(negedge clk);
        assert(dc.c1.present_state == `ENABLE_ARC4)
            else $error("crack state is not ENABLE_ARC4");

        //We see if the enabling wiring is actually set high
        assert(dc.c1.en_arc4 == 1'b1)
            else $error("enable for arc4 not set high");

        @(negedge clk);
        assert(dc.c1.present_state == `IN_ARC4)
            else $error("crack state is not IN_ARC4");

        while(~(dc.c1.present_state == `PT_WAIT)) begin
            @(negedge clk);
        end

        //We have now exited the arc4 state, and so we can test some signals
        assert(dc.c1.rdy_arc4 == 1'b1)
            else $error("Arc 4 not set back to ready afterwards");

        assert(dc.c1.present_state == `PT_WAIT)
            else $error("State is incorrect after being in arc 4");

        @(negedge clk);
        assert(dc.c1.present_state == `PT_CHECKER)
            else $error("crack state is not PT_CHECKER");

        while((dc.c1.present_state == `PT_CHECKER)) begin
            @(negedge clk);
        end

        assert(dc.c1.present_state == `KEY_INC)
            else $error("crack state is not KEY_INC");

        //Now that we have checked the internal circle state, we can go back to black box testing

        while(rdy_crack == 1'b0) begin
            @(negedge clk);
        end

        for(i = 0; i < 46;i++) begin
            assert(dc.pt.altsyncram_component.m_default.altsyncram_inst.mem_data[i] == lookup[i])
                else $error("first pt value should be %d, not %d", lookup[i], dc.pt.altsyncram_component.m_default.altsyncram_inst.mem_data[i]);  
        end

        $display("The number of clock cycles is %d", counter);


        //We can also check another file
        //We will decipher this simple example with a small key index
        $readmemh("test4.memh", ct.altsyncram_component.m_default.altsyncram_inst.mem_data);

        //enables the module
        @(negedge clk) rst_n = 1'b0;

        @(negedge clk) rst_n = 1'b1;

        

        while(~rdy_crack) begin
            //wait for ready
        end

        //check that we begin in the ready state
        assert(dc.present_state == `READY)
            else $error("crack state is not READY");

        assert(rdy_crack == 1'b1)
            else $error("crack state is not READY"); 

        //enables the module
        @(negedge clk) en_crack = 1'b1;

        @(negedge clk) en_crack = 1'b0;

        while(rdy_crack == 1'b0) begin
            @(negedge clk);
        end
        //at the end of this we are now ready

        //now we check the final answer
        assert(key_valid == 1'b1)
            else $error("key_valid should be set high");  

        assert(key == 24'h7)
            else $error("key should be 7, not %d", key);    

        for(i = 0; i < 76;i++) begin
            assert(dc.pt.altsyncram_component.m_default.altsyncram_inst.mem_data[i] == lookup2[i+1])
                else $error("second pt value be %d, not %d", lookup2[i+1], dc.pt.altsyncram_component.m_default.altsyncram_inst.mem_data[i]);  
        end



        $display("If no errors for second run, then the rdy - enable protocol worked!");
        $display("If no errors were displayed, then everything worked correctly!");
        $stop;
    end

endmodule: tb_rtl_doublecrack
