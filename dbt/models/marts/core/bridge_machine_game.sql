-- Resolves the many-to-many between machines and games, time-bounded:
-- a game can be installed on many machines, a machine hosts several games, installs change over time.
select
    {{ surrogate_key(['machine_id']) }} as machine_sk,
    {{ surrogate_key(['game_id']) }}    as game_sk,
    machine_id,
    game_id,
    installed_from,
    installed_to,
    installed_to = date '9999-12-31'    as is_currently_installed
from {{ ref('stg_raw__machine_games') }}
