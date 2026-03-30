-- Clean and standardize NYC Open Restaurant application data
-- One row per application

WITH source AS (
    SELECT * FROM {{ source('raw', 'source_nyc_open_restaurant_apps') }}
),

cleaned AS (
    SELECT
        -- Keep all other columns as-is, except the ones we want to transform
        * EXCEPT (
            objectid,
            globalid,
            bulding_number,
            borough,
            zip,
            time_of_submission,
            latitude,
            longitude
        ),

        -- Identifiers
        CAST(objectid AS STRING) AS application_id,
        CAST(globalid AS STRING) AS global_id,

        -- Fix misspelled raw column name and standardize type
        CAST(bulding_number AS STRING) AS building_number,

        -- Standardize borough values
        CASE
            WHEN UPPER(TRIM(CAST(borough AS STRING))) IN ('MANHATTAN', 'NEW YORK COUNTY') THEN 'Manhattan'
            WHEN UPPER(TRIM(CAST(borough AS STRING))) IN ('BRONX', 'THE BRONX') THEN 'Bronx'
            WHEN UPPER(TRIM(CAST(borough AS STRING))) IN ('BROOKLYN', 'KINGS COUNTY') THEN 'Brooklyn'
            WHEN UPPER(TRIM(CAST(borough AS STRING))) IN ('QUEENS', 'QUEEN', 'QUEENS COUNTY') THEN 'Queens'
            WHEN UPPER(TRIM(CAST(borough AS STRING))) IN ('STATEN ISLAND', 'RICHMOND COUNTY') THEN 'Staten Island'
            ELSE 'UNKNOWN'
        END AS borough,

        -- Clean zip code
        CASE
            WHEN UPPER(TRIM(CAST(zip AS STRING))) IN ('N/A', 'NA', '') THEN NULL
            WHEN REGEXP_CONTAINS(TRIM(CAST(zip AS STRING)), r'^\d{5}$') THEN TRIM(CAST(zip AS STRING))
            WHEN REGEXP_CONTAINS(TRIM(CAST(zip AS STRING)), r'^\d{5}-\d{4}$') THEN TRIM(CAST(zip AS STRING))
            ELSE NULL
        END AS zip,

        -- Safe casting for datetime and coordinates
        SAFE_CAST(time_of_submission AS TIMESTAMP) AS time_of_submission,
        SAFE_CAST(latitude AS NUMERIC) AS latitude,
        SAFE_CAST(longitude AS NUMERIC) AS longitude,

        -- Metadata
        CURRENT_TIMESTAMP() AS _stg_loaded_at

    FROM source

    -- Filters
    WHERE objectid IS NOT NULL
      AND time_of_submission IS NOT NULL
      AND borough IS NOT NULL

    -- Deduplicate
    QUALIFY ROW_NUMBER() OVER (
        PARTITION BY objectid
        ORDER BY SAFE_CAST(time_of_submission AS TIMESTAMP) DESC
    ) = 1
)

SELECT * FROM cleaned
-- All should be part of this table: stg_nyc_open_restaurant_apps