select
    {{ date_key('rate_date') }}            as date_key,
    rate_date,
    {{ surrogate_key(['currency_code']) }} as currency_sk,
    currency_code,
    units_per_eur,
    cast(1 / units_per_eur as decimal(18, 10)) as eur_per_unit,
    rate_type,
    published_rate_date
from {{ ref('int_fx_rates__daily') }}
