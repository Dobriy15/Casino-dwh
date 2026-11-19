-- Q1. How many unique customers did we have in total per country at any given date?
-- Change the date to any day in history - the answer is point-in-time correct (SCD2).
select country_code, country_name, registered_clients, clients_visited_to_date
from {{ ref('rpt_clients_by_country_daily') }}
where as_of_date = date '2023-01-15'
order by country_code
