-- Analysing Traffic Sources

-- 1. Finding out the top traffic sources
SELECT
  utm_source,
  utm_campaign,
  http_referer,
  COUNT(DISTINCT website_session_id) AS number_of_sessions
FROM website_sessions
WHERE created_at < '2012-04-12'
GROUP BY utm_source, utm_campaign, http_referer
ORDER BY number_of_sessions DESC;

-- 2 Calculating Conversion Rate (Sessions → Orders) 
--   - gsearch nonbrand is currently the main traffic source.
--   - We are evaluating if its conversion rate meets our 
--     minimum target of 4%.
--   - If CVR < 4%, reduce bids to save cost.
--   - If CVR > 4%, consider increasing bids to gain more volume.

SELECT
    COUNT(DISTINCT ws.website_session_id) AS total_sessions,
    COUNT(DISTINCT o.order_id) AS total_orders,
    ROUND(COUNT(DISTINCT o.order_id) * 100.0 / COUNT(DISTINCT ws.website_session_id), 2) AS conversion_rate
FROM website_sessions ws
LEFT JOIN orders o
    ON ws.website_session_id = o.website_session_id
WHERE ws.utm_source = 'gsearch'
  AND ws.utm_campaign = 'nonbrand'
  AND ws.created_at < '2012-04-12';

-- 3.Trended Session Volume after Bid-Down
--   - Based on earlier CVR analysis, we bid down gsearch nonbrand
--     campaigns on 2012-04-15 to reduce cost.
--   - This query pulls weekly session trends to check if traffic
--     volume dropped after the bid change.
--   - Data covers weeks before and after the bid change. 

SELECT 
    -- YEAR(created_at) AS yr,      -- optional: year for grouping
    -- WEEK(created_at) AS wk,      -- optional: week number for grouping
    MIN(DATE(created_at)) AS week_started_at,               -- first date of that week
    COUNT(DISTINCT website_session_id) AS sessions          -- unique sessions in that week
FROM website_sessions
WHERE created_at < '2012-05-10'                             -- up to end date for analysis
  AND utm_source = 'gsearch'
  AND utm_campaign = 'nonbrand'
GROUP BY YEAR(created_at), WEEK(created_at)                  -- group by week
ORDER BY week_started_at;                                    -- chronological order


-- 4 --   - The site experience on mobile was reported to be poor.
--   - Goal: Compare conversion rates (Sessions → Orders) for
--     desktop vs mobile users.
--   - If desktop performs significantly better, we may consider
--     increasing bids for desktop traffic to drive more volume,
--     while potentially reducing bids for mobile.
SELECT
    ws.device_type,
    COUNT(DISTINCT ws.website_session_id) AS sessions,
    COUNT(DISTINCT o.order_id) AS orders,
    COUNT(DISTINCT o.order_id) / COUNT(DISTINCT ws.website_session_id) AS session_to_order_cvr
FROM website_sessions ws
LEFT JOIN orders o
    ON ws.website_session_id = o.website_session_id
WHERE ws.created_at < '2012-05-11'
    AND ws.utm_source = 'gsearch' 
    AND ws.utm_campaign = 'nonbrand'
GROUP BY ws.device_type;

-- 5 Weekly Traffic Trends by Device Type (Pre & Post Bid-Up)
--   - Device-level CVR analysis showed desktop performing better than mobile.
--   - On 2012-05-19, we increased bids for gsearch nonbrand desktop campaigns
--     to capture more high-converting desktop traffic.
--   - This query pulls weekly session counts for both desktop and mobile
--     from 2012-04-15 until 2012-06-09 to measure impact on volume.
--   - Baseline period: 2012-04-15 to just before 2012-05-19.

SELECT
    YEAR(created_at) AS yr,
    WEEK(created_at) AS wk,
    MIN(DATE(created_at)) AS week_start_date,

    COUNT(DISTINCT CASE WHEN device_type = 'desktop' 
                        THEN website_session_id END) AS desktop_sessions,

    COUNT(DISTINCT CASE WHEN device_type = 'mobile' 
                        THEN website_session_id END) AS mobile_sessions,

    COUNT(DISTINCT website_session_id) AS total_sessions

FROM website_sessions
WHERE created_at < '2012-06-09'
  AND created_at > '2012-04-15'
  AND utm_source = 'gsearch'
  AND utm_campaign = 'nonbrand'
GROUP BY
    YEAR(created_at),
    WEEK(created_at)
ORDER BY
    yr, wk;