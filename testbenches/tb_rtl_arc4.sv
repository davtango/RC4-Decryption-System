`define READY 3'b000
`define ENABLE_INIT 3'b001 
`define IN_INIT 3'b010 
`define ENABLE_KSA 3'b011 
`define IN_KSA 3'b100 
`define ENABLE_PRGA 3'b101
`define IN_PRGA 3'b110 

`timescale 1ps / 1ps

module tb_rtl_arc4();

    logic TB_CLK;
    logic [2:0] A4_STATE;
    logic rst_n;
    logic en_arc4;
    logic rdy_arc4;
    logic [23:0] key;
    logic [7:0] ct_addr, ct_rddata;
    logic [7:0] pt_addr, pt_rddata, pt_wrdata;
    logic pt_wren;

    logic [7:0] ct_data; //unused
    logic ct_wren; //unused


    //instantiate all of the relevant modules
    ct_mem ct( .address(ct_addr), .clock(TB_CLK), .data(ct_data), .wren(ct_wren), .q(ct_rddata));
    pt_mem pt( .address(pt_addr), .clock(TB_CLK), .data(pt_wrdata), .wren(pt_wren), .q(pt_rddata));
    arc4 a4( .clk(TB_CLK), .rst_n(rst_n), .en(en_arc4), .rdy(rdy_arc4), .key(key), .ct_addr(ct_addr), .ct_rddata(ct_rddata),
             .pt_addr(pt_addr), .pt_rddata(pt_rddata), .pt_wrdata(pt_wrdata), .pt_wren(pt_wren));
    

    initial begin 
        forever begin 
            #10;
            TB_CLK = 1'b0;
            #10;
            TB_CLK = 1'b1;
        end
    end

    assign A4_STATE = a4.present_state;


    /* Testing Plan 
    - White box testing: 
        We want to test state transitions, that every gets enabled at the correct time
    -   We want to test the behavour matches that of expected code
    - Black box testing:
        We want to check the outputs at the end matches our expected value
    - Check ready enable testing
        

    */

    int i;
    int j;
    int tmp;
    int test_s[256:0];
    int test_k[2:0];
    int plain_test[256:0];
    int k;

    initial begin

        //resets the module
        en_arc4 = 1'b0;
        @(negedge TB_CLK) rst_n = 1'b0;
        @(negedge TB_CLK) rst_n = 1'b1;

        key = 24'h438567; // set an arbitrary value for the key

        test_k[0] = key[23:16];
        test_k[1] = key[15:8];
        test_k[2] = key[7:0];

        while(~rdy_arc4) begin
            //wait for ready
        end

        //check that we begin in the ready state
        assert(A4_STATE == `READY)
            else $error("ARC4 state is not READY");


        #20;
        //writes to the cipher text memory so we can convert it
        $readmemh("test1.memh", ct.altsyncram_component.m_default.altsyncram_inst.mem_data);


        //checkes that ready is high

        //enables the module
        @(negedge TB_CLK) en_arc4 = 1'b1;

        @(negedge TB_CLK) en_arc4 = 1'b0;

        //check that we are no longer in the ready state
        assert(A4_STATE == `ENABLE_INIT)
            else $error("ARC4 state is not ENABLE_INIT");

        //checks that ready went low
        assert(rdy_arc4 == 1'b0)
            else $error("Ready stays high after enable");

        //check that all the outputs in the state are correct
        assert(a4.en_init == 1'b1) 
            else $error("ARC4 didn't enable init");

        //check that none of the other outputs are enabled
        assert(a4.en_ksa == 1'b0) 
            else $error("Enabled ksa when it shouldn't have");
        assert(a4.en_prga == 1'b0) 
            else $error("Enabled prga when it shouldn't have");


        repeat (5) begin
            @(negedge TB_CLK); //
        end

        //checks that the signals stayed low
        assert(rdy_arc4 == 1'b0)
            else $error("Ready stays high after enable");

        //check that all the outputs in the state are correct
        assert(a4.en_ksa == 1'b0) 
            else $error("Enabled ksa when it shouldn't have");
        assert(a4.en_prga == 1'b0) 
            else $error("Enabled prga when it shouldn't have");

        
        //We wait until out of init staet
        while(A4_STATE == `IN_INIT) begin
            @(negedge TB_CLK); //wait until out of the init state
        end

        //We check the memory for the correct filled values of s
        for(i = 0; i < 256; i++) begin
            test_s[i] = i;
            assert(a4.s.altsyncram_component.m_default.altsyncram_inst.mem_data[i] == i)
                else $error("The S ram was not filled with the correct value for %d, it is %d", i, a4.s.altsyncram_component.m_default.altsyncram_inst.mem_data[i]);
        end

        //checks for the state transition in the KSA state, along with the wires being high
        assert(A4_STATE == `ENABLE_KSA)
            else $error("Switched to the incorrect state");

        assert(a4.en_ksa == 1'b1)
            else $error("Didn't enable KSA");

        assert(a4.en_prga == 1'b0) 
            else $error("Enabled prga when it shouldn't have");

        assert(a4.en_init == 1'b0) 
            else $error("Enabled en_init when it shouldn't have");


        repeat (5) begin
            @(negedge TB_CLK); //
        end

        //checks that the signals stayed low
        assert(rdy_arc4 == 1'b0)
            else $error("Ready stays high after enable");

        //check that all the outputs in the state are correct
        assert(a4.en_ksa == 1'b0) 
            else $error("Enabled ksa when it shouldn't have");
        assert(a4.en_prga == 1'b0) 
            else $error("Enabled prga when it shouldn't have");
        
        //We wait until we are out of the KSA state
        while(A4_STATE == `IN_KSA) begin
            @(negedge TB_CLK); //wait until out of the init state
        end


        //We check the memory for the correct filled values of s
        j = 0;
        for(i = 0; i < 256; i++) begin
            j = (j + test_s[i] + test_k[i % 3]) % 256;
            tmp = test_s[i];
            test_s[i] = test_s[j];
            test_s[j] = tmp;
        end

        for(i = 0; i < 256; i++) begin
            assert(a4.s.altsyncram_component.m_default.altsyncram_inst.mem_data[i] == test_s[i])
                else $error("The KSA-level S ram was not filled with the correct value for %d, it is %d instead of %d", i, a4.s.altsyncram_component.m_default.altsyncram_inst.mem_data[i], test_s[i]);

        end


        //checks for the state transition in the KSA state, along with the wires being high
        assert(A4_STATE == `ENABLE_PRGA)
            else $error("Switched to the incorrect state");

        assert(a4.en_ksa == 1'b0)
            else $error("Enabled KSA when it shouldn't have");

        assert(a4.en_prga == 1'b1) 
            else $error("Didn't enable PRGA");

        assert(a4.en_init == 1'b0) 
            else $error("Enabled en_init when it shouldn't have");


        repeat (5) begin
            @(negedge TB_CLK); //
        end

        //checks that the signals stayed low
        assert(rdy_arc4 == 1'b0)
            else $error("Ready stays high after enable");

        //check that all the outputs in the state are correct
        assert(a4.en_ksa == 1'b0) 
            else $error("Enabled ksa when it shouldn't have");
        assert(a4.en_init == 1'b0) 
            else $error("Enabled en_init when it shouldn't have");
        
        //We wait until we are out of the PRGA state
        while(A4_STATE == `IN_PRGA) begin
            @(negedge TB_CLK); //wait until out of the init state
        end

        //compute if we have the correct output
        j = 0;
        i = 0;
        for(k = 1; k <= ct.altsyncram_component.m_default.altsyncram_inst.mem_data[0]; k++) begin
            i = (i + 1) % 256;
            j = (j + test_s[i]) % 256;
            tmp = test_s[i];
            test_s[i] = test_s[j];
            test_s[j] = tmp;

            plain_test[k] = test_s[(test_s[i] + test_s[j]) % 256] ^ ct.altsyncram_component.m_default.altsyncram_inst.mem_data[k];
        
            assert(plain_test[k] == pt.altsyncram_component.m_default.altsyncram_inst.mem_data[k])
                else $error("The plain text doesn't match the actual for %d, as it is %d instead of %d", k, pt.altsyncram_component.m_default.altsyncram_inst.mem_data[k], plain_test[k]);
        end

        //at this point we successfully done the cipher


        //checks for the state transition in the KSA state, along with the wires being high
        assert(A4_STATE == `READY)
            else $error("Not back to ready state");

        assert(rdy_arc4 == 1'b1)
            else $error("Ready should be high after enable");

        //once ready, we should be able to enable again, with no reset
        key = 24'h1245ab; // set an arbitrary value for the key

        test_k[0] = key[23:16];
        test_k[1] = key[15:8];
        test_k[2] = key[7:0];

        //reset
        @(negedge TB_CLK); //rst_n = 1'b0;
        @(negedge TB_CLK); //rst_n = 1'b1;

        //enables the module
        @(negedge TB_CLK) en_arc4 = 1'b1;

        @(negedge TB_CLK) en_arc4 = 1'b0;

        //check that we are no longer in the ready state
        assert(A4_STATE == `ENABLE_INIT)
            else $error("ARC4 state is not ENABLE_INIT");

        repeat (5) begin
            @(negedge TB_CLK); //
        end

        //wait until everything is done
        while(~(A4_STATE == `ENABLE_KSA)) begin
            @(negedge TB_CLK);
        end

        //We check the memory for the correct filled values of s
        for(i = 0; i < 256; i++) begin
            test_s[i] = i;
            assert(a4.s.altsyncram_component.m_default.altsyncram_inst.mem_data[i] == i)
                else $error("Second run: The S ram was not filled with the correct value for %d, it is %d", i, a4.s.altsyncram_component.m_default.altsyncram_inst.mem_data[i]);
        end

        repeat (5) begin
            @(negedge TB_CLK); //
        end

        //wait until everything is done
        while((A4_STATE == `IN_KSA)) begin
            @(negedge TB_CLK);
        end

        j = 0;
        for(i = 0; i < 256; i++) begin
            j = (j + test_s[i] + test_k[i % 3]) % 256;
            tmp = test_s[i];
            test_s[i] = test_s[j];
            test_s[j] = tmp;
        end

        for(i = 0; i < 256; i++) begin
            assert(a4.s.altsyncram_component.m_default.altsyncram_inst.mem_data[i] == test_s[i])
                else $error("The KSA-level S ram was not filled with the correct value for %d, it is %d instead of %d", i, a4.s.altsyncram_component.m_default.altsyncram_inst.mem_data[i], test_s[i]);

        end

        //wait until everything is done
        while(~(A4_STATE == `READY)) begin
            @(negedge TB_CLK);
        end

        j = 0;
        i = 0;
        for(k = 1; k <= ct.altsyncram_component.m_default.altsyncram_inst.mem_data[0]; k++) begin
            i = (i + 1) % 256;
            j = (j + test_s[i]) % 256;
            tmp = test_s[i];
            test_s[i] = test_s[j];
            test_s[j] = tmp;

            plain_test[k] = test_s[(test_s[i] + test_s[j]) % 256] ^ ct.altsyncram_component.m_default.altsyncram_inst.mem_data[k];
        
            assert(plain_test[k] == pt.altsyncram_component.m_default.altsyncram_inst.mem_data[k])
                else $error("The plain text doesn't match the actual for %d, as it is %d instead of %d", k, pt.altsyncram_component.m_default.altsyncram_inst.mem_data[k], plain_test[k]);
        end

        

        
        $display("If no errors were displayed, then everything worked correctly!");
        
        $stop;


    end

    

endmodule: tb_rtl_arc4
