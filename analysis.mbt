///|
/// Compact graph together with a mapping from each original state to its new
/// identifier. `None` means that the original state was removed.
pub struct TrimResult[W] {
  graph : Transducer[W]
  old_to_new : Array[Int?]
}

///|
/// Return whether each state can be reached from the start by graph arcs.
/// Arc weights and labels (including epsilon) do not affect structural reachability.
pub fn[W] reachable_states(transducer : Transducer[W]) -> Array[Bool] {
  let count = transducer.outgoing.length()
  let reached : Array[Bool] = []
  for _ in 0..<count {
    reached.push(false)
  }
  match transducer.start {
    None => ()
    Some(start) => {
      reached[start] = true
      let queue : Array[Int] = [start]
      let mut cursor = 0
      while cursor < queue.length() {
        let state = queue[cursor]
        for arc in transducer.outgoing[state] {
          if !reached[arc.destination] {
            reached[arc.destination] = true
            queue.push(arc.destination)
          }
        }
        cursor = cursor + 1
      }
    }
  }
  reached
}

///|
/// Return whether each state can reach a structurally final state.
/// A state is final whenever it has an explicitly stored final weight, even if
/// that value is the semiring zero. Epsilon and zero-valued arcs are traversed.
pub fn[W] coaccessible_states(transducer : Transducer[W]) -> Array[Bool] {
  let count = transducer.outgoing.length()
  let predecessors : Array[Array[Int]] = []
  let accessible : Array[Bool] = []
  let queue : Array[Int] = []
  for state in 0..<count {
    predecessors.push([])
    accessible.push(false)
    if transducer.final_weights[state] is Some(_) {
      accessible[state] = true
      queue.push(state)
    }
  }
  for source in 0..<count {
    for arc in transducer.outgoing[source] {
      predecessors[arc.destination].push(source)
    }
  }
  let mut cursor = 0
  while cursor < queue.length() {
    let state = queue[cursor]
    for predecessor in predecessors[state] {
      if !accessible[predecessor] {
        accessible[predecessor] = true
        queue.push(predecessor)
      }
    }
    cursor = cursor + 1
  }
  accessible
}

///|
/// Read the compacted graph produced by `trim`.
pub fn[W] trim_result_transducer(result : TrimResult[W]) -> Transducer[W] {
  result.graph
}

///|
/// Return a copy of the original-to-compacted state mapping.
pub fn[W] trim_result_state_mapping(result : TrimResult[W]) -> Array[Int?] {
  let copy : Array[Int?] = []
  for state in result.old_to_new {
    copy.push(state)
  }
  copy
}

///|
/// Remove states that are not both reachable from the start and able to reach
/// a structurally final state. Retained states are re-numbered in original
/// state order. An absent start or an empty accepting core yields an empty
/// graph with no start state. The operation is structural: it does not inspect
/// label matches or compare generic weights against semiring zero.
pub fn[W] trim(transducer : Transducer[W]) -> TrimResult[W] {
  let core = accepting_core_states(transducer)
  let keep : Array[Bool] = []
  let mapping : Array[Int?] = []
  let mut retained_count = 0
  for state in 0..<transducer.outgoing.length() {
    let retained = core[state]
    keep.push(retained)
    if retained {
      mapping.push(Some(retained_count))
      retained_count = retained_count + 1
    } else {
      mapping.push(None)
    }
  }

  let builder = transducer_builder(transducer.semiring)
  for _ in 0..<retained_count {
    ignore(add_state(builder))
  }
  match transducer.start {
    Some(start) =>
      match mapping[start] {
        Some(new_start) => ignore(set_start(builder, new_start))
        None => ()
      }
    None => ()
  }
  for old_state in 0..<transducer.outgoing.length() {
    if keep[old_state] {
      let new_state = mapping[old_state].unwrap()
      match transducer.final_weights[old_state] {
        Some(weight) => ignore(set_final(builder, new_state, weight))
        None => ()
      }
      for arc in transducer.outgoing[old_state] {
        if keep[arc.destination] {
          ignore(
            add_arc(
              builder,
              new_state,
              arc.input,
              arc.output,
              mapping[arc.destination].unwrap(),
              arc.weight,
            ),
          )
        }
      }
    }
  }
  { graph: build_transducer(builder), old_to_new: mapping, }
}

///|
/// Return a deterministic topological order of every state in a DAG.
/// All disconnected components are included. Among currently ready states,
/// lower state identifiers are emitted first; newly ready states are appended
/// after states already in the queue. A cyclic graph returns `GraphHasCycle`.
pub fn[W] topological_order(
  transducer : Transducer[W],
) -> Result[Array[Int], WfstError] {
  let count = transducer.outgoing.length()
  let indegree : Array[Int] = []
  for _ in 0..<count {
    indegree.push(0)
  }
  for arcs in transducer.outgoing {
    for arc in arcs {
      indegree[arc.destination] = indegree[arc.destination] + 1
    }
  }
  let queue : Array[Int] = []
  for state in 0..<count {
    if indegree[state] == 0 {
      queue.push(state)
    }
  }
  let order : Array[Int] = []
  let mut cursor = 0
  while cursor < queue.length() {
    let state = queue[cursor]
    order.push(state)
    for arc in transducer.outgoing[state] {
      indegree[arc.destination] = indegree[arc.destination] - 1
      if indegree[arc.destination] == 0 {
        queue.push(arc.destination)
      }
    }
    cursor = cursor + 1
  }
  if order.length() == count {
    Ok(order)
  } else {
    Err(WfstError::GraphHasCycle)
  }
}

///|
/// Compute structural reachability from an explicit root state rather than the
/// graph's declared start. This is useful when inspecting components or when
/// an algorithm chooses its own entry state. Every stored arc is traversed.
pub fn[W] reachable_states_from(
  transducer : Transducer[W],
  root : Int,
) -> Result[Array[Bool], WfstError] {
  let count = transducer.outgoing.length()
  if root < 0 || root >= count {
    return Err(WfstError::InvalidStateId(root))
  }
  let reached : Array[Bool] = []
  for _ in 0..<count {
    reached.push(false)
  }
  reached[root] = true
  let queue : Array[Int] = [root]
  let mut cursor = 0
  while cursor < queue.length() {
    let state = queue[cursor]
    for arc in transducer.outgoing[state] {
      if !reached[arc.destination] {
        reached[arc.destination] = true
        queue.push(arc.destination)
      }
    }
    cursor = cursor + 1
  }
  Ok(reached)
}

///|
/// Return the states lying on at least one structural path from the declared
/// start to an explicitly final state. Weights and labels are not interpreted.
pub fn[W] accepting_core_states(transducer : Transducer[W]) -> Array[Bool] {
  let reached = reachable_states(transducer)
  let accessible = coaccessible_states(transducer)
  let core : Array[Bool] = []
  for state in 0..<transducer.outgoing.length() {
    core.push(reached[state] && accessible[state])
  }
  core
}

///|
/// Report whether every state belongs to the graph's structural accepting
/// core. The empty graph is trimmed; a graph without a start and with states is
/// not. This check ignores labels and semiring-zero values.
pub fn[W] transducer_is_trimmed(transducer : Transducer[W]) -> Bool {
  let core = accepting_core_states(transducer)
  for state in core {
    if !state {
      return false
    }
  }
  true
}
