CREATE SCHEMA IF NOT EXISTS core;

/* TASK 1 
 Current quarter/year are determined from CURRENT_DATE in the database session.
 Date window prevents overlap and uses indexes on payment.payment_date where available. 
 A category appears only if it has a payment in the current quarter: the inner
 joins and GROUP BY naturally exclude categories with zero current-quarter sales.
 A film may have more than one category in a customized dataset; then the same
 payment contributes to each category. Standard dvdrental normally has one.
 No hard-coded dates or IDs. On current-quarter dates with no payments the view
 returns zero rows.
 */
 
CREATE OR REPLACE VIEW core.sales_revenue_by_category_qtr AS
SELECT c.category_id,
       c.name AS category_name,
       EXTRACT(YEAR FROM CURRENT_DATE)::integer AS sales_year,
       EXTRACT(QUARTER FROM CURRENT_DATE)::integer AS sales_quarter,
       SUM(p.amount)::numeric(12,2) AS total_sales_revenue
FROM public.payment AS p
JOIN public.rental AS r ON r.rental_id = p.rental_id
JOIN public.inventory AS i ON i.inventory_id = r.inventory_id
JOIN public.film AS f ON f.film_id = i.film_id
JOIN public.film_category AS fc ON fc.film_id = f.film_id
JOIN public.category AS c ON c.category_id = fc.category_id
WHERE p.payment_date >= date_trunc('quarter', CURRENT_DATE::timestamp)
  AND p.payment_date < date_trunc('quarter', CURRENT_DATE::timestamp) + INTERVAL '3 months'
GROUP BY c.category_id, c.name;

/* TASK 1  */

SELECT * FROM core.sales_revenue_by_category_qtr ORDER BY total_sales_revenue DESC;
SELECT c.category_id, c.name
FROM public.category c
WHERE NOT EXISTS (
  SELECT 1 FROM core.sales_revenue_by_category_qtr v
  WHERE v.category_id = c.category_id
)
ORDER BY c.name; -- These are examples of categories NOT present in the view.
SELECT * FROM core.sales_revenue_by_category_qtr
WHERE total_sales_revenue <= 0; 

SELECT * FROM core.sales_revenue_by_category_qtr
WHERE sales_year <> EXTRACT(YEAR FROM CURRENT_DATE)::integer
   OR sales_quarter <> EXTRACT(QUARTER FROM CURRENT_DATE)::integer;

-- There are no input parameters. Missing payments/categories give no rows;
-- missing referenced tables cause an SQL error at view creation/execution.

/* TASK 2 — SQL-language function, one DATE parameter represents BOTH the
 year and quarter (e.g. DATE '2026-04-01' represents Q2 2026).
 A DATE is preferable to ambiguous strings such as 'Q2-26'. It must be the
 first day of a quarter; incorrect inputs and NULL return an empty result set. If there are no payments,
 the function returns an empty set (not an exception).
 The view from Task 1 is dynamic and only represents TODAY's quarter. A
 historical/future quarter cannot be fetched from that view; the function
 therefore uses the SAME join/aggregation logic with its supplied quarter.
 */
 
CREATE OR REPLACE FUNCTION core.get_sales_revenue_by_category_qtr(p_quarter_start date)
RETURNS TABLE (category_id integer, category_name text,
               sales_year integer, sales_quarter integer,
               total_sales_revenue numeric)
LANGUAGE sql STABLE AS $function$
  SELECT c.category_id,
         c.name::text,
         EXTRACT(YEAR FROM p_quarter_start)::integer,
         EXTRACT(QUARTER FROM p_quarter_start)::integer,
         SUM(p.amount)::numeric
  FROM public.payment p
  JOIN public.rental r ON r.rental_id = p.rental_id
  JOIN public.inventory i ON i.inventory_id = r.inventory_id
  JOIN public.film f ON f.film_id = i.film_id
  JOIN public.film_category fc ON fc.film_id = f.film_id
  JOIN public.category c ON c.category_id = fc.category_id
  WHERE p_quarter_start IS NOT NULL
    AND p_quarter_start = date_trunc('quarter', p_quarter_start::timestamp)::date
    AND p.payment_date >= p_quarter_start::timestamp
    AND p.payment_date < (p_quarter_start::timestamp + INTERVAL '3 months')
  GROUP BY c.category_id, c.name
$function$;

/* A SQL-language function cannot directly use PL/pgSQL RAISE EXCEPTION.
 Invalid (non-quarter-start) dates and NULL are intentionally handled by
 returning zero rows; missing payment data likewise yields zero rows.
 The parameter is optional in the sense that the caller may pass NULL,
 but no default is supplied: an omitted argument is a PostgreSQL call error.
 The SQL function is STABLE and read-only. */
 
SELECT * FROM core.get_sales_revenue_by_category_qtr(
  date_trunc('quarter', CURRENT_DATE::timestamp)::date
) ORDER BY total_sales_revenue DESC; -- Valid/current quarter
SELECT * FROM core.get_sales_revenue_by_category_qtr(DATE '2005-01-01'); -- Valid historical quarter; 
SELECT * FROM core.get_sales_revenue_by_category_qtr(DATE '2026-02-01'); 
SELECT * FROM core.get_sales_revenue_by_category_qtr(NULL::date); 

(SELECT * FROM core.sales_revenue_by_category_qtr
 EXCEPT SELECT * FROM core.get_sales_revenue_by_category_qtr(
   date_trunc('quarter', CURRENT_DATE)::date))
UNION ALL
(SELECT * FROM core.get_sales_revenue_by_category_qtr(
   date_trunc('quarter', CURRENT_DATE)::date)
 EXCEPT SELECT * FROM core.sales_revenue_by_category_qtr);

/* TASK 3 — Most popular film for EACH requested country, measured by rental
 COUNT (not revenue). One output row per input country, including countries
 with no rentals or missing from public.country; in those cases film metadata
 is NULL. Ties resolved by highest rental count, then lowest film_id.
 Duplicated input country names produce duplicated output rows intentionally.
 Country is the customer's country, via customer -> address -> city -> country.
 */
CREATE OR REPLACE FUNCTION core.most_popular_films_by_countries(p_countries text[])
RETURNS TABLE (country text, film text, rating text, language text,
               length integer, release_year integer)
LANGUAGE plpgsql STABLE AS $function$
BEGIN
  IF p_countries IS NULL OR cardinality(p_countries) = 0 THEN
    RAISE EXCEPTION 'Provide at least one country in p_countries'
      USING ERRCODE = '22023';
  END IF;
  IF EXISTS (SELECT 1 FROM unnest(p_countries) AS x(name)
             WHERE x.name IS NULL OR btrim(x.name) = '') THEN
    RAISE EXCEPTION 'Country names cannot be NULL or blank' USING ERRCODE = '22023';
  END IF;
  RETURN QUERY
  WITH requested AS (
    SELECT u.country_name, u.ordinality
    FROM unnest(p_countries) WITH ORDINALITY AS u(country_name, ordinality)
  ), ranked AS (
    SELECT co.country_id, f.film_id, f.title,
           f.rating::text AS film_rating, l.name AS language_name,
           f.length::integer AS film_length,
           f.release_year::integer AS film_release_year,
           COUNT(*) AS rental_count,
           ROW_NUMBER() OVER (
             PARTITION BY co.country_id ORDER BY COUNT(*) DESC, f.film_id
           ) AS rank_no
    FROM public.country co
    JOIN public.city ci ON ci.country_id = co.country_id
    JOIN public.address a ON a.city_id = ci.city_id
    JOIN public.customer cu ON cu.address_id = a.address_id
    JOIN public.rental r ON r.customer_id = cu.customer_id
    JOIN public.inventory i ON i.inventory_id = r.inventory_id
    JOIN public.film f ON f.film_id = i.film_id
    JOIN public.language l ON l.language_id = f.language_id
    GROUP BY co.country_id, f.film_id, f.title, f.rating,
             l.name, f.length, f.release_year
  )
  SELECT req.country_name, ranked.title::text, ranked.film_rating,
         ranked.language_name::text, ranked.film_length, ranked.film_release_year
  FROM requested req
  LEFT JOIN public.country co ON co.country = req.country_name
  LEFT JOIN ranked ON ranked.country_id = co.country_id AND ranked.rank_no = 1
  ORDER BY req.ordinality;
END;
$function$;


SELECT * FROM core.most_popular_films_by_countries(ARRAY['Afghanistan','Brazil','United States']);
SELECT * FROM core.most_popular_films_by_countries(ARRAY['Nonexistent Country']);
-- Edge case: no country match -> one row with NULL film fields.
-- Invalid input -> SQLSTATE 22023; missing rentals -> country with NULL film.
-- If a country has tied films, smallest film_id wins deterministically.

DO $test$ BEGIN
  BEGIN
    PERFORM * FROM core.most_popular_films_by_countries(NULL::text[]);
    RAISE EXCEPTION 'Expected validation error was not raised';
  EXCEPTION WHEN SQLSTATE '22023' THEN
    RAISE NOTICE 'PASS: NULL array rejected';
  END;
END $test$;

/* TASK 4 — Rental rows for films IN STOCK, with partial title match.
 'In stock' is evaluated at rental level: an inventory item is available if
 it has no rental without return_date. For each matching film with at least one
 available inventory copy, return its historical rental rows (if any).
 LIKE is case-sensitive; % means any sequence of characters. Escape a literal
 percent or underscore in the supplied pattern when needed. Only matching
 films are processed before joining rentals; the unanchored pattern '%love%'
 can require scanning film titles, but filtering first avoids scanning all
 rental rows. Row numbers begin at 1 and are deterministic (as required).
 If a title matches but no copy is in stock, return one explanatory row.
 If no title matches, return one explanatory row. Multiple matches are listed.
 */
CREATE OR REPLACE FUNCTION core.films_in_stock_by_title(p_pattern text)
RETURNS TABLE (row_num bigint, film_title text, language text,
               customer_name text, rental_date timestamp)
LANGUAGE plpgsql STABLE AS $function$
DECLARE v_titles integer;
BEGIN
  IF p_pattern IS NULL OR btrim(p_pattern) = '' THEN
    RAISE EXCEPTION 'Title pattern cannot be NULL or blank' USING ERRCODE = '22023';
  END IF;
  SELECT COUNT(*) INTO v_titles FROM public.film f WHERE f.title LIKE p_pattern;
  IF v_titles = 0 THEN
    RETURN QUERY SELECT NULL::bigint, 'No film title matches the pattern'::text,
                        NULL::text, NULL::text, NULL::timestamp;
    RETURN;
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM public.film f
    JOIN public.inventory i ON i.film_id = f.film_id
    WHERE f.title LIKE p_pattern
      AND NOT EXISTS (SELECT 1 FROM public.rental active_r
                      WHERE active_r.inventory_id = i.inventory_id
                        AND active_r.return_date IS NULL)
  ) THEN
    RETURN QUERY SELECT NULL::bigint, 'Matching film(s) are not in stock'::text,
                        NULL::text, NULL::text, NULL::timestamp;
    RETURN;
  END IF;
  RETURN QUERY
  WITH available_films AS (
    SELECT DISTINCT f.film_id, f.title, l.name AS language_name
    FROM public.film f
    JOIN public.language l ON l.language_id = f.language_id
    JOIN public.inventory i ON i.film_id = f.film_id
    WHERE f.title LIKE p_pattern
      AND NOT EXISTS (SELECT 1 FROM public.rental active_r
                      WHERE active_r.inventory_id = i.inventory_id
                        AND active_r.return_date IS NULL)
  )
  SELECT ROW_NUMBER() OVER (ORDER BY af.title, r.rental_date, r.rental_id),
         af.title::text, af.language_name::text,
         (cu.first_name || ' ' || cu.last_name)::text,
         r.rental_date::timestamp
  FROM available_films af
  LEFT JOIN public.inventory i ON i.film_id = af.film_id
  LEFT JOIN public.rental r ON r.inventory_id = i.inventory_id
  LEFT JOIN public.customer cu ON cu.customer_id = r.customer_id
  ORDER BY af.title, r.rental_date NULLS LAST, r.rental_id;
END;
$function$;
SELECT * FROM core.films_in_stock_by_title('%LOVE%'); -- Valid/multiple matches
SELECT * FROM core.films_in_stock_by_title('%ZZZ_NOT_A_FILM%'); -- No matches

DO $test$ BEGIN
  BEGIN
    PERFORM * FROM core.films_in_stock_by_title(NULL::text);
    RAISE EXCEPTION 'Expected NULL-pattern validation was not raised';
  EXCEPTION WHEN SQLSTATE '22023' THEN
    RAISE NOTICE 'PASS: NULL title pattern rejected';
  END;
END $test$;


/* TASK 5 — Add film with safe ID generation (film_id IDENTITY/SERIAL default).
 Validate language before insert. Default language is Klingon, which is NOT
 normally present in standard dvdrental: with no Klingon row this must raise
 an exception, as required by the task. No duplicate titles (case-insensitive) are allowed through this function.
 An advisory transaction lock serializes competing calls to this function.
 External INSERTs bypass the function and may require a separate UNIQUE index.
 Existing title conflicts raise an exception.
 PostgreSQL functions execute in their caller's transaction: any exception
 rolls back the INSERT, preserving consistency. Optional parameters supported.
 */

SELECT lower(title), COUNT(*) FROM public.film
GROUP BY lower(title) HAVING COUNT(*) > 1;
-- No persistent schema change to public.film is needed: function performs
-- duplicate check and uses an advisory transaction lock to serialize inserts
-- through THIS function. External direct inserts can still bypass this guard.
-- Do not add a UNIQUE index unless the assignment/database owner authorizes it.

CREATE OR REPLACE FUNCTION core.new_movie(
  p_title text,
  p_rental_rate numeric DEFAULT 4.99,
  p_rental_duration integer DEFAULT 3,
  p_language_name text DEFAULT 'Klingon'
)
RETURNS integer LANGUAGE plpgsql VOLATILE AS $function$
DECLARE v_language_id integer; v_film_id integer;
BEGIN
  IF p_title IS NULL OR btrim(p_title) = '' THEN
    RAISE EXCEPTION 'Film title is required' USING ERRCODE = '22023';
  END IF;
  IF p_rental_rate IS NULL OR p_rental_rate < 0 THEN
    RAISE EXCEPTION 'Rental rate must be nonnegative' USING ERRCODE = '22023';
  END IF;
  IF p_rental_duration IS NULL OR p_rental_duration <= 0 THEN
    RAISE EXCEPTION 'Rental duration must be positive' USING ERRCODE = '22023';
  END IF;
  IF p_language_name IS NULL OR btrim(p_language_name) = '' THEN
    RAISE EXCEPTION 'Language is required' USING ERRCODE = '22023';
  END IF;
  SELECT l.language_id INTO v_language_id
  FROM public.language l
  WHERE lower(btrim(l.name::text)) = lower(btrim(p_language_name))
  ORDER BY l.language_id LIMIT 1;
  IF v_language_id IS NULL THEN
    RAISE EXCEPTION 'Language "%" does not exist in language table', p_language_name
      USING ERRCODE = '22023';
  END IF;

  PERFORM pg_advisory_xact_lock(hashtext('core.new_movie.title'),
                               hashtext(lower(btrim(p_title))));
  IF EXISTS (SELECT 1 FROM public.film f WHERE lower(f.title) = lower(btrim(p_title))) THEN
    RAISE EXCEPTION 'Film "%" already exists', p_title USING ERRCODE = '23505';
  END IF;
  INSERT INTO public.film (title, rental_rate, rental_duration,
                           language_id, release_year)
  VALUES (btrim(p_title), p_rental_rate, p_rental_duration,
          v_language_id, EXTRACT(YEAR FROM CURRENT_DATE)::integer)
  RETURNING film_id INTO v_film_id;
  RETURN v_film_id;
EXCEPTION
  WHEN unique_violation THEN
    RAISE EXCEPTION 'Film "%" already exists (unique title)', p_title
      USING ERRCODE = '23505';
END;
$function$;

/* TASK 5 TESTS. There is deliberately NO top-level BEGIN/ROLLBACK.
   The nested PL/pgSQL exception block is a subtransaction: the successful
   test INSERT is undone by the deliberate exception caught outside it.
   All created views/functions therefore remain installed after execution.
   PASS notices confirm the validations; test film must not remain.
*/
DO $tests$
DECLARE
    v_id integer;
    v_test_title text := 'EPAM_TEMP_TEST_FILM_2026';
BEGIN
    IF EXISTS (SELECT 1 FROM public.film WHERE title = v_test_title) THEN
        RAISE EXCEPTION 'Test title already exists: %. Choose another temporary title.', v_test_title;
    END IF;

    BEGIN
 
        v_id := core.new_movie(v_test_title, 4.99, 3, 'English');
        IF v_id IS NULL OR NOT EXISTS (
            SELECT 1 FROM public.film WHERE film_id = v_id AND title = v_test_title
        ) THEN
            RAISE EXCEPTION 'New movie insert verification failed';
        END IF;
        RAISE NOTICE 'PASS: valid movie inserted and verified (will be undone)';

        BEGIN
            PERFORM core.new_movie(v_test_title, 4.99, 3, 'English');
            RAISE EXCEPTION 'FAIL: duplicate movie was accepted';
        EXCEPTION WHEN unique_violation THEN
            RAISE NOTICE 'PASS: duplicate rejected';
        END;

        BEGIN
            PERFORM core.new_movie(NULL::text, 4.99, 3, 'English');
            RAISE EXCEPTION 'FAIL: NULL title was accepted';
        EXCEPTION WHEN SQLSTATE '22023' THEN
            RAISE NOTICE 'PASS: NULL title rejected';
        END;

        BEGIN
            PERFORM core.new_movie('EPAM_TEMP_TEST_BAD_LANGUAGE', 4.99, 3, 'NotARealLanguage');
            RAISE EXCEPTION 'FAIL: invalid language was accepted';
        EXCEPTION WHEN SQLSTATE '22023' THEN
            RAISE NOTICE 'PASS: invalid language rejected';
        END;


        RAISE EXCEPTION 'End of safe test; undo test inserts' USING ERRCODE = 'P9001';
    EXCEPTION WHEN SQLSTATE 'P9001' THEN
        RAISE NOTICE 'PASS: temporary test insert rolled back; objects remain installed';
    END;

    IF EXISTS (SELECT 1 FROM public.film WHERE title = v_test_title) THEN
        RAISE EXCEPTION 'FAIL: temporary test movie still exists';
    END IF;
    RAISE NOTICE 'PASS: no temporary movie remains';
END;
$tests$;

SELECT 'VIEW' AS object_type, schemaname AS schema_name, viewname AS object_name
FROM pg_views
WHERE schemaname = 'core' AND viewname = 'sales_revenue_by_category_qtr'
UNION ALL
SELECT 'FUNCTION', n.nspname, p.proname
FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname = 'core'
  AND p.proname IN (
    'get_sales_revenue_by_category_qtr',
    'most_popular_films_by_countries',
    'films_in_stock_by_title',
    'new_movie'
  )
ORDER BY object_type, object_name;
