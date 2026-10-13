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

///|
fn tropical_value_of(weight : @moon-wfst.TropicalWeight) -> Int {
  @moon-wfst.tropical_value(weight).unwrap()
}

///|
test "shortest path uses tropical costs and includes final weight" {
  let semiring = @moon-wfst.tropical_semiring()
  let builder = @moon-wfst.transducer_builder(semiring)
  let start = @moon-wfst.add_state(builder)
  let via_fast = @moon-wfst.add_state(builder)
  let via_slow = @moon-wfst.add_state(builder)
  let goal = @moon-wfst.add_state(builder)
  ignore(@moon-wfst.set_start(builder, start))
  ignore(
    @moon-wfst.set_final(builder, goal, @moon-wfst.tropical_cost(3).unwrap()),
  )
  ignore(
    @moon-wfst.add_arc(
      builder,
      start,
      @moon-wfst.Label::Symbol("a"),
      @moon-wfst.Label::Symbol("x"),
      via_fast,
      @moon-wfst.tropical_cost(2).unwrap(),
    ),
  )
  ignore(
    @moon-wfst.add_arc(
      builder,
      via_fast,
      @moon-wfst.Label::Symbol("b"),
      @moon-wfst.Label::Symbol("y"),
      goal,
      @moon-wfst.tropical_cost(2).unwrap(),
    ),
  )
  ignore(
    @moon-wfst.add_arc(
      builder,
      start,
      @moon-wfst.Label::Symbol("c"),
      @moon-wfst.Label::Symbol("z"),
      via_slow,
      @moon-wfst.tropical_cost(1).unwrap(),
    ),
  )
  ignore(
    @moon-wfst.add_arc(
      builder,
      via_slow,
      @moon-wfst.Label::Symbol("d"),
      @moon-wfst.Label::Symbol("w"),
      goal,
      @moon-wfst.tropical_cost(10).unwrap(),
    ),
  )
  let path = @moon-wfst.shortest_path(
    @moon-wfst.build_transducer(builder),
    @moon-wfst.tropical_path_order(),
  ).unwrap()
  let states = @moon-wfst.accepting_path_states(path)
  assert_eq(states.length(), 3)
  assert_eq(states[0], start)
  assert_eq(states[1], via_fast)
  assert_eq(states[2], goal)
  assert_eq(@moon-wfst.accepting_path_steps(path).length(), 2)
  assert_eq(tropical_value_of(@moon-wfst.accepting_path_total_weight(path)), 7)
  assert_eq(tropical_value_of(@moon-wfst.accepting_path_final_weight(path)), 3)
}

///|
test "shortest path reports missing start and disconnected finals" {
  let semiring = @moon-wfst.tropical_semiring()
  let no_start = @moon-wfst.transducer_builder(semiring)
  ignore(@moon-wfst.add_state(no_start))
  assert_true(
    @moon-wfst.shortest_path(
      @moon-wfst.build_transducer(no_start),
      @moon-wfst.tropical_path_order(),
    )
    is Err(@moon-wfst.NoStartState),
  )

  let builder = @moon-wfst.transducer_builder(semiring)
  let start = @moon-wfst.add_state(builder)
  let disconnected = @moon-wfst.add_state(builder)
  ignore(@moon-wfst.set_start(builder, start))
  ignore(
    @moon-wfst.set_final(
      builder,
      disconnected,
      @moon-wfst.tropical_cost(0).unwrap(),
    ),
  )
  assert_true(
    @moon-wfst.shortest_path(
      @moon-wfst.build_transducer(builder),
      @moon-wfst.tropical_path_order(),
    )
    is Err(@moon-wfst.NoAcceptingPath),
  )
}

///|
test "shortest path rejects negative weights before search" {
  let integer_semiring : @moon-wfst.Semiring[Int] = {
    zero: 999999,
    one: 0,
    plus: (left, right) => if left < right { left } else { right },
    times: (left, right) => left + right,
  }
  let order = @moon-wfst.path_order(
    (left, right) => {
      if left < right {
        -1
      } else if left > right {
        1
      } else {
        0
      }
    },
    weight => weight >= 0,
    weight => weight == 999999,
  )
  let builder = @moon-wfst.transducer_builder(integer_semiring)
  let start = @moon-wfst.add_state(builder)
  let disconnected = @moon-wfst.add_state(builder)
  ignore(@moon-wfst.set_start(builder, start))
  ignore(
    @moon-wfst.add_arc(
      builder,
      disconnected,
      @moon-wfst.Label::Symbol("n"),
      @moon-wfst.Label::Symbol("n"),
      disconnected,
      -1,
    ),
  )
  assert_true(
    @moon-wfst.shortest_path(@moon-wfst.build_transducer(builder), order)
    is Err(@moon-wfst.NegativeWeight),
  )
}

///|
test "shortest path breaks equal costs by state id" {
  let semiring = @moon-wfst.tropical_semiring()
  let builder = @moon-wfst.transducer_builder(semiring)
  let start = @moon-wfst.add_state(builder)
  let first = @moon-wfst.add_state(builder)
  let second = @moon-wfst.add_state(builder)
  ignore(@moon-wfst.set_start(builder, start))
  ignore(
    @moon-wfst.set_final(builder, first, @moon-wfst.tropical_cost(0).unwrap()),
  )
  ignore(
    @moon-wfst.set_final(builder, second, @moon-wfst.tropical_cost(0).unwrap()),
  )
  ignore(
    @moon-wfst.add_arc(
      builder,
      start,
      @moon-wfst.Label::Symbol("a"),
      @moon-wfst.Label::Symbol("a"),
      first,
      @moon-wfst.tropical_cost(1).unwrap(),
    ),
  )
  ignore(
    @moon-wfst.add_arc(
      builder,
      start,
      @moon-wfst.Label::Symbol("b"),
      @moon-wfst.Label::Symbol("b"),
      second,
      @moon-wfst.tropical_cost(1).unwrap(),
    ),
  )
  let path = @moon-wfst.shortest_path(
    @moon-wfst.build_transducer(builder),
    @moon-wfst.tropical_path_order(),
  ).unwrap()
  assert_eq(@moon-wfst.accepting_path_states(path)[1], first)
}

///|
test "clearing a final state and invalid reads remain typed" {
  let builder = @moon-wfst.transducer_builder(@moon-wfst.boolean_semiring())
  let only = @moon-wfst.add_state(builder)
  assert_true(@moon-wfst.set_final(builder, only, true) is Ok(_))
  assert_eq(
    @moon-wfst.transducer_final_weight(
      @moon-wfst.build_transducer(builder),
      only,
    ).unwrap(),
    Some(true),
  )
  assert_true(@moon-wfst.clear_final(builder, only) is Ok(_))
  let graph = @moon-wfst.build_transducer(builder)
  assert_eq(@moon-wfst.transducer_final_weight(graph, only).unwrap(), None)
  assert_true(
    @moon-wfst.transducer_final_weight(graph, 2)
    is Err(@moon-wfst.InvalidStateId(2)),
  )
  assert_true(
    @moon-wfst.transducer_arcs_from(graph, -1)
    is Err(@moon-wfst.InvalidStateId(-1)),
  )
}

///|
test "mutating an outgoing-arc copy does not change the graph" {
  let builder = @moon-wfst.transducer_builder(@moon-wfst.boolean_semiring())
  let from = @moon-wfst.add_state(builder)
  let to = @moon-wfst.add_state(builder)
  ignore(
    @moon-wfst.add_arc(
      builder,
      from,
      @moon-wfst.Label::Symbol("a"),
      @moon-wfst.Label::Symbol("b"),
      to,
      true,
    ),
  )
  let graph = @moon-wfst.build_transducer(builder)
  let copied = @moon-wfst.transducer_arcs_from(graph, from).unwrap()
  copied.push({
    input: @moon-wfst.Label::Symbol("c"),
    output: @moon-wfst.Label::Symbol("d"),
    destination: to,
    weight: true,
  })
  assert_eq(copied.length(), 2)
  assert_eq(@moon-wfst.transducer_arcs_from(graph, from).unwrap().length(), 1)
}

///|
test "composition with no matching intermediate symbols is empty" {
  let ops = @moon-wfst.boolean_semiring()
  let left_builder = @moon-wfst.transducer_builder(ops)
  let left_start = @moon-wfst.add_state(left_builder)
  let left_end = @moon-wfst.add_state(left_builder)
  ignore(@moon-wfst.set_start(left_builder, left_start))
  ignore(@moon-wfst.set_final(left_builder, left_end, true))
  ignore(
    @moon-wfst.add_arc(
      left_builder,
      left_start,
      @moon-wfst.Label::Symbol("a"),
      @moon-wfst.Label::Symbol("x"),
      left_end,
      true,
    ),
  )
  let right_builder = @moon-wfst.transducer_builder(ops)
  let right_start = @moon-wfst.add_state(right_builder)
  let right_end = @moon-wfst.add_state(right_builder)
  ignore(@moon-wfst.set_start(right_builder, right_start))
  ignore(@moon-wfst.set_final(right_builder, right_end, true))
  ignore(
    @moon-wfst.add_arc(
      right_builder,
      right_start,
      @moon-wfst.Label::Symbol("different"),
      @moon-wfst.Label::Symbol("b"),
      right_end,
      true,
    ),
  )
  let result = @moon-wfst.compose(
    @moon-wfst.build_transducer(left_builder),
    @moon-wfst.build_transducer(right_builder),
  ).unwrap()
  assert_eq(@moon-wfst.transducer_state_count(result), 1)
  assert_eq(@moon-wfst.transducer_arcs_from(result, 0).unwrap().length(), 0)
  assert_eq(@moon-wfst.transducer_final_weight(result, 0).unwrap(), None)
}

///|
test "a zero-arc accepting path includes only its final weight" {
  let semiring = @moon-wfst.tropical_semiring()
  let builder = @moon-wfst.transducer_builder(semiring)
  let start = @moon-wfst.add_state(builder)
  ignore(@moon-wfst.set_start(builder, start))
  ignore(
    @moon-wfst.set_final(builder, start, @moon-wfst.tropical_cost(6).unwrap()),
  )
  let path = @moon-wfst.shortest_path(
    @moon-wfst.build_transducer(builder),
    @moon-wfst.tropical_path_order(),
  ).unwrap()
  assert_eq(@moon-wfst.accepting_path_states(path).length(), 1)
  assert_eq(@moon-wfst.accepting_path_steps(path).length(), 0)
  assert_eq(tropical_value_of(@moon-wfst.accepting_path_total_weight(path)), 6)
}

///|
test "negative terminal costs are rejected" {
  let operations : @moon-wfst.Semiring[Int] = {
    zero: 999,
    one: 0,
    plus: (left, right) => if left < right { left } else { right },
    times: (left, right) => left + right,
  }
  let ordering = @moon-wfst.path_order(
    (left, right) => {
      if left < right {
        -1
      } else if left > right {
        1
      } else {
        0
      }
    },
    weight => weight >= 0,
    weight => weight == 999,
  )
  let builder = @moon-wfst.transducer_builder(operations)
  let state = @moon-wfst.add_state(builder)
  ignore(@moon-wfst.set_start(builder, state))
  ignore(@moon-wfst.set_final(builder, state, -2))
  assert_true(
    @moon-wfst.shortest_path(@moon-wfst.build_transducer(builder), ordering)
    is Err(@moon-wfst.NegativeWeight),
  )
}
