/*
This script ingests a waveform capture of the SD card controller module and processes
it for use in the SD card controller testbench. We captured the waveform by connecting
a logic analyzer to the FPGA while it communicated to the SD card. The waveform
is 50 million samples long, so we don't want to use the whole thing in our testbench.
This script filters out all samples that aren't on rising SCK edges, and it filters
out samples that occur after the first block read.

This script is written in odin: https://odin-lang.org. It's a cool "C replacement"
language that I wanted an excuse to try out. You can run this program by installing
odin and running `odin run scripts/process_capture_file.odin -file`
*/

package main

import "core:fmt"
import "core:os"

Sample :: bit_field u8 {
    sck: bool  | 1,
    miso: bool | 1,
    mosi: bool | 1,
    cs: bool   | 1,
}

main :: proc() {
    // "capture.bin" is a binary dump of a successful sd card block read transaction. Each byte represents
    // one sample, and, since the logic analyzer has 8 channels, each bit represents one of the channels.
    // See the `Sample` struct for the layout of of the bits.
    in_file, err := os.open("capture.bin");
    if err != nil {
        os.exit(-1);
    }
    defer os.close(in_file);
    // Read the entire file into `data`
    data, read_err := os.read_entire_file(in_file, context.allocator);
    defer delete(data)

    // Create a file to output to
    out_file, _ := os.create("tb/sd_card_tb_capture.bin");
    defer os.close(out_file);

    out_data: [dynamic]u8;
    defer delete(out_data)

    prev_sample: Sample;
    for byte, index in data {
        // Only output a limited number of samples.
        if len(out_data) >= 40000 {
            break;
        }

        // Cast to a Sample bit field
        sample := Sample(byte);

        // Only emit the samples that occur on rising clock edges
        if index == 0 || sample.sck && !prev_sample.sck {
            append(&out_data, u8(sample))
        }

        prev_sample = sample;
    }
    fmt.printfln("%i samples kept out of %i total samples", len(out_data), len(data));

    // Write the data to the file
    _, write_err := os.write(out_file, out_data[:]);
    if write_err != nil {
        fmt.println("Error writing to output file:", write_err);
        os.exit(-2);
    }
}