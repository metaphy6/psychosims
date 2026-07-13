#include <cassert>
#include <cstdio>
#include <cstring>
#include <fstream>
#include <iostream>
#include <string>

#include "psychosims_native.h"

namespace {

bool file_exists(const char* path) {
    std::ifstream f(path, std::ios::binary);
    return f.good();
}

void test_real_model(const char* model_path) {
    std::cout << "testing real model: " << model_path << std::endl;

    const char* params =
        "{\"n_ctx\":2048,\"n_batch\":512,\"n_threads\":4,"
        "\"correlation_id\":\"smoke\"}";
    PsyContext* ctx = psy_context_load(model_path, params);
    assert(ctx != nullptr);

    const char* metadata = psy_model_metadata(ctx);
    assert(metadata != nullptr);
    assert(std::strlen(metadata) > 2);
    std::cout << "metadata: " << metadata << std::endl;

    // Tokenize a short prompt.
    const char* prompt = "What is 2+2?";
    PsyToken tokens[128];
    int32_t n_tokens = psy_tokenize(ctx, prompt, tokens, 128);
    assert(n_tokens > 0);
    std::cout << "tokenized to " << n_tokens << " tokens" << std::endl;

    // Apply chat template.
    const char* conversation =
        "[{\"role\":\"system\",\"content\":\"You are a helpful assistant.\"},"
        "{\"role\":\"user\",\"content\":\"What is 2+2?\"}]";
    char formatted[4096];
    int32_t written = psy_apply_chat_template(ctx, conversation, formatted, 4096);
    assert(written > 0);
    std::cout << "formatted prompt length: " << written << std::endl;

    // Generate a few tokens.
    const char* gen_params =
        "{\"prompt\":\"What is 2+2?\",\"max_tokens\":16,"
        "\"temperature\":0.0,\"top_p\":1.0,\"top_k\":0,"
        "\"correlation_id\":\"smoke\"}";
    int generated = 0;
    auto callback = [](const char* text, int32_t /*token_id*/, int /*complete*/, void* user) {
        auto* count = static_cast<int*>(user);
        std::cout << text;
        std::cout.flush();
        ++(*count);
    };
    int32_t result = psy_generate(ctx, gen_params, callback, &generated);
    assert(result == 0);
    std::cout << std::endl << "generated " << generated << " callback(s)" << std::endl;

    psy_context_destroy(ctx);
}

} // namespace

int main() {
    const char* version = psy_version();
    assert(std::strcmp(version, "psychosims-native-0.1.0") == 0);

    // Loading with an empty path must fail gracefully.
    PsyContext* ctx = psy_context_load("", "{}");
    assert(ctx == nullptr);

    // Destroy must tolerate a null pointer.
    psy_context_destroy(nullptr);

    // If the pinned Tier-A primary model is present, exercise the real backend.
    const char* primary_model = "assets/models/qwen2.5-1.5b-instruct-q4_k_m.gguf";
    if (file_exists(primary_model)) {
        test_real_model(primary_model);
    } else {
        std::cout << "real model not present at " << primary_model
                  << "; skipping real-backend smoke test" << std::endl;
    }

    std::cout << "native smoke test passed" << std::endl;
    return 0;
}
