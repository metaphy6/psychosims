// White-box contract tests exercise the same stream and sampler used by the shim.
// The shared-library ABI and real-model cache paths remain covered by smoke tests.
#include "../src/psychosims_native.cpp"
#include <cassert>
#include <iostream>

struct StreamCapture {
    std::string bytes;
    int callbacks = 0;
    int complete = 0;
};
static void capture(const char* text, int32_t, int complete, void* data) {
    auto& state = *static_cast<StreamCapture*>(data);
    state.bytes += text;
    ++state.callbacks;
    state.complete += complete;
}
static void test_sample_counts() {
    GenerateStats stats;
    GenerationOutput output{stats};
    StreamCapture state;
    output.feed("\xE2", 1, capture, &state);
    output.feed("\x82", 2, capture, &state);
    assert(state.callbacks == 0);
    assert(stats.generated_tokens == 2);
    output.feed("\xAC", 3, capture, &state);
    output.flush(3, capture, &state);
    assert(state.bytes == "\xE2\x82\xAC");
    assert(state.callbacks == 1 && state.complete == 1);
    assert(stats.generated_tokens == 3);
    PsyContext ctx;
    ctx.last_generate_stats = stats;
    assert(std::strstr(psy_last_generate_stats(&ctx), "\"generated_tokens\":3") != nullptr);

    // A token limit or stop may leave a partial code point. Flushing is an
    // output callback, not another sampled token; empty pieces still count.
    GenerateStats limited_stats;
    GenerationOutput limited{limited_stats};
    StreamCapture partial;
    limited.feed("\xE2", 1, capture, &partial);
    limited.feed("\x82", 2, capture, &partial);
    limited.flush(2, capture, &partial);
    assert(limited_stats.generated_tokens == 2);
    assert(partial.callbacks == 1 && partial.complete == 0);
    assert(partial.bytes == "\xE2\x82");
    limited.feed("", 4, capture, &partial);
    assert(limited_stats.generated_tokens == 3);
}
static int choose(llama_sampler* sampler, float first, float second) {
    llama_token_data data[] = {{7, first, 0}, {8, second, 0}};
    llama_token_data_array candidates = {data, 2, -1, false};
    llama_sampler_apply(sampler, &candidates);
    assert(candidates.selected >= 0);
    return candidates.data[candidates.selected].id;
}
static void test_repetition_penalty() {
    auto make = [](float penalty, const std::vector<llama_token>& prompt) {
        return create_sampler(nullptr, 10, prompt, 0, 1, 0, 42, "", penalty);
    };
    auto* neutral = make(1.0f, {7});
    assert(choose(neutral, 10, 9) == 7);
    llama_sampler_free(neutral);
    auto* penalty = make(2.0f, {7});
    assert(choose(penalty, 10, 9) == 8);
    assert(choose(penalty, -1, -1.5f) == 8);
    llama_sampler_accept(penalty, 8);
    assert(choose(penalty, 10, 9) == 7);
    llama_sampler_free(penalty);
    auto* stochastic = create_sampler(nullptr, 10, {7}, 1, 1, 1, 42, "", 2);
    assert(choose(stochastic, 10, 9) == 8);
    llama_sampler_free(stochastic);
    // Prompt history is bounded; old prompt rows do not penalize forever.
    std::vector<llama_token> prompt{7};
    prompt.insert(prompt.end(), 64, 8);
    penalty = make(2.0f, prompt);
    assert(choose(penalty, 9, 10) == 7);
    llama_sampler_free(penalty);
    // A new generation starts from prompt history, not previous output state.
    penalty = make(2.0f, {7});
    assert(choose(penalty, 10, 9) == 8);
    llama_sampler_free(penalty);
}
int main() {
    test_sample_counts();
    test_repetition_penalty();
    std::cout << "native sampled-token and repetition-penalty contracts passed\n";
}
