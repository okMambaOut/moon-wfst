///|
fn main {
  let semiring = @wfst.tropical_semiring()
  let morphology = @wfst.transducer_builder(semiring)
  let start = @wfst.add_state(morphology)
  let accepting = @wfst.add_state(morphology)
  ignore(@wfst.set_start(morphology, start))
  ignore(
    @wfst.set_final(morphology, accepting, @wfst.tropical_cost(0).unwrap()),
  )

  // Two analyses share the surface form; the lower-cost path is selected.
  ignore(
    @wfst.add_arc(
      morphology,
      start,
      @wfst.Label::Symbol("went"),
      @wfst.Label::Symbol("go+PAST"),
      accepting,
      @wfst.tropical_cost(1).unwrap(),
    ),
  )
  ignore(
    @wfst.add_arc(
      morphology,
      start,
      @wfst.Label::Symbol("went"),
      @wfst.Label::Symbol("went+NOUN"),
      accepting,
      @wfst.tropical_cost(4).unwrap(),
    ),
  )

  let analyzer = @wfst.project_output(@wfst.build_transducer(morphology))
  let best = @wfst.shortest_path(analyzer, @wfst.tropical_path_order()).unwrap()
  let analysis = match @wfst.accepting_path_steps(best)[0].arc.output {
    @wfst.Label::Symbol(text) => text
    @wfst.Label::Epsilon => "<epsilon>"
  }
  let cost = @wfst.tropical_value(@wfst.accepting_path_total_weight(best)).unwrap()
  println(
    "morphology analysis for went: " + analysis + ", cost=" + cost.to_string(),
  )
}
