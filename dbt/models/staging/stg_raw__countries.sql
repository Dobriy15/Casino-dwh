select
    upper(country_code)   as country_code,
    upper(iso3_code)      as iso3_code,
    country_name,
    region
from {{ source('raw', 'countries') }}
