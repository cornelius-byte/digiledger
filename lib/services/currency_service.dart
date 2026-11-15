import 'package:flutter/material.dart';
import '../database/database_helper.dart';
import 'theme_service.dart';

class Country {
  final String code;
  final String name;
  final String currencyCode;
  final String symbol;
  final String flag;

  const Country({
    required this.code,
    required this.name,
    required this.currencyCode,
    required this.symbol,
    required this.flag,
  });
}

class CurrencyService {
  static const Country defaultCountry = Country(
    code: 'US',
    name: 'United States',
    currencyCode: 'USD',
    symbol: '\$',
    flag: '🇺🇸',
  );

  static const List<Country> supportedCountries = [
    Country(code: 'US', name: 'United States', currencyCode: 'USD', symbol: '\$', flag: '🇺🇸'),
    Country(code: 'GB', name: 'United Kingdom', currencyCode: 'GBP', symbol: '£', flag: '🇬🇧'),
    Country(code: 'EU', name: 'Eurozone (EU)', currencyCode: 'EUR', symbol: '€', flag: '🇪🇺'),
    Country(code: 'IN', name: 'India', currencyCode: 'INR', symbol: '₹', flag: '🇮🇳'),
    Country(code: 'CA', name: 'Canada', currencyCode: 'CAD', symbol: 'CA\$', flag: '🇨🇦'),
    Country(code: 'AU', name: 'Australia', currencyCode: 'AUD', symbol: 'A\$', flag: '🇦🇺'),
    Country(code: 'JP', name: 'Japan', currencyCode: 'JPY', symbol: '¥', flag: '🇯🇵'),
    Country(code: 'CN', name: 'China', currencyCode: 'CNY', symbol: '¥', flag: '🇨🇳'),
    Country(code: 'BR', name: 'Brazil', currencyCode: 'BRL', symbol: 'R\$', flag: '🇧🇷'),
    Country(code: 'MX', name: 'Mexico', currencyCode: 'MXN', symbol: 'MX\$', flag: '🇲🇽'),
    Country(code: 'KR', name: 'South Korea', currencyCode: 'KRW', symbol: '₩', flag: '🇰🇷'),
    Country(code: 'NG', name: 'Nigeria', currencyCode: 'NGN', symbol: '₦', flag: '🇳🇬'),
    Country(code: 'ZA', name: 'South Africa', currencyCode: 'ZAR', symbol: 'R', flag: '🇿🇦'),
    Country(code: 'SA', name: 'Saudi Arabia', currencyCode: 'SAR', symbol: '﷼', flag: '🇸🇦'),
    Country(code: 'AE', name: 'United Arab Emirates', currencyCode: 'AED', symbol: 'د.إ', flag: '🇦🇪'),
    Country(code: 'PK', name: 'Pakistan', currencyCode: 'PKR', symbol: 'Rs', flag: '🇵🇰'),
    Country(code: 'BD', name: 'Bangladesh', currencyCode: 'BDT', symbol: '৳', flag: '🇧🇩'),
    Country(code: 'ID', name: 'Indonesia', currencyCode: 'IDR', symbol: 'Rp', flag: '🇮🇩'),
    Country(code: 'MY', name: 'Malaysia', currencyCode: 'MYR', symbol: 'RM', flag: '🇲🇾'),
    Country(code: 'PH', name: 'Philippines', currencyCode: 'PHP', symbol: '₱', flag: '🇵🇭'),
    Country(code: 'SG', name: 'Singapore', currencyCode: 'SGD', symbol: 'S\$', flag: '🇸🇬'),
    Country(code: 'NZ', name: 'New Zealand', currencyCode: 'NZD', symbol: 'NZ\$', flag: '🇳🇿'),
    Country(code: 'CH', name: 'Switzerland', currencyCode: 'CHF', symbol: 'CHF', flag: '🇨🇭'),
    Country(code: 'SE', name: 'Sweden', currencyCode: 'SEK', symbol: 'kr', flag: '🇸🇪'),
    Country(code: 'NO', name: 'Norway', currencyCode: 'NOK', symbol: 'kr', flag: '🇳🇴'),
    Country(code: 'DK', name: 'Denmark', currencyCode: 'DKK', symbol: 'kr', flag: '🇩🇰'),
    Country(code: 'TR', name: 'Turkey', currencyCode: 'TRY', symbol: '₺', flag: '🇹🇷'),
    Country(code: 'EG', name: 'Egypt', currencyCode: 'EGP', symbol: 'E£', flag: '🇪🇬'),
    Country(code: 'KE', name: 'Kenya', currencyCode: 'KES', symbol: 'KSh', flag: '🇰🇪'),
    Country(code: 'VN', name: 'Vietnam', currencyCode: 'VND', symbol: '₫', flag: '🇻🇳'),
    Country(code: 'TH', name: 'Thailand', currencyCode: 'THB', symbol: '฿', flag: '🇹🇭'),
    Country(code: 'RU', name: 'Russia', currencyCode: 'RUB', symbol: '₽', flag: '🇷🇺'),
    Country(code: 'AR', name: 'Argentina', currencyCode: 'ARS', symbol: 'AR\$', flag: '🇦🇷'),
    Country(code: 'CL', name: 'Chile', currencyCode: 'CLP', symbol: 'CL\$', flag: '🇨🇱'),
    Country(code: 'CO', name: 'Colombia', currencyCode: 'COP', symbol: 'CO\$', flag: '🇨🇴'),
  ];

  static final ValueNotifier<Country> currentCountry = ValueNotifier<Country>(defaultCountry);
  static final ValueNotifier<bool> hasSelectedCountry = ValueNotifier<bool>(false);

  static Future<void> init() async {
    try {
      final savedCode = await DatabaseHelper.instance.getSetting('selected_country');
      if (savedCode != null) {
        final found = supportedCountries.firstWhere(
          (c) => c.code == savedCode,
          orElse: () => defaultCountry,
        );
        currentCountry.value = found;
      }
      final hasSelected = await DatabaseHelper.instance.getSetting('has_selected_country');
      hasSelectedCountry.value = hasSelected == 'true';
    } catch (_) {}
  }

  static String get symbol => currentCountry.value.symbol;

  static String format(double amount, {int fractionDigits = 2}) {
    return '$symbol${amount.toStringAsFixed(fractionDigits)}';
  }

  static String formatNegative(double amount, {int fractionDigits = 2}) {
    return '-$symbol${amount.toStringAsFixed(fractionDigits)}';
  }

  static Future<void> setCountry(Country country) async {
    currentCountry.value = country;
    hasSelectedCountry.value = true;
    await DatabaseHelper.instance.saveSetting('selected_country', country.code);
    await DatabaseHelper.instance.saveSetting('has_selected_country', 'true');
  }

  static Future<void> showCountrySelectionDialog(BuildContext context, {bool isFirstLaunch = false}) async {
    await showDialog(
      context: context,
      barrierDismissible: !isFirstLaunch,
      builder: (context) => CountrySelectionDialog(isFirstLaunch: isFirstLaunch),
    );
  }
}

class CountrySelectionDialog extends StatefulWidget {
  final bool isFirstLaunch;

  const CountrySelectionDialog({super.key, required this.isFirstLaunch});

  @override
  State<CountrySelectionDialog> createState() => _CountrySelectionDialogState();
}

class _CountrySelectionDialogState extends State<CountrySelectionDialog> {
  late List<Country> _filteredCountries;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _filteredCountries = CurrencyService.supportedCountries;
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final query = _searchController.text.trim().toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredCountries = CurrencyService.supportedCountries;
      } else {
        _filteredCountries = CurrencyService.supportedCountries.where((c) {
          return c.name.toLowerCase().contains(query) ||
              c.currencyCode.toLowerCase().contains(query) ||
              c.code.toLowerCase().contains(query) ||
              c.symbol.contains(query);
        }).toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = ThemeService.isDarkOrCyber;
    final borderColor = ThemeService.getBorderColor();
    final currentCountryCode = CurrencyService.currentCountry.value.code;

    final dialogBg = isDark ? const Color(0xFF1E1E2C) : const Color(0xFFFFF8E7);
    final textColor = isDark ? Colors.white : Colors.black;

    return Dialog(
      backgroundColor: dialogBg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: borderColor, width: 2.2),
      ),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 420, maxHeight: 560),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                const Icon(Icons.public_rounded, size: 28, color: Color(0xFF0C513F)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    widget.isFirstLaunch ? 'Select Your Country' : 'Change Country & Currency',
                    style: ThemeService.getAppTextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                ),
                if (!widget.isFirstLaunch)
                  IconButton(
                    icon: Icon(Icons.close, color: textColor),
                    onPressed: () => Navigator.pop(context),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              widget.isFirstLaunch
                  ? 'Your transactions will be formatted according to your country\'s currency.'
                  : 'Choose a country to update transaction currency formatting across DigiLedger.',
              style: ThemeService.getAppTextStyle(
                fontSize: 14,
                color: isDark ? Colors.white70 : Colors.black87,
              ),
            ),
            const SizedBox(height: 14),

            // Search Box
            TextField(
              controller: _searchController,
              style: ThemeService.getAppTextStyle(fontSize: 16, color: textColor),
              decoration: InputDecoration(
                hintText: 'Search country or currency (e.g. India, USD, £)',
                hintStyle: ThemeService.getAppTextStyle(
                  fontSize: 14,
                  color: isDark ? Colors.white54 : Colors.black54,
                ),
                prefixIcon: Icon(Icons.search, color: isDark ? Colors.white70 : Colors.black54),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: borderColor, width: 1.5),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: borderColor.withValues(alpha: 0.6), width: 1.5),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: borderColor, width: 2.0),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Country List
            Expanded(
              child: _filteredCountries.isEmpty
                  ? Center(
                child: Text(
                  'No matching country found',
                  style: ThemeService.getAppTextStyle(
                    fontSize: 16,
                    color: isDark ? Colors.white54 : Colors.black54,
                  ),
                ),
              )
                  : ListView.separated(
                itemCount: _filteredCountries.length,
                separatorBuilder: (_, __) => const SizedBox(height: 6),
                itemBuilder: (context, index) {
                  final country = _filteredCountries[index];
                  final isSelected = country.code == currentCountryCode;

                  return InkWell(
                    onTap: () async {
                      await CurrencyService.setCountry(country);
                      if (context.mounted) {
                        Navigator.pop(context);
                      }
                    },
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? (isDark ? const Color(0xFF2C3E50) : const Color(0xFFB5E48C))
                            : (isDark ? const Color(0xFF282836) : Colors.white),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isSelected ? borderColor : Colors.grey.withValues(alpha: 0.3),
                          width: isSelected ? 2.0 : 1.0,
                        ),
                      ),
                      child: Row(
                        children: [
                          Text(
                            country.flag,
                            style: const TextStyle(fontSize: 24),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  country.name,
                                  style: ThemeService.getAppTextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: textColor,
                                  ),
                                ),
                                Text(
                                  '${country.currencyCode} (${country.symbol})',
                                  style: ThemeService.getAppTextStyle(
                                    fontSize: 13,
                                    color: isDark ? Colors.white70 : Colors.black54,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (isSelected)
                            Icon(
                              Icons.check_circle_rounded,
                              color: isDark ? const Color(0xFF00F0FF) : const Color(0xFF0C513F),
                              size: 22,
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),

            if (widget.isFirstLaunch) ...[
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () async {
                    // Default to US dollar if user clicks continue without explicitly selecting
                    await CurrencyService.setCountry(CurrencyService.defaultCountry);
                    if (context.mounted) {
                      Navigator.pop(context);
                    }
                  },
                  child: Text(
                    'Continue with United States (USD \$)',
                    style: ThemeService.getAppTextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: isDark ? const Color(0xFF00F0FF) : const Color(0xFF0C513F),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
