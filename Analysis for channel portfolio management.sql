-- ANALYSIS OF CHANNEL PORTFOLIO MANAGEMENT

/* 1 : Analysing channel portfolios
Goal: bsearch (launched ~Aug 22) ka weekly session trend nikalna 
      aur gsearch nonbrand ke saath compare karna.

Data source: website_sessions
Important fields: created_at (timestamp), website_session_id, utm_source, utm_campaign

High-level steps:
1) Time window filter: Aug 22, 2012 se Nov 28, 2012 tak
2) Campaign filter: nonbrand (paid search nonbrand only)
3) Weekly bucket: YEARWEEK() se week-wise group
4) Metrics per week:
   - total_nonbrand_sessions: nonbrand ke total sessions (all sources within nonbrand)
   - gsearch_sessions: nonbrand me gsearch ka sessions count
   - bsearch_sessions: nonbrand me bsearch ka sessions count
*/
USE mavenfuzzyfactory;

SELECT
    /* YEARWEEK: year+week number (e.g., 201234 = 2012 ka week 34).
       Mode 0 default (weeks start on Sunday). Agar Monday-start chahiye, mode 3 use kar sakte ho. */
     YEARWEEK(created_at, 0) AS yrwk,

    /* Us weekly bucket ka earliest calendar date (visual labeling ke liye helpful). */
    MIN(DATE(created_at)) AS week_start_date,

    /* Nonbrand ke total unique sessions for the week (source-agnostic within nonbrand). */
    COUNT(DISTINCT website_session_id) AS total_nonbrand_sessions,

    /* gsearch (nonbrand) sessions per week. DISTINCT se duplicate session double-count nahi hoga. */
    COUNT(DISTINCT CASE 
                     WHEN utm_source = 'gsearch' THEN website_session_id 
                     ELSE NULL 
                   END) AS gsearch_sessions,

    /* bsearch (nonbrand) sessions per week. */
    COUNT(DISTINCT CASE 
                     WHEN utm_source = 'bsearch' THEN website_session_id 
                     ELSE NULL 
                   END) AS bsearch_sessions

FROM website_sessions
WHERE 
    /* Test launch ke baad ka data include karo (Aug 22 inclusive rakhna banta hai). */
    created_at >= '2012-08-22'
    /* Assignment ke cutoff tak ka data. */
    AND created_at <  '2012-11-29'
    /* Sirf nonbrand paid traffic par focus. */
    AND utm_campaign = 'nonbrand'

/* Week-wise aggregation. */
GROUP BY YEARWEEK(created_at, 0)

/* Trend ko chronological order me dikhane ke liye. */
ORDER BY yrwk;


-- 2 Comparing Channel Characteristics
-- Pull overall sessions, mobile sessions, and % mobile
-- for gsearch vs bsearch nonbrand traffic since Aug 22

SELECT
    utm_source,   -- differentiate between gsearch and bsearch

    -- total sessions
    COUNT(DISTINCT website_sessions.website_session_id) AS sessions,

    -- total mobile sessions only
    COUNT(DISTINCT CASE 
                      WHEN device_type = 'mobile' 
                      THEN website_sessions.website_session_id 
                   END) AS mobile_sessions,

    -- percentage of sessions that are mobile
    COUNT(DISTINCT CASE 
                      WHEN device_type = 'mobile' 
                      THEN website_sessions.website_session_id 
                   END) 
    / COUNT(DISTINCT website_sessions.website_session_id) AS pct_mobile

FROM website_sessions
WHERE created_at >= '2012-08-22'   -- starting point from Tom's request
  AND created_at < '2012-11-30'    -- cut-off date (based on request timing)
  AND utm_campaign = 'nonbrand'    -- only nonbrand paid traffic
  AND utm_source IN ('gsearch', 'bsearch') -- restrict to only these two sources

GROUP BY utm_source;

-- 3 Cross Bid Optimisation
SELECT
    website_sessions.device_type,  -- user ka device type (desktop/mobile/tablet)
    website_sessions.utm_source,   -- traffic source (gsearch ya bsearch)
    
    -- total unique sessions count kar rahe hain
    COUNT(DISTINCT website_sessions.website_session_id) AS sessions,
    
    -- total unique orders count kar rahe hain
    COUNT(DISTINCT orders.order_id) AS orders,
    
    -- conversion rate: orders / sessions (float me nikalne ke liye 1.0 multiply kiya)
    COUNT(DISTINCT orders.order_id) * 1.0 
        / COUNT(DISTINCT website_sessions.website_session_id) AS conv_rate

FROM website_sessions

-- sessions ko orders table ke saath join kar rahe hain
LEFT JOIN orders
    ON orders.website_session_id = website_sessions.website_session_id

WHERE website_sessions.created_at >= '2012-08-22'  -- start date (Tom ke request se)
  AND website_sessions.created_at < '2012-09-19'   -- end date (special campaign se pehle tak ka data)
  AND website_sessions.utm_campaign = 'nonbrand'   -- sirf nonbrand paid search data chahiye

-- grouping kar rahe hain device type aur source ke hisaab se
GROUP BY
    website_sessions.device_type,
    website_sessions.utm_source;
-- 4 : Analysing channel portfolio trends
SELECT
    YEARWEEK(created_at) AS year_week,                                -- Week number
    MIN(DATE(created_at)) AS week_start_date,                         -- Starting date of that week

    -- Desktop Sessions
    COUNT(DISTINCT CASE WHEN utm_source = 'gsearch' AND device_type = 'desktop' 
                        THEN website_session_id END) AS g_dtop_sessions,
    COUNT(DISTINCT CASE WHEN utm_source = 'bsearch' AND device_type = 'desktop' 
                        THEN website_session_id END) AS b_dtop_sessions,

    -- % of bsearch vs gsearch on Desktop
    COUNT(DISTINCT CASE WHEN utm_source = 'bsearch' AND device_type = 'desktop' 
                        THEN website_session_id END) * 1.0 /
    NULLIF(COUNT(DISTINCT CASE WHEN utm_source = 'gsearch' AND device_type = 'desktop' 
                               THEN website_session_id END), 0) AS b_pct_of_g_dtop,

    -- Mobile Sessions
    COUNT(DISTINCT CASE WHEN utm_source = 'gsearch' AND device_type = 'mobile' 
                        THEN website_session_id END) AS g_mob_sessions,
    COUNT(DISTINCT CASE WHEN utm_source = 'bsearch' AND device_type = 'mobile' 
                        THEN website_session_id END) AS b_mob_sessions,

    -- % of bsearch vs gsearch on Mobile
    COUNT(DISTINCT CASE WHEN utm_source = 'bsearch' AND device_type = 'mobile' 
                        THEN website_session_id END) * 1.0 /
    NULLIF(COUNT(DISTINCT CASE WHEN utm_source = 'gsearch' AND device_type = 'mobile' 
                               THEN website_session_id END), 0) AS b_pct_of_g_mob

FROM website_sessions
WHERE created_at >= '2012-11-04'          -- start date as per request
  AND created_at <  '2012-12-22'          -- end date as per request
  AND utm_campaign = 'nonbrand'           -- only nonbrand paid search
GROUP BY YEARWEEK(created_at)
ORDER BY week_start_date;

-- 5 Analysing Direct Traffic 
-- Step 1:
SELECT
    website_session_id,
    created_at,

   
    CASE
        -- If no UTM source but referrer is Google or Bing → this is Organic Search traffic
        WHEN utm_source IS NULL 
             AND http_referer IN ('https://www.gsearch.com', 'https://www.bsearch.com') 
        THEN 'organic_search'

        -- If campaign is tagged as "nonbrand" → this is Paid Nonbrand traffic
        WHEN utm_campaign = 'nonbrand' 
        THEN 'paid_nonbrand'

        -- If campaign is tagged as "brand" → this is Paid Brand traffic
        WHEN utm_campaign = 'brand' 
        THEN 'paid_brand'

        -- If no UTM and no referrer → user typed in the URL directly (Direct traffic)
        WHEN utm_source IS NULL 
             AND http_referer IS NULL 
        THEN 'direct_type_in'
    END AS channel_group


FROM website_sessions;

-- Step 2: Aggregate channel sessions by month and calculate percentages vs paid nonbrand

SELECT
    YEAR(created_at) AS yr,      -- Year of the session
    MONTH(created_at) AS mo,     -- Month of the session

    -- Total Paid Nonbrand sessions
    COUNT(DISTINCT CASE WHEN channel_group = 'paid_nonbrand' 
                        THEN website_session_id END) AS nonbrand,

    -- Total Paid Brand sessions
    COUNT(DISTINCT CASE WHEN channel_group = 'paid_brand' 
                        THEN website_session_id END) AS brand,

    -- % Paid Brand sessions relative to Paid Nonbrand sessions
    COUNT(DISTINCT CASE WHEN channel_group = 'paid_brand' 
                        THEN website_session_id END) * 1.0 /
    NULLIF(COUNT(DISTINCT CASE WHEN channel_group = 'paid_nonbrand' 
                               THEN website_session_id END), 0) AS brand_pct_of_nonbrand,

    -- Total Direct Type-In sessions
    COUNT(DISTINCT CASE WHEN channel_group = 'direct_type_in' 
                        THEN website_session_id END) AS direct,

    -- % Direct Type-In relative to Paid Nonbrand
    COUNT(DISTINCT CASE WHEN channel_group = 'direct_type_in' 
                        THEN website_session_id END) * 1.0 /
    NULLIF(COUNT(DISTINCT CASE WHEN channel_group = 'paid_nonbrand' 
                               THEN website_session_id END), 0) AS direct_pct_of_nonbrand,

    -- Total Organic Search sessions
    COUNT(DISTINCT CASE WHEN channel_group = 'organic_search' 
                        THEN website_session_id END) AS organic,

    -- % Organic Search relative to Paid Nonbrand
    COUNT(DISTINCT CASE WHEN channel_group = 'organic_search' 
                        THEN website_session_id END) * 1.0 /
    NULLIF(COUNT(DISTINCT CASE WHEN channel_group = 'paid_nonbrand' 
                               THEN website_session_id END), 0) AS organic_pct_of_nonbrand

FROM
(
    -- Step 1: Classify each session into a channel group
    SELECT
        website_session_id,
        created_at,
        CASE
            WHEN utm_source IS NULL 
                 AND http_referer IN ('https://www.gsearch.com','https://www.bsearch.com') 
            THEN 'organic_search'

            WHEN utm_campaign = 'nonbrand' 
            THEN 'paid_nonbrand'

            WHEN utm_campaign = 'brand' 
            THEN 'paid_brand'

            WHEN utm_source IS NULL 
                 AND http_referer IS NULL 
            THEN 'direct_type_in'
        END AS channel_group
    FROM website_sessions
    WHERE created_at < '2012-12-23'   -- limit sessions before Dec 23
) AS channel_classified
GROUP BY
    YEAR(created_at),
    MONTH(created_at)
ORDER BY
    YEAR(created_at),
    MONTH(created_at);





