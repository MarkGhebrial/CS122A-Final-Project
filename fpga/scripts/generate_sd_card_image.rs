use std::fs::*;
use std::io::Write;

fn main() {
    let mut file = File::create("out.img").unwrap();

    let v: Vec<u8> = (0..=255).collect();

    // Print the 0-255 array in verilog syntax.
    print!("{{");
    for number in &v {
        print!("8'h{number:X?}, ");
    }
    println!("}}");

    // Write 100 copies of the array to out.img
    for _ in 0..100 {
        file.write_all(&v);
    }
}