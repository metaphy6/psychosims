#include "psychosims_native.h"
#include "psychosims_log.h"

#include <algorithm>
#include <atomic>
#include <cctype>
#include <chrono>
#include <cstdint>
#include <cstdlib>
#include <cstring>
#include <list>
#include <mutex>
#include <string>
#include <vector>

namespace {

using SteadyClock = std::chrono::steady_clock;
using Millis = std::chrono::milliseconds;

int64_t to_ms(SteadyClock::duration d) {
    return std::chrono::duration_cast<Millis>(d).count();
}

} // namespace

#if __has_include(<llama.h>)
#define PSYCHOSIMS_WITH_LLAMA_CPP 1
#include <llama.h>
#if __has_include(<ggml.h>)
#include <ggml.h>
#endif
#endif

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

// Backend selection: use real llama.cpp when the header is available
// (CMake/NDK builds with the submodule), otherwise compile as a stub backend.

namespace {

// Parse a JSON array of strings (e.g. ["a", "b"]) from json_find_value output.
std::vector<std::string> parse_string_array(const char* arr) {
    std::vector<std::string> out;
    if (!arr) return out;
    arr = json_skip_ws(arr);
    if (*arr != '[') return out;
    ++arr;
    while (true) {
        arr = json_skip_ws(arr);
        if (*arr == ']') break;
        if (*arr == '"') {
            std::string s;
            const char* tmp = arr;
            if (parse_string(tmp, s)) out.push_back(std::move(s));
            arr = tmp;
        } else {
            arr = json_skip_value(arr);
        }
        arr = json_skip_ws(arr);
        if (*arr == ',') { ++arr; continue; }
        if (*arr == ']') break;
        if (!*arr) break;
    }
    return out;
}

std::vector<std::string> json_get_string_array(const char* json, const char* key) {
    const char* v = json_find_value(json, key);
    return parse_string_array(v);
}

// UTF-8 streaming helper: accumulate bytes and emit complete codepoints.
struct Utf8Accumulator {
    std::string buf;

    static bool ends_incomplete(const std::string& s) {
        int cont = 0;
        for (auto it = s.rbegin(); it != s.rend(); ++it) {
            unsigned char c = static_cast<unsigned char>(*it);
            if ((c & 0xC0) == 0x80) {
                ++cont;
                continue;
            }
            if (c < 0x80) return false;
            int expected = 0;
            if ((c & 0xE0) == 0xC0) expected = 1;
            else if ((c & 0xF0) == 0xE0) expected = 2;
            else if ((c & 0xF8) == 0xF0) expected = 3;
            return cont < expected;
        }
        return cont > 0;
    }

    bool feed(const std::string& piece, PsyToken token,
              PsyTokenCallback callback, void* user_data) {
        buf += piece;
        if (!ends_incomplete(buf)) {
            callback(buf.c_str(), token, 1, user_data);
            buf.clear();
            return true;
        }
        return false;
    }

    void flush(PsyToken token, PsyTokenCallback callback, void* user_data) {
        if (!buf.empty()) {
            callback(buf.c_str(), token, ends_incomplete(buf) ? 0 : 1, user_data);
            buf.clear();
        }
    }
};

#if PSYCHOSIMS_WITH_LLAMA_CPP
// Parse [{"role":"...","content":"..."}, ...] into llama_chat_message array.
// Uses std::list for stable storage because llama_chat_message holds raw
// c_str() pointers that must remain valid while the array is consumed.
bool parse_chat_messages(const char* json,
                         std::vector<llama_chat_message>& messages,
                         std::list<std::string>& role_storage,
                         std::list<std::string>& content_storage) {
    if (!json) return false;
    const char* p = json_skip_ws(json);
    if (*p != '[') return false;
    ++p;
    while (true) {
        p = json_skip_ws(p);
        if (*p == ']') { ++p; break; }
        if (*p != '{') {
            p = json_skip_value(p);
            p = json_skip_ws(p);
            if (*p == ',') { ++p; continue; }
            if (*p == ']') { ++p; break; }
            if (!*p) break;
            continue;
        }
        ++p;
        std::string role, content;
        while (true) {
            p = json_skip_ws(p);
            if (*p == '}') { ++p; break; }
            if (*p != '"') return false;
            std::string key;
            const char* tmp = p;
            if (!parse_string(tmp, key)) return false;
            p = tmp;
            p = json_skip_ws(p);
            if (*p == ':') ++p;
            p = json_skip_ws(p);
            std::string val;
            tmp = p;
            if (*p == '"') {
                if (!parse_string(tmp, val)) return false;
                p = tmp;
            } else {
                p = json_skip_value(p);
            }
            if (key == "role") role = std::move(val);
            else if (key == "content") content = std::move(val);
            p = json_skip_ws(p);
            if (*p == ',') { ++p; continue; }
            if (*p == '}') { ++p; break; }
            if (!*p) break;
        }
        role_storage.push_back(std::move(role));
        content_storage.push_back(std::move(content));
        messages.push_back(
            {role_storage.back().c_str(), content_storage.back().c_str()});
        p = json_skip_ws(p);
        if (*p == ',') { ++p; continue; }
        if (*p == ']') { ++p; break; }
        if (!*p) break;
    }
    return true;
}
#endif

} // namespace

// ---------------------------------------------------------------------------
// Opaque context.
// ---------------------------------------------------------------------------

struct GenerateStats {
    int prompt_tokens = 0;
    int64_t prompt_eval_ms = 0;
    int generated_tokens = 0;
    int64_t generation_ms = 0;
    int64_t total_ms = 0;
};

struct PsyContext {
    std::atomic<bool> cancelled{false};
    std::string last_detokenized;
    std::string last_metadata;
    std::string last_stats;
    std::string model_path;
    std::string corr_id;
    std::string kv_cache_type;
    int n_ctx = 4096;
    int n_batch = 512;
    int n_threads = 4;
    GenerateStats last_generate_stats;
    std::vector<llama_token> cached_prompt_tokens;
#if PSYCHOSIMS_WITH_LLAMA_CPP
    llama_model* model = nullptr;
    llama_context* lctx = nullptr;
    const llama_vocab* vocab = nullptr;
    bool real_mode = false;
#endif
};

const char* psy_version(void) {
    return "psychosims-native-0.1.0";
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
    ctx->kv_cache_type = json_get_string(params, "kv_cache_type", "f16");

#if PSYCHOSIMS_WITH_LLAMA_CPP
    {
        llama_model_params mparams = llama_model_default_params();
        mparams.use_mmap = true;
        llama_model* model = llama_model_load_from_file(model_path, mparams);
        if (model) {
            llama_context_params cparams = llama_context_default_params();
            cparams.n_ctx = static_cast<uint32_t>(ctx->n_ctx);
            cparams.n_batch = static_cast<uint32_t>(ctx->n_batch);
            cparams.n_ubatch = static_cast<uint32_t>(ctx->n_batch);
            cparams.n_threads = ctx->n_threads;
            cparams.n_threads_batch = ctx->n_threads;
#if __has_include(<ggml.h>)
            if (ctx->kv_cache_type == "f32") {
                cparams.type_k = GGML_TYPE_F32;
                cparams.type_v = GGML_TYPE_F32;
            } else if (ctx->kv_cache_type == "f16") {
                cparams.type_k = GGML_TYPE_F16;
                cparams.type_v = GGML_TYPE_F16;
            } else if (ctx->kv_cache_type == "q8_0") {
                cparams.type_k = GGML_TYPE_Q8_0;
                cparams.type_v = GGML_TYPE_Q8_0;
            } else if (ctx->kv_cache_type == "q4_0") {
                cparams.type_k = GGML_TYPE_Q4_0;
                cparams.type_v = GGML_TYPE_Q4_0;
            }
#endif
            llama_context* lctx = llama_init_from_model(model, cparams);
            if (lctx) {
                ctx->model = model;
                ctx->lctx = lctx;
                ctx->vocab = llama_model_get_vocab(model);
                ctx->real_mode = true;
                const std::string kv =
                    "n_ctx=" + std::to_string(ctx->n_ctx) +
                    ",n_batch=" + std::to_string(ctx->n_batch) +
                    ",n_threads=" + std::to_string(ctx->n_threads);
                psy_log(PSY_LOG_SUCCESS, "native:inference", "model_loaded",
                        corr_id, kv.c_str(), "llama.cpp backend loaded");
                return ctx;
            }
            llama_model_free(model);
        }
        psy_log(PSY_LOG_WARN, "native:inference", "load_failed", corr_id,
                "reason=llama_load_failed,falling_back=stub",
                "real backend failed; using stub backend");
    }
#endif

    const std::string kv = "n_ctx=" + std::to_string(ctx->n_ctx);
    psy_log(PSY_LOG_SUCCESS, "native:inference", "model_loaded", corr_id,
            kv.c_str(), "stub backend loaded (no llama.cpp linked)");
    return ctx;
}

void psy_context_destroy(PsyContext* ctx) {
    if (!ctx) return;
#if PSYCHOSIMS_WITH_LLAMA_CPP
    if (ctx->real_mode) {
        if (ctx->lctx) llama_free(ctx->lctx);
        if (ctx->model) llama_model_free(ctx->model);
    }
#endif
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
#if PSYCHOSIMS_WITH_LLAMA_CPP
    if (ctx->real_mode && ctx->vocab) {
        const int32_t text_len = static_cast<int32_t>(std::strlen(text));
        if (!tokens || max_tokens <= 0) {
            // Count-only path: tokenize into a temporary buffer.
            std::vector<llama_token> tmp;
            tmp.resize(4096);
            int32_t n = llama_tokenize(ctx->vocab, text, text_len, tmp.data(),
                                       static_cast<int32_t>(tmp.size()), true,
                                       true);
            if (n < 0) {
                tmp.resize(static_cast<size_t>(-n));
                n = llama_tokenize(ctx->vocab, text, text_len, tmp.data(),
                                   static_cast<int32_t>(tmp.size()), true, true);
            }
            return n < 0 ? 0 : n;
        }
        return llama_tokenize(ctx->vocab, text, text_len, tokens, max_tokens,
                              true, true);
    }
#endif
    const size_t len = std::strlen(text);
    const int32_t count = static_cast<int32_t>(len);
    if (tokens && max_tokens > 0) {
        const int32_t to_write = count < max_tokens ? count : max_tokens;
        for (int32_t i = 0; i < to_write; ++i)
            tokens[i] = static_cast<PsyToken>(static_cast<unsigned char>(text[i]));
    }
    return count;
}

const char* psy_detokenize(PsyContext* ctx, PsyToken token) {
    if (!ctx) return "";
#if PSYCHOSIMS_WITH_LLAMA_CPP
    if (ctx->real_mode && ctx->vocab) {
        static thread_local std::string buf;
        buf.resize(128);
        int32_t n = llama_token_to_piece(ctx->vocab, token, buf.data(),
                                         static_cast<int32_t>(buf.size()), 0, true);
        if (n < 0) {
            buf.resize(static_cast<size_t>(-n));
            n = llama_token_to_piece(ctx->vocab, token, buf.data(),
                                     static_cast<int32_t>(buf.size()), 0, true);
        }
        if (n > 0) {
            ctx->last_detokenized.assign(buf.data(), static_cast<size_t>(n));
        } else {
            ctx->last_detokenized = "\xef\xbf\xbd";
        }
        return ctx->last_detokenized.c_str();
    }
#endif
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
#if PSYCHOSIMS_WITH_LLAMA_CPP
    if (ctx->real_mode && ctx->model && ctx->vocab) {
        std::vector<llama_chat_message> messages;
        std::list<std::string> roles;
        std::list<std::string> contents;
        if (parse_chat_messages(conversation_json, messages, roles, contents)) {
            const char* tmpl = llama_model_chat_template(ctx->model, nullptr);
            int32_t needed = llama_chat_apply_template(
                tmpl, messages.data(), messages.size(), true, nullptr, 0);
            if (needed > 0) {
                std::vector<char> tmp(static_cast<size_t>(needed) + 1, '\0');
                int32_t written = llama_chat_apply_template(
                    tmpl, messages.data(), messages.size(), true,
                    tmp.data(), static_cast<int32_t>(tmp.size()));
                if (written >= 0) {
                    // Some templates leave uninitialised padding bytes after the
                    // terminating null; only copy the valid [0, written] range.
                    const int32_t to_copy = written < out_size ? written : out_size - 1;
                    std::memcpy(out_prompt, tmp.data(), static_cast<size_t>(to_copy));
                    out_prompt[to_copy] = '\0';
                    return written;
                }
            }
        }
    }
#endif
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
#if PSYCHOSIMS_WITH_LLAMA_CPP
    if (ctx->real_mode && ctx->model && ctx->vocab) {
        char desc[256] = {0};
        llama_model_desc(ctx->model, desc, sizeof(desc));
        ctx->last_metadata =
            std::string("{\"n_ctx\":") + std::to_string(llama_n_ctx(ctx->lctx)) +
            ",\"n_ctx_train\":" + std::to_string(llama_model_n_ctx_train(ctx->model)) +
            ",\"n_batch\":" + std::to_string(ctx->n_batch) +
            ",\"n_threads\":" + std::to_string(ctx->n_threads) +
            ",\"kv_cache_type\":\"" + ctx->kv_cache_type + "\"" +
            ",\"n_vocab\":" + std::to_string(llama_vocab_n_tokens(ctx->vocab)) +
            ",\"n_embd\":" + std::to_string(llama_model_n_embd(ctx->model)) +
            ",\"n_layer\":" + std::to_string(llama_model_n_layer(ctx->model)) +
            ",\"size_bytes\":" + std::to_string(llama_model_size(ctx->model)) +
            ",\"n_params\":" + std::to_string(llama_model_n_params(ctx->model)) +
            ",\"description\":\"" + std::string(desc) + "\"" +
            ",\"quantization\":\"unknown\"}";
        return ctx->last_metadata.c_str();
    }
#endif
    ctx->last_metadata =
        std::string("{\"n_ctx\":") + std::to_string(ctx->n_ctx) +
        ",\"n_batch\":" + std::to_string(ctx->n_batch) +
        ",\"n_threads\":" + std::to_string(ctx->n_threads) +
        ",\"kv_cache_type\":\"" + ctx->kv_cache_type + "\"" +
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
    const uint32_t seed = json_get_uint32(params_json, "seed", 0xFFFFFFFFu);
    const std::string grammar = json_get_string(params_json, "grammar", "");
    const std::vector<std::string> stop_strings = json_get_string_array(params_json, "stop");
    if (max_tokens <= 0) max_tokens = 1;

#if PSYCHOSIMS_WITH_LLAMA_CPP
    if (ctx->real_mode && ctx->lctx && ctx->vocab) {
        const auto total_start = SteadyClock::now();
        ctx->last_generate_stats = GenerateStats();

        psy_log(PSY_LOG_INFO, "native:inference", "generate", corr_id,
                ("prompt_len=" + std::to_string(prompt.size())).c_str(),
                "llama.cpp generate started");

        // Tokenize prompt.
        std::vector<llama_token> prompt_tokens;
        prompt_tokens.resize(prompt.size() + 8);
        int32_t n_tokens = llama_tokenize(
            ctx->vocab, prompt.c_str(), static_cast<int32_t>(prompt.size()),
            prompt_tokens.data(), static_cast<int32_t>(prompt_tokens.size()),
            true, true);
        if (n_tokens < 0) {
            prompt_tokens.resize(static_cast<size_t>(-n_tokens));
            n_tokens = llama_tokenize(
                ctx->vocab, prompt.c_str(), static_cast<int32_t>(prompt.size()),
                prompt_tokens.data(), static_cast<int32_t>(prompt_tokens.size()),
                true, true);
        }
        if (n_tokens <= 0) {
            psy_log(PSY_LOG_ERROR, "native:inference", "generate", corr_id,
                    "reason=tokenize_failed", "failed to tokenize prompt");
            return -1;
        }
        prompt_tokens.resize(static_cast<size_t>(n_tokens));

        // Respect context window.
        const int n_ctx = static_cast<int>(llama_n_ctx(ctx->lctx));
        const int reserve = max_tokens + 4;
        if (static_cast<int>(prompt_tokens.size()) > n_ctx - reserve) {
            const size_t keep = static_cast<size_t>(std::max(0, n_ctx - reserve));
            prompt_tokens.erase(
                prompt_tokens.begin(),
                prompt_tokens.end() - static_cast<ptrdiff_t>(keep));
            psy_log(PSY_LOG_WARN, "native:inference", "generate", corr_id,
                    ("truncated_to=" + std::to_string(prompt_tokens.size())).c_str(),
                    "prompt truncated to fit context window");
        }

        // Build sampler chain.
        llama_sampler_chain_params sparams = llama_sampler_chain_default_params();
        llama_sampler* smpl = llama_sampler_chain_init(sparams);
        if (temperature <= 0.0f) {
            llama_sampler_chain_add(smpl, llama_sampler_init_greedy());
        } else {
            llama_sampler_chain_add(smpl, llama_sampler_init_temp(temperature));
            if (top_k > 0) {
                llama_sampler_chain_add(smpl, llama_sampler_init_top_k(top_k));
            }
            if (top_p > 0.0f && top_p < 1.0f) {
                llama_sampler_chain_add(smpl, llama_sampler_init_top_p(top_p, 1));
            }
            if (!grammar.empty()) {
                llama_sampler* grmr = llama_sampler_init_grammar(
                    ctx->vocab, grammar.c_str(), nullptr);
                if (grmr) llama_sampler_chain_add(smpl, grmr);
            }
            llama_sampler_chain_add(
                smpl, llama_sampler_init_dist(seed == 0xFFFFFFFFu ? 12345u : seed));
        }

        // Prepare batch.
        const int32_t n_batch = ctx->n_batch;
        llama_batch batch = llama_batch_init(n_batch, 0, 1);
        if (!batch.token) {
            llama_sampler_free(smpl);
            psy_log(PSY_LOG_ERROR, "native:inference", "generate", corr_id,
                    "reason=batch_init_failed", "failed to allocate batch");
            return -1;
        }

        // Decode prompt in chunks, reusing the longest common prefix with
        // the previous turn so the stable Tier-1 frame is not re-evaluated.
        const auto prompt_start = SteadyClock::now();

        size_t common_prefix = 0;
        if (!ctx->cached_prompt_tokens.empty()) {
            const size_t min_len = std::min(
                prompt_tokens.size(), ctx->cached_prompt_tokens.size());
            while (common_prefix < min_len &&
                   prompt_tokens[common_prefix] ==
                       ctx->cached_prompt_tokens[common_prefix]) {
                ++common_prefix;
            }
        }

        // Trim any divergent KV cells so new positions stay consecutive.
        if (common_prefix > 0 && ctx->lctx) {
            llama_memory_seq_rm(
                llama_get_memory(ctx->lctx), 0,
                static_cast<llama_pos>(common_prefix), -1);
        }

        int32_t n_past = static_cast<int32_t>(common_prefix);
        bool decode_ok = true;
        const size_t total_prompt = prompt_tokens.size();
        for (size_t i = common_prefix;
             i < total_prompt && decode_ok;
             i += static_cast<size_t>(n_batch)) {
            const size_t chunk = std::min(static_cast<size_t>(n_batch),
                                          total_prompt - i);
            batch.n_tokens = static_cast<int32_t>(chunk);
            for (size_t j = 0; j < chunk; ++j) {
                batch.token[j] = prompt_tokens[i + j];
                batch.pos[j] = n_past + static_cast<int32_t>(j);
                batch.n_seq_id[j] = 1;
                batch.seq_id[j][0] = 0;
                batch.logits[j] = 0;
            }
            batch.logits[chunk - 1] = 1;
            if (llama_decode(ctx->lctx, batch) != 0) {
                decode_ok = false;
                break;
            }
            n_past += static_cast<int32_t>(chunk);
        }
        ctx->cached_prompt_tokens = prompt_tokens;
        ctx->last_generate_stats.prompt_tokens =
            static_cast<int>(prompt_tokens.size());
        ctx->last_generate_stats.prompt_eval_ms =
            to_ms(SteadyClock::now() - prompt_start);

        if (!decode_ok) {
            llama_batch_free(batch);
            llama_sampler_free(smpl);
            psy_log(PSY_LOG_ERROR, "native:inference", "generate", corr_id,
                    "reason=decode_failed", "prompt decode failed");
            return -1;
        }

        // Sampling loop.
        const auto generation_start = SteadyClock::now();
        llama_token token = prompt_tokens.empty() ? -1 : prompt_tokens.back();
        std::string generated;
        Utf8Accumulator utf8;
        int emitted = 0;
        for (int i = 0; i < max_tokens; ++i) {
            if (ctx->cancelled.load(std::memory_order_acquire)) {
                ctx->cancelled.store(false, std::memory_order_release);
                llama_batch_free(batch);
                llama_sampler_free(smpl);
                psy_log(PSY_LOG_INFO, "native:inference", "generate", corr_id,
                        "status=cancelled", "generation cancelled");
                return 1;
            }

            if (i == 0) {
                token = llama_sampler_sample(smpl, ctx->lctx, -1);
            } else {
                batch.n_tokens = 1;
                batch.token[0] = token;
                batch.pos[0] = n_past;
                batch.n_seq_id[0] = 1;
                batch.seq_id[0][0] = 0;
                batch.logits[0] = 1;
                if (llama_decode(ctx->lctx, batch) != 0) {
                    decode_ok = false;
                    break;
                }
                ++n_past;
                token = llama_sampler_sample(smpl, ctx->lctx, -1);
            }

            if (llama_vocab_is_eog(ctx->vocab, token)) break;

            char piece_buf[256];
            int32_t n = llama_token_to_piece(ctx->vocab, token, piece_buf,
                                             sizeof(piece_buf), 0, true);
            std::string piece;
            if (n > 0) {
                piece.assign(piece_buf, static_cast<size_t>(n));
            } else if (n < 0) {
                piece.resize(static_cast<size_t>(-n));
                n = llama_token_to_piece(ctx->vocab, token, piece.data(),
                                         static_cast<int32_t>(piece.size()), 0, true);
                if (n > 0) piece.resize(static_cast<size_t>(n));
            }
            generated += piece;
            if (utf8.feed(piece, token, callback, user_data)) ++emitted;

            // Stop-string check.
            bool stopped = false;
            for (const auto& s : stop_strings) {
                if (generated.size() >= s.size() &&
                    generated.compare(generated.size() - s.size(), s.size(), s) == 0) {
                    stopped = true;
                    break;
                }
            }
            if (stopped) break;
        }

        utf8.flush(token, callback, user_data);
        llama_batch_free(batch);
        llama_sampler_free(smpl);

        ctx->last_generate_stats.generated_tokens = emitted;
        ctx->last_generate_stats.generation_ms = to_ms(SteadyClock::now() - generation_start);
        ctx->last_generate_stats.total_ms = to_ms(SteadyClock::now() - total_start);

        psy_log(PSY_LOG_SUCCESS, "native:inference", "generate", corr_id,
                ("tokens=" + std::to_string(emitted)).c_str(),
                decode_ok ? "llama.cpp generate completed"
                          : "llama.cpp generate failed during sampling");
        return decode_ok ? 0 : -1;
    }
#endif

    // Stub generate path for fallback / builds without llama.cpp.
    psy_log(PSY_LOG_INFO, "native:inference", "generate", corr_id,
            ("prompt_len=" + std::to_string(prompt.size())).c_str(),
            "stub generate started");

    const bool utf8_test = (prompt.find("utf8") != std::string::npos);
    static const char* kStubPhrase = "deterministic stub response ";
    static const char* kUtf8Phrase = "caf\xc3\xa9 "; // "café "
    const char* phrase = utf8_test ? kUtf8Phrase : kStubPhrase;
    const size_t phrase_len = std::strlen(phrase);
    std::string pending;
    int emitted = 0;
    size_t phrase_idx = 0;
    int utf8_remaining = 0;
    for (; emitted < max_tokens; ++phrase_idx) {
        const char ch = phrase[phrase_idx % phrase_len];
        if (ch == '\0') continue;
        if (ctx->cancelled.load(std::memory_order_acquire)) {
            ctx->cancelled.store(false, std::memory_order_release);
            psy_log(PSY_LOG_INFO, "native:inference", "generate", corr_id,
                    "status=cancelled", "generation cancelled");
            return 1;
        }
        const unsigned char c = static_cast<unsigned char>(ch);
        const bool is_continuation = (c & 0xC0) == 0x80;
        if (!is_continuation) {
            if (c < 0x80) {
                utf8_remaining = 0;
            } else if ((c & 0xE0) == 0xC0) {
                utf8_remaining = 1;
            } else if ((c & 0xF0) == 0xE0) {
                utf8_remaining = 2;
            } else if ((c & 0xF8) == 0xF0) {
                utf8_remaining = 3;
            } else {
                utf8_remaining = 0;
            }
        } else if (utf8_remaining > 0) {
            --utf8_remaining;
        }
        const bool is_complete = (utf8_remaining == 0);

        pending.push_back(ch);
        const bool emit_now = utf8_test || (ch == ' ');
        if (emit_now) {
            callback(pending.c_str(), static_cast<PsyToken>(pending[0]),
                     is_complete ? 1 : 0, user_data);
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
    ctx->cached_prompt_tokens.clear();
#if PSYCHOSIMS_WITH_LLAMA_CPP
    if (ctx->real_mode && ctx->lctx) {
        llama_memory_clear(llama_get_memory(ctx->lctx), true);
        psy_log(PSY_LOG_INFO, "native:inference", "kv_cache_reset",
                ctx->corr_id.empty() ? "none" : ctx->corr_id.c_str(),
                nullptr, "KV cache cleared");
        return;
    }
#endif
    psy_log(PSY_LOG_INFO, "native:inference", "kv_cache_reset",
            ctx->corr_id.empty() ? "none" : ctx->corr_id.c_str(),
            nullptr, "stub KV reset (no-op)");
}

const char* psy_last_generate_stats(PsyContext* ctx) {
    if (!ctx) return "{}";
    const GenerateStats& s = ctx->last_generate_stats;
    ctx->last_stats =
        std::string("{\"prompt_tokens\":") + std::to_string(s.prompt_tokens) +
        ",\"prompt_eval_ms\":" + std::to_string(s.prompt_eval_ms) +
        ",\"generated_tokens\":" + std::to_string(s.generated_tokens) +
        ",\"generation_ms\":" + std::to_string(s.generation_ms) +
        ",\"total_ms\":" + std::to_string(s.total_ms) + "}";
    return ctx->last_stats.c_str();
}
