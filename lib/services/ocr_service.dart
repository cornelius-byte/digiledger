import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:fast_paddle_ocr/ocr.dart';

class OcrResult {
  final String? vendorName;
  final double? amount;
  final DateTime? date;
  final String rawText;
  final String? savedImagePath;
  final String? bboxImagePath;
  final bool hasTextDetected;

  const OcrResult({
    this.vendorName,
    this.amount,
    this.date,
    required this.rawText,
    this.savedImagePath,
    this.bboxImagePath,
    this.hasTextDetected = false,
  });
}

class OcrService {
  static final Ocr _ocrPlugin = Ocr();
  static bool _isModelLoaded = false;
  static bool _isLoadingModel = false;

  static Ocr get ocrPlugin => _ocrPlugin;
  static bool get isModelLoaded => _isModelLoaded;

  /// Copies an asset model file from bundle to device storage if not already present.
  static Future<String> _copyAssetToFile(String assetName) async {
    final dir = await getApplicationDocumentsDirectory();
    final modelsDir = Directory(p.join(dir.path, 'ocr_models'));
    if (!await modelsDir.exists()) {
      await modelsDir.create(recursive: true);
    }
    final file = File(p.join(modelsDir.path, assetName));
    if (!await file.exists() || (await file.length()) == 0) {
      final ByteData data = await rootBundle.load('assets/ocr/$assetName');
      await file.writeAsBytes(data.buffer.asUint8List(), flush: true);
    }
    return file.path;
  }

  /// Initializes and loads the PaddleOCR NCNN models (detection & recognition).
  /// Using sizeid = 3 (560px) for much higher text recognition resolution on receipts.
  static Future<bool> initModel({int sizeid = 3}) async {
    if (_isModelLoaded) return true;
    if (_isLoadingModel) {
      while (_isLoadingModel) {
        await Future.delayed(const Duration(milliseconds: 100));
      }
      return _isModelLoaded;
    }

    _isLoadingModel = true;
    try {
      final detParam = await _copyAssetToFile('PP_OCRv5_mobile_det.ncnn.param');
      final detModel = await _copyAssetToFile('PP_OCRv5_mobile_det.ncnn.bin');
      final recParam = await _copyAssetToFile('PP_OCRv5_mobile_rec.ncnn.param');
      final recModel = await _copyAssetToFile('PP_OCRv5_mobile_rec.ncnn.bin');

      final success = await _ocrPlugin.loadModel(
        detParam: detParam,
        detModel: detModel,
        recParam: recParam,
        recModel: recModel,
        sizeid: sizeid, // 3 = 560 for sharp receipt text detection
        cpugpu: 0,
      );

      _isModelLoaded = success;
      debugPrint("PaddleOCR loadModel result: $success (sizeid: $sizeid)");
      return success;
    } catch (e) {
      debugPrint('Error initializing PaddleOCR models: $e');
      return false;
    } finally {
      _isLoadingModel = false;
    }
  }

  /// Processes a receipt image using real offline PaddleOCR and extracts structured info.
  static Future<OcrResult> processReceipt(String imagePath) async {
    final file = File(imagePath);
    if (!await file.exists()) {
      return OcrResult(
        rawText: "",
        hasTextDetected: false,
        savedImagePath: imagePath,
      );
    }

    final bool loaded = await initModel();
    if (!loaded) {
      debugPrint("Warning: PaddleOCR model failed to load.");
      return OcrResult(
        rawText: "",
        hasTextDetected: false,
        savedImagePath: imagePath,
      );
    }

    try {
      // Run native C++ NCNN inference on the captured image
      final String? recognizedText = await _ocrPlugin.ocrFromImage(imagePath);
      final String rawText = (recognizedText ?? "").trim();

      if (rawText.isEmpty) {
        return OcrResult(
          rawText: "",
          hasTextDetected: false,
          savedImagePath: imagePath,
        );
      }

      // Check for native annotated bbox image
      final String ext = p.extension(imagePath);
      final String base = imagePath.substring(0, imagePath.length - ext.length);
      final String bboxPath = '${base}_bbox$ext';
      final String? validBbox = (File(bboxPath).existsSync()) ? bboxPath : null;

      return parseReceiptText(
        rawText,
        imagePath: imagePath,
        bboxImagePath: validBbox,
      );
    } catch (e) {
      debugPrint("Error running PaddleOCR on image: $e");
      return OcrResult(
        rawText: "",
        hasTextDetected: false,
        savedImagePath: imagePath,
      );
    }
  }

  /// Parses recognized receipt text into structured data (merchant, total amount, date).
  static OcrResult parseReceiptText(
    String rawText, {
    String? imagePath,
    String? bboxImagePath,
  }) {
    final cleanText = rawText.trim();
    if (cleanText.isEmpty) {
      return OcrResult(
        rawText: "",
        hasTextDetected: false,
        savedImagePath: imagePath,
        bboxImagePath: bboxImagePath,
      );
    }

    final String? vendor = _extractVendorName(cleanText);
    final double? amount = _extractTotalAmount(cleanText);
    final DateTime? date = _extractDate(cleanText);

    return OcrResult(
      vendorName: vendor,
      amount: amount,
      date: date,
      rawText: cleanText,
      savedImagePath: imagePath,
      bboxImagePath: bboxImagePath,
      hasTextDetected: true,
    );
  }

  /// Cleans merchant name by removing decorative symbols and prefixes like "Merchant-", "Store Name:", etc.
  static String _cleanMerchantName(String name) {
    var clean = name.trim();
    // Strip decorative characters at edges (*, #, =, -, _, ~, :, ;)
    clean = clean.replaceAll(RegExp(r'^[\*#=\-_~:;]+\s*|\s*[\*#=\-_~:;]+$'), '').trim();

    // Strip prefixes like "Merchant-", "Merchant:", "Merchant -", "Vendor:", "Store Name:", etc.
    final prefixRegex = RegExp(
      r'^(?:MERCHANT(?:\s*NAME)?|VENDOR(?:\s*NAME)?|STORE(?:\s*NAME)?|SHOP(?:\s*NAME)?|BUSINESS(?:\s*NAME)?|PAYEE|SELLER|BILLER|OUTLET)\s*[:\-\=\.]+\s*',
      caseSensitive: false,
    );
    clean = clean.replaceFirst(prefixRegex, '').trim();

    // Strip quotation marks or brackets if any
    clean = clean.replaceAll(RegExp(r'^["' "'" r'\[\(\{]+\s*|\s*["' "'" r'\]\)\}]+$'), '').trim();
    return clean;
  }

  /// Extracts vendor / merchant name from the top header lines of the receipt.
  static String? _extractVendorName(String rawText) {
    final lines = rawText
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();

    if (lines.isEmpty) return null;

    final genericHeaderRegex = RegExp(
      r'^(RECEIPT|TAX\s*INVOICE|INVOICE|BILL|BILLING|CASH\s*RECEIPT|SALE|ORDER|TRANSACTION|CUSTOMER\s*COPY|MERCHANT\s*COPY|MERCHANT|VENDOR|STORE|SHOP|DUPLICATE|WELCOME|WELCOME\s*TO|THANK\s*YOU|THANKS\s*FOR\s*VISITING|ORIGINAL|COPY|TERMINAL|STATION|OFFICIAL\s*RECEIPT|STORE\s*#?\d+|REGISTER\s*#?\d+|REG\s*#?\d+)$',
      caseSensitive: false,
    );

    final phoneRegex = RegExp(r'^(?:TEL|PHONE|FAX|CALL|PH)?[:\s]*\+?[\d\s\-\(\)\.]{7,}$', caseSensitive: false);
    final urlEmailRegex = RegExp(r'(www\.|\.com|\.org|\.net|\.io|@|http)', caseSensitive: false);
    final addressRegex = RegExp(r'^\d+\s+[A-Za-z]+.*');
    final dateOnlyRegex = RegExp(r'^\d{1,4}[/\-\.]\d{1,2}[/\-\.]\d{1,4}$');
    final timeOnlyRegex = RegExp(r'^\d{1,2}:\d{2}(?::\d{2})?(?:\s*(?:AM|PM))?$', caseSensitive: false);
    final pureSymbolsRegex = RegExp(r'^[^a-zA-Z0-9]+$');

    // Check top 7 lines for the business name
    final checkLimit = lines.length < 7 ? lines.length : 7;
    for (int i = 0; i < checkLimit; i++) {
      String line = lines[i];

      // Strip decorative surrounding chars and label prefixes like "Merchant-"
      line = _cleanMerchantName(line);

      if (line.length < 3) continue;
      if (pureSymbolsRegex.hasMatch(line)) continue;
      if (genericHeaderRegex.hasMatch(line)) continue;
      if (phoneRegex.hasMatch(line)) continue;
      if (urlEmailRegex.hasMatch(line)) continue;
      if (addressRegex.hasMatch(line)) continue;
      if (dateOnlyRegex.hasMatch(line)) continue;
      if (timeOnlyRegex.hasMatch(line)) continue;

      // Ensure line contains at least some letters
      if (!RegExp(r'[a-zA-Z]').hasMatch(line)) continue;

      // Avoid picking lines that are transaction lines or prices
      if (RegExp(r'\b(TOTAL|AMOUNT|SUBTOTAL|TAX|CASH|CHANGE|CARD|VISA|MASTERCARD|DEBIT|CREDIT|BALANCE|PRICE|QTY|ITEM)\b', caseSensitive: false).hasMatch(line)) {
        continue;
      }

      // If line contains store info like "WALMART STORE #1234", extract the main business name
      final storeIdMatch = RegExp(r'^(.*?)\s*(?:STORE|BRANCH|#|\bst\b|\bave\b)\s*#?\d+', caseSensitive: false).firstMatch(line);
      if (storeIdMatch != null && storeIdMatch.group(1)!.trim().length >= 3) {
        return _cleanMerchantName(storeIdMatch.group(1)!.trim());
      }

      return line;
    }

    // Fallback: return the first non-empty line that has letters
    for (final line in lines) {
      final clean = _cleanMerchantName(line);
      if (clean.length >= 3 && RegExp(r'[a-zA-Z]').hasMatch(clean)) {
        if (!genericHeaderRegex.hasMatch(clean)) {
          return clean;
        }
      }
    }

    return null;
  }

  /// Extracts the grand total / amount due from receipt text.
  static double? _extractTotalAmount(String rawText) {
    final lines = rawText
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();

    if (lines.isEmpty) return null;

    // High confidence keywords for the final grand total (ordered by specificity)
    final totalKeywords = [
      RegExp(r'\b(GRAND\s*TOTAL|FINAL\s*TOTAL|TOTAL\s*DUE|AMOUNT\s*DUE|BALANCE\s*DUE|TOTAL\s*PAYABLE|TOTAL\s*AMOUNT)\b', caseSensitive: false),
      RegExp(r'\b(NET\s*AMOUNT|NET\s*TOTAL|TOTAL\s*PAID|TOTAL\s*SALE|TOTAL\s*CHARGE|CHARGE)\b', caseSensitive: false),
      RegExp(r'(?:^|[^\w])TOTAL(?:\s*[:=\-]|\s+|$)', caseSensitive: false),
      RegExp(r'\b(T[O0o]T[A4][Ll1I]|TOTAL)\b', caseSensitive: false),
      RegExp(r'\b(AMOUNT|BAL|BALANCE|DUE)\b', caseSensitive: false),
    ];

    // Priority 1: Search for high-priority total keywords from bottom to top
    for (final pattern in totalKeywords) {
      for (int i = lines.length - 1; i >= 0; i--) {
        final line = lines[i];

        // Skip if line specifies subtotal instead of final total
        if (RegExp(r'\b(SUBTOTAL|SUB-TOTAL|SUB\s*TOTAL)\b', caseSensitive: false).hasMatch(line) &&
            !RegExp(r'\b(GRAND\s*TOTAL|TOTAL\s*DUE)\b', caseSensitive: false).hasMatch(line)) {
          continue;
        }

        // Skip if line specifies total items / count rather than money amount
        if (RegExp(r'\b(TOTAL|T[O0o]T[A4][Ll1I])\s*(?:ITEMS?|QTY|COUNT|PCS|PIECES)\b', caseSensitive: false).hasMatch(line) &&
            !RegExp(r'[\$€£₹¥]', caseSensitive: false).hasMatch(line)) {
          continue;
        }

        if (pattern.hasMatch(line)) {
          // 1. Check monetary value on the exact same line
          final amount = _extractAmountFromTotalLine(line);
          if (amount != null && amount > 0) {
            return amount;
          }

          // 2. Check up to 3 lines down (handling intervening blank or currency/desc lines)
          for (int offset = 1; offset <= 3 && (i + offset) < lines.length; offset++) {
            final nextLine = lines[i + offset];
            // Stop if encountering cash tendered or change section
            if (RegExp(r'\b(CASH|CHANGE|TENDER|TENDERED|SUBTOTAL)\b', caseSensitive: false).hasMatch(nextLine)) {
              break;
            }
            final nextAmount = _parseAmountFromLine(nextLine);
            if (nextAmount != null && nextAmount > 0) {
              return nextAmount;
            }
          }

          // 3. Check line immediately above (only if not a subtotal, tax, item, or discount)
          if (i - 1 >= 0) {
            final prevLine = lines[i - 1];
            if (!RegExp(r'\b(TAX|VAT|SUBTOTAL|ITEM|TIP|DISCOUNT|SAVING)\b', caseSensitive: false).hasMatch(prevLine)) {
              final prevAmount = _parseAmountFromLine(prevLine);
              if (prevAmount != null && prevAmount > 0) {
                return prevAmount;
              }
            }
          }
        }
      }
    }

    // Priority 2: Look for compressed total lines like "TOTAL24.50" or "TOTAL:24.50"
    final compressedTotalRegex = RegExp(
      r'(?:TOTAL|T[O0o]T[A4][Ll1I]|AMOUNT|DUE|BAL)\D*?([0-9]{1,4}[,\.][0-9]{2})',
      caseSensitive: false,
    );
    for (int i = lines.length - 1; i >= 0; i--) {
      final line = lines[i];
      if (RegExp(r'\b(SUBTOTAL|SUB-TOTAL|SUB\s*TOTAL)\b', caseSensitive: false).hasMatch(line)) continue;
      final match = compressedTotalRegex.firstMatch(line);
      if (match != null) {
        final val = _cleanAndParseDouble(match.group(1));
        if (val != null && val > 0) {
          return val;
        }
      }
    }

    // Priority 3: Look for lines with currency symbols followed by amounts
    final currencyLineRegex = RegExp(
      r'(?:[\$€£₹¥]|USD|EUR|GBP|INR|RS\.?|RM|CAD|AUD)\s*([0-9]{1,3}(?:[,\.][0-9]{3})*[,\.][0-9]{1,2}|[0-9]+[,\.][0-9]{1,2}|[0-9]+)\b',
      caseSensitive: false,
    );
    double maxCurrencyAmount = 0.0;
    for (final line in lines) {
      if (RegExp(r'\b(DATE|TIME|TEL|PHONE|ACCOUNT|CARD|CHANGE|CASH|TENDER|TENDERED|SAVED|SAVINGS|POINTS)\b', caseSensitive: false).hasMatch(line)) {
        continue;
      }
      final matches = currencyLineRegex.allMatches(line);
      for (final match in matches) {
        final val = _cleanAndParseDouble(match.group(1));
        if (val != null && val > maxCurrencyAmount && val < 100000) {
          maxCurrencyAmount = val;
        }
      }
    }
    if (maxCurrencyAmount > 0) {
      return maxCurrencyAmount;
    }

    // Priority 4: Scan all decimal amounts in the text, preferring the largest reasonable transaction amount
    final generalAmountRegex = RegExp(r'\b([0-9]{1,4}[,\.][0-9]{2})\b');
    final List<double> foundAmounts = [];
    for (final line in lines) {
      if (RegExp(r'\b(DATE|TIME|TEL|PHONE|ACCOUNT|BARCODE|STORE|REG|REGISTER|INVOICE|ORDER|TRANS|TRANSACTION|BATCH|AUTH|TERMINAL|EXP|CARD|VISA|MASTERCARD|CASH|CHANGE|TENDER|TENDERED|SAVED|SAVINGS)\b', caseSensitive: false).hasMatch(line)) {
        continue;
      }
      if (RegExp(r'^\d{1,4}[/\-\.]\d{1,2}[/\-\.]\d{1,4}$').hasMatch(line)) continue;
      if (RegExp(r'^\d{1,2}:\d{2}(?::\d{2})?$').hasMatch(line)) continue;

      final matches = generalAmountRegex.allMatches(line);
      for (final match in matches) {
        final val = _cleanAndParseDouble(match.group(1));
        if (val != null && val > 0 && val < 100000) {
          foundAmounts.add(val);
        }
      }
    }

    if (foundAmounts.isNotEmpty) {
      foundAmounts.sort();
      return foundAmounts.last;
    }

    return null;
  }

  /// Extracts the amount specifically associated with a TOTAL or amount keyword on the same line.
  static double? _extractAmountFromTotalLine(String line) {
    var cleanLine = line.trim();
    // Normalize spaces around decimal separators: "21 . 08" -> "21.08", "21. 08" -> "21.08"
    cleanLine = cleanLine.replaceAllMapped(
      RegExp(r'(\d+)\s*([\.,])\s*(\d{1,2})\b'),
      (m) => '${m[1]}${m[2]}${m[3]}',
    );

    // Try matching amount directly adjacent to total/due/amount keyword:
    // e.g. "TOTAL: $21.08", "TOTAL $ 21.08", "TOTAL 21.08", "TOTAL21.08", "AMOUNT DUE: 34.50"
    final directMatch = RegExp(
      r'(?:TOTAL|T[O0o]T[A4][Ll1I]|AMOUNT|AMT|DUE|BALANCE|BAL|PAYABLE|NET)\s*[:=\-]?\s*(?:[\$€£₹¥]|USD|EUR|GBP|INR|RS\.?|RM|CAD|AUD)?\s*([0-9]{1,3}(?:[,\.][0-9]{3})*(?:[,\.][0-9]{1,2})?|[0-9]+(?:[,\.][0-9]{1,2})?)\b',
      caseSensitive: false,
    ).firstMatch(cleanLine);

    if (directMatch != null) {
      final parsed = _cleanAndParseDouble(directMatch.group(1));
      if (parsed != null && parsed > 0) {
        return parsed;
      }
    }

    // Otherwise, parse general amount from the line
    return _parseAmountFromLine(cleanLine);
  }

  static double? _parseAmountFromLine(String line) {
    if (line.trim().isEmpty) return null;

    // Normalize spacing around decimals: "24 . 50" -> "24.50"
    var clean = line.replaceAllMapped(
      RegExp(r'(\d+)\s*([\.,])\s*(\d{1,2})\b'),
      (m) => '${m[1]}${m[2]}${m[3]}',
    );

    // 1. Standard currency + price or decimal: e.g. $24.50, €34.50, 1,250.00, 24.50
    final priceRegex = RegExp(
      r'(?:[\$€£₹¥]|USD|EUR|GBP|INR|RS\.?|RM|CAD|AUD)?\s*([0-9]{1,3}(?:[,\.][0-9]{3})*[,\.][0-9]{2})\b',
      caseSensitive: false,
    );
    final matches = priceRegex.allMatches(clean).toList();
    if (matches.isNotEmpty) {
      final lastVal = _cleanAndParseDouble(matches.last.group(1));
      if (lastVal != null && lastVal > 0) return lastVal;
    }

    // 2. Simple decimal with 1 or 2 decimal digits: e.g. 24.5, 24.50, 24,50
    final simpleDecimal = RegExp(r'\b([0-9]+[\.,][0-9]{1,2})\b');
    final simpleMatches = simpleDecimal.allMatches(clean).toList();
    if (simpleMatches.isNotEmpty) {
      final lastVal = _cleanAndParseDouble(simpleMatches.last.group(1));
      if (lastVal != null && lastVal > 0) return lastVal;
    }

    // 3. Integer amount with explicit currency symbol: e.g. $25, €34, Rs 500, ₹1200
    final currencyIntRegex = RegExp(
      r'(?:[\$€£₹¥]|USD|EUR|GBP|INR|RS\.?|RM|CAD|AUD)\s*([0-9]{1,3}(?:,[0-9]{3})+|[0-9]+)\b',
      caseSensitive: false,
    );
    final intMatches = currencyIntRegex.allMatches(clean).toList();
    if (intMatches.isNotEmpty) {
      final lastVal = _cleanAndParseDouble(intMatches.last.group(1));
      if (lastVal != null && lastVal > 0) return lastVal;
    }

    // 4. Standalone integer if the line contains a price-like indicator
    final priceIndicatorRegex = RegExp(r'\b(TOTAL|AMOUNT|DUE|PRICE|PAY|CHARGE)\b', caseSensitive: false);
    if (priceIndicatorRegex.hasMatch(clean)) {
      final standaloneIntRegex = RegExp(r'\b([0-9]{1,6})\b');
      final standaloneMatches = standaloneIntRegex.allMatches(clean).toList();
      for (int i = standaloneMatches.length - 1; i >= 0; i--) {
        final val = double.tryParse(standaloneMatches[i].group(1)!);
        if (val != null && val > 0 && val < 100000) {
          return val;
        }
      }
    }

    return null;
  }

  static double? _cleanAndParseDouble(String? valStr) {
    if (valStr == null || valStr.isEmpty) return null;
    try {
      String clean = valStr.trim();
      // Handle thousands separators vs decimal points
      if (clean.contains(',') && clean.contains('.')) {
        if (clean.lastIndexOf('.') > clean.lastIndexOf(',')) {
          clean = clean.replaceAll(',', '');
        } else {
          clean = clean.replaceAll('.', '').replaceAll(',', '.');
        }
      } else if (clean.contains(',')) {
        final commaIndex = clean.indexOf(',');
        final digitsAfterComma = clean.length - commaIndex - 1;
        if (digitsAfterComma == 3 && !clean.substring(commaIndex + 1).contains(',')) {
          clean = clean.replaceAll(',', '');
        } else {
          clean = clean.replaceAll(',', '.');
        }
      }
      return double.tryParse(clean);
    } catch (_) {
      return null;
    }
  }

  /// Suggests a matching transaction category name based on merchant and raw receipt text.
  static String? suggestCategoryName(String? vendor, String rawText) {
    final combined = '${vendor ?? ""} $rawText'.toLowerCase();

    // Food & Dining
    if (RegExp(r'\b(coffee|cafe|starbucks|restaurant|bistro|diner|burger|mcdonald|pizza|subway|kfc|taco|bakery|bar|pub|tea|food|grill|kitchen|sushi|donut|bbq|chipotle|wendy|domino|panera|noodle|ramen|swiggy|zomato|doordash|ubereats)\b').hasMatch(combined)) {
      return 'Food';
    }

    // Groceries & Supermarkets
    if (RegExp(r'\b(walmart|target|costco|supermarket|grocery|groceries|market|trader\s*joe|whole\s*foods|kroger|aldi|safeway|mart|fresh|produce|sprouts|publix|meijer|heb|bjs|blinkit|zepto|instamart|bigbasket)\b').hasMatch(combined)) {
      return 'Groceries';
    }

    // Transportation & Fuel
    if (RegExp(r'\b(uber|lyft|taxi|cab|shell|chevron|exxon|mobil|bp|gas|fuel|petrol|metro|transit|parking|station|train|bus|airline|flight|subway\s*train|ola|rapido)\b').hasMatch(combined)) {
      return 'Transport';
    }

    // Clothes & Apparel
    if (RegExp(r'\b(zara|h&m|nike|adidas|uniqlo|gap|clothing|apparel|shoes|fashion|dress|jeans|shirt|pants|boutique|footwear|nordstrom|tj\s*maxx)\b').hasMatch(combined)) {
      return 'Clothes';
    }

    // Electronics & Tech
    if (RegExp(r'\b(apple|best\s*buy|samsung|sony|electronics|tech|gadget|computer|phone|laptop|headphone|audio|dell|lenovo)\b').hasMatch(combined)) {
      return 'Electronics';
    }

    // Health & Pharmacy
    if (RegExp(r'\b(pharmacy|cvs|walgreens|hospital|clinic|medical|doctor|health|dental|medicine|care|optometry|vision|rx)\b').hasMatch(combined)) {
      return 'Health';
    }

    // Stationery & Office
    if (RegExp(r'\b(stationery|staples|office|book|paper|print|pen|pencil|notebook|depot|desk)\b').hasMatch(combined)) {
      return 'Stationery';
    }

    return null;
  }

  /// Extracts date from receipt text if available.
  static DateTime? _extractDate(String rawText) {
    // 1. Matches YYYY-MM-DD or YYYY/MM/DD
    final ymdRegex = RegExp(r'\b(20\d{2})[/\-\.](0?[1-9]|1[0-2])[/\-\.](0?[1-9]|[12]\d|3[01])\b');
    final ymdMatch = ymdRegex.firstMatch(rawText);
    if (ymdMatch != null) {
      try {
        final year = int.parse(ymdMatch.group(1)!);
        final month = int.parse(ymdMatch.group(2)!);
        final day = int.parse(ymdMatch.group(3)!);
        return DateTime(year, month, day);
      } catch (_) {}
    }

    // 2. Matches DD/MM/YYYY or MM/DD/YYYY
    final dmyRegex = RegExp(r'\b(0?[1-9]|[12]\d|3[01])[/\-\.](0?[1-9]|1[0-2])[/\-\.](20\d{2}|\d{2})\b');
    final dmyMatch = dmyRegex.firstMatch(rawText);
    if (dmyMatch != null) {
      try {
        final part1 = int.parse(dmyMatch.group(1)!);
        final part2 = int.parse(dmyMatch.group(2)!);
        var year = int.parse(dmyMatch.group(3)!);
        if (year < 100) year += 2000;
        return DateTime(year, part2, part1);
      } catch (_) {}
    }

    return null;
  }

  /// Saves receipt image to local app storage for permanent reference.
  static Future<String> saveReceiptLocally(File imageFile) async {
    final appDir = await getApplicationDocumentsDirectory();
    final receiptDir = Directory(p.join(appDir.path, 'receipts'));
    if (!await receiptDir.exists()) {
      await receiptDir.create(recursive: true);
    }
    final newFileName = 'receipt_${DateTime.now().millisecondsSinceEpoch}${p.extension(imageFile.path)}';
    final savedFile = await imageFile.copy(p.join(receiptDir.path, newFileName));
    return savedFile.path;
  }
}
