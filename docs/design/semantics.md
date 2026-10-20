# Data model and algorithm contracts

MoonWFST models a finite directed graph as a weighted relation. A state is an integer local to one transducer. Every arc has an input label, output label, destination, and weight. `Epsilon` is represented explicitly and is distinct from a symbol whose text happens to be empty. The start state is optional during construction so an empty or acceptor-only graph can be represented; algorithms that require a start state return a typed error. Final weights are attached to states, not encoded as synthetic arcs.

## Semiring contract

A caller-provided semiring supplies additive zero, multiplicative one, alternative-path addition (`plus`), and sequential path extension (`times`). The library cannot prove the semiring axioms. Callers must ensure the operations are closed, associative, distributive, and use the supplied identities consistently. DAG aggregation and concatenation preserve sequential multiplication order, including for non-commutative semirings. Composition has the stronger requirement that multiplication is commutative: it interleaves weights from two paths, so `(a1 × b1) × (a2 × b2)` must agree with `(a1 × a2) × (b1 × b2)`. The library cannot verify this law. Boolean and bounded tropical weights satisfy it.

The Boolean semiring is provided for reachability-style relations. A bounded non-negative tropical semiring is provided for least-cost examples. Its finite costs are non-negative machine integers; addition of path costs saturates to tropical infinity at the documented bound, so overflow never wraps into a cheaper path.

## Transformations

- Input projection copies each input label to the output side.
- Output projection copies each output label to the input side.
- Inversion swaps the two labels on every arc.
- These transformations preserve topology, weights, start state, and final weights.
- Composition joins a left arc's output symbol to a right arc's input symbol and multiplies each matched pair of arc weights, then multiplies the terminal weights. Compatible semirings with commutative multiplication are required. The first implementation is explicitly epsilon-free: if either graph contains epsilon on either side, composition returns `UnsupportedEpsilonComposition`. No epsilon filter is implied.

## Shortest accepting path

The ordered-weight API is only valid when its comparison is consistent with the semiring's choice operation, path extension is monotone and nondecreasing (extending a path cannot improve its weight), and every arc and terminal weight accepted by Dijkstra is non-negative in the supplied order. The library checks the caller-provided non-negative predicate on actual arc/final weights; it cannot prove the algebraic laws. Ties are resolved by stable state and arc insertion order. A result carries the accepting state sequence, traversed arcs, and total weight including the final weight. Unreachable accepting states produce `NoAcceptingPath`, not an infinity-valued pseudo-path.

## Resource and failure behavior

State identifiers are dense and zero-based. Construction rejects negative or out-of-range state references before a graph is returned. Composition visits only reachable state pairs, but this may still grow as the product of the two state sets. The API has no hidden global state, file/network access, or implicit alphabet normalization.

## Structural graph analysis

`reachable_states` traverses from the declared start across every stored arc. `coaccessible_states` traverses the reverse graph from every state that has an explicitly stored final weight. Both are structural: arc labels and weights do not affect these sets, and an explicit semiring-zero final weight still marks a structurally final state. A missing start makes every state unreachable, but does not change coaccessibility.

`trim` retains the intersection of those sets, which removes states unable to participate in any structurally start-to-final path. It preserves original state order while compacting identifiers and returns an original-to-new mapping. If no structurally accepting core exists, its graph has zero states and no start. Since arbitrary semiring values have no required equality operation, trim intentionally does not remove zero-weight arcs or zero-weight finals; callers needing semiring-aware pruning must supply that policy themselves.

## Language combinators

`union_transducers` adds a fresh epsilon-only branch state. Each present operand start is reached with semiring one; operand arcs and final weights are copied unchanged. A missing start contributes no branch. `concatenate_transducers` keeps the left start, clears each left final, and connects each former left final to the right start by an epsilon/epsilon arc carrying the former final weight. This preserves the path product order and supports an empty accepted string on either side. If the right graph has no start, left acceptance is cleared.

These constructors use the left operand's semiring for synthetic branch arcs. The type system does not establish that two caller-provided semiring values are compatible; callers must pass graphs whose weight values share the same algebra and whose operations have compatible meanings. Both combinators preserve the operand state order within each copied block and do not attempt epsilon removal or minimization.

## Acyclic ordering

`topological_order` applies Kahn's algorithm to every graph state, not only states reachable from the declared start. Parallel arcs contribute independently to indegree and are decremented independently. The result is deterministic for an unchanged graph: initial zero-indegree states are queued in ascending identifier order, then newly ready states are appended in outgoing-arc insertion order. Cycles, including self-loops and disconnected cyclic components, return `GraphHasCycle`; an empty graph returns an empty order.

## Exact relation membership

`accepts_pair` explores the finite product `(graph state, input position, output position)` and returns whether a path consumes both token arrays completely and ends at an explicit final state. Each side consumes independently: epsilon on one side does not imply epsilon on the other. A caller-supplied `is_zero` predicate excludes semiring-zero arcs and finals; all other weight values are ignored, so this query recognizes support-graph membership but does not aggregate weights or return a witness. It does not test whether the aggregate weighted relation is nonzero: cancellation between alternative paths, zero divisors, or saturating products may make an accepted pair have aggregate weight zero. The predicate must be deterministic and side-effect free. The implementation memoizes the product space, using `O(V × (|input| + 1) × (|output| + 1))` memory, and terminates even with epsilon/epsilon cycles. A graph without a start returns `NoStartState`.

## Multiple best paths on DAGs

`shortest_paths_in_dag` retains at most `k` partial traces per state, extends them in topological order, applies terminal weights only at accepting states, and returns fewer than `k` paths when the graph has fewer accepting derivations. Nonpositive `k` returns `InvalidPathLimit`; any cycle anywhere in the graph returns `GraphHasCycle` before results are produced. Unlike Dijkstra, negative finite edge values are permitted because the graph is acyclic. The comparison must still be compatible with semiring extension; arbitrary comparison and semiring functions cannot be proven consistent. Parallel arcs are distinct derivations. Equal totals preserve deterministic state/arc traversal order. The current trace-copying implementation favors auditability over large-graph efficiency: it retains up to `k` explicit prefixes per state, each carrying its full state and arc trace.

## Inspection APIs

`transducer_incoming_arcs` scans source states in ascending id order and preserves insertion order among a source's parallel arcs; it returns copied entries. `transducer_stats` reports whole-snapshot state/arc counts, independent epsilon counts by side, explicit final count, maximum out-degree, reachability and coaccessibility cardinalities, and presence of a start. These are structural metrics: disconnected states and explicit zero finals count. `reachable_states_from` allows inspection from a caller-selected root, `accepting_core_states` exposes the exact structural subset retained by `trim`, and `transducer_is_trimmed` checks whether all states belong to that core. Empty graphs are considered trimmed.
## Semiring forward and backward aggregation

`forward_weights_in_dag` returns one semiring value per state, indexed by dense state ID. It seeds the declared start with semiring one and propagates `prefix × arc` in topological order; unreachable states retain semiring zero. With no start, every forward entry is zero. `backward_weights_in_dag` works in reverse topological order: each state's explicit final weight is one accepting suffix candidate, and every outgoing arc contributes `arc × destination_suffix`. Thus a state that is both final and has outgoing accepting paths aggregates both possibilities. `total_weight_in_dag` returns the backward value at the declared start, or semiring zero when no start exists.

All three operations require the entire graph to be acyclic, including disconnected components. This avoids silently assigning finite results to cyclic path sets without a semiring-specific closure. The caller owns the semiring laws and interpretation; the implementation does not normalize probabilities. Tests use an integer sum/product semiring to hand-check a two-branch graph, a Boolean semiring for a missing start, and a self-loop to verify cycle errors.

## Snapshot and weight ownership

Builder snapshots copy graph arrays and arc records, so later builder edits cannot mutate the stored topology. Generic weights are values supplied by the caller: mutable objects contained in a weight are not deep-cloned. Semiring functions must not mutate shared weights; callers needing stronger isolation should use immutable weights or explicitly copy their own payloads.

The topology arrays in builders and snapshots, accepting-path traces, and trim mappings are private. Use the public accessors, which return copied arrays. This closes the former direct-field mutation bypass; clients reading these internal array fields must migrate to the accessors. Generic weight payloads still follow the immutable-value contract above.
