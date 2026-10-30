//! Local Python model execution for the DuckDB adapter.
//!
//! The dbt-duckdb macros do every piece of SQL: before `statement('main')` they export each
//! `ref()` of the model to Parquet, and after it they load the child's `result.parquet` into
//! the target table. This crate only writes the rendered runner script to disk and runs it
//! with a plain interpreter, from the dbt process CWD, so the script's relative paths line
//! up with the paths the macros used.
//!
//! Every file of a run is `target/loom-warehouse.<model>.<file>`; see `loom_prefix` in
//! `dbt-duckdb/macros/adapters.sql` for why that layout is flat.

use std::path::PathBuf;
use std::process::Command;

use dbt_common::{AdapterError, AdapterErrorKind, AdapterResult};
use minijinja::Value;

/// Interpreter override. Falls back to `python` on PATH when unset.
pub const PYTHON_ENV_VAR: &str = "LOOM_PYTHON";

/// Lines of the child's stderr kept in the error message.
const STDERR_TAIL_LINES: usize = 20;

/// Submit a DuckDB Python model job: write `compiled_code` to
/// `target/loom-warehouse.<model>.model.py` and run it to completion.
pub fn submit_python_job(model: &Value, compiled_code: &str) -> AdapterResult<()> {
    let model_name = model
        .get_attr("name")
        .ok()
        .and_then(|v| v.as_str().map(|s| s.to_string()))
        .ok_or_else(|| internal("model name is required"))?;

    let script = script_path(&model_name);
    std::fs::write(&script, compiled_code)
        .map_err(|e| internal(format!("cannot write {}: {e}", script.display())))?;

    let interpreter = interpreter();
    let output = Command::new(&interpreter)
        .arg(&script)
        .output()
        .map_err(|e| internal(format!("cannot run `{interpreter}`: {e}")))?;

    if output.status.success() {
        return Ok(());
    }

    let stderr = String::from_utf8_lossy(&output.stderr);
    let tail: Vec<&str> = stderr.lines().rev().take(STDERR_TAIL_LINES).collect();
    let tail: Vec<&str> = tail.into_iter().rev().collect();
    Err(internal(format!(
        "Python model '{model_name}' failed ({}, interpreter `{interpreter}`, script {}):\n{}",
        output.status,
        script.display(),
        tail.join("\n"),
    )))
}

fn script_path(model_name: &str) -> PathBuf {
    PathBuf::from(format!("target/loom-warehouse.{model_name}.model.py"))
}

fn interpreter() -> String {
    std::env::var(PYTHON_ENV_VAR)
        .ok()
        .filter(|s| !s.trim().is_empty())
        .unwrap_or_else(|| "python".to_string())
}

fn internal(msg: impl Into<String>) -> AdapterError {
    AdapterError::new(AdapterErrorKind::Internal, msg.into())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn missing_interpreter_is_reported_with_its_path() {
        let dir = std::env::temp_dir().join(format!("loom-warehouse-test-{}", std::process::id()));
        std::fs::create_dir_all(dir.join("target")).unwrap();
        // Spawning resolves the script relative to the CWD, exactly like a dbt run.
        let previous_cwd = std::env::current_dir().unwrap();
        std::env::set_current_dir(&dir).unwrap();

        let bogus = dir.join("no-such-python");
        // SAFETY: this crate's tests are single-threaded with respect to this variable.
        unsafe { std::env::set_var(PYTHON_ENV_VAR, &bogus) };

        let model = Value::from_serialize(serde_json::json!({ "name": "py_unit" }));
        let err = submit_python_job(&model, "print('never runs')").unwrap_err();

        unsafe { std::env::remove_var(PYTHON_ENV_VAR) };
        std::env::set_current_dir(previous_cwd).unwrap();
        std::fs::remove_dir_all(&dir).unwrap();

        assert!(
            err.to_string().contains(&bogus.display().to_string()),
            "error does not name the interpreter: {err}"
        );
    }
}
