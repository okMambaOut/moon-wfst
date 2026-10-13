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
