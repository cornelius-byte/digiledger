import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../database/database_helper.dart';

class AddTransactionScreen extends StatefulWidget {
  const AddTransactionScreen({super.key});

  @override
  State<AddTransactionScreen> createState() => _AddTransactionScreenState();
}

class _AddTransactionScreenState extends State<AddTransactionScreen> {
  // Mode toggle: true for Manual, false for OCR Scanner
  bool _isManualMode = true;

  final _formKey = GlobalKey<FormState>();
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _merchantController = TextEditingController();

  String _selectedType = 'Expense';
  int? _selectedCategoryId;
  bool _isLoadingCategories = true;

  File? _receiptImage;
  bool _isScanning = false;

  // Dynamically loaded categories from SQLite 3NF database
  var _categories = [];

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  // Fetch categories from database helper
  Future<void> _loadCategories() async {
    try {
      final categoriesData = await DatabaseHelper.instance.getCategories();
      setState(() {
        _categories = categoriesData;
        if (_categories.isNotEmpty) {
          // Use 'category_id' instead of 'id'
          _selectedCategoryId = (_categories.first['category_id'] as num?)?.toInt();
        }
        _isLoadingCategories = false;
      });
    } catch (e) {
      setState(() => _isLoadingCategories = false);
    }
  }

  // Image Picker for OCR
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

  // Simulated OCR Pipeline matching your flowchart specification
  void _runOcrPipeline() async {
    setState(() => _isScanning = true);

    // Simulate OCR processing delay (DBNet Detection -> CRNN Recognition -> Heuristics)
    await Future.delayed(const Duration(seconds: 2));

    // Mock extracted values from receipt text processing
    setState(() {
      _merchantController.text = "Supermarket Mart";
      _amountController.text = "45.50";
      _isScanning = false;
      _isManualMode = true; // Switch back to form with auto-filled data!
    });

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('OCR Success: Receipt parsed and auto-filled!')),
    );
  }

  void _saveTransaction() async {
    if (_formKey.currentState!.validate() && _selectedCategoryId != null) {
      final amount = double.parse(_amountController.text);
      final merchant = _merchantController.text.isEmpty ? 'Unknown' : _merchantController.text;
      final date = DateTime.now().toIso8601String();

      await DatabaseHelper.instance.insertTransaction({
        'amount': amount,
        'type': _selectedType,
        'date': date,
        'merchant': merchant,
        'notes': _receiptImage != null ? 'Scanned Receipt' : 'Manual entry',
        'receipt_image_path': _receiptImage?.path,
        'category_id': _selectedCategoryId,
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Transaction saved locally!')),
      );
      _amountController.clear();
      _merchantController.clear();
      setState(() => _receiptImage = null);
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _merchantController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Transaction'),
        backgroundColor: const Color(0xFFFFC6C7), // Pink Accent
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView(
          children: [
            // Mode Selector Toggle Buttons
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isManualMode ? const Color(0xFFD0F4DE) : Colors.grey[200],
                      foregroundColor: Colors.black,
                    ),
                    onPressed: () => setState(() => _isManualMode = true),
                    child: const Text('Manual Entry'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: !_isManualMode ? const Color(0xFFBCE6FF) : Colors.grey[200],
                      foregroundColor: Colors.black,
                    ),
                    onPressed: () => setState(() => _isManualMode = false),
                    child: const Text('Scan Receipt (OCR)'),
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
                  color: const Color(0xFFBCE6FF),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.black, width: 1.5),
                ),
                child: Column(
                  children: [
                    const Icon(Icons.document_scanner, size: 48),
                    const SizedBox(height: 10),
                    const Text(
                      'PaddleOCR / ML Kit Receipt Scanner',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Capture or upload a receipt to automatically extract the merchant name and total amount.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ElevatedButton.icon(
                          icon: const Icon(Icons.camera_alt),
                          label: const Text('Camera'),
                          onPressed: () => _pickReceiptImage(ImageSource.camera),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton.icon(
                          icon: const Icon(Icons.photo_library),
                          label: const Text('Gallery'),
                          onPressed: () => _pickReceiptImage(ImageSource.gallery),
                        ),
                      ],
                    ),
                    if (_isScanning) ...[
                      const SizedBox(height: 20),
                      const CircularProgressIndicator(),
                      const SizedBox(height: 8),
                      const Text('Processing OCR Pipeline (DBNet & CRNN)...'),
                    ]
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],

            // Main Transaction Form (Used for both Manual & Auto-filled OCR data)
            Form(
              key: _formKey,
              child: Column(
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: _selectedType,
                    decoration: const InputDecoration(labelText: 'Transaction Type'),
                    items: ['Expense', 'Income']
                        .map((type) => DropdownMenuItem(value: type, child: Text(type)))
                        .toList(),
                    onChanged: (value) => setState(() => _selectedType = value!),
                  ),
                  const SizedBox(height: 16),

                  TextFormField(
                    controller: _amountController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Amount (\$)',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty || double.tryParse(value) == null) {
                        return 'Please enter a valid amount';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  TextFormField(
                    controller: _merchantController,
                    decoration: const InputDecoration(
                      labelText: 'Merchant / Vendor Name',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Dynamic Category Dropdown from DB
                  _isLoadingCategories
                      ? const Center(child: CircularProgressIndicator())
                      : DropdownButtonFormField<int>(
                    initialValue: _selectedCategoryId,
                    decoration: const InputDecoration(labelText: 'Category'),
                    items: _categories
                        .map((cat) => DropdownMenuItem<int>(
                      // Use 'category_id' and 'category_name'
                      value: (cat['category_id'] as num?)?.toInt() ?? 0,
                      child: Text((cat['category_name'] as String?) ?? 'General'),
                    ))
                        .toList(),
                    onChanged: (value) => setState(() => _selectedCategoryId = value),
                  ),
                  const SizedBox(height: 30),

                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFD0F4DE),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      minimumSize: const Size(double.infinity, 50),
                    ),
                    onPressed: _saveTransaction,
                    child: const Text(
                      'Save Transaction',
                      style: TextStyle(fontSize: 16, color: Colors.black, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}