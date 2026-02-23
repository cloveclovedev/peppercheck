# Naming Conventions

Project-wide naming conventions. New conventions should be added here as sections.

## Notification Template Keys

### Pattern

`notification_{event}_{recipient}`

- `{recipient}` is always `_tasker` or `_referee`
- Every key must have a recipient suffix, even when the recipient seems obvious from the event name
- The `notification_` prefix is retained as a namespace (required for flat key systems like Android `strings.xml` / iOS `Localizable.strings`)

### How keys flow through the system

1. **SQL**: `notify_event(user_id, 'notification_{event}_{recipient}', ...)` — base key only, no `_title`/`_body` suffix
2. **`notify_event()` function**: Auto-appends `_title` and `_body` to construct `title_loc_key` / `body_loc_key`
3. **Edge Function** (`send-notification`): Forwards loc_keys to FCM as-is
4. **Background/terminated notifications**: Android `strings.xml` / iOS `Localizable.strings` resolve the loc_key natively
5. **Foreground notifications**: Flutter `notification_text_resolver.dart` resolves the loc_key to slang `t.notification.*` accessors
6. **Flutter i18n**: `ja.i18n.json` `notification` section stores the localized text (keys without `notification_` prefix, e.g. `evidence_timeout_tasker_title`)

### Adding a new notification

1. Choose base key following the pattern: `notification_{event}_{recipient}`
2. Add to ALL 5 layers:
   - SQL `notify_event()` call
   - Android `strings.xml` (en + ja) with `_title` and `_body` suffixed keys
   - iOS `Localizable.strings` (en + ja) with `_title` and `_body` suffixed keys
   - Flutter `ja.i18n.json` `notification` section (without `notification_` prefix)
   - Flutter `notification_text_resolver.dart` switch cases
3. Regenerate slang: `cd peppercheck_flutter && dart run build_runner build`
