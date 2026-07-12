#ifndef PSYCHOSIMS_NATIVE_H
#define PSYCHOSIMS_NATIVE_H

#ifdef __cplusplus
extern "C" {
#endif

/// Opaque handle to the native inference context.
typedef struct PsyContext PsyContext;

/// Returns a health string; used to verify the native library loads.
const char* psy_version(void);

/// Creates a placeholder inference context.
PsyContext* psy_context_create(void);

/// Destroys the inference context.
void psy_context_destroy(PsyContext* ctx);

#ifdef __cplusplus
}
#endif

#endif // PSYCHOSIMS_NATIVE_H
