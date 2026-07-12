#include "psychosims_native.h"

const char* psy_version(void) {
    return "psychosims-native-0.1.0";
}

struct PsyContext {
    int dummy;
};

PsyContext* psy_context_create(void) {
    return new PsyContext{0};
}

void psy_context_destroy(PsyContext* ctx) {
    delete ctx;
}
