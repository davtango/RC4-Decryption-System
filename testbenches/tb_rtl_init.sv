`define READY 1'b0
`define INITIALIZING 1'b1

`timescale 1ps / 1ps

module tb_rtl_init();

    // Logic Instantiations
    logic clk, rst_n, en, rdy;
    logic [7:0] addr, wrdata, s_rddata;
    logic wren;

    s_mem s( .address(addr), .clock(clk), .data(wrdata), .wren(wren), .q(s_rddata));
    init init( .clk(clk), .rst_n(rst_n), .en(en), .rdy(rdy), .addr(addr), .wrdata(wrdata), .wren(wren));


    
    initial begin 
        forever begin 
            #10;
            clk = 1'b0;
            #10;
            clk = 1'b1;
        end
    end

    int i;

    initial begin

        @(negedge clk) rst_n = 1'b0;
        @(negedge clk) rst_n = 1'b1;

        //check that we are in the ready state
        assert(init.present_state == `READY)
            else $error("Doesn't start in ready state");

        assert(init.rdy == 1'b1)
            else $error("Doesn't have ready high");

        @(negedge clk) en = 1;
        @(negedge clk) en = 0;

        assert(init.present_state == `INITIALIZING)
            else $error("Doesn't move to initializing state");

        assert(init.rdy == 1'b0)
            else $error("Error: Didn't set ready to low");


        //wait in here until done initializing
        while(init.present_state == `INITIALIZING) begin
            @(negedge clk); 
        end

        //done process
        for(i = 0; i < 256; i++) begin
            assert(s.altsyncram_component.m_default.altsyncram_inst.mem_data[i] == i)
                else $error("Value at %d is %d", i, s.altsyncram_component.m_default.altsyncram_inst.mem_data[i]);
        end


        //We can now run through it again

        //We should now be back in ready state
        assert(init.present_state == `READY)
            else $error("Doesn't start in ready state");

        assert(init.rdy == 1'b1)
            else $error("Doesn't have ready high");


        @(negedge clk) en = 1;
        @(negedge clk) en = 0;

        assert(init.present_state == `INITIALIZING)
            else $error("Doesn't move to initializing state");

        assert(init.rdy == 1'b0)
            else $error("Error: Didn't set ready to low");


        //wait in here until done initializing
        while(init.present_state == `INITIALIZING) begin
            @(negedge clk); 
        end

        //done process
        for(i = 0; i < 256; i++) begin
            assert(s.altsyncram_component.m_default.altsyncram_inst.mem_data[i] == i)
                else $error("Value at %d is %d", i, s.altsyncram_component.m_default.altsyncram_inst.mem_data[i]);
        end

        
        
        
        $display("If no errors for second run, then the rdy - enable protocol worked!");
        $display("If no errors were displayed, then everything worked correctly!");
        $stop;
    end

endmodule: tb_rtl_init
