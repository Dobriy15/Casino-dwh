select
    cast(game_id as integer)              as game_id,
    game_name,
    provider,
    game_category,
    cast(theoretical_rtp as decimal(5, 4)) as theoretical_rtp,
    updated_at
from {{ source('raw', 'games') }}
