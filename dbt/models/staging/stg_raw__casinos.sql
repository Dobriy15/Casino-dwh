select
    cast(casino_id as integer) as casino_id,
    casino_code,
    casino_name,
    upper(country_code)        as country_code,
    city,
    address,
    timezone,
    cast(opened_at as date)    as opened_at,
    updated_at
from {{ source('raw', 'casinos') }}
