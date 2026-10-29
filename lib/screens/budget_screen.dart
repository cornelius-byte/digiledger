import 'package:flutter/material.dart';
import '../database/database_helper.dart';

class BudgetScreen extends StatefulWidget {
  const BudgetScreen({super.key});

  @override
  State<BudgetScreen> createState() => _BudgetScreenState();
}

class _BudgetScreenState extends State<BudgetScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _limitController = TextEditingController();

  String _selectedInterval = 'Monthly';
  double _selectedWarningPercent = 75.0; // Default warning at 75%
  double _currentSpending = 0.0;
  double _budgetLimit = 500.0; // Default mock limit for display

  @override
  void initState() {
    super.initState();
    _fetchBudgetStatus();
  }

  Future<void> _fetchBudgetStatus() async {
    final spending = await DatabaseHelper.instance.getMonthlySpending();
    setState(() {
      _currentSpending = spending;
    });
  }

  void _saveBudget() {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _budgetLimit = double.parse(_limitController.text);
      });

      // Check threshold rules based on your algorithm spec
      double warningThresholdAmount = _budgetLimit * (_selectedWarningPercent / 100.0);

      String alertMessage = 'Budget saved successfully!';
      if (_currentSpending >= _budgetLimit) {
        alertMessage = '⚠️ Warning: Current spending has reached or exceeded the budget limit!';
      } else if (_currentSpending >= warningThresholdAmount) {
        alertMessage = '⚠️ Notice: You have reached your ${_selectedWarningPercent.toInt()}% warning threshold!';
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(alertMessage), duration: const Duration(seconds: 4)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Calculate progress ratio for visual indicator
    double progress = _budgetLimit > 0 ? (_currentSpending / _budgetLimit).clamp(0.0, 1.0) : 0.0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Budget Management'),
        backgroundColor: const Color(0xFFD0F4DE), // Mint Green
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView(
          children: [
            // Current Status Visual Card
            Container(
              padding: const EdgeInsets.all(20.0),
              decoration: BoxDecoration(
                color: const Color(0xFFFFC6C7), // Pink Accent
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.black, width: 1.5),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Budget Tracking Status',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  Text('Spent: \$$_currentSpending / Limit: \$$_budgetLimit'),
                  const SizedBox(height: 8),
                  LinearProgressIndicator(
                    value: progress,
                    backgroundColor: Colors.white,
                    color: progress >= 1.0 ? Colors.red : Colors.black,
                    minHeight: 10,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Warning Threshold set at: ${_selectedWarningPercent.toInt()}%',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Form to Set New Budget (Algorithm Step 1 & 2)
            Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Set New Budget Limit',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),

                  // Time Interval Selector
                  DropdownButtonFormField<String>(
                    initialValue: _selectedInterval,
                    decoration: const InputDecoration(labelText: 'Time Interval'),
                    items: ['Weekly', 'Monthly', 'Yearly']
                        .map((interval) => DropdownMenuItem(value: interval, child: Text(interval)))
                        .toList(),
                    onChanged: (value) => setState(() => _selectedInterval = value!),
                  ),
                  const SizedBox(height: 16),

                  // Limit Amount Input
                  TextFormField(
                    controller: _limitController,
                    keyboardType: TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Budget Limit Amount (\$)',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty || double.tryParse(value) == null) {
                        return 'Please enter a valid limit';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // Warning Portion Selector (25%, 50%, 75%, 100%)
                  DropdownButtonFormField<double>(
                    initialValue: _selectedWarningPercent,
                    decoration: const InputDecoration(labelText: 'Warning Threshold Portion'),
                    items: const [
                      DropdownMenuItem(value: 25.0, child: Text('25% of Budget')),
                      DropdownMenuItem(value: 50.0, child: Text('50% of Budget')),
                      DropdownMenuItem(value: 75.0, child: Text('75% of Budget')),
                      DropdownMenuItem(value: 100.0, child: Text('100% (Limit Reached)')),
                    ],
                    onChanged: (value) => setState(() => _selectedWarningPercent = value!),
                  ),
                  const SizedBox(height: 30),

                  // Save Budget Button
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFBCE6FF), // Light Blue
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      minimumSize: const Size(double.infinity, 50),
                    ),
                    onPressed: _saveBudget,
                    child: const Text(
                      'Save & Apply Budget Rules',
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