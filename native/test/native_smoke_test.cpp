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

int stat(PsyContext* ctx, const char* key) {
    const std::string json = psy_last_generate_stats(ctx);
    const std::string marker = std::string("\"") + key + "\":";
    const size_t start = json.find(marker);
    assert(start != std::string::npos);
    return std::stoi(json.substr(start + marker.size()));
}

void test_real_model(const char* model_path) {
    std::cout << "testing real model: " << model_path << std::endl;

    const char* params =
        "{\"n_ctx\":512,\"n_batch\":64,\"n_threads\":2,"
        "\"correlation_id\":\"smoke\"}";
    PsyContext* ctx = psy_context_load(model_path, params);
    assert(ctx != nullptr);

    const char* metadata = psy_model_metadata(ctx);
    assert(metadata != nullptr);
    assert(std::strlen(metadata) > 2);
    assert(std::strstr(metadata, "\"backend\":\"llama.cpp\"") != nullptr);
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
        "\"temperature\":0.0,\"top_p\":1.0,\"top_k\":0,\"repetition_penalty\":1.2,"
        "\"correlation_id\":\"smoke\"}";
    std::string generated;
    auto callback = [](const char* text, int32_t /*token_id*/, int /*complete*/, void* user) {
        static_cast<std::string*>(user)->append(text);
    };
    // Rejected requests must not discard the prompt or sample missing logits.
    assert(psy_generate(ctx, "{\"prompt\":\"hello\",\"max_tokens\":512}",
                        callback, &generated) == -2);
    assert(psy_generate(ctx, "{\"prompt\":\"hello\",\"max_tokens\":2147483647}",
                        callback, &generated) == -2);
    std::string oversized_prompt;
    for (int i = 0; i < 600; ++i) oversized_prompt += "hello ";
    const std::string oversized_params =
        "{\"prompt\":\"" + oversized_prompt + "\",\"max_tokens\":1}";
    assert(psy_generate(ctx, oversized_params.c_str(), callback, &generated) == -2);
    assert(generated.empty());
    for (const char* value : {"-1", "2.1", "1e39", "null", "true", "\"NaN\"", "1junk"}) {
        const std::string invalid = "{\"prompt\":\"hello\",\"max_tokens\":1,\"repetition_penalty\":" + std::string(value) + "}";
        assert(psy_generate(ctx, invalid.c_str(), callback, &generated) == -1);
    }
    assert(generated.empty());
    // The same context remains usable after every rejected request.
    int32_t result = psy_generate(ctx, gen_params, callback, &generated);
    assert(result == 0);
    assert(!generated.empty());
    assert(std::strstr(psy_last_generate_stats(ctx), "\"generated_tokens\":0") == nullptr);
    assert(stat(ctx, "prompt_tokens") == n_tokens);
    assert(stat(ctx, "evaluated_prompt_tokens") == n_tokens);
    assert(stat(ctx, "reused_prompt_tokens") == 0);
    std::cout << "generated: " << generated << std::endl;

    // Repeating a prompt must use its exact cached logits and KV rows, never
    // logits left over by the response or a differently batched final row.
    std::string repeated;
    assert(psy_generate(ctx, gen_params, callback, &repeated) == 0);
    assert(repeated == generated);
    assert(stat(ctx, "prompt_tokens") == n_tokens);
    assert(stat(ctx, "evaluated_prompt_tokens") == 0);
    assert(stat(ctx, "reused_prompt_tokens") == n_tokens);

    // A partially shared prompt reports only its suffix as evaluated.
    PsyToken changed_tokens[128];
    const int32_t changed_count = psy_tokenize(ctx, "What is 2+3?", changed_tokens, 128);
    int common = 0;
    while (common < n_tokens && common < changed_count &&
           tokens[common] == changed_tokens[common]) ++common;
    assert(common > 0 && common < changed_count);
    std::string changed;
    assert(psy_generate(ctx, "{\"prompt\":\"What is 2+3?\",\"max_tokens\":4,"
        "\"temperature\":0,\"top_p\":1,\"top_k\":0}", callback, &changed) == 0);
    assert(stat(ctx, "prompt_tokens") == changed_count);
    assert(stat(ctx, "evaluated_prompt_tokens") == changed_count - common);
    assert(stat(ctx, "reused_prompt_tokens") == common);
    psy_reset_kv(ctx);
    std::string after_reset;
    assert(psy_generate(ctx, gen_params, callback, &after_reset) == 0);
    assert(after_reset == generated);
    assert(stat(ctx, "evaluated_prompt_tokens") == n_tokens);
    assert(stat(ctx, "reused_prompt_tokens") == 0);

    // Sampler transforms must not mutate the cached prompt-logit snapshot.
    const char* stochastic_params =
        "{\"prompt\":\"What is 2+2?\",\"max_tokens\":16,"
        "\"temperature\":0.7,\"top_p\":0.9,\"top_k\":40,\"seed\":123,\"repetition_penalty\":1.2}";
    std::string sampled_a, sampled_b, sampled_c;
    assert(psy_generate(ctx, stochastic_params, callback, &sampled_a) == 0);
    assert(psy_generate(ctx, stochastic_params, callback, &sampled_b) == 0);
    assert(sampled_a == sampled_b);
    assert(stat(ctx, "evaluated_prompt_tokens") == 0);
    psy_reset_kv(ctx);
    assert(psy_generate(ctx, stochastic_params, callback, &sampled_c) == 0);
    assert(sampled_c == sampled_a);
    std::string greedy_after_sampling;
    assert(psy_generate(ctx, gen_params, callback, &greedy_after_sampling) == 0);
    assert(greedy_after_sampling == generated);

    auto cancel_real = [](const char*, int32_t, int, void* user) {
        psy_cancel(static_cast<PsyContext*>(user));
    };
    assert(psy_generate(ctx, gen_params, cancel_real, ctx) == 1);
    assert(stat(ctx, "generated_tokens") > 0 && stat(ctx, "generated_tokens") <= 16);
    std::string after_cancel;
    assert(psy_generate(ctx, gen_params, callback, &after_cancel) == 0);
    assert(after_cancel == generated);
    assert(stat(ctx, "evaluated_prompt_tokens") == n_tokens);
    assert(stat(ctx, "reused_prompt_tokens") == 0);

    // A shorter prefix is a different prompt; its logits are not the longer
    // prompt's cached end logits even when every new input token matches.
    const char* shortened_params =
        "{\"prompt\":\"What is\",\"max_tokens\":16,\"temperature\":0,\"top_p\":1,\"top_k\":0}";
    std::string shortened_warm, shortened_cold;
    assert(psy_generate(ctx, shortened_params, callback, &shortened_warm) == 0);
    assert(stat(ctx, "evaluated_prompt_tokens") > 0);
    psy_reset_kv(ctx);
    assert(psy_generate(ctx, shortened_params, callback, &shortened_cold) == 0);
    assert(shortened_warm == shortened_cold);

    psy_context_destroy(ctx);
}

} // namespace

int main(int argc, char** argv) {
    const char* version = psy_version();
    assert(std::strcmp(version, "psychosims-native-0.1.0") == 0);

    // Loading with an empty path must fail gracefully.
    PsyContext* ctx = psy_context_load("", "{}");
    assert(ctx == nullptr);

    // A real-model load failure must never turn into successful stub inference.
    ctx = psy_context_load("/missing/psychosims-regression-model.gguf", "{}");
    assert(ctx == nullptr);

    ctx = psy_context_load("/missing/model.gguf", "{\"backend\":\"invalid\"}");
    assert(ctx == nullptr);
    ctx = psy_context_load("development", "{\"backend\":\"stub\",\"n_batch\":0}");
    assert(ctx == nullptr);
    ctx = psy_context_load("development", "{\"backend\":\"stub\",\"n_ctx\":512}");
    assert(ctx != nullptr);
    assert(std::strstr(psy_model_metadata(ctx), "\"backend\":\"stub\"") != nullptr);
    int callbacks = 0;
    auto count = [](const char*, int32_t, int, void* user) {
        ++*static_cast<int*>(user);
    };
    assert(psy_generate(ctx, "{\"prompt\":\"hello\",\"max_tokens\":512}",
                        count, &callbacks) == -2);
    assert(callbacks == 0);
    for (const char* value : {"-1", "2.1", "1e39", "null", "true", "\"NaN\"", "1junk"}) {
        const std::string invalid = "{\"max_tokens\":1,\"repetition_penalty\":" + std::string(value) + "}";
        assert(psy_generate(ctx, invalid.c_str(), count, &callbacks) == -1);
    }
    assert(callbacks == 0);
    assert(psy_generate(ctx, "{\"max_tokens\":3,\"repetition_penalty\":0}", count, &callbacks) == 0);
    assert(callbacks == 3);
    assert(std::strstr(psy_last_generate_stats(ctx), "\"generated_tokens\":3") != nullptr);
    auto cancel = [](const char*, int32_t, int, void* user) {
        psy_cancel(static_cast<PsyContext*>(user));
    };
    assert(psy_generate(ctx, "{\"max_tokens\":100}", cancel, ctx) == 1);
    psy_reset_kv(ctx);
    callbacks = 0;
    assert(psy_generate(ctx, "{\"max_tokens\":3}", count, &callbacks) == 0);
    assert(callbacks == 3);
    psy_context_destroy(ctx);

    // Destroy must tolerate a null pointer.
    psy_context_destroy(nullptr);

    if (argc == 2 && std::strcmp(argv[1], "--contracts-only") == 0) {
        std::cout << "native contracts passed (explicit stub; no model acceptance)" << std::endl;
        return 0;
    }
    const char* primary_model = argc == 2 ? argv[1] :
        "assets/models/qwen2.5-1.5b-instruct-q4_k_m.gguf";
    if (!file_exists(primary_model)) {
        std::cerr << "Required real model unavailable: " << primary_model << std::endl;
        return 1;
    }
    test_real_model(primary_model);
    std::cout << "native real-model smoke passed" << std::endl;
    return 0;
}
