select
    cast(visit_id as bigint)   as visit_id,
    cast(client_id as integer) as client_id,
    cast(casino_id as integer) as casino_id,
    entered_at,
    exited_at
from {{ source('raw', 'casino_visits') }}
