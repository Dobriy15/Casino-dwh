select
    cast(table_id as integer)        as table_id,
    cast(casino_id as integer)       as casino_id,
    cast(table_type_id as integer)   as table_type_id,
    table_number,
    cast(seats as integer)           as seats,
    cast(min_bet_eur as decimal(18, 2)) as min_bet_eur,
    cast(max_bet_eur as decimal(18, 2)) as max_bet_eur,
    updated_at
from {{ source('raw', 'gaming_tables') }}
