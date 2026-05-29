`include "src/buffer.sv"
// `include "src/sd_card.sv"
`timescale 1ns/1ps

module buffer_tb;

initial begin
    $dumpfile("build/buffer.vcd"); // intermediate file for waveform generation
    $dumpvars(0, buffer_tb);       // capture all signals under buffer_tb
end

logic clk = 0;
logic[31:0] word_addr = 0;
wire[15:0] word;
wire word_ready;
wire[31:0] block_addr;
spi_module_status sd_status = IDLE;
logic[511:0] block_data;

// Unit under test
sd_card_buffer uut
(
    .clk(clk),
    .word_addr(word_addr),
    .word(word),
    .word_ready(word_ready),
    .block_addr(block_addr),
    .sd_status(sd_status),
    .block_data(block_data)
);

always begin 
    #1;
    clk =~ clk; // Toggle the clock
end

logic [1:0][511:0] blocks = {
    512'hDEADBEEF99999999999999999999999999999999999999999999999999998005,
    512'hFEA0AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAABEAC,
    512'h00,
    ~512'h00
};

logic[31:0] prev_block_addr;
int counter = 1;
always @(posedge clk) begin
    prev_block_addr <= block_addr;

    if (counter == 0) begin
        sd_status = IDLE;
        if (prev_block_addr != block_addr) begin
            // Start reading a block
            counter = counter + 1;
        end
    end
    else begin
        sd_status = READING_BLOCK;
        counter = counter + 1;
        if (counter == 4000) begin
            counter = 0;
            block_data = blocks[block_addr % 4];
        end
    end
end

initial begin
    for (int i = 0; i < 150000; i = i + 1) begin
        #2;
        if (word_ready) begin
            word_addr = word_addr + 1;
        end
    end

    $finish;
end

endmodule
