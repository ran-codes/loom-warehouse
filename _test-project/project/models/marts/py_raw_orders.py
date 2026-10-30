def model(dbt, session):
    dbt.config(materialized="table")
    return dbt.source("ecom", "raw_orders")
