`include "src/sd_card.sv"
`timescale 1ns/1ps

module top_tb;

logic clk = 0;

wire sd_sck;
logic sd_poci = 0; // SD card data input. We use a capture of a successful sd card read to emulate the sd card's behavior
wire sd_pico; // SD card data output
wire sd_cs; // SD card chip select

// Unit under test
wire start_tx;
wire transmitting;
wire[3:0] num_bytes;
wire[63:0] tx_data;
wire[63:0] rx_data;
spi_controller spi (
    .clk(clk),
    .start_tx(start_tx),
    .transmitting(transmitting),
    .num_bytes(num_bytes),
    .tx_data(tx_data),
    .rx_data(rx_data),
    .sck(sd_sck),
    .poci(sd_poci),
    .pico(sd_pico)
);

logic[31:0] block_addr = 0;
wire[511:0][7:0] block_data;
sd_module_status status;
sd_module_state state;
sd_card uut (
    .clk(clk),
    .block_addr(block_addr),
    .block_data(block_data),
    .status(status),
    .state(state),
    .start_tx(start_tx),
    .spi_transmitting(transmitting),
    .num_bytes(num_bytes),
    .tx_data(tx_data),
    .rx_data(rx_data),
    .cs(sd_cs)
);

// File descriptor for sd card data capture file
int fd = 0;
int sample;
int counter = 0;
int failures = 0;
always begin 
    #1;
    clk =~ clk;
end

initial begin
    $dumpfile("build/sd_card.vcd");
    $dumpvars(0, top_tb);

    fd = $fopen("tb/sd_card_tb_capture.bin", "r");

    $display("Processing... Hang tight.");

    // Read the first two samples
    $fgetc(fd); sample = $fgetc(fd);
    sd_poci = sample[1];
end

always @(posedge sd_sck) begin
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
    if ($feof(fd)) begin
        // Verify that the data in the block data register is correct
        for (int i = 0; i < 512; i = i + 1) begin
            if (block_data[i] != 255 - (i % 256)) begin
                $display("Incorrect data in block data register at index ", i, "; Expected ", 255 - (i % 256), ", found ", block_data[i]);
                failures = failures + 1;
            end
        end

        if (failures == 0) begin
            $display("Test PASSED!");
        end
        else begin
            $display("Test FAILED with ", failures, " failures.");
        end

        $fclose(fd);
        $finish();
    end

    // Keep track of the number of SCK rising edges
    counter = counter + 1;
end

// Update MISO on falling sck edges
always @(negedge sd_sck) begin
    sd_poci = sample[1];
end

endmodule
