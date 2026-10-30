-- Fails (returns a row) when py_orders does not carry every row of stg_orders.
with py as (select count(*) as n from {{ ref('py_orders') }}),
     stg as (select count(*) as n from {{ ref('stg_orders') }})
select py.n as py_orders_rows, stg.n as stg_orders_rows
from py, stg
where py.n != stg.n
