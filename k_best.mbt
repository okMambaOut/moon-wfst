///|
/// A partial accepting path retained by the DAG k-best dynamic program.
priv struct PartialPath[W] {
  states : Array[Int]
  steps : Array[PathStep[W]]
  weight : W
}

///|
/// Keep at most `limit` paths ordered by accumulated weight. Equal weights are
/// appended after earlier candidates to preserve traversal stability.
fn[W] insert_partial_path(
  paths : Array[PartialPath[W]],
  candidate : PartialPath[W],
  limit : Int,
  compare : (W, W) -> Int,
) -> Array[PartialPath[W]] {
  let result : Array[PartialPath[W]] = []
  let mut inserted = false
  for path in paths {
    if !inserted && compare(candidate.weight, path.weight) < 0 {
      result.push(candidate)
      inserted = true
    }
    if result.length() < limit {
      result.push(path)
    }
  }
  if !inserted && result.length() < limit {
    result.push(candidate)
  }
  result
}

///|
/// Keep at most `limit` accepting paths ordered by complete path weight.
fn[W] insert_accepting_path(
  paths : Array[AcceptingPath[W]],
  candidate : AcceptingPath[W],
  limit : Int,
  compare : (W, W) -> Int,
) -> Array[AcceptingPath[W]] {
  let result : Array[AcceptingPath[W]] = []
  let mut inserted = false
  for path in paths {
    if !inserted && compare(candidate.total, path.total) < 0 {
      result.push(candidate)
      inserted = true
    }
    if result.length() < limit {
      result.push(path)
    }
  }
  if !inserted && result.length() < limit {
    result.push(candidate)
  }
  result
}

///|
/// Find up to `limit` least-weight accepting paths in a finite DAG.
/// Unlike `shortest_path`, this dynamic program does not require nonnegative
/// arc weights because cycles are rejected before traversal. The supplied
/// comparison must still be compatible with semiring path extension. Parallel
/// arcs remain distinct paths; equal-cost paths retain deterministic graph
/// traversal order. A nonpositive limit is rejected.
pub fn[W] shortest_paths_in_dag(
  transducer : Transducer[W],
  order : PathOrder[W],
  limit : Int,
) -> Result[Array[AcceptingPath[W]], WfstError] {
  if limit <= 0 {
    return Err(WfstError::InvalidPathLimit(limit))
  }
  let start = match transducer.start {
    Some(state) => state
    None => return Err(WfstError::NoStartState)
  }
  let order_of_states = match topological_order(transducer) {
    Ok(order) => order
    Err(error) => return Err(error)
  }
  let paths_to_state : Array[Array[PartialPath[W]]] = []
  for _ in 0..<transducer.outgoing.length() {
    paths_to_state.push([])
  }
  if !(order.is_zero)(transducer.semiring.one) {
    let initial_states : Array[Int] = [start]
    let initial_steps : Array[PathStep[W]] = []
    paths_to_state[start].push({
      states: initial_states,
      steps: initial_steps,
      weight: transducer.semiring.one,
    })
  }
  for state in order_of_states {
    for prefix in paths_to_state[state] {
      for arc in transducer.outgoing[state] {
        if !(order.is_zero)(arc.weight) {
          let weight = semiring_times(
            transducer.semiring,
            prefix.weight,
            arc.weight,
          )
          if !(order.is_zero)(weight) {
            let states : Array[Int] = []
            for path_state in prefix.states {
              states.push(path_state)
            }
            states.push(arc.destination)
            let steps : Array[PathStep[W]] = []
            for step in prefix.steps {
              steps.push(step)
            }
            steps.push({ source: state, arc, })
            let candidate : PartialPath[W] = { states, steps, weight, }
            paths_to_state[arc.destination] = insert_partial_path(
              paths_to_state[arc.destination],
              candidate,
              limit,
              order.compare,
            )
          }
        }
      }
    }
  }

  let accepting : Array[AcceptingPath[W]] = []
  for state in order_of_states {
    match transducer.final_weights[state] {
      Some(final_weight) if !(order.is_zero)(final_weight) =>
        for prefix in paths_to_state[state] {
          let total = semiring_times(
            transducer.semiring,
            prefix.weight,
            final_weight,
          )
          if !(order.is_zero)(total) {
            let candidate : AcceptingPath[W] = {
              states: prefix.states,
              steps: prefix.steps,
              final_weight,
              total,
            }
            let next = insert_accepting_path(
              accepting,
              candidate,
              limit,
              order.compare,
            )
            accepting.clear()
            for path in next {
              accepting.push(path)
            }
          }
        }
      _ => ()
    }
  }
  Ok(accepting)
}
