# AI use disclosure

AI assistance was used during project planning, implementation, debugging, test drafting, example construction, and documentation. The participant selected the WFST direction and provided the project constraints. The participant remains responsible for reviewing the code, API contracts, provenance, licensing, and final submission claims.

Changes were checked with the locally available MoonBit toolchain where possible. Native-target results are reported only when the corresponding command succeeds; a CI configuration is not described as a completed CI run. Tests and examples construct their own small graphs in source code.

The OCR example uses a six-cell synthetic candidate lattice written directly in the example source. Its selected string (`NB0158`) and total cost (`6`) are deterministic fixture outputs, not real OCR data, generated training data, production measurements, or a benchmark. No OpenFst or RustFST source code was copied; those projects were consulted only for terminology and behavior/API comparison as described in `THIRD-PARTY-NOTICES.md`.
