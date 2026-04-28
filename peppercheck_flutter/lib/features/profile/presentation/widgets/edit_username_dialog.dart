import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:peppercheck_flutter/common_widgets/base_dialog.dart';
import 'package:peppercheck_flutter/features/profile/data/profile_errors.dart';
import 'package:peppercheck_flutter/features/profile/presentation/profile_edit_controller.dart';
import 'package:peppercheck_flutter/gen/slang/strings.g.dart';

class EditUsernameDialog extends ConsumerStatefulWidget {
  final String currentUsername;
  const EditUsernameDialog({super.key, required this.currentUsername});

  @override
  ConsumerState<EditUsernameDialog> createState() => _EditUsernameDialogState();
}

class _EditUsernameDialogState extends ConsumerState<EditUsernameDialog> {
  late final TextEditingController _controller;
  String? _localErrorKey;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.currentUsername);
    _localErrorKey = validateUsername(widget.currentUsername);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    setState(() {
      _localErrorKey = validateUsername(value);
    });
  }

  String? _resolveErrorMessage(Object? asyncError) {
    if (asyncError is UsernameAlreadyTakenException) {
      return t.profile.edit.errors.taken;
    }
    if (asyncError != null && asyncError is String) {
      return _messageForKey(asyncError);
    }
    if (asyncError != null) {
      return t.profile.edit.errors.generic;
    }
    if (_localErrorKey != null && _controller.text.isNotEmpty) {
      return _messageForKey(_localErrorKey!);
    }
    return null;
  }

  String _messageForKey(String key) {
    switch (key) {
      case 'tooShort':
        return t.profile.edit.errors.tooShort;
      case 'tooLong':
        return t.profile.edit.errors.tooLong;
      case 'invalidChars':
        return t.profile.edit.errors.invalidChars;
      default:
        return t.profile.edit.errors.generic;
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(profileEditControllerProvider);
    final isLoading = state.isLoading;
    final errorMessage = _resolveErrorMessage(state.error);
    final canSubmit = !isLoading && _localErrorKey == null;

    return BaseDialog(
      title: t.profile.edit.usernameTitle,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _controller,
            enabled: !isLoading,
            maxLength: 20,
            onChanged: _onChanged,
            decoration: InputDecoration(
              hintText: t.profile.edit.usernameHint,
              errorText: errorMessage,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: isLoading ? null : () => Navigator.of(context).pop(),
          child: Text(t.profile.edit.cancel),
        ),
        TextButton(
          onPressed: canSubmit
              ? () {
                  ref
                      .read(profileEditControllerProvider.notifier)
                      .updateUsername(
                        username: _controller.text,
                        onSuccess: () => Navigator.of(context).pop(),
                      );
                }
              : null,
          child: isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(t.profile.edit.save),
        ),
      ],
    );
  }
}
