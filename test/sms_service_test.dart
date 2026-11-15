import 'package:flutter_test/flutter_test.dart';
import 'package:digiledger/services/sms_service.dart';

void main() {
  group('SmsService.isFinancialSms', () {
    test('identifies debit and credit financial messages', () {
      const sms1 = 'Dear SBI User, your A/c ending 4589 is debited by Rs.450.00 on 15-Nov-26 at Starbucks via UPI. Ref No: 123456789. Bal: Rs.5240.00';
      expect(SmsService.isFinancialSms('AD-SBIPIN', sms1), isTrue);

      const sms2 = 'INR 1,200.00 debited from A/C **8912 on 15/11/26 to VPA uber@axisbank. UPI Ref 987654321.';
      expect(SmsService.isFinancialSms('VM-HDFCBK', sms2), isTrue);

      const sms3 = 'Your A/C ending 3321 has been credited with Rs 5000.00 on 15-Nov-26 by Salary. Available Bal: Rs 45000.00';
      expect(SmsService.isFinancialSms('AXISBK', sms3), isTrue);
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

    test('extracts credit / income transaction correctly', () {
      const sms = 'Your A/C ending 3321 has been credited with Rs 5000.00 on 15-Nov-26 by Salary. Available Bal: Rs 45000.00';
      final result = SmsService.parseSms('AXISBK', sms);

      expect(result, isNotNull);
      expect(result!.amount, equals(5000.00));
      expect(result.type, equals('Income'));
      expect(result.accountEnding, equals('3321'));
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

    test('falls back to friendly bank name when merchant not explicitly specified', () {
      const sms = 'Your a/c ending 1234 is debited by Rs. 200.00 on 12-Nov-26. Avl Bal Rs. 800.00';
      final result = SmsService.parseSms('VM-HDFCBK', sms);

      expect(result, isNotNull);
      expect(result!.amount, equals(200.00));
      expect(result.merchant, equals('HDFC Bank'));
      expect(result.type, equals('Expense'));
    });
  });
}
