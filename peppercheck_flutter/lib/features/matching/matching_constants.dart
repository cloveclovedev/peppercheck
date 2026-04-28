/// Hours before a task's `due_date` after which a referee can no longer
/// withdraw from their accepted match.
///
/// Mirrors the server-side `matching_time_config.cancel_deadline_hours`
/// singleton; if that value changes, update this constant too. The server
/// remains the authoritative gate — this client value is for UX only.
const int kRefereeCancelDeadlineHours = 12;
