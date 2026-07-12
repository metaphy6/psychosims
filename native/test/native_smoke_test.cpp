#include <cassert>
#include <cstring>
#include <iostream>

#include "psychosims_native.h"

int main() {
    const char* version = psy_version();
    assert(std::strcmp(version, "psychosims-native-0.1.0") == 0);

    PsyContext* ctx = psy_context_create();
    assert(ctx != nullptr);
    psy_context_destroy(ctx);

    std::cout << "native smoke test passed" << std::endl;
    return 0;
}
