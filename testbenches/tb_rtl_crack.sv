`define READY 3'b000
`define GET_ML 3'b001
`define ENABLE_ARC4 3'b010 
`define IN_ARC4 3'b011
`define PT_WAIT 3'b100
`define PT_CHECKER 3'b101
`define KEY_INC 3'b110 // key incrementer 

`timescale 1ps / 1ps

module tb_rtl_crack();

    logic clk;
    logic rst_n; // rst_n is universal for both task 4 FSM and crack.sv, however a separate rst_n for crack can be implemented if need be
    logic en_crack, rdy_crack; 
    logic [23:0] key;
    logic key_valid; 

    logic [7:0] ct_addr, ct_rddata, ct_wrdata; // ct_wrdata, ct_wren are unused/not driven
    logic ct_wren;

    // New ports for task 5 crack

    logic [23:0] dc_initial_key; 
    logic [23:0] dc_key_inc;
    logic [7:0] dc_pt_addr; 
    logic [7:0] dc_pt_rddata; 
    logic stop_flag;

    

    ct_mem ct( .address(ct_addr), .clock(clk), .data(ct_wrdata), .wren(ct_wren), .q(ct_rddata));
    crack c( .clk(clk), .rst_n(rst_n), .en(en_crack), .rdy(rdy_crack), .key(key), .key_valid(key_valid), .ct_addr(ct_addr), .ct_rddata(ct_rddata),
             .dc_initial_key(dc_initial_key), .dc_key_inc(dc_key_inc), .dc_pt_addr(dc_pt_addr), .dc_pt_rddata(dc_pt_rddata), .stop_flag(stop_flag));




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
        dc_initial_key = 24'd0;
        dc_key_inc = 24'd1; 
        en_crack = 1'b0;
        @(negedge clk) rst_n = 1'b0;
        @(negedge clk) rst_n = 1'b1;

        #20;

        //We will decipher this simple example with a small key index
        $readmemh("test1.memh", ct.altsyncram_component.m_default.altsyncram_inst.mem_data);


        while(~rdy_crack) begin
            //wait for ready
        end

        //check that we begin in the ready state
        assert(c.present_state == `READY)
            else $error("crack state is not READY");

        assert(rdy_crack == 1'b1)
            else $error("crack state is not READY");   

        //enables the module
        @(negedge clk) en_crack = 1'b1;

        @(negedge clk) en_crack = 1'b0;

        //check that we are no longer in the ready state
        assert(c.present_state == `GET_ML)
            else $error("crack state is not GET_ML");

        assert(rdy_crack == 1'b0)
            else $error("ready did not go low");

        //now we can just test the state transitions

        @(negedge clk);
        assert(c.present_state == `ENABLE_ARC4)
            else $error("crack state is not ENABLE_ARC4");

        //We see if the enabling wiring is actually set high
        assert(c.en_arc4 == 1'b1)
            else $error("enable for arc4 not set high");

        @(negedge clk);
        assert(c.present_state == `IN_ARC4)
            else $error("crack state is not IN_ARC4");

        while(~(c.present_state == `PT_WAIT)) begin
            @(negedge clk);
        end

        //We have now exited the arc4 state, and so we can test some signals
        assert(c.rdy_arc4 == 1'b1)
            else $error("Arc 4 not set back to ready afterwards");

        assert(c.present_state == `PT_WAIT)
            else $error("State is incorrect after being in arc 4");

        @(negedge clk);
        assert(c.present_state == `PT_CHECKER)
            else $error("crack state is not PT_CHECKER");

        while((c.present_state == `PT_CHECKER)) begin
            @(negedge clk);
        end

        assert(c.present_state == `KEY_INC)
            else $error("crack state is not KEY_INC");

        @(negedge clk);
        assert(c.present_state == `ENABLE_ARC4)
            else $error("crack state is not ENABLE_ARC4");

        while(~(c.present_state == `PT_WAIT)) begin
            @(negedge clk);
        end
        //waited for PT checker
        $display("Another cycle complete, key is %d", key);

        @(negedge clk);

        while((c.present_state == `PT_WAIT)) begin
            @(negedge clk);
        end
        //waited for PT checker
        $display("Another cycle complete, key is %d", key);

        @(negedge clk);

        while((c.present_state == `PT_CHECKER)) begin
            @(negedge clk);
        end

        $display("Done checking, key is %d", key);

        //check that we begin in the ready state
        assert(c.present_state == `READY)
            else $error("crack state is not READY");

        assert(rdy_crack == 1'b1)
            else $error("crack state is not READY");   

        

        //now we check the final answer
        assert(key_valid == 1'b1)
            else $error("key_valid should be set high");  

        assert(key == 24'h1)
            else $error("key should be , not %d", key);    

        for(i = 0; i < 46;i++) begin
            assert(c.pt.altsyncram_component.m_default.altsyncram_inst.mem_data[i] == lookup[i])
                else $error("pt value should be %d, not %d", lookup[i], c.pt.altsyncram_component.m_default.altsyncram_inst.mem_data[i]);  
        end



        $display("The number of clock cycles is %d", counter);


        //We can also check another file
        //We will decipher this simple example with a small key index
        $readmemh("test4.memh", ct.altsyncram_component.m_default.altsyncram_inst.mem_data);


        while(~rdy_crack) begin
            //wait for ready
        end

        //check that we begin in the ready state
        assert(c.present_state == `READY)
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
            assert(c.pt.altsyncram_component.m_default.altsyncram_inst.mem_data[i] == lookup2[i+1])
                else $error("pt value be %d, not %d", lookup2[i+1], c.pt.altsyncram_component.m_default.altsyncram_inst.mem_data[i]);  
        end


        $display("If no errors for second run, then the rdy - enable protocol worked!");
        $display("If no errors were displayed, then everything worked correctly!");
        $stop;
    end


endmodule: tb_rtl_crack
