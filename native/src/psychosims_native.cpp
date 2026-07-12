#include "psychosims_native.h"
#include "psychosims_log.h"

#include <string>
#include <vector>
#include <cstring>
#include <cstdlib>

const char* psy_version(void) {
    return "psychosims-native-0.1.0";
}

struct PsyContext {
    std::string model_path;
    std::string params;
    std::string last_error;
    std::string last_detokenized;
    std::string last_metadata;
    std::vector<PsyToken> token_buffer;
    bool cancelled = false;
};

PsyContext* psy_context_load(const char* model_path, const char* params) {
    if (!model_path || model_path[0] == '\0') {
        psy_log(PSY_LOG_ERROR, "native:inference", "load_failed", "none",
                "reason=missing_path", "model_path is empty");
        return nullptr;
    }
    auto* ctx = new PsyContext();
    ctx->model_path = model_path;
    ctx->params = params ? params : "{}";
    psy_log(PSY_LOG_SUCCESS, "native:inference", "model_loaded", "none",
            "path=stub", "llama.cpp backend not linked in PoC stub");
    return ctx;
}

void psy_context_destroy(PsyContext* ctx) {
    delete ctx;
}

int32_t psy_tokenize(
    PsyContext* ctx,
    const char* text,
    PsyToken* tokens,
    int32_t max_tokens) {
    if (!ctx || !text) return -1;
    ctx->token_buffer.clear();
    const size_t len = std::strlen(text);
    // Stub tokenizer: one token per byte for deterministic scaffolding tests.
    for (size_t i = 0; i < len; ++i) {
        ctx->token_buffer.push_back(static_cast<PsyToken>(text[i]));
    }
    if (tokens && max_tokens > 0) {
        const int32_t to_write =
            static_cast<int32_t>(ctx->token_buffer.size()) < max_tokens
                ? static_cast<int32_t>(ctx->token_buffer.size())
                : max_tokens;
        std::memcpy(tokens, ctx->token_buffer.data(),
                    static_cast<size_t>(to_write) * sizeof(PsyToken));
    }
    return static_cast<int32_t>(ctx->token_buffer.size());
}

const char* psy_detokenize(PsyContext* ctx, PsyToken token) {
    if (!ctx) return "";
    // Return the byte value as a one-byte string for the stub.
    char buf[2] = {static_cast<char>(token & 0xFF), '\0'};
    ctx->last_detokenized = buf;
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
        std::memcpy(out_prompt, rendered.c_str(), out_size - 1);
        out_prompt[out_size - 1] = '\0';
    } else {
        std::memcpy(out_prompt, rendered.c_str(), needed + 1);
    }
    return needed;
}

const char* psy_model_metadata(PsyContext* ctx) {
    if (!ctx) return "{}";
    ctx->last_metadata =
        "{\"n_ctx\":2048,\"n_vocab\":151936,\"quantization\":\"Q4_K_M\"}";
    return ctx->last_metadata.c_str();
}

int32_t psy_generate(
    PsyContext* ctx,
    const char* params_json,
    PsyTokenCallback callback,
    void* user_data) {
    if (!ctx || !callback) return -1;
    psy_log(PSY_LOG_INFO, "native:inference", "generate_start", "none",
            "max_tokens=stub", "scaffolding generation");
    const char* stub_text = "This is a deterministic stub response.";
    for (int i = 0; stub_text[i] != '\0'; ++i) {
        if (ctx->cancelled) {
            ctx->cancelled = false;
            return 1;
        }
        char buf[2] = {stub_text[i], '\0'};
        callback(buf, static_cast<PsyToken>(stub_text[i]), 1, user_data);
    }
    return 0;
}

void psy_cancel(PsyContext* ctx) {
    if (ctx) ctx->cancelled = true;
}

void psy_reset_kv(PsyContext* ctx) {
    if (ctx) {
        psy_log(PSY_LOG_INFO, "native:inference", "kv_cache_reset", "none",
                nullptr, nullptr);
    }
}
