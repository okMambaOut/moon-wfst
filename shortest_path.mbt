///|
/// Ordering and validation operations required by Dijkstra's algorithm. The
/// caller must ensure comparison agrees with semiring alternatives and that
/// extending a path by a non-negative weight is monotone.
pub struct PathOrder[W] {
  compare : (W, W) -> Int32
  is_nonnegative : (W) -> Bool
  is_zero : (W) -> Bool
}

///|
/// Construct a path-order policy for a caller-defined weight domain.
pub fn[W] path_order(
  compare : (W, W) -> Int32,
  is_nonnegative : (W) -> Bool,
  is_zero : (W) -> Bool,
) -> PathOrder[W] {
  { compare, is_nonnegative, is_zero, }
}

///|
/// Dijkstra policy for the built-in bounded tropical semiring.
pub fn tropical_path_order() -> PathOrder[TropicalWeight] {
  {
    compare: tropical_compare,
    is_nonnegative: _ => true,
    is_zero: tropical_is_infinite,
  }
}

///|
/// One traversed arc annotated with the source state.
pub(all) struct PathStep[W] {
  source : Int32
  arc : Arc[W]
}

///|
/// A least-cost accepting path with its terminal weight included in `total`.
pub struct AcceptingPath[W] {
  states : Array[Int32]
  steps : Array[PathStep[W]]
  final_weight : W
  total : W
}

///|
/// Return a copy of the state sequence from start through accepting state.
pub fn[W] accepting_path_states(path : AcceptingPath[W]) -> Array[Int32] {
  let result : Array[Int32] = []
  for state in path.states {
    result.push(state)
  }
  result
}

///|
/// Return a copy of the arc trace.
pub fn[W] accepting_path_steps(path : AcceptingPath[W]) -> Array[PathStep[W]] {
  let result : Array[PathStep[W]] = []
  for step in path.steps {
    result.push(step)
  }
  result
}

///|
/// The final-state weight attached to the accepting state.
pub fn[W] accepting_path_final_weight(path : AcceptingPath[W]) -> W {
  path.final_weight
}

///|
/// The product of all arc weights followed by the final-state weight.
pub fn[W] accepting_path_total_weight(path : AcceptingPath[W]) -> W {
  path.total
}

///|
/// Find a least-cost accepting path using an O(V^2 + E) linear-scan Dijkstra
/// implementation. Every arc and final weight is validated, including values
/// on unreachable states. Equal-cost alternatives preserve state-id and arc
/// insertion order. The supplied `PathOrder` laws cannot be proven at runtime.
pub fn[W] shortest_path(
  transducer : Transducer[W],
  order : PathOrder[W],
) -> Result[AcceptingPath[W], WfstError] {
  let start = match transducer.start {
    Some(state) => state
    None => return Err(WfstError::NoStartState)
  }

  for arcs in transducer.outgoing {
    for arc in arcs {
      if !(order.is_nonnegative)(arc.weight) {
        return Err(WfstError::NegativeWeight)
      }
    }
  }
  for final_weight in transducer.final_weights {
    match final_weight {
      Some(weight) if !(order.is_nonnegative)(weight) =>
        return Err(WfstError::NegativeWeight)
      _ => ()
    }
  }

  let count = transducer.outgoing.length()
  let distances : Array[W?] = []
  let predecessors : Array[(Int32, Int32)?] = []
  let settled : Array[Bool] = []
  for _ in 0..<count {
    distances.push(None)
    predecessors.push(None)
    settled.push(false)
  }
  distances[start] = Some(transducer.semiring.one)
  if (order.is_zero)(transducer.semiring.one) {
    return Err(WfstError::NoAcceptingPath)
  }

  let mut iteration = 0
  while iteration < count {
    let mut selected : Int32? = None
    for state in 0..<count {
      if !settled[state] {
        match distances[state] {
          Some(candidate) =>
            match selected {
              None => selected = Some(state)
              Some(current) => {
                let current_weight = distances[current].unwrap()
                if (order.compare)(candidate, current_weight) < 0 {
                  selected = Some(state)
                }
              }
            }
          None => ()
        }
      }
    }

    let state = match selected {
      Some(value) => value
      None => break
    }
    settled[state] = true
    let current_weight = distances[state].unwrap()
    for arc_index in 0..<transducer.outgoing[state].length() {
      let arc = transducer.outgoing[state][arc_index]
      if !settled[arc.destination] && !(order.is_zero)(arc.weight) {
        let candidate = semiring_times(
          transducer.semiring,
          current_weight,
          arc.weight,
        )
        if !(order.is_zero)(candidate) {
          match distances[arc.destination] {
            None => {
              distances[arc.destination] = Some(candidate)
              predecessors[arc.destination] = Some((state, arc_index))
            }
            Some(existing) if (order.compare)(candidate, existing) < 0 => {
              distances[arc.destination] = Some(candidate)
              predecessors[arc.destination] = Some((state, arc_index))
            }
            _ => ()
          }
        }
      }
    }
    iteration = iteration + 1
  }

  let mut best_state : Int32? = None
  let mut best_total : W? = None
  let mut best_final : W? = None
  for state in 0..<count {
    match (distances[state], transducer.final_weights[state]) {
      (Some(distance), Some(final_weight)) if !(order.is_zero)(final_weight) => {
        let total = semiring_times(transducer.semiring, distance, final_weight)
        if !(order.is_zero)(total) {
          match best_total {
            None => {
              best_state = Some(state)
              best_total = Some(total)
              best_final = Some(final_weight)
            }
            Some(existing) if (order.compare)(total, existing) < 0 => {
              best_state = Some(state)
              best_total = Some(total)
              best_final = Some(final_weight)
            }
            _ => ()
          }
        }
      }
      _ => ()
    }
  }

  let goal = match best_state {
    Some(state) => state
    None => return Err(WfstError::NoAcceptingPath)
  }
  let final_weight = best_final.unwrap()
  let total = best_total.unwrap()
  let reversed_states : Array[Int32] = []
  let reversed_steps : Array[PathStep[W]] = []
  reversed_states.push(goal)
  let mut cursor = goal
  while cursor != start {
    let (previous, arc_index) = match predecessors[cursor] {
      Some(previous) => previous
      None => return Err(WfstError::NoAcceptingPath)
    }
    reversed_steps.push({
      source: previous,
      arc: transducer.outgoing[previous][arc_index],
    })
    cursor = previous
    reversed_states.push(cursor)
  }
  let states : Array[Int32] = []
  let steps : Array[PathStep[W]] = []
  for offset in 0..<reversed_states.length() {
    states.push(reversed_states[reversed_states.length() - offset - 1])
  }
  for offset in 0..<reversed_steps.length() {
    steps.push(reversed_steps[reversed_steps.length() - offset - 1])
  }
  Ok({ states, steps, final_weight, total, })
}
