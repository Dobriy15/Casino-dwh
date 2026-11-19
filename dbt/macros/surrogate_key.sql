{#- Deterministic hash-based surrogate key (dbt_utils-compatible semantics, no package dependency). -#}
{% macro surrogate_key(columns) -%}
    md5(concat_ws('||', {% for c in columns -%}
        coalesce(cast({{ c }} as varchar), '_null_'){{ ", " if not loop.last }}
    {%- endfor %}))
{%- endmacro %}

{#- Integer date key yyyymmdd, the conventional key for dim_date. -#}
{% macro date_key(expr) -%}
    cast(strftime(cast({{ expr }} as date), '%Y%m%d') as integer)
{%- endmacro %}

{#- Gaming (business) day: casinos operate past midnight, so a 02:00 spin belongs to the
    previous day's shift/accounting. Cut-off hour is configurable via var('gaming_day_cutoff_hour'). -#}
{% macro gaming_date(ts) -%}
    cast({{ ts }} - interval {{ var('gaming_day_cutoff_hour') }} hour as date)
{%- endmacro %}
