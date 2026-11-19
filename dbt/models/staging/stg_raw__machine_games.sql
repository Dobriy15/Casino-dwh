select
    cast(machine_id as integer)                          as machine_id,
    cast(game_id as integer)                             as game_id,
    cast(installed_at as date)                           as installed_from,
    coalesce(cast(removed_at as date), date '9999-12-31') as installed_to
from {{ source('raw', 'machine_games') }}
