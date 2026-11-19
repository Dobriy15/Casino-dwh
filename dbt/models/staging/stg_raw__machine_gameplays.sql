select
    cast(gameplay_id as bigint)                  as gameplay_id,
    cast(visit_id as bigint)                     as visit_id,
    cast(client_id as integer)                   as client_id,
    cast(machine_id as integer)                  as machine_id,
    cast(game_id as integer)                     as game_id,
    game_start_time,
    upper(currency_code)                         as currency_code,
    cast(bet_amount_money as decimal(18, 2))     as bet_amount_local,
    cast(win_amount_money as decimal(18, 2))     as win_amount_local,
    lower(game_status)                           as game_status
from {{ source('raw', 'machine_gameplays') }}
