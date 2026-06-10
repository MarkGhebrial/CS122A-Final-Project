`include "src/sd_card.sv"
`include "src/spi_controller.sv"

// TODO: Come up with a better name for this
module communicator (
    input wire clk,

    // I/O for talking to the sd card module
    output logic[31:0] block_addr = 0,
    input wire[511:0][7:0] block_data,
    input sd_module_status status,

    // SPI output pins
    output wire sck,
    output wire pico
);

logic start_tx = 0;
logic [4095:0] tx_data;
wire transmitting;
// logic[4095:0] tx;
spi_controller #(
    .MAX_NUM_BYTES(512)
) spi (
    .clk(clk),
    .start_tx(start_tx),
    .transmitting(transmitting),
    .num_bytes(10'd512),
    .tx_data(tx_data),
    .sck(sck),
    .pico(pico)
);

typedef enum logic[1:0] {
    WAITING_FOR_SD_BLOCK_READ_TO_FINISH = 0,
    WAITING_FOR_SPI_TRANSMISSION_TO_END = 2
} communicator_state;

communicator_state state = WAITING_FOR_SD_BLOCK_READ_TO_FINISH;

always @(posedge clk) begin
    case (state)
        WAITING_FOR_SD_BLOCK_READ_TO_FINISH: begin
            if (status == IDLE) begin
                state <= WAITING_FOR_SPI_TRANSMISSION_TO_END;
                // Start transmitting the block over spi
                tx_data <= block_data;
                start_tx <= ~start_tx;
                // Tell the sd card module to start reading the next block
                block_addr <= block_addr + 1;
            end
        end
        WAITING_FOR_SPI_TRANSMISSION_TO_END: begin
            if (!transmitting) begin
                // We already initialized the next sd card block read
                state <= WAITING_FOR_SD_BLOCK_READ_TO_FINISH;
            end
        end
    endcase
end

endmodule