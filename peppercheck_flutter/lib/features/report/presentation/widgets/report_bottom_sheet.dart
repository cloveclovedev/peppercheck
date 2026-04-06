import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:peppercheck_flutter/app/theme/app_sizes.dart';
import 'package:peppercheck_flutter/features/report/presentation/report_controller.dart';
import 'package:peppercheck_flutter/gen/slang/strings.g.dart';

/// Shows the report bottom sheet and returns `true` if the report was submitted.
Future<bool?> showReportBottomSheet(
  BuildContext context, {
  required String taskId,
  required bool isTasker,
  required String? evidenceId,
  required String? judgementId,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _ReportBottomSheet(
      taskId: taskId,
      isTasker: isTasker,
      evidenceId: evidenceId,
      judgementId: judgementId,
    ),
  );
}

class _ReportBottomSheet extends ConsumerStatefulWidget {
  final String taskId;
  final bool isTasker;
  final String? evidenceId;
  final String? judgementId;

  const _ReportBottomSheet({
    required this.taskId,
    required this.isTasker,
    required this.evidenceId,
    required this.judgementId,
  });

  @override
  ConsumerState<_ReportBottomSheet> createState() => _ReportBottomSheetState();
}

class _ReportBottomSheetState extends ConsumerState<_ReportBottomSheet> {
  String? _selectedContentType;
  String? _selectedReason;
  final _detailController = TextEditingController();
  bool _isSubmitting = false;

  List<_RadioOption> get _contentTypeOptions {
    if (widget.isTasker) {
      return [_RadioOption('judgement', t.report.contentType.judgement)];
    }
    return [
      _RadioOption('task_description', t.report.contentType.taskDescription),
      _RadioOption('evidence', t.report.contentType.evidence),
    ];
  }

  String _reasonLabel(String value) {
    switch (value) {
      case 'inappropriate_content':
        return t.report.reason.inappropriateContent;
      case 'harassment':
        return t.report.reason.harassment;
      case 'spam':
        return t.report.reason.spam;
      case 'other':
        return t.report.reason.other;
      default:
        return value;
    }
  }

  String? _resolveContentId() {
    switch (_selectedContentType) {
      case 'evidence':
        return widget.evidenceId;
      case 'judgement':
        return widget.judgementId;
      default:
        return null;
    }
  }

  Future<void> _submit() async {
    if (_selectedContentType == null || _selectedReason == null) return;

    setState(() => _isSubmitting = true);

    final success = await ref
        .read(reportControllerProvider.notifier)
        .submitReport(
          taskId: widget.taskId,
          reporterRole: widget.isTasker ? 'tasker' : 'referee',
          contentType: _selectedContentType!,
          contentId: _resolveContentId(),
          reason: _selectedReason!,
          detail:
              _selectedReason == 'other' &&
                  _detailController.text.trim().isNotEmpty
              ? _detailController.text.trim()
              : null,
        );

    if (!mounted) return;

    if (success) {
      Navigator.of(context).pop(true);
    } else {
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t.report.errorMessage(message: ''))),
      );
    }
  }

  @override
  void dispose() {
    _detailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final canSubmit =
        _selectedContentType != null &&
        _selectedReason != null &&
        !_isSubmitting;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(AppSizes.screenHorizontalPadding),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: AppSizes.spacingSmall),
              Center(
                child: Container(
                  width: 32,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[400],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: AppSizes.spacingMedium),
              Text(
                t.report.sheetTitle,
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: AppSizes.spacingMedium),
              // Content type selection
              Text(
                t.report.contentTypeTitle,
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: AppSizes.spacingSmall),
              ..._contentTypeOptions.map(
                (option) => RadioListTile<String>(
                  title: Text(option.label),
                  value: option.value,
                  groupValue: _selectedContentType,
                  onChanged: (v) => setState(() => _selectedContentType = v),
                  dense: true,
                ),
              ),
              const SizedBox(height: AppSizes.spacingMedium),
              // Reason selection
              Text(
                t.report.reasonTitle,
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: AppSizes.spacingSmall),
              ...['inappropriate_content', 'harassment', 'spam', 'other'].map(
                (reason) => RadioListTile<String>(
                  title: Text(_reasonLabel(reason)),
                  value: reason,
                  groupValue: _selectedReason,
                  onChanged: (v) => setState(() => _selectedReason = v),
                  dense: true,
                ),
              ),
              // Detail field for "other"
              if (_selectedReason == 'other') ...[
                const SizedBox(height: AppSizes.spacingSmall),
                TextField(
                  controller: _detailController,
                  decoration: InputDecoration(
                    hintText: t.report.detailHint,
                    border: const OutlineInputBorder(),
                  ),
                  maxLines: 3,
                  maxLength: 500,
                ),
              ],
              const SizedBox(height: AppSizes.spacingMedium),
              // Submit button
              FilledButton(
                onPressed: canSubmit ? _submit : null,
                child: _isSubmitting
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(t.report.submit),
              ),
              const SizedBox(height: AppSizes.spacingMedium),
            ],
          ),
        ),
      ),
    );
  }
}

class _RadioOption {
  final String value;
  final String label;
  const _RadioOption(this.value, this.label);
}
