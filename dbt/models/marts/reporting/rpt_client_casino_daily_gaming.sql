-- Q4 / Q5: Customer's total bet and total win amount in EUR per day per casino.
-- Grain: client x casino x gaming day. Machine and table play combined (and split out).
with plays as (
    select game_date, casino_id, client_id, 'machine' as channel,
           bet_amount_eur, win_amount_eur, ggr_eur
    from {{ ref('fct_machine_gameplay') }}
    union all
    select game_date, casino_id, client_id, 'table' as channel,
           bet_amount_eur, win_amount_eur, ggr_eur
    from {{ ref('fct_table_gameplay') }}
)
select
    p.game_date,
    p.casino_id,
    ca.casino_name,
    p.client_id,
    count(*)                                                        as games_played,
    sum(p.bet_amount_eur)                                           as total_bet_eur,
    sum(p.win_amount_eur)                                           as total_win_eur,
    sum(p.bet_amount_eur) filter (where channel = 'machine')        as machine_bet_eur,
    sum(p.win_amount_eur) filter (where channel = 'machine')        as machine_win_eur,
    sum(p.bet_amount_eur) filter (where channel = 'table')          as table_bet_eur,
    sum(p.win_amount_eur) filter (where channel = 'table')          as table_win_eur,
    sum(p.ggr_eur)                                                  as client_ggr_eur
from plays p
join {{ ref('dim_casino') }} ca using (casino_id)
group by all
