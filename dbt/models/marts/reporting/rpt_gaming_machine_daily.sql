-- Machine performance per gaming day with daily rankings (building block for Q6 / Q7).
with daily as (
    select
        f.game_date,
        f.machine_id,
        count(*)                                  as games_played,
        count(*) filter (where f.is_settled)      as games_settled,
        sum(f.bet_amount_eur)                     as total_bet_eur,
        sum(f.win_amount_eur)                     as total_win_eur,
        sum(f.ggr_eur)                            as profit_eur
    from {{ ref('fct_machine_gameplay') }} f
    group by all
)
select
    d.*,
    m.asset_tag,
    m.manufacturer,
    m.model,
    ca.casino_name,
    ca.country_code,
    rank() over (partition by d.game_date order by d.games_played desc) as rank_by_games_played,
    rank() over (partition by d.game_date order by d.profit_eur desc)   as rank_by_profit
from daily d
join {{ ref('dim_gaming_machine') }} m using (machine_id)
join {{ ref('dim_casino') }} ca on ca.casino_id = m.casino_id
