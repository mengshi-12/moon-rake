///| Cells follow the margin array order. Active weights have strictly positive

///|
/// lower bounds; fixed structural-zero rows use base=lower=upper=0.
pub(all) struct Row {
  id : String
  cells : Array[String]
  base_weight : Double
  lower : Double
  upper : Double
} derive(Eq, @debug.Debug, ToJson)

///|
pub(all) struct Target {
  category : String
  total : Double
} derive(Eq, @debug.Debug, ToJson)

///|
pub(all) struct Margin {
  name : String
  targets : Array[Target]
} derive(Eq, @debug.Debug, ToJson)

///|
pub(all) struct Problem {
  rows : Array[Row]
  margins : Array[Margin]
} derive(@debug.Debug)

///|
/// Residuals use |actual-target|/max(1,target). Tolerance is 1e-10..1e-3.
pub(all) struct Options {
  max_iterations : Int
  tolerance : Double
} derive(Eq, @debug.Debug, ToJson)

///|
pub(all) enum Status {
  Converged
  IterationLimit
  BaselineRejected
} derive(Eq, @debug.Debug, ToJson)

///|
pub(all) struct Residual {
  margin : String
  category : String
  target : Double
  actual : Double
  scaled_error : Double
} derive(Eq, @debug.Debug, ToJson)

///|
pub(all) struct Diagnostics {
  residuals : Array[Residual]
  maximum_error : Double
  bounds_violations : Int
  total_weight : Double
  effective_sample_size : Double
  passes : Bool
} derive(Eq, @debug.Debug, ToJson)

///|
pub(all) struct WeightedRow {
  id : String
  weight : Double
} derive(Eq, @debug.Debug, ToJson)

///|
/// Trace errors are recomputed after complete sweeps, not during projections.
pub(all) struct Fit {
  status : Status
  iterations : Int
  weights : Array[WeightedRow]
  trace : Array[Double]
  diagnostics : Diagnostics
} derive(Eq, @debug.Debug, ToJson)

///|
pub(all) enum RakeError {
  SizeLimit
  InvalidOptions
  InvalidRow(String)
  DuplicateRow(String)
  InvalidMargin(String)
  UnknownCategory(String, String)
  InconsistentTotals
  InfeasibleMargin(String, String)
  InvalidWeights
  NotOneWay
  NumericFailure
} derive(Eq, @debug.Debug)

///|
priv struct Group {
  margin : String
  category : String
  target : Double
  members : Array[Int]
}

///|
priv struct Compiled {
  rows : Array[Row]
  groups : Array[Group]
}

///|
pub extend Row with Eq::{equal, not_equal}

///|
pub extend Row with @debug.Debug::{to_repr}

///|
pub extend Row with ToJson::{to_json}

///|
pub extend Target with Eq::{equal, not_equal}

///|
pub extend Target with @debug.Debug::{to_repr}

///|
pub extend Target with ToJson::{to_json}

///|
pub extend Margin with Eq::{equal, not_equal}

///|
pub extend Margin with @debug.Debug::{to_repr}

///|
pub extend Margin with ToJson::{to_json}

///|
pub extend Options with Eq::{equal, not_equal}

///|
pub extend Options with @debug.Debug::{to_repr}

///|
pub extend Options with ToJson::{to_json}

///|
pub extend Status with Eq::{equal, not_equal}

///|
pub extend Status with @debug.Debug::{to_repr}

///|
pub extend Status with ToJson::{to_json}

///|
pub extend Residual with Eq::{equal, not_equal}

///|
pub extend Residual with @debug.Debug::{to_repr}

///|
pub extend Residual with ToJson::{to_json}

///|
pub extend Diagnostics with Eq::{equal, not_equal}

///|
pub extend Diagnostics with @debug.Debug::{to_repr}

///|
pub extend Diagnostics with ToJson::{to_json}

///|
pub extend WeightedRow with Eq::{equal, not_equal}

///|
pub extend WeightedRow with @debug.Debug::{to_repr}

///|
pub extend WeightedRow with ToJson::{to_json}

///|
pub extend Fit with Eq::{equal, not_equal}

///|
pub extend Fit with @debug.Debug::{to_repr}

///|
pub extend Fit with ToJson::{to_json}

///|
pub extend RakeError with Eq::{equal, not_equal}

///|
pub extend RakeError with @debug.Debug::{to_repr}

///|
pub extend Problem with @debug.Debug::{to_repr}
