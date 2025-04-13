import 'package:flutter/material.dart';
import 'package:ewallet/core/utils/custome_colors.dart';

extension CustomTheme on BuildContext {
  CustomColors get customColors => Theme.of(this).extension<CustomColors>()!;
}
