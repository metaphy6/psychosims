#ifndef PSYCHOSIMS_LOG_H
#define PSYCHOSIMS_LOG_H

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>

#ifdef __cplusplus
extern "C" {
#endif

/* Cross-stack log-level identifiers matching docs/code/LOGGING.md. */
typedef enum PsyLogLevel {
    PSY_LOG_DEBUG,
    PSY_LOG_INFO,
    PSY_LOG_SUCCESS,
    PSY_LOG_WARN,
    PSY_LOG_ERROR,
    PSY_LOG_FATAL
} PsyLogLevel;

/* Render one canonical log line to stderr.
 *   level   - one of PsyLogLevel
 *   scope   - "native:<module>"
 *   event   - lowercase snake_case event name
 *   corr_id - correlation/session id or "none"
 *   kv      - optional "key=value" pairs, comma separated, may be NULL
 *   message - optional human summary, may be NULL
 *
 * This function never allocates and is safe to call from inference threads.
 */
static inline void psy_log(PsyLogLevel level,
                           const char* scope,
                           const char* event,
                           const char* corr_id,
                           const char* kv,
                           const char* message) {
    const char* emoji = "ℹ️";
    const char* level_name = "info";
    switch (level) {
        case PSY_LOG_DEBUG:   emoji = "🔍"; level_name = "debug";   break;
        case PSY_LOG_INFO:    emoji = "ℹ️"; level_name = "info";    break;
        case PSY_LOG_SUCCESS: emoji = "✅"; level_name = "success"; break;
        case PSY_LOG_WARN:    emoji = "⚠️"; level_name = "warn";    break;
        case PSY_LOG_ERROR:   emoji = "❌"; level_name = "error";   break;
        case PSY_LOG_FATAL:   emoji = "🛑"; level_name = "fatal";   break;
    }

    char ts[32];
    const time_t now = time(NULL);
    struct tm utc;
#ifdef _WIN32
    gmtime_s(&utc, &now);
#else
    gmtime_r(&now, &utc);
#endif
    strftime(ts, sizeof(ts), "%Y-%m-%dT%H:%M:%SZ", &utc);

    fprintf(stderr, "%s %7s [%s] [%s] %-24s corr=%s",
            emoji, level_name, ts, scope ? scope : "native",
            event ? event : "", corr_id ? corr_id : "none");

    if (kv && kv[0]) {
        fprintf(stderr, " | %s", kv);
    }
    if (message && message[0]) {
        fprintf(stderr, " | %s", message);
    }
    fprintf(stderr, "\n");
}

#ifdef __cplusplus
}
#endif

#endif /* PSYCHOSIMS_LOG_H */
