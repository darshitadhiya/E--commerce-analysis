-- Analysing business trends and seasonality
USE mavenfuzzyfactory;
-- 1 Analysing seasonality
-- Step: Aggregate weekly session and order volume for 2012
SELECT
    YEAR(website_sessions.created_at) AS yr,   -- Year of the session (2012)
    WEEK(website_sessions.created_at) AS wk,  -- Week number in the year
    MIN(DATE(website_sessions.created_at)) AS week_start,  -- Start date of that week

    -- Total sessions in that week
    COUNT(DISTINCT website_sessions.website_session_id) AS sessions,

    -- Total orders in that week
    COUNT(DISTINCT orders.order_id) AS orders

FROM website_sessions

-- Join orders to get order count per session
LEFT JOIN orders
ON website_sessions.website_session_id = orders.website_session_id

-- Only include sessions/orders before Jan 1, 2013
WHERE website_sessions.created_at < '2013-01-01'

-- Group by year and week to get weekly aggregates
GROUP BY
    YEAR(website_sessions.created_at),
    WEEK(website_sessions.created_at)

-- Optional: order by year and week to see trend chronologically
ORDER BY
    YEAR(website_sessions.created_at),
    WEEK(website_sessions.created_at);
    
    
-- 2 Analysing Business patterns
-- Step: Calculate average website sessions by hour of day and by day of week
SELECT
    hr,  -- Hour of the day (0-23)
    
    -- Average sessions across all days for this hour
    ROUND(AVG(website_sessions), 1) AS avg_sessions,
    
    -- Average sessions for each weekday (Monday=0, Tuesday=1, etc.)
    AVG(CASE WHEN wkday = 0 THEN website_sessions ELSE NULL END) AS mon,
    AVG(CASE WHEN wkday = 1 THEN website_sessions ELSE NULL END) AS tues,
    AVG(CASE WHEN wkday = 2 THEN website_sessions ELSE NULL END) AS wed,
    AVG(CASE WHEN wkday = 3 THEN website_sessions ELSE NULL END) AS thurs,
    AVG(CASE WHEN wkday = 4 THEN website_sessions ELSE NULL END) AS fri,
    AVG(CASE WHEN wkday = 5 THEN website_sessions ELSE NULL END) AS sat,
    AVG(CASE WHEN wkday = 6 THEN website_sessions ELSE NULL END) AS sun

FROM
(
    -- Subquery: Count sessions per date, hour, and weekday
    SELECT
        DATE(created_at) AS created_date,   -- Date of the session
        WEEKDAY(created_at) AS wkday,       -- Weekday number (Monday=0)
        HOUR(created_at) AS hr,             -- Hour of the day (0-23)
        COUNT(DISTINCT website_session_id) AS website_sessions  -- Total sessions in this date/hour
    FROM website_sessions
    WHERE created_at BETWEEN '2012-09-15' AND '2012-11-15'  -- Filter for requested date range
    GROUP BY
        DATE(created_at),
        WEEKDAY(created_at),
        HOUR(created_at)
) AS daily_hourly_sessions

-- Aggregate by hour to get average sessions per hour across the entire period
GROUP BY hr
ORDER BY hr;

