-- Task 1

-- Points 1, 2

-- Movies:
-- The Prestige (2006) - Drama
-- The Matrix (1999) - Science Fiction
-- Se7en (1995) - Thriller
--
-- Rental rates: 4.99, 9.99, 19.99
-- Rental durations: 7, 14, 21 days

/* A separate transaction is used to insert the three films
together without mixing this step with later operations.
If an error occurs, the transaction can be rolled back.
ROLLBACK would undo all film inserts in this transaction,
provided they have not been committed yet.
Referential integrity is preserved by selecting an existing
language_id from public.language instead of hardcoding it.
NOT EXISTS checks the title and release year to avoid
inserting the same movies again when rerunning the script. */

BEGIN;

WITH inserted_films AS (
    INSERT INTO public.film (
        title,
        release_year,
        language_id,
        rental_duration,
        rental_rate,
        length,
        replacement_cost,
        rating,
        last_update
    )
    SELECT
        m.title,
        m.release_year,
        l.language_id,
        m.rental_duration,
        m.rental_rate,
        m.length,
        19.99,
        m.rating::public.mpaa_rating,
        CURRENT_DATE
    FROM (
        SELECT 'The Prestige' AS title,
               2006 AS release_year,
               7 AS rental_duration,
               4.99 AS rental_rate,
               130 AS length,
               'PG-13' AS rating
        UNION ALL
        SELECT 'The Matrix', 1999, 14, 9.99, 136, 'R'
        UNION ALL
        SELECT 'Se7en', 1995, 21, 19.99, 127, 'R'
    ) AS m
    CROSS JOIN public.language AS l
    WHERE LOWER(l.name) = 'english'
      AND NOT EXISTS (
          SELECT 1
          FROM public.film AS f
          WHERE LOWER(f.title) = LOWER(m.title)
            AND f.release_year = m.release_year
      )
    RETURNING
        film_id,
        title,
        release_year,
        rental_duration,
        rental_rate
)
SELECT *
FROM inserted_films;

COMMIT;

-- Checking the inserted films.
SELECT
    film_id,
    title,
    release_year,
    rental_duration,
    rental_rate,
    last_update
FROM public.film
WHERE LOWER(title) IN (
    'the prestige',
    'the matrix',
    'se7en'
)
ORDER BY release_year;


SELECT
    actor_id,
    first_name,
    last_name
FROM public.actor
WHERE (LOWER(first_name), LOWER(last_name)) IN (
    ('hugh', 'jackman'),
    ('christian', 'bale'),
    ('michael', 'caine'),
    ('keanu', 'reeves'),
    ('laurence', 'fishburne'),
    ('carrie-anne', 'moss'),
    ('brad', 'pitt'),
    ('morgan', 'freeman'),
    ('kevin', 'spacey')
)
ORDER BY last_name, first_name;


----------------------------------------------------------------------------------------------------------

-- Point 3

-- I selected three leading actors for each movie:
-- The Prestige: Hugh Jackman, Christian Bale, Michael Caine
-- The Matrix: Keanu Reeves, Laurence Fishburne, Carrie-Anne Moss
-- Se7en: Brad Pitt, Morgan Freeman, Kevin Spacey

-- A separate transaction is used because adding actors and connecting them to films is one related operation.
-- If the transaction fails, PostgreSQL will not commit any changes from this transaction.
-- ROLLBACK is possible before COMMIT and would undo both the new actors and their film_actor relationships.
-- Referential integrity is preserved by selecting actor_id and film_id from existing records instead of hardcoding IDs.
-- NOT EXISTS prevents duplicate actors and actor-film pairs when the script is executed again.

BEGIN;

WITH new_actors (first_name, last_name) AS (
    SELECT 'Hugh', 'Jackman'
    UNION ALL SELECT 'Christian', 'Bale'
    UNION ALL SELECT 'Michael', 'Caine'
    UNION ALL SELECT 'Keanu', 'Reeves'
    UNION ALL SELECT 'Laurence', 'Fishburne'
    UNION ALL SELECT 'Carrie-Anne', 'Moss'
    UNION ALL SELECT 'Brad', 'Pitt'
    UNION ALL SELECT 'Morgan', 'Freeman'
    UNION ALL SELECT 'Kevin', 'Spacey'
)
INSERT INTO public.actor (
    first_name,
    last_name,
    last_update
)
SELECT
    na.first_name,
    na.last_name,
    CURRENT_DATE
FROM new_actors AS na
WHERE NOT EXISTS (
    SELECT 1
    FROM public.actor AS a
    WHERE LOWER(a.first_name) = LOWER(na.first_name)
      AND LOWER(a.last_name) = LOWER(na.last_name)
)
RETURNING actor_id, first_name, last_name;

-- Connectinh actors to their movies.
WITH movie_actors (title, release_year, first_name, last_name) AS (
    SELECT 'The Prestige', 2006, 'Hugh', 'Jackman'
    UNION ALL SELECT 'The Prestige', 2006, 'Christian', 'Bale'
    UNION ALL SELECT 'The Prestige', 2006, 'Michael', 'Caine'
    UNION ALL SELECT 'The Matrix', 1999, 'Keanu', 'Reeves'
    UNION ALL SELECT 'The Matrix', 1999, 'Laurence', 'Fishburne'
    UNION ALL SELECT 'The Matrix', 1999, 'Carrie-Anne', 'Moss'
    UNION ALL SELECT 'Se7en', 1995, 'Brad', 'Pitt'
    UNION ALL SELECT 'Se7en', 1995, 'Morgan', 'Freeman'
    UNION ALL SELECT 'Se7en', 1995, 'Kevin', 'Spacey'
)
INSERT INTO public.film_actor (
    actor_id,
    film_id,
    last_update
)
SELECT
    a.actor_id,
    f.film_id,
    CURRENT_DATE
FROM movie_actors AS ma
JOIN public.actor AS a ON LOWER(a.first_name) = LOWER(ma.first_name)
   AND LOWER(a.last_name) = LOWER(ma.last_name)
JOIN public.film AS f ON LOWER(f.title) = LOWER(ma.title)
   AND f.release_year = ma.release_year
WHERE NOT EXISTS (
    SELECT 1
    FROM public.film_actor AS fa
    WHERE fa.actor_id = a.actor_id AND fa.film_id = f.film_id
)
RETURNING actor_id, film_id;

COMMIT;


SELECT
    f.title AS movie,
    a.first_name,
    a.last_name
FROM public.film_actor AS fa
JOIN public.film AS f
    ON fa.film_id = f.film_id
JOIN public.actor AS a
    ON fa.actor_id = a.actor_id
WHERE LOWER(f.title) IN (
    'the prestige',
    'the matrix',
    'se7en'
)
ORDER BY f.title, a.last_name;


-------------------------------------------------------------------------------
-- Point 4 

SELECT
    s.store_id,
    COUNT(i.inventory_id) AS inventory_count
FROM public.store AS s
LEFT JOIN public.inventory AS i
    ON s.store_id = i.store_id
GROUP BY s.store_id
ORDER BY s.store_id;

-- I chose Store 1 to add one copy of each favorite movie.
--
-- A separate transaction is used because adding inventory is a separate step from inserting movies and actors.
-- If the transaction fails, the changes will not be committed.
-- ROLLBACK before COMMIT would undo the inventory records inserted in this transaction.
-- Referential integrity is preserved by selecting film_id and store_id from existing film and store records.
-- NOT EXISTS prevents inserting another copy of the same movie into the selected store when rerunning the script.

BEGIN;

INSERT INTO public.inventory (
    film_id,
    store_id,
    last_update
)
SELECT
    f.film_id,
    s.store_id,
    CURRENT_DATE
FROM public.film AS f
CROSS JOIN public.store AS s
WHERE s.store_id = (
    SELECT MIN(store_id)
    FROM public.store
)
AND LOWER(f.title) IN (
    'the prestige',
    'the matrix',
    'se7en'
)
AND NOT EXISTS (
    SELECT 1
    FROM public.inventory AS i
    WHERE i.film_id = f.film_id
      AND i.store_id = s.store_id
)
RETURNING inventory_id, film_id, store_id;

COMMIT;

-- Verifyinh that all three movies are available in Store 1.
SELECT
    i.inventory_id,
    f.title AS movie,
    i.store_id,
    i.last_update
FROM public.inventory AS i
JOIN public.film AS f
    ON i.film_id = f.film_id
WHERE LOWER(f.title) IN (
    'the prestige',
    'the matrix',
    'se7en'
)
ORDER BY f.title;



----------------------------------------------------------------------------------

-- Point 5


-- Finding customers with at least 43 rentals and 43 payments.

SELECT
    c.customer_id,
    c.first_name,
    c.last_name,
    r.rental_count,
    p.payment_count
FROM public.customer AS c
JOIN (
    SELECT customer_id, COUNT(*) AS rental_count
    FROM public.rental
    GROUP BY customer_id
) AS r
    ON c.customer_id = r.customer_id
JOIN (
    SELECT customer_id, COUNT(*) AS payment_count
    FROM public.payment
    GROUP BY customer_id
) AS p
    ON c.customer_id = p.customer_id
WHERE r.rental_count >= 43
  AND p.payment_count >= 43
ORDER BY r.rental_count DESC, p.payment_count DESC
LIMIT 10;

-- I selected Eleanor Hunt because she has at least 43 rentals and 43 payments. I will change her personal information
-- to mine without changing the address table.
--
-- A separate transaction is used to keep the customer update independent from the other subtasks.
-- If the transaction fails, PostgreSQL will not commit the changes made within this transaction.
-- ROLLBACK before COMMIT would restore the customer's previous information.
-- Referential integrity is preserved by using an existing address_id from public.address.
-- The UPDATE targets one customer and does not insert records, so it cannot create duplicate customers. The WHERE conditions
-- also make the operation safe to rerun.

-- Checking the customer before making changes.
SELECT
    c.customer_id,
    c.first_name,
    c.last_name,
    c.email,
    c.address_id,
    COUNT(DISTINCT r.rental_id) AS rental_count,
    COUNT(DISTINCT p.payment_id) AS payment_count
FROM public.customer AS c
LEFT JOIN public.rental AS r ON c.customer_id = r.customer_id
LEFT JOIN public.payment AS p ON c.customer_id = p.customer_id
WHERE LOWER(c.first_name) = 'eleanor' AND LOWER(c.last_name) = 'hunt'
GROUP BY c.customer_id;

BEGIN;

UPDATE public.customer AS c
SET
    first_name = 'Nane',
    last_name = 'Narimanyan',
    email = 'nane.narimanyan@example.com',
    address_id = (
        SELECT MIN(address_id)
        FROM public.address
    ),
    last_update = CURRENT_DATE
WHERE (
    (LOWER(c.first_name) = 'eleanor'
     AND LOWER(c.last_name) = 'hunt'
     AND (SELECT COUNT(*)
          FROM public.rental AS r
          WHERE r.customer_id = c.customer_id) >= 43
     AND (SELECT COUNT(*)
          FROM public.payment AS p
          WHERE p.customer_id = c.customer_id) >= 43)
    OR
    (LOWER(c.first_name) = 'nane'
     AND LOWER(c.last_name) = 'narimanyan'
     AND LOWER(c.email) = 'nane.narimanyan@example.com')
)
RETURNING
    customer_id,
    first_name,
    last_name,
    email,
    address_id,
    last_update;


SELECT
    customer_id,
    first_name,
    last_name,
    email,
    address_id,
    last_update
FROM public.customer
WHERE LOWER(first_name) = 'nane' AND LOWER(last_name) = 'narimanyan';

COMMIT;
---------------------------------------------------------------------------------------------

-- Point 6

SELECT
    tc.table_name AS referencing_table,
    kcu.column_name AS referencing_column,
    ccu.table_name AS referenced_table,
    ccu.column_name AS referenced_column
FROM information_schema.table_constraints AS tc
JOIN information_schema.key_column_usage AS kcu
    ON tc.constraint_name = kcu.constraint_name
   AND tc.constraint_schema = kcu.constraint_schema
JOIN information_schema.constraint_column_usage AS ccu
    ON tc.constraint_name = ccu.constraint_name
   AND tc.constraint_schema = ccu.constraint_schema
WHERE tc.constraint_type = 'FOREIGN KEY'
  AND tc.table_schema = 'public'
  AND ccu.table_schema = 'public'
  AND ccu.table_name IN ('rental', 'payment')
ORDER BY referenced_table, referencing_table;


-- Checking the customer's existing rentals.
SELECT
    r.rental_id,
    r.customer_id,
    r.inventory_id,
    r.rental_date,
    r.return_date
FROM public.rental AS r
JOIN public.customer AS c
    ON r.customer_id = c.customer_id
WHERE LOWER(c.email) = 'nane.narimanyan@example.com'
  AND LOWER(c.first_name) = 'nane'
  AND LOWER(c.last_name) = 'narimanyan'
ORDER BY r.rental_id;


-- I remove my customer's old rental and payment records while keeping the customer and inventory records.
--
-- A separate transaction is used because both deletions must succeed together.
-- If one DELETE fails, the transaction can be rolled back without keeping only part of the changes.
-- ROLLBACK before COMMIT restores the deleted payments and rentals.
-- Referential integrity is preserved by deleting payments first, because payment records reference rental records.
-- The WHERE conditions limit deletion to my customer only.
-- The script is safe to rerun because already deleted records will not be deleted again.

BEGIN;

-- Checking the number of payments and rentals before deletion.
SELECT
    c.customer_id,
    (SELECT COUNT(*)
     FROM public.payment AS p
     WHERE p.customer_id = c.customer_id) AS payments_before,
    (SELECT COUNT(*)
     FROM public.rental AS r
     WHERE r.customer_id = c.customer_id) AS rentals_before
FROM public.customer AS c
WHERE LOWER(c.email) = 'nane.narimanyan@example.com'
  AND LOWER(c.first_name) = 'nane'
  AND LOWER(c.last_name) = 'narimanyan';

-- Delete the customer's payments first.
DELETE FROM public.payment AS p
WHERE p.customer_id IN (
    SELECT c.customer_id
    FROM public.customer AS c
    WHERE LOWER(c.email) = 'nane.narimanyan@example.com'
      AND LOWER(c.first_name) = 'nane'
      AND LOWER(c.last_name) = 'narimanyan'
)

RETURNING p.payment_id, p.customer_id, p.rental_id;

-- Delete the customer's rentals.
DELETE FROM public.rental AS r
WHERE r.customer_id IN (
    SELECT c.customer_id
    FROM public.customer AS c
    WHERE LOWER(c.email) = 'nane.narimanyan@example.com'
      AND LOWER(c.first_name) = 'nane'
      AND LOWER(c.last_name) = 'narimanyan'
)
RETURNING r.rental_id, r.customer_id, r.inventory_id;

-- Verify that all previous payments and rentals were removed.
SELECT
    c.customer_id,
    (SELECT COUNT(*)
     FROM public.payment AS p
     WHERE p.customer_id = c.customer_id) AS payments_after,
    (SELECT COUNT(*)
     FROM public.rental AS r
     WHERE r.customer_id = c.customer_id) AS rentals_after
FROM public.customer AS c
WHERE LOWER(c.email) = 'nane.narimanyan@example.com'
  AND LOWER(c.first_name) = 'nane'
  AND LOWER(c.last_name) = 'narimanyan';

COMMIT;
-- checking
SELECT
    c.customer_id,
    (SELECT COUNT(*)
     FROM public.payment p
     WHERE p.customer_id = c.customer_id) AS payments_after,
    (SELECT COUNT(*)
     FROM public.rental r
     WHERE r.customer_id = c.customer_id) AS rentals_after
FROM public.customer c
WHERE LOWER(c.email) = 'nane.narimanyan@example.com';



-----------------------------------------------------------------------------------------------

-- Point 7

SELECT
    table_name,
    column_name,
    data_type,
    is_nullable,
    column_default
FROM information_schema.columns
WHERE table_schema = 'public'
  AND table_name IN ('rental', 'payment')
ORDER BY table_name, ordinal_position;




-- Check which payment partitions exist and their date ranges.
SELECT
    child.relname AS partition_name,
    pg_get_expr(child.relpartbound, child.oid) AS date_range
FROM pg_inherits AS inh
JOIN pg_class AS parent
    ON parent.oid = inh.inhparent
JOIN pg_class AS child
    ON child.oid = inh.inhrelid
JOIN pg_namespace AS ns
    ON ns.oid = parent.relnamespace
WHERE ns.nspname = 'public'
  AND parent.relname = 'payment'
ORDER BY child.relname;


-- I rent The Prestige, The Matrix, and Se7en from Store 1.
-- Each movie has one inventory copy in this store.
-- I use June 15, 2017, because the payment table has a partition for June 2017.
--
-- A separate transaction is used because the rentals and payments belong to the same activity and must succeed together.
-- If an INSERT fails, the transaction can be rolled back.
-- ROLLBACK before COMMIT removes the new rentals and payments.
-- Referential integrity is preserved by selecting customer_id, inventory_id, and staff_id from existing records.
-- NOT EXISTS prevents duplicate rentals and payments when the script is executed again.

BEGIN;

-- Inserting the three rentals using existing customer, inventory, and staff records instead of hardcoding their IDs.

WITH selected_customer AS (
    SELECT customer_id
    FROM public.customer
    WHERE LOWER(first_name) = 'nane'
      AND LOWER(last_name) = 'narimanyan'
      AND LOWER(email) = 'nane.narimanyan@example.com'
),
selected_movies AS (
    SELECT DISTINCT ON (f.film_id)
        f.film_id,
        f.title,
        i.inventory_id,
        i.store_id,
        f.rental_rate
    FROM public.film AS f
    JOIN public.inventory AS i ON i.film_id = f.film_id
    WHERE LOWER(f.title) IN (
        'the prestige',
        'the matrix',
        'se7en'
    )
      AND i.store_id = (
          SELECT MIN(store_id)
          FROM public.store
      )
    ORDER BY f.film_id, i.inventory_id
),
selected_staff AS (
    SELECT DISTINCT ON (store_id)
        store_id,
        staff_id
    FROM public.staff
    ORDER BY store_id, staff_id
)
INSERT INTO public.rental (
    rental_date,
    inventory_id,
    customer_id,
    return_date,
    staff_id,
    last_update
)
SELECT
    TIMESTAMPTZ '2017-06-15 12:00:00+04',
    m.inventory_id,
    c.customer_id,
    NULL,
    s.staff_id,
    CURRENT_DATE
FROM selected_movies AS m
CROSS JOIN selected_customer AS c
JOIN selected_staff AS s ON s.store_id = m.store_id
WHERE NOT EXISTS (
    SELECT 1
    FROM public.rental AS r
    WHERE r.inventory_id = m.inventory_id
      AND r.customer_id = c.customer_id
      AND r.rental_date =
          TIMESTAMPTZ '2017-06-15 12:00:00+04'
)
RETURNING
    rental_id,
    inventory_id,
    customer_id,
    rental_date,
    staff_id;

-- The payment amount comes from the movie's rental_rate.

INSERT INTO public.payment (
    customer_id,
    staff_id,
    rental_id,
    amount,
    payment_date
)
SELECT
    r.customer_id,
    r.staff_id,
    r.rental_id,
    f.rental_rate,
    TIMESTAMPTZ '2017-06-15 12:05:00+04'
FROM public.rental AS r
JOIN public.inventory AS i ON r.inventory_id = i.inventory_id
JOIN public.film AS f ON i.film_id = f.film_id
JOIN public.customer AS c ON r.customer_id = c.customer_id
WHERE LOWER(c.email) = 'nane.narimanyan@example.com'
  AND LOWER(c.first_name) = 'nane'
  AND LOWER(c.last_name) = 'narimanyan'
  AND LOWER(f.title) IN (
      'the prestige',
      'the matrix',
      'se7en'
  )
  AND r.rental_date =
      TIMESTAMPTZ '2017-06-15 12:00:00+04'
  AND NOT EXISTS (
      SELECT 1
      FROM public.payment AS p
      WHERE p.rental_id = r.rental_id
        AND p.customer_id = r.customer_id
  )
RETURNING
    payment_id,
    customer_id,
    rental_id,
    amount,
    payment_date;

-- Checking 
SELECT
    f.title AS movie,
    r.rental_id,
    r.rental_date,
    p.payment_id,
    p.amount,
    p.payment_date
FROM public.rental AS r
JOIN public.inventory AS i ON r.inventory_id = i.inventory_id
JOIN public.film AS f ON i.film_id = f.film_id
JOIN public.customer AS c ON r.customer_id = c.customer_id
LEFT JOIN public.payment AS p ON r.rental_id = p.rental_id
   AND r.customer_id = p.customer_id
WHERE LOWER(c.email) = 'nane.narimanyan@example.com'
  AND r.rental_date =
      TIMESTAMPTZ '2017-06-15 12:00:00+04'
ORDER BY f.title;

-- COMMIT;
