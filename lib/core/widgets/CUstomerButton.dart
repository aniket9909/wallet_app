import 'package:flutter/material.dart';

class CustomerButton extends StatelessWidget {
  final String label;
  final Color? backgourndColor;
  final Color? textColor;
  final bool? isActive;
  final VoidCallback onPressed;

  const CustomerButton({
    Key? key,
    required this.label,
    required this.onPressed,
    this.backgourndColor,
    this.textColor,
    this.isActive,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isActive ?? true ? onPressed : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: (isActive ?? true)
              ? backgourndColor ?? Colors.blue
              : (backgourndColor ?? Colors.blue).withOpacity(0.5),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 16,
            color: (isActive ?? true)
                ? textColor ?? Colors.white
                : (textColor ?? Colors.white).withOpacity(0.5),
          ),
        ),
      ),
    );
  }
}
