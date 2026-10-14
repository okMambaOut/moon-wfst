# Third-party notices

## Runtime/toolchain dependency

The root `moon.pkg` imports `moonbitlang/core/debug` for debug representations. This module is provided by the installed MoonBit toolchain; this repository does not vendor or modify it. The locally installed core package includes an Apache License 2.0 `LICENSE` file. Consumers should use the license and notices distributed with their own MoonBit toolchain version.

## Semantic references (no source or data copied)

- [OpenFst](https://github.com/mjansche/openfst) — Apache-2.0. Consulted for WFST terminology and algorithm behavior. No OpenFst source files, test data, or assets are included or translated line-for-line.
- [RustFST](https://github.com/GWBM/RustFST) — dual MIT/Apache-2.0. Consulted for cross-language data-model and API comparison. No RustFST implementation code or data is included.

These references do not imply binary-format compatibility or complete API parity. MoonWFST is an independent MoonBit implementation of the subset documented in the README and `docs/design/semantics.md`. This file records references, not additional dependencies.
