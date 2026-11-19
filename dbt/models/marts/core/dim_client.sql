-- SCD Type 2 client dimension.
-- Natural (business) key of a physical person: identity document type + number + issuing country.
-- client_id is the source-system key; client_sk identifies one version of the client.
select
    {{ surrogate_key(['client_id', 'valid_from']) }}                           as client_sk,
    client_id,
    {{ surrogate_key(['document_type', 'document_number', 'document_country_code']) }}
                                                                                as person_key,
    first_name,
    last_name,
    birth_date,
    gender,
    document_type,
    document_number,
    document_country_code,
    residence_country_code,
    email,
    is_self_excluded,
    registered_at,
    cast(registered_at as date)                                                 as registration_date,
    registration_casino_id,
    valid_from,
    valid_to,
    valid_to = timestamp '9999-12-31'                                           as is_current,
    version_number
from {{ ref('int_clients__scd2') }}
