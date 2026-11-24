import 'package:material_ui/material_ui.dart';

// Lightweight, type-safe English (default) & Vietnamese localization for Mâm.
// Zero codegen dependencies; switches instantaneously across the entire app.

enum AppLanguage {
  en('en', 'English'),
  vi('vi', 'Tiếng Việt');

  const AppLanguage(this.code, this.label);
  final String code;
  final String label;

  static AppLanguage fromCode(String? code) {
    return code == 'vi' ? AppLanguage.vi : AppLanguage.en;
  }
}

class MamStrings {
  const MamStrings(this.language);

  final AppLanguage language;

  bool get isVi => language == AppLanguage.vi;
  String t(String en, String vi) => isVi ? vi : en;

  // Common
  String get appName => 'Mâm';
  String get cancel => t('Cancel', 'Hủy');
  String get save => t('Save', 'Lưu');
  String get add => t('Add', 'Thêm');
  String get edit => t('Edit', 'Sửa');
  String get delete => t('Delete', 'Xóa');
  String get apply => t('Apply', 'Áp dụng');
  String get host => t('Host', 'Chủ xị');
  String get me => t('Me', 'Tôi');
  String get paid => t('Paid', 'Đã trả');
  String get settled => t('Settled', 'Đã xong');
  String get archived => t('Archived', 'Lưu trữ');
  String get undo => t('Undo', 'Hoàn tác');

  // Home
  String get menuTooltip => t('Menu', 'Menu');
  String get homeBtn => t('Home', 'Trang chủ');
  String get settings => t('Settings', 'Cài đặt');
  String get panelSubtitle =>
      t('Split bills & VietQR', 'Chia bill & VietQR');
  String get syncStatusLabel => t('Sync status', 'Trạng thái đồng bộ');
  String get tapToSync => t('Tap to sync now', 'Chạm để đồng bộ ngay');
  String get tapToConfigureSync =>
      t('Tap to sign in & sync', 'Chạm để đăng nhập & đồng bộ');
  String get searchBillsHint => t(
        'Search bills, members, DD/MM/YY...',
        'Tìm bill, thành viên, DD/MM/YY...',
      );
  String get clearSearch => t('Clear search', 'Xóa tìm kiếm');
  String get archiveAction => t('Archive', 'Lưu trữ');
  String get restoreAction => t('Restore', 'Khôi phục');
  String billArchivedSnack(String title) =>
      isVi ? 'Đã lưu trữ "$title"' : 'Archived "$title"';
  String billRestoredSnack(String title) =>
      isVi ? 'Đã khôi phục "$title"' : 'Restored "$title"';
  String archivedDivider(int count) =>
      isVi ? 'Đã lưu trữ ($count)' : 'Archived ($count)';
  String get syncLocal => t('Local', 'Local');
  String get syncSynced => t('Synced', 'Đã sync');
  String get syncPending => t('Pending', 'Chờ sync');
  String get syncSyncing => t('Syncing', 'Đang sync');
  String get syncError => t('Sync error', 'Lỗi sync');

  String get allSettledTitle =>
      t('All bills settled', 'Tất cả bill đã thu đủ');
  String get uncollectedTitle => t('Uncollected', 'Còn chưa thu');
  String toRefundBanner(String formatted) =>
      isVi ? 'Cần trả lại: $formatted' : 'To refund: $formatted';
  String get allSettledBadge => t('All clear', 'Đã chốt đủ');
  String pendingBillsBadge(int count) =>
      isVi ? '$count bill đang chờ' : '$count pending';

  String filterAll(int count) => isVi ? 'Tất cả ($count)' : 'All ($count)';
  String filterPending(int count) =>
      isVi ? 'Chưa đủ ($count)' : 'Pending ($count)';
  String filterSettled(int count) =>
      isVi ? 'Đã xong ($count)' : 'Settled ($count)';
  String filterArchived(int count) =>
      isVi ? 'Lưu trữ ($count)' : 'Archived ($count)';

  String get equalSplitLabel => t('Equal split', 'Chia đều');
  String itemsCount(int count) =>
      isVi ? '$count món' : '$count ${count == 1 ? 'item' : 'items'}';
  String paidProgress(int paidCount, int total) =>
      isVi ? '$paidCount/$total đã trả' : '$paidCount/$total paid';

  String get emptyAll => t(
        'No bills yet. Tap "+" below to create your first bill.',
        'Chưa có hóa đơn nào. Bấm nút "+" bên dưới để tạo hóa đơn đầu tiên.',
      );
  String get emptyPending => t(
        'All caught up! No pending bills left.',
        'Không còn bill nào đang chờ thanh toán.',
      );
  String get emptySettled => t(
        'No settled bills yet.',
        'Chưa có bill nào hoàn tất.',
      );
  String get emptyArchived => t(
        'No archived bills yet. Swipe left on a bill to archive it.',
        'Chưa có bill lưu trữ. Vuốt trái vào 1 bill để lưu trữ.',
      );
  String emptySearch(String query) => isVi
      ? 'Không tìm thấy bill nào khớp "$query".'
      : 'No bills match "$query".';

  String get quickEqualBtn => t('Equal split', 'Chia đều');
  String get newBillBtn => t('New bill', 'Tạo bill mới');
  String get deleteBillTitle => t('Delete bill?', 'Xóa hóa đơn?');
  String deleteBillConfirm(String title) => isVi
      ? 'Xóa "$title" khỏi lịch sử trên các thiết bị?'
      : 'Delete "$title" from history across synced devices?';

  // Quick Equal
  String get quickEqualTitle => t('Quick Equal Split', 'Chia đều siêu tốc');
  String get singlePayerMode => t('Single payer', '1 người trả');
  String get multiPayerMode => t('Multiple payers', 'Nhiều người ứng');
  String get paidUpfrontLabel => t('Paid upfront', 'Đã ứng');
  String get upfrontBtn => t('Upfront', 'Tiền ứng');
  String get upfrontSheetTitle => t('Upfront payments', 'Ai đã ứng tiền trước?');
  String get upfrontSheetHint => t(
        'Enter how much each person already paid. Host collects and refunds the net difference.',
        'Nhập số tiền mỗi người đã trả trước. Chủ xị sẽ thu và trả lại phần chênh lệch.',
      );
  String autoTotalFromUpfront(String formatted) =>
      isVi ? 'Tổng tiền đã ứng: $formatted' : 'Total from upfront: $formatted';
  String get enterPositiveUpfront => t(
        'Please enter at least one upfront amount greater than 0',
        'Vui lòng nhập ít nhất 1 khoản đã ứng lớn hơn 0',
      );
  String get mealName => t('Meal / Event name', 'Tên bữa ăn');
  String get mealHint => t('e.g. Morning coffee', 'vd: Cà phê sáng');
  String get totalBillVnd => t('Total bill (VND)', 'Tổng tiền hóa đơn (VNĐ)');
  String get enterPositiveTotal => t(
        'Please enter a total amount greater than 0đ',
        'Vui lòng nhập tổng số tiền lớn hơn 0đ',
      );
  String participantsCount(int n) =>
      isVi ? 'Người tham gia ($n)' : 'Participants ($n)';
  String get addPersonHint => t('Add person name...', 'Thêm tên người...');
  String get tapToChangeHost => t(
        'Tap a chip to change who is the Host.',
        'Chạm vào tên để đổi người làm Chủ xị.',
      );
  String get roundingLabel => t('Rounding', 'Làm tròn số tiền');
  String get roundNone => t('None', 'Không');
  String get roundNearest1k => t('Nearest 1k', 'Gần 1k');
  String get roundCeil1k => t('Up 1k', 'Lên 1k');
  String get eachPersonPays => t('Each person pays:', 'Mỗi người trả:');
  String roundingDeltaShort(String signed) =>
      isVi ? 'Lệch làm tròn: $signed' : 'Rounding diff: $signed';
  String get createResultQr =>
      t('Create result & VietQR', 'Tạo kết quả & VietQR');
  String get equalTotalItemName =>
      t('Equal split total', 'Tổng hóa đơn chia đều');
  String guestLabel(int n) => isVi ? 'Bạn $n' : 'Guest $n';

  // Bill Input
  String get inputBillTitle => t('Enter bill', 'Nhập hóa đơn');
  String get editBillTitle => t('Edit bill', 'Sửa hóa đơn');
  String get scanOcrTitle => t('Scan receipt (AI OCR)', 'Scan ảnh hóa đơn (AI OCR)');
  String get scanOcrSubtitle => t(
        'Take a photo or try VN demo receipts',
        'Chụp bill thật hoặc thử hóa đơn mẫu VN',
      );
  String get restaurantName => t('Restaurant / Meal', 'Tên quán / Bữa ăn');
  String get billDateLabel => t('Bill date', 'Ngày hóa đơn');
  String get itemsList => t('Items', 'Danh sách món');
  String subtotalText(String formatted) =>
      isVi ? 'Tạm tính: $formatted' : 'Subtotal: $formatted';
  String itemHint(int index) => isVi ? 'Tên món #$index' : 'Item #$index';
  String get defaultItemName => t('Item', 'Món ăn');
  String get qtyLabel => t('Qty', 'SL');
  String get unitPriceLabel => t('Unit price', 'Đơn giá');
  String get lineTotalLabel => t('Line total', 'Thành tiền');
  String lineTotalInline(String formatted) =>
      isVi ? 'Thành tiền: $formatted' : 'Line total: $formatted';
  String get addItemBtn => t('Add item', 'Thêm món');
  String get feesAndDiscounts =>
      t('Tax, fees & discounts', 'Thuế, phụ phí & giảm giá');
  String get vatLabel => t('VAT (VND)', 'VAT (VNĐ)');
  String get serviceChargeLabel => t('Service charge (VND)', 'Phí phục vụ (VNĐ)');
  String get shippingLabel => t('Shipping (VND)', 'Tiền ship (VNĐ)');
  String get shipFlat => t('Equal', 'Đều');
  String get shipProRata => t('Pro-rata', 'Tỷ lệ');
  String get billDiscountLabel =>
      t('Bill voucher / discount (VND)', 'Giảm giá / Voucher toàn bill (VNĐ)');
  String get ocrTotalLabel => t(
        'Printed bill total for reconciliation (optional)',
        'Tổng in trên bill để đối chiếu (không bắt buộc)',
      );
  String get needOneItem => t(
        'Add at least 1 item with amount > 0đ',
        'Cần ít nhất 1 món có giá trị > 0đ',
      );
  String ocrMatched(String total) => isVi
      ? 'Khớp tổng in trên bill ($total)'
      : 'Matches printed bill total ($total)';
  String ocrMismatch(String diff, String total) => isVi
      ? 'Lệch $diff so với tổng bill ($total)'
      : 'Off by $diff vs printed total ($total)';
  String get grandTotal => t('Grand total', 'Tổng cộng');
  String get nextAssign => t('Next: Assign', 'Tiếp: Gán món');

  // Split Assign
  String get assignTitle => t('Fast Item Assign', 'Gán món siêu tốc');
  String get groupsBtn => t('Groups', 'Nhóm');
  String get addPersonTooltip => t('Add person', 'Thêm người');
  String assignGuide(String name) => isVi
      ? 'Chạm vào món để gán cho $name · Giữ lâu để chọn nhiều người'
      : 'Tap items to assign to $name · Long-press for multi-select';
  String itemDiscountApplied(String amount) => isVi
      ? 'Đã trừ giảm riêng $amount'
      : 'Item discount -$amount applied';
  String get unassigned => t('Unassigned', 'Chưa gán');
  String get splitAllTable => t('All', 'Cả bàn');
  String unassignedSummary(int count, String total) => isVi
      ? 'Còn $count món ($total) chưa gán'
      : '$count unassigned ${count == 1 ? 'item' : 'items'} ($total)';
  String allAssignedSummary(int count) => isVi
      ? 'Đã gán đủ tất cả $count món'
      : 'All $count items assigned';
  String get splitRemainingAll => t('Split all', 'Chia cả bàn');
  String get saveAndViewResult =>
      t('Save & View result', 'Lưu & Xem kết quả');
  String quickSplitItem(String name) =>
      isVi ? 'Chia nhanh: $name' : 'Quick split: $name';
  String get addPersonDialogTitle =>
      t('Add person to table', 'Thêm người vào mâm');
  String get personNameHint => t('Name (e.g. Alex)', 'Tên (vd: Trang)');
  String get pickGroupTitle => t('Choose saved group', 'Chọn nhóm hay đi ăn');
  String get unassignedDialogTitle => t('Unassigned items left', 'Còn món chưa gán');
  String unassignedDialogBody(int count, String total) => isVi
      ? 'Còn $count món ($total) chưa chọn người ăn.'
      : '$count ${count == 1 ? 'item' : 'items'} ($total) have no one assigned yet.';
  String get backToAssign => t('Go back', 'Quay lại gán');
  String get continueAnyway => t('Continue', 'Vẫn tiếp tục');

  // Result & Receipt
  String get resultTitle => t('Result', 'Kết quả');
  String get billNotFound => t('Bill not found.', 'Không tìm thấy hóa đơn.');
  String roundingDeltaHost(bool positive, String signed) => isVi
      ? 'Chênh lệch làm tròn: Chủ xị ${positive ? 'dư' : 'bù'} $signed'
      : 'Rounding diff: Host ${positive ? 'keeps' : 'covers'} $signed';
  String get noBankAccountTap => t(
        'No receiving bank account — Tap to add',
        'Chưa có STK nhận tiền — Chạm để thêm',
      );
  String receivingBank(String bank, String accNo) =>
      isVi ? 'Nhận tiền: $bank · $accNo' : 'Receive via: $bank · $accNo';
  String get perPersonDetails => t('Per-person breakdown', 'Chi tiết từng người');
  String tapForDetails(int itemCount) => isVi
      ? '$itemCount món · Chạm xem chi tiết'
      : '$itemCount ${itemCount == 1 ? 'item' : 'items'} · Tap for details';
  String get proRataLine => t(
        'Tax / Service / Discount (pro-rata)',
        'Thuế / Phí / Giảm giá (pro-rata)',
      );
  String get flatShipLine => t('Shipping (equal split)', 'Tiền ship (chia đều)');
  String get markPaid => t('Mark paid', 'Tick đã trả');
  String get markRefunded => t('Mark refunded', 'Tick đã trả lại');
  String get refunded => t('Refunded', 'Đã trả lại');
  String get refundBadge => t('Refund', 'Trả lại');
  String refundAmountLabel(String amount) =>
      isVi ? 'Trả lại $amount' : 'Refund $amount';
  String shareAndUpfront(String share, String paid) =>
      isVi ? 'Phần $share · Đã ứng $paid' : 'Share $share · Paid $paid';
  String hostSettlementSummary(String collect, String refund) => isVi
      ? 'Chủ xị thu: $collect · Trả lại: $refund'
      : 'Host collects: $collect · Refunds: $refund';
  String netQrBreakdown(String share, String paid) =>
      isVi ? 'Phần $share − Đã ứng $paid' : 'Share $share − Paid $paid';
  String get personQrBtn => t('VietQR', 'VietQR riêng');
  String get exportSummaryBtn =>
      t('Export Summary Receipt', 'Xuất Receipt Card tổng');
  String get pickBankTitle =>
      t('Choose receiving bank', 'Chọn tài khoản nhận tiền');
  String get receiptPreviewTitle =>
      t('Receipt Card Preview', 'Xem trước Receipt Card');
  String get exportingPng => t('Exporting PNG...', 'Đang xuất ảnh...');
  String get sharePngBtn => t(
        'Share PNG (Zalo / Messenger)',
        'Chia sẻ ảnh PNG (Zalo / Messenger)',
      );
  String exportError(Object err) =>
      isVi ? 'Không xuất được ảnh: $err' : 'Failed to export image: $err';
  String get addBankFirst => t(
        'Please add a bank account in Settings to generate VietQR',
        'Vui lòng thêm tài khoản ngân hàng trong Cài đặt để tạo VietQR',
      );
  String personQrTitle(String name) =>
      isVi ? 'VietQR cho $name' : 'VietQR for $name';
  String get copyAccNo => t('Copy account', 'Copy STK');
  String get copyNote => t('Copy note', 'Copy ND');
  String get copiedAccNo => t('Account number copied', 'Đã sao chép số tài khoản');
  String get copiedNote => t('Transfer note copied', 'Đã sao chép nội dung CK');
  String get sharePersonQrBtn =>
      t('Share personal VietQR (PNG)', 'Gửi thẻ VietQR riêng (PNG)');

  // Receipt Card printable labels
  String get receiptHeaderTag => t('BILL SUMMARY', 'PHIẾU CHIA BILL');
  String get receiptItemsSubtotal => t('Items subtotal', 'Tiền món');
  String get receiptVat => t('VAT', 'Thuế VAT');
  String get receiptService => t('Service charge', 'Phí phục vụ');
  String receiptShipping(bool isFlat) => isVi
      ? 'Tiền ship (${isFlat ? 'chia đều' : 'tỷ lệ'})'
      : 'Shipping (${isFlat ? 'equal' : 'pro-rata'})';
  String get receiptDiscount => t('Bill discount', 'Giảm giá toàn bill');
  String get receiptGrandTotal => t('TOTAL', 'TỔNG CỘNG');
  String receiptRoundingNote(String signed) => isVi
      ? 'Làm tròn 1.000đ · Chênh lệch: $signed'
      : 'Rounded to 1,000đ · Diff: $signed';
  String get scanVietQrPay =>
      t('SCAN VIETQR TO PAY', 'QUÉT VIETQR THANH TOÁN');
  String shareOfPerson(String name) =>
      isVi ? 'Phần của $name' : "$name's share";
  String notePrefix(String note) => isVi ? 'ND: $note' : 'Note: $note';
  String moreItemsCount(int count) =>
      isVi ? '+ $count món khác' : '+ $count more items';

  String totalBillCurrency(String code) =>
      isVi ? 'Tổng tiền hóa đơn ($code)' : 'Total bill ($code)';
  String vatLabelCurrency(String code) => 'VAT ($code)';
  String serviceChargeLabelCurrency(String code) =>
      isVi ? 'Phí phục vụ ($code)' : 'Service charge ($code)';
  String shippingLabelCurrency(String code) =>
      isVi ? 'Tiền ship ($code)' : 'Shipping ($code)';
  String billDiscountLabelCurrency(String code) => isVi
      ? 'Giảm giá / Voucher toàn bill ($code)'
      : 'Bill voucher / discount ($code)';
  String roundNearestStep(String stepLabel) =>
      isVi ? 'Gần $stepLabel' : 'Nearest $stepLabel';
  String roundCeilStep(String stepLabel) =>
      isVi ? 'Lên $stepLabel' : 'Round up $stepLabel';
  String receiptRoundingNoteStep(String stepLabel, String signed) => isVi
      ? 'Làm tròn $stepLabel · Chênh lệch: $signed'
      : 'Rounded to $stepLabel · Diff: $signed';

  // Currency & Input format settings
  String get currencyAndFormatSection =>
      t('Currency & Number Format', 'Tiền tệ & Định dạng số');
  String get currencyLabel => t('Currency', 'Đơn vị tiền tệ');
  String get amountFormatLabel =>
      t('Amount input format', 'Định dạng nhập số tiền');
  String get formatAuto => t('Auto', 'Tự động');
  String get formatDotThousands => '1.000';
  String get formatUsdDecimal => '1.00';
  String get formatPlain => t('Plain', 'Thô');
  String get formatPreviewLabel => t('Input preview', 'Xem trước');
  String get formatAtmHint => t(
        'ATM/POS mode: type 100 → 1.00, 312592 → 3,125.92',
        'Kiểu ATM/POS: gõ 100 → 1.00, 312592 → 3,125.92',
      );
  String get formatDotHint => t(
        'Grouped: 1000 → 1.000, 5923892 → 5.923.892',
        'Tự phân tách: 1000 → 1.000, 5923892 → 5.923.892',
      );
  String get formatPlainHint => t(
        'Digits only without separators',
        'Chỉ nhập số không phân tách',
      );

  // Settings
  String get languageLabel => t('Language', 'Ngôn ngữ');
  String get bankSection => t('Bank accounts (VietQR)', 'Tài khoản ngân hàng (VietQR)');
  String get addBankBtn => t('Add bank', 'Thêm STK');
  String get noBankEmpty => t(
        'No receiving bank account yet. Add one to generate VietQR codes automatically.',
        'Chưa có tài khoản nhận tiền. Thêm 1 STK để tạo mã VietQR tự động.',
      );
  String get defaultBadge => t('Default', 'Mặc định');
  String get setDefault => t('Set as default', 'Đặt làm mặc định');
  String get groupsSection => t('Saved dining groups', 'Nhóm hay đi ăn cùng');
  String get addGroupBtn => t('Add group', 'Thêm nhóm');
  String get noGroupsEmpty => t('No saved groups yet.', 'Chưa có nhóm nào.');
  String get defaultsSection => t('Splitting defaults', 'Mặc định chia tiền');
  String get defaultRoundingLabel => t('Default rounding', 'Làm tròn mặc định');
  String get defaultShipLabel =>
      t('Default shipping split', 'Chia tiền ship mặc định');
  String get shipFlatFull => t('Equal split', 'Chia đều');
  String get shipProRataFull => t('Pro-rata', 'Theo tỷ lệ');
  String get transferTemplateLabel =>
      t('Transfer note template', 'Mẫu nội dung chuyển khoản');
  String get transferTemplateHelp => t(
        'Use {name} (person) and {title} (bill title)',
        'Dùng {name} (tên người) và {title} (tên bill)',
      );
  String get addBankTitle => t('Add bank account', 'Thêm tài khoản ngân hàng');
  String get editBankTitle => t('Edit bank account', 'Sửa tài khoản');
  String get searchBankHint =>
      t('Search bank (VCB, TCB, MB, Timo...)', 'Tìm ngân hàng (VCB, TCB, MB, Timo...)');
  String get accountNoLabel => t('Account number', 'Số tài khoản');
  String get accountHolderLabel =>
      t('Account holder name (optional)', 'Tên chủ tài khoản (tùy chọn)');
  String get setAsDefaultAccount =>
      t('Set as default account', 'Đặt làm tài khoản mặc định');
  String get saveAccountBtn => t('Save account', 'Lưu tài khoản');
  String get addGroupTitle => t('Add dining group', 'Thêm nhóm bạn');
  String get editGroupTitle => t('Edit dining group', 'Sửa nhóm bạn');
  String get groupNameLabel => t('Group name', 'Tên nhóm');
  String get membersLabel =>
      t('Members (comma-separated)', 'Thành viên (cách nhau bởi dấu phẩy)');
  String get firstMemberIsHost => t(
        'First person defaults to Host',
        'Người đầu tiên mặc định là Chủ xị',
      );

  // Sync Card
  String get syncSectionTitle =>
      t('iOS ↔ Android Sync (Supabase)', 'Đồng bộ iOS ↔ Android (Supabase)');
  String get syncUnconfiguredBody => t(
        'Running in Local-first mode (100% offline). To enable cloud sync between iOS & Android, build with --dart-define=SUPABASE_URL=... and SUPABASE_ANON_KEY=...',
        'Đang chạy chế độ Local-first (offline 100%). Để bật đồng bộ cloud giữa iOS & Android, build app kèm --dart-define=SUPABASE_URL=... và SUPABASE_ANON_KEY=...',
      );
  String get neverSynced => t('Not synced yet', 'Chưa đồng bộ lần nào');
  String lastSyncedOn(String date) =>
      isVi ? 'Đồng bộ gần nhất: $date' : 'Last synced: $date';
  String get syncNowBtn => t('Sync now', 'Đồng bộ ngay');
  String get signOutBtn => t('Sign out', 'Đăng xuất');
  String get signInTitle =>
      t('Sign in to sync iOS ↔ Android', 'Đăng nhập đồng bộ iOS ↔ Android');
  String get emailLabel => 'Email';
  String get passwordLabel => t('Password', 'Mật khẩu');
  String get invalidAuthInput => t(
        'Enter a valid email and password (≥ 6 characters)',
        'Nhập email hợp lệ và mật khẩu ≥ 6 ký tự',
      );
  String get signInBtn => t('Sign in', 'Đăng nhập');
  String get signUpBtn => t('Sign up', 'Tạo TK');
  String get signUpCheckEmail => t(
        'Account created! Check your email to confirm, then sign in.',
        'Đã tạo tài khoản! Kiểm tra email để xác nhận rồi đăng nhập.',
      );
  String get working => t('Working...', 'Đang xử lý...');
  String get authErrInvalidCredentials => t(
        'Incorrect email or password. Please check and try again.',
        'Email hoặc mật khẩu chưa đúng. Vui lòng kiểm tra lại.',
      );
  String get authErrEmailNotConfirmed => t(
        'Your email is not confirmed yet. Please check your inbox.',
        'Email chưa được xác nhận. Vui lòng kiểm tra hộp thư của bạn.',
      );
  String get authErrUserExists => t(
        'This email is already registered. Try signing in instead.',
        'Email này đã được đăng ký. Hãy thử đăng nhập.',
      );
  String get authErrWeakPassword => t(
        'Password is too weak. Please use at least 6 characters.',
        'Mật khẩu quá yếu. Vui lòng dùng ít nhất 6 ký tự.',
      );
  String get authErrInvalidEmail => t(
        'Please enter a valid email address.',
        'Vui lòng nhập địa chỉ email hợp lệ.',
      );
  String get authErrRateLimited => t(
        'Too many attempts. Please wait a moment and try again.',
        'Bạn thử quá nhiều lần. Vui lòng đợi một lát rồi thử lại.',
      );
  String get authErrNetwork => t(
        'Network error. Please check your internet connection.',
        'Lỗi kết nối mạng. Vui lòng kiểm tra internet và thử lại.',
      );
  String get authErrGeneric => t(
        'Could not sign in right now. Please try again.',
        'Không thể đăng nhập lúc này. Vui lòng thử lại.',
      );

  // OCR Sheet
  String get ocrSheetTitle => t('Scan receipt (AI OCR)', 'Scan hóa đơn (AI OCR)');
  String get takePhotoTitle => t('Take receipt photo', 'Chụp ảnh hóa đơn');
  String get takePhotoSub =>
      t('Sent via Edge Function /scan-bill', 'Gửi qua Edge Function /scan-bill');
  String get pickPhotoTitle =>
      t('Choose receipt from gallery', 'Chọn ảnh hóa đơn từ máy');
  String get pickPhotoSubConfigured => t(
        'Auto-extracted via Gemini Flash',
        'Trích xuất tự động bằng Gemini Flash',
      );
  String get pickPhotoSubUnconfigured => t(
        'Requires Supabase OCR proxy (try demo presets below)',
        'Cần cấu hình Supabase để gọi AI thật (dùng mẫu Demo bên dưới)',
      );
  String get demoPresetsHeading => t(
        'Try VN sample receipts (Offline Demo)',
        'Thử nhanh hóa đơn mẫu VN (Demo Offline)',
      );
  String get ocrNeedsSupabase => t(
        'Supabase OCR proxy not configured — pick a Demo receipt below to test the OCR flow.',
        'Chưa kết nối Supabase OCR proxy — hãy chọn 1 hóa đơn mẫu Demo để trải nghiệm luồng OCR.',
      );
  String get ocrNeedsLogin => t(
        'Please sign in under Settings before scanning with AI OCR.',
        'Vui lòng đăng nhập trong Cài đặt trước khi scan OCR.',
      );
  String get ocrScanningTitle => t(
        'Reading receipt with AI...',
        'Đang đọc hóa đơn bằng AI...',
      );
  String get ocrScanningSub => t(
        'Extracting items, totals & currency. Please wait a moment.',
        'Đang trích xuất món ăn, tổng tiền & tiền tệ. Vui lòng đợi giây lát.',
      );
  String get ocrErrorTitle => t('Could not scan receipt', 'Không thể quét hóa đơn');
  String get ocrRetryHint =>
      t('Choose another photo or try again below.', 'Chọn ảnh khác hoặc thử lại bên dưới.');

  // Bottom Navigation & Create Action Sheet
  String get navHome => t('Home', 'Trang chủ');
  String get navMembers => t('Members', 'Danh bạ');
  String get navSync => t('Sync', 'Đồng bộ');
  String get navSettings => t('Settings', 'Cài đặt');
  String get createActionTooltip => t('Create bill', 'Tạo hóa đơn');
  String get createSheetTitle => t('Create new', 'Tạo mới');
  String get createEqualSub =>
      t('Split evenly or with multiple upfront payers', 'Chia đều nhanh hoặc nhiều người ứng trước');
  String get createNewBillSub =>
      t('Enter items manually & assign per person', 'Nhập từng món & gán cho từng người');
  String get createScanTitle => t('Scan receipt', 'Quét hóa đơn');
  String get createScanSub =>
      t('Snap or pick a receipt photo for AI OCR', 'Chụp hoặc chọn ảnh bill để AI tự đọc');
  String get syncSignInPrompt => t(
        'Sign in under Settings to sync across devices.',
        'Đăng nhập trong Cài đặt để đồng bộ giữa các thiết bị.',
      );
  String get syncAlreadyRunning => t('Sync in progress...', 'Đang đồng bộ...');
  String get syncDoneSnack => t('Synced with cloud', 'Đã đồng bộ dữ liệu');

  // Persistent Members Directory (Danh bạ thành viên)
  String get membersTitle => t('Members', 'Danh bạ thành viên');
  String get addMemberBtn => t('Add member', 'Thêm người');
  String get addMemberTitle => t('Add member', 'Thêm thành viên');
  String get editMemberTitle => t('Rename member', 'Đổi tên thành viên');
  String get memberNameLabel => t('Member name', 'Tên thành viên');
  String get searchMembersHint => t('Search members...', 'Tìm thành viên...');
  String get emptyMembers => t(
        'No saved members yet. Add friends here or when splitting a bill.',
        'Chưa có thành viên nào. Thêm bạn bè tại đây hoặc ngay khi chia bill.',
      );
  String get fromDirectoryLabel => t('From contacts', 'Chọn từ danh bạ');
  String get pickOrAddMembersTitle =>
      t('Select or add members', 'Chọn hoặc thêm thành viên');
  String get savedMembersHint =>
      t('Tap to include in this bill', 'Chạm để thêm vào bill này');
  String get newMemberQuickHint =>
      t('Add new person (saved to contacts)...', 'Thêm người mới (tự lưu danh bạ)...');
  String get deleteMemberTitle => t('Remove member?', 'Xóa thành viên?');
  String deleteMemberConfirm(String name) => isVi
      ? 'Xóa "$name" khỏi danh bạ? Lịch sử các bill cũ vẫn được giữ nguyên.'
      : 'Remove "$name" from contacts? Existing bill history will be preserved.';
  String get memberClearedBadge => t('Settled', 'Đã chốt');
  String memberOwesLabel(String amount) =>
      isVi ? 'Còn nợ $amount' : 'Owes $amount';
  String memberRefundLabel(String amount) =>
      isVi ? 'Cần hoàn $amount' : 'Refund $amount';
  String memberPendingBillsCount(int count) =>
      isVi ? '$count bill chưa chốt' : '$count pending ${count == 1 ? 'bill' : 'bills'}';

  // Notes, Trips & Edit Quick Equal
  String get noteLabel => t('Note (optional)', 'Ghi chú (tùy chọn)');
  String get noteHint =>
      t('e.g. Birthday dinner, table 5...', 'vd: Sinh nhật phòng, bàn 5...');
  String get tripLabel =>
      t('Trip / Event (optional)', 'Chuyến đi / Sự kiện (tùy chọn)');
  String get tripHint =>
      t('e.g. Da Lat 24/11', 'vd: Đà Lạt 24/11');
  String get saveChangesBtn => t('Save changes', 'Lưu thay đổi');

  // Per-Person Debt Ledger (Uncollected) & Combined VietQR
  String get viewByPersonHint => t('View by person', 'Xem theo người');
  String get personLedgerTitle =>
      t('Unsettled by person', 'Công nợ theo người');
  String get noUnsettledPeople =>
      t('Everyone is settled!', 'Mọi người đã tất toán hết!');
  String get combinedQrBtn => t('Combined QR', 'QR gộp');
  String get markAllPaidBtn => t('Mark all paid', 'Đã trả hết');
  String get markAllRefundedBtn => t('Mark all refunded', 'Đã hoàn hết');
  String markedAllPaidSnack(String name, int billCount) => isVi
      ? 'Đã chốt tất cả $billCount bill của $name'
      : 'Settled all $billCount ${billCount == 1 ? 'bill' : 'bills'} for $name';
  String combinedBillsTitle(int count) =>
      isVi ? 'Gộp $count hóa đơn' : 'Combined ($count ${count == 1 ? 'bill' : 'bills'})';
  String combinedTransferNote(String name, int count) =>
      '$name thanh toan $count bill';
  String get totalToCollectLabel => t('Total to collect', 'Tổng cần thu');
  String get totalToRefundLabel => t('Total to refund', 'Tổng cần hoàn');

  // Trip / Event Settlement
  String get tripsHeading => t('Trips', 'Chuyến đi');
  String get tripSettlementTitle => t('Trip Settlement', 'Tổng kết chuyến đi');
  String tripBillsProgress(int settled, int total) =>
      isVi ? '$settled/$total bill đã xong' : '$settled/$total bills settled';
  String get tripTotalSpend => t('Total spend', 'Tổng chi chuyến đi');
  String get tripPerPersonSection =>
      t('Consolidated settlement', 'Tất toán gộp theo người');
  String get tripBillsSection => t('Bills in this trip', 'Hóa đơn trong chuyến');
  String tripNetTotalLabel(String formatted) =>
      isVi ? 'Tổng cả chuyến: $formatted' : 'Trip total: $formatted';
  String get tripAllSettledPerson => t('All settled', 'Đã tất toán');
  String get emptyTripBills =>
      t('No bills in this trip yet.', 'Chưa có hóa đơn nào trong chuyến đi này.');
}

class MamStringsScope extends InheritedWidget {
  const MamStringsScope({
    super.key,
    required this.strings,
    required super.child,
  });

  final MamStrings strings;

  static MamStrings of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<MamStringsScope>();
    return scope?.strings ?? const MamStrings(AppLanguage.en);
  }

  @override
  bool updateShouldNotify(MamStringsScope oldWidget) =>
      oldWidget.strings.language != strings.language;
}

extension MamStringsContext on BuildContext {
  MamStrings get s => MamStringsScope.of(this);
}
