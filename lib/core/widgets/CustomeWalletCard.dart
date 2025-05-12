import 'package:ewallet/core/widgets/CustomeText.dart';
import 'package:flutter/material.dart';

class CustomeWalletCard extends StatelessWidget {
  final String walletName;
  final String walletBalance;
  final String leadingImage;
  final Color? backgroundColor;
  final Color? textColor;
  final VoidCallback onTap;

  const CustomeWalletCard({
    super.key,
    required this.walletName,
    required this.walletBalance,
    required this.leadingImage,
    required this.backgroundColor,
    required this.textColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Card(
        color: backgroundColor,
        child: Container(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              Expanded(
                flex: 1,
                child: Image.asset(
                  '${leadingImage}',
                  width: 100,
                  height: 100,
                ),
              ),
              SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CommonText(
                      text: walletName,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: textColor,
                    ),
                    // const SizedBox(height: 10),
                    walletBalance == ''
                        ? Container()
                        : CommonText(
                            text: walletBalance,
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: textColor,
                          ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
