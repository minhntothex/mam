import 'dart:convert';

/// Offline VietQR (EMVCo NAPAS 247 IBFT) payload generator.
///
/// Generates standard EMVCo Merchant Presented Mode strings with CRC16-CCITT-FALSE
/// completely offline without relying on external APIs.

abstract final class VietQrGenerator {
  static const String _napasAid = 'A000000727';
  static const String _serviceCodeAccount = 'QRIBFTTA';
  static const String _currencyVnd = '704';
  static const String _countryVn = 'VN';

  static final RegExp _binPattern = RegExp(r'^[0-9]{6}$');

  /// Generates a VietQR EMVCo string.
  ///
  /// - When [amount] is provided and `> 0`, creates a dynamic QR (`Tag 01 = 12`)
  ///   with `Tag 54 = amount`.
  /// - When [amount] is `null` or `0`, creates a static QR (`Tag 01 = 11`)
  ///   without `Tag 54`.
  /// - [transferNote] is automatically stripped of Vietnamese diacritics and
  ///   special characters, then truncated to [maxNoteLength] (default 25 chars
  ///   for broadest compatibility across VN banking apps).
  static String generate({
    required String bankBin,
    required String accountNo,
    int? amount,
    String? transferNote,
    int maxNoteLength = 25,
  }) {
    final cleanBin = bankBin.trim();
    final cleanAccount = accountNo.trim().replaceAll(RegExp(r'\s+'), '');

    if (!_binPattern.hasMatch(cleanBin)) {
      throw ArgumentError.value(
        bankBin,
        'bankBin',
        'Bank BIN must be exactly 6 numeric digits',
      );
    }
    if (cleanAccount.isEmpty) {
      throw ArgumentError.value(
        accountNo,
        'accountNo',
        'Account number must not be empty',
      );
    }
    if (amount != null && amount < 0) {
      throw ArgumentError.value(
        amount,
        'amount',
        'Amount must be >= 0',
      );
    }

    final isDynamic = amount != null && amount > 0;
    final beneficiary = _tlv('00', cleanBin) + _tlv('01', cleanAccount);
    final napasAccountInfo =
        _tlv('00', _napasAid) + _tlv('01', beneficiary) + _tlv('02', _serviceCodeAccount);

    final buffer = StringBuffer()
      ..write(_tlv('00', '01'))
      ..write(_tlv('01', isDynamic ? '12' : '11'))
      ..write(_tlv('38', napasAccountInfo))
      ..write(_tlv('53', _currencyVnd));

    if (isDynamic) {
      buffer.write(_tlv('54', amount.toString()));
    }

    buffer.write(_tlv('58', _countryVn));

    final normalizedNote =
        transferNote == null ? '' : normalizeTransferNote(transferNote, maxLength: maxNoteLength);
    if (normalizedNote.isNotEmpty) {
      buffer.write(_tlv('62', _tlv('08', normalizedNote)));
    }

    // Append CRC tag ID + length ('6304') before computing CRC16-CCITT-FALSE.
    buffer.write('6304');
    final payloadWithoutCrc = buffer.toString();
    final crc = crc16CcittFalse(payloadWithoutCrc);
    return '$payloadWithoutCrc$crc';
  }

  /// Renders a transfer note template (e.g. `{name} tra tien {title}`) and
  /// normalizes it for VietQR `Tag 62/08`.
  static String formatTransferNote({
    required String template,
    required String participantName,
    required String billTitle,
    int maxLength = 25,
  }) {
    final filled = template
        .replaceAll('{name}', participantName)
        .replaceAll('{title}', billTitle);
    return normalizeTransferNote(filled, maxLength: maxLength);
  }

  /// Strips Vietnamese diacritics, removes special symbols, collapses spaces,
  /// and truncates to [maxLength] ASCII characters.
  static String normalizeTransferNote(String input, {int maxLength = 25}) {
    final ascii = removeVietnameseDiacritics(input);
    final cleaned = ascii
        .replaceAll(RegExp(r'[^A-Za-z0-9 ]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (maxLength <= 0 || cleaned.length <= maxLength) return cleaned;
    return cleaned.substring(0, maxLength).trimRight();
  }

  /// Replaces Vietnamese accented characters with plain ASCII equivalents.
  static String removeVietnameseDiacritics(String input) {
    final buffer = StringBuffer();
    for (final rune in input.runes) {
      final ch = String.fromCharCode(rune);
      buffer.write(_vietnameseCharMap[ch] ?? ch);
    }
    return buffer.toString();
  }

  /// Computes CRC16-CCITT-FALSE (poly 0x1021, init 0xFFFF, no xorOut)
  /// returned as 4 uppercase hex characters.
  static String crc16CcittFalse(String input) {
    final bytes = utf8.encode(input);
    var crc = 0xFFFF;
    for (final byte in bytes) {
      crc ^= (byte & 0xFF) << 8;
      for (var i = 0; i < 8; i++) {
        if ((crc & 0x8000) != 0) {
          crc = ((crc << 1) ^ 0x1021) & 0xFFFF;
        } else {
          crc = (crc << 1) & 0xFFFF;
        }
      }
    }
    return crc.toRadixString(16).toUpperCase().padLeft(4, '0');
  }

  static String _tlv(String tag, String value) {
    final byteLen = utf8.encode(value).length;
    if (byteLen > 99) {
      throw ArgumentError('TLV value too long ($byteLen bytes) for tag $tag');
    }
    return '$tag${byteLen.toString().padLeft(2, '0')}$value';
  }

  static const Map<String, String> _vietnameseCharMap = {
    'à': 'a', 'á': 'a', 'ạ': 'a', 'ả': 'a', 'ã': 'a',
    'â': 'a', 'ầ': 'a', 'ấ': 'a', 'ậ': 'a', 'ẩ': 'a', 'ẫ': 'a',
    'ă': 'a', 'ằ': 'a', 'ắ': 'a', 'ặ': 'a', 'ẳ': 'a', 'ẵ': 'a',
    'è': 'e', 'é': 'e', 'ẹ': 'e', 'ẻ': 'e', 'ẽ': 'e',
    'ê': 'e', 'ề': 'e', 'ế': 'e', 'ệ': 'e', 'ể': 'e', 'ễ': 'e',
    'ì': 'i', 'í': 'i', 'ị': 'i', 'ỉ': 'i', 'ĩ': 'i',
    'ò': 'o', 'ó': 'o', 'ọ': 'o', 'ỏ': 'o', 'õ': 'o',
    'ô': 'o', 'ồ': 'o', 'ố': 'o', 'ộ': 'o', 'ổ': 'o', 'ỗ': 'o',
    'ơ': 'o', 'ờ': 'o', 'ớ': 'o', 'ợ': 'o', 'ở': 'o', 'ỡ': 'o',
    'ù': 'u', 'ú': 'u', 'ụ': 'u', 'ủ': 'u', 'ũ': 'u',
    'ư': 'u', 'ừ': 'u', 'ứ': 'u', 'ự': 'u', 'ử': 'u', 'ữ': 'u',
    'ỳ': 'y', 'ý': 'y', 'ỵ': 'y', 'ỷ': 'y', 'ỹ': 'y',
    'đ': 'd',
    'À': 'A', 'Á': 'A', 'Ạ': 'A', 'Ả': 'A', 'Ã': 'A',
    'Â': 'A', 'Ầ': 'A', 'Ấ': 'A', 'Ậ': 'A', 'Ẩ': 'A', 'Ẫ': 'A',
    'Ă': 'A', 'Ằ': 'A', 'Ắ': 'A', 'Ặ': 'A', 'Ẳ': 'A', 'Ẵ': 'A',
    'È': 'E', 'É': 'E', 'Ẹ': 'E', 'Ẻ': 'E', 'Ẽ': 'E',
    'Ê': 'E', 'Ề': 'E', 'Ế': 'E', 'Ệ': 'E', 'Ể': 'E', 'Ễ': 'E',
    'Ì': 'I', 'Í': 'I', 'Ị': 'I', 'Ỉ': 'I', 'Ĩ': 'I',
    'Ò': 'O', 'Ó': 'O', 'Ọ': 'O', 'Ỏ': 'O', 'Õ': 'O',
    'Ô': 'O', 'Ồ': 'O', 'Ố': 'O', 'Ộ': 'O', 'Ổ': 'O', 'Ỗ': 'O',
    'Ơ': 'O', 'Ờ': 'O', 'Ớ': 'O', 'Ợ': 'O', 'Ở': 'O', 'Ỡ': 'O',
    'Ù': 'U', 'Ú': 'U', 'Ụ': 'U', 'Ủ': 'U', 'Ũ': 'U',
    'Ư': 'U', 'Ừ': 'U', 'Ứ': 'U', 'Ự': 'U', 'Ử': 'U', 'Ữ': 'U',
    'Ỳ': 'Y', 'Ý': 'Y', 'Ỵ': 'Y', 'Ỷ': 'Y', 'Ỹ': 'Y',
    'Đ': 'D',
  };
}
