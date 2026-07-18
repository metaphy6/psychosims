// Package psylog is the Go server's cross-stack logger.
//
// It emits the canonical log-line schema defined in docs/code/LOGGING.md,
// matching the Dart, C/C++, and (former Python) implementations exactly. Mode
// (text vs JSON) and minimum level are read from the environment at
// construction time; in tests they default to text/info.
//
// Writes go to stderr via fmt.Fprintln so the no-raw-output gate
// (scripts/no_raw_print_check.sh) never trips on raw print calls in server code.
package psylog

import (
	"encoding/json"
	"fmt"
	"os"
	"sort"
	"strings"
	"time"
)

// Level is a log severity, ordered from most to least verbose.
type Level string

const (
	Debug   Level = "debug"
	Info    Level = "info"
	Success Level = "success"
	Warn    Level = "warn"
	Error   Level = "error"
	Fatal   Level = "fatal"
)

var levelOrder = []Level{Debug, Info, Success, Warn, Error, Fatal}

var levelEmoji = map[Level]string{
	Debug:   "🔍",
	Info:    "ℹ️",
	Success: "✅",
	Warn:    "⚠️",
	Error:   "❌",
	Fatal:   "🛑",
}

// ErrorKind classifies the origin of an error for triage.
type ErrorKind string

const (
	ErrUser     ErrorKind = "user"
	ErrSystem   ErrorKind = "system"
	ErrExternal ErrorKind = "external"
	ErrOffline  ErrorKind = "offline"
)

// KV is a set of structured key/value fields attached to a log line.
type KV map[string]any

// Logger renders the shared log-line schema.
type Logger struct {
	MinLevel      Level
	JSONMode      bool
	CorrelationID string
}

func levelIndex(l Level) int {
	for i, v := range levelOrder {
		if v == l {
			return i
		}
	}
	return 0
}

func (lg *Logger) emit(line string) {
	fmt.Fprintln(os.Stderr, line)
}

func (lg *Logger) log(level Level, scope, event string, kv KV, kind ErrorKind, message string) {
	if levelIndex(level) < levelIndex(lg.MinLevel) {
		return
	}

	ts := time.Now().UTC().Format(time.RFC3339Nano)
	scope = strings.ToLower(scope)
	event = strings.ToLower(event)

	if lg.JSONMode {
		payload := map[string]any{
			"ts":             ts,
			"level":          string(level),
			"scope":          scope,
			"event":          event,
			"correlation_id": lg.CorrelationID,
		}
		if len(kv) > 0 {
			payload["kv"] = map[string]any(kv)
		}
		if kind != "" {
			payload["error_kind"] = string(kind)
		}
		encoded, err := json.Marshal(payload)
		if err != nil {
			return
		}
		lg.emit(string(encoded))
		return
	}

	parts := []string{
		fmt.Sprintf("%s %-7s [%s] [%s] %-24s", levelEmoji[level], strings.ToUpper(string(level)), ts, scope, event),
		"corr=" + lg.CorrelationID,
	}
	if len(kv) > 0 {
		keys := make([]string, 0, len(kv))
		for k := range kv {
			keys = append(keys, k)
		}
		sort.Strings(keys)
		pairs := make([]string, 0, len(kv))
		for _, k := range keys {
			pairs = append(pairs, fmt.Sprintf("%s=%v", k, kv[k]))
		}
		parts = append(parts, "| "+strings.Join(pairs, " "))
	}
	if kind != "" {
		parts = append(parts, "| error_kind="+string(kind))
	}
	if message != "" {
		parts = append(parts, "| "+message)
	}
	lg.emit(strings.Join(parts, " "))
}

// Debug logs at debug level.
func (lg *Logger) Debug(scope, event string, kv KV) { lg.log(Debug, scope, event, kv, "", "") }

// Info logs at info level.
func (lg *Logger) Info(scope, event string, kv KV) { lg.log(Info, scope, event, kv, "", "") }

// Success logs at success level.
func (lg *Logger) Success(scope, event string, kv KV) { lg.log(Success, scope, event, kv, "", "") }

// Warn logs at warn level.
func (lg *Logger) Warn(scope, event string, kv KV) { lg.log(Warn, scope, event, kv, "", "") }

// Error logs at error level with the system error kind by default.
func (lg *Logger) Error(scope, event string, kv KV) {
	lg.log(Error, scope, event, kv, ErrSystem, "")
}

// Fatal logs at fatal level with the system error kind by default.
func (lg *Logger) Fatal(scope, event string, kv KV) {
	lg.log(Fatal, scope, event, kv, ErrSystem, "")
}

// Default builds a logger from the environment. Used until the config authority
// is wired into the server.
func Default() *Logger {
	minLevel := Level(getenv("PSY_LOG_LEVEL", "info"))
	jsonMode := strings.ToLower(getenv("PSY_LOG_MODE", "text")) == "json"
	correlationID := getenv("PSY_CORRELATION_ID", "none")
	return &Logger{MinLevel: minLevel, JSONMode: jsonMode, CorrelationID: correlationID}
}

func getenv(key, fallback string) string {
	if v, ok := os.LookupEnv(key); ok && v != "" {
		return v
	}
	return fallback
}
