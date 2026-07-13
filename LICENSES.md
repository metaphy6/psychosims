# Third-Party Licenses & Model Attribution

## Large Language Models

### Qwen2.5-1.5B-Instruct
- **Model**: Qwen2.5-1.5B-Instruct (Q4_K_M quantization)
- **Source**: [Alibaba Qwen](https://github.com/QwenLM/Qwen2.5)
- **License**: Qwen Research License Agreement + CC-BY-NC 4.0
- **Attribution**: © 2024 Alibaba Group
- **Usage**: Phase 1 PoC — primary model for psychology simulation inference
- **File**: `app/assets/models/qwen2.5-1.5b-instruct-q4_k_m.gguf`

### Phi-3.5-Mini-Instruct
- **Model**: Phi-3.5-Mini-Instruct (Q4_K_M quantization)
- **Source**: [Microsoft Phi-3.5](https://huggingface.co/microsoft/Phi-3.5-mini-instruct)
- **License**: MIT
- **Attribution**: © 2024 Microsoft Corporation
- **Usage**: Phase 1 PoC — comparator model for quality benchmarking
- **File**: `app/assets/models/Phi-3.5-mini-instruct-Q4_K_M.gguf`
- **Note**: Model tuning deferred to Phase 2 (batch initialization)

## Core Dependencies

### llama.cpp
- **Source**: [ggerganov/llama.cpp](https://github.com/ggerganov/llama.cpp)
- **License**: MIT
- **Attribution**: © llama.cpp contributors
- **Usage**: On-device LLM inference engine (C++ backend)
- **Version**: Pinned commit in `native/third_party/llama.cpp`

### Flutter & Dart
- **Source**: [flutter/flutter](https://github.com/flutter/flutter)
- **License**: BSD 3-Clause
- **Attribution**: © Google
- **Usage**: UI framework and Dart runtime

---

## Compliance Notes

1. **Model Quantization**: Qwen and Phi models are quantized using llama.cpp (GGUF format), 
   preserving original licenses.

2. **Deterministic Simulation**: Models are used for deterministic, seeded psychology case 
   simulation, not general-purpose generation. All output is subject to prototype safeguards 
   (injection isolation, token budgeting, deterministic core).

3. **Academic Use**: This software is developed for research and educational purposes 
   (learning psychology simulation techniques).

4. **Attribution in Binaries**: Model names and version info are embedded in build metadata 
   and discoverable via `InferenceService.metadata()`.

---

**Generated**: 2026-07-13  
**Phase**: 1 (PoC)
