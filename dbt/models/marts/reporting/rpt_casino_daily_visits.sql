-- Q3: How many unique customer visits were made per day per casino?
-- Grain: casino x gaming day.
select
    v.visit_date,
    ca.casino_id,
    ca.casino_name,
    ca.country_code,
    count(distinct v.client_id)                         as unique_visitors,
    count(*)                                            as total_entries,
    count(*) filter (where v.is_first_visit_ever)       as first_time_visitors,
    round(avg(v.duration_minutes), 1)                   as avg_visit_minutes
from {{ ref('fct_casino_visit') }} v
join {{ ref('dim_casino') }} ca using (casino_sk)
group by all
