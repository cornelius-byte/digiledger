import 'package:flutter_test/flutter_test.dart';
import 'package:digiledger/services/sms_service.dart';
import 'package:digiledger/database/database_helper.dart';

void main() {
  group('SmsService.isFinancialSms', () {
    test('identifies valid debit expense messages', () {
      const sms1 = 'Dear SBI User, your A/c ending 4589 is debited by Rs.450.00 on 15-Nov-26 at Starbucks via UPI. Ref No: 123456789. Bal: Rs.5240.00';
      expect(SmsService.isFinancialSms('AD-SBIPIN', sms1), isTrue);

      const sms2 = 'INR 1,200.00 debited from A/C **8912 on 15/11/26 to VPA uber@axisbank. UPI Ref 987654321.';
      expect(SmsService.isFinancialSms('VM-HDFCBK', sms2), isTrue);

      const sms3 = 'Paid Rs. 250.00 to Swiggy on 10-Jan-2027 from HDFC Bank A/c 1234.';
      expect(SmsService.isFinancialSms('HDFCBK', sms3), isTrue);
    });

    test('rejects incoming credit / deposit messages', () {
      const sms = 'Your A/C ending 3321 has been credited with Rs 5000.00 on 15-Nov-26 by Salary. Available Bal: Rs 45000.00';
      expect(SmsService.isFinancialSms('AXISBK', sms), isFalse);
    });

    test('rejects recharge messages', () {
      const sms = 'Hi, recharge of Rs. 1099 successfully credited to your Airtel number 8732085468.';
      expect(SmsService.isFinancialSms('AIRTEL', sms), isFalse);
    });

    test('rejects cashback, promotional offer and URL link messages', () {
      const sms = 'Get upto Rs. 200 cashback now! Just recharge via Airtel app https://i.airtel.in/...';
      expect(SmsService.isFinancialSms('AIRTEL', sms), isFalse);
    });

    test('ignores pure OTP and verification codes without transactions', () {
      const otpSms1 = '123456 is your secret OTP for NetBanking login. Do not share this with anyone.';
      expect(SmsService.isFinancialSms('HDFCBK', otpSms1), isFalse);

      const otpSms2 = 'Use OTP 987654 to verify your email address. Valid for 10 minutes.';
      expect(SmsService.isFinancialSms('VERIFY', otpSms2), isFalse);
    });

    test('ignores promotional spam without financial transactions', () {
      const promoSms = 'Recharge now to get 50% extra data and unlimited calls for 28 days! Visit link.';
      expect(SmsService.isFinancialSms('AIRTEL', promoSms), isFalse);
    });
  });

  group('SmsService.parseSms', () {
    test('extracts amount, merchant, type, refId, and category from standard UPI debit SMS', () {
      const sms = 'Dear SBI User, your A/c ending 4589 is debited by Rs.450.00 on 15-Nov-26 at Starbucks via UPI. Ref No: 123456789. Bal: Rs.5240.00';
      final result = SmsService.parseSms('AD-SBIPIN', sms);

      expect(result, isNotNull);
      expect(result!.amount, equals(450.00));
      expect(result.merchant, equals('Starbucks'));
      expect(result.type, equals('Expense'));
      expect(result.suggestedCategory, equals('Food'));
      expect(result.referenceId, equals('123456789'));
      expect(result.accountEnding, equals('4589'));
    });

    test('extracts details from VPA format transaction SMS', () {
      const sms = 'INR 1,200.00 debited from A/C **8912 on 15/11/26 to VPA uber@axisbank. UPI Ref 987654321.';
      final result = SmsService.parseSms('VM-HDFCBK', sms);

      expect(result, isNotNull);
      expect(result!.amount, equals(1200.00));
      expect(result.merchant, equals('Uber'));
      expect(result.type, equals('Expense'));
      expect(result.suggestedCategory, equals('Transport'));
      expect(result.referenceId, equals('987654321'));
      expect(result.accountEnding, equals('8912'));
    });

    test('returns null for credit / income transaction', () {
      const sms = 'Your A/C ending 3321 has been credited with Rs 5000.00 on 15-Nov-26 by Salary. Available Bal: Rs 45000.00';
      final result = SmsService.parseSms('AXISBK', sms);

      expect(result, isNull);
    });

    test('returns null for cashback and recharge promo alerts', () {
      const sms = 'Get upto Rs. 200 cashback now! Just recharge via Airtel app https://i.airtel.in/...';
      final result = SmsService.parseSms('AIRTEL', sms);

      expect(result, isNull);
    });

    test('extracts merchant from info: UPI/... pattern', () {
      const sms = 'Rs. 320.50 debited from A/c XX1234 on 10/11/26. Info: UPI/Swiggy/txn123. Avl Bal: Rs 1500';
      final result = SmsService.parseSms('HDFCBK', sms);

      expect(result, isNotNull);
      expect(result!.amount, equals(320.50));
      expect(result.merchant, equals('Swiggy'));
      expect(result.suggestedCategory, equals('Food'));
      expect(result.type, equals('Expense'));
    });

    test('identifies debit expense messages without currency symbols (decimals and whole numbers)', () {
      const smsWhole = 'Your A/c ending 1234 is debited by 150 on 10-Jan-27 at Starbucks. Ref No: 99887766.';
      final result1 = SmsService.parseSms('AX-SBIUPI-S', smsWhole);
      expect(result1, isNotNull);
      expect(result1!.amount, equals(150.0));
      expect(result1.merchant, equals('Starbucks'));

      const smsDecimal = 'Your A/c ending 1234 is debited by 20.00 on 10-Jan-27 at Starbucks. Ref No: 99887767.';
      final result2 = SmsService.parseSms('AD-SBIUPI-T', smsDecimal);
      expect(result2, isNotNull);
      expect(result2!.amount, equals(20.00));
      expect(result2.merchant, equals('Starbucks'));
    });

    test('handles Service (-S) and Transactional (-T) bank senders correctly', () {
      const sms = 'Your A/c ending 1234 is debited by 100 on 10-Jan-27. Ref No: 12345.';
      final res1 = SmsService.parseSms('AX-SBIUPI-S', sms);
      expect(res1, isNotNull);
      expect(res1!.merchant, equals('State Bank of India'));

      final res2 = SmsService.parseSms('AD-SBIUPI-T', sms);
      expect(res2, isNotNull);
      expect(res2!.merchant, equals('State Bank of India'));

      final res3 = SmsService.parseSms('SBIUPI-S', sms);
      expect(res3, isNotNull);
      expect(res3!.merchant, equals('State Bank of India'));
    });

    test('extracts Refno from UPI/IMPS and Ref No patterns', () {
      const sms1 = 'INR 500 debited from A/C 1234 on 10-Jan-27 to VPA swiggy@icici. UPI Ref No: 887766554433.';
      final res1 = SmsService.parseSms('HDFCBK', sms1);
      expect(res1, isNotNull);
      expect(res1!.referenceId, equals('887766554433'));

      const sms2 = 'INR 250 debited from A/C 1234 on 10-Jan-27. Info: UPI/DR/998877665544.';
      final res2 = SmsService.parseSms('HDFCBK', sms2);
      expect(res2, isNotNull);
      expect(res2!.referenceId, equals('998877665544'));
    });

    test('falls back to friendly bank name when merchant not explicitly specified', () {
      const sms = 'Your a/c ending 1234 is debited by Rs. 200.00 on 12-Nov-26. Avl Bal Rs. 800.00';
      final result = SmsService.parseSms('VM-HDFCBK', sms);

      expect(result, isNotNull);
      expect(result!.amount, equals(200.00));
      expect(result.merchant, equals('HDFC Bank'));
      expect(result.type, equals('Expense'));
    });
  });

  group('DatabaseHelper.isDateInBudgetInterval', () {
    final referenceDate = DateTime(2027, 1, 7); // Thursday Jan 7, 2027 (Week: Sun Jan 3 - Sat Jan 9)

    test('validates Weekly interval correctly', () {
      final inWeekDate = DateTime(2027, 1, 6); // Wednesday Jan 6
      final outOfWeekDate = DateTime(2027, 1, 2); // Saturday Jan 2

      expect(DatabaseHelper.isDateInBudgetInterval(inWeekDate, 'Weekly', refDate: referenceDate), isTrue);
      expect(DatabaseHelper.isDateInBudgetInterval(outOfWeekDate, 'Weekly', refDate: referenceDate), isFalse);
    });

    test('validates Monthly interval correctly', () {
      final inMonthDate = DateTime(2027, 1, 25);
      final outOfMonDate = DateTime(2026, 12, 31);

      expect(DatabaseHelper.isDateInBudgetInterval(inMonthDate, 'Monthly', refDate: referenceDate), isTrue);
      expect(DatabaseHelper.isDateInBudgetInterval(outOfMonDate, 'Monthly', refDate: referenceDate), isFalse);
    });

    test('validates Yearly interval correctly', () {
      final inYearDate = DateTime(2027, 6, 15);
      final outOfYearDate = DateTime(2026, 12, 31);

      expect(DatabaseHelper.isDateInBudgetInterval(inYearDate, 'Yearly', refDate: referenceDate), isTrue);
      expect(DatabaseHelper.isDateInBudgetInterval(outOfYearDate, 'Yearly', refDate: referenceDate), isFalse);
    });
  });
}

