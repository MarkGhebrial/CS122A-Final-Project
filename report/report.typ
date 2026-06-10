#import "@preview/fletcher:0.5.8" as fletcher: diagram, node, edge

// Set the font
#set text(font: "Lato", size: 10pt)
#show math.equation: set text(size: 11pt)//, weight: "bold")
// Center the title
#show title: set align(center)

// Set the heading numbering
#set heading(numbering: "1.1.")
#show outline: set heading(numbering: "1.")

// Style code blocks
#show raw: set text(font: "Source Code Pro", size: 9pt, weight: "semibold")
#show raw.where(block: true): block.with(
  fill: luma(230),
  inset: 8pt,
  radius: 4pt,
  width: 100%,
)
#show raw.where(block: false): box.with(
  fill: luma(230),
  inset: (x: 3pt, y: 0pt),
  outset: (y: 3pt),
  radius: 1.5pt,
)

// Center images
#show image: it => align(center)[#it]

#set figure(supplement: none)
#show figure.caption: set block(width: 75%)

#show link: underline

#set overline(stroke: 0.75pt)

#set page(
   margin: 1in,
   paper: "us-letter",
   numbering: "1 of 1"
)
// #set page(margin: context {
//   if counter(page).get().first() > 1 {
//     1in
//   } else {
//     0.5in
//   }
// })
// #context 

// #set page(header: context {
//   if counter(page).get().first() == 1 [
//     #set grid.cell(align: top)
//     #grid(
//       columns: (auto, 1fr),
//       [#title[CS122A Final Project Report]],
//       grid.cell(align: right)[
//         *Mark Ghebrial \
//         Jade Than* \
//         June 10th, 2026
//       ]
//     )
//     #line(length: 100%)
//   ]
// })

// #show page.where(counter == 1): set page(margin: (top: 0.5in))

#set grid.cell(align: top)
#grid(
  columns: (auto, 1fr),
  [#title[CS122A Final Project Report]],
  grid.cell(align: right)[
    *Mark Ghebrial \
    Jade Than* \
    June 10th, 2026
  ]
)
#line(length: 100%)


= High Level Description of Project
The initial plan for this project was to turn a laptop keyboard into a USB keyboard by implementing a keyswitch matrix scanner on the FPGA, using SPI to send scancodes to the Pi Pico, and using `tinyusb` to send keypress events to a computer. Our TA suggested we add more complexity, so we decided to increase scope by using an I2S amplifier to play audio samples on each keypress.

Since the iCESugar-pro has an SD card slot, we decided that we'd store the audio samples in an SD card connected to the FPGA. Implementing the SD card protocol in Verilog swallowed up so much time that we finished it _during finals week_. By the time we realized our blunder, it was too late to return to our original project scope (just the keyboard), so we had to set aside the keyboard and double down on getting audio playback from the SD card working.

*Our current project description is as follows:* The FPGA acts as an SPI master for two devices: the SD card and the Raspberry Pi Pico. The FPGA initializes the SD card, then starts reading blocks and streaming them to the Pico. The Pico saves the raw audio data into memory before disabling the FPGA (via a flow control pin) and playing the audio sample in a loop.

= Elements of Complexity
- SD card, driven by the FPGA
- I2S between Pico and amplifier
- SPI communication between FPGA and Pico
- Testbenches for Verilog code

= User Guide
TODO: Instructions on flashing audio data onto an SD card

= List of Hardware Components
- iCESugar-pro
- Raspberry Pi Pico
- Micro SD card
- MAX98357 I2S amplifier
- Generic speaker

= List of Software Libraries
On the Raspberry Pi Pico 2, we used circuit python to process raw pcm data (place into a buffer) and output it as I2S.

On the FPGA, all the code was written by us.

= List of Protocols Used
- SD card SPI protocol.
  - This is a protocol built on top of SPI. It uses fixed length, 6 byte commands. Most command responses are 1 byte, but some append extra data.
- I2S
  - This is a protocol that is technically handled by Circuit Python. It just outputs raw PCM data, a LR signal (for left and right stereo), and CLK at 512 kHz to the MAX98357A.

// / SD card SPI: fdsafdsafa
// / fdsafdsafasfsa: fdsafdsaf

= How we met the Requirements listed in the Proposal
_In the proposal???_ We don't meet any of the requirements at all. Our project scope has changed so much that our project proposal is not an accurate picture of what we delivered.

Ultimately though, we were able to successfully read data from the SD card.

We were also able to output this data onto a speaker, though the library that we used to output the I2S has some very strange implementations such that it only is able to load one sound and play it once or keep looping it. We understand the protocol completely, so if we had more time (it took 3 weeks to switch to using the library because the I2S implementation didn't work and the clock was off by 15 kHz which led to noise I think) then maybe we could have implemented something that had the capacity to play any data that was input into it rather than load data once.

We did not implement the keyboard nor the 


= Design Diagrams
== Wiring
TODO: Maybe sketch something out on paper and 


== SD Card Module State Machine
The Verilog module that handles communication with the SD card contains a large state machine.

== FPGA Module Hierarchy
#diagram(
  node-stroke: 1pt,
  spacing: (3.5em, 4em),
  {
    import fletcher.shapes: diamond, pill, rect

    node((0, -2), [Physical pins], shape: pill)
    
    node((0, 0), [top], name: <top>, corner-radius: 5pt)

    node((-1, 1), [pll], name: <pll>, shape: rect)
    node((1, 1), [main], name: <main>)

    node((0, 2), [sd_card_spi], name: <sd-card-spi>)
    node((1, 2), [sd_card_controller])
    node((2, 2), [communicator], name: <communicator>)

    node((2, 3), [pico_spi_controller], name: <pico-spi>)
    // node()

    edge((0, -2), <top>, "<|-|>", text(size: 8pt)[25Mhz clock\ SD card SPI pins\ Pico SPI pins])
    
    edge(<top>, <pll>, "-|>", text(size: 8pt)[25MHz clock], label-angle: auto, bend: -15deg)
    edge(<top>, <pll>, "<|-", text(size: 8pt)[8MHz clock], label-angle: auto, bend: 15deg)

    edge(<top>, <main>, "<|-|>", text(size: 8pt)[8Mhz clock\ SD card SPI pins\ Pico SPI pins], label-angle: auto)

    edge(<main>, <sd-card-spi>, "-|>", text(size: 8pt)[Block address], label-angle: auto, bend: -15deg)
    edge(<main>, <sd-card-spi>, "<|-", text(size: 8pt)[Block data], label-angle: auto, bend: 15deg)
    
    edge(<main>, <communicator>, "<|-", text(size: 8pt)[Pico SPI Pins\ Block address], label-angle: auto, bend: 15deg)
    edge(<main>, <communicator>, "-|>", text(size: 8pt)[Block data], label-angle: auto, bend: -15deg)

    edge(<communicator>, <pico-spi>, "-|>", text(size: 8pt)[label])
  }
)


= AI Usage
Neither team member used AI for any part of this project.

= Acknowledgements
Massive thank you to RB for being so chill. Another thanks to Allen Knight for helping with debugging I2S on the fpga even if it didn't work out in the end.

No other outside code was used for the Raspberry Pi Pico 2 or the FPGA except for the pll clock.

