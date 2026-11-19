// ESP32 + RC522 -> UART2 TX (GPIO17) -> FPGA GPIO[18], 9600 8N1
// Library: MFRC522 by GithubCommunity (Arduino Library Manager)
#include <SPI.h>
#include <MFRC522.h>

#define SS_PIN  5
#define RST_PIN 22

MFRC522 rfid(SS_PIN, RST_PIN);

// your tags
const byte TAG_N[4] = {0x52, 0x95, 0x90, 0x5C};  // EV from North
const byte TAG_E[4] = {0xDA, 0xFC, 0xEF, 0x05};  // EV from East

bool uidIs(const byte *ref) {
  if (rfid.uid.size < 4) return false;
  for (byte i = 0; i < 4; i++) if (rfid.uid.uidByte[i] != ref[i]) return false;
  return true;
}

void setup() {
  Serial.begin(115200);
  Serial2.begin(9600, SERIAL_8N1, 16, 17);  // RX2=16 (unused), TX2=17
  SPI.begin(18, 19, 23, SS_PIN);            // SCK, MISO, MOSI, SS
  rfid.PCD_Init();
  Serial.println("Ready, tap a tag");
}

void loop() {
  if (!rfid.PICC_IsNewCardPresent() || !rfid.PICC_ReadCardSerial()) return;

  Serial.print("UID:");
  for (byte i = 0; i < rfid.uid.size; i++) Serial.printf(" %02X", rfid.uid.uidByte[i]);
  Serial.println();

  if (uidIs(TAG_N))      { Serial2.write('N'); Serial.println("-> N"); }
  else if (uidIs(TAG_E)) { Serial2.write('E'); Serial.println("-> E"); }
  else                   { Serial.println("unknown tag, ignored"); }

  rfid.PICC_HaltA();
  rfid.PCD_StopCrypto1();
  delay(300);
}
