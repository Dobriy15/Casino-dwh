-- Transactions must be in the currency that was legal tender in the casino's country on that date
-- (e.g. HRK in Croatia only until 2022-12-31).
with plays as (
    select casino_id, game_start_time, currency_code from {{ ref('fct_machine_gameplay') }}
    union all
    select casino_id, game_start_time, currency_code from {{ ref('fct_table_gameplay') }}
)
select p.*
from plays p
join {{ ref('dim_casino') }} ca using (casino_id)
left join {{ ref('stg_raw__country_currencies') }} cc
    on cc.country_code = ca.country_code
   and cc.currency_code = p.currency_code
   and cast(p.game_start_time as date) between cc.valid_from and cc.valid_to
where cc.country_code is null
