-- Builds a Type-2 slowly changing history of clients from the CDC event log.
-- Each CDC event opens a new version; the version is closed by the next event of the same client.
-- Consecutive events that do not change any tracked attribute are collapsed.
with events as (
    select
        *,
        {{ surrogate_key(['first_name', 'last_name', 'residence_country_code', 'document_type',
                          'document_number', 'document_country_code', 'email', 'is_self_excluded']) }}
            as attr_hash
    from {{ ref('stg_raw__clients_cdc') }}
),

changed as (
    select *
    from events
    qualify coalesce(
        lag(attr_hash) over (partition by client_id order by changed_at), ''
    ) <> attr_hash
),

registration as (
    -- registration facts are immutable: take them from the create event
    select
        client_id,
        min(registered_at)                                      as registered_at,
        arg_min(registration_casino_id, changed_at)             as registration_casino_id
    from events
    group by client_id
)

select
    c.client_id,
    c.first_name,
    c.last_name,
    c.birth_date,
    c.gender,
    c.document_type,
    c.document_number,
    c.document_country_code,
    c.residence_country_code,
    c.email,
    c.is_self_excluded,
    r.registered_at,
    r.registration_casino_id,
    c.changed_at                                                        as valid_from,
    coalesce(
        lead(c.changed_at) over (partition by c.client_id order by c.changed_at),
        timestamp '9999-12-31'
    )                                                                   as valid_to,
    row_number() over (partition by c.client_id order by c.changed_at)  as version_number,
    c.cdc_operation
from changed c
join registration r using (client_id)
