`include "src/sd_card.sv"

module sd_card_buffer(
    input wire clk,

    // The address of the 2 byte word to read from the SD card
    input wire[31:0] word_addr,
    // The word read from the SD card
    output logic[15:0] word = 0,
    // Whether or not the word is done being read
    output logic word_ready = 0,
    
    // The address to pass to the sd_card module
    output logic[31:0] block_addr = 0,
    // The sd_status returned by the sd_card module
    input spi_module_status sd_status,
    // The block data returned from the sd_card module
    input wire[511:0] block_data
);

logic[511:0] buf0 = 0;
// The block address of the data currently loaded into buf0
logic[31:0] buf0_addr = 0;
// Whether or not buf0 actually contains the correct data
logic buf0_ready = 0;

logic[511:0] buf1 = 0;
// The block address of the data currently loaded into buf1
logic[31:0] buf1_addr = 0;
// Whether or not buf1 actually contains the correct data
logic buf1_ready = 0;


logic[31:0] b_addr = 0;
logic[6:0] b_offset = 0;
logic sd_module_is_currently_busy = 0;

spi_module_status prev_sd_status = INITIALIZING;

always @(posedge clk) begin
    if (prev_sd_status != IDLE && sd_status == IDLE) begin
        sd_module_is_currently_busy = 0;
    end

    // If the sd card module is done reading data...
    if (sd_status == IDLE) begin
        // ...and the data it read is from the correct address...
        if (block_addr == buf0_addr) begin
            // ...copy that data into the buffer
            buf0 = block_data;
            buf0_ready = 1;
        end 
        if (block_addr == buf1_addr) begin
            buf1 = block_data;
            buf1_ready = 1;
        end 
    end

    // Calculate the corresponding block address and block_offset of the word
    // Such that: word_addr = (512 * b_addr) + b_offset
    b_addr = word_addr / 64;
    b_offset = word_addr % 64;

    // If buf0 has the data we need
    if (buf0_ready && buf0_addr == b_addr) begin
        word = (buf0 >> (b_offset * 16)) & 16'hFFFF;
        word_ready = 1;

        // Start loading the next block from the sd card
        if (!sd_module_is_currently_busy && buf1_addr != buf0_addr + 1) begin
            buf1_addr = buf0_addr + 1;
            buf1_ready = 0;
            // Tell the sd card module to start reading the block at buf1_addr
            block_addr = buf1_addr;
            sd_module_is_currently_busy = 1;
        end
    end
    // If buf0 doesn't have the data we need but buf1 does
    else if (buf1_ready && buf1_addr == b_addr) begin
        word = (buf1 >> (b_offset * 16)) & 16'hFFFF;
        word_ready = 1;

        if (!sd_module_is_currently_busy && buf0_addr != buf1_addr + 1) begin
            buf0_addr = buf1_addr + 1;
            buf0_ready = 0;
            // Tell the sd card module to start reading the block at buf0_addr
            block_addr = buf0_addr;
            sd_module_is_currently_busy = 1;
        end
    end
    // If neither buf has the data we need
    else if (!sd_module_is_currently_busy) begin
        word_ready = 0;
        // Start reading the data we need into buf0
        buf0_addr = b_addr;
        buf0_ready = 0;
        // Tell the sd card module to start reading the block at buf0_addr
        block_addr = buf0_addr;
        sd_module_is_currently_busy = 1;
    end

    prev_sd_status = sd_status;
end

endmodule