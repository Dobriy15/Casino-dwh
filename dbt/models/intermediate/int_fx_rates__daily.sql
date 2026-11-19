-- One rate per currency per calendar day.
--  * EUR is the reporting currency -> rate 1.
--  * ECB publishes only on TARGET business days -> weekends/holidays take the last published rate (ASOF join).
--  * Legacy currencies (HRK after 2023-01-01) use the irrevocably fixed conversion rate.
with bounds as (
    select
        least(
            (select min(cast(game_start_time as date)) from {{ ref('stg_raw__machine_gameplays') }}),
            (select min(cast(game_start_time as date)) from {{ ref('stg_raw__table_gameplays') }}),
            (select min(rate_date) from {{ ref('stg_raw__fx_rates') }})
        ) as d_from,
        greatest(
            (select max(cast(game_start_time as date)) from {{ ref('stg_raw__machine_gameplays') }}),
            (select max(cast(game_start_time as date)) from {{ ref('stg_raw__table_gameplays') }})
        ) + 1 as d_to
),

spine as (
    select cast(d as date) as rate_date
    from bounds, generate_series(d_from, d_to, interval 1 day) as t(d)
),

currency_days as (
    select s.rate_date, c.currency_code
    from spine s
    cross join {{ ref('stg_raw__currencies') }} c
),

published as (
    select
        cd.rate_date,
        cd.currency_code,
        fx.units_per_eur,
        fx.rate_date as published_rate_date
    from currency_days cd
    asof left join {{ ref('stg_raw__fx_rates') }} fx
        on cd.currency_code = fx.currency_code
       and cd.rate_date >= fx.rate_date
)

select
    p.rate_date,
    p.currency_code,
    cast(case
        when p.currency_code = '{{ var("reporting_currency") }}' then 1
        when fixed.currency_code is not null then fixed.units_per_eur
        else p.units_per_eur
    end as decimal(18, 6))                                     as units_per_eur,
    case
        when p.currency_code = '{{ var("reporting_currency") }}' then 'IDENTITY'
        when fixed.currency_code is not null then 'FIXED_CONVERSION'
        when p.published_rate_date = p.rate_date then 'ECB_PUBLISHED'
        else 'ECB_FORWARD_FILLED'
    end                                                        as rate_type,
    p.published_rate_date
from published p
left join {{ ref('fixed_conversion_rates') }} fixed
    on p.currency_code = fixed.currency_code
   and p.rate_date >= fixed.effective_from
