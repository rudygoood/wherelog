import 'package:flutter/material.dart';
import 'home_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});
  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _controller = PageController();
  int _page = 0;

  final pages = [
    {'title': 'Track Your Stuff', 'desc': 'Never lose things in Attic, Basement, Storage again', 'icon': Icons.inventory_2},
    {'title': 'Remember Places', 'desc': 'Save parking spots, hidden spots, and points of interest', 'icon': Icons.place},
    {'title': 'Inventory at Home', 'desc': 'Know what you have and where', 'icon': Icons.home},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: PageView.builder(
        controller: _controller,
        onPageChanged: (i) => setState(() => _page = i),
        itemCount: pages.length,
        itemBuilder: (context, i) {
          return Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(pages[i]['icon'] as IconData, size: 100, color: Colors.blue),
                const SizedBox(height: 32),
                Text(pages[i]['title'] as String, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                Text(pages[i]['desc'] as String, textAlign: TextAlign.center, style: const TextStyle(fontSize: 16, color: Colors.grey)),
              ],
            ),
          );
        },
      ),
      bottomSheet: Container(
        padding: const EdgeInsets.all(24),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: List.generate(pages.length, (i) => Container(
                margin: const EdgeInsets.all(4),
                width: 10, height: 10,
                decoration: BoxDecoration(color: _page == i? Colors.blue : Colors.grey[300], shape: BoxShape.circle),
              )),
            ),
            ElevatedButton(
              onPressed: () {
                if (_page == pages.length - 1) {
                  Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const HomeScreen()));
                } else {
                  _controller.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
                }
              },
              child: Text(_page == pages.length - 1? 'Get Started' : 'Next'),
            )
          ],
        ),
      ),
    );
  }
}