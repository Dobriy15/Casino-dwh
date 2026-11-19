-- Every game round must happen while the client is inside the casino (between entry and exit).
select f.gameplay_id, f.game_start_time, v.entered_at, v.exited_at
from {{ ref('fct_machine_gameplay') }} f
join {{ ref('fct_casino_visit') }} v using (visit_id)
where f.client_id <> v.client_id
   or f.game_start_time < v.entered_at
   or (v.exited_at is not null and f.game_start_time > v.exited_at)
