-- Q2. How many new customer registrations did we have during the last 7 days?
select window_start, window_end, casino_name, new_registrations
from {{ ref('rpt_new_registrations_last_7_days') }}
order by casino_id nulls last
