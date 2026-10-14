///|
/// Structural metrics captured from a transducer snapshot. Epsilon counts are
/// independent: an epsilon/epsilon arc contributes to both counters.
pub(all) struct TransducerStats {
  state_count : Int32
  arc_count : Int32
  epsilon_input_arc_count : Int32
  epsilon_output_arc_count : Int32
  final_state_count : Int32
  max_out_degree : Int32
  reachable_state_count : Int32
  coaccessible_state_count : Int32
  has_start : Bool
} derive(Eq)

///|
pub extend TransducerStats with Eq::{equal, not_equal}

///|
/// Return a stable copy of all arcs entering `destination`, ordered first by
/// source-state id and then by each source's insertion order. Parallel arcs are
/// retained as separate entries. The returned array is independent of the graph.
pub fn[W] transducer_incoming_arcs(
  transducer : Transducer[W],
  destination : Int32,
) -> Result[Array[(Int32, Arc[W])], WfstError] {
  let count = transducer.outgoing.length()
  if destination < 0 || destination >= count {
    return Err(WfstError::InvalidStateId(destination))
  }
  let incoming : Array[(Int32, Arc[W])] = []
  for source in 0..<count {
    for arc in transducer.outgoing[source] {
      if arc.destination == destination {
        incoming.push((source, arc))
      }
    }
  }
  Ok(incoming)
}

///|
/// Count graph structure and start/final reachability in O(V + E) time.
/// Counts include unreachable states and explicitly stored zero-valued finals.
pub fn[W] transducer_stats(transducer : Transducer[W]) -> TransducerStats {
  let mut arc_count = 0
  let mut epsilon_input_arc_count = 0
  let mut epsilon_output_arc_count = 0
  let mut final_state_count = 0
  let mut max_out_degree = 0
  for state in 0..<transducer.outgoing.length() {
    let degree = transducer.outgoing[state].length()
    arc_count = arc_count + degree
    if degree > max_out_degree {
      max_out_degree = degree
    }
    if transducer.final_weights[state] is Some(_) {
      final_state_count = final_state_count + 1
    }
    for arc in transducer.outgoing[state] {
      if arc.input is Label::Epsilon {
        epsilon_input_arc_count = epsilon_input_arc_count + 1
      }
      if arc.output is Label::Epsilon {
        epsilon_output_arc_count = epsilon_output_arc_count + 1
      }
    }
  }
  let reachable = reachable_states(transducer)
  let coaccessible = coaccessible_states(transducer)
  let mut reachable_state_count = 0
  let mut coaccessible_state_count = 0
  for state in 0..<transducer.outgoing.length() {
    if reachable[state] {
      reachable_state_count = reachable_state_count + 1
    }
    if coaccessible[state] {
      coaccessible_state_count = coaccessible_state_count + 1
    }
  }
  {
    state_count: transducer.outgoing.length(),
    arc_count,
    epsilon_input_arc_count,
    epsilon_output_arc_count,
    final_state_count,
    max_out_degree,
    reachable_state_count,
    coaccessible_state_count,
    has_start: transducer.start is Some(_),
  }
}
