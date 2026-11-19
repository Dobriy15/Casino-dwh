-- Q4. What was the customer's total bet amount in EUR per day per casino?
-- Q5. What was the customer's total win amount in EUR per day per casino?
select game_date, casino_name, client_id, games_played, total_bet_eur, total_win_eur
from {{ ref('rpt_client_casino_daily_gaming') }}
order by game_date desc, total_bet_eur desc
