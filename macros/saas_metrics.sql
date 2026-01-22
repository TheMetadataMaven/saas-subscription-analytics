/*
    Macro: generate_date_spine
    
    Generates a date spine table for filling gaps in time series data.
    Useful for ensuring every date/month is represented even when no events occurred.
    
    Usage:
    {{ generate_date_spine('2023-01-01', '2024-12-31', 'day') }}
*/
{% macro generate_date_spine(start_date, end_date, date_part='day') %}

{% if date_part == 'day' %}
SELECT
    date_day AS date_value
FROM UNNEST(
    GENERATE_DATE_ARRAY(
        DATE('{{ start_date }}'),
        DATE('{{ end_date }}'),
        INTERVAL 1 DAY
    )
) AS date_day

{% elif date_part == 'month' %}
SELECT
    DATE_TRUNC(date_month, MONTH) AS date_value
FROM UNNEST(
    GENERATE_DATE_ARRAY(
        DATE_TRUNC(DATE('{{ start_date }}'), MONTH),
        DATE_TRUNC(DATE('{{ end_date }}'), MONTH),
        INTERVAL 1 MONTH
    )
) AS date_month

{% elif date_part == 'week' %}
SELECT
    DATE_TRUNC(date_week, WEEK) AS date_value
FROM UNNEST(
    GENERATE_DATE_ARRAY(
        DATE_TRUNC(DATE('{{ start_date }}'), WEEK),
        DATE_TRUNC(DATE('{{ end_date }}'), WEEK),
        INTERVAL 1 WEEK
    )
) AS date_week

{% endif %}

{% endmacro %}


/*
    Macro: safe_divide
    
    Performs division with null handling to avoid divide-by-zero errors.
    
    Usage:
    {{ safe_divide('numerator', 'denominator') }}
*/
{% macro safe_divide(numerator, denominator, default=0) %}
    CASE 
        WHEN {{ denominator }} IS NULL OR {{ denominator }} = 0 
        THEN {{ default }}
        ELSE {{ numerator }} / {{ denominator }}
    END
{% endmacro %}


/*
    Macro: cents_to_dollars
    
    Converts cents to dollars with proper rounding.
    Useful when source data stores amounts in cents.
    
    Usage:
    {{ cents_to_dollars('amount_cents') }}
*/
{% macro cents_to_dollars(amount_cents) %}
    ROUND({{ amount_cents }} / 100.0, 2)
{% endmacro %}


/*
    Macro: calculate_mrr_movement
    
    Determines the MRR movement type based on beginning and ending MRR.
    
    Usage:
    {{ calculate_mrr_movement('beginning_mrr', 'ending_mrr', 'is_first_month') }}
*/
{% macro calculate_mrr_movement(beginning_mrr, ending_mrr, is_first_month) %}
    CASE
        WHEN {{ is_first_month }} AND {{ ending_mrr }} > 0 THEN 'new'
        WHEN COALESCE({{ beginning_mrr }}, 0) = 0 AND {{ ending_mrr }} > 0 THEN 'resurrection'
        WHEN {{ beginning_mrr }} > 0 AND {{ ending_mrr }} > {{ beginning_mrr }} THEN 'expansion'
        WHEN {{ beginning_mrr }} > 0 AND {{ ending_mrr }} < {{ beginning_mrr }} AND {{ ending_mrr }} > 0 THEN 'contraction'
        WHEN COALESCE({{ beginning_mrr }}, 0) > 0 AND {{ ending_mrr }} = 0 THEN 'churn'
        ELSE 'unchanged'
    END
{% endmacro %}


/*
    Macro: cohort_month
    
    Extracts the cohort month key from a date.
    
    Usage:
    {{ cohort_month('signup_date') }}
*/
{% macro cohort_month(date_column) %}
    FORMAT_DATE('%Y-%m', DATE({{ date_column }}))
{% endmacro %}


/*
    Macro: tenure_bucket
    
    Categorizes tenure into standard buckets.
    
    Usage:
    {{ tenure_bucket('days_since_signup') }}
*/
{% macro tenure_bucket(days_column) %}
    CASE
        WHEN {{ days_column }} <= 30 THEN '0-30 days'
        WHEN {{ days_column }} <= 90 THEN '31-90 days'
        WHEN {{ days_column }} <= 180 THEN '91-180 days'
        WHEN {{ days_column }} <= 365 THEN '181-365 days'
        ELSE '365+ days'
    END
{% endmacro %}


/*
    Macro: time_decay_weight
    
    Calculates time decay attribution weight with configurable half-life.
    
    Usage:
    {{ time_decay_weight('days_to_conversion', 7) }}
*/
{% macro time_decay_weight(days_column, half_life=7) %}
    POW(0.5, {{ days_column }} / {{ half_life }}.0)
{% endmacro %}
