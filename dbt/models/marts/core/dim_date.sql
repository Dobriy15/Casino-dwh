-- Conformed calendar dimension. Static range, wide enough for history + future loads.
with days as (
    select cast(d as date) as date_day
    from generate_series(date '2015-01-01', date '2030-12-31', interval 1 day) as t(d)
)
select
    {{ date_key('date_day') }}                       as date_key,
    date_day,
    extract(year from date_day)                      as year,
    extract(quarter from date_day)                   as quarter,
    extract(month from date_day)                     as month,
    strftime(date_day, '%B')                         as month_name,
    strftime(date_day, '%Y-%m')                      as year_month,
    extract(isoyear from date_day)                   as iso_year,
    extract(week from date_day)                      as iso_week,
    extract(isodow from date_day)                    as iso_day_of_week,
    strftime(date_day, '%A')                         as day_name,
    extract(isodow from date_day) in (6, 7)          as is_weekend,
    date_trunc('week', date_day)::date               as week_start_date,
    date_trunc('month', date_day)::date              as month_start_date
from days
