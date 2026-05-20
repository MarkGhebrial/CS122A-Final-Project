module dac
(
  input logic pclk,        
  output logic dataOut,     // DIN
  output logic lrOut        // LRC
);

reg [7:0] wavmem [0:7994];
// reg [7:0] wavmem [0:3];
logic [15:0] currWord = 16'h0000;
int divider = 0;
int count = 15;
int lrcount = 0;
int wavcount = 0;
int thing = 0;
int wavchange = 0;
initial begin
  $readmemh("include\\sine.txt", wavmem);
end

// Logic
always @ (negedge pclk)begin
  if (count == 15)begin
    count <= 0;
    // wavcount <= (wavcount + 1) % 4457;
    wavcount <= (wavcount + 1) % 3997;
    currWord <= {wavmem[wavcount * 2], wavmem[wavcount * 2 + 1]};
  end
  else begin
    count <= count + 1;
  end

  // if (count == 15)begin
  //   count <= 0;
  //   if (wavcount > 7) begin
  //     wavchange <= ~wavchange;
  //     currWord <= (wavchange)? 16'h0001: 16'h00FF;
  //     wavcount <= 0;
  //   end
  //   else begin
  //     wavcount <= wavcount + 1;
  //   end
  //   lrOut <= thing;
  //   thing <= ~thing;
  // end
  // else begin
  //   count <= count + 1;
  // end

  // if (count == 0)begin
  //   count <= 15;
  //   wavcount <= (wavcount + 1) % 4457;
  //   currWord <= {test[wavcount * 2], test[wavcount * 2 + 1]};
  // end
  // else begin
  //   count <= count - 1;
  // end

  lrcount <= (lrcount + 1) % 16;

  dataOut <= currWord[count % 16];
end

endmodule