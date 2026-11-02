import 'package:flutter/material.dart';
import '../database/database_helper.dart';
import '../services/theme_service.dart';

class CategoriesScreen extends StatefulWidget {
  const CategoriesScreen({super.key});

  @override
  State<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends State<CategoriesScreen> {
  List<Map<String, dynamic>> _categories = [];
  bool _isLoading = true;
  final TextEditingController _categoryController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    setState(() => _isLoading = true);
    final data = await DatabaseHelper.instance.getCategories();

    if (data.isEmpty) {
      await DatabaseHelper.instance.insertCategory('Food');
      await DatabaseHelper.instance.insertCategory('Transport');
      await DatabaseHelper.instance.insertCategory('Stationery');
      await DatabaseHelper.instance.insertCategory('Clothes');
      await DatabaseHelper.instance.insertCategory('Electronics');
      await DatabaseHelper.instance.insertCategory('Health');
      await DatabaseHelper.instance.insertCategory('Groceries');
      final updatedData = await DatabaseHelper.instance.getCategories();
      setState(() {
        _categories = updatedData;
        _isLoading = false;
      });
    } else {
      setState(() {
        _categories = data;
        _isLoading = false;
      });
    }
  }

  Future<void> _addCategory() async {
    final text = _categoryController.text.trim();
    if (text.isEmpty) return;

    await DatabaseHelper.instance.insertCategory(text);
    _categoryController.clear();
    await _loadCategories();
  }

  Future<void> _deleteCategory(int categoryId) async {
    await DatabaseHelper.instance.deleteCategory(categoryId);
    await _loadCategories();
  }

  @override
  Widget build(BuildContext context) {
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
            ? const Color(0xFF16162A)
            : const Color(0xFF282836)))
            : const Color(0xFFFFC6C7);

        final cardTextColor = ThemeService.getTextColorForBackground(cardBgColor);

        return Scaffold(
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  // Header Card with Back Arrow
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
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
                            size: 28,
                          ),
                          onPressed: () => Navigator.pop(context),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Categories',
                          style: ThemeService.getAppTextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                            color: ThemeService.getTextColorForBackground(headerPillColor),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Main Content Card
                  Expanded(
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20.0),
                      decoration: BoxDecoration(
                        color: cardBgColor,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: borderColor, width: 2.5),
                        boxShadow: [
                          BoxShadow(
                            color: shadowColor,
                            offset: const Offset(4, 4),
                            blurRadius: 0,
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          // List of Categories
                          Expanded(
                            child: _isLoading
                                ? const Center(child: CircularProgressIndicator())
                                : ListView.builder(
                              itemCount: _categories.length,
                              itemBuilder: (context, index) {
                                final item = _categories[index];
                                final name = item['category_name'] ?? '';
                                final id = item['category_id'] as int?;

                                return Container(
                                  margin: const EdgeInsets.symmetric(vertical: 6.0),
                                  padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        name,
                                        style: ThemeService.getAppTextStyle(
                                          fontSize: 24,
                                          fontWeight: FontWeight.w600,
                                          color: cardTextColor,
                                        ),
                                      ),
                                      if (id != null)
                                        IconButton(
                                          icon: Icon(
                                            Icons.close,
                                            size: 22,
                                            color: cardTextColor.withValues(alpha: 0.7),
                                          ),
                                          onPressed: () => _deleteCategory(id),
                                          tooltip: 'Delete Category',
                                        ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ),
                          const SizedBox(height: 12),

                          // Add Category Section
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF222238) : const Color(0xFFFFF3BF),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: borderColor, width: 2.0),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: _categoryController,
                                    style: ThemeService.getAppTextStyle(
                                      fontSize: 22,
                                      color: isDark ? Colors.white : Colors.black,
                                    ),
                                    decoration: InputDecoration(
                                      hintText: 'Add Category',
                                      hintStyle: ThemeService.getAppTextStyle(
                                        fontSize: 22,
                                        color: isDark ? Colors.white54 : Colors.black54,
                                      ),
                                      border: InputBorder.none,
                                      isDense: true,
                                    ),
                                    onSubmitted: (_) => _addCategory(),
                                  ),
                                ),
                                IconButton(
                                  icon: Icon(
                                    Icons.add,
                                    size: 32,
                                    color: isDark ? Colors.white : Colors.black,
                                  ),
                                  onPressed: _addCategory,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
