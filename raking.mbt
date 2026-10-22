///|
fn measure(
  compiled : Compiled,
  weights : Array[Double],
  tolerance : Double,
) -> Diagnostics {
  let residuals : Array[Residual] = []
  let mut maximum_error = 0.0
  let mut total_weight = 0.0
  let mut bounds_violations = 0
  for i, row in compiled.rows {
    let weight = weights[i]
    total_weight += weight
    if weight < row.lower || weight > row.upper {
      bounds_violations += 1
    }
  }
  for group in compiled.groups {
    let mut actual = 0.0
    for i in group.members {
      actual += weights[i]
    }
    let scaled_error = (actual - group.target).abs() /
      tolerance_scale(group.target)
    if scaled_error > maximum_error {
      maximum_error = scaled_error
    }
    residuals.push({
      margin: group.margin,
      category: group.category,
      target: group.target,
      actual,
      scaled_error,
    })
  }
  {
    residuals,
    maximum_error,
    bounds_violations,
    total_weight,
    effective_sample_size: @causal.effective_sample_size(
      normalized_weights(weights),
    ),
    passes: maximum_error <= tolerance && bounds_violations == 0,
  }
}

///| ESS and weighted means are scale invariant; normalize before calling the

///|
/// upstream to avoid squaring or multiplying subnormal external weights.
fn normalized_weights(weights : Array[Double]) -> Array[Double] {
  let mut maximum = 0.0
  for w in weights {
    if w > maximum {
      maximum = w
    }
  }
  if maximum == 0.0 {
    weights.copy()
  } else {
    weights.map(fn(w) { w / maximum })
  }
}

///|
fn scaled_weight(row : Row, current : Double, alpha : Double) -> Double {
  if row.upper == 0.0 {
    return 0.0
  }
  let value = current * alpha
  if value < row.lower {
    row.lower
  } else if value > row.upper {
    row.upper
  } else {
    value
  }
}

///|
fn projected_total(
  compiled : Compiled,
  weights : Array[Double],
  group : Group,
  alpha : Double,
) -> Double {
  let mut total = 0.0
  for i in group.members {
    total += scaled_weight(compiled.rows[i], weights[i], alpha)
  }
  total
}

///|
/// Solve one bounded multiplicative projection by a bracketed scalar bisection.
fn project(
  compiled : Compiled,
  weights : Array[Double],
  group : Group,
) -> Result[Unit, RakeError] {
  if group.members.is_empty() {
    return Ok(())
  }
  let mut high = 1.0
  let mut doublings = 0
  while projected_total(compiled, weights, group, high) < group.target &&
        doublings < 96 {
    high *= 2.0
    doublings += 1
  }
  let mut low = 0.0
  // 128 subdivisions also handle ratios near 1e-24 (the documented bounds).
  for _ in 0..<128 {
    let middle = (low + high) / 2.0
    if projected_total(compiled, weights, group, middle) < group.target {
      low = middle
    } else {
      high = middle
    }
  }
  let alpha = (low + high) / 2.0
  for i in group.members {
    let next = scaled_weight(compiled.rows[i], weights[i], alpha)
    if !finite(next) {
      return Err(NumericFailure)
    }
    weights[i] = next
  }
  Ok(())
}

///| Multi-margin coordinate projections with absolute per-row bounds. A complete

///| sweep is always rechecked against every margin. Exhausting the iteration

///|
/// budget returns IterationLimit, never a claim of joint infeasibility.
pub fn fit(
  problem : Problem,
  options? : Options = default_options(),
) -> Result[Fit, RakeError] {
  if !valid_options(options) {
    return Err(InvalidOptions)
  }
  let compiled = match compile(problem, options.tolerance) {
    Ok(c) => c
    Err(e) => return Err(e)
  }
  let weights = compiled.rows.map(fn(r) { r.base_weight })
  let trace : Array[Double] = []
  let initial = measure(compiled, weights, options.tolerance)
  if initial.passes {
    return Ok({
      status: Converged,
      iterations: 0,
      weights: compiled.rows.mapi(fn(i, r) { { id: r.id, weight: weights[i], } }),
      trace,
      diagnostics: initial,
    })
  }
  for iteration in 1..<=options.max_iterations {
    for group in compiled.groups {
      match project(compiled, weights, group) {
        Ok(_) => ()
        Err(e) => return Err(e)
      }
    }
    let diagnostics = measure(compiled, weights, options.tolerance)
    trace.push(diagnostics.maximum_error)
    if diagnostics.passes || iteration == options.max_iterations {
      return Ok({
        status: if diagnostics.passes {
          Converged
        } else {
          IterationLimit
        },
        iterations: iteration,
        weights: compiled.rows.mapi(fn(i, r) {
          { id: r.id, weight: weights[i], }
        }),
        trace,
        diagnostics,
      })
    }
  }
  Err(NumericFailure)
}

///| Independently reevaluate externally supplied weights in problem.rows order.

///|
/// Reports bound failures instead of silently clipping them.
pub fn evaluate(
  problem : Problem,
  weights : Array[Double],
  tolerance? : Double = 1.0e-8,
) -> Result[Diagnostics, RakeError] {
  let options = { max_iterations: 1, tolerance, }
  if !valid_options(options) {
    return Err(InvalidOptions)
  }
  let compiled = match compile(problem, tolerance) {
    Ok(c) => c
    Err(e) => return Err(e)
  }
  if weights.length() != problem.rows.length() ||
    weights.any(fn(w) { !finite(w) || w < 0.0 || w > 1.0e12 }) {
    return Err(InvalidWeights)
  }
  let indexed : Map[String, Double] = Map([])
  for i, row in problem.rows {
    indexed[row.id] = weights[i]
  }
  measure(compiled, compiled.rows.map(fn(r) { indexed[r.id] }), tolerance) |> Ok
}

///| Real interoperability adapter to moon-causal@0.2.5's single-key raking.

///| The upstream result is reevaluated here against all bounds and margins;

///|
/// upstream's convergence flag is not treated as an acceptance verdict.
pub fn oneway_baseline(problem : Problem) -> Result[Fit, RakeError] {
  if problem.margins.length() != 1 {
    return Err(NotOneWay)
  }
  let compiled = match compile(problem, 1.0e-8) {
    Ok(c) => c
    Err(e) => return Err(e)
  }
  let keys = Array::make(compiled.rows.length(), 0)
  let targets : Array[Double] = []
  for g, group in compiled.groups {
    targets.push(group.target)
    for row in group.members {
      keys[row] = g
    }
  }
  let upstream = @causal.rake_integer_cells(
    keys,
    compiled.rows.map(fn(r) { r.base_weight }),
    targets,
    100,
  )
  let diagnostics = measure(compiled, upstream.weights, 1.0e-8)
  Ok({
    status: if diagnostics.passes {
      Converged
    } else {
      BaselineRejected
    },
    iterations: upstream.iterations,
    weights: compiled.rows.mapi(fn(i, r) {
      { id: r.id, weight: upstream.weights[i], }
    }),
    trace: [diagnostics.maximum_error],
    diagnostics,
  })
}

///|
/// Validated adapter to moon-causal's Hájek weighted mean (no causal inference).
pub fn weighted_mean(
  values : Array[Double],
  weights : Array[Double],
) -> Result[Double, RakeError] {
  if values.is_empty() ||
    values.length() != weights.length() ||
    values.length() > 5000 {
    return Err(InvalidWeights)
  }
  if values.any(fn(x) { !finite(x) || x.abs() > 1.0e12 }) ||
    weights.any(fn(w) { !finite(w) || w < 0.0 || w > 1.0e12 }) {
    return Err(InvalidWeights)
  }
  let mut total = 0.0
  for w in weights {
    total += w
  }
  if total <= 0.0 {
    return Err(InvalidWeights)
  }
  Ok(@causal.hajek_mean(values, normalized_weights(weights)))
}
