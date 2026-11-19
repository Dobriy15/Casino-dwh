select
    upper(currency_code) as currency_code,
    currency_name,
    symbol,
    cast(minor_units as integer) as minor_units
from {{ source('raw', 'currencies') }}
