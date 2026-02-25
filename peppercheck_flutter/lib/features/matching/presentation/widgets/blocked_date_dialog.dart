import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:peppercheck_flutter/app/theme/app_colors.dart';
import 'package:peppercheck_flutter/features/matching/domain/referee_blocked_date.dart';
import 'package:peppercheck_flutter/gen/slang/strings.g.dart';

class BlockedDateDialog extends StatefulWidget {
  final RefereeBlockedDate? blockedDate;
  final Function(DateTime startDate, DateTime endDate, String? reason) onSave;

  const BlockedDateDialog({super.key, this.blockedDate, required this.onSave});

  @override
  State<BlockedDateDialog> createState() => _BlockedDateDialogState();
}

class _BlockedDateDialogState extends State<BlockedDateDialog> {
  DateTime? _startDate;
  DateTime? _endDate;
  late final TextEditingController _reasonController;

  @override
  void initState() {
    super.initState();
    if (widget.blockedDate != null) {
      _startDate = widget.blockedDate!.startDate;
      _endDate = widget.blockedDate!.endDate;
      _reasonController = TextEditingController(
        text: widget.blockedDate!.reason,
      );
    } else {
      _reasonController = TextEditingController();
    }
  }

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _selectDateRange() async {
    final now = DateTime.now();
    final initialRange = (_startDate != null && _endDate != null)
        ? DateTimeRange(start: _startDate!, end: _endDate!)
        : DateTimeRange(start: now, end: now.add(const Duration(days: 1)));

    final picked = await showDateRangePicker(
      context: context,
      initialDateRange: initialRange,
      firstDate: DateTime.now(),
      lastDate: DateTime(2100),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
              primary: AppColors.accentBlue,
              onPrimary: Colors.white,
              surface: AppColors.backgroundWhite,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
      });
    }
  }

  String _formatDate(DateTime date) {
    return '${date.year}/${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}';
  }

  bool get _isValid => _startDate != null && _endDate != null;

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.blockedDate != null;

    return AlertDialog(
      backgroundColor: AppColors.backgroundWhite,
      surfaceTintColor: Colors.transparent,
      title: Text(
        isEdit
            ? t.matching.referee_blocked_dates.edit_title
            : t.matching.referee_blocked_dates.add_title,
        style: const TextStyle(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.bold,
        ),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              t.matching.referee_blocked_dates.select_date_range,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 4),
            InkWell(
              onTap: _selectDateRange,
              borderRadius: BorderRadius.circular(8),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.border),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.date_range,
                      size: 16,
                      color: AppColors.textSecondary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        (_startDate != null && _endDate != null)
                            ? '${_formatDate(_startDate!)} - ${_formatDate(_endDate!)}'
                            : t.matching.referee_blocked_dates.select_date_range,
                        style: TextStyle(
                          color: (_startDate != null)
                              ? AppColors.textPrimary
                              : AppColors.textSecondary,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              t.matching.referee_blocked_dates.reason,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 4),
            TextField(
              controller: _reasonController,
              maxLines: 2,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 14,
              ),
              decoration: InputDecoration(
                hintText: t.matching.referee_blocked_dates.reason_hint,
                hintStyle: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 14,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: AppColors.accentBlue),
                ),
                filled: true,
                fillColor: AppColors.backgroundWhite,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => context.pop(),
          style: TextButton.styleFrom(foregroundColor: AppColors.textSecondary),
          child: Text(t.common.cancel),
        ),
        FilledButton(
          onPressed: _isValid
              ? () {
                  final reason = _reasonController.text.trim().isEmpty
                      ? null
                      : _reasonController.text.trim();
                  widget.onSave(_startDate!, _endDate!, reason);
                  context.pop();
                }
              : null,
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.accentBlue,
            foregroundColor: Colors.white,
          ),
          child: Text(t.common.save),
        ),
      ],
    );
  }
}
