-- Q3. How many unique customer visits were made per day per casino?
select visit_date, casino_name, unique_visitors, total_entries
from {{ ref('rpt_casino_daily_visits') }}
order by visit_date desc, casino_name
