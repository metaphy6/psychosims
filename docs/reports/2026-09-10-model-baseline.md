# Three-model local baseline — 2026-09-10

The baseline **does not satisfy model acceptance**. Each model passes deterministic repeated generation, exact-prompt warm-cache latency and token throughput, but fails cold latency and at least one raw dialogue criterion. Passing the measurement test means all samples were collected; it does not mean the product acceptance thresholds passed.

| Model | Input tokens | Load to first token max (s) | Cold assembled first token p95 (s) | Exact-prompt warm first token p95 (ms) | Minimum generated tokens/s | Raw clues | Raw brevity |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| qwen2.5-1.5b | 1090 | 8.148 | 8.224 | 6.139 | 28.51 | 0/20 | 20/20 |
| phi-3.5-mini | 1209 | 29.608 | 31.739 | 6.771 | 10.44 | 20/20 | 0/20 |
| smollm2-1.7b | 1126 | 14.846 | 13.982 | 5.360 | 21.20 | 0/20 | 20/20 |

Predeclared budgets remain unchanged: load to first token at most 8 seconds; first-token p95 at most 2.5 seconds; generated throughput at least 8 tokens/second. All three fail the first two cold budgets. All pass the exact-prompt warm and throughput comparisons. Qwen misses the startup bound by 0.148 seconds on this run; this is a failure, not rounding to a pass.

## Method and retained evidence

- Fresh parent-owned run `w4-parent-model-matrix--20260910T120006Z-769473`, 12:00 UTC start, completed in 42m33s with three measurement tests passing. The earlier interrupted 11:31 run is excluded.
- [Complete structured samples](2026-09-10-model-baseline.json) retain exact model hashes, byte counts, native metadata, host load, all latency/token samples, quality observations and the source log digest.
- Linux x64 development host, Dart 3.10.4/Flutter test runner, 16 logical processors; inference uses four threads, batch 512, f16 KV cache, context 2048, seed 42, greedy generation and output limit 256. Roleplay frame `roleplay-1.0.0`.
- Each model has five load samples, twenty cold/warm generation pairs and three mature planner probes. The twenty quality observations repeat the same greedy prompt and seed; they are **not twenty independent cases**. All twenty pairs produce matching cold/warm bytes. The exact-prompt warm run reuses every input token and evaluates zero new prompt tokens; this is not a real next-turn responsiveness measurement.
- The assembled prompt populates currently implemented state/digest and an overloaded-history truncation case. This does not establish future nine-axis schema coverage, alternate quantization coverage, release performance or minimum-device acceptance.
- Sampled native token counters count actual generated non-EOG tokens; Unicode callback chunks are not treated as tokens. Generation time excludes prefill for throughput; first-token latency separately includes cold prefill and prompt assembly where labeled.
- Process peak RSS is cumulative within the test process: Qwen 2.13 GB; Phi 4.86 GB; Smol still 4.86 GB after Phi. These are process high-water marks, not isolated per-model resident memory or device budgets. Other local work ran concurrently, with host load retained in the samples.

## Dialogue findings and next verification

All three models passed first-person, no frame leak, no list, no advice and non-refusal checks in the twenty repeated raw baseline outputs. Qwen and Smol omitted the literal clue; Phi included it but produced 226 generated tokens and failed brevity. All nine mature planner probes exhausted their three attempts and used a validated fallback. Some mature Smol attempts also failed the no-advice check. Fallback success is not model-generated clue compliance.

Inspection found the prompt invited clue paraphrasing while validation required exact literal tokens. The planner repeated the same prompt/seed/greedy parameters on corrective attempts, and prompt duplication inflated prefill. The next implementation will align the prompt with literal clue validation, make correction attempts distinct and bounded, reduce redundant prompt material, and measure actual changing-next-turn prefix reuse. Re-run the same acceptance thresholds after those changes; keep this baseline unchanged.

Physical C1 memory/thermal/battery, other supported platforms, alternate model quantizations and provider/device integration remain unverified. No cloud deployment, release or distribution occurred.
