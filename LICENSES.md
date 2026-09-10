# Third-party licenses and model attribution

Current local implementation review: 2026-09-10. This project is unreleased.

## Models

| Exact candidate | License | Attribution and primary evidence | Bundled text |
| --- | --- | --- | --- |
| Qwen2.5-1.5B-Instruct | Apache-2.0 | Alibaba Cloud; [exact 1.5B model license](https://huggingface.co/Qwen/Qwen2.5-1.5B-Instruct/blob/main/LICENSE) | [QWEN2.5_LICENSE](app/assets/licenses/QWEN2.5_LICENSE) |
| Phi-3.5-mini-instruct | MIT | Microsoft Corporation; [model license](https://huggingface.co/microsoft/Phi-3.5-mini-instruct/blob/main/LICENSE) | [PHI3.5_LICENSE](app/assets/licenses/PHI3.5_LICENSE) |
| SmolLM2-1.7B-Instruct | Apache-2.0 | Hugging Face; [official model card and license declaration](https://huggingface.co/HuggingFaceTB/SmolLM2-1.7B-Instruct/blob/main/README.md?code=true) | [SMOLLM2_LICENSE](app/assets/licenses/SMOLLM2_LICENSE) |

The previous Qwen Research License / CC-BY-NC attribution was incorrect for this
exact 1.5B candidate. Licenses differ across model families and sizes; this table
does not approve other variants. SmolLM2's official model card declares Apache-2.0;
the local bundle contains that standard text. Preserve upstream copyright and
NOTICE material when preparing a distributable artifact.

All three current artifacts use Q4_K_M. Download URLs and verified hashes are
owned by [config](config/lib/src/loader.dart); native source and patches are
recorded in [PINNED_BUILDS](native/PINNED_BUILDS.md). Model fetch and inference
share the app's model cache. Repository-local acceptance weights under
`assets/models/` are test inputs, not Flutter-bundled model assets.

## Software dependencies

The generated [CycloneDX inventory](docs/reports/dependency-inventory.cdx.json)
records resolved Dart packages, Go modules, pinned llama.cpp, SDK notice files,
and model license texts, with dependency edges and input/license fingerprints.
It distinguishes workspace code and SDK packages from Pub packages. It does
not pretend to enumerate every dependency inside a future platform binary.

- llama.cpp is MIT licensed; retain its main license and vendored library notices.
- Flutter and Dart use BSD-family terms and include additional third-party
  notices in their SDK/engine bundles. Preserve the complete notice bundles.
- GTK 2.2.0, pulled in by Linux app-links support, is MPL-2.0. The exact version
  and license hash are recorded in [license_policy.json](scripts/license_policy.json).
  Preserve its notices and provide the covered source, including modifications,
  when distributing a future build. [Mozilla's MPL guidance](https://www.mozilla.org/en-US/MPL/2.0/FAQ/)
  describes the source-availability boundary. No distribution has occurred.

The license policy has exact-component, exact-file exceptions for GTK and the
Flutter engine notice bundle. It does not globally allow MPL or unknown licenses.
These local development records do not close platform distribution acceptance.

## Reproducing the checks

1. Run `scripts/bootstrap.sh --tools-only` to install project-local pinned scanners.
2. Run `make security.dependencies` to enforce lockfiles, compare the inventory,
   classify installed license text and scan package versions/native commit IDs.
3. After an intentional dependency update, run `scripts/sbom.sh --write`, inspect
   the complete inventory and license-policy diff, then repeat the gate.

Never refresh an inventory merely to hide an unexpected license or resolution.
The base-model policy remains Apache-2.0/MIT only. A release still requires
complete in-app notices, covered-source delivery where required, model artifact
provenance and the inventories produced by each target-platform build.
