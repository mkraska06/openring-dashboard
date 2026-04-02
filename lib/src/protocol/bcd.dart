// Binary-Coded Decimal (BCD) utilities used by the Colmi ring protocol.
//
// BCD encodes each decimal digit into a nibble (4 bits).
// For example, decimal 25 becomes 0x25 (0010 0101).

/// Converts a BCD-encoded byte to its decimal value.
///
/// Example: `bcdToDec(0x25)` → `25`
int bcdToDec(int bcd) => ((bcd >> 4) & 0x0F) * 10 + (bcd & 0x0F);

/// Converts a decimal value (0-99) to BCD encoding.
///
/// Example: `decToBcd(25)` → `0x25`
int decToBcd(int dec) {
  assert(dec >= 0 && dec <= 99, 'Value must be 0-99 for BCD encoding');
  return ((dec ~/ 10) << 4) | (dec % 10);
}
