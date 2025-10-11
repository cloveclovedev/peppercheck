package dev.cloveclove.peppercheck.ui.common

import java.time.Instant
import java.time.ZoneId
import java.time.format.DateTimeFormatter

/**
 * Converts a UTC datetime string (PostgreSQL `timestamptz`)
 * into a string formatted in the device's current time zone.
 */
fun formatUtcToLocal(
    utcIsoString: String?,
    pattern: String = "yyyy/MM/dd HH:mm"
): String {
    if (utcIsoString.isNullOrBlank()) return "Unknown"

    return runCatching {
        val instant = Instant.parse(utcIsoString)
        val localDateTime = instant.atZone(ZoneId.systemDefault())
        localDateTime.format(DateTimeFormatter.ofPattern(pattern))
    }.getOrElse { "Unknown" }
}
