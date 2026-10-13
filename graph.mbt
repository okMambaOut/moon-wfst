///|
/// Mutable graph assembler. A builder can be reused after `build`; every built
/// graph owns copies of its adjacency and final-weight arrays.
pub struct TransducerBuilder[W] {
  semiring : Semiring[W]
  outgoing : Array[Array[Arc[W]]]
  final_weights : Array[W?]
  mut start : Int?
}

///|
/// Validated weighted finite-state transducer. Graph arrays are not exposed as
/// mutable references; use the accessors to inspect a snapshot.
pub struct Transducer[W] {
  semiring : Semiring[W]
  outgoing : Array[Array[Arc[W]]]
  final_weights : Array[W?]
  start : Int?
}

///|
/// Create an empty transducer builder for the supplied semiring.
pub fn[W] transducer_builder(semiring : Semiring[W]) -> TransducerBuilder[W] {
  let outgoing : Array[Array[Arc[W]]] = []
  let final_weights : Array[W?] = []
  { semiring, outgoing, final_weights, start: None, }
}

///|
/// Append a state and return its dense, zero-based identifier.
pub fn[W] add_state(builder : TransducerBuilder[W]) -> Int {
  let id = builder.outgoing.length()
  let arcs : Array[Arc[W]] = []
  builder.outgoing.push(arcs)
  builder.final_weights.push(None)
  id
}

///|
/// Set the start state. An invalid state id leaves the builder unchanged.
pub fn[W] set_start(
  builder : TransducerBuilder[W],
  state : Int,
) -> Result[Unit, WfstError] {
  if state < 0 || state >= builder.outgoing.length() {
    Err(WfstError::InvalidStateId(state))
  } else {
    builder.start = Some(state)
    Ok(())
  }
}

///|
/// Set a state's final weight. Passing a semiring-zero weight is permitted and
/// retains the distinction between a final state with zero weight and non-final.
pub fn[W] set_final(
  builder : TransducerBuilder[W],
  state : Int,
  weight : W,
) -> Result[Unit, WfstError] {
  if state < 0 || state >= builder.outgoing.length() {
    Err(WfstError::InvalidStateId(state))
  } else {
    builder.final_weights[state] = Some(weight)
    Ok(())
  }
}

///|
/// Mark a state as non-final.
pub fn[W] clear_final(
  builder : TransducerBuilder[W],
  state : Int,
) -> Result[Unit, WfstError] {
  if state < 0 || state >= builder.outgoing.length() {
    Err(WfstError::InvalidStateId(state))
  } else {
    builder.final_weights[state] = None
    Ok(())
  }
}

///|
/// Add an arc after validating both endpoint identifiers.
pub fn[W] add_arc(
  builder : TransducerBuilder[W],
  source : Int,
  input : Label,
  output : Label,
  destination : Int,
  weight : W,
) -> Result[Unit, WfstError] {
  let count = builder.outgoing.length()
  if source < 0 || source >= count {
    Err(WfstError::InvalidStateId(source))
  } else if destination < 0 || destination >= count {
    Err(WfstError::InvalidStateId(destination))
  } else {
    let arc : Arc[W] = { input, output, destination, weight, }
    builder.outgoing[source].push(arc)
    Ok(())
  }
}

///|
/// Produce a graph snapshot independent of later builder mutations.
pub fn[W] build_transducer(builder : TransducerBuilder[W]) -> Transducer[W] {
  let outgoing : Array[Array[Arc[W]]] = []
  for source_arcs in builder.outgoing {
    let copied_arcs : Array[Arc[W]] = []
    for arc in source_arcs {
      copied_arcs.push(arc)
    }
    outgoing.push(copied_arcs)
  }
  let final_weights : Array[W?] = []
  for weight in builder.final_weights {
    final_weights.push(weight)
  }
  { semiring: builder.semiring, outgoing, final_weights, start: builder.start, }
}

///|
/// Number of states in a transducer snapshot.
pub fn[W] transducer_state_count(transducer : Transducer[W]) -> Int {
  transducer.outgoing.length()
}

///|
/// Read the optional start-state identifier.
pub fn[W] transducer_start_state(transducer : Transducer[W]) -> Int? {
  transducer.start
}

///|
/// Return a copy of a state's outgoing arcs. Invalid identifiers are reported.
pub fn[W] transducer_arcs_from(
  transducer : Transducer[W],
  state : Int,
) -> Result[Array[Arc[W]], WfstError] {
  if state < 0 || state >= transducer.outgoing.length() {
    Err(WfstError::InvalidStateId(state))
  } else {
    let copied : Array[Arc[W]] = []
    for arc in transducer.outgoing[state] {
      copied.push(arc)
    }
    Ok(copied)
  }
}

///|
/// Read a state's optional final weight.
pub fn[W] transducer_final_weight(
  transducer : Transducer[W],
  state : Int,
) -> Result[W?, WfstError] {
  if state < 0 || state >= transducer.final_weights.length() {
    Err(WfstError::InvalidStateId(state))
  } else {
    Ok(transducer.final_weights[state])
  }
}

///|
/// Return the semiring attached to this graph.
pub fn[W] transducer_semiring(transducer : Transducer[W]) -> Semiring[W] {
  transducer.semiring
}
