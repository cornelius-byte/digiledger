import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import '../database/database_helper.dart';
import 'currency_service.dart';
import 'notification_service.dart';
import 'ocr_service.dart';

class ParsedSmsTransaction {
  final String sender;
  final String body;
  final double amount;
  final String merchant;
  final String transactionName;
  final String type; // 'Expense' or 'Income'
  final DateTime date;
  final String? suggestedCategory;
  final String? referenceId;
  final String? accountEnding;

  const ParsedSmsTransaction({
    required this.sender,
    required this.body,
    required this.amount,
    required this.merchant,
    required this.transactionName,
    required this.type,
    required this.date,
    this.suggestedCategory,
    this.referenceId,
    this.accountEnding,
  });

  @override
  String toString() =>
      'ParsedSmsTransaction(amount: $amount, merchant: $merchant, type: $type, date: $date, ref: $referenceId)';
}

class SmsService {
  static const MethodChannel _methodChannel = MethodChannel('com.example.digiledger/sms');
  static const EventChannel _eventChannel = EventChannel('com.example.digiledger/sms_stream');

  static final ValueNotifier<bool> isTrackingActive = ValueNotifier<bool>(false);
  static final ValueNotifier<int> newTransactionsCount = ValueNotifier<int>(0);

  static StreamSubscription? _incomingSmsSubscription;
  static bool _isInitialized = false;

  /// Initializes SMS tracking state from database and starts stream if enabled.
  static Future<void> init() async {
    if (_isInitialized) return;
    _isInitialized = true;

    final enabledSetting = await DatabaseHelper.instance.getSetting('sms_tracking_enabled');
    final isEnabled = enabledSetting == null ? true : (enabledSetting == 'true');

    if (isEnabled) {
      final hasPermission = await checkSmsPermission();
      if (hasPermission) {
        isTrackingActive.value = true;
        await DatabaseHelper.instance.saveSetting('sms_tracking_enabled', 'true');
        startIncomingSmsListener();
        await autoScanAllSms(forceFullScan: true);
      } else {
        isTrackingActive.value = false;
      }
    }
  }

  /// First-install / permission prompt method that requests SMS permission and performs a full inbox scan automatically.
  static Future<bool> requestAndAutoSyncOnInstall() async {
    final granted = await requestSmsPermission();
    if (granted) {
      isTrackingActive.value = true;
      await DatabaseHelper.instance.saveSetting('sms_tracking_enabled', 'true');
      startIncomingSmsListener();
      await autoScanAllSms(forceFullScan: true);
      return true;
    } else {
      isTrackingActive.value = false;
      await DatabaseHelper.instance.saveSetting('sms_tracking_enabled', 'false');
      return false;
    }
  }

  /// Automatically scans both pending background SMS messages and past inbox messages.
  static Future<int> autoScanAllSms({bool forceFullScan = false}) async {
    int count = 0;
    count += await syncPendingSms();
    count += await syncInboxSms(limit: 1000, forceFullScan: forceFullScan);
    return count;
  }

  /// Checks if SMS permission is granted.
  static Future<bool> checkSmsPermission() async {
    final status = await Permission.sms.status;
    return status.isGranted;
  }

  /// Explicitly requests SMS permission from the user.
  static Future<bool> requestSmsPermission() async {
    final status = await Permission.sms.request();
    return status.isGranted;
  }

  /// Enables or disables automatic SMS transaction tracking.
  static Future<bool> setTrackingEnabled(bool enable) async {
    if (enable) {
      final granted = await requestSmsPermission();
      if (!granted) {
        isTrackingActive.value = false;
        await DatabaseHelper.instance.saveSetting('sms_tracking_enabled', 'false');
        return false;
      }
      isTrackingActive.value = true;
      await DatabaseHelper.instance.saveSetting('sms_tracking_enabled', 'true');
      startIncomingSmsListener();
      await autoScanAllSms(forceFullScan: true);
      return true;
    } else {
      isTrackingActive.value = false;
      await DatabaseHelper.instance.saveSetting('sms_tracking_enabled', 'false');
      stopIncomingSmsListener();
      return true;
    }
  }

  /// Listens to real-time incoming SMS alerts when app is active.
  static void startIncomingSmsListener() {
    _incomingSmsSubscription?.cancel();
    try {
      _incomingSmsSubscription = _eventChannel.receiveBroadcastStream().listen(
        (dynamic event) async {
          if (event is Map) {
            final sender = event['address']?.toString() ?? 'Unknown';
            final body = event['body']?.toString() ?? '';
            final dateMs = (event['date'] as num?)?.toInt() ?? DateTime.now().millisecondsSinceEpoch;
            final date = DateTime.fromMillisecondsSinceEpoch(dateMs);

            await handleIncomingSms(sender, body, date);
          }
        },
        onError: (e) {
          debugPrint('Error in SMS event stream: $e');
        },
      );
    } catch (e) {
      debugPrint('Failed to start incoming SMS listener: $e');
    }
  }

  /// Stops incoming SMS real-time listener.
  static void stopIncomingSmsListener() {
    _incomingSmsSubscription?.cancel();
    _incomingSmsSubscription = null;
  }

  /// Handles a single incoming or pending SMS message.
  static Future<bool> handleIncomingSms(String sender, String body, DateTime date) async {
    if (!isFinancialSms(sender, body)) return false;

    final parsed = parseSms(sender, body, date: date);
    if (parsed == null) return false;

    final inserted = await insertTransactionIfUnique(parsed);
    if (inserted) {
      newTransactionsCount.value++;
      // Trigger user alert notification
      try {
        await NotificationService.showSmsTransactionNotification(
          id: date.millisecondsSinceEpoch ~/ 1000,
          title: 'Auto-Added ${parsed.type}: ${CurrencyService.symbol}${parsed.amount.toStringAsFixed(2)}',
          body: '${parsed.merchant} • Category: ${parsed.suggestedCategory ?? "General"}',
        );
      } catch (_) {}
      return true;
    }
    return false;
  }

  /// Processes any SMS messages that arrived while the app was backgrounded/closed.
  static Future<int> syncPendingSms() async {
    int count = 0;
    try {
      final List<dynamic>? pendingList = await _methodChannel.invokeListMethod('getPendingSms');
      if (pendingList != null && pendingList.isNotEmpty) {
        for (final item in pendingList) {
          if (item is Map) {
            final sender = item['address']?.toString() ?? 'Unknown';
            final body = item['body']?.toString() ?? '';
            final dateMs = (item['date'] as num?)?.toInt() ?? DateTime.now().millisecondsSinceEpoch;
            final date = DateTime.fromMillisecondsSinceEpoch(dateMs);

            final added = await handleIncomingSms(sender, body, date);
            if (added) count++;
          }
        }
      }
    } catch (e) {
      debugPrint('Error syncing pending SMS: $e');
    }
    return count;
  }

  /// Scans the user's SMS inbox for past financial transactions.
  static Future<int> syncInboxSms({int limit = 1000, bool forceFullScan = false}) async {
    final hasPermission = await checkSmsPermission();
    if (!hasPermission) {
      final granted = await requestSmsPermission();
      if (!granted) return 0;
    }

    int addedCount = 0;
    try {
      final lastSyncStr = forceFullScan ? null : await DatabaseHelper.instance.getSetting('last_synced_sms_timestamp');
      final int sinceTimestamp = forceFullScan ? 0 : (int.tryParse(lastSyncStr ?? '') ?? 0);

      final List<dynamic>? smsList = await _methodChannel.invokeListMethod(
        'getInboxSms',
        {'limit': limit, 'sinceTimestamp': sinceTimestamp},
      );

      if (smsList != null && smsList.isNotEmpty) {
        int maxTimestamp = sinceTimestamp;

        for (final item in smsList) {
          if (item is Map) {
            final sender = item['address']?.toString() ?? 'Unknown';
            final body = item['body']?.toString() ?? '';
            final dateMs = (item['date'] as num?)?.toInt() ?? 0;
            final date = DateTime.fromMillisecondsSinceEpoch(dateMs);

            if (dateMs > maxTimestamp) {
              maxTimestamp = dateMs;
            }

            if (!isFinancialSms(sender, body)) continue;

            final parsed = parseSms(sender, body, date: date);
            if (parsed != null) {
              final inserted = await insertTransactionIfUnique(parsed);
              if (inserted) addedCount++;
            }
          }
        }

        if (maxTimestamp > 0) {
          await DatabaseHelper.instance.saveSetting('last_synced_sms_timestamp', maxTimestamp.toString());
        }
      }
    } catch (e) {
      debugPrint('Error syncing SMS inbox: $e');
    }

    if (addedCount > 0) {
      newTransactionsCount.value += addedCount;
    }
    return addedCount;
  }

  /// Verifies if an SMS is a financial transaction alert.
  static bool isFinancialSms(String sender, String body) {
    final cleanBody = body.toLowerCase();

    // 1. Filter out pure OTP / 2FA login verification codes without transaction context
    final isPureOtp = RegExp(
      r'\b(is\s+your\s+otp|use\s+otp|login\s+otp|verification\s+code|do\s+not\s+share\s+this\s+otp|secret\s+code)\b',
    ).hasMatch(cleanBody);
    final hasTransactionAction = RegExp(
      r'\b(debited|credited|spent|paid|transferred|withdrawn|purchase|deducted)\b',
    ).hasMatch(cleanBody);

    if (isPureOtp && !hasTransactionAction) return false;

    // 2. Filter out promotional ads, spam, plan expiration pitches
    if (RegExp(
      r'\b(recharge\s+now|plan\s+expiry|unlimited\s+calls|free\s+data|cashback\s+offer|win\s+up\s+to|apply\s+for\s+loan|pre-approved|coupon\s+code)\b',
    ).hasMatch(cleanBody) && !hasTransactionAction) {
      return false;
    }

    // 3. Must contain at least one primary transaction keyword
    final hasTransactionKeyword = RegExp(
      r'\b(debited|spent|paid|sent|withdrawn|purchase|transferred|deducted|charged|credited|deposited|received|refund|cashback|txn|upi|vpa|a\/c|acct|balance|bal)\b',
    ).hasMatch(cleanBody);

    // 4. Must contain currency sign or currency keyword
    final hasCurrency = RegExp(
      r'(\₹|rs\.?|inr|\$|usd|€|eur|gbp|\£)',
    ).hasMatch(cleanBody);

    return hasTransactionKeyword && hasCurrency;
  }

  /// Parses financial SMS text into structured transaction fields.
  static ParsedSmsTransaction? parseSms(String sender, String body, {DateTime? date}) {
    // 1. Extract Amount
    final double? amount = _extractAmount(body);
    if (amount == null || amount <= 0) return null;

    // 2. Determine Transaction Type (Expense vs Income)
    final String type = _extractType(body);

    // 3. Extract Merchant / Vendor Name
    final String merchant = _extractMerchant(sender, body);

    // 4. Extract Reference ID / UTR
    final String? refId = _extractReferenceId(body);

    // 5. Extract Account Ending
    final String? accountEnding = _extractAccountEnding(body);

    // 6. Extract / Fallback Date
    final DateTime txDate = _extractDate(body) ?? date ?? DateTime.now();

    // 7. Auto-Match Category
    final String? category = OcrService.suggestCategoryName(merchant, body);

    return ParsedSmsTransaction(
      sender: sender,
      body: body,
      amount: amount,
      merchant: merchant,
      transactionName: merchant,
      type: type,
      date: txDate,
      suggestedCategory: category,
      referenceId: refId,
      accountEnding: accountEnding,
    );
  }

  /// Extracts the monetary amount from the SMS body.
  static double? _extractAmount(String body) {
    // Pattern 1: Currency symbol or code followed by digits: ₹ 450.00, Rs.450, INR 1,250.50, $25
    final currencyPattern = RegExp(
      r'(?:[\$€£₹¥]|INR|RS\.?|USD|EUR|GBP)\s*([0-9]{1,3}(?:,[0-9]{3})+(?:\.[0-9]{1,2})?|[0-9]+(?:\.[0-9]{1,2})?)\b',
      caseSensitive: false,
    );
    final match1 = currencyPattern.firstMatch(body);
    if (match1 != null) {
      final parsed = _parseCleanDouble(match1.group(1));
      if (parsed != null && parsed > 0) return parsed;
    }

    // Pattern 2: Action keyword followed by amount: "debited by 500", "paid 250.00", "spent 120", "amt 450"
    final actionPattern = RegExp(
      r'\b(?:debited(?:\s*by|\s*with)?|paid|spent|sent|credited(?:\s*by|\s*with)?|amount(?:\s*of)?|amt(?:\s*of)?)\s*(?:[A-Za-z]+|\₹|Rs\.?)?\s*([0-9]{1,3}(?:,[0-9]{3})+(?:\.[0-9]{1,2})?|[0-9]+(?:\.[0-9]{1,2})?)\b',
      caseSensitive: false,
    );
    final match2 = actionPattern.firstMatch(body);
    if (match2 != null) {
      final parsed = _parseCleanDouble(match2.group(1));
      if (parsed != null && parsed > 0) return parsed;
    }

    // Pattern 3: "for INR 500" or "for Rs. 500" or "for 500"
    final forPattern = RegExp(
      r'\bfor\s+(?:INR|RS\.?|\₹|\$)?\s*([0-9]{1,3}(?:,[0-9]{3})+(?:\.[0-9]{1,2})?|[0-9]+(?:\.[0-9]{1,2})?)\b',
      caseSensitive: false,
    );
    final match3 = forPattern.firstMatch(body);
    if (match3 != null) {
      final parsed = _parseCleanDouble(match3.group(1));
      if (parsed != null && parsed > 0) return parsed;
    }

    return null;
  }

  /// Parses monetary string handling thousand separators and decimals.
  static double? _parseCleanDouble(String? str) {
    if (str == null || str.trim().isEmpty) return null;
    var clean = str.trim().replaceAll(',', '');
    return double.tryParse(clean);
  }

  /// Determines whether the SMS represents an Expense or Income.
  static String _extractType(String body) {
    final lower = body.toLowerCase();
    final isCredit = RegExp(
      r'\b(credited(?:\s*to|\s*with)?|deposited|received\s+(?:from|in)|refund(?:ed)?|cashback)\b',
    ).hasMatch(lower);

    final isDebit = RegExp(
      r'\b(debited(?:\s*from|\s*with)?|spent|paid\s+to|sent\s+to|withdrawn|purchase\s+at|deducted)\b',
    ).hasMatch(lower);

    if (isCredit && !isDebit) {
      return 'Income';
    }
    return 'Expense';
  }

  /// Extracts vendor / merchant name from SMS patterns or bank sender headers.
  static String _extractMerchant(String sender, String body) {
    // 1. Check "paid to [Merchant]" or "transferred to [Merchant]" or "sent to [Merchant]"
    final paidToMatch = RegExp(
      r"\b(?:paid\s+to|transfer(?:red)?\s+to|sent\s+to)\s+([A-Za-z0-9\s\.\&'\-]+?)(?:\s+(?:on|using|via|ref|from|bal|avl|upi|txn|a\/c|ending|at\s+\d)|\.|\,|$)",
      caseSensitive: false,
    ).firstMatch(body);
    if (paidToMatch != null) {
      final name = _cleanMerchantString(paidToMatch.group(1));
      if (name != null && name.length >= 2) return name;
    }

    // 2. Check "at [Merchant]" e.g. "purchase at Starbucks on card ..."
    final atMatch = RegExp(
      r"\b(?:at|purchase\s+at)\s+([A-Za-z0-9\s\.\&'\-]+?)(?:\s+(?:on|using|via|ref|from|bal|avl|upi|txn|a\/c|ending)|\.|\,|$)",
      caseSensitive: false,
    ).firstMatch(body);
    if (atMatch != null) {
      final name = _cleanMerchantString(atMatch.group(1));
      if (name != null && name.length >= 2) return name;
    }

    // 3. Check "info: UPI/[Merchant]/..."
    final infoMatch = RegExp(
      r"\binfo:\s*(?:UPI\/)?([A-Za-z0-9\s\.\&'\-]+?)(?:\/|\s|$)",
      caseSensitive: false,
    ).firstMatch(body);
    if (infoMatch != null) {
      final name = _cleanMerchantString(infoMatch.group(1));
      if (name != null && name.length >= 2) return name;
    }

    // 4. Check "VPA [handle]" or "to VPA [handle]" e.g. to VPA zomato@hdfcbank
    final vpaMatch = RegExp(
      r'\b(?:to\s+)?VPA\s+([A-Za-z0-9\.\@\-]+)',
      caseSensitive: false,
    ).firstMatch(body);
    if (vpaMatch != null) {
      final rawVpa = vpaMatch.group(1)!;
      final handlePart = rawVpa.split('@').first;
      final clean = _cleanMerchantString(handlePart);
      if (clean != null && clean.length >= 2) return clean;
    }

    // 5. Check "towards [Merchant]"
    final towardsMatch = RegExp(
      r"\btowards\s+([A-Za-z0-9\s\.\&'\-]+?)(?:\s+(?:on|using|via|ref|from)|\.|\,|$)",
      caseSensitive: false,
    ).firstMatch(body);
    if (towardsMatch != null) {
      final name = _cleanMerchantString(towardsMatch.group(1));
      if (name != null && name.length >= 2) return name;
    }

    // Fallback: derive user-friendly name from sender shortcode
    return _friendlySenderName(sender);
  }

  /// Cleans extracted merchant name, stripping trailing punctuation and junk words.
  static String? _cleanMerchantString(String? raw) {
    if (raw == null) return null;
    var clean = raw.trim();
    clean = clean.replaceAll(RegExp(r"^[\*#=\-_~:;\.]+|\s*[\*#=\-_~:;\.]+$"), '').trim();

    // Ignore if merchant is a stopword or noise
    final lower = clean.toLowerCase();
    if (['your', 'the', 'an', 'a', 'a/c', 'account', 'card', 'bank', 'bank a/c'].contains(lower)) {
      return null;
    }
    if (clean.length < 2) return null;

    // Capitalize words
    return clean.split(' ').map((w) {
      if (w.isEmpty) return w;
      return w[0].toUpperCase() + (w.length > 1 ? w.substring(1) : '');
    }).join(' ');
  }

  /// Maps bank sender shortcodes (e.g. VM-HDFCBK) to recognizable bank names.
  static String _friendlySenderName(String sender) {
    final s = sender.toUpperCase();
    if (s.contains('HDFC')) return 'HDFC Bank';
    if (s.contains('SBIPIN') || s.contains('SBIUPI') || s.contains('SBI')) return 'State Bank of India';
    if (s.contains('ICICI')) return 'ICICI Bank';
    if (s.contains('AXIS')) return 'Axis Bank';
    if (s.contains('KOTAK')) return 'Kotak Bank';
    if (s.contains('PAYTM')) return 'Paytm';
    if (s.contains('GPAY') || s.contains('GOOGLE')) return 'Google Pay';
    if (s.contains('PHONPE') || s.contains('PHONEPE')) return 'PhonePe';
    if (s.contains('AMAZON')) return 'Amazon Pay';
    if (s.contains('CITI')) return 'Citibank';
    if (s.contains('BOB') || s.contains('BARODA')) return 'Bank of Baroda';
    if (s.contains('PNB')) return 'Punjab National Bank';
    if (s.contains('INDUS')) return 'IndusInd Bank';
    if (s.contains('YESB')) return 'Yes Bank';

    // If sender has hyphen like VM-HDFCBK or AD-AIRTEL, take the right part
    if (sender.contains('-')) {
      final suffix = sender.split('-').last.trim();
      if (suffix.isNotEmpty) return suffix;
    }

    return sender.trim().isNotEmpty ? sender.trim() : 'Bank Transaction';
  }

  /// Extracts reference ID / UTR number from SMS body.
  static String? _extractReferenceId(String body) {
    final refMatch = RegExp(
      r'\b(?:UPI\s*Ref(?:\s*No)?|Ref(?:\s*No)?|Txn(?:\s*ID)?|UTR|Reference)\s*[:=\-]?\s*([A-Za-z0-9]+)\b',
      caseSensitive: false,
    ).firstMatch(body);
    return refMatch?.group(1);
  }

  /// Extracts account ending digits (e.g. A/c ending 1234, A/C **8912, A/c XX1234).
  static String? _extractAccountEnding(String body) {
    final acctMatch = RegExp(
      r'\b(?:a\/c|account|acct|card)(?:\s*no\.?)?(?:\s*ending)?(?:\s*with|\s*in)?\s*[\*xX\.\-]*\s*([0-9]{3,4})\b',
      caseSensitive: false,
    ).firstMatch(body);
    return acctMatch?.group(1);
  }

  /// Extracts date from SMS text if explicitly mentioned, otherwise null.
  static DateTime? _extractDate(String body) {
    // 1. Matches DD-Mon-YY or DD-Mon-YYYY (e.g. 15-Nov-26 or 15-Nov-2026)
    final dateMonMatch = RegExp(
      r'\b(\d{1,2})-(Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)-(\d{2,4})\b',
      caseSensitive: false,
    ).firstMatch(body);
    if (dateMonMatch != null) {
      try {
        final day = int.parse(dateMonMatch.group(1)!);
        final monStr = dateMonMatch.group(2)!.toLowerCase();
        final months = ['jan', 'feb', 'mar', 'apr', 'may', 'jun', 'jul', 'aug', 'sep', 'oct', 'nov', 'dec'];
        final month = months.indexOf(monStr) + 1;
        var year = int.parse(dateMonMatch.group(3)!);
        if (year < 100) year += 2000;
        return DateTime(year, month, day);
      } catch (_) {}
    }

    // 2. Matches DD/MM/YYYY or DD-MM-YYYY
    final dmyMatch = RegExp(r'\b(0?[1-9]|[12]\d|3[01])[/\-\.](0?[1-9]|1[0-2])[/\-\.](20\d{2}|\d{2})\b').firstMatch(body);
    if (dmyMatch != null) {
      try {
        final day = int.parse(dmyMatch.group(1)!);
        final month = int.parse(dmyMatch.group(2)!);
        var year = int.parse(dmyMatch.group(3)!);
        if (year < 100) year += 2000;
        return DateTime(year, month, day);
      } catch (_) {}
    }

    return null;
  }

  /// Inserts a parsed transaction into SQLite if it does not already exist.
  static Future<bool> insertTransactionIfUnique(ParsedSmsTransaction tx) async {
    final dateStr =
        "${tx.date.year.toString().padLeft(4, '0')}-${tx.date.month.toString().padLeft(2, '0')}-${tx.date.day.toString().padLeft(2, '0')}";

    // De-duplication check
    final isDup = await DatabaseHelper.instance.isTransactionDuplicate(
      amount: tx.amount,
      date: dateStr,
      merchant: tx.merchant,
      referenceId: tx.referenceId,
    );
    if (isDup) return false;

    // Resolve Category ID
    int? categoryId;
    final categories = await DatabaseHelper.instance.getCategories();
    if (tx.suggestedCategory != null && categories.isNotEmpty) {
      for (final cat in categories) {
        if ((cat['category_name'] as String).toLowerCase() == tx.suggestedCategory!.toLowerCase()) {
          categoryId = (cat['category_id'] as num?)?.toInt();
          break;
        }
      }
    }
    // Fallback to first category if not matched
    if (categoryId == null && categories.isNotEmpty) {
      categoryId = (categories.first['category_id'] as num?)?.toInt();
    }

    final notesText = StringBuffer();
    notesText.write('[Auto-SMS] ');
    if (tx.referenceId != null) notesText.write('Ref: ${tx.referenceId} | ');
    if (tx.accountEnding != null) notesText.write('A/c: **${tx.accountEnding} | ');
    final cleanSnippet = tx.body.replaceAll('\n', ' ').trim();
    notesText.write(cleanSnippet.length > 80 ? '${cleanSnippet.substring(0, 80)}...' : cleanSnippet);

    await DatabaseHelper.instance.insertTransaction({
      'amount': tx.amount,
      'type': tx.type,
      'date': dateStr,
      'merchant': tx.merchant,
      'transaction_name': tx.transactionName,
      'category_id': categoryId,
      'notes': notesText.toString(),
    });

    return true;
  }
}
