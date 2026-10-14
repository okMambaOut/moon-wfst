# Changelog

All notable project changes are recorded here. Release artifact availability is recorded by GitHub Releases and the public MoonCakes registry.

## 0.1.0 — 2026-10-14

- Define the generic weighted-transducer graph, typed labels and explicit epsilon, semiring operations, validated builder snapshots, and bounded tropical weights.
- Add projection, inversion, epsilon inspection, epsilon-free composition, weighted union and concatenation, relation membership, graph analysis/trimming, topological ordering, shortest accepting paths, and bounded DAG k-best paths.
- Add DAG forward/backward and total semiring aggregation, including order-sensitive matrix and cancellation-boundary tests.
- Add runnable speech-lattice/lexicon, morphology-ranking, and synthetic OCR-constraint examples.
- Document algorithm contracts, unsupported behavior, source references, AI assistance, Apache-2.0 licensing, and third-party attribution.
- Add CI configuration for formatting, multi-target check/build, four-target tests, and the three wasm-gc examples.

- Validate 47 tests on wasm-gc, wasm, and JavaScript locally with Moon 0.1.20261012; verify all four targets, including native, and three runnable examples in actual GitHub Actions.
