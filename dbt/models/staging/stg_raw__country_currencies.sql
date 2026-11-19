select
    upper(country_code)                                 as country_code,
    upper(currency_code)                                as currency_code,
    cast(valid_from as date)                            as valid_from,
    coalesce(cast(valid_to as date), date '9999-12-31') as valid_to
from {{ source('raw', 'country_currencies') }}
