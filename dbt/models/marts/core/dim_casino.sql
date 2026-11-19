select
    {{ surrogate_key(['ca.casino_id']) }} as casino_sk,
    ca.casino_id,
    ca.casino_code,
    ca.casino_name,
    ca.city,
    ca.address,
    ca.timezone,
    ca.opened_at,
    co.country_code,
    co.country_name,
    co.region
from {{ ref('stg_raw__casinos') }} ca
join {{ ref('stg_raw__countries') }} co using (country_code)
