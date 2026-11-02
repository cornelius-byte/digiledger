import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../database/database_helper.dart';
import '../services/theme_service.dart';

class AnalyticsScreen extends StatelessWidget {
  const AnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AppThemeOption>(
      valueListenable: ThemeService.currentTheme,
      builder: (context, currentTheme, _) {
        final shadowColor = ThemeService.getShadowColor();
        final borderColor = ThemeService.getBorderColor();
        final headerPillColor = ThemeService.getHeaderPillColor();

        return DefaultTabController(
          length: 2,
          child: Scaffold(
            body: SafeArea(
              child: Column(
                children: [
                  // Top Pill Header
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
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
                      child: Column(
                        children: [
                          Row(
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
                              Text(
                                'Analytics',
                                style: ThemeService.getAppTextStyle(
                                  fontSize: 26,
                                  fontWeight: FontWeight.bold,
                                  color: ThemeService.getTextColorForBackground(headerPillColor),
                                ),
                              ),
                            ],
                          ),
                          TabBar(
                            labelColor: ThemeService.getTextColorForBackground(headerPillColor),
                            unselectedLabelColor: ThemeService.getTextColorForBackground(headerPillColor).withValues(alpha: 0.6),
                            indicatorColor: ThemeService.getTextColorForBackground(headerPillColor),
                            indicatorWeight: 3,
                            labelStyle: ThemeService.getAppTextStyle(fontSize: 19, fontWeight: FontWeight.bold),
                            unselectedLabelStyle: ThemeService.getAppTextStyle(fontSize: 18),
                            tabs: const [
                              Tab(text: 'Charts'),
                              Tab(text: 'Spending Trends'),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Tab Views
                  const Expanded(
                    child: TabBarView(
                      children: [
                        ChartsTab(),
                        SpendingTrendsTab(),
                      ],
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

// ----------------- TAB 1: CHARTS -----------------
class ChartsTab extends StatefulWidget {
  const ChartsTab({super.key});

  @override
  State<ChartsTab> createState() => _ChartsTabState();
}

class _ChartsTabState extends State<ChartsTab> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _categories = [];
  List<Map<String, dynamic>> _transactions = [];

  final List<Color> _colorPalette = [
    const Color(0xFFFF6B6B),
    const Color(0xFF4D96FF),
    const Color(0xFF6BCB77),
    const Color(0xFFFFD93D),
    const Color(0xFF9376E0),
    const Color(0xFFFF8FB1),
    const Color(0xFF00EAD3),
  ];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final cats = await DatabaseHelper.instance.getCategories();
    final txs = await DatabaseHelper.instance.getFilteredTransactions();
    setState(() {
      _categories = cats;
      _transactions = txs;
      _isLoading = false;
    });
  }

  String _getMonthName(int month) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return months[month - 1];
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());

    return ValueListenableBuilder<AppThemeOption>(
      valueListenable: ThemeService.currentTheme,
      builder: (context, currentTheme, _) {
        final isDark = ThemeService.isDarkOrCyber;
        final shadowColor = ThemeService.getShadowColor();
        final borderColor = ThemeService.getBorderColor();

        final cardBgColor = isDark
            ? (currentTheme == AppThemeOption.cyberpunk2077
            ? const Color(0xFF1C050C)
            : (currentTheme == AppThemeOption.edgerunners
            ? const Color(0xFF161625)
            : const Color(0xFF282836)))
            : Colors.white;

        final cardTextColor = ThemeService.getTextColorForBackground(cardBgColor);

        double total = 0;
        Map<int, double> catSpending = {};
        for (var tx in _transactions) {
          double amt = (tx['amount'] as num?)?.toDouble() ?? 0;
          int catId = (tx['category_id'] as num?)?.toInt() ?? 0;
          total += amt;
          catSpending[catId] = (catSpending[catId] ?? 0) + amt;
        }

        final activeCategories = _categories.where((cat) {
          int id = (cat['category_id'] as num?)?.toInt() ?? 0;
          return (catSpending[id] ?? 0) > 0;
        }).toList();

        int currentYear = DateTime.now().year;
        Map<DateTime, double> monthlyMap = {};
        for (var tx in _transactions) {
          final dateStr = tx['date'] as String? ?? DateTime.now().toIso8601String();
          final date = DateTime.tryParse(dateStr) ?? DateTime.now();

          if (date.year == currentYear) {
            DateTime monthKey = DateTime(date.year, date.month, 1);
            double amt = (tx['amount'] as num?)?.toDouble() ?? 0;
            monthlyMap[monthKey] = (monthlyMap[monthKey] ?? 0) + amt;
          }
        }

        final sortedMonths = monthlyMap.keys.toList()..sort();

        return RefreshIndicator(
          onRefresh: _loadData,
          child: ListView(
            padding: const EdgeInsets.all(16.0),
            children: [
              // Category Distribution Card
              Container(
                padding: const EdgeInsets.all(18),
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Category Distribution',
                      style: ThemeService.getAppTextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: cardTextColor,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        SizedBox(
                          width: 120,
                          height: 120,
                          child: CustomPaint(
                            painter: PieRingPainter(
                              categories: activeCategories,
                              catSpending: catSpending,
                              total: total,
                              colors: _colorPalette,
                            ),
                            child: Center(
                              child: Text(
                                '\$${total.toStringAsFixed(0)}',
                                style: ThemeService.getAppTextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 20,
                                  color: cardTextColor,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: activeCategories.asMap().entries.map((entry) {
                              int index = entry.key;
                              var cat = entry.value;
                              int id = (cat['category_id'] as num?)?.toInt() ?? 0;
                              String name = cat['category_name'] ?? 'General';
                              double spent = catSpending[id] ?? 0;
                              double pct = total > 0 ? (spent / total) * 100 : 0;
                              Color color = _colorPalette[index % _colorPalette.length];

                              return Padding(
                                padding: const EdgeInsets.only(bottom: 6.0),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 12,
                                      height: 12,
                                      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                                    ),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        '$name (${pct.toStringAsFixed(0)}%) - \$${spent.toStringAsFixed(2)}',
                                        style: ThemeService.getAppTextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: cardTextColor,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Monthly Expense Bar Chart Card
              Container(
                padding: const EdgeInsets.all(18),
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Monthly Expense Bar Chart ($currentYear)',
                      style: ThemeService.getAppTextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: cardTextColor,
                      ),
                    ),
                    const SizedBox(height: 20),
                    sortedMonths.isEmpty
                        ? Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Center(
                        child: Text(
                          'No monthly data recorded for this year.',
                          style: ThemeService.getAppTextStyle(
                            fontSize: 18,
                            color: isDark ? Colors.white54 : Colors.black54,
                          ),
                        ),
                      ),
                    )
                        : SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: SizedBox(
                        height: 170,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: sortedMonths.asMap().entries.map((entry) {
                            int index = entry.key;
                            DateTime monthDate = entry.value;
                            double val = monthlyMap[monthDate] ?? 0;
                            double maxHeight = monthlyMap.values.reduce((a, b) => a > b ? a : b);
                            double barHeight = maxHeight > 0 ? (val / maxHeight) * 90 : 20;
                            if (barHeight < 20) barHeight = 20;
                            Color barColor = _colorPalette[index % _colorPalette.length];
                            String monthLabel = _getMonthName(monthDate.month);

                            return Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16.0),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  Text(
                                    '\$${val.toStringAsFixed(0)}',
                                    style: ThemeService.getAppTextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                      color: cardTextColor,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Container(
                                    width: 36,
                                    height: barHeight,
                                    decoration: BoxDecoration(
                                      color: barColor,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: borderColor, width: 1.5),
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    monthLabel,
                                    style: ThemeService.getAppTextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: cardTextColor,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class PieRingPainter extends CustomPainter {
  final List<Map<String, dynamic>> categories;
  final Map<int, double> catSpending;
  final double total;
  final List<Color> colors;

  PieRingPainter({required this.categories, required this.catSpending, required this.total, required this.colors});

  @override
  void paint(Canvas canvas, Size size) {
    if (total == 0) return;
    Paint paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 16
      ..strokeCap = StrokeCap.butt;

    double startAngle = -math.pi / 2;
    Rect rect = Offset.zero & size;

    for (int i = 0; i < categories.length; i++) {
      int id = (categories[i]['category_id'] as num?)?.toInt() ?? 0;
      double spent = catSpending[id] ?? 0;
      if (spent <= 0) continue;

      double sweepAngle = (spent / total) * 2 * math.pi;
      paint.color = colors[i % colors.length];

      canvas.drawArc(rect.deflate(8), startAngle, sweepAngle, false, paint);
      startAngle += sweepAngle;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

// ----------------- TAB 2: SPENDING TRENDS -----------------
class SpendingTrendsTab extends StatefulWidget {
  const SpendingTrendsTab({super.key});

  @override
  State<SpendingTrendsTab> createState() => _SpendingTrendsTabState();
}

class _SpendingTrendsTabState extends State<SpendingTrendsTab> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _transactions = [];
  List<Map<String, dynamic>> _categories = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final txs = await DatabaseHelper.instance.getFilteredTransactions();
    final cats = await DatabaseHelper.instance.getCategories();
    setState(() {
      _transactions = txs;
      _categories = cats;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());

    return ValueListenableBuilder<AppThemeOption>(
      valueListenable: ThemeService.currentTheme,
      builder: (context, currentTheme, _) {
        final isDark = ThemeService.isDarkOrCyber;
        final shadowColor = ThemeService.getShadowColor();
        final borderColor = ThemeService.getBorderColor();

        final cardBgColor = isDark
            ? (currentTheme == AppThemeOption.cyberpunk2077
            ? const Color(0xFF1C050C)
            : (currentTheme == AppThemeOption.edgerunners
            ? const Color(0xFF161625)
            : const Color(0xFF282836)))
            : Colors.white;

        final cardTextColor = ThemeService.getTextColorForBackground(cardBgColor);

        final now = DateTime.now();
        int daysSinceSunday = now.weekday % 7;
        DateTime startOfWeek = DateTime(now.year, now.month, now.day).subtract(Duration(days: daysSinceSunday));
        DateTime endOfWeek = startOfWeek.add(const Duration(days: 6, hours: 23, minutes: 59, seconds: 59));

        final weekTransactions = _transactions.where((tx) {
          final dateStr = tx['date'] as String? ?? now.toIso8601String();
          final date = DateTime.tryParse(dateStr) ?? now;
          return date.isAfter(startOfWeek.subtract(const Duration(seconds: 1))) &&
              date.isBefore(endOfWeek.add(const Duration(seconds: 1)));
        }).toList();

        double currentWeekTotal = 0;
        for (var tx in weekTransactions) {
          currentWeekTotal += (tx['amount'] as num?)?.toDouble() ?? 0;
        }

        Map<String, double> weekdayTotals = {
          'Sun': 0, 'Mon': 0, 'Tue': 0, 'Wed': 0, 'Thu': 0, 'Fri': 0, 'Sat': 0
        };

        for (var tx in weekTransactions) {
          final dateStr = tx['date'] as String? ?? now.toIso8601String();
          final date = DateTime.tryParse(dateStr) ?? now;
          double amt = (tx['amount'] as num?)?.toDouble() ?? 0;

          if (date.weekday == 7) weekdayTotals['Sun'] = weekdayTotals['Sun']! + amt;
          if (date.weekday == 1) weekdayTotals['Mon'] = weekdayTotals['Mon']! + amt;
          if (date.weekday == 2) weekdayTotals['Tue'] = weekdayTotals['Tue']! + amt;
          if (date.weekday == 3) weekdayTotals['Wed'] = weekdayTotals['Wed']! + amt;
          if (date.weekday == 4) weekdayTotals['Thu'] = weekdayTotals['Thu']! + amt;
          if (date.weekday == 5) weekdayTotals['Fri'] = weekdayTotals['Fri']! + amt;
          if (date.weekday == 6) weekdayTotals['Sat'] = weekdayTotals['Sat']! + amt;
        }

        Map<int, double> catMap = {};
        for (var tx in _transactions) {
          int catId = (tx['category_id'] as num?)?.toInt() ?? 0;
          double amt = (tx['amount'] as num?)?.toDouble() ?? 0;
          catMap[catId] = (catMap[catId] ?? 0) + amt;
        }

        String topCategoryName = 'General';
        if (catMap.isNotEmpty) {
          int topId = catMap.entries.reduce((a, b) => a.value > b.value ? a : b).key;
          final matchedCat = _categories.firstWhere(
                (c) => (c['category_id'] as num?)?.toInt() == topId,
            orElse: () => <String, Object?>{},
          );
          if (matchedCat.isNotEmpty) {
            topCategoryName = matchedCat['category_name']?.toString() ?? 'General';
          }
        }

        final List<Color> trendColors = [
          const Color(0xFFFF6B6B),
          const Color(0xFF4D96FF),
          const Color(0xFF6BCB77),
          const Color(0xFFFFD93D),
          const Color(0xFF9376E0),
          const Color(0xFFFF8FB1),
          const Color(0xFF00EAD3),
        ];

        return RefreshIndicator(
          onRefresh: _loadData,
          child: ListView(
            padding: const EdgeInsets.all(16.0),
            children: [
              // Summary Header Card
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: isDark
                      ? (currentTheme == AppThemeOption.cyberpunk2077
                      ? const Color(0xFF2B0512)
                      : const Color(0xFF382B44))
                      : const Color(0xFFFFC6C7),
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
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Current Week Spending (Sun-Sat): \$${currentWeekTotal.toStringAsFixed(2)}',
                      style: ThemeService.getAppTextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: ThemeService.getTextColorForBackground(isDark ? const Color(0xFF382B44) : const Color(0xFFFFC6C7)),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Refreshes automatically every Sunday.',
                      style: ThemeService.getAppTextStyle(
                        fontSize: 16,
                        color: ThemeService.getSecondaryTextColorForBackground(isDark ? const Color(0xFF382B44) : const Color(0xFFFFC6C7)),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Daily Spending Wave Graph
              Container(
                padding: const EdgeInsets.all(18),
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Daily Spending Wave (This Week)',
                      style: ThemeService.getAppTextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: cardTextColor,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Container(
                      height: 160,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E1E2C) : Colors.grey[50],
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: borderColor, width: 1.5),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: weekdayTotals.entries.toList().asMap().entries.map((mapEntry) {
                          int index = mapEntry.key;
                          var entry = mapEntry.value;
                          double val = entry.value;
                          double maxVal = weekdayTotals.values.fold(0.0, (a, b) => a > b ? a : b);
                          double height = maxVal > 0 ? (val / maxVal) * 80 : 10;
                          if (height < 10) height = 10;
                          Color barColor = trendColors[index % trendColors.length];

                          return Column(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Text(
                                '\$${val.toStringAsFixed(0)}',
                                style: ThemeService.getAppTextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: cardTextColor,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Container(
                                width: 22,
                                height: height,
                                decoration: BoxDecoration(
                                  color: barColor,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: borderColor, width: 1.2),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                entry.key,
                                style: ThemeService.getAppTextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: cardTextColor,
                                ),
                              ),
                            ],
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Smart Insight Card
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF383322) : const Color(0xFFFFF1BA),
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
                child: Row(
                  children: [
                    const Icon(Icons.lightbulb, color: Colors.amber, size: 32),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Insight:',
                            style: ThemeService.getAppTextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 20,
                              color: isDark ? Colors.amberAccent : Colors.black,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Your highest overall spending is concentrated in "$topCategoryName".',
                            style: ThemeService.getAppTextStyle(
                              fontSize: 18,
                              color: isDark ? Colors.white70 : Colors.black87,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
