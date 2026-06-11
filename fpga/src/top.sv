`include "src/sd_card.sv"
`include "src/dac.sv"
`include "src/divider.sv"
// `include "src/clk.v"

module top (
    input wire clk, 
    output wire sd_sck,
    input wire sd_poci, // SD card data input
    output wire sd_pico, // SD card data output
    output wire sd_cs, // SD card chip select

    output wire pico_sck, // Pi Pico sck
    input wire pico_poci, // Pi pico data input
    output wire pico_pico, // Pi pico data output

    output spi_module_status status,

    output logic DATAOUT,
    output logic DAC_CLK,
    output logic DAC_LRC
);


logic[31:0] block_addr = 0;
wire[511:0] block_data;
sd_card card_controller (
    .clk(clk),
    .block_addr(block_addr),
    .status(status),
    .sck(sd_sck),
    .poci(sd_poci),
    .pico(sd_pico),
    .cs(sd_cs)
);

logic start_tx = 0;
wire transmitting;
logic[3:0] num_bytes = 4;
logic[63:0] tx_data = 0;
wire[63:0] rx_data;
spi_controller pico_spi_controller (
    .clk(clk),
    .start_tx(start_tx),
    .transmitting(transmitting),
    .num_bytes(num_bytes),
    .tx_data(tx_data),
    .rx_data(rx_data),
    .sck(pico_sck),
    .poci(pico_poci),
    .pico(pico_pico)
);

/** Logic */
logic clk512;
logic clkdiv;

// pll clk5120(
//     .clkin(clk),
//     .clkout0(clk512)
// );

divider divider(
    .pclk(clk512),
    .clkout(clkdiv)
);

dac dac1 (
    .pclk(clkdiv),
    .dataOut(DATAOUT),
    .lrOut(DAC_LRC)
);

assign DAC_CLK = clkdiv;


always @(posedge clk) begin
    // Transmit the same data over and over again over SPI
    if (!transmitting) begin
        if (status == IDLE) begin
            num_bytes = 2;
            tx_data = 'b1111000011110000;
        end
        else if (status == ERROR_RETRYING) begin
            num_bytes = 1;
            tx_data = 'b11001100;
        end
        else if (status == INITIALIZING) begin
            num_bytes = 1;
            tx_data = 'b10101010;
        end
        else begin // READING_BLOCK
            num_bytes = 3;
            tx_data = 'b111000111000111000111000;
        end

        start_tx = ~start_tx;
    end
end

endmodule