///|
fn find_state_pair(pairs : Array[(Int, Int)], sought : (Int, Int)) -> Int? {
  for index in 0..<pairs.length() {
    if pairs[index] == sought {
      return Some(index)
    }
  }
  None
}

///|
/// Compose two epsilon-free transducers. A left output label is joined with an
/// equal right input label. Both operands must use compatible semiring laws,
/// and multiplication must be commutative: arc-wise interleaving otherwise
/// differs from multiplying the complete left path by the complete right path.
/// These algebraic obligations cannot be checked at runtime. The result uses
/// the left graph's semiring.
pub fn[W] compose(
  left : Transducer[W],
  right : Transducer[W],
) -> Result[Transducer[W], WfstError] {
  if transducer_has_epsilon(left) || transducer_has_epsilon(right) {
    return Err(WfstError::UnsupportedEpsilonComposition)
  }
  let left_start = match left.start {
    Some(state) => state
    None => return Err(WfstError::NoStartState)
  }
  let right_start = match right.start {
    Some(state) => state
    None => return Err(WfstError::NoStartState)
  }

  let builder = transducer_builder(left.semiring)
  let pairs : Array[(Int, Int)] = []
  pairs.push((left_start, right_start))
  ignore(add_state(builder))
  ignore(set_start(builder, 0))

  let mut cursor = 0
  while cursor < pairs.length() {
    let (left_state, right_state) = pairs[cursor]
    match (left.final_weights[left_state], right.final_weights[right_state]) {
      (Some(left_weight), Some(right_weight)) =>
        ignore(
          set_final(
            builder,
            cursor,
            semiring_times(left.semiring, left_weight, right_weight),
          ),
        )
      _ => ()
    }

    for left_arc in left.outgoing[left_state] {
      for right_arc in right.outgoing[right_state] {
        if left_arc.output == right_arc.input {
          let destination_pair = (left_arc.destination, right_arc.destination)
          let destination = match find_state_pair(pairs, destination_pair) {
            Some(index) => index
            None => {
              let index = add_state(builder)
              pairs.push(destination_pair)
              index
            }
          }
          ignore(
            add_arc(
              builder,
              cursor,
              left_arc.input,
              right_arc.output,
              destination,
              semiring_times(left.semiring, left_arc.weight, right_arc.weight),
            ),
          )
        }
      }
    }
    cursor = cursor + 1
  }
  Ok(build_transducer(builder))
}
