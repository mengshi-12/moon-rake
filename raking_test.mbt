///|
fn row(
  id : String,
  cells : Array[String],
  base? : Double = 1.0,
  lower? : Double = 0.001,
  upper? : Double = 1000.0,
) -> @moon-rake.Row {
  { id, cells, base_weight: base, lower, upper, }
}

///|
fn margin(
  name : String,
  targets : Array[(String, Double)],
) -> @moon-rake.Margin {
  { name, targets: targets.map(fn(p) { { category: p.0, total: p.1, } }), }
}

///|
fn problem() -> @moon-rake.Problem {
  {
    rows: [
      row("a", ["F", "N"]),
      row("b", ["F", "S"]),
      row("c", ["M", "N"]),
      row("d", ["M", "S"]),
    ],
    margins: [
      margin("gender", [("F", 60.0), ("M", 40.0)]),
      margin("region", [("N", 50.0), ("S", 50.0)]),
    ],
  }
}

///|
fn near(a : Double, b : Double, tolerance? : Double = 1.0e-6) -> Unit raise {
  assert_true((a - b).abs() <= tolerance)
}

///|
test "balanced two-margin survey has analytic weights and a complete residual check" {
  let p = problem()
  let result = @moon-rake.fit(p).unwrap()
  assert_eq(result.status, @moon-rake.Converged)
  for i, value in [30.0, 30.0, 20.0, 20.0] {
    near(result.weights[i].weight, value)
  }
  near(result.diagnostics.total_weight, 100.0)
  near(result.diagnostics.effective_sample_size, 10000.0 / 2600.0)
  assert_true(result.diagnostics.passes)
  assert_true(
    @moon-rake.evaluate(p, result.weights.map(fn(w) { w.weight })).unwrap().passes,
  )
}

///|
test "nonuniform 2 by 2 seed matches the independent odds-ratio solution" {
  let p : @moon-rake.Problem = {
    rows: [
      row("a", ["R1", "C1"], base=1.0),
      row("b", ["R1", "C2"], base=2.0),
      row("c", ["R2", "C1"], base=3.0),
      row("d", ["R2", "C2"], base=4.0),
    ],
    margins: [
      margin("rows", [("R1", 40.0), ("R2", 60.0)]),
      margin("columns", [("C1", 30.0), ("C2", 70.0)]),
    ],
  }
  let r = @moon-rake.fit(p).unwrap()
  assert_eq(r.status, @moon-rake.Converged)
  for i, expected in [10.0, 30.0, 20.0, 40.0] {
    near(r.weights[i].weight, expected)
  }
  near(
    r.weights[0].weight *
    r.weights[3].weight /
    (r.weights[1].weight * r.weights[2].weight),
    2.0 / 3.0,
  )
}

///|
test "absolute bounds redistribute remainder instead of clipping and declaring success" {
  let p : @moon-rake.Problem = {
    rows: [
      row("a", ["all"], base=3.0, lower=1.0, upper=4.0),
      row("b", ["all"], lower=1.0, upper=20.0),
    ],
    margins: [margin("total", [("all", 10.0)])],
  }
  let r = @moon-rake.fit(p).unwrap()
  near(r.weights[0].weight, 4.0)
  near(r.weights[1].weight, 6.0)
  assert_true(r.diagnostics.passes)
  let upstream = @moon-rake.oneway_baseline(p).unwrap()
  near(upstream.weights[0].weight, 7.5)
  assert_eq(upstream.status, @moon-rake.BaselineRejected)
  assert_eq(upstream.diagnostics.bounds_violations, 1)
  assert_false(upstream.diagnostics.passes)
}

///|
test "176 one-margin bound cases match independently clipped analytic optima" {
  for a in 1..<=4 {
    for b in 1..<=4 {
      for target in 2..<=12 {
        let t = target.to_double()
        let p : @moon-rake.Problem = {
          rows: [
            row("a", ["x"], base=a.to_double(), lower=1.0, upper=5.0),
            row("b", ["x"], base=b.to_double(), lower=1.0, upper=8.0),
          ],
          margins: [margin("m", [("x", t)])],
        }
        let r = @moon-rake.fit(p).unwrap()
        let low = if t - 8.0 > 1.0 { t - 8.0 } else { 1.0 }
        let high = if t - 1.0 < 5.0 { t - 1.0 } else { 5.0 }
        let raw = t * a.to_double() / (a + b).to_double()
        let expected = if raw < low {
          low
        } else if raw > high {
          high
        } else {
          raw
        }
        assert_eq(r.status, @moon-rake.Converged)
        near(r.weights[0].weight, expected)
        near(r.weights[1].weight, t - expected)
      }
    }
  }
}

///|
test "single-margin interoperability agrees with moon-causal baseline" {
  let p : @moon-rake.Problem = {
    rows: [
      row("a", ["A"], base=2.0),
      row("b", ["A"], base=3.0),
      row("c", ["B"], base=4.0),
    ],
    margins: [margin("m", [("A", 15.0), ("B", 12.0)])],
  }
  let ours = @moon-rake.fit(p).unwrap()
  let upstream = @moon-rake.oneway_baseline(p).unwrap()
  for i, w in ours.weights {
    near(w.weight, upstream.weights[i].weight)
  }
  assert_true(upstream.diagnostics.passes)
  assert_eq(
    @moon-rake.oneway_baseline(problem()).unwrap_err(),
    @moon-rake.NotOneWay,
  )
}

///|
test "jointly incompatible supported margins exhaust budget rather than claim convergence" {
  let p : @moon-rake.Problem = {
    rows: [row("a", ["A", "X"]), row("b", ["B", "Y"])],
    margins: [
      margin("m1", [("A", 60.0), ("B", 40.0)]),
      margin("m2", [("X", 50.0), ("Y", 50.0)]),
    ],
  }
  let r = @moon-rake.fit(p, options={ max_iterations: 5, tolerance: 1.0e-8, }).unwrap()
  assert_eq(r.status, @moon-rake.IterationLimit)
  assert_eq(r.iterations, 5)
  assert_eq(r.trace.length(), 5)
  assert_false(r.diagnostics.passes)
  near(r.diagnostics.maximum_error, 0.25)
}

///|
test "impossible group bound and absent positive support are explicit errors" {
  let p : @moon-rake.Problem = {
    rows: [row("a", ["A"], upper=4.0)],
    margins: [margin("m", [("A", 5.0)])],
  }
  assert_eq(
    @moon-rake.fit(p).unwrap_err(),
    @moon-rake.InfeasibleMargin("m", "A"),
  )
  assert_eq(
    @moon-rake.fit({ ..p, margins: [margin("m", [("A", 1.0), ("B", 2.0)])], }).unwrap_err(),
    @moon-rake.InfeasibleMargin("m", "B"),
  )
}

///|
test "fixed structural-zero rows remain zero and empty zero categories are valid" {
  let p : @moon-rake.Problem = {
    rows: [row("a", ["A"]), row("z", ["Z"], base=0.0, lower=0.0, upper=0.0)],
    margins: [margin("m", [("A", 5.0), ("Z", 0.0), ("empty", 0.0)])],
  }
  let r = @moon-rake.fit(p).unwrap()
  near(r.weights[0].weight, 5.0)
  near(r.weights[1].weight, 0.0)
  assert_true(r.diagnostics.passes)
}

///|
test "zero support cannot satisfy even a tiny positive target via tolerance" {
  let p : @moon-rake.Problem = {
    rows: [row("a", ["A"]), row("z", ["Z"], base=0.0, lower=0.0, upper=0.0)],
    margins: [margin("m", [("A", 1.0), ("Z", 1.0e-12)])],
  }
  assert_eq(
    @moon-rake.fit(p).unwrap_err(),
    @moon-rake.InfeasibleMargin("m", "Z"),
  )
}

///|
test "already calibrated problem returns zero iterations" {
  let p : @moon-rake.Problem = {
    rows: [row("a", ["A"], base=5.0)],
    margins: [margin("m", [("A", 5.0)])],
  }
  let r = @moon-rake.fit(p).unwrap()
  assert_eq(r.iterations, 0)
  assert_eq(r.trace, [])
}

///|
test "external audit maps original row order and reports bounds without clipping" {
  let p : @moon-rake.Problem = {
    rows: [row("b", ["B"], upper=3.0), row("a", ["A"], upper=20.0)],
    margins: [margin("m", [("A", 8.0), ("B", 2.0)])],
  }
  assert_true(@moon-rake.evaluate(p, [2.0, 8.0]).unwrap().passes)
  let bad = @moon-rake.evaluate(p, [5.0, 5.0]).unwrap()
  assert_eq(bad.bounds_violations, 1)
  assert_false(bad.passes)
  assert_eq(
    @moon-rake.evaluate(p, [2.0]).unwrap_err(),
    @moon-rake.InvalidWeights,
  )
}

///|
test "row permutation preserves ID-associated fit and caller input" {
  let p = problem()
  let reversed = { ..p, rows: [p.rows[3], p.rows[2], p.rows[1], p.rows[0]], }
  let a = @moon-rake.fit(p).unwrap()
  let b = @moon-rake.fit(reversed).unwrap()
  assert_eq(a.weights, b.weights)
  assert_eq(reversed.rows[0].id, "d")
  assert_eq(p.rows[0].base_weight, 1.0)
}

///|
test "unknown categories duplicate targets and unequal total populations fail" {
  let p = problem()
  assert_eq(
    @moon-rake.fit({ ..p, rows: [row("x", ["unknown", "N"])], }).unwrap_err(),
    @moon-rake.UnknownCategory("gender", "unknown"),
  )
  let one : @moon-rake.Problem = {
    rows: [row("a", ["A"])],
    margins: [margin("m", [("A", 1.0), ("A", 2.0)])],
  }
  assert_eq(@moon-rake.fit(one).unwrap_err(), @moon-rake.InvalidMargin("m"))
  let unequal = {
    ..p,
    margins: [p.margins[0], margin("region", [("N", 40.0), ("S", 40.0)])],
  }
  assert_eq(@moon-rake.fit(unequal).unwrap_err(), @moon-rake.InconsistentTotals)
}

///|
test "invalid row widths base weights and IDs are rejected" {
  let p = problem()
  assert_eq(
    @moon-rake.fit({ ..p, rows: [row("x", ["F"])], }).unwrap_err(),
    @moon-rake.InvalidRow("x"),
  )
  assert_eq(
    @moon-rake.fit({ ..p, rows: [row("x", ["F", "N"], base=0.0)], }).unwrap_err(),
    @moon-rake.InvalidRow("x"),
  )
  assert_eq(
    @moon-rake.fit({ ..p, rows: [p.rows[0], p.rows[0]], }).unwrap_err(),
    @moon-rake.DuplicateRow("a"),
  )
}

///|
test "NaN infinity and invalid budgets do not masquerade as convergence" {
  let p = problem()
  assert_eq(
    @moon-rake.fit(p, options={ max_iterations: 0, tolerance: 1.0e-8, }).unwrap_err(),
    @moon-rake.InvalidOptions,
  )
  assert_eq(
    @moon-rake.fit(p, options={ max_iterations: 5, tolerance: 0.0 / 0.0, }).unwrap_err(),
    @moon-rake.InvalidOptions,
  )
  assert_eq(
    @moon-rake.fit({ ..p, rows: [row("x", ["F", "N"], base=1.0 / 0.0)], }).unwrap_err(),
    @moon-rake.InvalidRow("x"),
  )
  assert_eq(
    @moon-rake.evaluate(p, [1.0, 1.0, 1.0, 0.0 / 0.0]).unwrap_err(),
    @moon-rake.InvalidWeights,
  )
}

///|
test "weighted mean validates shapes and normalizes subnormal weight scales" {
  near(@moon-rake.weighted_mean([10.0, 20.0], [1.0, 3.0]).unwrap(), 17.5)
  near(
    @moon-rake.weighted_mean([10.0, 20.0], [1.0e-320, 3.0e-320]).unwrap(),
    17.5,
    tolerance=0.001,
  )
  assert_eq(
    @moon-rake.weighted_mean([1.0], [1.0, 2.0]).unwrap_err(),
    @moon-rake.InvalidWeights,
  )
  assert_eq(
    @moon-rake.weighted_mean([1.0], [0.0]).unwrap_err(),
    @moon-rake.InvalidWeights,
  )
}

///|
test "extreme supported projection ratios remain finite and bounded" {
  let p : @moon-rake.Problem = {
    rows: [row("a", ["A"], base=1.0e12, lower=1.0e-12, upper=1.0e12)],
    margins: [margin("m", [("A", 1.0e-12)])],
  }
  let r = @moon-rake.fit(p, options={ max_iterations: 2, tolerance: 1.0e-10, }).unwrap()
  assert_eq(r.status, @moon-rake.Converged)
  assert_true(r.weights[0].weight >= 1.0e-12)
  assert_true(r.weights[0].weight < 1.0e-10)
}

///|
test "size limits duplicate margin names and empty identifiers are rejected" {
  let p = problem()
  assert_eq(
    @moon-rake.fit({ ..p, rows: [], }).unwrap_err(),
    @moon-rake.SizeLimit,
  )
  assert_eq(
    @moon-rake.fit({ ..p, margins: [], }).unwrap_err(),
    @moon-rake.SizeLimit,
  )
  assert_eq(
    @moon-rake.fit({
      ..p,
      margins: [p.margins[0], margin("gender", [("N", 50.0), ("S", 50.0)])],
    }).unwrap_err(),
    @moon-rake.InvalidMargin("gender"),
  )
  assert_eq(
    @moon-rake.fit({ ..p, rows: [row("", ["F", "N"])], }).unwrap_err(),
    @moon-rake.InvalidRow(""),
  )
  assert_eq(
    @moon-rake.fit({ ..p, rows: [row("x", ["F", "N"], base=2.0, upper=1.0)], }).unwrap_err(),
    @moon-rake.InvalidRow("x"),
  )
  assert_eq(
    @moon-rake.fit(p, options={ max_iterations: 1001, tolerance: 1.0e-8, }).unwrap_err(),
    @moon-rake.InvalidOptions,
  )
  assert_eq(
    @moon-rake.evaluate(p, [25.0, 25.0, 25.0, 25.0], tolerance=0.5).unwrap_err(),
    @moon-rake.InvalidOptions,
  )
}

///|
test "fit JSON carries status simultaneous residuals and escaped row IDs" {
  let p : @moon-rake.Problem = {
    rows: [row("a\"\\\n", ["A"])],
    margins: [margin("m", [("A", 2.0)])],
  }
  let json = @moon-rake.fit(p).unwrap().to_json()
  assert_true(json.stringify().contains("maximum_error"))
  match json {
    Object(fields) => assert_true(fields.contains("status"))
    _ => fail("expected object")
  }
}
