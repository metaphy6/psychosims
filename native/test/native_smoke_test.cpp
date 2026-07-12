#include <cassert>
#include <cstring>
#include <iostream>

#include "psychosims_native.h"

int main() {
    const char* version = psy_version();
    assert(std::strcmp(version, "psychosims-native-0.1.0") == 0);

    // Loading with an empty path must fail gracefully.
    PsyContext* ctx = psy_context_load("", "{}");
    assert(ctx == nullptr);

    // Destroy must tolerate a null pointer.
    psy_context_destroy(nullptr);

    std::cout << "native smoke test passed" << std::endl;
    return 0;
}
