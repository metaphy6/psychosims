#ifndef PSYCHOSIMS_NATIVE_H
#define PSYCHOSIMS_NATIVE_H

#include <stdint.h>
#include <stddef.h>

#ifdef __cplusplus
extern "C" {
#endif

/// Opaque handle to the native inference context.
typedef struct PsyContext PsyContext;

/// Native token id. Negative values signal errors.
typedef int32_t PsyToken;

/// Streaming token callback. Invoked on the dedicated generation thread.
/// [token_text] is UTF-8 and null-terminated. [is_codepoint_complete] is 1 when
/// the emitted bytes form a complete Unicode codepoint.
typedef void (*PsyTokenCallback)(
    const char* token_text,
    int32_t token_id,
    int is_codepoint_complete,
    void* user_data);

/// Returns a health string; used to verify the native library loads.
const char* psy_version(void);

/// Loads a model from [model_path] and returns a context. Returns NULL on
/// failure; details are emitted through the logging shim.
/// [params] is a JSON object string with generation parameters.
PsyContext* psy_context_load(const char* model_path, const char* params);

/// Destroys the inference context and frees all native resources.
void psy_context_destroy(PsyContext* ctx);

/// Tokenizes [text] and writes token ids into [tokens] up to [max_tokens].
/// Returns the number of tokens (may be larger than [max_tokens] if truncated).
/// Returns -1 on error.
int32_t psy_tokenize(
    PsyContext* ctx,
    const char* text,
    PsyToken* tokens,
    int32_t max_tokens);

/// Detokenizes a single token id into a null-terminated UTF-8 string.
/// The returned pointer is valid until the next call on the same context.
const char* psy_detokenize(PsyContext* ctx, PsyToken token);

/// Applies the loaded model's chat template to [conversation_json] and writes
/// the formatted prompt into [out_prompt] up to [out_size]. Returns the number
/// of bytes written (excluding null terminator) or -1 on error.
int32_t psy_apply_chat_template(
    PsyContext* ctx,
    const char* conversation_json,
    char* out_prompt,
    int32_t out_size);

/// Queries model metadata (e.g. context size, vocabulary size) as a JSON string.
/// The returned pointer is valid until the next call on the same context.
const char* psy_model_metadata(PsyContext* ctx);

/// Generates tokens from the prompt in [params_json], streaming each token via
/// [callback]. [user_data] is passed through untouched.
/// Returns 0 on success, 1 if cancelled, -1 on error.
int32_t psy_generate(
    PsyContext* ctx,
    const char* params_json,
    PsyTokenCallback callback,
    void* user_data);

/// Cancels an in-flight generation. Safe to call from another thread.
void psy_cancel(PsyContext* ctx);

/// Resets the KV cache for a new case/session without unloading the model.
void psy_reset_kv(PsyContext* ctx);

/// Returns timing/statistics for the last generation as a JSON string.
///
/// Fields include:
///   - prompt_tokens: number of prompt tokens processed
///   - prompt_eval_ms: milliseconds spent in prompt decode
///   - generated_tokens: number of generated tokens emitted
///   - generation_ms: milliseconds spent in the sampling loop
///   - total_ms: total generation time
///
/// The returned pointer is valid until the next call on the same context.
const char* psy_last_generate_stats(PsyContext* ctx);

#ifdef __cplusplus
}
#endif

#endif // PSYCHOSIMS_NATIVE_H
