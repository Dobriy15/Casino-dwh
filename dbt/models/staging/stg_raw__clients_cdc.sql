-- CDC events for the client master. Exact duplicate deliveries are removed here;
-- history (SCD2) is built in the intermediate layer.
with src as (
    select
        cast(client_id as integer)           as client_id,
        trim(first_name)                     as first_name,
        trim(last_name)                      as last_name,
        cast(birth_date as date)             as birth_date,
        upper(gender)                        as gender,
        upper(document_type)                 as document_type,
        upper(replace(document_number, ' ', '')) as document_number,
        upper(document_country_code)         as document_country_code,
        upper(residence_country_code)        as residence_country_code,
        lower(email)                         as email,
        cast(registration_casino_id as integer) as registration_casino_id,
        registered_at,
        coalesce(is_self_excluded, false)    as is_self_excluded,
        lower(op)                            as cdc_operation,
        changed_at,
        _ingested_at                         as ingested_at
    from {{ source('raw', 'clients_cdc') }}
)
select *
from src
qualify row_number() over (
    partition by client_id, changed_at
    order by ingested_at desc
) = 1
