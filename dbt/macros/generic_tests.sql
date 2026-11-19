{#- Column must be >= 0 -#}
{% test non_negative(model, column_name) %}
select * from {{ model }} where {{ column_name }} < 0
{% endtest %}

{#- SCD2 integrity: for each business key, validity intervals must not overlap
    and exactly one row must be current. -#}
{% test scd2_valid_intervals(model, business_key, valid_from='valid_from', valid_to='valid_to') %}
with ordered as (
    select
        {{ business_key }} as bk,
        {{ valid_from }} as vf,
        {{ valid_to }} as vt,
        lead({{ valid_from }}) over (partition by {{ business_key }} order by {{ valid_from }}) as next_vf
    from {{ model }}
),
interval_breaks as (
    select bk, 'overlap_or_gap' as issue from ordered
    where next_vf is not null and vt <> next_vf
),
currents as (
    select bk, 'current_rows_' || count(*) as issue from ordered
    where vt = timestamp '9999-12-31'
    group by bk having count(*) <> 1
)
select * from interval_breaks
union all
select * from currents
{% endtest %}

{#- Composite uniqueness (avoids a dbt_utils dependency). -#}
{% test unique_combination(model, columns) %}
select {{ columns | join(', ') }}, count(*) as n
from {{ model }}
group by {{ columns | join(', ') }}
having count(*) > 1
{% endtest %}
