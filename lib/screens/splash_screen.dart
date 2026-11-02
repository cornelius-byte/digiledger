import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'main_navigation.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    // Navigate to MainNavigation after 2.5 seconds
    Future.delayed(const Duration(milliseconds: 2500), () {
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) => const MainNavigation(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
          },
          transitionDuration: const Duration(milliseconds: 500),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFBCE6FF), // Light blue splash background matching mockup
      body: SafeArea(
        child: Stack(
          children: [
            Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    // Main Dark Green Notebook Card
                    Container(
                      width: double.infinity,
                      constraints: const BoxConstraints(maxWidth: 360),
                      padding: const EdgeInsets.fromLTRB(28, 32, 28, 28),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0C513F), // Dark green notebook cover
                        borderRadius: BorderRadius.circular(32),
                        border: Border.all(color: Colors.black, width: 2.5),
                        boxShadow: const [
                          BoxShadow(
                            color: Colors.black,
                            offset: Offset(6, 6),
                            blurRadius: 0,
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Inner White Page
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
                            decoration: BoxDecoration(
                              color: Colors.white, // Inner white page
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(color: Colors.black, width: 2.0),
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // Exact App Logo Icon matching second image (ledger book with dollar coin)
                                Container(
                                  width: 84,
                                  height: 72,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF0C513F),
                                    borderRadius: BorderRadius.circular(18),
                                    border: Border.all(color: Colors.black, width: 1.5),
                                  ),
                                  child: Stack(
                                    children: [
                                      // 3 horizontal menu lines on the left
                                      Positioned(
                                        left: 12,
                                        top: 0,
                                        bottom: 0,
                                        child: Column(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Container(width: 16, height: 3, color: const Color(0xFFB5E48C)),
                                            const SizedBox(height: 5),
                                            Container(width: 16, height: 3, color: const Color(0xFFB5E48C)),
                                            const SizedBox(height: 5),
                                            Container(width: 16, height: 3, color: const Color(0xFFB5E48C)),
                                          ],
                                        ),
                                      ),
                                      // Large circular coin / ledger page section on the right with dollar sign
                                      Positioned(
                                        right: 6,
                                        top: 10,
                                        bottom: 10,
                                        child: Container(
                                          width: 44,
                                          height: 44,
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF8CE072), // Bright green coin fill
                                            shape: BoxShape.circle,
                                            border: Border.all(color: const Color(0xFF0C513F), width: 1.5),
                                          ),
                                          child: Center(
                                            child: Text(
                                              '\$',
                                              style: GoogleFonts.patrickHand(
                                                color: const Color(0xFF0C513F),
                                                fontSize: 30,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 18),

                                // App Title
                                Text(
                                  'DigiLedger',
                                  style: GoogleFonts.patrickHand(
                                    fontSize: 36,
                                    fontWeight: FontWeight.bold,
                                    color: const Color(0xFF1E1E1E),
                                  ),
                                ),
                                const SizedBox(height: 4),

                                // Subtitle
                                Text(
                                  'YOUR MONEY, MADE CLEAR',
                                  style: GoogleFonts.patrickHand(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: const Color(0xFF0C513F),
                                    letterSpacing: 1.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 18),

                          // Feature Pill 1: Fully offline (inside notebook card)
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                            decoration: BoxDecoration(
                              color: const Color(0xFFB5E48C),
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(color: Colors.black, width: 2.0),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.wifi_off, size: 18, color: Colors.black87),
                                const SizedBox(width: 8),
                                Text(
                                  'Fully offline • No account needed',
                                  style: GoogleFonts.patrickHand(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black87,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 10),

                          // Feature Pill 2: Private (inside notebook card)
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFE5B4),
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(color: Colors.black, width: 2.0),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.shield_outlined, size: 18, color: Colors.black87),
                                const SizedBox(width: 8),
                                Text(
                                  'Private • Stored only on your device',
                                  style: GoogleFonts.patrickHand(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black87,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    // 3 Binder Rings / Tabs on the left edge
                    Positioned(
                      left: -14,
                      top: 75,
                      child: Column(
                        children: [
                          _buildBinderRing(const Color(0xFFFFE5B4)), // Yellowish ring
                          const SizedBox(height: 70),
                          _buildBinderRing(const Color(0xFFB5E48C)), // Light green ring
                          const SizedBox(height: 70),
                          _buildBinderRing(const Color(0xFFBCE6FF)), // Light blue ring
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Loading bar at bottom
            Positioned(
              left: 0,
              right: 0,
              bottom: 40,
              child: Column(
                children: [
                  SizedBox(
                    width: 180,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: const LinearProgressIndicator(
                        backgroundColor: Colors.white,
                        color: Color(0xFF0C513F),
                        minHeight: 6,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Loading...',
                    style: GoogleFonts.patrickHand(
                      fontSize: 16,
                      color: Colors.black54,
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

  Widget _buildBinderRing(Color color) {
    return Container(
      width: 22,
      height: 26,
      decoration: BoxDecoration(
        color: color,
        borderRadius: const BorderRadius.horizontal(left: Radius.circular(12)),
        border: Border.all(color: Colors.black, width: 2.0),
        boxShadow: const [
          BoxShadow(
            color: Colors.black,
            offset: Offset(-2, 2),
            blurRadius: 0,
          ),
        ],
      ),
    );
  }
}
