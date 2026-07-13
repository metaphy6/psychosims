#include <cassert>
#include <cstdint>
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

void run_cycle(const char* model_path, int cycle) {
    std::cout << "--- cycle " << cycle << " ---" << std::endl;

    const char* params =
        "{\"n_ctx\":2048,\"n_batch\":512,\"n_threads\":4,"
        "\"correlation_id\":\"san\"}";
    PsyContext* ctx = psy_context_load(model_path, params);
    assert(ctx != nullptr);

    const char* metadata = psy_model_metadata(ctx);
    assert(metadata != nullptr);
    assert(std::strlen(metadata) > 2);

    const char* gen_params =
        "{\"prompt\":\"What is 2+2?\",\"max_tokens\":8,"
        "\"temperature\":0.0,\"top_p\":1.0,\"top_k\":0,"
        "\"correlation_id\":\"san\"}";
    int generated = 0;
    auto callback = [](const char* /*text*/, int32_t /*token_id*/,
                       int /*complete*/, void* user) {
        auto* count = static_cast<int*>(user);
        ++(*count);
    };
    int32_t result = psy_generate(ctx, gen_params, callback, &generated);
    assert(result == 0);
    std::cout << "generated " << generated << " token(s)" << std::endl;

    psy_context_destroy(ctx);
}

} // namespace

int main() {
    const char* primary_model = "assets/models/qwen2.5-1.5b-instruct-q4_k_m.gguf";
    if (!file_exists(primary_model)) {
        std::cout << "real model not present at " << primary_model
                  << "; skipping sanitizer cycles" << std::endl;
        return 0;
    }

    std::cout << "running load->generate->unload cycles under sanitizer"
              << std::endl;
    for (int i = 0; i < 3; ++i) {
        run_cycle(primary_model, i + 1);
    }

    std::cout << "sanitizer cycles passed" << std::endl;
    return 0;
}
