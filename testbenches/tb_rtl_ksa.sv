
// note to reader: ksa.sv once had a FETCH_J state. This testbench was developed before it was optimized, but you can still see how it was testbenched!

`define READY 3'b000
`define FETCH_I 3'b001
`define CALC_J 3'b010 
`define FETCH_J 3'b011 
`define WRITE_SJ 3'b100 
`define WRITE_SI_INCREMENT 3'b101 

`timescale 1ps / 1ps

module tb_rtl_ksa();

    // Logic Instantiations
    logic clk, rst_n;
    logic en_ksa;
    logic rdy_ksa;
    logic [7:0] addr_ksa, wrdata_ksa, rddata_ksa;
    logic wren_ksa;
    logic [23:0] key; // unique to ksa


    //memory for the s
    s_mem s( .address(addr_ksa), .clock(clk), .data(wrdata_ksa), .wren(wren_ksa), .q(rddata_ksa)); // We only care about the output q of the RAM block as rddata, only used by ksa.sv for task 2
    

    //init init( .clk(clk), .rst_n(rst_n), .en(en), .rdy(rdy), .addr(addr), .wrdata(wrdata), .wren(wren));
    ksa ksa( .clk(clk), .rst_n(rst_n), .en(en_ksa), .rdy(rdy_ksa), .key(key), .addr(addr_ksa), .rddata(rddata_ksa), .wrdata(wrdata_ksa), .wren(wren_ksa));


    
    initial begin 
        forever begin 
            #10;
            clk = 1'b0;
            #10;
            clk = 1'b1;
        end
    end

    int i;
    int j;
    int test_k[2:0];
    int test_s[256:0];
    int tmp;

    initial begin

        //resets the module
        en_ksa = 1'b0;
        @(negedge clk) rst_n = 1'b0;
        @(negedge clk) rst_n = 1'b1;

        key = 24'h438567; // set an arbitrary value for the key

        test_k[0] = key[23:16];
        test_k[1] = key[15:8];
        test_k[2] = key[7:0];

        //we need to initialize s
        for(i = 0; i < 256; i++) begin
            s.altsyncram_component.m_default.altsyncram_inst.mem_data[i] = i;
            test_s[i] = i;
        end

        while(~rdy_ksa) begin
            //wait for ready
        end

        //check that we begin in the ready state
        assert(ksa.present_state == `READY)
            else $error("ksa state is not READY");

        assert(rdy_ksa == 1'b1)
            else $error("ksa state is not READY");   

        //enables the module
        @(negedge clk) en_ksa = 1'b1;

        @(negedge clk) en_ksa = 1'b0;

        //check that we are no longer in the ready state
        assert(ksa.present_state == `FETCH_I)
            else $error("ksa state is not FETCH_I");

        assert(rdy_ksa == 1'b0)
            else $error("ready did not go low");

        //now we check looping through the states
        @(negedge clk);
        assert(ksa.present_state == `CALC_J)
            else $error("ksa state is not CALC_J");

        @(negedge clk);
        assert(ksa.present_state == `FETCH_J)
            else $error("ksa state is not FETCH_J");

        @(negedge clk);
        assert(ksa.present_state == `WRITE_SJ)
            else $error("ksa state is not WRITE_SJ");

        @(negedge clk);
        assert(ksa.present_state == `WRITE_SI_INCREMENT)
            else $error("ksa state is not WRITE_SI_INCREMENT");

        //Now we wait until finished
        while(~(ksa.present_state == `READY)) begin
            @(negedge clk);
        end

         j = 0;
        for(i = 0; i < 256; i++) begin
            j = (j + test_s[i] + test_k[i % 3]) % 256;
            tmp = test_s[i];
            test_s[i] = test_s[j];
            test_s[j] = tmp;
        end

        for(i = 0; i < 256; i++) begin
            assert(test_s[i] == s.altsyncram_component.m_default.altsyncram_inst.mem_data[i])
                else $error("Test value at %d, doesn't match %d, is instead %d", i, test_s[i], s.altsyncram_component.m_default.altsyncram_inst.mem_data[i]);
        end

        //now we run it again to see if it still works

        //check that we begin in the ready state
        assert(ksa.present_state == `READY)
            else $error("ksa state is not READY");

        assert(rdy_ksa == 1'b1)
            else $error("ksa state is not READY");   

        key = 24'h412532; // set an arbitrary value for the key

        test_k[0] = key[23:16];
        test_k[1] = key[15:8];
        test_k[2] = key[7:0];

        //enables again
        @(negedge clk) en_ksa = 1'b1;

        @(negedge clk) en_ksa = 1'b0;

        //Now we wait until finished
        while(~(ksa.present_state == `READY)) begin
            @(negedge clk);
        end

        j = 0;
        for(i = 0; i < 256; i++) begin
            j = (j + test_s[i] + test_k[i % 3]) % 256;
            tmp = test_s[i];
            test_s[i] = test_s[j];
            test_s[j] = tmp;
        end

        for(i = 0; i < 256; i++) begin
            assert(test_s[i] == s.altsyncram_component.m_default.altsyncram_inst.mem_data[i])
                else $error("Second run Test value at %d, doesn't match %d, is instead %d", i, test_s[i], s.altsyncram_component.m_default.altsyncram_inst.mem_data[i]);
        end

        $display("If no errors for second run, then the rdy - enable protocol worked!");
        $display("If no errors were displayed, then everything worked correctly!");
        $stop;
    end

endmodule: tb_rtl_ksa
