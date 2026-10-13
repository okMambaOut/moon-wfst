///|
fn main {
  let semiring = @wfst.tropical_semiring()
  let acoustic = @wfst.transducer_builder(semiring)
  let acoustic_start = @wfst.add_state(acoustic)
  let acoustic_end = @wfst.add_state(acoustic)
  ignore(@wfst.set_start(acoustic, acoustic_start))
  ignore(
    @wfst.set_final(acoustic, acoustic_end, @wfst.tropical_cost(0).unwrap()),
  )
  ignore(
    @wfst.add_arc(
      acoustic,
      acoustic_start,
      @wfst.Label::Symbol("k"),
      @wfst.Label::Symbol("K"),
      acoustic_end,
      @wfst.tropical_cost(2).unwrap(),
    ),
  )

  let lexicon = @wfst.transducer_builder(semiring)
  let lexicon_start = @wfst.add_state(lexicon)
  let lexicon_end = @wfst.add_state(lexicon)
  ignore(@wfst.set_start(lexicon, lexicon_start))
  ignore(@wfst.set_final(lexicon, lexicon_end, @wfst.tropical_cost(1).unwrap()))
  ignore(
    @wfst.add_arc(
      lexicon,
      lexicon_start,
      @wfst.Label::Symbol("K"),
      @wfst.Label::Symbol("cat"),
      lexicon_end,
      @wfst.tropical_cost(3).unwrap(),
    ),
  )

  let combined = @wfst.compose(
    @wfst.build_transducer(acoustic),
    @wfst.build_transducer(lexicon),
  ).unwrap()
  let best = @wfst.shortest_path(combined, @wfst.tropical_path_order()).unwrap()
  let output = @wfst.accepting_path_steps(best)[0].arc.output
  let word = match output {
    @wfst.Label::Symbol(text) => text
    @wfst.Label::Epsilon => "<epsilon>"
  }
  let cost = @wfst.tropical_value(@wfst.accepting_path_total_weight(best)).unwrap()
  println(
    "speech lattice composed with lexicon: " +
    word +
    ", total cost=" +
    cost.to_string(),
  )
}
