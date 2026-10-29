import 'package:flutter/material.dart';

class TestFile extends StatelessWidget {
  const TestFile({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFD0F4DE), // Your Mint Green
        borderRadius: BorderRadius.circular(16), // Softly rounded corners
        border: Border.all(
          color: Colors.black,
          width: 2.0, // Bold sketch-like outline
        ),
        boxShadow: const [
          BoxShadow(
            color: Colors.blueAccent,
            offset: Offset(3, 3), // Creates a playful "offset shadow" comic effect
            blurRadius: 0, // Hard shadow instead of blurred gradient
          ),
        ],
      ),
      child: const Text('Hello Hand-Drawn World!'),
    );
  }
}
