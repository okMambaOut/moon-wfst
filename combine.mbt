///|
/// Copy a transducer into a builder using a dense state-id offset.
fn[W] copy_transducer_into(
  source : Transducer[W],
  destination : TransducerBuilder[W],
  offset : Int32,
) -> Unit {
  for old_state in 0..<source.outgoing.length() {
    let new_state = offset + old_state
    match source.final_weights[old_state] {
      Some(weight) => ignore(set_final(destination, new_state, weight))
      None => ()
    }
    for arc in source.outgoing[old_state] {
      ignore(
        add_arc(
          destination,
          new_state,
          arc.input,
          arc.output,
          offset + arc.destination,
          arc.weight,
        ),
      )
    }
  }
}

///|
/// Form the weighted union of two transducers using a fresh epsilon branching
/// state. Both inputs must use semiring operations with compatible meanings.
pub fn[W] union_transducers(
  left : Transducer[W],
  right : Transducer[W],
) -> Transducer[W] {
  let builder = transducer_builder(left.semiring)
  let branch = add_state(builder)
  let left_offset = 1
  let right_offset = left_offset + left.outgoing.length()
  let state_count = left.outgoing.length() + right.outgoing.length()
  for _ in 0..<state_count {
    ignore(add_state(builder))
  }
  ignore(set_start(builder, branch))
  copy_transducer_into(left, builder, left_offset)
  copy_transducer_into(right, builder, right_offset)
  match left.start {
    Some(start) =>
      ignore(
        add_arc(
          builder,
          branch,
          Label::Epsilon,
          Label::Epsilon,
          left_offset + start,
          left.semiring.one,
        ),
      )
    None => ()
  }
  match right.start {
    Some(start) =>
      ignore(
        add_arc(
          builder,
          branch,
          Label::Epsilon,
          Label::Epsilon,
          right_offset + start,
          left.semiring.one,
        ),
      )
    None => ()
  }
  build_transducer(builder)
}

///|
/// Concatenate two weighted transducers. Each final weight in the left graph
/// becomes an epsilon transition to the right start; its value is carried on
/// that transition so path multiplication order remains left-to-right. Both
/// inputs must use semiring operations with compatible meanings.
pub fn[W] concatenate_transducers(
  left : Transducer[W],
  right : Transducer[W],
) -> Transducer[W] {
  let builder = transducer_builder(left.semiring)
  let left_offset = 0
  let right_offset = left.outgoing.length()
  let state_count = left.outgoing.length() + right.outgoing.length()
  for _ in 0..<state_count {
    ignore(add_state(builder))
  }
  copy_transducer_into(left, builder, left_offset)
  copy_transducer_into(right, builder, right_offset)
  match left.start {
    Some(start) => ignore(set_start(builder, left_offset + start))
    None => ()
  }
  match right.start {
    Some(right_start) =>
      for left_state in 0..<left.final_weights.length() {
        match left.final_weights[left_state] {
          Some(final_weight) => {
            ignore(clear_final(builder, left_offset + left_state))
            ignore(
              add_arc(
                builder,
                left_offset + left_state,
                Label::Epsilon,
                Label::Epsilon,
                right_offset + right_start,
                final_weight,
              ),
            )
          }
          None => ()
        }
      }
    None =>
      for left_state in 0..<left.final_weights.length() {
        if left.final_weights[left_state] is Some(_) {
          ignore(clear_final(builder, left_offset + left_state))
        }
      }
  }
  build_transducer(builder)
}
