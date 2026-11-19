-- Country with its currency history flattened to the currently valid currency.
-- The full validity history stays available in stg_raw__country_currencies.
select
    {{ surrogate_key(['c.country_code']) }} as country_sk,
    c.country_code,
    c.iso3_code,
    c.country_name,
    c.region,
    cc.currency_code                        as current_currency_code,
    cc.valid_from                           as current_currency_since
from {{ ref('stg_raw__countries') }} c
left join {{ ref('stg_raw__country_currencies') }} cc
    on c.country_code = cc.country_code
   and current_date between cc.valid_from and cc.valid_to
