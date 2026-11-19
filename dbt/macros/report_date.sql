{#- "As-of" date for relative reports. Uses var('report_date') when given,
    otherwise the latest date with casino activity in the warehouse. -#}
{% macro report_date() -%}
    {%- if var('report_date') -%}
        cast('{{ var("report_date") }}' as date)
    {%- else -%}
        (select max(visit_date) from {{ ref('fct_casino_visit') }})
    {%- endif -%}
{%- endmacro %}
