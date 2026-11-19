-- Gaming table with its type denormalised (star schema: avoids a snowflake join for the most common slice).
select
    {{ surrogate_key(['t.table_id']) }}  as table_sk,
    t.table_id,
    t.table_number,
    t.seats,
    t.min_bet_eur,
    t.max_bet_eur,
    tt.table_type_id,
    tt.table_type_code,
    tt.table_type_name,
    tt.table_type_category,
    {{ surrogate_key(['t.casino_id']) }} as casino_sk,
    t.casino_id
from {{ ref('stg_raw__gaming_tables') }} t
join {{ ref('stg_raw__table_types') }} tt using (table_type_id)
