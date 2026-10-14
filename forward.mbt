///|
/// Aggregate semiring weights of every prefix reaching each state in a DAG.
/// The result is indexed by dense state identifier; states unreachable from
/// the declared start retain semiring zero. The entire graph must be acyclic,
/// including components that are not reachable from the start.
pub fn[W] forward_weights_in_dag(
  transducer : Transducer[W],
) -> Result[Array[W], WfstError] {
  let order = match topological_order(transducer) {
    Ok(order) => order
    Err(error) => return Err(error)
  }
  let semiring = transducer_semiring(transducer)
  let count = transducer_state_count(transducer)
  let values : Array[W] = []
  for _ in 0..<count {
    values.push(semiring_zero(semiring))
  }
  match transducer_start_state(transducer) {
    None => Ok(values)
    Some(start) => {
      values[start] = semiring_one(semiring)
      for state in order {
        let prefix_weight = values[state]
        for arc in transducer.outgoing[state] {
          let path_weight = semiring_times(semiring, prefix_weight, arc.weight)
          values[arc.destination] = semiring_plus(
            semiring,
            values[arc.destination],
            path_weight,
          )
        }
      }
      Ok(values)
    }
  }
}

///|
/// Aggregate semiring weights of every accepting suffix from each state in a
/// DAG. Explicit final weights contribute paths that stop at that state; arcs
/// may still continue to other accepting paths. States with no accepting
/// suffix have semiring zero. The entire graph must be acyclic.
pub fn[W] backward_weights_in_dag(
  transducer : Transducer[W],
) -> Result[Array[W], WfstError] {
  let order = match topological_order(transducer) {
    Ok(order) => order
    Err(error) => return Err(error)
  }
  let semiring = transducer_semiring(transducer)
  let count = transducer_state_count(transducer)
  let values : Array[W] = []
  for _ in 0..<count {
    values.push(semiring_zero(semiring))
  }
  let mut cursor = order.length()
  while cursor > 0 {
    cursor = cursor - 1
    let state = order[cursor]
    let mut suffix_weight = match transducer.final_weights[state] {
      Some(final_weight) => final_weight
      None => semiring_zero(semiring)
    }
    for arc in transducer.outgoing[state] {
      let path_weight = semiring_times(
        semiring,
        arc.weight,
        values[arc.destination],
      )
      suffix_weight = semiring_plus(semiring, suffix_weight, path_weight)
    }
    values[state] = suffix_weight
  }
  Ok(values)
}

///|
/// Return the semiring aggregate of all accepting paths in a DAG. A graph
/// without a declared start denotes no paths and returns semiring zero. This
/// operation rejects cycles rather than assuming a finite closure exists.
pub fn[W] total_weight_in_dag(
  transducer : Transducer[W],
) -> Result[W, WfstError] {
  let suffix_weights = match backward_weights_in_dag(transducer) {
    Ok(weights) => weights
    Err(error) => return Err(error)
  }
  match transducer_start_state(transducer) {
    None => Ok(semiring_zero(transducer_semiring(transducer)))
    Some(start) => Ok(suffix_weights[start])
  }
}
