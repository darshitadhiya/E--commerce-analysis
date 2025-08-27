-- Analysing Website Performance
-- 1. Finding top website pages:
--    This query finds the most viewed website pages (pageview_url) before June 9, 2012.
--    It counts unique pageviews (website_pageview_id) for each page within each session,
USE mavenfuzzyfactory;

SELECT
    pageview_url,
    COUNT(DISTINCT website_pageview_id) AS pvs
FROM website_pageviews
WHERE created_at < '2012-06-09'
GROUP BY pageview_url
ORDER BY pvs DESC;


-- 2. Finding Top Entry Pages
-- Goal: Identify which website pages are most commonly the first page users see when starting a session,
--       and rank them by the number of sessions they attract.

-- STEP 1: Find the first pageview for each session
-- Explanation: For each website_session_id, we find the earliest (minimum) pageview_id to know where the session started.
CREATE TEMPORARY TABLE first_pv_per_session 
SELECT
    website_session_id,
    MIN(website_pageview_id) AS first_pv
FROM website_pageviews
WHERE created_at < '2012-06-12'
GROUP BY website_session_id;
select * from first_pv_per_session ;
-- STEP 2: Find the URL for that first pageview and count how many sessions landed there
-- Explanation: Join our first_pv_per_session table back to website_pageviews to get the actual pageview_url,
-- then count how many distinct sessions landed on each URL.
SELECT
    wp.pageview_url AS landing_page_url,
    COUNT(DISTINCT fps.website_session_id) AS sessions_hitting_page
FROM first_pv_per_session AS fps
LEFT JOIN website_pageviews AS wp
    ON fps.first_pv = wp.website_pageview_id
GROUP BY wp.pageview_url
ORDER BY sessions_hitting_page DESC;

-- 3 Calculating Bounce Rates
-- STEP 1 : finding first page view id for most relevant sessions
use mavenfuzzyfactory;
CREATE TEMPORARY TABLE first_pageviews AS
SELECT
    website_session_id,
    MIN(website_pageview_id) AS min_pageview_id
FROM website_pageviews
WHERE created_at < '2012-06-14'
GROUP BY website_session_id;


-- STEP 2 : Identify the landpage of each session 
CREATE TEMPORARY TABLE sessions_w_home_landing_page 
SELECT
    first_pageviews.website_session_id,
    website_pageviews.pageview_url AS landing_page
FROM first_pageviews
LEFT JOIN website_pageviews
    ON website_pageviews.website_pageview_id = first_pageviews.min_pageview_id
WHERE website_pageviews.pageview_url = '/home';

-- SELECT * FROM sessions_w_home_landing_page;

-- STEP 3 : Bounced sessions
SELECT
    sessions_w_home_landing_page.website_session_id,
    sessions_w_home_landing_page.landing_page,
    COUNT(website_pageviews.website_pageview_id) AS count_of_pages_viewed
FROM sessions_w_home_landing_page
LEFT JOIN website_pageviews
    ON website_pageviews.website_session_id = sessions_w_home_landing_page.website_session_id
GROUP BY
    sessions_w_home_landing_page.website_session_id,
    sessions_w_home_landing_page.landing_page
HAVING
    COUNT(website_pageviews.website_pageview_id) = 1;

-- select * from bounced_sessions;

SELECT
    sessions_w_home_landing_page.website_session_id,
    bounced_sessions.website_session_id AS bounced_website_session_id
FROM
    sessions_w_home_landing_page
LEFT JOIN
    bounced_sessions
    ON sessions_w_home_landing_page.website_session_id = bounced_sessions.website_session_id
ORDER BY
    sessions_w_home_landing_page.website_session_id;
-- final output :
SELECT
    COUNT(DISTINCT sessions_w_home_landing_page.website_session_id) AS sessions,
    COUNT(DISTINCT bounced_sessions.website_session_id) AS bounced_sessions,
    COUNT(DISTINCT bounced_sessions.website_session_id) * 1.0 
        / COUNT(DISTINCT sessions_w_home_landing_page.website_session_id) AS b
FROM
    sessions_w_home_landing_page
LEFT JOIN
    bounced_sessions
ON
    sessions_w_home_landing_page.website_session_id = bounced_sessions.website_session_id;
    
    
-- 4 Analysing landing page tests
USE mavenfuzzyfactory;

-- Step 0: Find out when the new lander page (/lander-1) was first launched
SELECT
    MIN(created_at) AS first_created_at,         -- sabse pehli baar yeh page kab load hua
    MIN(website_pageview_id) AS first_pageview_id -- sabse pehla pageview ka ID
FROM website_pageviews
WHERE pageview_url = '/lander-1'
  AND created_at IS NOT NULL;                    -- null values ko ignore karna, taaki galat date na aaye

-- Output from Step 0:
-- first_created_at = '2012-06-19 00:35:54'
-- first_pageview_id = 23504


-- Step 1: Create a temporary table with the first pageview for each relevant session
CREATE TEMPORARY TABLE first_test_pageviews AS
SELECT 
    wp.website_session_id,                            -- session ka ID
    MIN(wp.website_pageview_id) AS min_pageview_id    -- us session ka sabse pehla pageview ID
FROM website_pageviews AS wp

-- Join with sessions table to filter only relevant sessions
INNER JOIN website_sessions AS ws
    ON ws.website_session_id = wp.website_session_id

-- Filters according to the assignment
WHERE ws.created_at < '2012-07-28'                    -- sirf 28 July se pehle ke sessions
  AND wp.website_pageview_id > 23504                   -- sirf naya lander launch hone ke baad ke sessions
  AND ws.utm_source = 'gsearch'                        -- sirf gsearch traffic
  AND ws.utm_campaign = 'nonbrand'                     -- sirf nonbrand traffic

-- Group by session so MIN() kaam kare correctly
GROUP BY wp.website_session_id;

 -- Step 2: Create a temp table with landing page for each test session
CREATE TEMPORARY TABLE nonbrand_test_sessions_w_landing_page AS
SELECT
    ftp.website_session_id,                -- session ka ID
    wp.pageview_url AS landing_page         -- session ka landing page
FROM first_test_pageviews AS ftp
LEFT JOIN website_pageviews AS wp
    ON wp.website_pageview_id = ftp.min_pageview_id  -- pehle pageview se join
WHERE wp.pageview_url IN ('/home', '/lander-1');     -- sirf /home aur /lander-1 ke liye
-- select * from nonbrand_test_sessions_w_landing_page

-- Step 3: Create a temp table to identify bounced sessions
CREATE TEMPORARY TABLE nonbrand_test_bounced_sessions AS
SELECT
    nlp.website_session_id,                     -- session ka ID
    nlp.landing_page,                           -- landing page
    COUNT(wp.website_pageview_id) AS count_of_pages_viewed  -- total pages viewed in that session
FROM nonbrand_test_sessions_w_landing_page AS nlp
LEFT JOIN website_pageviews AS wp
    ON wp.website_session_id = nlp.website_session_id
GROUP BY
    nlp.website_session_id,
    nlp.landing_page
HAVING COUNT(wp.website_pageview_id) = 1;       -- sirf bounce sessions (1 page view)
-- select * from nonbrand_test_bounced_sessions


-- Step 4: Join landing page sessions with bounced sessions


SELECT
    nlp.landing_page,                   -- landing page URL (/home or /lander-1)
    nlp.website_session_id,             -- every session ID
    nb.website_session_id AS bounced_website_session_id -- will show session_id if it was a bounced session, NULL otherwise
FROM nonbrand_test_sessions_w_landing_page AS nlp
LEFT JOIN nonbrand_test_bounced_sessions AS nb
    ON nlp.website_session_id = nb.website_session_id
ORDER BY
    nlp.website_session_id;

-- Step 5: Calculate bounce rate per landing page(final output)
SELECT
    nlp.landing_page,   -- landing page URL (like /home or /lander-1)

    COUNT(DISTINCT nlp.website_session_id) AS sessions,  -- total sessions on that landing page

    COUNT(DISTINCT nb.website_session_id) AS bounced_sessions, -- how many of those sessions bounced

    COUNT(DISTINCT nb.website_session_id) * 1.0 / COUNT(DISTINCT nlp.website_session_id) AS bounce_rate
    -- bounce rate = bounced_sessions / total_sessions (converted to decimal with *1.0)
FROM nonbrand_test_sessions_w_landing_page AS nlp
LEFT JOIN nonbrand_test_bounced_sessions AS nb
    ON nlp.website_session_id = nb.website_session_id
GROUP BY
    nlp.landing_page;

-- 5. Landing Page Trend Analysis

-- Step 1: Create a temporary table with first pageview ID and total pageviews per session
-- Ye table har session ke liye first pageview ID aur total pageviews store karega
-- Taaki hum baad me weekly trend ya landing page analysis ke liye use kar saken
USE mavenfuzzyfactory;
CREATE TEMPORARY TABLE sessions_w_min_pv_id_and_view_count AS
SELECT
    ws.website_session_id,                 -- Session ka unique ID
    MIN(wp.website_pageview_id) AS first_pageview_id,  
                                           -- Har session me sabse pehla pageview ID
                                           -- MIN() use kiya kyunki pageviews chronological hote hain
    COUNT(wp.website_pageview_id) AS count_pageviews  
                                           -- Total pageviews per session
FROM 
    website_sessions ws                     -- Main table: sessions ke data ke liye
LEFT JOIN 
    website_pageviews wp                    -- Pageviews table join kar rahe hain
    ON ws.website_session_id = wp.website_session_id  
                                           -- Join condition: same session_id
WHERE 
    ws.created_at >= '2012-06-01'          -- Filter: sessions 1 June 2012 se start
    AND ws.created_at <= '2012-08-31'      -- Filter: sessions 31 August 2012 tak
    AND ws.utm_source = 'gsearch'          -- Paid search traffic ka source
    AND ws.utm_campaign = 'nonbrand'       -- Nonbrand campaign traffic
GROUP BY 
    ws.website_session_id;                  -- Group by session, taaki MIN() aur COUNT() per session calculate ho


 -- select * from sessions_w_min_pv_id_and_view_count ;
 
 -- Step 2: Create temporary table with landing page and session creation time
-- Ye table har session ke saath landing page aur session start time store karega
-- Taaki hum landing page ke hisaab se weekly trends nikal saken

CREATE TEMPORARY TABLE sessions_w_counts_lander_and_created_at AS
SELECT
    sc.website_session_id,                   -- Session ka unique ID
    sc.first_pageview_id,                    -- Session ka first pageview ID
    sc.count_pageviews,                      -- Total pageviews per session
    wp.pageview_url AS landing_page,         -- First pageview ka URL, i.e., landing page
    wp.created_at AS session_created_at      -- First pageview ka timestamp, session start time
FROM 
    sessions_w_min_pv_id_and_view_count sc  -- Step 1 ka temporary table (session-level metrics)
LEFT JOIN 
    website_pageviews wp                     -- Pageviews table join kar rahe hain
    ON sc.first_pageview_id = wp.website_pageview_id;
                                             -- Join condition: har session ka first pageview se match
 -- select * from sessions_w_counts_lander_and_created_at;
 
 -- Step 3: Weekly landing page trend with total sessions, bounced sessions, and bounce rate
-- Ye query har week ke liye: (final o/p)
-- 1. Total sessions
-- 2. Bounced sessions (sessions with only 1 pageview)
-- 3. Bounce rate
-- 4. Sessions per landing page ('/home' and '/lander-1')
-- nikalti hai

SELECT
    -- YEARWEEK(session_created_at) AS year_week,  -- Year and week number (e.g., 202512 for week 12 of 2025)
    MIN(DATE(session_created_at)) AS week_start_date,  -- Week start date (first day of the week)
    
    -- Total number of sessions in the week
   -- COUNT(DISTINCT website_session_id) AS total_sessions,
    
    -- Sessions that bounced (only 1 pageview)
     -- COUNT(DISTINCT CASE 
                     --  WHEN count_pageviews = 1 THEN website_session_id 
                      -- ELSE NULL 
                 --  END) AS bounced_sessions,
    
    -- Bounce rate calculation: bounced_sessions / total_sessions
    COUNT(DISTINCT CASE 
                       WHEN count_pageviews = 1 THEN website_session_id 
                       ELSE NULL 
                   END) * 1.0 / COUNT(DISTINCT website_session_id) AS bounce_rate,
    
    -- Sessions that started on '/home' landing page
    COUNT(DISTINCT CASE 
                       WHEN landing_page = '/home' THEN website_session_id 
                       ELSE NULL 
                   END) AS home_sessions,
    
    -- Sessions that started on '/lander-1' landing page
    COUNT(DISTINCT CASE 
                       WHEN landing_page = '/lander-1' THEN website_session_id 
                       ELSE NULL 
                   END) AS lander_sessions

FROM 
    sessions_w_counts_lander_and_created_at  -- Step 2 ka temporary table

GROUP BY
    YEARWEEK(session_created_at)              -- Weekly aggregation
ORDER BY
    YEARWEEK(session_created_at);             -- Optional: order by week for trend visualization



-- 6.  Building Conversion funnels
-- STEP 1: Select all pageviews for relevant sessions
-- Ye query har gsearch nonbrand session ke liye pageviews pull karegi
-- Aur identify karegi ki har pageview funnel ke kaunse step me belong karta hai

SELECT
    website_sessions.website_session_id,               -- Unique session ID
    website_pageviews.pageview_url,                    -- Pageview URL (visitor ne kaunsa page dekha)
    website_pageviews.created_at AS pageview_created_at,  -- Pageview ka timestamp

    -- Funnel step indicators: 1 = visitor ne page visit kiya, 0 = nahi kiya

    CASE WHEN pageview_url = '/products' THEN 1 ELSE 0 END AS products_page,   
        -- Product listing page visited? (Step 1)
    
    CASE WHEN pageview_url = '/the-original-mr-fuzzy' THEN 1 ELSE 0 END AS mrfuzzy_page,  
        -- Specific product page visited? (Step 2)
    
    CASE WHEN pageview_url = '/cart' THEN 1 ELSE 0 END AS cart_page,  
        -- Visitor ne cart page visit kiya? (Step 3)
    
    CASE WHEN pageview_url = '/shipping' THEN 1 ELSE 0 END AS shipping_page,  
        -- Visitor ne shipping page visit kiya? (Step 4)
    
    CASE WHEN pageview_url = '/billing' THEN 1 ELSE 0 END AS billing_page,  
        -- Visitor ne billing page visit kiya? (Step 5)
    
    CASE WHEN pageview_url = '/thank-you-for-your-order' THEN 1 ELSE 0 END AS thankyou_page  
        -- Visitor ne order complete kiya? (Thank You Page, Step 6)

FROM 
    website_sessions
LEFT JOIN 
    website_pageviews
    ON website_sessions.website_session_id = website_pageviews.website_session_id  
    -- Join: session ke saare pageviews ko match karna

WHERE 
    website_sessions.utm_source = 'gsearch'  
        -- Paid search traffic only
    AND website_sessions.utm_campaign = 'nonbrand'  
        -- Nonbrand campaign only
    AND website_sessions.created_at > '2012-08-05'  
        -- Only sessions after August 5th
    AND website_sessions.created_at < '2012-09-05'  
        -- Only sessions before September 5th

ORDER BY
    website_sessions.website_session_id,              -- Order by session for easy tracking
    website_pageviews.created_at;                     -- Order by pageview timestamp (chronological order)


-- STEP 2: Create session-level funnel table
-- Har session ke liye ye table identify karega ki visitor ne kaunse funnel step tak pohcha
CREATE TEMPORARY TABLE session_level_made_it_flags
SELECT
    website_session_id,

    -- MAX() use kiya har page ke liye, taaki agar session me page visit hua hai to 1 mile, nahi to 0
    MAX(products_page) AS product_made_it,         -- Product listing page visited
    MAX(mrfuzzy_page) AS mrfuzzy_made_it,         -- Specific product page visited
    MAX(cart_page) AS cart_made_it,               -- Cart page visited
    MAX(shipping_page) AS shipping_made_it,       -- Shipping page visited
    MAX(billing_page) AS billing_made_it,         -- Billing page visited
    MAX(thankyou_page) AS thankyou_made_it        -- Thank you page visited

FROM 
(
    -- Subquery: Pageview level flags (Step 1)
    SELECT
        ws.website_session_id,                     -- Unique session ID
        wp.pageview_url,

        CASE WHEN wp.pageview_url = '/products' THEN 1 ELSE 0 END AS products_page,
        CASE WHEN wp.pageview_url = '/the-original-mr-fuzzy' THEN 1 ELSE 0 END AS mrfuzzy_page,
        CASE WHEN wp.pageview_url = '/cart' THEN 1 ELSE 0 END AS cart_page,
        CASE WHEN wp.pageview_url = '/shipping' THEN 1 ELSE 0 END AS shipping_page,
        CASE WHEN wp.pageview_url = '/billing' THEN 1 ELSE 0 END AS billing_page,
        CASE WHEN wp.pageview_url = '/thank-you-for-your-order' THEN 1 ELSE 0 END AS thankyou_page

    FROM 
        website_sessions ws
    LEFT JOIN 
        website_pageviews wp
        ON ws.website_session_id = wp.website_session_id

    WHERE 
        ws.utm_source = 'gsearch'                -- Paid search traffic
        AND ws.utm_campaign = 'nonbrand'         -- Nonbrand campaign
        AND ws.created_at > '2012-08-05'         -- Only sessions after Aug 5
        AND ws.created_at < '2012-09-05'         -- Only sessions before Sep 5

    ORDER BY
        ws.website_session_id,
        wp.created_at                             -- Pageview chronological order
) AS pageview_level
GROUP BY
    website_session_id;                           -- Session-level aggregation

-- STEP 3: Aggregate the session-level funnel data
-- Ye query har funnel step ke liye unique sessions count karegi
-- Taaki hum dekh saken kitne visitors har step tak pohche aur drop-off rate calculate kar saken

SELECT
    COUNT(DISTINCT website_session_id) AS sessions,  
        -- Total sessions (all sessions from gsearch nonbrand)

    COUNT(DISTINCT CASE WHEN product_made_it = 1 THEN website_session_id ELSE NULL END) AS to_products,  
        -- Sessions that reached Product listing page

    COUNT(DISTINCT CASE WHEN mrfuzzy_made_it = 1 THEN website_session_id ELSE NULL END) AS to_mrfuzzy,  
        -- Sessions that reached specific product page

    COUNT(DISTINCT CASE WHEN cart_made_it = 1 THEN website_session_id ELSE NULL END) AS to_cart,  
        -- Sessions that reached Cart page

    COUNT(DISTINCT CASE WHEN shipping_made_it = 1 THEN website_session_id ELSE NULL END) AS to_shipping,  
        -- Sessions that reached Shipping page

    COUNT(DISTINCT CASE WHEN billing_made_it = 1 THEN website_session_id ELSE NULL END) AS to_billing,  
        -- Sessions that reached Billing page

    COUNT(DISTINCT CASE WHEN thankyou_made_it = 1 THEN website_session_id ELSE NULL END) AS to_thankyou  
        -- Sessions that reached Thank You page (Order Completed)

FROM 
    session_level_made_it_flags;  
    -- Ye table Step 2 se aayi hai jisme har session ke furthest steps flagged hain
    
-- STEP 4: Calculate funnel step-to-step conversion rates (final step)
-- Ye query har funnel step ke liye conversion % nikalti hai
-- Taaki pata chale kitne users previous step se next step tak pohche

SELECT
    -- Landing Page → Product Listing conversion
    COUNT(DISTINCT CASE WHEN product_made_it = 1 THEN website_session_id ELSE NULL END) 
        / COUNT(DISTINCT website_session_id) AS lander_click_rt,
    
    -- Product Listing → Specific Product Page conversion
    COUNT(DISTINCT CASE WHEN mrfuzzy_made_it = 1 THEN website_session_id ELSE NULL END)
        / COUNT(DISTINCT CASE WHEN product_made_it = 1 THEN website_session_id ELSE NULL END) AS products_to_mrfuzzy,
    
    -- Specific Product → Cart conversion
    COUNT(DISTINCT CASE WHEN cart_made_it = 1 THEN website_session_id ELSE NULL END)
        / COUNT(DISTINCT CASE WHEN mrfuzzy_made_it = 1 THEN website_session_id ELSE NULL END) AS mrfuzzy_to_cart,
    
    -- Cart → Shipping conversion
    COUNT(DISTINCT CASE WHEN shipping_made_it = 1 THEN website_session_id ELSE NULL END)
        / COUNT(DISTINCT CASE WHEN cart_made_it = 1 THEN website_session_id ELSE NULL END) AS cart_to_shipping,
    
    -- Shipping → Billing conversion
    COUNT(DISTINCT CASE WHEN billing_made_it = 1 THEN website_session_id ELSE NULL END)
        / COUNT(DISTINCT CASE WHEN shipping_made_it = 1 THEN website_session_id ELSE NULL END) AS shipping_to_billing,
    
    -- Billing → Thank You (Order Complete) conversion
    COUNT(DISTINCT CASE WHEN thankyou_made_it = 1 THEN website_session_id ELSE NULL END)
        / COUNT(DISTINCT CASE WHEN billing_made_it = 1 THEN website_session_id ELSE NULL END) AS billing_to_thankyou

FROM 
    session_level_made_it_flags;  
    -- Step 2 ka session-level table, har session ka furthest step flagged

-- 5 landing page analysis

/* 
Step 1: Find the first pageview_id for /billing-2 
-----------------------------------------------
Why?  
We need to know the point in time when the new billing page (/billing-2) 
first went live. After this ID, we will only look at sessions to make a 
fair comparison between /billing (old) and /billing-2 (new). 
*/

SELECT
    MIN(website_pageviews.website_pageview_id) AS first_pv_id  -- Smallest pageview_id = first time /billing-2 was seen
FROM website_pageviews
WHERE pageview_url = '/billing-2';   -- Only look at the new billing page


/* 
Step 2: Pull sessions that saw a billing page (old or new)
----------------------------------------------------------
Why?  
Now that we know the test went live at pageview_id 53550, we want to 
compare how many sessions saw /billing (old) vs /billing-2 (new), 
and whether those sessions placed an order.

This gives us session-level data showing:
- session_id
- which billing version they saw
- whether that session converted (order_id present or NULL)
*/

SELECT
    website_pageviews.website_session_id,         -- each unique session
    website_pageviews.pageview_url AS billing_version_seen, -- which billing page (/billing or /billing-2)
    orders.order_id                               -- order_id (NULL if no order placed)
FROM website_pageviews
LEFT JOIN orders
    ON orders.website_session_id = website_pageviews.website_session_id
WHERE website_pageviews.website_pageview_id >= 53550   -- only sessions after test went live
  AND website_pageviews.created_at < '2012-11-10'      -- limit to assignment date
  AND website_pageviews.pageview_url IN ('/billing','/billing-2'); -- only look at billing pages

-- step 3 final output
SELECT
    billing_version_seen,                                           -- kaunsa billing page dekha (/billing ya /billing-2)
    COUNT(DISTINCT website_session_id) AS sessions,                 -- total unique sessions jo us billing page par gaye
    COUNT(DISTINCT order_id) AS orders,                             -- total unique orders jo us page ke sessions ne kiye
    COUNT(DISTINCT order_id) * 1.0 / COUNT(DISTINCT website_session_id) AS billing_to_order_rt
                                                                    -- conversion rate: (orders / sessions)
FROM (
        -- Subquery: yeh sirf billing sessions aur unke orders laata hai
        SELECT
            website_pageviews.website_session_id,                   -- session id (har visitor ka session)
            website_pageviews.pageview_url AS billing_version_seen, -- kaunsa billing page visit kiya (/billing ya /billing-2)
            orders.order_id                                         -- agar order hua toh order_id, warna NULL
        FROM website_pageviews
        LEFT JOIN orders
            ON orders.website_session_id = website_pageviews.website_session_id
        WHERE website_pageviews.website_pageview_id >= 53550        -- sirf wohi sessions count karo jab se test live hua
          AND website_pageviews.created_at < '2012-11-10'           -- sirf assignment ke cutoff date tak ka data lo
          AND website_pageviews.pageview_url IN ('/billing','/billing-2') 
                                                                    -- sirf billing aur billing-2 pages chahiye
     ) AS billing_sessions_w_orders
GROUP BY
    billing_version_seen;                                           -- dono billing versions ka result alag alag dikhega




