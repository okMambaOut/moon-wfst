# Resource and trust boundary

The library accepts caller-built finite graphs and user-defined weight functions. It performs state-ID validation, explicit epsilon-policy rejection, cycle checks where required, and typed errors for invalid path limits and invalid tropical costs. It does not validate arbitrary algebraic laws, compare two semiring closures, catch arbitrary caller callback failures, deep-copy mutable weight payloads, or promise cancellation of long operations.

## Complexity decisions

- Graph construction and snapshots copy stored arrays. Applications should enforce state/arc ceilings before accepting user input.
- Epsilon-free composition explores reachable state pairs and joins every outgoing arc pair at each pair of states. There can be `V_left × V_right` pairs; the current pair lookup is a linear scan of discovered pairs. This is intentionally simple, not OpenFst-scale optimization.
- Structural traversals and topological ordering use adjacency scans; disconnected cycles reject DAG algorithms even if they cannot contribute an accepting path.
- Dijkstra uses an array-based minimum selection, with quadratic state-selection work in the worst case. Every arc and final weight is checked with the caller's nonnegative predicate, including unreachable values.
- `accepts_pair` uses a dense product of graph states and both token-position ranges. The caller must cap each dimension before allocation; the public API does not expose a memory budget.
- DAG k-best keeps up to `k` explicit path prefixes per state. Each prefix stores its state/arc trace, so long paths and large `k` increase both copying and memory use. This is derivation ranking, not deduplication of identical output strings.
- Forward/backward DAG weights aggregate alternatives without enumerating complete paths, but weight arithmetic cost is chosen by the caller. Numeric overflow behavior of a custom semiring is not controlled by MoonWFST.

## Operational advice

Validate workload sizes at application boundaries, use immutable weights and pure operations, and isolate untrusted workloads in a cancellable worker or separate process. Bounded tropical arithmetic saturates to infinity; support-graph membership does not imply an unsaturated accepting weight. The built-in tests and examples are small deterministic fixtures, not load tests, security certification, probability normalization, or measured recognition quality.
