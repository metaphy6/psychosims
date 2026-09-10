#include <atomic>
#include <cassert>
#include <chrono>
#include <cstdint>
#include <cstring>
#include <fstream>
#include <iostream>
#include <string>
#include <thread>

#include "psychosims_native.h"

namespace {

bool file_exists(const char* path) {
    std::ifstream f(path, std::ios::binary);
    return f.good();
}

void run_cycle(const char* model_path, int cycle, bool cancel_midway) {
    std::cout << "--- cycle " << cycle
              << (cancel_midway ? " (cancel)" : "") << " ---" << std::endl;

    const char* params =
        "{\"n_ctx\":2048,\"n_batch\":512,\"n_threads\":4,"
        "\"use_mmap\":true,\"correlation_id\":\"san\"}";
    PsyContext* ctx = psy_context_load(model_path, params);
    assert(ctx != nullptr);

    const char* metadata = psy_model_metadata(ctx);
    assert(metadata != nullptr);
    assert(std::strlen(metadata) > 2);
    assert(std::strstr(metadata, "\"backend\":\"llama.cpp\"") != nullptr);

    const char* gen_params =
        "{\"prompt\":\"What is 2+2?\",\"max_tokens\":32,"
        "\"temperature\":0.0,\"top_p\":1.0,\"top_k\":0,"
        "\"correlation_id\":\"san\"}";
    int generated = 0;
    auto callback = [](const char* /*text*/, int32_t /*token_id*/,
                       int /*complete*/, void* user) {
        auto* count = static_cast<int*>(user);
        ++(*count);
    };

    if (cancel_midway) {
        // Start generation on a separate thread and cancel it partway through
        // to exercise the cancellation path under the sanitizer.
        std::atomic<bool> emitted{false};
        std::atomic<bool> cancelled{false};
        struct CancelState {
            std::atomic<bool>& emitted;
            std::atomic<bool>& cancelled;
        } state{emitted, cancelled};
        auto cancel_callback = [](const char*, int32_t, int, void* user) {
            auto* state = static_cast<CancelState*>(user);
            state->emitted.store(true, std::memory_order_release);
            while (!state->cancelled.load(std::memory_order_acquire)) {
                std::this_thread::yield();
            }
        };
        int32_t result = -1;
        std::thread gen_thread([&]() {
            result = psy_generate(ctx, gen_params, cancel_callback, &state);
            emitted.store(true, std::memory_order_release);
        });
        while (!emitted.load(std::memory_order_acquire)) {
            std::this_thread::yield();
        }
        psy_cancel(ctx);
        cancelled.store(true, std::memory_order_release);
        gen_thread.join();
        assert(result == 1);
        psy_reset_kv(ctx);
        assert(psy_generate(ctx, gen_params, callback, &generated) == 0);
        assert(generated > 0);
        std::cout << "active cancellation and regeneration passed" << std::endl;
    } else {
        int32_t result = psy_generate(ctx, gen_params, callback, &generated);
        assert(result == 0);
        assert(generated > 0);
        std::cout << "generated " << generated << " token(s)" << std::endl;
    }

    psy_context_destroy(ctx);
}

} // namespace

int main(int argc, char** argv) {
    const char* primary_model = argc == 2 ? argv[1] :
        "assets/models/qwen2.5-1.5b-instruct-q4_k_m.gguf";
    if (!file_exists(primary_model)) {
        std::cout << "real model not present at " << primary_model
                  << "; sanitizer acceptance cannot run" << std::endl;
        return 1;
    }

    std::cout << "running load->generate->unload cycles under sanitizer"
              << std::endl;
    for (int i = 0; i < 3; ++i) {
        run_cycle(primary_model, i + 1, false);
    }

    std::cout << "running load->generate->cancel->unload cycle under sanitizer"
              << std::endl;
    run_cycle(primary_model, 4, true);

    std::cout << "sanitizer cycles passed" << std::endl;
    return 0;
}
