{{ config(
    materialized='incremental',
    unique_key='gameplay_id',
    incremental_strategy='delete+insert',
    on_schema_change='append_new_columns'
) }}

{{ gameplay_fact(
    'stg_raw__table_gameplays',
    [{'id': 'table_id', 'sk': 'table_sk'}],
    ['win', 'loss']
) }}
