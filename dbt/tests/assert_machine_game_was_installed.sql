-- A game can only be played on a machine where it was installed at that time.
select f.gameplay_id, f.machine_id, f.game_id, f.game_start_time
from {{ ref('fct_machine_gameplay') }} f
left join {{ ref('bridge_machine_game') }} b
    on b.machine_id = f.machine_id
   and b.game_id = f.game_id
   and cast(f.game_start_time as date) >= b.installed_from
   and cast(f.game_start_time as date) <  b.installed_to
where b.machine_id is null
