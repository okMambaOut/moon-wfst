///|
/// An explicit transducer label. Epsilon is not represented by an empty string.
pub(all) enum Label {
  Epsilon
  Symbol(String)
} derive(Eq, Debug)

///|
/// Semiring operations used by graph construction and algorithms.
/// The caller is responsible for satisfying the semiring laws.
pub(all) struct Semiring[W] {
  zero : W
  one : W
  plus : (W, W) -> W
  times : (W, W) -> W
}

///|
/// One directed, weighted transition. Its source is the containing state's id.
pub(all) struct Arc[W] {
  input : Label
  output : Label
  destination : Int
  weight : W
}

///|
/// Stable errors returned by graph and algorithm APIs.
pub(all) enum WfstError {
  InvalidStateId(Int)
  NoStartState
  UnsupportedEpsilonComposition
  NegativeWeight
  NoAcceptingPath
} derive(Eq, Debug)

///|
/// Return whether a label is the explicit epsilon marker.
pub fn label_is_epsilon(label : Label) -> Bool {
  match label {
    Label::Epsilon => true
    Label::Symbol(_) => false
  }
}

///|
pub extend Label with Eq::{equal, not_equal}

///|
pub extend Label with @debug.Debug::{to_repr}

///|
pub extend WfstError with Eq::{equal, not_equal}

///|
pub extend WfstError with @debug.Debug::{to_repr}
