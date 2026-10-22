///|
fn row(
  id : String,
  cells : Array[String],
  base? : Double = 1.0,
  lower? : Double = 0.001,
  upper? : Double = 1000.0,
) -> @rake.Row {
  { id, cells, base_weight: base, lower, upper, }
}

///|
fn margin(name : String, targets : Array[(String, Double)]) -> @rake.Margin {
  { name, targets: targets.map(fn(t) { { category: t.0, total: t.1, } }), }
}

///|
fn main {
  let survey : @rake.Problem = {
    rows: [
      row("a", ["F", "N"]),
      row("b", ["F", "S"]),
      row("c", ["M", "N"]),
      row("d", ["M", "S"]),
    ],
    margins: [
      margin("group", [("F", 60.0), ("M", 40.0)]),
      margin("region", [("N", 50.0), ("S", 50.0)]),
    ],
  }
  let fitted = @rake.fit(survey).unwrap()
  println("1 survey calibration: expected weights 30,30,20,20")
  for weighted in fitted.weights {
    println("  \{weighted.id}: \{weighted.weight}")
  }
  let weights = fitted.weights.map(fn(w) { w.weight })
  println(
    "weighted mean of 10,20,30,40 = \{@rake.weighted_mean([10.0,20.0,30.0,40.0],weights).unwrap()}",
  )

  let table : @rake.Problem = {
    rows: [
      row("11", ["R1", "C1"]),
      row("12", ["R1", "C2"]),
      row("13", ["R1", "C3"]),
      row("21", ["R2", "C1"]),
      row("22", ["R2", "C2"]),
      row("23", ["R2", "C3"]),
    ],
    margins: [
      margin("row", [("R1", 40.0), ("R2", 60.0)]),
      margin("column", [("C1", 20.0), ("C2", 30.0), ("C3", 50.0)]),
    ],
  }
  println("2 aggregate cell balancing: expected 8,12,20,12,18,30")
  println(@rake.fit(table).unwrap().to_json().stringify())

  println(
    "3 independent audit of old weights against changed population margins",
  )
  let changed = {
    ..survey,
    margins: [margin("group", [("F", 50.0), ("M", 50.0)]), survey.margins[1]],
  }
  println(@rake.evaluate(changed, weights).unwrap().to_json().stringify())
  println("recalibrated: \{@rake.fit(changed).unwrap().diagnostics.passes}")

  let one : @rake.Problem = {
    rows: [
      row("a", ["all"], base=3.0, lower=1.0, upper=4.0),
      row("b", ["all"], lower=1.0, upper=20.0),
    ],
    margins: [margin("total", [("all", 10.0)])],
  }
  println(
    "moon-causal unbounded baseline passes our bound audit=\{@rake.oneway_baseline(one).unwrap().diagnostics.passes}",
  )
  println(
    "bounded projection passes=\{@rake.fit(one).unwrap().diagnostics.passes}",
  )
  let incompatible : @rake.Problem = {
    rows: [row("a", ["A", "X"]), row("b", ["B", "Y"])],
    margins: [
      margin("m1", [("A", 60.0), ("B", 40.0)]),
      margin("m2", [("X", 50.0), ("Y", 50.0)]),
    ],
  }
  let limited = @rake.fit(incompatible, options={
    max_iterations: 5,
    tolerance: 1.0e-8,
  }).unwrap()
  println(
    "joint mismatch is reported as iteration limit=\{limited.status == @rake.IterationLimit}",
  )
  let unsupported = { ..one, margins: [margin("total", [("all", 100.0)])], }
  println("unsupported bounds rejected=\{@rake.fit(unsupported) is Err(_)}")
}
