///|
/// Audit weights that came from somewhere else, without refitting first.
///
/// The weights below stand in for a spreadsheet column pasted next to the
/// design: same row order, no provenance, and a claim that they are calibrated.
/// `evaluate` recomputes every margin and every bound from the design instead of
/// trusting that claim, and the run then shows the same design refitted.
fn row(
  id : String,
  cells : Array[String],
  lower? : Double = 1.0,
  upper? : Double = 25.0,
) -> @rake.Row {
  { id, cells, base_weight: 1.0, lower, upper, }
}

///|
fn margin(name : String, targets : Array[(String, Double)]) -> @rake.Margin {
  { name, targets: targets.map(fn(t) { { category: t.0, total: t.1, } }), }
}

///|
fn main {
  let design : @rake.Problem = {
    rows: [
      row("north-low", ["north", "low"]),
      row("north-mid", ["north", "mid"]),
      row("north-high", ["north", "high"]),
      row("south-low", ["south", "low"]),
      row("south-mid", ["south", "mid"]),
      row("south-high", ["south", "high"]),
    ],
    margins: [
      margin("region", [("north", 50.0), ("south", 50.0)]),
      margin("band", [("low", 30.0), ("mid", 30.0), ("high", 40.0)]),
    ],
  }
  // Pasted from a spreadsheet: the high band was entered as 17 + 20 instead of
  // 20 + 20, so the calibrated claim is false.
  let imported : Array[Double] = [15.0, 15.0, 20.0, 15.0, 15.0, 17.0]
  let verdict = @rake.evaluate(design, imported).unwrap()
  println("audit of imported weights (row order as pasted)")
  for residual in verdict.residuals {
    println(
      "  \{residual.margin}/\{residual.category}: target=\{residual.target} actual=\{residual.actual} error=\{residual.scaled_error}",
    )
  }
  println(
    "passes=\{verdict.passes} max_error=\{verdict.maximum_error} bounds_violations=\{verdict.bounds_violations} ess=\{verdict.effective_sample_size}",
  )
  let fitted = @rake.fit(design).unwrap()
  println(
    "after refit: iterations=\{fitted.iterations} passes=\{fitted.diagnostics.passes} max_error=\{fitted.diagnostics.maximum_error}",
  )
  for weighted in fitted.weights {
    println("  \{weighted.id}: \{weighted.weight}")
  }
}
