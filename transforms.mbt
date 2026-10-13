///|
/// Return whether any arc uses epsilon on either label side.
pub fn[W] transducer_has_epsilon(transducer : Transducer[W]) -> Bool {
  for arcs in transducer.outgoing {
    for arc in arcs {
      if label_is_epsilon(arc.input) || label_is_epsilon(arc.output) {
        return true
      }
    }
  }
  false
}

///|
fn[W] copy_builder_shell(transducer : Transducer[W]) -> TransducerBuilder[W] {
  let builder = transducer_builder(transducer.semiring)
  for _ in 0..<transducer.outgoing.length() {
    ignore(add_state(builder))
  }
  match transducer.start {
    Some(start) => ignore(set_start(builder, start))
    None => ()
  }
  for state in 0..<transducer.final_weights.length() {
    match transducer.final_weights[state] {
      Some(weight) => ignore(set_final(builder, state, weight))
      None => ()
    }
  }
  builder
}

///|
/// Copy a transducer while replacing each output label with its input label.
pub fn[W] project_input(transducer : Transducer[W]) -> Transducer[W] {
  let builder = copy_builder_shell(transducer)
  for source in 0..<transducer.outgoing.length() {
    for arc in transducer.outgoing[source] {
      ignore(
        add_arc(
          builder,
          source,
          arc.input,
          arc.input,
          arc.destination,
          arc.weight,
        ),
      )
    }
  }
  build_transducer(builder)
}

///|
/// Copy a transducer while replacing each input label with its output label.
pub fn[W] project_output(transducer : Transducer[W]) -> Transducer[W] {
  let builder = copy_builder_shell(transducer)
  for source in 0..<transducer.outgoing.length() {
    for arc in transducer.outgoing[source] {
      ignore(
        add_arc(
          builder,
          source,
          arc.output,
          arc.output,
          arc.destination,
          arc.weight,
        ),
      )
    }
  }
  build_transducer(builder)
}

///|
/// Reverse every arc's input/output mapping while preserving graph topology
/// and all weights.
pub fn[W] invert(transducer : Transducer[W]) -> Transducer[W] {
  let builder = copy_builder_shell(transducer)
  for source in 0..<transducer.outgoing.length() {
    for arc in transducer.outgoing[source] {
      ignore(
        add_arc(
          builder,
          source,
          arc.output,
          arc.input,
          arc.destination,
          arc.weight,
        ),
      )
    }
  }
  build_transducer(builder)
}
