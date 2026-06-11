module peripheral (
    // SPI output pins
    input wire sck,
    input wire communicator,

    // Communication with the rest of fpga
    output wire en,

    // Communication with the Raspberry Pi
    input wire pico_clk,
    output wire pico_data
);

logic start = 0;
logic enable = 1;
logic data_out = 0;
logic [4095:0] read_data_in;
logic [4095:0] write_data_out;
logic fpgaBit = 0;
logic picoBit = 4095;

// Logic
// Place into the buffer
always @(posedge sck) begin
  if(fpgaBit == 4095)begin
    fpgaBit <= 0;
    enable <= 0;
  end
  else begin
    fpgaBit <= fpgaBit + 1;
  end

  // Read in data
  for (int i = 0; i < 4095; i = i + 1) begin
    read_data_in[i] <= read_data_in[i + 1];
  end
  read_data_in[4095] <= communicator;
end

// Data has MSB in index 0 of a byte, so we just send it out like that again
always @(negedge pico_clk) begin
  if(picoBit == 4095) begin
    picoBit <= 0;
    // Pull in data that has been read already
    for (int i = 0; i < 4095; i++) begin
      write_data_out[i] <= read_data_in[i + 1];
    end
    enable <= 1;
    data_out <= read_data_in[0];
  end
  else begin
    data_out <= write_data_out[0];
    for (int i = 0; i < 4095; i = i + 1) begin
      write_data_out[i] <= write_data_out[i + 1];
    end
    picoBit <= picoBit + 1;
  end
  
end


assign en = enable;
assign pico_data = data_out;

endmodule