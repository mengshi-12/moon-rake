///|
pub fn default_options() -> Options {
  { max_iterations: 100, tolerance: 1.0e-8, }
}

///|
fn finite(x : Double) -> Bool {
  x == x && x.abs() <= 1.0e300
}

///|
fn tolerance_scale(target : Double) -> Double {
  if target > 1.0 {
    target
  } else {
    1.0
  }
}

///|
fn valid_options(options : Options) -> Bool {
  options.max_iterations >= 1 &&
  options.max_iterations <= 1000 &&
  finite(options.tolerance) &&
  options.tolerance >= 1.0e-10 &&
  options.tolerance <= 1.0e-3
}

///|
fn compile(
  problem : Problem,
  tolerance : Double,
) -> Result[Compiled, RakeError] {
  if problem.rows.is_empty() ||
    problem.rows.length() > 5000 ||
    problem.margins.is_empty() ||
    problem.margins.length() > 8 {
    return Err(SizeLimit)
  }
  let rows = problem.rows.copy()
  rows.sort_by(fn(a, b) { a.id.lexical_compare(b.id) })
  for i, row in rows {
    if row.id == "" ||
      row.cells.length() != problem.margins.length() ||
      !finite(row.base_weight) ||
      !finite(row.lower) ||
      !finite(row.upper) ||
      row.lower < 0.0 ||
      row.upper > 1.0e12 ||
      row.lower > row.base_weight ||
      row.base_weight > row.upper {
      return Err(InvalidRow(row.id))
    }
    if row.upper == 0.0 {
      if row.base_weight != 0.0 || row.lower != 0.0 {
        return Err(InvalidRow(row.id))
      }
    } else if row.lower < 1.0e-12 {
      return Err(InvalidRow(row.id))
    }
    if i > 0 && rows[i - 1].id == row.id {
      return Err(DuplicateRow(row.id))
    }
  }
  let names : Map[String, Bool] = Map([])
  let groups : Array[Group] = []
  let mut first_total = 0.0
  let mut number_targets = 0
  for col, margin in problem.margins {
    if margin.name == "" ||
      names.contains(margin.name) ||
      margin.targets.is_empty() {
      return Err(InvalidMargin(margin.name))
    }
    names[margin.name] = true
    number_targets += margin.targets.length()
    if number_targets > 256 {
      return Err(SizeLimit)
    }
    let targets = margin.targets.copy()
    targets.sort_by(fn(a, b) { a.category.lexical_compare(b.category) })
    let categories : Map[String, Bool] = Map([])
    let mut total = 0.0
    for target in targets {
      if target.category == "" ||
        categories.contains(target.category) ||
        !finite(target.total) ||
        target.total < 0.0 ||
        target.total > 1.0e12 {
        return Err(InvalidMargin(margin.name))
      }
      categories[target.category] = true
    }
    for row in rows {
      if !categories.contains(row.cells[col]) {
        return Err(UnknownCategory(margin.name, row.cells[col]))
      }
    }
    for target in targets {
      total += target.total
      let members : Array[Int] = []
      let mut minimum = 0.0
      let mut maximum = 0.0
      for i, row in rows {
        if row.cells[col] == target.category {
          members.push(i)
          minimum += row.lower
          maximum += row.upper
        }
      }
      let epsilon = tolerance * tolerance_scale(target.total)
      if target.total < minimum - epsilon || target.total > maximum + epsilon {
        return Err(InfeasibleMargin(margin.name, target.category))
      }
      // A zero-support group cannot be made positive by a tolerance loophole.
      if target.total > 0.0 && maximum == 0.0 {
        return Err(InfeasibleMargin(margin.name, target.category))
      }
      groups.push({
        margin: margin.name,
        category: target.category,
        target: target.total,
        members,
      })
    }
    if col == 0 {
      first_total = total
    } else if (total - first_total).abs() >
      tolerance * tolerance_scale(first_total) {
      return Err(InconsistentTotals)
    }
  }
  if first_total <= 0.0 {
    return Err(InconsistentTotals)
  }
  Ok({ rows, groups, })
}
