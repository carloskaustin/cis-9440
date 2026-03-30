-- Clean and standardize restaurant roadway/sidewalk seating application data
-- One row per application / record

WITH source AS (
    SELECT * FROM {{ source('raw', 'source_nyc_open_restaurant_apps') }}
), -- Easier to refer to the dbt reference to a long name table this way

cleaned AS (
    SELECT
        -- Get all columns from source, except ones we're transforming below
        -- To do cleaning on them or explicitly cast them as types just in case
        * EXCEPT (
            objectid,
            globalid,
            seating_interest_sidewalk,
            restaurant_name,
            legal_business_name,
            doing_business_as_dba,
            bulding_number,
            street,
            borough,
            zip,
            business_address,
            food_service_establishment,
            sidewalk_dimensions_length,
            sidewalk_dimensions_width,
            sidewalk_dimensions_area,
            roadway_dimensions_length,
            roadway_dimensions_width,
            roadway_dimensions_area,
            approved_for_sidewalk_seating,
            approved_for_roadway_seating,
            qualify_alcohol,
            sla_serial_number,
            sla_license_type,
            landmark_district_or_building,
            landmarkdistrict_terms,
            healthcompliance_terms,
            time_of_submission,
            latitude,
            longitude,
            community_board,
            council_district,
            census_tract,
            bin,
            bbl,
            nta
        ),

        -- Identifiers
        CAST(objectid AS STRING) AS application_id,
        CAST(globalid AS STRING) AS global_id,

        -- Restaurant / business details
        CAST(seating_interest_sidewalk AS STRING) AS seating_interest_sidewalk,
        CAST(restaurant_name AS STRING) AS restaurant_name,
        CAST(legal_business_name AS STRING) AS legal_business_name,
        CAST(doing_business_as_dba AS STRING) AS doing_business_as_dba,

        -- Address
        CAST(bulding_number AS STRING) AS building_number,
        CAST(street AS STRING) AS street,

        CASE
            WHEN UPPER(TRIM(borough)) IN ('MANHATTAN', 'NEW YORK COUNTY') THEN 'Manhattan'
            WHEN UPPER(TRIM(borough)) IN ('BRONX', 'THE BRONX') THEN 'Bronx'
            WHEN UPPER(TRIM(borough)) IN ('BROOKLYN', 'KINGS COUNTY') THEN 'Brooklyn'
            WHEN UPPER(TRIM(borough)) IN ('QUEENS', 'QUEEN', 'QUEENS COUNTY') THEN 'Queens'
            WHEN UPPER(TRIM(borough)) IN ('STATEN ISLAND', 'RICHMOND COUNTY') THEN 'Staten Island'
            ELSE 'UNKNOWN'
        END AS borough,

        CASE
            WHEN UPPER(TRIM(CAST(zip AS STRING))) IN ('N/A', 'NA', '') THEN NULL
            WHEN LENGTH(TRIM(CAST(zip AS STRING))) = 5 THEN TRIM(CAST(zip AS STRING))
            WHEN LENGTH(TRIM(CAST(zip AS STRING))) = 9 THEN TRIM(CAST(zip AS STRING))
            WHEN LENGTH(TRIM(CAST(zip AS STRING))) = 10
                AND REGEXP_CONTAINS(TRIM(CAST(zip AS STRING)), r'^\d{5}-\d{4}$')
            THEN TRIM(CAST(zip AS STRING))
            ELSE NULL
        END AS zip,

        CAST(business_address AS STRING) AS business_address,

        -- Establishment / application details
        CAST(food_service_establishment AS STRING) AS food_service_establishment,
        CAST(approved_for_sidewalk_seating AS STRING) AS approved_for_sidewalk_seating,
        CAST(approved_for_roadway_seating AS STRING) AS approved_for_roadway_seating,
        CAST(qualify_alcohol AS STRING) AS qualify_alcohol,
        CAST(sla_serial_number AS STRING) AS sla_serial_number,
        CAST(sla_license_type AS STRING) AS sla_license_type,
        CAST(landmark_district_or_building AS STRING) AS landmark_district_or_building,
        CAST(landmarkdistrict_terms AS STRING) AS landmarkdistrict_terms,
        CAST(healthcompliance_terms AS STRING) AS healthcompliance_terms,

        -- Dimensions
        CAST(sidewalk_dimensions_length AS DECIMAL) AS sidewalk_dimensions_length,
        CAST(sidewalk_dimensions_width AS DECIMAL) AS sidewalk_dimensions_width,
        CAST(sidewalk_dimensions_area AS DECIMAL) AS sidewalk_dimensions_area,
        CAST(roadway_dimensions_length AS DECIMAL) AS roadway_dimensions_length,
        CAST(roadway_dimensions_width AS DECIMAL) AS roadway_dimensions_width,
        CAST(roadway_dimensions_area AS DECIMAL) AS roadway_dimensions_area,

        -- Date/Time
        CAST(time_of_submission AS TIMESTAMP) AS time_of_submission,

        -- Geography / districting
        CAST(latitude AS DECIMAL) AS latitude,
        CAST(longitude AS DECIMAL) AS longitude,
        CAST(community_board AS STRING) AS community_board,
        CAST(council_district AS STRING) AS council_district,
        CAST(census_tract AS STRING) AS census_tract,
        CAST(bin AS STRING) AS bin,
        CAST(bbl AS STRING) AS bbl,
        CAST(nta AS STRING) AS nta,

        -- Metadata
        CURRENT_TIMESTAMP() AS _stg_loaded_at

    FROM source

    -- Filters
    WHERE objectid IS NOT NULL
      AND globalid IS NOT NULL
      AND time_of_submission IS NOT NULL
      AND borough IS NOT NULL

    -- Deduplicate
    QUALIFY ROW_NUMBER() OVER (
        PARTITION BY objectid
        ORDER BY time_of_submission DESC
    ) = 1
)

SELECT * FROM cleaned
-- All should be part of this table: stg_restaurant_seating