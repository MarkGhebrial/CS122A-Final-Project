module dac
(
  input logic pclk,        
  output logic dataOut,     // DIN
  output logic lrOut        // LRC
);

reg [7:0] wavmem [0:7999];
// 7793
// reg [7:0] wavmem [0:319];
logic [15:0] currWord = 16'h0000;
int divider = 0;
int count = 31;
int lrcount = 0;
int wavcount = 0;
int thing = 0;
int wavchange = 0;
initial begin
  $readmemh("include/hi.txt", wavmem);
end

// Logic
always @ (negedge pclk)begin
  if (count == 31)begin
    count <= 0;
    if (wavcount == 3999)begin
      wavcount <= 0;
    end
    else begin
      wavcount <= (wavcount + 1);
    end
    currWord <= {wavmem[wavcount << 1], wavmem[(wavcount << 1) + 1]};
  end
  else begin
    count <= count + 1;
  end

  if(lrcount == 15)begin
    lrcount <= 0;
    thing <= ~thing;
  end
  else begin
    lrcount <= lrcount + 1;
  end

  dataOut <= (currWord >> (count)) % 2;
  lrOut <= thing;
end

endmodule