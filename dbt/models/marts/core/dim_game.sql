select
    {{ surrogate_key(['game_id']) }} as game_sk,
    game_id,
    game_name,
    provider,
    game_category,
    theoretical_rtp
from {{ ref('stg_raw__games') }}
