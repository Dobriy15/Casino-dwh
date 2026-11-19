-- Q6-Q9: Which gaming machine / table had the most played games and made the most profit per day?
-- One row per gaming day x asset type x metric. Ties are kept (rank() = 1) and listed together.
with winners as (
    select game_date, 'machine' as asset_type, 'most_games_played' as metric,
           asset_tag || ' (' || casino_name || ')' as asset, games_played::decimal(18, 2) as value
    from {{ ref('rpt_gaming_machine_daily') }} where rank_by_games_played = 1
    union all
    select game_date, 'machine', 'most_profit_eur',
           asset_tag || ' (' || casino_name || ')', profit_eur
    from {{ ref('rpt_gaming_machine_daily') }} where rank_by_profit = 1
    union all
    select game_date, 'table', 'most_games_played',
           table_type_code || ' ' || table_number || ' (' || casino_name || ')', games_played::decimal(18, 2)
    from {{ ref('rpt_gaming_table_daily') }} where rank_by_games_played = 1
    union all
    select game_date, 'table', 'most_profit_eur',
           table_type_code || ' ' || table_number || ' (' || casino_name || ')', profit_eur
    from {{ ref('rpt_gaming_table_daily') }} where rank_by_profit = 1
)
select
    game_date,
    asset_type,
    metric,
    string_agg(asset, '; ' order by asset) as top_assets,
    count(*)                               as tied_assets,
    max(value)                             as metric_value
from winners
group by all
