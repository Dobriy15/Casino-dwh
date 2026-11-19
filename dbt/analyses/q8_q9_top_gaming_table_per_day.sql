-- Q8. Which gaming table had the most played games per day?
-- Q9. Which gaming table made the most profit per day?
select game_date, metric, top_assets, metric_value, tied_assets
from {{ ref('rpt_top_assets_daily') }}
where asset_type = 'table'
order by game_date desc, metric
