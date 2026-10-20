///|
test "tropical machine-integer boundary saturates before overflow" {
  let s = @moon-wfst.tropical_semiring()
  let max = @moon-wfst.tropical_cost(2147483646).unwrap()
  let one = @moon-wfst.tropical_cost(1).unwrap()
  let zero_cost = @moon-wfst.tropical_cost(0).unwrap()
  assert_eq(@moon-wfst.tropical_value(max), Some(2147483646))
  assert_eq(
    @moon-wfst.tropical_value(@moon-wfst.semiring_times(s, max, zero_cost)),
    Some(2147483646),
  )
  assert_true(
    @moon-wfst.tropical_is_infinite(@moon-wfst.semiring_times(s, max, one)),
  )
  assert_true(
    @moon-wfst.tropical_is_infinite(@moon-wfst.semiring_times(s, max, max)),
  )
  assert_true(
    @moon-wfst.tropical_is_infinite(
      @moon-wfst.semiring_times(s, @moon-wfst.tropical_infinity(), zero_cost),
    ),
  )
  assert_true(
    @moon-wfst.tropical_cost(2147483647) is Err(@moon-wfst.WeightOutOfRange),
  )
  assert_true(
    @moon-wfst.tropical_cost(-2147483648) is Err(@moon-wfst.NegativeWeight),
  )
}

///|
test "terminal costs reorder accepting prefixes including empty paths" {
  let b = @moon-wfst.transducer_builder(@moon-wfst.tropical_semiring())
  for _ in 0..<3 {
    @moon-wfst.add_state(b) |> ignore
  }
  @moon-wfst.set_start(b, 0).unwrap()
  @moon-wfst.set_final(b, 0, @moon-wfst.tropical_cost(20).unwrap()).unwrap()
  @moon-wfst.set_final(b, 1, @moon-wfst.tropical_cost(100).unwrap()).unwrap()
  @moon-wfst.set_final(b, 2, @moon-wfst.tropical_cost(0).unwrap()).unwrap()
  @moon-wfst.add_arc(
    b,
    0,
    @moon-wfst.Symbol("a"),
    @moon-wfst.Symbol("A"),
    1,
    @moon-wfst.tropical_cost(0).unwrap(),
  ).unwrap()
  @moon-wfst.add_arc(
    b,
    0,
    @moon-wfst.Symbol("b"),
    @moon-wfst.Symbol("B"),
    2,
    @moon-wfst.tropical_cost(10).unwrap(),
  ).unwrap()
  let g = @moon-wfst.build_transducer(b)
  let order = @moon-wfst.tropical_path_order()
  let best = @moon-wfst.shortest_path(g, order).unwrap()
  assert_eq(@moon-wfst.accepting_path_states(best), [0, 2])
  let paths = @moon-wfst.shortest_paths_in_dag(g, order, 10).unwrap()
  assert_eq(paths.length(), 3)
  assert_eq(
    @moon-wfst.tropical_value(@moon-wfst.accepting_path_total_weight(paths[0])),
    Some(10),
  )
  assert_eq(
    @moon-wfst.tropical_value(@moon-wfst.accepting_path_total_weight(paths[1])),
    Some(20),
  )
  assert_eq(@moon-wfst.accepting_path_states(paths[1]), [0])
  assert_eq(
    @moon-wfst.tropical_value(@moon-wfst.accepting_path_total_weight(paths[2])),
    Some(100),
  )
}

///|
test "epsilon cycles terminate without conflating an empty-string symbol" {
  let b = @moon-wfst.transducer_builder(@moon-wfst.boolean_semiring())
  for _ in 0..<2 {
    @moon-wfst.add_state(b) |> ignore
  }
  @moon-wfst.set_start(b, 0).unwrap()
  @moon-wfst.set_final(b, 1, true).unwrap()
  @moon-wfst.add_arc(b, 0, @moon-wfst.Epsilon, @moon-wfst.Epsilon, 0, true).unwrap()
  @moon-wfst.add_arc(
    b,
    0,
    @moon-wfst.Symbol(""),
    @moon-wfst.Symbol("中😀"),
    1,
    true,
  ).unwrap()
  @moon-wfst.add_arc(b, 0, @moon-wfst.Epsilon, @moon-wfst.Epsilon, 1, false).unwrap()
  let g = @moon-wfst.build_transducer(b)
  assert_eq(@moon-wfst.accepts_pair(g, [], [], w => !w), Ok(false))
  assert_eq(@moon-wfst.accepts_pair(g, [""], ["中😀"], w => !w), Ok(true))
  assert_eq(@moon-wfst.accepts_pair(g, [], ["中😀"], w => !w), Ok(false))
  assert_true(
    @moon-wfst.total_weight_in_dag(g) is Err(@moon-wfst.GraphHasCycle),
  )
}

///|
test "all DAG entry points reject disconnected cycles" {
  let b = @moon-wfst.transducer_builder(@moon-wfst.tropical_semiring())
  for _ in 0..<2 {
    @moon-wfst.add_state(b) |> ignore
  }
  @moon-wfst.set_start(b, 0).unwrap()
  let zero_cost = @moon-wfst.tropical_cost(0).unwrap()
  @moon-wfst.set_final(b, 0, zero_cost).unwrap()
  @moon-wfst.add_arc(b, 1, @moon-wfst.Epsilon, @moon-wfst.Epsilon, 1, zero_cost).unwrap()
  let g = @moon-wfst.build_transducer(b)
  assert_true(@moon-wfst.topological_order(g) is Err(@moon-wfst.GraphHasCycle))
  assert_true(
    @moon-wfst.forward_weights_in_dag(g) is Err(@moon-wfst.GraphHasCycle),
  )
  assert_true(
    @moon-wfst.backward_weights_in_dag(g) is Err(@moon-wfst.GraphHasCycle),
  )
  assert_true(
    @moon-wfst.total_weight_in_dag(g) is Err(@moon-wfst.GraphHasCycle),
  )
  assert_true(
    @moon-wfst.shortest_paths_in_dag(g, @moon-wfst.tropical_path_order(), 1)
    is Err(@moon-wfst.GraphHasCycle),
  )
  assert_eq(
    @moon-wfst.accepting_path_states(
      @moon-wfst.shortest_path(g, @moon-wfst.tropical_path_order()).unwrap(),
    ),
    [0],
  )
}

///|
test "missing starts denote empty relations in union and concatenation" {
  let b = @moon-wfst.transducer_builder(@moon-wfst.boolean_semiring())
  @moon-wfst.add_state(b) |> ignore
  @moon-wfst.set_final(b, 0, true).unwrap()
  let missing = @moon-wfst.build_transducer(b)
  @moon-wfst.set_start(b, 0).unwrap()
  let started = @moon-wfst.build_transducer(b)
  assert_eq(
    @moon-wfst.total_weight_in_dag(
      @moon-wfst.concatenate_transducers(started, missing),
    ),
    Ok(false),
  )
  assert_eq(
    @moon-wfst.total_weight_in_dag(
      @moon-wfst.concatenate_transducers(missing, started),
    ),
    Ok(false),
  )
  assert_eq(
    @moon-wfst.total_weight_in_dag(
      @moon-wfst.union_transducers(missing, missing),
    ),
    Ok(false),
  )
  assert_eq(
    @moon-wfst.total_weight_in_dag(
      @moon-wfst.union_transducers(started, missing),
    ),
    Ok(true),
  )
  assert_eq(
    @moon-wfst.accepts_pair(
      @moon-wfst.union_transducers(started, missing),
      [],
      [],
      w => !w,
    ),
    Ok(true),
  )
}

///|
test "topological ready queue follows insertion order after initial states" {
  let b = @moon-wfst.transducer_builder(@moon-wfst.boolean_semiring())
  for _ in 0..<4 {
    @moon-wfst.add_state(b) |> ignore
  }
  @moon-wfst.add_arc(b, 0, @moon-wfst.Epsilon, @moon-wfst.Epsilon, 3, true).unwrap()
  @moon-wfst.add_arc(b, 0, @moon-wfst.Epsilon, @moon-wfst.Epsilon, 2, true).unwrap()
  assert_eq(
    @moon-wfst.topological_order(@moon-wfst.build_transducer(b)),
    Ok([0, 1, 3, 2]),
  )
}
