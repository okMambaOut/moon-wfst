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
  GraphHasCycle
  InvalidPathLimit(Int)
  NegativeWeight
  WeightOutOfRange
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

///|
/// Apply semiring addition to two alternative path weights.
pub fn[W] semiring_plus(semiring : Semiring[W], left : W, right : W) -> W {
  (semiring.plus)(left, right)
}

///|
/// Extend a path by composing its current weight with one arc weight.
pub fn[W] semiring_times(semiring : Semiring[W], left : W, right : W) -> W {
  (semiring.times)(left, right)
}

///|
/// The additive identity of a semiring.
pub fn[W] semiring_zero(semiring : Semiring[W]) -> W {
  semiring.zero
}

///|
/// The multiplicative identity of a semiring.
pub fn[W] semiring_one(semiring : Semiring[W]) -> W {
  semiring.one
}

///|
/// Boolean weights: `false` is zero, `true` is one, alternatives use OR,
/// and path extension uses AND.
pub fn boolean_semiring() -> Semiring[Bool] {
  {
    zero: false,
    one: true,
    plus: (left, right) => left || right,
    times: (left, right) => left && right,
  }
}

///|
/// A bounded tropical weight. Finite values are non-negative machine integers;
/// `Infinity` is the additive identity and represents no path.
pub enum TropicalWeight {
  Finite(Int)
  Infinity
} derive(Debug)

///|
/// The largest machine integer is reserved as tropical infinity.
const TROPICAL_INFINITY_BOUND : Int = 2147483647

///|
/// Construct a finite tropical cost. Negative and reserved infinity values are
/// rejected so every public finite value has well-defined saturating addition.
pub fn tropical_cost(cost : Int) -> Result[TropicalWeight, WfstError] {
  if cost < 0 {
    Err(WfstError::NegativeWeight)
  } else if cost >= TROPICAL_INFINITY_BOUND {
    Err(WfstError::WeightOutOfRange)
  } else {
    Ok(TropicalWeight::Finite(cost))
  }
}

///|
/// Return the tropical additive identity.
pub fn tropical_infinity() -> TropicalWeight {
  TropicalWeight::Infinity
}

///|
/// Return a finite cost, or `None` for tropical infinity.
pub fn tropical_value(weight : TropicalWeight) -> Int? {
  match weight {
    TropicalWeight::Finite(cost) => Some(cost)
    TropicalWeight::Infinity => None
  }
}

///|
/// Return whether a tropical weight is infinite.
pub fn tropical_is_infinite(weight : TropicalWeight) -> Bool {
  match weight {
    TropicalWeight::Finite(_) => false
    TropicalWeight::Infinity => true
  }
}

///|
/// Compare tropical weights using their natural least-cost order.
pub fn tropical_compare(left : TropicalWeight, right : TropicalWeight) -> Int {
  match (left, right) {
    (TropicalWeight::Infinity, TropicalWeight::Infinity) => 0
    (TropicalWeight::Infinity, TropicalWeight::Finite(_)) => 1
    (TropicalWeight::Finite(_), TropicalWeight::Infinity) => -1
    (TropicalWeight::Finite(a), TropicalWeight::Finite(b)) =>
      if a < b {
        -1
      } else if a > b {
        1
      } else {
        0
      }
  }
}

///|
fn tropical_min(
  left : TropicalWeight,
  right : TropicalWeight,
) -> TropicalWeight {
  if tropical_compare(left, right) <= 0 {
    left
  } else {
    right
  }
}

///|
fn tropical_extend(
  left : TropicalWeight,
  right : TropicalWeight,
) -> TropicalWeight {
  match (left, right) {
    (TropicalWeight::Infinity, _) | (_, TropicalWeight::Infinity) =>
      TropicalWeight::Infinity
    (TropicalWeight::Finite(a), TropicalWeight::Finite(b)) =>
      if a >= TROPICAL_INFINITY_BOUND - b {
        TropicalWeight::Infinity
      } else {
        TropicalWeight::Finite(a + b)
      }
  }
}

///|
/// A bounded non-negative min-plus semiring suitable for deterministic
/// least-cost graph examples. Addition saturates to infinity before overflow.
pub fn tropical_semiring() -> Semiring[TropicalWeight] {
  {
    zero: TropicalWeight::Infinity,
    one: TropicalWeight::Finite(0),
    plus: tropical_min,
    times: tropical_extend,
  }
}

///|
pub extend TropicalWeight with @debug.Debug::{to_repr}
