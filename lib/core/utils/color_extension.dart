import 'package:flutter/material.dart';
import 'package:wallet_app/core/utils/custome_colors.dart';

extension CustomTheme on BuildContext {
  CustomColors get customColors => Theme.of(this).extension<CustomColors>()!;
}
