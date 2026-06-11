# CS122A Final Project

Team members: Mark Ghebrial, Jade Than

The code that runs on the pico can be found in [`/pico`](/pico). The verilog that "runs" on the IceSugar can be found in [`/fpga`](/fpga).

## Synthesizing FPGA Code
### Setup
```bash
cd fpga
mkdir build
```

### Running a testbench
```bash
make <name of testbench>.sim
```

### Flashing the code
```bash
make top.bit && icesprog build/top.bit
```

## Building Raspberry Pi Pico Code
TODO: Instructions for loading CircuitPython code