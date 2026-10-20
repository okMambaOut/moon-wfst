///|
test "review R001 snapshots isolate topology and explicit final changes" {
  let builder = @moon-wfst.transducer_builder(@moon-wfst.boolean_semiring())
  let start = @moon-wfst.add_state(builder)
  let finish = @moon-wfst.add_state(builder)
  @moon-wfst.set_start(builder, start).unwrap()
  @moon-wfst.set_final(builder, finish, true).unwrap()
  @moon-wfst.add_arc(
    builder,
    start,
    @moon-wfst.Symbol("中😀"),
    @moon-wfst.Symbol(""),
    finish,
    true,
  ).unwrap()
  let graph = @moon-wfst.build_transducer(builder)
  @moon-wfst.clear_final(builder, finish).unwrap()
  @moon-wfst.set_start(builder, finish).unwrap()
  @moon-wfst.add_state(builder) |> ignore
  assert_eq(@moon-wfst.transducer_state_count(graph), 2)
  assert_eq(@moon-wfst.transducer_start_state(graph), Some(start))
  assert_eq(@moon-wfst.transducer_final_weight(graph, finish), Ok(Some(true)))
  let arcs = @moon-wfst.transducer_arcs_from(graph, start).unwrap()
  arcs.clear()
  let incoming = @moon-wfst.transducer_incoming_arcs(graph, finish).unwrap()
  incoming.clear()
  assert_eq(@moon-wfst.transducer_stats(graph).arc_count, 1)
  assert_eq(
    @moon-wfst.accepts_pair(graph, ["中😀"], [""], w => !w),
    Ok(true),
  )
  assert_true(
    @moon-wfst.add_arc(
      builder,
      start,
      @moon-wfst.Epsilon,
      @moon-wfst.Epsilon,
      999,
      true,
    )
    is Err(@moon-wfst.InvalidStateId(999)),
  )
  assert_eq(@moon-wfst.transducer_stats(graph).arc_count, 1)
}

///|
test "review R001 accepting path accessors cannot corrupt traces" {
  let builder = @moon-wfst.transducer_builder(@moon-wfst.tropical_semiring())
  let start = @moon-wfst.add_state(builder)
  let finish = @moon-wfst.add_state(builder)
  @moon-wfst.set_start(builder, start).unwrap()
  @moon-wfst.set_final(builder, finish, @moon-wfst.tropical_cost(2).unwrap()).unwrap()
  @moon-wfst.add_arc(
    builder,
    start,
    @moon-wfst.Symbol("x"),
    @moon-wfst.Symbol("y"),
    finish,
    @moon-wfst.tropical_cost(3).unwrap(),
  ).unwrap()
  let graph = @moon-wfst.build_transducer(builder)
  let path = @moon-wfst.shortest_path(graph, @moon-wfst.tropical_path_order()).unwrap()
  let states = @moon-wfst.accepting_path_states(path)
  states[0] = 999
  let steps = @moon-wfst.accepting_path_steps(path)
  steps.clear()
  assert_eq(@moon-wfst.accepting_path_states(path), [start, finish])
  assert_eq(@moon-wfst.accepting_path_steps(path).length(), 1)
  assert_eq(
    @moon-wfst.tropical_value(@moon-wfst.accepting_path_total_weight(path)),
    Some(5),
  )
  assert_eq(@moon-wfst.transducer_stats(graph).arc_count, 1)
}

///|
test "review R001 trim mapping accessor returns isolated copies" {
  let builder = @moon-wfst.transducer_builder(@moon-wfst.boolean_semiring())
  let removed = @moon-wfst.add_state(builder)
  let kept = @moon-wfst.add_state(builder)
  @moon-wfst.set_start(builder, kept).unwrap()
  @moon-wfst.set_final(builder, kept, true).unwrap()
  let result = @moon-wfst.trim(@moon-wfst.build_transducer(builder))
  let mapping = @moon-wfst.trim_result_state_mapping(result)
  mapping[removed] = Some(999)
  mapping.clear()
  assert_eq(@moon-wfst.trim_result_state_mapping(result), [None, Some(0)])
  assert_eq(
    @moon-wfst.transducer_state_count(@moon-wfst.trim_result_transducer(result)),
    1,
  )
}
