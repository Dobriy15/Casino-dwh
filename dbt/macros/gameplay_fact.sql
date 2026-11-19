{#-
  Shared body for the two gameplay fact tables (machine / table).
  Grain: one game round played by one client on one asset.

  Measures are stored both in the local transaction currency and in the reporting currency (EUR),
  converted with the daily rate of the transaction's calendar date.

  GGR (gross gaming revenue = casino profit) = bets - wins, counted only for settled rounds;
  rounds still 'ongoing' / 'undefined' (voided) contribute to games played but not to GGR.

  Incremental: delete+insert on gameplay_id, re-processing a look-back window to absorb
  late-arriving rows and status changes (ongoing -> win/loss).
-#}
{% macro gameplay_fact(source_model, asset_cols, settled_statuses) %}
with plays as (
    select * from {{ ref(source_model) }}
    {% if is_incremental() %}
    where game_start_time >= (
        select max(game_start_time) - interval {{ var('incremental_lookback_days') }} day from {{ this }}
    )
    {% endif %}
)

select
    p.gameplay_id,
    {{ date_key(gaming_date('p.game_start_time')) }}               as game_date_key,
    {{ gaming_date('p.game_start_time') }}                          as game_date,
    p.game_start_time,
    p.visit_id,
    {{ surrogate_key(['v.casino_id']) }}                            as casino_sk,
    v.casino_id,
    c.client_sk,
    p.client_id,
    {% for col in asset_cols -%}
    {{ surrogate_key(['p.' ~ col.id]) }}                            as {{ col.sk }},
    p.{{ col.id }},
    {% endfor -%}
    {{ surrogate_key(['p.currency_code']) }}                        as currency_sk,
    p.currency_code,
    fx.units_per_eur                                                as fx_units_per_eur,
    p.game_status,
    p.game_status in ({{ "'" ~ settled_statuses | join("', '") ~ "'" }}) as is_settled,
    p.bet_amount_local,
    p.win_amount_local,
    cast(p.bet_amount_local / fx.units_per_eur as decimal(18, 2))   as bet_amount_eur,
    cast(p.win_amount_local / fx.units_per_eur as decimal(18, 2))   as win_amount_eur,
    case when p.game_status in ({{ "'" ~ settled_statuses | join("', '") ~ "'" }})
         then cast((p.bet_amount_local - p.win_amount_local) / fx.units_per_eur as decimal(18, 2))
         else 0
    end                                                             as ggr_eur
from plays p
join {{ ref('stg_raw__casino_visits') }} v
    on p.visit_id = v.visit_id
left join {{ ref('dim_client') }} c
    on p.client_id = c.client_id
   and p.game_start_time >= c.valid_from
   and p.game_start_time <  c.valid_to
left join {{ ref('int_fx_rates__daily') }} fx
    on fx.currency_code = p.currency_code
   and fx.rate_date = cast(p.game_start_time as date)
{% endmacro %}
