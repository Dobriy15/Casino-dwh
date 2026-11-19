-- Daily new client registrations per registering casino. Building block for Q2.
select
    c.registration_date,
    ca.casino_id,
    ca.casino_name,
    ca.country_code,
    count(distinct c.client_id) as new_registrations
from {{ ref('dim_client') }} c
join {{ ref('dim_casino') }} ca on ca.casino_id = c.registration_casino_id
where c.version_number = 1
group by all
