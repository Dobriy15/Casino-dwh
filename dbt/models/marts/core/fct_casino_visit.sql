-- Grain: one client entering one casino (one row per registered entry).
select
    v.visit_id,
    {{ date_key(gaming_date('v.entered_at')) }}            as visit_date_key,
    {{ gaming_date('v.entered_at') }}                       as visit_date,
    {{ surrogate_key(['v.casino_id']) }}                    as casino_sk,
    v.casino_id,
    c.client_sk,
    v.client_id,
    v.entered_at,
    v.exited_at,
    date_diff('minute', v.entered_at, v.exited_at)          as duration_minutes,
    v.exited_at is null                                     as is_open_visit,
    row_number() over (partition by v.client_id order by v.entered_at) = 1
                                                            as is_first_visit_ever
from {{ ref('stg_raw__casino_visits') }} v
left join {{ ref('dim_client') }} c
    on v.client_id = c.client_id
   and v.entered_at >= c.valid_from
   and v.entered_at <  c.valid_to
