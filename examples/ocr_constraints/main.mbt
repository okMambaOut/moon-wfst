///|
fn add_candidate(
  builder : @wfst.TransducerBuilder[@wfst.TropicalWeight],
  source : Int32,
  destination : Int32,
  cell : String,
  glyph : String,
  cost : Int32,
) -> Unit {
  ignore(
    @wfst.add_arc(
      builder,
      source,
      @wfst.Label::Symbol(cell),
      @wfst.Label::Symbol(glyph),
      destination,
      @wfst.tropical_cost(cost).unwrap(),
    ),
  )
}

///|
fn build_ocr_lattice(
  semiring : @wfst.Semiring[@wfst.TropicalWeight],
) -> @wfst.Transducer[@wfst.TropicalWeight] {
  let lattice = @wfst.transducer_builder(semiring)
  for _ in 0..<7 {
    ignore(@wfst.add_state(lattice))
  }
  ignore(@wfst.set_start(lattice, 0))
  ignore(@wfst.set_final(lattice, 6, @wfst.tropical_cost(0).unwrap()))

  // Synthetic OCR hypotheses: each cell has an observed glyph and a cost.
  // Lower costs represent more confident upstream recognizer candidates.
  add_candidate(lattice, 0, 1, "cell-1", "N", 0)
  add_candidate(lattice, 0, 1, "cell-1", "M", 1)
  add_candidate(lattice, 1, 2, "cell-2", "8", 0)
  add_candidate(lattice, 1, 2, "cell-2", "B", 2)
  add_candidate(lattice, 2, 3, "cell-3", "O", 0)
  add_candidate(lattice, 2, 3, "cell-3", "0", 2)
  add_candidate(lattice, 3, 4, "cell-4", "I", 0)
  add_candidate(lattice, 3, 4, "cell-4", "1", 3)
  add_candidate(lattice, 4, 5, "cell-5", "S", 0)
  add_candidate(lattice, 4, 5, "cell-5", "5", 2)
  add_candidate(lattice, 5, 6, "cell-6", "B", 0)
  add_candidate(lattice, 5, 6, "cell-6", "8", 3)
  @wfst.build_transducer(lattice)
}

///|
fn add_rule(
  builder : @wfst.TransducerBuilder[@wfst.TropicalWeight],
  source : Int32,
  destination : Int32,
  observed : String,
  normalized : String,
  penalty : Int32,
) -> Unit {
  ignore(
    @wfst.add_arc(
      builder,
      source,
      @wfst.Label::Symbol(observed),
      @wfst.Label::Symbol(normalized),
      destination,
      @wfst.tropical_cost(penalty).unwrap(),
    ),
  )
}

///|
fn build_reference_constraint(
  semiring : @wfst.Semiring[@wfst.TropicalWeight],
) -> @wfst.Transducer[@wfst.TropicalWeight] {
  let constraint = @wfst.transducer_builder(semiring)
  for _ in 0..<7 {
    ignore(@wfst.add_state(constraint))
  }
  ignore(@wfst.set_start(constraint, 0))
  ignore(@wfst.set_final(constraint, 6, @wfst.tropical_cost(0).unwrap()))

  let uppercase = [
    "A", "B", "C", "D", "E", "F", "G", "H", "I", "J", "K", "L", "M", "N", "O", "P",
    "Q", "R", "S", "T", "U", "V", "W", "X", "Y", "Z",
  ]
  let digits = ["0", "1", "2", "3", "4", "5", "6", "7", "8", "9"]

  // Invoice reference format: two uppercase letters followed by four digits.
  for position in 0..<6 {
    if position < 2 {
      for letter in uppercase {
        add_rule(constraint, position, position + 1, letter, letter, 0)
      }
    } else {
      for digit in digits {
        add_rule(constraint, position, position + 1, digit, digit, 0)
      }
      // Common OCR confusions are normalized only where the format expects a digit.
      add_rule(constraint, position, position + 1, "O", "0", 1)
      add_rule(constraint, position, position + 1, "I", "1", 1)
      add_rule(constraint, position, position + 1, "S", "5", 1)
      add_rule(constraint, position, position + 1, "B", "8", 1)
    }
  }
  @wfst.build_transducer(constraint)
}

///|
fn main {
  let semiring = @wfst.tropical_semiring()
  let lattice = build_ocr_lattice(semiring)
  let format = build_reference_constraint(semiring)
  let rescored = @wfst.compose(lattice, format).unwrap()
  let best = @wfst.shortest_path(rescored, @wfst.tropical_path_order()).unwrap()

  let mut reference = ""
  for step in @wfst.accepting_path_steps(best) {
    match step.arc.output {
      @wfst.Label::Symbol(glyph) => reference = reference + glyph
      @wfst.Label::Epsilon => ()
    }
  }
  let total_cost = @wfst.tropical_value(@wfst.accepting_path_total_weight(best)).unwrap()
  println("invoice reference after format-constrained OCR: " + reference)
  println("combined OCR and repair cost: " + total_cost.to_string())
}
