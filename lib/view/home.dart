import 'package:ewallet/core/utils/color_extension.dart';
import 'package:ewallet/core/utils/view_imports.dart';
import 'package:ewallet/core/widgets/CustomeText.dart';
import 'package:ewallet/view/wallets.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class Home extends StatefulWidget {
  const Home({super.key});

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  int _selectedIndex = 0;
  final PageController _pageController = PageController();

  final List<Widget> _pages = [
    Dashboard(),
    Center(child: Text('Debt Tracker')),
    AllWallets(),
    Center(child: Text('Smart Save')),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      bottomNavigationBar: BottomAppBar(
        height: 100,
        shape: const CircularNotchedRectangle(),
        notchMargin: 8.0,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildNavItem(
              index: 0,
              icon: FontAwesomeIcons.house,
              label: "Total Amount",
            ),
            _buildNavItem(
              index: 1,
              icon: FontAwesomeIcons.chartArea,
              label: "DebtTracker",
            ),
            _buildNavItem(
              index: 2,
              icon: FontAwesomeIcons.wallet,
              label: "Wallets",
            ),
            _buildNavItem(
              index: 3,
              icon: FontAwesomeIcons.piggyBank,
              label: "SmartSave",
            ),
          ],
        ),
      ),
      body: PageView(
        controller: _pageController,
        onPageChanged: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        children: _pages,
      ),
    );
  }

  Widget _buildNavItem({
    required int index,
    required IconData icon,
    required String label,
  }) {
    final isSelected = _selectedIndex == index;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: FaIcon(
            icon,
            color: isSelected ? context.customColors.primaryColor : Colors.grey,
          ),
          onPressed: () {
            _pageController.animateToPage(
              index,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
            );
            setState(() {
              _selectedIndex = index;
            });
          },
        ),
        CommonText(
          text: label,
          color: isSelected ? context.customColors.primaryColor : Colors.grey,
        ),
      ],
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }
}
