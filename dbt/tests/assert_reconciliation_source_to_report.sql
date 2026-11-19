-- Reconciliation: row counts and EUR bet totals must survive the trip source -> fact -> report.
with src as (
    select
        (select count(*) from {{ ref('stg_raw__machine_gameplays') }})
      + (select count(*) from {{ ref('stg_raw__table_gameplays') }}) as source_rows
),
fct as (
    select
        (select count(*) from {{ ref('fct_machine_gameplay') }})
      + (select count(*) from {{ ref('fct_table_gameplay') }}) as fact_rows,
        (select sum(bet_amount_eur) from {{ ref('fct_machine_gameplay') }})
      + (select sum(bet_amount_eur) from {{ ref('fct_table_gameplay') }}) as fact_bet_eur
),
rpt as (
    select sum(games_played) as report_rows, sum(total_bet_eur) as report_bet_eur
    from {{ ref('rpt_client_casino_daily_gaming') }}
)
select *
from src, fct, rpt
where source_rows <> fact_rows
   or fact_rows <> report_rows
   or abs(fact_bet_eur - report_bet_eur) > 0.01
