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
int ch;
always begin 
    #1;
    clk =~ clk;
end

initial begin
    $dumpfile("build/sd_card.vcd");
    $dumpvars(0, top_tb);

    fd = $fopen("tb/sd_card_tb_capture.bin", "r");

    $display("Processing... Hang tight.");

    $fgetc(fd);
    // if ($feof(fd)) begin
    //     $fclose(fd);
    //     $finish();
    // end
    // sd_poci = ch[1];
    ch = $fgetc(fd);
    if ($feof(fd)) begin
        $fclose(fd);
        $finish();
    end
    sd_poci = ch[1];
end

// Update MISO on falling sck edges
always @(negedge sd_sck) begin
    ch = $fgetc(fd);

    if ($feof(fd)) begin
        $fclose(fd);
        $finish();
    end

    sd_poci = ch[1];
end

endmodule
