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
The easiest way to do this is with [the Raspberry Pi Pico extension for VSCode](https://marketplace.visualstudio.com/items?itemName=raspberry-pi.raspberry-pi-pico). Once you have it installed, do the following:

```bash
code pico # Open the Pico project directory in a new VSCode window
```

Then, in the new window, navigate to the "Raspberry Pi Pico Project" item in the sidebar.

### Compiling the Code
Click the "Compile Project" button.

### Flashing using USB
Unplug the Pico from your computer. Press and hold the "bootsel" button on the Pico while you plug the USB cable back in. Then, click the "Run Project (USB)" button.

### Flashing using the Pico Debug Probe
Make sure the debug probe is connected correctly to the Pico. Then, click the "Flash Project (SWD)" button.