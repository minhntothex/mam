// Offline Vietnam NAPAS 247 Bank BIN registry for VietQR generation.
// Update this list when new digital banks launch or merge.

final class BankInfo {
  const BankInfo({
    required this.bin,
    required this.shortName,
    required this.fullName,
    required this.code,
  });

  final String bin;
  final String shortName;
  final String fullName;
  final String code;
}

const List<BankInfo> kVietnamBanks = [
  BankInfo(bin: '970436', shortName: 'Vietcombank', fullName: 'Ngân hàng TMCP Ngoại thương Việt Nam', code: 'VCB'),
  BankInfo(bin: '970407', shortName: 'Techcombank', fullName: 'Ngân hàng TMCP Kỹ thương Việt Nam', code: 'TCB'),
  BankInfo(bin: '970422', shortName: 'MB Bank', fullName: 'Ngân hàng TMCP Quân đội', code: 'MB'),
  BankInfo(bin: '970418', shortName: 'BIDV', fullName: 'Ngân hàng TMCP Đầu tư và Phát triển Việt Nam', code: 'BIDV'),
  BankInfo(bin: '970415', shortName: 'VietinBank', fullName: 'Ngân hàng TMCP Công thương Việt Nam', code: 'CTG'),
  BankInfo(bin: '970416', shortName: 'ACB', fullName: 'Ngân hàng TMCP Á Châu', code: 'ACB'),
  BankInfo(bin: '970423', shortName: 'TPBank', fullName: 'Ngân hàng TMCP Tiên Phong', code: 'TPB'),
  BankInfo(bin: '970432', shortName: 'VPBank', fullName: 'Ngân hàng TMCP Việt Nam Thịnh Vượng', code: 'VPB'),
  BankInfo(bin: '970405', shortName: 'Agribank', fullName: 'Ngân hàng Nông nghiệp và Phát triển Nông thôn', code: 'VBA'),
  BankInfo(bin: '970403', shortName: 'Sacombank', fullName: 'Ngân hàng TMCP Sài Gòn Thương Tín', code: 'STB'),
  BankInfo(bin: '970441', shortName: 'VIB', fullName: 'Ngân hàng TMCP Quốc tế Việt Nam', code: 'VIB'),
  BankInfo(bin: '970448', shortName: 'OCB', fullName: 'Ngân hàng TMCP Phương Đông', code: 'OCB'),
  BankInfo(bin: '970437', shortName: 'HDBank', fullName: 'Ngân hàng TMCP Phát triển TP.HCM', code: 'HDB'),
  BankInfo(bin: '970443', shortName: 'SHB', fullName: 'Ngân hàng TMCP Sài Gòn - Hà Nội', code: 'SHB'),
  BankInfo(bin: '970426', shortName: 'MSB', fullName: 'Ngân hàng TMCP Hàng Hải Việt Nam', code: 'MSB'),
  BankInfo(bin: '970440', shortName: 'SeABank', fullName: 'Ngân hàng TMCP Đông Nam Á', code: 'SEAB'),
  BankInfo(bin: '970431', shortName: 'Eximbank', fullName: 'Ngân hàng TMCP Xuất Nhập khẩu Việt Nam', code: 'EIB'),
  BankInfo(bin: '970449', shortName: 'LPBank', fullName: 'Ngân hàng TMCP Lộc Phát Việt Nam', code: 'LPB'),
  BankInfo(bin: '970428', shortName: 'Nam A Bank', fullName: 'Ngân hàng TMCP Nam Á', code: 'NAB'),
  BankInfo(bin: '970409', shortName: 'Bac A Bank', fullName: 'Ngân hàng TMCP Bắc Á', code: 'BAB'),
  BankInfo(bin: '970454', shortName: 'BVBank', fullName: 'Ngân hàng TMCP Bản Việt', code: 'BVB'),
  BankInfo(bin: '970425', shortName: 'ABBank', fullName: 'Ngân hàng TMCP An Bình', code: 'ABB'),
  BankInfo(bin: '970412', shortName: 'PVcomBank', fullName: 'Ngân hàng TMCP Đại Chúng Việt Nam', code: 'PVCB'),
  BankInfo(bin: '970414', shortName: 'MBV', fullName: 'Ngân hàng TNHH MTV Việt Nam Hiện Đại', code: 'MBV'),
  BankInfo(bin: '546034', shortName: 'CAKE', fullName: 'TMCP Việt Nam Thịnh Vượng - Ngân hàng số CAKE', code: 'CAKE'),
  BankInfo(bin: '546035', shortName: 'Ubank', fullName: 'TMCP Việt Nam Thịnh Vượng - Ngân hàng số Ubank', code: 'UBANK'),
  BankInfo(bin: '963388', shortName: 'Timo', fullName: 'Ngân hàng số Timo by BVBank', code: 'TIMO'),
  BankInfo(bin: '970406', shortName: 'Vikki', fullName: 'Ngân hàng Số Vikki', code: 'VIKKI'),
  BankInfo(bin: '970424', shortName: 'Shinhan Bank', fullName: 'Ngân hàng TNHH MTV Shinhan Việt Nam', code: 'SHBVN'),
  BankInfo(bin: '970457', shortName: 'Woori Bank', fullName: 'Ngân hàng TNHH MTV Woori Việt Nam', code: 'WVN'),
  BankInfo(bin: '458761', shortName: 'HSBC', fullName: 'Ngân hàng TNHH MTV HSBC Việt Nam', code: 'HSBC'),
  BankInfo(bin: '970410', shortName: 'Standard Chartered', fullName: 'Ngân hàng TNHH MTV Standard Chartered Việt Nam', code: 'SCVN'),
];

BankInfo? findBankByBin(String bin) {
  for (final bank in kVietnamBanks) {
    if (bank.bin == bin) return bank;
  }
  return null;
}
