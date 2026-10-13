///|
test "epsilon is distinct from an empty symbol" {
  assert_true(@moon-wfst.label_is_epsilon(@moon-wfst.Label::Epsilon))
  assert_true(!@moon-wfst.label_is_epsilon(@moon-wfst.Label::Symbol("")))
  assert_eq(@moon-wfst.Label::Symbol(""), @moon-wfst.Label::Symbol(""))
}

///|
test "semiring operations are caller supplied" {
  let integers : @moon-wfst.Semiring[Int] = {
    zero: 0,
    one: 1,
    plus: (left, right) => left + right,
    times: (left, right) => left * right,
  }
  assert_eq((integers.plus)(2, 5), 7)
  assert_eq((integers.times)(3, 4), 12)
}

///|
test "Boolean semiring follows reachability algebra" {
  let bools = @moon-wfst.boolean_semiring()
  assert_true(@moon-wfst.semiring_zero(bools) == false)
  assert_true(@moon-wfst.semiring_one(bools))
  assert_true(@moon-wfst.semiring_plus(bools, false, true))
  assert_true(!@moon-wfst.semiring_times(bools, true, false))
  assert_true(@moon-wfst.semiring_times(bools, true, true))
}

///|
test "tropical costs reject negative and reserved values" {
  assert_true(@moon-wfst.tropical_cost(-1) is Err(@moon-wfst.NegativeWeight))
  assert_true(
    @moon-wfst.tropical_cost(2147483647) is Err(@moon-wfst.WeightOutOfRange),
  )
  assert_eq(
    @moon-wfst.tropical_value(@moon-wfst.tropical_cost(12).unwrap()),
    Some(12),
  )
}

///|
test "tropical semiring chooses minimum and saturates safely" {
  let tropical = @moon-wfst.tropical_semiring()
  let two = @moon-wfst.tropical_cost(2).unwrap()
  let seven = @moon-wfst.tropical_cost(7).unwrap()
  assert_eq(
    @moon-wfst.tropical_value(@moon-wfst.semiring_plus(tropical, seven, two)),
    Some(2),
  )
  assert_eq(
    @moon-wfst.tropical_value(@moon-wfst.semiring_times(tropical, two, seven)),
    Some(9),
  )
  let near_limit = @moon-wfst.tropical_cost(2147483646).unwrap()
  assert_true(
    @moon-wfst.tropical_is_infinite(
      @moon-wfst.semiring_times(tropical, near_limit, two),
    ),
  )
  assert_eq(
    @moon-wfst.tropical_compare(@moon-wfst.tropical_infinity(), seven),
    1,
  )
}

///|
test "builder validates states and arc endpoints" {
  let builder = @moon-wfst.transducer_builder(@moon-wfst.boolean_semiring())
  let first = @moon-wfst.add_state(builder)
  let second = @moon-wfst.add_state(builder)
  assert_eq(first, 0)
  assert_eq(second, 1)
  assert_true(
    @moon-wfst.set_start(builder, -1) is Err(@moon-wfst.InvalidStateId(-1)),
  )
  assert_true(
    @moon-wfst.add_arc(
      builder,
      first,
      @moon-wfst.Label::Symbol("a"),
      @moon-wfst.Label::Symbol("b"),
      8,
      true,
    )
    is Err(@moon-wfst.InvalidStateId(8)),
  )
  assert_true(
    @moon-wfst.add_arc(
      builder,
      9,
      @moon-wfst.Label::Epsilon,
      @moon-wfst.Label::Epsilon,
      second,
      true,
    )
    is Err(@moon-wfst.InvalidStateId(9)),
  )
}

///|
test "built graph is a stable snapshot and exposes copied arcs" {
  let builder = @moon-wfst.transducer_builder(@moon-wfst.boolean_semiring())
  let start = @moon-wfst.add_state(builder)
  let final_id = @moon-wfst.add_state(builder)
  assert_true(@moon-wfst.set_start(builder, start) is Ok(_))
  assert_true(@moon-wfst.set_final(builder, final_id, true) is Ok(_))
  assert_true(
    @moon-wfst.add_arc(
      builder,
      start,
      @moon-wfst.Label::Symbol("x"),
      @moon-wfst.Label::Symbol("y"),
      final_id,
      true,
    )
    is Ok(_),
  )
  let snapshot = @moon-wfst.build_transducer(builder)
  assert_eq(@moon-wfst.transducer_state_count(snapshot), 2)
  assert_eq(@moon-wfst.transducer_start_state(snapshot), Some(0))
  assert_eq(
    @moon-wfst.transducer_arcs_from(snapshot, start).unwrap().length(),
    1,
  )
  assert_eq(
    @moon-wfst.transducer_final_weight(snapshot, final_id).unwrap(),
    Some(true),
  )
  ignore(@moon-wfst.add_state(builder))
  assert_eq(@moon-wfst.transducer_state_count(snapshot), 2)
  assert_eq(
    @moon-wfst.transducer_state_count(@moon-wfst.build_transducer(builder)),
    3,
  )
}

///|
test "projection and inversion preserve graph structure and weights" {
  let builder = @moon-wfst.transducer_builder(@moon-wfst.boolean_semiring())
  let start = @moon-wfst.add_state(builder)
  let final_id = @moon-wfst.add_state(builder)
  ignore(@moon-wfst.set_start(builder, start))
  ignore(@moon-wfst.set_final(builder, final_id, true))
  ignore(
    @moon-wfst.add_arc(
      builder,
      start,
      @moon-wfst.Label::Symbol("read"),
      @moon-wfst.Label::Symbol("lemma"),
      final_id,
      true,
    ),
  )
  let original = @moon-wfst.build_transducer(builder)
  let input_projection = @moon-wfst.project_input(original)
  let output_projection = @moon-wfst.project_output(original)
  let reversed = @moon-wfst.invert(original)
  let input_arc = @moon-wfst.transducer_arcs_from(input_projection, 0).unwrap()[0]
  let output_arc = @moon-wfst.transducer_arcs_from(output_projection, 0).unwrap()[0]
  let reverse_arc = @moon-wfst.transducer_arcs_from(reversed, 0).unwrap()[0]
  assert_eq(input_arc.input, @moon-wfst.Label::Symbol("read"))
  assert_eq(input_arc.output, @moon-wfst.Label::Symbol("read"))
  assert_eq(output_arc.input, @moon-wfst.Label::Symbol("lemma"))
  assert_eq(output_arc.output, @moon-wfst.Label::Symbol("lemma"))
  assert_eq(reverse_arc.input, @moon-wfst.Label::Symbol("lemma"))
  assert_eq(reverse_arc.output, @moon-wfst.Label::Symbol("read"))
  assert_eq(reverse_arc.weight, true)
  assert_eq(
    @moon-wfst.transducer_final_weight(reversed, final_id).unwrap(),
    Some(true),
  )
}

///|
test "epsilon scan examines input and output labels" {
  let builder = @moon-wfst.transducer_builder(@moon-wfst.boolean_semiring())
  let from = @moon-wfst.add_state(builder)
  let to = @moon-wfst.add_state(builder)
  ignore(
    @moon-wfst.add_arc(
      builder,
      from,
      @moon-wfst.Label::Epsilon,
      @moon-wfst.Label::Symbol("x"),
      to,
      true,
    ),
  )
  let graph = @moon-wfst.build_transducer(builder)
  assert_true(@moon-wfst.transducer_has_epsilon(graph))
  assert_true(
    @moon-wfst.transducer_has_epsilon(@moon-wfst.project_input(graph)),
  )
}

///|
test "composition joins labels and multiplies arc and final weights" {
  let tropical = @moon-wfst.tropical_semiring()
  let left_builder = @moon-wfst.transducer_builder(tropical)
  let left_start = @moon-wfst.add_state(left_builder)
  let left_final = @moon-wfst.add_state(left_builder)
  ignore(@moon-wfst.set_start(left_builder, left_start))
  ignore(
    @moon-wfst.set_final(
      left_builder,
      left_final,
      @moon-wfst.tropical_cost(4).unwrap(),
    ),
  )
  ignore(
    @moon-wfst.add_arc(
      left_builder,
      left_start,
      @moon-wfst.Label::Symbol("a"),
      @moon-wfst.Label::Symbol("x"),
      left_final,
      @moon-wfst.tropical_cost(2).unwrap(),
    ),
  )
  let right_builder = @moon-wfst.transducer_builder(tropical)
  let right_start = @moon-wfst.add_state(right_builder)
  let right_final = @moon-wfst.add_state(right_builder)
  ignore(@moon-wfst.set_start(right_builder, right_start))
  ignore(
    @moon-wfst.set_final(
      right_builder,
      right_final,
      @moon-wfst.tropical_cost(5).unwrap(),
    ),
  )
  ignore(
    @moon-wfst.add_arc(
      right_builder,
      right_start,
      @moon-wfst.Label::Symbol("x"),
      @moon-wfst.Label::Symbol("b"),
      right_final,
      @moon-wfst.tropical_cost(3).unwrap(),
    ),
  )
  let composed = @moon-wfst.compose(
    @moon-wfst.build_transducer(left_builder),
    @moon-wfst.build_transducer(right_builder),
  ).unwrap()
  assert_eq(@moon-wfst.transducer_state_count(composed), 2)
  let arc = @moon-wfst.transducer_arcs_from(composed, 0).unwrap()[0]
  assert_eq(arc.input, @moon-wfst.Label::Symbol("a"))
  assert_eq(arc.output, @moon-wfst.Label::Symbol("b"))
  assert_eq(@moon-wfst.tropical_value(arc.weight), Some(5))
  assert_eq(
    @moon-wfst.tropical_value(
      @moon-wfst.transducer_final_weight(composed, 1).unwrap().unwrap(),
    ),
    Some(9),
  )
}

///|
test "composition keeps only reachable matching state pairs" {
  let ops = @moon-wfst.boolean_semiring()
  let left_builder = @moon-wfst.transducer_builder(ops)
  let left_start = @moon-wfst.add_state(left_builder)
  let left_match = @moon-wfst.add_state(left_builder)
  ignore(@moon-wfst.add_state(left_builder))
  ignore(@moon-wfst.set_start(left_builder, left_start))
  ignore(
    @moon-wfst.add_arc(
      left_builder,
      left_start,
      @moon-wfst.Label::Symbol("a"),
      @moon-wfst.Label::Symbol("join"),
      left_match,
      true,
    ),
  )
  let right_builder = @moon-wfst.transducer_builder(ops)
  let right_start = @moon-wfst.add_state(right_builder)
  let right_match = @moon-wfst.add_state(right_builder)
  ignore(@moon-wfst.add_state(right_builder))
  ignore(@moon-wfst.set_start(right_builder, right_start))
  ignore(
    @moon-wfst.add_arc(
      right_builder,
      right_start,
      @moon-wfst.Label::Symbol("join"),
      @moon-wfst.Label::Symbol("b"),
      right_match,
      true,
    ),
  )
  let result = @moon-wfst.compose(
    @moon-wfst.build_transducer(left_builder),
    @moon-wfst.build_transducer(right_builder),
  ).unwrap()
  assert_eq(@moon-wfst.transducer_state_count(result), 2)
  assert_eq(@moon-wfst.transducer_arcs_from(result, 0).unwrap().length(), 1)
}

///|
test "epsilon composition is rejected on either label side" {
  let ops = @moon-wfst.boolean_semiring()
  let left_builder = @moon-wfst.transducer_builder(ops)
  let left_state = @moon-wfst.add_state(left_builder)
  ignore(@moon-wfst.set_start(left_builder, left_state))
  ignore(
    @moon-wfst.add_arc(
      left_builder,
      left_state,
      @moon-wfst.Label::Symbol("a"),
      @moon-wfst.Label::Epsilon,
      left_state,
      true,
    ),
  )
  let right_builder = @moon-wfst.transducer_builder(ops)
  let right_state = @moon-wfst.add_state(right_builder)
  ignore(@moon-wfst.set_start(right_builder, right_state))
  let result = @moon-wfst.compose(
    @moon-wfst.build_transducer(left_builder),
    @moon-wfst.build_transducer(right_builder),
  )
  assert_true(result is Err(@moon-wfst.UnsupportedEpsilonComposition))
}

///|
test "composition requires explicit starts" {
  let ops = @moon-wfst.boolean_semiring()
  let left_builder = @moon-wfst.transducer_builder(ops)
  ignore(@moon-wfst.add_state(left_builder))
  let right_builder = @moon-wfst.transducer_builder(ops)
  ignore(@moon-wfst.add_state(right_builder))
  assert_true(
    @moon-wfst.compose(
      @moon-wfst.build_transducer(left_builder),
      @moon-wfst.build_transducer(right_builder),
    )
    is Err(@moon-wfst.NoStartState),
  )
}
