import 'package:flutter/material.dart';
import 'package:peppercheck_flutter/app/theme/app_colors.dart';

class BaseTextField extends StatelessWidget {
  final String value;
  final ValueChanged<String> onValueChange;
  final String label;
  final int minLines;
  final int? maxLines;
  final bool readOnly;
  final bool enabled;
  final VoidCallback? onClick;
  final Widget? trailingIcon;
  final TextInputType? keyboardType;

  const BaseTextField({
    super.key,
    required this.value,
    required this.onValueChange,
    required this.label,
    this.minLines = 1,
    this.maxLines,
    this.readOnly = false,
    this.enabled = true,
    this.onClick,
    this.trailingIcon,
    this.keyboardType,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Native implementation uses AccentBlueLight for indicators and TextBlack for labels/text
    final focusedIndicatorColor = AppColors.accentBlueLight;
    final unfocusedIndicatorColor = AppColors.accentBlueLight.withValues(
      alpha: 0.6,
    );
    final labelColor = AppColors.textBlack.withValues(alpha: 0.6);
    final textColor = AppColors.textBlack;

    return InkWell(
      onTap: onClick,
      child: IgnorePointer(
        ignoring:
            onClick !=
            null, // If onClick is provided, ignore pointer events on TextField so InkWell handles them
        child: TextFormField(
          initialValue: value,
          onChanged: onValueChange,
          readOnly: readOnly,
          enabled: enabled,
          minLines: minLines,
          maxLines: maxLines,
          keyboardType: keyboardType,
          style: theme.textTheme.bodyLarge?.copyWith(color: textColor),
          decoration: InputDecoration(
            labelText: label,
            labelStyle: theme.textTheme.bodyMedium?.copyWith(color: labelColor),
            floatingLabelStyle: theme.textTheme.bodyMedium?.copyWith(
              color: labelColor,
            ),
            suffixIcon: trailingIcon,
            filled: true,
            fillColor: Colors.transparent, // Transparent container
            // Border styles
            enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: unfocusedIndicatorColor),
            ),
            focusedBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: focusedIndicatorColor),
            ),
            disabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: unfocusedIndicatorColor),
            ),

            // Remove default content padding if needed to match native look closely
            // contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 0),
          ),
          cursorColor: focusedIndicatorColor,
        ),
      ),
    );
  }
}
