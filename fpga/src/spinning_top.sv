`include "src/spi_controller.sv"

module spinning_top (
    input wire clk, 
    // output wire sd_sck,
    // input wire sd_poci, // SD card data input
    // output wire sd_pico, // SD card data output
    // output wire sd_cs, // SD card chip select

    output wire pico_sck, // Pi Pico sck
    input wire pico_poci, // Pi pico data input
    output wire pico_pico // Pi pico data output
);

logic pico_start_tx = 0;
wire pico_xmitting;
logic[2:0] pico_num_bytes = 8;
logic[63:0] pico_tx_data = 0;
wire[63:0] pico_rx_data;
spi_controller pico_controller (
    .clk(clk),
    .start_tx(pico_start_tx),
    .transmitting(pico_xmitting),
    .num_bytes(pico_num_bytes),
    .tx_data(pico_tx_data),
    .rx_data(pico_rx_data),
    .sck(pico_sck),
    .poci(pico_poci),
    .pico(pico_pico)
);


logic[15:0] counter = 20000;

always @(posedge clk) begin
    // Wait a bit before 
    if (counter != 0) begin
        counter <= counter - 1;
    end
    else begin
        if (!pico_xmitting) begin
            pico_tx_data <= 'hAAAAAA;
            pico_num_bytes <= 3;
            pico_start_tx <= ~pico_start_tx;
        end
    end
end

endmodule