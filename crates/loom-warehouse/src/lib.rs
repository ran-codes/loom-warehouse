//! Local Python model execution for the DuckDB adapter.
//!
//! Stub: every job returns a "not implemented" error until the data handoff lands.

use dbt_common::{AdapterError, AdapterErrorKind, AdapterResult};
use minijinja::Value;

/// Submit a DuckDB Python model job.
pub fn submit_python_job(_model: &Value, _compiled_code: &str) -> AdapterResult<()> {
    Err(AdapterError::new(
        AdapterErrorKind::NotSupported,
        "loom-warehouse: Python models on DuckDB are not implemented yet",
    ))
}
