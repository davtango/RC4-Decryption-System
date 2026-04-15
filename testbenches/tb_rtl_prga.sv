
`define READY 3'b000
`define ML_PT 3'b001 
`define READ_I 3'b010 
`define READ_J 3'b011
`define WRITE_I 3'b100 
`define WRITE_J 3'b101 
`define READ_PAD 3'b110 
`define WRITE_PT 3'b111 


`timescale 1ps / 1ps
module tb_rtl_prga();

    // Logic Instantiations
    logic clk, rst_n;

    logic [7:0] s_addr_prga;
    logic [7:0] s_wrdata_prga;
    logic s_wren_prga, ct_wren, pt_wren_prga;

    logic [7:0] s_rddata; // driven only by S block, shared as input by init, p, and prga

    // for CT, PT blocks (mainly for prga)

    logic [7:0] ct_addr_prga, ct_data, ct_rddata;
    logic [7:0] pt_addr_prga;
    logic [7:0] pt_wrdata_prga, pt_rddata;

    logic [23:0] key;

    // Ready and Enable Signals

    logic rdy_prga;
    logic en_prga;

    s_mem s( .address(s_addr_prga), .clock(clk), .data(s_wrdata_prga), .wren(s_wren_prga), .q(s_rddata));
    ct_mem ct( .address(ct_addr_prga), .clock(clk), .data(ct_data), .wren(ct_wren), .q(ct_rddata));
    pt_mem pt( .address(pt_addr_prga), .clock(clk), .data(pt_wrdata_prga), .wren(pt_wren_prga), .q(pt_rddata));

    prga p( .clk(clk), .rst_n(rst_n), .en(en_prga), .rdy(rdy_prga), .key(key), .s_addr(s_addr_prga), .s_rddata(s_rddata), .s_wrdata(s_wrdata_prga), .s_wren(s_wren_prga),
            .ct_addr(ct_addr_prga), .ct_rddata(ct_rddata),
            .pt_addr(pt_addr_prga), .pt_rddata(pt_rddata), .pt_wrdata(pt_wrdata_prga), .pt_wren(pt_wren_prga));

    
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
    int k;

    initial begin

        //resets the module
        en_prga = 1'b0;
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

        while(~rdy_prga) begin
            //wait for ready
        end

        //check that we begin in the ready state
        assert(p.present_state == `READY)
            else $error("prga state is not READY");


        #20;
        //writes to the cipher text memory so we can convert it
        $readmemh("test1.memh", ct.altsyncram_component.m_default.altsyncram_inst.mem_data);


        //We now activate the module and see how well it works

        //check that we begin in the ready state
        assert(p.present_state == `READY)
            else $error("prga state is not READY");

        assert(rdy_prga == 1'b1)
            else $error("prga state is not READY");   

        //enables the module
        @(negedge clk) en_prga = 1'b1;

        @(negedge clk) en_prga = 1'b0;

        //check that we are no longer in the ready state
        assert(p.present_state == `ML_PT)
            else $error("prga state is not ML_PT");

        assert(rdy_prga == 1'b0)
            else $error("ready did not go low");

        //we do some white box testing for if we goes in the correct loop

        @(negedge clk);
        assert(p.present_state == `READ_I)
            else $error("prga state is not READ_I");
        
        @(negedge clk);
        assert(p.present_state == `READ_J)
            else $error("prga state is not READ_J");

        @(negedge clk);
        assert(p.present_state == `WRITE_I)
            else $error("prga state is not WRITE_I");

        @(negedge clk);
        assert(p.present_state == `WRITE_J)
            else $error("prga state is not WRITE_J");

        @(negedge clk);
        assert(p.present_state == `READ_PAD)
            else $error("prga state is not READ_PAD");

        @(negedge clk);
        assert(p.present_state == `WRITE_PT)
            else $error("prga state is not WRITE_PT");    
        
        //if no errors then we are looping correctly

        while(~(p.present_state == `READY)) begin
            @(negedge clk);
        end

        //we should be out now

        assert(p.present_state == `READY)
            else $error("prga state is not back to READY");  

        assert(rdy_prga == 1'b1)
            else $error("rdy_prga is not set back to high");  

        j = 0;
        i = 0;
        for(k = 1; k <= ct.altsyncram_component.m_default.altsyncram_inst.mem_data[0]; k++) begin
            i = (i + 1) % 256;
            j = (j + test_s[i]) % 256;
            tmp = test_s[i];
            test_s[i] = test_s[j];
            test_s[j] = tmp;

            tmp = test_s[(test_s[i] + test_s[j]) % 256] ^ ct.altsyncram_component.m_default.altsyncram_inst.mem_data[k];

            assert(tmp == pt.altsyncram_component.m_default.altsyncram_inst.mem_data[k])
                else $error("The plain text doesn't match the actual for %d, as it is %d instead of %d", k, pt.altsyncram_component.m_default.altsyncram_inst.mem_data[k], tmp);
        end

        //Now we can try running through it again

        @(negedge clk) //rst_n = 1'b0;

        @(negedge clk) //rst_n = 1'b1;

        //enables the module
        @(negedge clk) en_prga = 1'b1;

        @(negedge clk) en_prga = 1'b0;

        //check that we are no longer in the ready state
        assert(p.present_state == `ML_PT)
            else $error("2nd time: prga state is not ML_PT");

        assert(rdy_prga == 1'b0)
            else $error("2nd time: ready did not go low");

        while(~(p.present_state == `READY)) begin
            @(negedge clk);
        end

        //we should be out now

        assert(p.present_state == `READY)
            else $error("prga state is not back to READY");  

        assert(rdy_prga == 1'b1)
            else $error("rdy_prga is not set back to high");  

        j = 0;
        i = 0;
        for(k = 1; k <= ct.altsyncram_component.m_default.altsyncram_inst.mem_data[0]; k++) begin
            i = (i + 1) % 256;
            j = (j + test_s[i]) % 256;
            tmp = test_s[i];
            test_s[i] = test_s[j];
            test_s[j] = tmp;

            tmp = test_s[(test_s[i] + test_s[j]) % 256] ^ ct.altsyncram_component.m_default.altsyncram_inst.mem_data[k];

            assert(tmp == pt.altsyncram_component.m_default.altsyncram_inst.mem_data[k])
                else $error("Second time The plain text doesn't match the actual for %d, as it is %d instead of %d", k, pt.altsyncram_component.m_default.altsyncram_inst.mem_data[k], tmp);
        end


        $display("If no errors for second run, then the rdy - enable protocol worked!");
        $display("If no errors were displayed, then everything worked correctly!");
        $stop;
    end

endmodule: tb_rtl_prga
