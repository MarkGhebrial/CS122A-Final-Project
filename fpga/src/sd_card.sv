`include "src/spi_controller.sv"
`default_nettype none

/*
SD card SPI command format:
MSB |  "01", 6-bit command index
    |  MSB | 32-bit command argument
    |      | 
    |      |
    |  LSB v
LSB v  7-bit CRC checksum, "1"
*/
`define SPI_COMMAND(COMMAND_INDEX, COMMAND_ARGUMENT, CRC=0) \
    (8'b01000000 | COMMAND_INDEX) << (5*8) | \
    (COMMAND_ARGUMENT << 8) | \
    ((CRC << 1) | 1'b1)

`define SPI_BEGIN_TRANSFER(NUM_BYTES, DATA) \
    start_tx <= ~start_tx; \
    num_bytes <= NUM_BYTES; \
    tx_data <= DATA;

`define RESET_STATE_MACHINE \
    state <= START_STATE; \
    status <= ERROR_RETRYING; \
    counter <= 0;

typedef enum logic[1:0] {
    // The module is going through the initialization routine for the first time
    INITIALIZING = 0,
    // An error was encountered and the module is retrying the initialization routine
    ERROR_RETRYING = 1,
    // The module is reading a block
    READING_BLOCK = 2,
    // The module is done reading the block and is currently doing nothing
    IDLE = 3
} sd_module_status;

typedef enum logic[4:0] {
    /** BEGIN CARD INITIALIZATION STATES **/
    // Start state
    START_STATE = 0,
    // Sending "dummy cycles" with CS high
    DUMMY_CYCLE_STATE = 1,

    // Waiting for CMD0 transmission
    CMD0_SEND_STATE = 2,
    // Waiting for CMD0 reply
    CMD0_RCV_STATE = 3,

    // Waiting for CMD8 transmission
    CMD8_SEND_STATE = 4,
    // Waiting for CMD8 reply
    CMD8_RCV_STATE0 = 5,
    CMD8_RCV_STATE1 = 6,

    // Waiting for CMD55 transmission
    CMD55_SEND_STATE = 7,
    // Waiting for CMD55 reply
    CMD55_RCV_STATE = 8,
    // Waiting for CMD41 transmission
    CMD41_SEND_STATE = 9,
    // Waiting for CMD41 reply
    CMD41_RCV_STATE  = 10,

    // // Waiting for CMD58 transmission
    CMD58_SEND_STATE = 11,
    // // Waiting for CMD58 reply
    CMD58_RCV_STATE0 = 12,
    CMD58_RCV_STATE1 = 13,

    // Waiting for CMD16 transmission
    CMD16_SEND_STATE = 14,
    // Waiting for CMD16 reply
    CMD16_RCV_STATE = 15,
    /** END CARD INITIALIZATION STATES **/

    /** BEGIN BLOCK READ STATES **/
    // Waiting for CMD17 transmission
    CMD17_SEND_STATE = 16,
    // Waiting for CMD17 reply
    CMD17_RCV_STATE = 17,
    // Reading bytes from the block
    BLOCK_READ_STATE = 18,
    // Reading checksum at end of block
    CHECKSUM_READ_STATE = 19,
    /** END BLOCK READ STATES **/

    // Waiting for block_addr to change
    IDLE_STATE = 20
} sd_module_state;

module sd_card(
    // Clock source
    input wire clk,

    // The address of the block to read from
    input wire[31:0] block_addr,
    output logic[511:0] block_data,
    
    // The status of the module
    output sd_module_status status = INITIALIZING,
    output sd_module_state state = START_STATE,

    // TODO: Rename these so that they're prefixed with "_spi"
    output logic start_tx = 0,
    input wire spi_transmitting,
    output logic[3:0] num_bytes,
    output logic[63:0] tx_data = 0,
    input wire[63:0] rx_data,

    output logic cs = 0
);

// A register used by the state machine for counting the number of cycles spent in the current state
logic[7:0] counter = 0;

// sd_module_state state = START_STATE;
logic[31:0] prev_block_addr = 0;

always @(posedge clk) begin
    case (state)
        START_STATE: begin
            // Send eight bytes of 0xFF with cs inactive
            cs <= 1;
            `SPI_BEGIN_TRANSFER(8, ~64'b0);
            // Unconditionally go to the next state
            state <= DUMMY_CYCLE_STATE;
        end
        DUMMY_CYCLE_STATE: begin
            // Wait until the SPI data transfer is over
            if (!spi_transmitting) begin
                // Go to the next state
                state <= CMD0_SEND_STATE;
                cs <= 0;
                `SPI_BEGIN_TRANSFER(6, `SPI_COMMAND(0, 0, 7'b1001010));
            end
        end
        CMD0_SEND_STATE: begin
            // Wait until the SPI data transfer is over
            if (!spi_transmitting) begin
                state <= CMD0_RCV_STATE;
                // Transfer 0xFF so we can read the response from the card
                `SPI_BEGIN_TRANSFER(1, 'hFF);
            end
        end
        CMD0_RCV_STATE: begin
            if (!spi_transmitting) begin
                // We haven't received a response yet, so transfer another byte
                if (rx_data == 'hFF) begin
                    if (counter < 16) begin
                        // Read another byte
                        `SPI_BEGIN_TRANSFER(1, 'hFF);
                        counter <= counter + 1;
                    end
                    else begin
                        // Give up
                        `RESET_STATE_MACHINE;
                    end
                end
                else begin
                    // Go to the next state
                    state <= CMD8_SEND_STATE;
                    counter <= 0;
                    // Start transmitting CMD8
                    `SPI_BEGIN_TRANSFER(6, `SPI_COMMAND(8, 'h1AA, 7'b1000011));
                end
            end
        end

        CMD8_SEND_STATE: begin
            // Wait until CMD8 is done transmitting
            if (!spi_transmitting) begin
                state <= CMD8_RCV_STATE0;
                `SPI_BEGIN_TRANSFER(1, 'hFF);
            end
        end
        // Receiving the first byte of the CMD8 response
        CMD8_RCV_STATE0: begin
            if (!spi_transmitting) begin
                // We haven't received a response yet, so stay in this state and transfer another byte
                if (rx_data == 'hFF) begin
                    if (counter < 16) begin
                        `SPI_BEGIN_TRANSFER(1, 'hFF);
                        counter <= counter + 1;
                    end else begin
                        `RESET_STATE_MACHINE;
                    end
                end
                else begin
                    // Go to the next state
                    state <= CMD8_RCV_STATE1;
                    counter <= 0;
                    // Begin reading the next 32 bits of the response
                    `SPI_BEGIN_TRANSFER(4, 'hFFFFFFFF);
                end
            end
        end
        // Receiving the last 4 bytes of the CMD8 response
        CMD8_RCV_STATE1: begin
            // If we're done reading the rest of the CMD8 response...
            if (!spi_transmitting) begin
                /// ...verify that the response is correct...
                if (rx_data == 'h1AA) begin
                    // ... and go to the next state
                    `SPI_BEGIN_TRANSFER(6, `SPI_COMMAND(55, 0))
                    state <= CMD55_SEND_STATE;
                end
                else begin
                    `RESET_STATE_MACHINE;
                end
            end
        end

        CMD55_SEND_STATE: begin
            // Wait until the transfer of CMD55 finishes, then start reading the reply
            if (!spi_transmitting) begin
                state <= CMD55_RCV_STATE;
                `SPI_BEGIN_TRANSFER(1, 'hFF);
            end
        end
        CMD55_RCV_STATE: begin
            if (!spi_transmitting) begin
                // We haven't received a response yet, so transfer another byte
                if (rx_data == 'hFF) begin
                    if (counter < 16) begin
                        `SPI_BEGIN_TRANSFER(1, 'hFF);
                        counter <= counter + 1;
                    end else begin
                        `RESET_STATE_MACHINE;
                    end
                end
                else begin
                    // Go to the next state
                    state <= CMD41_SEND_STATE;
                    counter <= 0;
                    `SPI_BEGIN_TRANSFER(6, `SPI_COMMAND(41, 'h40000000));
                end
            end
        end
        CMD41_SEND_STATE: begin
            // Wait until the transfer of CMD41 finishes, then start reading the reply
            if (!spi_transmitting) begin
                `SPI_BEGIN_TRANSFER(1, 'hFF);
                state <= CMD41_RCV_STATE;
            end
        end
        CMD41_RCV_STATE: begin
            if (!spi_transmitting) begin
                // 1st case: MSB of the byte is 1. Since all SD card SPI responses start with 0, this means we haven't received a response yet and need to transfer another byte.
                if (rx_data & (1 << 7)) begin
                    if (counter < 16) begin
                        counter <= counter + 1;
                        `SPI_BEGIN_TRANSFER(1, 'hFF);
                    end else begin
                        `RESET_STATE_MACHINE;
                    end
                end
                // 2nd case: We got a response from the card, but the card is still in idle mode. We have to resend CMD55
                else if (rx_data == 'h01) begin
                    // Send CMD55 again
                    `SPI_BEGIN_TRANSFER(6, `SPI_COMMAND(55, 0))
                    state <= CMD55_SEND_STATE;
                    counter <= 0;
                end
                // 3rd case: We got a response from the card and the card is no longer in idle mode. We can move onto the next state
                else if (rx_data == 'h00) begin
                    // Go send CMD58
                    `SPI_BEGIN_TRANSFER(6, `SPI_COMMAND(58, 0));
                    state <= CMD58_SEND_STATE;
                    counter <= 0;
                end
                // 4th case: Error response. Reset the state machine
                else begin
                    `RESET_STATE_MACHINE;
                end
            end
        end

        CMD58_SEND_STATE: begin
            // Wait until CMD58 is done transmitting
            if (!spi_transmitting) begin
                state <= CMD58_RCV_STATE0;
                `SPI_BEGIN_TRANSFER(1, 'hFF);
            end
        end
        // Receiving the first byte of the CMD8 response
        CMD58_RCV_STATE0: begin
            if (!spi_transmitting) begin
                // We haven't received a response yet, so transfer another byte
                if (rx_data & (1 << 7)) begin
                    if (counter < 16) begin
                        `SPI_BEGIN_TRANSFER(1, 'hFF);
                        counter <= counter + 1;
                    end else begin
                        `RESET_STATE_MACHINE;
                    end
                end
                else begin
                    // Go to the next state
                    state <= CMD58_RCV_STATE1;
                    counter <= 0;
                    // Begin reading the next 32 bits of the response
                    `SPI_BEGIN_TRANSFER(4, 'hFFFFFFFF);
                end
            end
        end
        // Receiving the last 4 bytes of the CMD58 response
        CMD58_RCV_STATE1: begin
            // If we're done reading the rest of the CMD58 response...
            if (!spi_transmitting) begin
                /// ...decide which state to go to next based off of the CCS bit in the response
                if (rx_data[30]) begin // TODO: This should be inverted
                    `SPI_BEGIN_TRANSFER(6, `SPI_COMMAND(16, 'h200));
                    state <= CMD16_SEND_STATE;
                end
                else begin
                    state <= CMD17_SEND_STATE;
                    status <= READING_BLOCK;
                    `SPI_BEGIN_TRANSFER(6, `SPI_COMMAND(17, block_addr));
                end
            end
        end

        CMD16_SEND_STATE: begin
            // Wait for the transfer to finish
            if (!spi_transmitting) begin
                `SPI_BEGIN_TRANSFER(1, 'hFF);
                state <= CMD16_RCV_STATE;
            end
        end
        CMD16_RCV_STATE: begin
            if (!spi_transmitting) begin
                // If the MSB of the data is 1, read another byte
                if (rx_data & (1 << 7)) begin
                    if (counter < 16) begin
                        counter <= counter + 1;
                        `SPI_BEGIN_TRANSFER(1, 'hFF);
                    end else begin
                        `RESET_STATE_MACHINE;
                    end
                end
                else begin
                    state <= CMD17_SEND_STATE;
                    status <= READING_BLOCK;
                    counter <= 0;
                    `SPI_BEGIN_TRANSFER(6, `SPI_COMMAND(17, block_addr));
                end
            end
        end

        // We are actively sending CMD17
        CMD17_SEND_STATE: begin
            if (!spi_transmitting) begin
                `SPI_BEGIN_TRANSFER(1, 'hFF);
                state <= CMD17_RCV_STATE;
            end
        end
        // We are waiting for the CMD17 response
        CMD17_RCV_STATE: begin
            if (!spi_transmitting) begin
                // We haven't received a response yet, so transfer another byte
                if (rx_data == 'hFF) begin
                    if (counter < 16) begin
                        `SPI_BEGIN_TRANSFER(1, 'hFF);
                        counter <= counter + 1;
                    end else begin
                        `RESET_STATE_MACHINE;
                    end
                end
                else begin
                    // Go to the next state
                    state <= BLOCK_READ_STATE;
                    counter <= 0;
                    `SPI_BEGIN_TRANSFER(8, ~64'b0);
                end
            end
        end
        // We are reading the block data
        BLOCK_READ_STATE: begin
            if (!spi_transmitting) begin
                if (counter < 8) begin
                    // Shift the received data into the block_data register
                    block_data <= { block_data[447:0], rx_data };
                    counter <= counter + 1;
                    `SPI_BEGIN_TRANSFER(8, ~64'b0);
                end
                else begin
                    counter <= 0;
                    state <= CHECKSUM_READ_STATE;
                    // Begin reading the two checksum bytes
                    `SPI_BEGIN_TRANSFER(2, 'hFFFF);
                end
            end
        end
        CHECKSUM_READ_STATE: begin
            if (!spi_transmitting) begin
                // Don't verify the checksum, just go straight to the idle state
                state <= IDLE_STATE;
                status <= IDLE;
            end
        end

        // We're done reading the block and can chill until the requested block address changes
        IDLE_STATE: begin
            // Wait for block_addr to change
            if (prev_block_addr != block_addr) begin
                state <= CMD17_SEND_STATE;
                status <= READING_BLOCK;
                counter <= 0;
                `SPI_BEGIN_TRANSFER(6, `SPI_COMMAND(17, block_addr));
            end
        end
    endcase

    prev_block_addr <= block_addr;
end


endmodule