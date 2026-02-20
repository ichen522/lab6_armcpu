`timescale 1ns/100ps

module tb_pipelinepc();

    reg clk;
    reg rstb;

    //--------------------------------------------------
    // Instantiate DUT
    //--------------------------------------------------
    pipelinepc uut (
        .clk(clk),
        .rstb(rstb)
    );

    //--------------------------------------------------
    // Clock generation (10ns period)
    //--------------------------------------------------
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    //--------------------------------------------------
    // Waveform dump
    //--------------------------------------------------
    initial begin
        $dumpfile("sim.vcd");
        $dumpvars(0, tb_pipelinepc);
    end

    //--------------------------------------------------
    // Reset and simulation control
    //--------------------------------------------------
    initial begin
        rstb = 0;
        #20;
        rstb = 1;

        // Run long enough for bubble sort
        #3000;

        $display("=======================================");
        $display("Simulation finished. Dumping memory...");
        $display("=======================================");

        // Dump Data Memory
        $writememh("data_dump.hex", uut.DMem.dmem);

        $finish;
    end

    //--------------------------------------------------
    // Debug print: show PC and instruction
    //--------------------------------------------------
    always @(posedge clk) begin
        if (rstb) begin
            $display("TIME=%0t | Thread=%0d | PC=%0h | INST=%0h",
                     $time,
                     uut.thread_id_reg,
                     uut.PC.current_pc,
                     uut.IMEM.inst);
        end
    end

endmodule