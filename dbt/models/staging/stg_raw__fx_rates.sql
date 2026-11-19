select
    cast(rate_date as date)                 as rate_date,
    upper(currency_code)                    as currency_code,
    cast(units_per_eur as decimal(18, 6))   as units_per_eur,
    source                                  as rate_source
from {{ source('raw', 'fx_rates') }}
