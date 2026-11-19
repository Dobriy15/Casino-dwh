-- Q6. Which gaming machine had the most played games per day?
-- Q7. Which gaming machine made the most profit per day?
select game_date, metric, top_assets, metric_value, tied_assets
from {{ ref('rpt_top_assets_daily') }}
where asset_type = 'machine'
order by game_date desc, metric
