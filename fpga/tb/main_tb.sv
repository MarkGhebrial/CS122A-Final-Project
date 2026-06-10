`include "src/main.sv"
`timescale 1ns/1ps

module main_tb;

logic clk = 0;
logic en = 1;
wire sd_sck;
logic sd_poci = 0;
wire sd_pico;
wire sd_cs;
wire pico_sck;
wire pico_pico;

// Unit under test
main uut
(
    .clk(clk),
    .en(en),
    .sd_sck(sd_sck),
    .sd_poci(sd_poci),
    .sd_pico(sd_pico),
    .sd_cs(sd_cs),
    .pico_sck(pico_sck),
    .pico_pico(pico_pico)
);

// File descriptor for sd card data capture file
int fd = 0;
int sample;
int counter = 0;
int failures = 0;
// Whether or not there are more samples in the waveform file to take
int more_samples = 1;
always begin 
    #1;
    clk =~ clk;
end

initial begin
    $dumpfile("build/main.vcd");
    $dumpvars(0, main_tb);

    fd = $fopen("tb/sd_card_tb_capture.bin", "r");

    $display("Processing... Hang tight.");

    // Read the first two samples
    $fgetc(fd); sample = $fgetc(fd);
    sd_poci = sample[1];

    // Wait a bunch of cycles before ending the simulation
    #(2 * 33000);
    if (failures == 0) begin
        $display("Test PASSED!");
    end
    else begin
        $display("Test FAILED with ", failures, " failures.");
    end
    $fclose(fd);
    $finish();
end

always @(posedge sd_sck) begin
    if (!$feof(fd)) begin
        // Verify that the sd card controller is sending the right data on the SPI bus
        if (sample[2] != sd_pico) begin
            $display("incorrect pico signal at sck tick ", counter);
            failures = failures + 1;
        end
        if (sample[3] != sd_cs) begin
            $display("incorrect cs signal at the ", counter, "th sck tick");
            failures = failures + 1;
        end

        // Read the next sample from the file
        sample = $fgetc(fd);
    end

    // Keep track of the number of SCK rising edges
    counter = counter + 1;
end

// Update MISO on falling sck edges
always @(negedge sd_sck) begin
    sd_poci = sample[1];
end

endmodule
