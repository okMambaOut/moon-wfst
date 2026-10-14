///|
/// A node in the finite product graph used by exact relation membership.
priv struct ProductConfiguration {
  state : Int32
  input_index : Int32
  output_index : Int32
}

///|
/// Check whether a transducer has a path matching both complete token arrays.
/// Epsilon labels consume no token on their respective side. `is_zero` lets the
/// caller exclude semiring-zero arcs and finals; all other weight operations are
/// ignored. This is a membership query, not a path-weight aggregation API.
pub fn[W] accepts_pair(
  transducer : Transducer[W],
  input : Array[String],
  output : Array[String],
  is_zero : (W) -> Bool,
) -> Result[Bool, WfstError] {
  let start = match transducer.start {
    Some(state) => state
    None => return Err(WfstError::NoStartState)
  }
  let input_length = input.length()
  let output_length = output.length()
  let visited : Array[Array[Array[Bool]]] = []
  for _ in 0..<transducer.outgoing.length() {
    let input_positions : Array[Array[Bool]] = []
    for _ in 0..<=input_length {
      let output_positions : Array[Bool] = []
      for _ in 0..<=output_length {
        output_positions.push(false)
      }
      input_positions.push(output_positions)
    }
    visited.push(input_positions)
  }
  let queue : Array[ProductConfiguration] = []
  visited[start][0][0] = true
  queue.push({ state: start, input_index: 0, output_index: 0, })
  let mut cursor = 0
  while cursor < queue.length() {
    let current = queue[cursor]
    if current.input_index == input_length &&
      current.output_index == output_length {
      match transducer.final_weights[current.state] {
        Some(weight) if !is_zero(weight) => return Ok(true)
        _ => ()
      }
    }
    for arc in transducer.outgoing[current.state] {
      if !is_zero(arc.weight) {
        let next_input : Int32? = match arc.input {
          Label::Epsilon => Some(current.input_index)
          Label::Symbol(symbol) =>
            if current.input_index < input_length &&
              input[current.input_index] == symbol {
              Some(current.input_index + 1)
            } else {
              None
            }
        }
        let next_output : Int32? = match arc.output {
          Label::Epsilon => Some(current.output_index)
          Label::Symbol(symbol) =>
            if current.output_index < output_length &&
              output[current.output_index] == symbol {
              Some(current.output_index + 1)
            } else {
              None
            }
        }
        match (next_input, next_output) {
          (Some(input_index), Some(output_index)) => {
            let destination = arc.destination
            if !visited[destination][input_index][output_index] {
              visited[destination][input_index][output_index] = true
              queue.push({ state: destination, input_index, output_index, })
            }
          }
          _ => ()
        }
      }
    }
    cursor = cursor + 1
  }
  Ok(false)
}
