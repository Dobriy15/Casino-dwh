-- Q1: How many unique customers did we have in total per country at any given date?
-- Grain: country x calendar date.
--   registered_clients        - clients registered on/before the date, by their country of residence
--                                *as it was on that date* (SCD2 point-in-time lookup)
--   clients_visited_to_date   - distinct clients who ever entered a casino in that country up to the date
--                                (alternative "casino country" interpretation)
with spine as (
    select date_day as as_of_date
    from {{ ref('dim_date') }}
    where date_day between (select min(registration_date) from {{ ref('dim_client') }})
                       and {{ report_date() }}
),

registered as (
    select
        s.as_of_date,
        c.residence_country_code as country_code,
        count(distinct c.client_id) as registered_clients,
        count(distinct c.client_id) filter (where c.registration_date = s.as_of_date) as new_registrations
    from spine s
    join {{ ref('dim_client') }} c
        on c.registration_date <= s.as_of_date
       -- the version valid at the end of the day
       and c.valid_from <  s.as_of_date + interval 1 day
       and c.valid_to   >= s.as_of_date + interval 1 day
    group by all
),

first_visit_in_country as (
    select ca.country_code, v.client_id, min(v.visit_date) as first_visit_date
    from {{ ref('fct_casino_visit') }} v
    join {{ ref('dim_casino') }} ca using (casino_sk)
    group by all
),

visited as (
    select
        s.as_of_date,
        f.country_code,
        count(*) as clients_visited_to_date
    from spine s
    join first_visit_in_country f on f.first_visit_date <= s.as_of_date
    group by all
)

select
    s.as_of_date,
    co.country_code,
    co.country_name,
    coalesce(r.registered_clients, 0)       as registered_clients,
    coalesce(r.new_registrations, 0)        as new_registrations,
    coalesce(v.clients_visited_to_date, 0)  as clients_visited_to_date
from spine s
cross join {{ ref('dim_country') }} co
left join registered r on r.as_of_date = s.as_of_date and r.country_code = co.country_code
left join visited    v on v.as_of_date = s.as_of_date and v.country_code = co.country_code
