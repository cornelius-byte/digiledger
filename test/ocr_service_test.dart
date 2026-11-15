import 'package:flutter_test/flutter_test.dart';
import 'package:digiledger/services/ocr_service.dart';

void main() {
  group('OcrService.parseReceiptText', () {
    test('extracts merchant and amount from standard receipt format', () {
      const sampleReceipt = '''
WALMART SUPERCENTER
STORE # 1234
100 MAIN STREET, AUSTIN, TX
TEL: (555) 123-4567

ORGANIC MILK         \$3.99
BREAD                \$2.50
COFFEE BEANS        \$12.99

SUBTOTAL:           \$19.48
TAX:                 \$1.60
TOTAL:              \$21.08

CASH TENDERED:      \$30.00
CHANGE:              \$8.92
2026-05-10 14:22
THANK YOU FOR SHOPPING!
''';

      final result = OcrService.parseReceiptText(sampleReceipt);

      expect(result.hasTextDetected, isTrue);
      expect(result.vendorName, equals('WALMART SUPERCENTER'));
      expect(result.amount, equals(21.08));
      expect(result.date, equals(DateTime(2026, 5, 10)));
    });

    test('extracts amount when keyword is on separate line from price', () {
      const sampleReceipt = '''
STARBUCKS COFFEE
SEATTLE, WA

CAFFE LATTE
BLUEBERRY MUFFIN

SUBTOTAL
8.50
TAX
0.72
GRAND TOTAL
9.22

VISA ENDING IN 1234
''';

      final result = OcrService.parseReceiptText(sampleReceipt);

      expect(result.hasTextDetected, isTrue);
      expect(result.vendorName, equals('STARBUCKS COFFEE'));
      expect(result.amount, equals(9.22));
    });

    test('extracts amount with various currency symbols and formats', () {
      const sampleReceipt = '''
LOCAL CAFE & BISTRO
DUBLIN

LUNCH SPECIAL
AMOUNT DUE: € 34.50
PAID WITH CARD
''';

      final result = OcrService.parseReceiptText(sampleReceipt);

      expect(result.hasTextDetected, isTrue);
      expect(result.vendorName, equals('LOCAL CAFE & BISTRO'));
      expect(result.amount, equals(34.50));
    });

    test('extracts amount when only decimal amounts exist without explicit TOTAL keyword', () {
      const sampleReceipt = '''
BEST BUY
RECEIPT
LAPTOP ACCESSORY
49.99
''';

      final result = OcrService.parseReceiptText(sampleReceipt);

      expect(result.hasTextDetected, isTrue);
      expect(result.vendorName, equals('BEST BUY'));
      expect(result.amount, equals(49.99));
    });

    test('ignores phone numbers, addresses, and generic headings for vendor name', () {
      const sampleReceipt = '''
*** RECEIPT ***
TAX INVOICE
STORE #4421
TRADER JOE'S
800 S ST, CHICAGO
PHONE: 555-0199

APPLES 4.00
TOTAL 4.00
''';

      final result = OcrService.parseReceiptText(sampleReceipt);

      expect(result.vendorName, equals("TRADER JOE'S"));
      expect(result.amount, equals(4.00));
    });

    test('handles empty or blank text gracefully', () {
      final result = OcrService.parseReceiptText('   ');

      expect(result.hasTextDetected, isFalse);
      expect(result.vendorName, isNull);
      expect(result.amount, isNull);
      expect(result.rawText, isEmpty);
    });

    test('extracts compressed total amounts', () {
      const receipt = '''
GROCERY STORE
ITEM 12.00
TOTAL24.50
''';
      final result = OcrService.parseReceiptText(receipt);
      expect(result.amount, equals(24.50));
    });

    test('suggestCategoryName maps correctly', () {
      expect(OcrService.suggestCategoryName('Starbucks', 'Latte'), equals('Food'));
      expect(OcrService.suggestCategoryName('Walmart', 'Milk Eggs'), equals('Groceries'));
      expect(OcrService.suggestCategoryName('Shell Gas Station', 'Fuel'), equals('Transport'));
      expect(OcrService.suggestCategoryName('Zara', 'Jacket'), equals('Clothes'));
      expect(OcrService.suggestCategoryName('CVS Pharmacy', 'Medicine'), equals('Health'));
      expect(OcrService.suggestCategoryName('Best Buy', 'Cable'), equals('Electronics'));
    });

    test('strips merchant label prefixes like Merchant- and Merchant: from vendor name', () {
      const receipt1 = '''
Merchant-Jeeve's
123 Baker Street
COFFEE 4.50
TOTAL \$4.50
''';
      final result1 = OcrService.parseReceiptText(receipt1);
      expect(result1.vendorName, equals("Jeeve's"));
      expect(result1.amount, equals(4.50));

      const receipt2 = '''
Merchant: Jeeve's Cafe
LUNCH 15.00
TOTAL: 15.00
''';
      final result2 = OcrService.parseReceiptText(receipt2);
      expect(result2.vendorName, equals("Jeeve's Cafe"));
      expect(result2.amount, equals(15.00));

      const receipt3 = '''
Store Name: Whole Foods Market
GROCERIES 52.30
TOTAL: \$52.30
''';
      final result3 = OcrService.parseReceiptText(receipt3);
      expect(result3.vendorName, equals('Whole Foods Market'));
      expect(result3.amount, equals(52.30));

      const receipt4 = '''
Vendor - Starbucks Coffee
LATTE 4.75
TOTAL 4.75
''';
      final result4 = OcrService.parseReceiptText(receipt4);
      expect(result4.vendorName, equals('Starbucks Coffee'));
      expect(result4.amount, equals(4.75));
    });

    test('extracts total amount from complex real-world receipt patterns', () {
      // 1. Total alongside cash and change on same line
      const receiptSameLine = '''
SUPERMARKET
TOTAL: \$21.08 CASH: \$30.00 CHANGE: \$8.92
''';
      final r1 = OcrService.parseReceiptText(receiptSameLine);
      expect(r1.amount, equals(21.08));

      // 2. Total with spaces around decimal point from OCR
      const receiptSpacedDot = '''
LOCAL CAFE
TOTAL 21 . 08
''';
      final r2 = OcrService.parseReceiptText(receiptSpacedDot);
      expect(r2.amount, equals(21.08));

      // 3. Integer total with currency symbol
      const receiptInt = '''
BURGER JOINT
MEAL COMBO
TOTAL: \$25
''';
      final r3 = OcrService.parseReceiptText(receiptInt);
      expect(r3.amount, equals(25.0));

      // 4. Total separated across multiple lines with currency note
      const receiptMultiLine = '''
COFFEE SHOP
TOTAL
USD
12.50
''';
      final r4 = OcrService.parseReceiptText(receiptMultiLine);
      expect(r4.amount, equals(12.50));

      // 5. Total with items count where TOTAL ITEMS should not be confused with amount
      const receiptWithItemsCount = '''
DEPARTMENT STORE
TOTAL ITEMS: 3
SUBTOTAL 40.00
TAX 4.00
TOTAL 44.00
''';
      final r5 = OcrService.parseReceiptText(receiptWithItemsCount);
      expect(r5.amount, equals(44.00));

      // 6. OCR zero typo in T0TAL
      const receiptOcrTypo = '''
BAKERY
T0TAL: 16.75
''';
      final r6 = OcrService.parseReceiptText(receiptOcrTypo);
      expect(r6.amount, equals(16.75));

      // 7. European comma as decimal separator
      const receiptEuroComma = '''
PARIS BOUTIQUE
TOTAL 24,50
''';
      final r7 = OcrService.parseReceiptText(receiptEuroComma);
      expect(r7.amount, equals(24.50));
    });
  });
}
