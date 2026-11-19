-- A losing / ongoing / voided round must have win = 0; a winning round must have win > 0.
select 'machine' as src, gameplay_id, game_status, win_amount_local
from {{ ref('fct_machine_gameplay') }}
where (game_status = 'win' and win_amount_local <= 0)
   or (game_status <> 'win' and win_amount_local <> 0)
union all
select 'table', gameplay_id, game_status, win_amount_local
from {{ ref('fct_table_gameplay') }}
where (game_status = 'win' and win_amount_local <= 0)
   or (game_status <> 'win' and win_amount_local <> 0)
