#include "psychosims_native.h"
#include "psychosims_log.h"

#include <atomic>
#include <cctype>
#include <cstdint>
#include <cstdlib>
#include <cstring>
#include <mutex>
#include <string>
#include <vector>

namespace {

// ---------------------------------------------------------------------------
// Minimal JSON helpers (no external JSON library).
// ---------------------------------------------------------------------------

const char* json_skip_ws(const char* p) {
    if (!p) return nullptr;
    while (*p && std::isspace(static_cast<unsigned char>(*p))) ++p;
    return p;
}

const char* json_skip_value(const char* p);

const char* json_skip_string(const char* p) {
    if (!p || *p != '"') return p;
    ++p;
    while (*p && *p != '"') {
        if (*p == '\\' && *(p + 1))
            p += 2;
        else
            ++p;
    }
    if (*p == '"') ++p;
    return p;
}

const char* json_skip_value(const char* p) {
    p = json_skip_ws(p);
    if (!p || !*p) return p;
    if (*p == '"') {
        p = json_skip_string(p);
    } else if (*p == '{') {
        ++p;
        while (true) {
            p = json_skip_ws(p);
            if (*p == '}') { ++p; break; }
            p = json_skip_string(p);
            p = json_skip_ws(p);
            if (*p == ':') ++p;
            p = json_skip_value(p);
            p = json_skip_ws(p);
            if (*p == ',') { ++p; continue; }
            if (*p == '}') { ++p; break; }
            if (!*p) break;
        }
    } else if (*p == '[') {
        ++p;
        while (true) {
            p = json_skip_ws(p);
            if (*p == ']') { ++p; break; }
            p = json_skip_value(p);
            p = json_skip_ws(p);
            if (*p == ',') { ++p; continue; }
            if (*p == ']') { ++p; break; }
            if (!*p) break;
        }
    } else {
        while (*p && *p != ',' && *p != '}' && *p != ']') ++p;
    }
    return p;
}

const char* json_find_value(const char* json, const char* key) {
    if (!json || !key) return nullptr;
    const size_t klen = std::strlen(key);
    const char* p = json_skip_ws(json);
    if (*p == '{') ++p;
    while (*p) {
        p = json_skip_ws(p);
        if (*p != '"') {
            if (*p == '}') return nullptr;
            p = json_skip_value(p);
            continue;
        }
        ++p;
        const char* key_start = p;
        p = json_skip_string(p - 1);
        const size_t len = (p - 1) - key_start;
        bool match = (len == klen && std::strncmp(key_start, key, klen) == 0);
        p = json_skip_ws(p);
        if (*p == ':') ++p;
        const char* val = json_skip_ws(p);
        if (match) return val;
        p = json_skip_value(val);
        p = json_skip_ws(p);
        if (*p == ',') ++p;
    }
    return nullptr;
}

bool parse_int(const char* p, int& out) {
    p = json_skip_ws(p);
    if (!p || !*p) return false;
    bool neg = false;
    if (*p == '-') { neg = true; ++p; }
    if (!std::isdigit(static_cast<unsigned char>(*p))) return false;
    long long val = 0;
    while (std::isdigit(static_cast<unsigned char>(*p))) {
        val = val * 10 + (*p - '0');
        ++p;
    }
    out = neg ? -static_cast<int>(val) : static_cast<int>(val);
    return true;
}

bool parse_uint32(const char* p, uint32_t& out) {
    int v = 0;
    if (!parse_int(p, v)) return false;
    out = static_cast<uint32_t>(v);
    return true;
}

bool parse_float(const char* p, float& out) {
    p = json_skip_ws(p);
    if (!p || !*p) return false;
    char* end = nullptr;
    out = std::strtof(p, &end);
    if (!end || end == p) return false;
    return true;
}

bool parse_bool(const char* p, bool& out) {
    p = json_skip_ws(p);
    if (!p) return false;
    if (std::strncmp(p, "true", 4) == 0) { out = true; return true; }
    if (std::strncmp(p, "false", 5) == 0) { out = false; return true; }
    return false;
}

bool parse_string(const char*& p, std::string& out) {
    p = json_skip_ws(p);
    if (!p || *p != '"') return false;
    ++p;
    while (*p && *p != '"') {
        if (*p == '\\' && *(p + 1)) {
            const char c = *(p + 1);
            if (c == 'n') out.push_back('\n');
            else if (c == 't') out.push_back('\t');
            else if (c == 'r') out.push_back('\r');
            else out.push_back(c);
            p += 2;
        } else {
            out.push_back(*p);
            ++p;
        }
    }
    if (*p == '"') ++p;
    return true;
}

std::string json_get_string(const char* json, const char* key, const char* default_val) {
    const char* v = json_find_value(json, key);
    std::string out;
    const char* tmp = v;
    if (tmp && parse_string(tmp, out)) return out;
    return default_val ? default_val : "";
}

int json_get_int(const char* json, const char* key, int default_val) {
    const char* v = json_find_value(json, key);
    int out = default_val;
    if (v && parse_int(v, out)) return out;
    return default_val;
}

uint32_t json_get_uint32(const char* json, const char* key, uint32_t default_val) {
    const char* v = json_find_value(json, key);
    uint32_t out = default_val;
    if (v && parse_uint32(v, out)) return out;
    return default_val;
}

float json_get_float(const char* json, const char* key, float default_val) {
    const char* v = json_find_value(json, key);
    float out = default_val;
    if (v && parse_float(v, out)) return out;
    return default_val;
}

bool json_get_bool(const char* json, const char* key, bool default_val) {
    const char* v = json_find_value(json, key);
    bool out = default_val;
    if (v && parse_bool(v, out)) return out;
    return default_val;
}

const char* extract_corr_id(const char* params_json) {
    static thread_local std::string corr_id;
    corr_id = json_get_string(params_json ? params_json : "{}", "correlation_id", "none");
    if (corr_id.empty()) corr_id = "none";
    return corr_id.c_str();
}

} // namespace

// ---------------------------------------------------------------------------
// Opaque context.
// ---------------------------------------------------------------------------

// This is the g++/host-compatible stub backend used while the real llama.cpp
// backend is built by CMake/NDK.  It does not link llama.cpp; it returns fixed
// placeholder outputs and routes every log through psy_log with a correlation
// id parsed from the incoming params_json.
struct PsyContext {
    std::atomic<bool> cancelled{false};
    std::string last_detokenized;
    std::string last_metadata;
    std::string model_path;
    std::string corr_id;
    int n_ctx = 4096;
    int n_batch = 512;
    int n_threads = 4;
};

const char* psy_version(void) {
    return "psychosims-native-0.1.0-stub";
}

PsyContext* psy_context_load(const char* model_path, const char* params) {
    const char* corr_id = extract_corr_id(params);
    if (!model_path || model_path[0] == '\0') {
        psy_log(PSY_LOG_ERROR, "native:inference", "load_failed", corr_id,
                "reason=missing_path", "model_path is empty");
        return nullptr;
    }

    PsyContext* ctx = new PsyContext();
    ctx->model_path = model_path;
    ctx->corr_id = corr_id;
    ctx->n_ctx = json_get_int(params, "n_ctx", 2048);
    ctx->n_batch = json_get_int(params, "n_batch", 512);
    ctx->n_threads = json_get_int(params, "n_threads", 4);

    const std::string kv = "n_ctx=" + std::to_string(ctx->n_ctx);
    psy_log(PSY_LOG_SUCCESS, "native:inference", "model_loaded", corr_id,
            kv.c_str(), "stub backend loaded (no llama.cpp linked)");
    return ctx;
}

void psy_context_destroy(PsyContext* ctx) {
    if (!ctx) return;
    psy_log(PSY_LOG_INFO, "native:inference", "model_unloaded",
            ctx->corr_id.empty() ? "none" : ctx->corr_id.c_str(),
            nullptr, nullptr);
    delete ctx;
}

int32_t psy_tokenize(
    PsyContext* ctx,
    const char* text,
    PsyToken* tokens,
    int32_t max_tokens) {
    if (!ctx || !text) return -1;
    // Stub tokenizer: one token per input byte up to max_tokens.
    const size_t len = std::strlen(text);
    const int32_t count = static_cast<int32_t>(len);
    if (tokens && max_tokens > 0) {
        const int32_t to_write = count < max_tokens ? count : max_tokens;
        for (int32_t i = 0; i < to_write; ++i) tokens[i] = static_cast<PsyToken>(static_cast<unsigned char>(text[i]));
    }
    return count;
}

const char* psy_detokenize(PsyContext* ctx, PsyToken token) {
    if (!ctx) return "";
    static const char* kUnk = "\xef\xbf\xbd";
    if (token >= 32 && token < 127) {
        ctx->last_detokenized = static_cast<char>(token);
    } else {
        ctx->last_detokenized = kUnk;
    }
    return ctx->last_detokenized.c_str();
}

int32_t psy_apply_chat_template(
    PsyContext* ctx,
    const char* conversation_json,
    char* out_prompt,
    int32_t out_size) {
    if (!ctx || !conversation_json || !out_prompt || out_size <= 0) return -1;
    const std::string rendered =
        std::string("### System\n") + conversation_json + "\n### Assistant\n";
    const int32_t needed = static_cast<int32_t>(rendered.size());
    if (needed >= out_size) {
        std::memcpy(out_prompt, rendered.c_str(), static_cast<size_t>(out_size) - 1);
        out_prompt[out_size - 1] = '\0';
    } else {
        std::memcpy(out_prompt, rendered.c_str(), static_cast<size_t>(needed) + 1);
    }
    return needed;
}

const char* psy_model_metadata(PsyContext* ctx) {
    if (!ctx) return "{}";
    ctx->last_metadata =
        std::string("{\"") + "n_ctx\":" + std::to_string(ctx->n_ctx) +
        ",\"n_vocab\":32000" +
        ",\"n_embd\":4096" +
        ",\"n_layer\":32" +
        ",\"quantization\":\"stub\"}";
    return ctx->last_metadata.c_str();
}

int32_t psy_generate(
    PsyContext* ctx,
    const char* params_json,
    PsyTokenCallback callback,
    void* user_data) {
    if (!ctx || !callback) return -1;

    const char* corr_id = extract_corr_id(params_json);
    const std::string prompt = json_get_string(params_json, "prompt", "");
    int max_tokens = json_get_int(params_json, "max_tokens", 256);
    const float temperature = json_get_float(params_json, "temperature", 0.8f);
    const float top_p = json_get_float(params_json, "top_p", 0.95f);
    const int top_k = json_get_int(params_json, "top_k", 40);
    (void)temperature; (void)top_p; (void)top_k;
    if (max_tokens <= 0) max_tokens = 1;

    psy_log(PSY_LOG_INFO, "native:inference", "generate", corr_id,
            ("prompt_len=" + std::to_string(prompt.size())).c_str(),
            "stub generate started");

    // Stream a deterministic stub phrase word-by-word.  Each emitted token is a
    // complete UTF-8 word (with trailing space) so Dart tests can join them and
    // find the full phrase.
    static const char* kStubPhrase = "deterministic stub response ";
    std::string pending;
    int emitted = 0;
    for (const char* word = kStubPhrase; *word && emitted < max_tokens; ++word) {
        if (ctx->cancelled.load(std::memory_order_acquire)) {
            ctx->cancelled.store(false, std::memory_order_release);
            psy_log(PSY_LOG_INFO, "native:inference", "generate", corr_id,
                    "status=cancelled", "generation cancelled");
            return 1;
        }
        pending.push_back(*word);
        if (*word == ' ') {
            callback(pending.c_str(), static_cast<PsyToken>(pending[0]), 1, user_data);
            pending.clear();
            ++emitted;
        }
    }
    if (!pending.empty() && emitted < max_tokens) {
        callback(pending.c_str(), static_cast<PsyToken>(pending[0]), 1, user_data);
        ++emitted;
    }

    psy_log(PSY_LOG_SUCCESS, "native:inference", "generate", corr_id,
            ("tokens=" + std::to_string(emitted)).c_str(),
            "stub generate completed");
    return 0;
}

void psy_cancel(PsyContext* ctx) {
    if (ctx) ctx->cancelled.store(true, std::memory_order_release);
}

void psy_reset_kv(PsyContext* ctx) {
    if (!ctx) return;
    psy_log(PSY_LOG_INFO, "native:inference", "kv_cache_reset",
            ctx->corr_id.empty() ? "none" : ctx->corr_id.c_str(),
            nullptr, "stub KV reset (no-op)");
}
