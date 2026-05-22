#include <SPI.h>

// SD card chip select
#define CS 4
// SD card
#define CD 7

struct SPICommand {
  // Which command this represents (6 bits)
  uint8_t command_index;
  // The argument of the command
  uint32_t argument;
  // 7 bit crc
  uint8_t crc;

  SPICommand(uint8_t command_index, uint32_t argument) {
    this->command_index = command_index;
    this->argument = argument;
    this->crc = 0;
  }

  SPICommand(uint8_t command_index, uint32_t argument, uint8_t crc) {
    this->command_index = command_index;
    this->argument = argument;
    this->crc = crc;
  }
};

struct R3SPIResponse {
  uint8_t r1;
  uint32_t ocr;

  R3SPIResponse(uint8_t r1, uint32_t ocr) {
    this->r1 = r1;
    this->ocr = ocr;
  }
};

struct BlockReadResponse {
  uint8_t r1_response;
  uint8_t data_token;
  uint8_t block[512];
  uint16_t crc;
};

void sendSPICommand(SPICommand c) {
  Serial.println("Sending SPI command");

  uint8_t buf[6];
  // Convert the command to a sequence of bytes
  buf[0] = (0b01 << 6) | (0b00111111 & c.command_index);
  // // Assumption: uin32_t is little endian
  // memcpy(&buf[1], c.argument, 4);
  for (int i = 0; i < 4; i++) {
    buf[i+1] = c.argument >> ((3-i)*8);
  }
  buf[5] = (c.crc << 1) | 0b1;

  Serial.println("aaaa");

  // TODO: Drive CS from high to low
  digitalWrite(CS, HIGH);
  delay(1);
  digitalWrite(CS, LOW);

  Serial.println("b");

  for (int i = 0; i < 6; i++) {
    Serial.print("Transferring: ");
    Serial.println(buf[i], BIN);
    SPI.transfer(buf[i]);
  }

  Serial.println("c");
}

// Read a 1 byte response from the SD card.
uint8_t readR1SPIResponse() {
  // Read bytes until we receive one that starts with 0
  uint8_t byte = 0;
  do {
    byte = SPI.transfer(0xFF);
    Serial.print("Read byte: "); Serial.println(byte, BIN);
  } while (byte & (0b1 << 7));

  return byte;
}

R3SPIResponse readR3SPIResponse() {
  // Read the one byte R1 response
  uint8_t r1 = readR1SPIResponse();

  // Read the 32 bit bonus value
  uint32_t ocr = 0;
  for (int i = 0; i < 4; i++) {
    ocr |= SPI.transfer(0xFF) << ((3-i)*8);
  }

  return R3SPIResponse(r1, ocr);
}

BlockReadResponse readBlockReadResponse() {
  BlockReadResponse response;

  // Read the command response
  response.r1_response = readR1SPIResponse();

  // The next byte of the response is the data token, but it's preceeded by some 0xFF's
  response.data_token = 0;
  do {
    response.data_token = SPI.transfer(0xFF);
  } while(response.data_token == 0xFF);
  if (response.data_token != 0xFE) { /* TODO: Return an error */ }

  // Read the actual data
  for (int i = 0; i < 512; i++) {
    response.block[511-i] = SPI.transfer(0xFF);
  }

  // Read the checksum. TODO: write the value into the response object
  SPI.transfer(0xFF);
  SPI.transfer(0xFF);

  return response;
}

int initSDCard() {
  // Power on
  // Wait >= 1ms

  // Initialize the SPI peripheral
  SPI.begin();
  SPI.beginTransaction(SPISettings(20000000, MSBFIRST, SPI_MODE0)); // 20 MHz

  // At least 74 dummy clock cycles with CS high.
  digitalWrite(CS, HIGH);
  for (int i = 0; i < 4; i++) SPI.transfer(0xFF);

  // Set CS low (active)
  digitalWrite(CS, LOW);

  // CMD0 with correct CRC
  sendSPICommand(SPICommand(0, 0, 0b1001010));
  // Verify 0x01 R1 response
  if (readR1SPIResponse() != 0x01) return -1;

  // CMD8 with correct CRC
  sendSPICommand(SPICommand(8, 0x1AA, 0b1000011));
  // Verify that the lower 12 bits in the response is 0x1AA
  auto cmd8_response = readR3SPIResponse();
  if ((cmd8_response.ocr & 0x3FF) != 0x1AA) return -2;
  
  // Do while R1 respnse is 0x01 (idle)
  uint8_t acmd41_response;
  do {
    // Send ACMD41 command
    sendSPICommand(SPICommand(55, 0));
    readR1SPIResponse();

    sendSPICommand(SPICommand(41, 0x40000000));
    acmd41_response = readR1SPIResponse();
  } while (acmd41_response == 0x01);
  if (acmd41_response != 0x00) return -3;

  // CMD58
  sendSPICommand(SPICommand(58, 0x00));
  auto cmd58_response = readR3SPIResponse();
  // If !CCS bit in R7 response
  // if (!(cmd58_response.ocr & (0b1 << 30))) {
    // while (1) Serial.println("yes");

    // CMD16 (set block size to 512 bytes)
    sendSPICommand(SPICommand(16, 0x200));
    readR1SPIResponse();
  // } else while (1) Serial.println("yes");
  
  return 0;
}

void setup() {
  pinMode(CS, OUTPUT);
  pinMode(CD, OUTPUT);

  Serial.begin(115200);

  delay(2000);
  Serial.println("Initializing sd card: ");
  Serial.print("Result: ");
  Serial.println(initSDCard());
}

void loop() {
  // Read the block at address 0
  sendSPICommand(SPICommand(17, 0));
  auto result = readBlockReadResponse();
  
  for (int i = 0; i < 512; i++) {
    Serial.write(result.block[511-i]);
  }
  Serial.println();

  delay(4000);
}
