import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../database/database_helper.dart';
import '../services/currency_service.dart';
import '../services/ocr_service.dart';
import '../services/theme_service.dart';
import 'transaction_history_screen.dart';
import 'receipt_scanner_screen.dart';

class AddTransactionScreen extends StatefulWidget {
  const AddTransactionScreen({super.key});

  @override
  State<AddTransactionScreen> createState() => _AddTransactionScreenState();
}

class _AddTransactionScreenState extends State<AddTransactionScreen> {
  bool _isManualMode = true;

  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _merchantController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();

  int? _selectedCategoryId;
  bool _isLoadingCategories = true;

  File? _receiptImage;
  bool _isScanning = false;

  List<Map<String, dynamic>> _categories = [];

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    try {
      final categoriesData = await DatabaseHelper.instance.getCategories();
      setState(() {
        _categories = categoriesData;
        if (_categories.isNotEmpty) {
          _selectedCategoryId = (_categories.first['category_id'] as num?)?.toInt();
        }
        _isLoadingCategories = false;
      });
    } catch (e) {
      setState(() => _isLoadingCategories = false);
    }
  }

  Future<void> _scanReceiptWithCamera() async {
    final OcrResult? result = await Navigator.push<OcrResult>(
      context,
      MaterialPageRoute(builder: (_) => const ReceiptScannerScreen()),
    );

    if (result != null && mounted) {
      _applyOcrResult(result);
    }
  }

  Future<void> _pickReceiptImage(ImageSource source) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: source);

    if (pickedFile != null) {
      setState(() {
        _receiptImage = File(pickedFile.path);
      });
      _runOcrPipeline();
    }
  }

  void _runOcrPipeline() async {
    if (_receiptImage == null) return;
    setState(() => _isScanning = true);

    try {
      final ocrResult = await OcrService.processReceipt(_receiptImage!.path);
      if (!mounted) return;
      _applyOcrResult(ocrResult);
    } catch (e) {
      if (mounted) setState(() => _isScanning = false);
    }
  }

  void _applyOcrResult(OcrResult ocrResult) {
    int? matchedCategoryId;
    final suggestedCategoryName = OcrService.suggestCategoryName(ocrResult.vendorName, ocrResult.rawText);
    if (suggestedCategoryName != null && _categories.isNotEmpty) {
      for (final cat in _categories) {
        if ((cat['category_name'] as String).toLowerCase() == suggestedCategoryName.toLowerCase()) {
          matchedCategoryId = (cat['category_id'] as num?)?.toInt();
          break;
        }
      }
    }

    setState(() {
      if (ocrResult.savedImagePath != null) {
        _receiptImage = File(ocrResult.savedImagePath!);
      }
      if (ocrResult.hasTextDetected) {
        if (ocrResult.vendorName != null && ocrResult.vendorName!.isNotEmpty) {
          _merchantController.text = ocrResult.vendorName!;
          if (_nameController.text.trim().isEmpty) {
            _nameController.text = ocrResult.vendorName!;
          }
        }
        if (ocrResult.amount != null) {
          _amountController.text = ocrResult.amount!.toStringAsFixed(2);
        }
        if (matchedCategoryId != null) {
          _selectedCategoryId = matchedCategoryId;
        }
        _notesController.text = "Receipt Scanned via PaddleOCR";
      }
      _isScanning = false;
    });

    if (!mounted) return;

    final isDark = ThemeService.isDarkOrCyber;
    final currentTheme = ThemeService.currentTheme.value;
    final snackBarBg = isDark
        ? (currentTheme == AppThemeOption.cyberpunk2077
        ? const Color(0xFF2E0914)
        : const Color(0xFF282836))
        : const Color(0xFF0C513F);
    final snackBarTextColor = ThemeService.getTextColorForBackground(snackBarBg);

    if (ocrResult.hasTextDetected) {
      final vendorText = ocrResult.vendorName ?? 'Receipt';
      final amountText = ocrResult.amount != null ? CurrencyService.format(ocrResult.amount!) : '';
      final msg = amountText.isNotEmpty 
          ? 'PaddleOCR: Extracted $vendorText • $amountText' 
          : 'PaddleOCR: Extracted $vendorText';

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: snackBarBg,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: ThemeService.getBorderColor(), width: 1.5),
          ),
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.greenAccent, size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  msg,
                  style: ThemeService.getAppTextStyle(fontSize: 15, color: snackBarTextColor, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          duration: const Duration(seconds: 4),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: isDark ? const Color(0xFF382B14) : const Color(0xFFFFF3BF),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: ThemeService.getBorderColor(), width: 1.5),
          ),
          content: Text(
            'PaddleOCR: No readable text detected on image. Please enter details manually.',
            style: ThemeService.getAppTextStyle(fontSize: 15, color: isDark ? Colors.amberAccent : Colors.black87, fontWeight: FontWeight.bold),
          ),
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  void _saveTransaction() async {
    if (_formKey.currentState!.validate() && _selectedCategoryId != null) {
      final transactionName = _nameController.text.trim().isEmpty
          ? (_merchantController.text.trim().isEmpty ? 'Expense' : _merchantController.text.trim())
          : _nameController.text.trim();
      final amount = double.parse(_amountController.text);
      final merchant = _merchantController.text.trim().isEmpty ? 'Unknown' : _merchantController.text.trim();
      final notes = _notesController.text.trim().isEmpty
          ? (_receiptImage != null ? 'Scanned Receipt' : 'Manual entry')
          : _notesController.text.trim();
      final date = DateTime.now().toIso8601String();

      String? savedReceiptPath;
      if (_receiptImage != null && _receiptImage!.existsSync()) {
        try {
          savedReceiptPath = await OcrService.saveReceiptLocally(_receiptImage!);
        } catch (_) {
          savedReceiptPath = _receiptImage?.path;
        }
      }

      await DatabaseHelper.instance.insertTransaction({
        'transaction_name': transactionName,
        'amount': amount,
        'type': 'Expense',
        'date': date,
        'merchant': merchant,
        'notes': notes,
        'receipt_image_path': savedReceiptPath,
        'category_id': _selectedCategoryId,
      });

      if (!mounted) return;
      final isDark = ThemeService.isDarkOrCyber;
      final currentTheme = ThemeService.currentTheme.value;
      final snackBarBg = isDark
          ? (currentTheme == AppThemeOption.cyberpunk2077
          ? const Color(0xFF2E0914)
          : const Color(0xFF282836))
          : const Color(0xFF0C513F);
      final snackBarTextColor = ThemeService.getTextColorForBackground(snackBarBg);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: snackBarBg,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: ThemeService.getBorderColor(), width: 1.5),
          ),
          content: Text(
            'Expense saved!',
            style: ThemeService.getAppTextStyle(fontSize: 18, color: snackBarTextColor, fontWeight: FontWeight.bold),
          ),
          duration: const Duration(seconds: 3),
          action: SnackBarAction(
            label: 'OPEN',
            textColor: currentTheme == AppThemeOption.cyberpunk2077
                ? const Color(0xFF00F0FF)
                : const Color(0xFFB5E48C),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const TransactionHistoryScreen(),
                ),
              );
            },
          ),
        ),
      );
      _nameController.clear();
      _amountController.clear();
      _merchantController.clear();
      _notesController.clear();
      setState(() => _receiptImage = null);
    }
  }

  void _showAddCategoryDialog() {
    final TextEditingController categoryController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Add Custom Category',
          style: ThemeService.getAppTextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        content: TextField(
          controller: categoryController,
          autofocus: true,
          style: ThemeService.getAppTextStyle(fontSize: 20),
          decoration: InputDecoration(
            labelText: 'Category Name',
            hintText: 'e.g., Entertainment, Gym',
            labelStyle: ThemeService.getAppTextStyle(fontSize: 18),
            hintStyle: ThemeService.getAppTextStyle(fontSize: 18),
            border: const OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: ThemeService.getAppTextStyle(fontSize: 18)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFFC6C7)),
            onPressed: () async {
              final newCategoryName = categoryController.text.trim();
              if (newCategoryName.isNotEmpty) {
                int newId = await DatabaseHelper.instance.insertCategory(newCategoryName);
                await _loadCategories();
                setState(() {
                  _selectedCategoryId = newId;
                });

                if (!context.mounted) return;
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Category "$newCategoryName" added!')),
                );
              }
            },
            child: Text('Save', style: ThemeService.getAppTextStyle(fontSize: 18, color: Colors.black)),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _amountController.dispose();
    _merchantController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Country>(
      valueListenable: CurrencyService.currentCountry,
      builder: (context, _, __) {
        return ValueListenableBuilder<AppThemeOption>(
          valueListenable: ThemeService.currentTheme,
          builder: (context, currentTheme, _) {
            final isDark = ThemeService.isDarkOrCyber;
            final shadowColor = ThemeService.getShadowColor();
            final borderColor = ThemeService.getBorderColor();
            final headerPillColor = ThemeService.getHeaderPillColor();

            final cardBgColor = isDark
                ? (currentTheme == AppThemeOption.cyberpunk2077
                ? const Color(0xFF1C050C)
                : (currentTheme == AppThemeOption.edgerunners
                ? const Color(0xFF161625)
                : const Color(0xFF282836)))
                : Colors.white;

            final cardTextColor = ThemeService.getTextColorForBackground(cardBgColor);

            return Scaffold(
              body: SafeArea(
                child: Column(
                  children: [
                    // 1. Top Pill Header
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
                        decoration: BoxDecoration(
                          color: headerPillColor,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: borderColor, width: 2.0),
                          boxShadow: [
                            BoxShadow(
                              color: shadowColor,
                              offset: const Offset(3, 3),
                              blurRadius: 0,
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            IconButton(
                              icon: Icon(
                                Icons.arrow_back,
                                color: ThemeService.getTextColorForBackground(headerPillColor),
                                size: 26,
                              ),
                              onPressed: () => Navigator.pop(context),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Add Transaction',
                                style: ThemeService.getAppTextStyle(
                                  fontSize: 26,
                                  fontWeight: FontWeight.bold,
                                  color: ThemeService.getTextColorForBackground(headerPillColor),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // 2. Main Form Content
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.all(16.0),
                        children: [
                          // Mode Selector Toggle Buttons
                          Row(
                            children: [
                              Expanded(
                                child: InkWell(
                                  onTap: () => setState(() => _isManualMode = true),
                                  borderRadius: BorderRadius.circular(16),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                    decoration: BoxDecoration(
                                      color: _isManualMode
                                          ? (isDark ? const Color(0xFF385E48) : const Color(0xFFD0F4DE))
                                          : (isDark ? const Color(0xFF2B2B38) : Colors.grey[200]),
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(color: borderColor, width: 1.8),
                                      boxShadow: [
                                        BoxShadow(
                                          color: shadowColor,
                                          offset: const Offset(2, 2),
                                          blurRadius: 0,
                                        ),
                                      ],
                                    ),
                                    child: Center(
                                      child: Text(
                                        'Manual Entry',
                                        style: ThemeService.getAppTextStyle(
                                          fontSize: 19,
                                          fontWeight: FontWeight.bold,
                                          color: _isManualMode
                                              ? ThemeService.getTextColorForBackground(const Color(0xFFD0F4DE))
                                              : (isDark ? Colors.white70 : Colors.black87),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: InkWell(
                                  onTap: () => setState(() => _isManualMode = false),
                                  borderRadius: BorderRadius.circular(16),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                    decoration: BoxDecoration(
                                      color: !_isManualMode
                                          ? (isDark ? const Color(0xFF324B66) : const Color(0xFFBCE6FF))
                                          : (isDark ? const Color(0xFF2B2B38) : Colors.grey[200]),
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(color: borderColor, width: 1.8),
                                      boxShadow: [
                                        BoxShadow(
                                          color: shadowColor,
                                          offset: const Offset(2, 2),
                                          blurRadius: 0,
                                        ),
                                      ],
                                    ),
                                    child: Center(
                                      child: Text(
                                        'Scan Receipt (OCR)',
                                        style: ThemeService.getAppTextStyle(
                                          fontSize: 19,
                                          fontWeight: FontWeight.bold,
                                          color: !_isManualMode
                                              ? ThemeService.getTextColorForBackground(const Color(0xFFBCE6FF))
                                              : (isDark ? Colors.white70 : Colors.black87),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),

                          // OCR Scanner View if selected
                          if (!_isManualMode) ...[
                            Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF223447) : const Color(0xFFBCE6FF),
                                borderRadius: BorderRadius.circular(22),
                                border: Border.all(color: borderColor, width: 2.0),
                                boxShadow: [
                                  BoxShadow(
                                    color: shadowColor,
                                    offset: const Offset(3, 3),
                                    blurRadius: 0,
                                  ),
                                ],
                              ),
                              child: Column(
                                children: [
                                  Icon(Icons.document_scanner, size: 52, color: isDark ? Colors.white : Colors.black),
                                  const SizedBox(height: 10),
                                  Text(
                                    'PaddleOCR Receipt Scanner',
                                    style: ThemeService.getAppTextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 22,
                                      color: isDark ? Colors.white : Colors.black,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Scan or upload a receipt to auto-fill Amount & Merchant below.',
                                    textAlign: TextAlign.center,
                                    style: ThemeService.getAppTextStyle(
                                      fontSize: 16,
                                      color: isDark ? Colors.white70 : Colors.black87,
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      ElevatedButton.icon(
                                        icon: const Icon(Icons.camera_alt),
                                        label: Text('Camera', style: ThemeService.getAppTextStyle(fontSize: 18)),
                                        onPressed: _scanReceiptWithCamera,
                                      ),
                                      const SizedBox(width: 12),
                                      ElevatedButton.icon(
                                        icon: const Icon(Icons.photo_library),
                                        label: Text('Gallery', style: ThemeService.getAppTextStyle(fontSize: 18)),
                                        onPressed: () => _pickReceiptImage(ImageSource.gallery),
                                      ),
                                    ],
                                  ),
                                  if (_isScanning) ...[
                                    const SizedBox(height: 20),
                                    const CircularProgressIndicator(),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Scanning receipt with PaddleOCR...',
                                      style: ThemeService.getAppTextStyle(fontSize: 16, color: isDark ? Colors.white : Colors.black),
                                    ),
                                  ]
                                ],
                              ),
                            ),
                            const SizedBox(height: 20),
                          ],

                          // Form Container Bounding Box Card
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: cardBgColor,
                              borderRadius: BorderRadius.circular(22),
                              border: Border.all(color: borderColor, width: 2.0),
                              boxShadow: [
                                BoxShadow(
                                  color: shadowColor,
                                  offset: const Offset(4, 4),
                                  blurRadius: 0,
                                ),
                              ],
                            ),
                            child: Form(
                              key: _formKey,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Transaction Name field (before Amount)
                                  TextFormField(
                                    controller: _nameController,
                                    style: ThemeService.getAppTextStyle(
                                      fontSize: 22,
                                      color: cardTextColor,
                                    ),
                                    decoration: InputDecoration(
                                      labelText: 'Transaction Name (e.g. Lunch, Coffee, Pen)',
                                      labelStyle: ThemeService.getAppTextStyle(
                                        fontSize: 18,
                                        color: cardTextColor.withValues(alpha: 0.7),
                                      ),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(14),
                                        borderSide: BorderSide(color: borderColor, width: 1.5),
                                      ),
                                    ),
                                    validator: (value) {
                                      if (value == null || value.trim().isEmpty) {
                                        return 'Please enter a transaction name';
                                      }
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 18),

                                  // Amount field
                                  TextFormField(
                                    controller: _amountController,
                                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                    style: ThemeService.getAppTextStyle(
                                      fontSize: 22,
                                      color: cardTextColor,
                                    ),
                                    decoration: InputDecoration(
                                      labelText: 'Amount (${CurrencyService.symbol})',
                                      labelStyle: ThemeService.getAppTextStyle(
                                        fontSize: 20,
                                        color: cardTextColor.withValues(alpha: 0.7),
                                      ),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(14),
                                        borderSide: BorderSide(color: borderColor, width: 1.5),
                                      ),
                                    ),
                                    validator: (value) {
                                      if (value == null || value.isEmpty || double.tryParse(value) == null) {
                                        return 'Please enter a valid amount';
                                      }
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 18),

                                  // Merchant / Vendor Name field
                                  TextFormField(
                                    controller: _merchantController,
                                    style: ThemeService.getAppTextStyle(
                                      fontSize: 22,
                                      color: cardTextColor,
                                    ),
                                    decoration: InputDecoration(
                                      labelText: 'Merchant / Vendor Name',
                                      labelStyle: ThemeService.getAppTextStyle(
                                        fontSize: 20,
                                        color: cardTextColor.withValues(alpha: 0.7),
                                      ),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(14),
                                        borderSide: BorderSide(color: borderColor, width: 1.5),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 18),

                                  // Dynamic Category Dropdown
                                  _isLoadingCategories
                                      ? const Center(child: CircularProgressIndicator())
                                      : Row(
                                    children: [
                                      Expanded(
                                        child: DropdownButtonFormField<int>(
                                          initialValue: _selectedCategoryId,
                                          dropdownColor: isDark ? const Color(0xFF282836) : Colors.white,
                                          style: ThemeService.getAppTextStyle(
                                            fontSize: 20,
                                            color: cardTextColor,
                                          ),
                                          decoration: InputDecoration(
                                            labelText: 'Category',
                                            labelStyle: ThemeService.getAppTextStyle(
                                              fontSize: 20,
                                              color: cardTextColor.withValues(alpha: 0.7),
                                            ),
                                            border: OutlineInputBorder(
                                              borderRadius: BorderRadius.circular(14),
                                              borderSide: BorderSide(color: borderColor, width: 1.5),
                                            ),
                                          ),
                                          items: _categories
                                              .map((cat) => DropdownMenuItem<int>(
                                            value: (cat['category_id'] as num?)?.toInt() ?? 0,
                                            child: Text(
                                              (cat['category_name'] as String?) ?? 'General',
                                              style: ThemeService.getAppTextStyle(
                                                fontSize: 20,
                                                color: cardTextColor,
                                              ),
                                            ),
                                          ))
                                              .toList(),
                                          onChanged: (value) => setState(() => _selectedCategoryId = value),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      IconButton(
                                        icon: const Icon(Icons.add_circle, color: Colors.green, size: 36),
                                        tooltip: 'Add Custom Category',
                                        onPressed: _showAddCategoryDialog,
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 18),

                                  // Notes field
                                  TextFormField(
                                    controller: _notesController,
                                    maxLines: 2,
                                    style: ThemeService.getAppTextStyle(
                                      fontSize: 20,
                                      color: cardTextColor,
                                    ),
                                    decoration: InputDecoration(
                                      labelText: 'Notes (Optional)',
                                      labelStyle: ThemeService.getAppTextStyle(
                                        fontSize: 18,
                                        color: cardTextColor.withValues(alpha: 0.7),
                                      ),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(14),
                                        borderSide: BorderSide(color: borderColor, width: 1.5),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 18),

                                  // Attached Receipt Badge if file exists
                                  if (_receiptImage != null && _receiptImage!.existsSync()) ...[
                                    Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: isDark ? const Color(0xFF222238) : const Color(0xFFE8F5E9),
                                        borderRadius: BorderRadius.circular(14),
                                        border: Border.all(color: Colors.green, width: 1.5),
                                      ),
                                      child: Row(
                                        children: [
                                          const Icon(Icons.check_circle, color: Colors.green, size: 24),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: Text(
                                              'Receipt attached and ready to save locally',
                                              style: ThemeService.getAppTextStyle(
                                                fontSize: 15,
                                                fontWeight: FontWeight.bold,
                                                color: isDark ? Colors.white : Colors.black87,
                                              ),
                                            ),
                                          ),
                                          IconButton(
                                            icon: const Icon(Icons.close, color: Colors.redAccent, size: 20),
                                            tooltip: 'Remove receipt',
                                            onPressed: () => setState(() => _receiptImage = null),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 18),
                                  ],

                                  // Save Button
                                  InkWell(
                                    onTap: _saveTransaction,
                                    borderRadius: BorderRadius.circular(16),
                                    child: Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.symmetric(vertical: 14),
                                      decoration: BoxDecoration(
                                        color: currentTheme == AppThemeOption.cyberpunk2077
                                            ? const Color(0xFFFF003C)
                                            : (currentTheme == AppThemeOption.edgerunners
                                            ? const Color(0xFFFEE715)
                                            : const Color(0xFFD0F4DE)),
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(color: borderColor, width: 2.0),
                                        boxShadow: [
                                          BoxShadow(
                                            color: shadowColor,
                                            offset: const Offset(3, 3),
                                            blurRadius: 0,
                                          ),
                                        ],
                                      ),
                                      child: Center(
                                        child: Text(
                                          'Save Expense',
                                          style: ThemeService.getAppTextStyle(
                                            fontSize: 22,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.black,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
