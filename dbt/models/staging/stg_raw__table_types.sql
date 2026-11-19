select
    cast(table_type_id as integer) as table_type_id,
    upper(table_type_code)         as table_type_code,
    table_type_name,
    category                       as table_type_category
from {{ source('raw', 'table_types') }}
