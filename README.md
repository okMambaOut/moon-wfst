# MoonWFST

MoonWFST is a reusable MoonBit library for weighted finite-state transducers (WFSTs). A transducer is a finite graph whose arcs carry input and output labels plus weights interpreted by a caller-supplied semiring. The library provides algorithms shared by speech-lattice decoding, morphological analysis, OCR post-processing, tokenization, and other finite-state pipelines; it is not a recognizer or domain-specific model.

**Status:** version `0.1.0` is an explicit, bounded API subset. The package is not published to MoonCakes and has no GitHub Release. Example outputs below come from source-defined synthetic graphs, not production data or benchmarks.

## Capabilities

- Validated graph construction with dense state IDs, copy-on-build snapshots, explicit final weights, and epsilon labels distinct from empty symbols.
- Caller-defined semirings, plus Boolean and bounded non-negative tropical weights.
- Input/output projection, inversion, weighted union and concatenation, and epsilon-free composition.
- Structural reachability, coaccessibility, accepting-core trimming, deterministic topological order, incoming-arc inspection, and graph metrics.
- Exact input/output token-pair membership, least-cost accepting paths, and bounded k-best paths for DAGs.
- Generic semiring forward/backward aggregation and total accepting weight on DAGs.
- Explicit errors for invalid states, unsupported epsilon composition, negative Dijkstra weights, cyclic DAG algorithms, and invalid path limits.

## Runnable examples

Use the installed MoonBit toolchain from the repository root:

```powershell
moon run --target wasm-gc examples/speech_lattice
moon run --target wasm-gc examples/morphology
moon run --target wasm-gc examples/ocr_constraints
```

| Example | Workflow | Deterministic fixture result |
| --- | --- | --- |
| Speech lattice | Compose a recognizer-style lattice with a lexicon and select the least-cost path. | `cat`, total cost `6`. |
| Morphology | Rank alternative analyses for an irregular surface form. | `go+PAST`, cost `1`. |
| OCR constraints | Rescore a six-cell synthetic character lattice against a format transducer and glyph-confusion costs. | `NB0158`, total cost `6`. |

The OCR example does not process pixels, invoke an OCR model, verify checksums, or represent measured OCR accuracy. All three programs are runnable source fixtures under [`examples`](examples).

## Use as a library

The examples are complete MoonBit packages and show graph construction, composition, path ranking, and result extraction. A consumer package imports the module as `@wfst` and builds a graph with `transducer_builder`, `add_state`, `set_start`, `set_final`, and `add_arc`; see [`examples/speech_lattice/main.mbt`](examples/speech_lattice/main.mbt) for an end-to-end API use. The current module name is `okMambaOut/moon-wfst`. Until a public package is published, there is no `moon add` installation command; use a local checkout/workspace dependency for development.

## Contracts and limits

- **Semirings:** the caller supplies zero, one, alternative addition, and path extension. The library cannot prove algebraic laws or compatibility between two supplied semirings; union and concatenation use the left operand's operations for synthetic arcs.
- **Composition:** operands must be epsilon-free and use compatible semirings with **commutative multiplication**. Arc-pair weight interleaving is not general non-commutative composition. An epsilon on either side returns `UnsupportedEpsilonComposition`; no epsilon filter is implied.
- **Shortest path:** Dijkstra validates all arc and final weights as non-negative, including unreachable values. Comparison monotonicity and algebraic consistency are caller obligations.
- **k-best:** `shortest_paths_in_dag` requires the whole graph to be acyclic. It permits suitable negative edge values on a DAG, preserves parallel arcs as distinct derivations, and stores explicit path prefixes; it is intended for bounded `k` and moderate graphs.
- **Membership:** `accepts_pair` answers support-graph membership under a caller-supplied zero predicate. It does not test aggregate nonzero weight (cancellation/zero divisors/saturation can differ), aggregate weights, or return a witness and uses product-space memory proportional to states × input positions × output positions.
- **Forward/backward aggregation:** `forward_weights_in_dag`, `backward_weights_in_dag`, and `total_weight_in_dag` aggregate paths with the graph semiring. They reject cycles anywhere in the graph; no infinite-series closure is inferred. Their algebraic results depend on the caller supplying valid semiring operations.
- **Not included:** epsilon-filtered composition, weighted epsilon closure/removal, determinization, minimization, OpenFst binary import/export, model training, tokenization policy, image recognition, and domain-specific validation.

Detailed ordering, structural-vs-weighted behavior, and error semantics are in [`docs/design/semantics.md`](docs/design/semantics.md). The bounded selection review is in [`docs/competition/duplicate-check.md`](docs/competition/duplicate-check.md).

## Build and verify

```powershell
moon info
moon fmt --check
moon check --target wasm-gc --deny-warn
moon check --target wasm --deny-warn
moon check --target js --deny-warn
moon check --target native --deny-warn
moon build --target wasm-gc --deny-warn
moon test --target wasm-gc --deny-warn
```

On this workstation with MoonBit `0.1.20261012` (verified 2026-10-14), the wasm-gc, WebAssembly, and JavaScript test runs each passed **47/47 tests**. Strict checks passed for `wasm-gc`, `wasm`, `js`, and `native`; builds passed for `wasm-gc`, `wasm`, and `js`. The `native` build could not run because this Windows machine has no `cc`, `gcc`, or `clang`; the CI job requests that build on Ubuntu. All three examples ran on `wasm-gc` and printed the fixture outputs above. The GitHub Actions workflow checks and builds all four targets, runs tests on all four targets and the three wasm-gc examples. A configured workflow is not evidence of a completed remote CI run.

The root library package contains **1,604 physical lines** of non-test `.mbt` implementation (blank lines included; tests, examples, generated interfaces, and build output excluded). These are scope and verification facts, not performance claims.

## License, attribution, and AI use

MoonWFST is licensed under Apache-2.0; see [`LICENSE`](LICENSE) and [`NOTICE`](NOTICE). The only imported MoonBit package is `moonbitlang/core/debug`, supplied by the MoonBit toolchain and not vendored here. OpenFst and RustFST informed terminology and semantic/API comparison only; no upstream source or data is included. Attribution and scope are recorded in [`THIRD-PARTY-NOTICES.md`](THIRD-PARTY-NOTICES.md). AI assistance is disclosed in [`AI-USE.md`](AI-USE.md).

## Security and resource model

Inputs are in-memory graphs, not a wire format. There is no network, filesystem, dynamic loading, or automatic parsing in the library. Untrusted callers must cap their own state/arc counts, token lengths, and requested `k` before construction and algorithms. Composition can reach the product of both state sets and currently finds state pairs by linear search. Dijkstra selects frontier states by a linear scan rather than a heap. Membership allocates a dense state/position product, and k-best explicitly copies prefixes. These are not bounded-time service guarantees; see [resource notes](docs/design/resources.md).

## Project history

Development continues from the preserved MoonWFST history. The first 23 commits retain their original `yujieMamba` author attribution; subsequent takeover commits use the participant-selected local `okmanba` name and the `okMambaOut` GitHub noreply email. Repository ownership and commit authorship are distinct facts. Neither history rewriting nor a claim that these accounts identify the same person is made.
