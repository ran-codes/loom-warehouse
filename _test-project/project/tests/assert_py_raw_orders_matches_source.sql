-- Fails (returns a row) when py_raw_orders does not carry every row of the raw_orders source.
with py as (select count(*) as n from {{ ref('py_raw_orders') }}),
     src as (select count(*) as n from {{ source('ecom', 'raw_orders') }})
select py.n as py_raw_orders_rows, src.n as raw_orders_rows
from py, src
where py.n != src.n
