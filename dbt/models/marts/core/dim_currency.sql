select
    {{ surrogate_key(['currency_code']) }} as currency_sk,
    currency_code,
    currency_name,
    symbol,
    minor_units,
    currency_code = '{{ var("reporting_currency") }}' as is_reporting_currency
from {{ ref('stg_raw__currencies') }}
