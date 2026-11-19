{{ config(
    materialized='incremental',
    unique_key='gameplay_id',
    incremental_strategy='delete+insert',
    on_schema_change='append_new_columns'
) }}

{{ gameplay_fact(
    'stg_raw__machine_gameplays',
    [{'id': 'machine_id', 'sk': 'machine_sk'}, {'id': 'game_id', 'sk': 'game_sk'}],
    ['win', 'loss']
) }}
