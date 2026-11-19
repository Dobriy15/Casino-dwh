select
    {{ surrogate_key(['m.machine_id']) }}   as machine_sk,
    m.machine_id,
    m.asset_tag,
    m.serial_number,
    m.manufacturer,
    m.model,
    m.floor_zone,
    m.installed_at,
    m.decommissioned_at,
    m.decommissioned_at is null             as is_active,
    {{ surrogate_key(['m.casino_id']) }}    as casino_sk,
    m.casino_id
from {{ ref('stg_raw__gaming_machines') }} m
