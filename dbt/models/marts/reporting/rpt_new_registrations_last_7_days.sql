-- Q2: How many new customer registrations did we have during the last 7 days?
-- Window = the 7 calendar days ending on (and including) the report date.
-- Report date = var('report_date') or the latest activity date in the warehouse.
-- One row per casino plus a grand total row (casino_id is null).
with params as (
    select {{ report_date() }} as window_end, {{ report_date() }} - 6 as window_start
),
per_casino as (
    select
        p.window_start,
        p.window_end,
        r.casino_id,
        r.casino_name,
        r.country_code,
        cast(sum(r.new_registrations) as bigint) as new_registrations
    from {{ ref('rpt_registrations_daily') }} r
    cross join params p
    where r.registration_date between p.window_start and p.window_end
    group by all
)
select * from per_casino
union all
select window_start, window_end, null, 'ALL CASINOS', null, cast(sum(new_registrations) as bigint)
from per_casino
group by all
