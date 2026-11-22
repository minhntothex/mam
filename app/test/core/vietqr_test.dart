import 'package:flutter_test/flutter_test.dart';
import 'package:mam/core/vietqr.dart';

void main() {
  group('VietQrGenerator', () {
    test('CRC16-CCITT-FALSE matches standard check value 29B1', () {
      expect(VietQrGenerator.crc16CcittFalse('123456789'), '29B1');
    });

    test('strips Vietnamese diacritics and symbols cleanly', () {
      expect(
        VietQrGenerator.normalizeTransferNote('Đức trả tiền ăn phở bò!!!', maxLength: 30),
        'Duc tra tien an pho bo',
      );
      expect(
        VietQrGenerator.formatTransferNote(
          template: '{name} tra tien {title}',
          participantName: 'Hùng',
          billTitle: 'Lẩu Haidilao Quận 1',
          maxLength: 25,
        ),
        'Hung tra tien Lau Haidila',
      );
    });

    test('generates valid dynamic VietQR with amount and normalized note', () {
      final qr = VietQrGenerator.generate(
        bankBin: '970436',
        accountNo: '0123456789',
        amount: 125000,
        transferNote: 'Minh trả tiền ăn trưa',
      );

      expect(qr.startsWith('000201010212'), isTrue); // Dynamic QR (01=12)
      expect(qr.contains('A000000727'), isTrue);
      expect(qr.contains('970436'), isTrue);
      expect(qr.contains('0123456789'), isTrue);
      expect(qr.contains('QRIBFTTA'), isTrue);
      expect(qr.contains('5303704'), isTrue);
      expect(qr.contains('5406125000'), isTrue);
      expect(qr.contains('5802VN'), isTrue);
      expect(qr.contains('0821Minh tra tien an trua'), isTrue);

      // Verify trailing CRC matches recomputed CRC16-CCITT-FALSE
      final bodyWithCrcTag = qr.substring(0, qr.length - 4);
      final crc = qr.substring(qr.length - 4);
      expect(bodyWithCrcTag.endsWith('6304'), isTrue);
      expect(VietQrGenerator.crc16CcittFalse(bodyWithCrcTag), crc);
    });

    test('generates static VietQR without Tag 54 when amount is null or 0', () {
      final qr = VietQrGenerator.generate(
        bankBin: '970407',
        accountNo: '1903000111222',
      );

      expect(qr.startsWith('000201010211'), isTrue); // Static QR (01=11)
      expect(qr.contains('53037045802VN'), isTrue); // No Tag 54 between 53 and 58
      final bodyWithCrcTag = qr.substring(0, qr.length - 4);
      final crc = qr.substring(qr.length - 4);
      expect(VietQrGenerator.crc16CcittFalse(bodyWithCrcTag), crc);
    });

    test('validates bank BIN, account number, and negative amount', () {
      expect(
        () => VietQrGenerator.generate(bankBin: '12345', accountNo: '0123'),
        throwsArgumentError,
      );
      expect(
        () => VietQrGenerator.generate(bankBin: '970436', accountNo: '   '),
        throwsArgumentError,
      );
      expect(
        () => VietQrGenerator.generate(
          bankBin: '970436',
          accountNo: '0123',
          amount: -1000,
        ),
        throwsArgumentError,
      );
    });
  });
}
