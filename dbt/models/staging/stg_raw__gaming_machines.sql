select
    cast(machine_id as integer)       as machine_id,
    cast(casino_id as integer)        as casino_id,
    asset_tag,
    serial_number,
    manufacturer,
    model,
    floor_zone,
    cast(installed_at as date)        as installed_at,
    cast(decommissioned_at as date)   as decommissioned_at,
    updated_at
from {{ source('raw', 'gaming_machines') }}
