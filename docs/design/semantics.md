# Data model and algorithm contracts

MoonWFST models a finite directed graph as a weighted relation. A state is an integer local to one transducer. Every arc has an input label, output label, destination, and weight. `Epsilon` is represented explicitly and is distinct from a symbol whose text happens to be empty. The start state is optional during construction so an empty or acceptor-only graph can be represented; algorithms that require a start state return a typed error. Final weights are attached to states, not encoded as synthetic arcs.

## Semiring contract

A caller-provided semiring supplies additive zero, multiplicative one, alternative-path addition (`plus`), and sequential path extension (`times`). The library cannot prove the semiring axioms. Callers must ensure the operations are closed, associative, distributive, and use the supplied identities consistently. Composition preserves left-to-right multiplication order, which matters for non-commutative semirings.

The Boolean semiring is provided for reachability-style relations. A bounded non-negative tropical semiring is provided for least-cost examples. Its finite costs are non-negative machine integers; addition of path costs saturates to tropical infinity at the documented bound, so overflow never wraps into a cheaper path.

## Transformations

- Input projection copies each input label to the output side.
- Output projection copies each output label to the input side.
- Inversion swaps the two labels on every arc.
- These transformations preserve topology, weights, start state, and final weights.
- Composition joins a left arc's output symbol to a right arc's input symbol and multiplies weights in left-to-right order. The first implementation is explicitly epsilon-free: if either graph contains epsilon on either side, composition returns `UnsupportedEpsilonComposition`. No epsilon filter is implied.

## Shortest accepting path

The ordered-weight API is only valid when its comparison is consistent with the semiring's choice operation, path extension is monotone, and every arc and terminal weight accepted by Dijkstra is non-negative in the supplied order. The library checks the caller-provided non-negative predicate on actual arc/final weights; it cannot prove the algebraic laws. Ties are resolved by stable state and arc insertion order. A result carries the accepting state sequence, traversed arcs, and total weight including the final weight. Unreachable accepting states produce `NoAcceptingPath`, not an infinity-valued pseudo-path.

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

`accepts_pair` explores the finite product `(graph state, input position, output position)` and returns whether a path consumes both token arrays completely and ends at an explicit final state. Each side consumes independently: epsilon on one side does not imply epsilon on the other. A caller-supplied `is_zero` predicate excludes semiring-zero arcs and finals; all other weight values are ignored, so this query recognizes membership but does not aggregate weights or return a witness. The predicate must be deterministic and side-effect free. The implementation memoizes the product space, using `O(V × (|input| + 1) × (|output| + 1))` memory, and terminates even with epsilon/epsilon cycles. A graph without a start returns `NoStartState`.
