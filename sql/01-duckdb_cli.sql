-- Commands to be pasted in the DuckDB CLI
-- Here with a CSV file, but can also be used with the JSONL and XLSX files!

-- Schema
-- Any format becomes tabular.
DESCRIBE FROM './data/breizhcamp.csv';
DESCRIBE FROM './data/breizhcamp.xlsx';
DESCRIBE FROM './data/breizhcamp.jsonl';

-- Get the 10 last videos talking about "tests"
SELECT "date", title
FROM './data/breizhcamp.csv'
WHERE 'test' IN title
ORDER BY date DESC
LIMIT 10;

-- Let's do some analytics on BreizhCamp YouTube channel videos.

-- Average duration of videos (in minutes)
SELECT to_seconds(avg(duration)) as duration FROM './data/breizhcamp.csv';

-- Quantiles of duration
SELECT
    to_seconds(quantile(duration, 0.01)) AS Q1,
    to_seconds(quantile(duration, 0.05)) AS Q5,
    to_seconds(quantile(duration, 0.25)) AS Q25,
    to_seconds(quantile(duration, 0.5)) AS Q50,
    to_seconds(quantile(duration, 0.75)) AS Q75,
    to_seconds(quantile(duration, 0.95)) AS Q95,
    to_seconds(quantile(duration, 0.99)) AS Q99,
FROM './data/breizhcamp.csv';

-- Distribution of duration (by buckets of 10 minutes)
-- Note: the last bucket contains the values outside the boundaries
SET VARIABLE duration_min = (select min(duration) from './data/breizhcamp.csv');
SET VARIABLE duration_max = (select max(duration) from './data/breizhcamp.csv');
SELECT
    histogram(duration, range($duration_min, $duration_max, 10 * 60)) AS hist
FROM './data/breizhcamp.csv';

-- Quantiles of views
SELECT
    quantile(views, 0.01) AS Q1,
    quantile(views, 0.05) AS Q5,
    quantile(views, 0.25) AS Q25,
    quantile(views, 0.5) AS Q50,
    quantile(views, 0.75) AS Q75,
    quantile(views, 0.95) AS Q95,
    quantile(views, 0.99) AS Q99,
FROM './data/breizhcamp.csv';

-- Views related to the duration (by segments of 10 minutes)
SELECT
    [
        to_seconds(bucket * (10 * 60)),
        to_seconds((bucket + 1) * (10 * 60))
    ] AS from_to,
    views
FROM (
    SELECT (duration / (10 * 60))::INTEGER AS bucket,
    avg(views)::INTEGER AS views
    FROM './data/breizhcamp.csv'
    WHERE bucket IS NOT NULL
    GROUP BY ALL
) ORDER BY views DESC;
