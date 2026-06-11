import time
import array
import math
import audiocore
import board
import digitalio
import io
import audiobusio
import busio

audio = audiobusio.I2SOut(board.GP0, board.GP1, board.GP3)

fpga_clk = digitalio.DigitalInOut(board.GP2)
fpga_clk.direction = digitalio.Direction.INPUT
fpga_data = digitalio.DigitalInOut(board.GP4)
fpga_data.direction = digitalio.Direction.INPUT

pin0 = digitalio.DigitalInOut(board.GP5)
pin1 = digitalio.DigitalInOut(board.GP6)
pin0.direction = digitalio.Direction.OUTPUT
pin1.direction = digitalio.Direction.OUTPUT

pin0.value = True
pin1.value = True

spi_input = bytearray(64000)
final_wave = array.array("H", [0] * 32000)

state = 1
byte_index = 0
count = 0
data = 0
while byte_index < 64000:
  # Transition actions
  if state == 1: #Low to Low
    if(fpga_clk.value):
      state = 2 #If is high, change
    else:
      state = 1
  elif state == 2: #Low to High
    state = 3
  elif state == 3: #High to High
    if(fpga_clk.value):
      state = 3
    else:
      state = 4 #If is low, change
  elif state == 4: #High to Low
    state = 1
  
  # State Actions
  if state == 1:
    pass
  elif state == 2:
    if (count < 8):
      if (data.value):
        data = (data << 1) + 1
      else:
        data = data << 1
      count += 1
    else:
      spi_input[byte_index] = data
      count = 0
      byte_index += 1
      data = 0
      if ((byte_index % 2) == 0):
        pin0.value = True
      else:
        pin0.value = False
      if ((byte_index % 4) == 0):
        pin1.value = True
      else:
        pin1.value = False
  elif state == 3:
    pass
  elif state == 4:
    pass

while (final_wave[31999] == 0):
  pass


wave_file = io.open("hiloud.wav", "rb")
header = wave_file.read(44)
wave = array.array("H", [0] * 4000)
print(header)
for i in range(4000):
  # wave[i] = wave_file.read(1)
  raw = int.from_bytes(wave_file.read(2), byteorder='little')
  if raw > 32767:
    wave[i] = raw - 32768
  else:
    wave[i] = raw + 32768

raw_wave = audiocore.RawSample(wave, sample_rate=16000, single_buffer=False)


audio.play(raw_wave, loop=True)
while audio.playing:
  pass
  
print("Done!")