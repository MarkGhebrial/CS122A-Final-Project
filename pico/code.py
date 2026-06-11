import time
import array
import math
import io
import sys

wave_file = io.open("test.wav", "rb")
header = wave_file.read(44)
wave = array.array("H", [0] * 4000)
final_wave = array.array("H", [0] * 32000)
test = bytearray(32000)

test[200] = 100

test_buffer = io.BufferedReader(io.BytesIO(test))


print(header)
for i in range(4000):
  # wave[i] = wave_file.read(1)
  raw = int.from_bytes(test_buffer.read(2), byteorder='little')
  if raw > 32767:
    wave[i] = raw - 32768
  else:
    wave[i] = raw + 32768
  if(i == 100 or i == 3000):
    print(raw)
    print((wave[i]))

sample_rate = 8000
tone_volume = .1  # Increase or decrease this to adjust the volume of the tone.
frequency = 440  # Set this to the Hz of the tone you want to generate.
length = sample_rate // frequency  # One freqency period
sine_wave = array.array("H", [0] * length)
for i in range(length):
  sine_wave[i] = int((math.sin(math.pi * 2 * frequency * i / sample_rate) * tone_volume + 1) * (2 ** 15 - 1))

# template_file = io.open("template16000.txt", "a")
# template_file.truncate(44)
# template_file.write(rest)
# template_file.close()
# wave_file.close()

# with open("template16000.wav", "wb") as template_file:
#   test = template_file.read()
# template_file = io.open("template16000.txt", "a")
# template_file.truncate(44)
# template_file.close()
# wave_file = io.open("hiloud.wav", "a")
# wave_file.close()


# throw = wave_file.read(44)
# test = wave_file.read(16000)

# wave_file.close()

# Requires 128 blocks of 512 bytes to fill up
# full = throw + test
# wave_file.close()
  
print("Done!")