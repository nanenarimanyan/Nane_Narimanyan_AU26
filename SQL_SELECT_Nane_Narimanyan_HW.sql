/* PART 1*/


/* TASK 1*/

/*The marketing team needs a list of animation movies between 2017 and 2019 to promote family-friendly content in an upcoming
season in stores. Show all animation movies released during this period with rate more than 1, sorted alphabetically*/

/* task 1 with joins*/
select
	film.film_id,
	film.title,
	film.description,
	film.rental_rate,
	category.name
from public.film
join public.film_category on film.film_id = film_category.film_id
join public.category on film_category.category_id = category.category_id
where release_year between 2017 and 2019 and rental_rate > 1 and category.name='Animation'
order by title;

/*The JOIN solution is simple and easy to read because we can clearly see how the tables are connected. It is usually
efficient, especially when the joining columns are indexed. However, joins can give us duplicate rows if there are
multiple matching records. This may require additional filtering and increase resource usage.*/


/*task 1 with subquery*/
SELECT
    f.film_id,
    f.title,
    f.description,
    f.release_year,
    f.rental_rate
FROM public.film AS f
WHERE f.film_id IN (
    SELECT fc.film_id
    FROM public.film_category AS fc
    INNER JOIN public.category AS c ON fc.category_id = c.category_id
    WHERE c.name = 'Animation'
)
AND f.release_year BETWEEN 2017 AND 2019
AND f.rental_rate > 1
ORDER BY f.title ASC;

/*The subquery solution separates the category filtering from the main query. Using IN also prevents duplicate film rows
caused by multiple matching IDs. However, nested queries can become harder to understand and maintain when the
logic gets more complicated. Performance depends on how PostgreSQL optimizes the query.*/

/* task 1 with cte*/
WITH animation_films AS (
    SELECT fc.film_id
    FROM public.film_category AS fc
    INNER JOIN public.category AS c ON fc.category_id = c.category_id
    WHERE c.name = 'Animation'
)
SELECT
    f.title,
    f.release_year,
    f.rental_rate
FROM public.film AS f
INNER JOIN animation_films AS af ON f.film_id = af.film_id
WHERE f.release_year BETWEEN 2017 AND 2019 AND f.rental_rate > 1
ORDER BY f.title;

/*The CTE solution makes the query more organized by separating it into logical parts. It is easier to read, debug, and
modify. However, for a simple task like this, it requires more code. In some cases, CTE materialization can increase
memory usage and affect performance.*/

/*I would use the JOIN solution because the task is simple and the relationships between the tables are clear.
It is easy to understand and maintain, and it does not require additional query structures. */



/*TASK 2*/

/*The finance department requires a report on store performance to assess profitability and plan resource allocation for stores
after March 2017. Calculate the revenue earned by each rental store after March 2017 (since April) (include columns: address and
address2 – as one column, revenue)*/


/*task 2 with joins*/
SELECT SUM(p.amount) AS revenue, CONCAT_WS(', ', a.address, a.address2) AS full_address
FROM public.payment AS p
INNER JOIN public.rental AS r ON p.rental_id = r.rental_id
INNER JOIN public.inventory AS i ON r.inventory_id = i.inventory_id
INNER JOIN public.store AS s ON i.store_id = s.store_id
INNER JOIN public.address AS a ON s.address_id = a.address_id
WHERE p.payment_date >= '2017-04-01'
GROUP BY s.store_id, a.address, a.address2;

/* This solution calculates the revenue directly by connecting payments to rentals, inventory, stores, and addresses.
It is shorter and does not require an additional query. BUt we need to pay attentionthat with five table, it is important to
check the relationships to avoid counting payments more than once.*/

/*task 2 with subqueries*/
SELECT
    CONCAT_WS(', ', a.address, a.address2) AS full_address,
    sr.revenue
FROM public.store AS s
INNER JOIN public.address AS a ON s.address_id = a.address_id
INNER JOIN (
    SELECT
        i.store_id,
        SUM(p.amount) AS revenue
    FROM public.payment AS p
    INNER JOIN public.rental AS r ON p.rental_id = r.rental_id
    INNER JOIN public.inventory AS i ON r.inventory_id = i.inventory_id
    WHERE p.payment_date >= '2017-04-01'
    GROUP BY i.store_id
) AS sr ON s.store_id = sr.store_id;

/* Here, I first calculate the total revenue for each store and then connect the results to the store addresses.
I like that the revenue calculation is independent of the address information. However, the subquery makes the SQL much longer,
which I do not find good property.*/


/*task 2 with cte*/

WITH store_revenue AS (
    SELECT
        i.store_id,
        SUM(p.amount) AS revenue
    FROM public.payment AS p
    INNER JOIN public.rental AS r ON p.rental_id = r.rental_id
    INNER JOIN public.inventory AS i ON r.inventory_id = i.inventory_id
    WHERE p.payment_date >= '2017-04-01'
    GROUP BY i.store_id
)
SELECT
    CONCAT_WS(', ', a.address, a.address2) AS full_address,
    sr.revenue
FROM public.store AS s
INNER JOIN public.address AS a ON s.address_id = a.address_id
INNER JOIN store_revenue AS sr ON s.store_id = sr.store_id;

/* The CTE creates a separate store_revenue result before adding the addresses. This is useful for a financial report because we
can easily check the revenue totals before showing the final result. But it requires more code, and it is not necessarily faster than
the other two solutions.*/


/* I would choose the CTE solution because the revenue calculation is the most important part ithink. Keeping it separate from the
address information makes it easier to verify the totals and update the report if the finance department needs more information later.*/



/*TASK 3*/

/*The marketing department in our stores aims to identify the most successful actors since 2015 to boost customer interest in their
films. Show top-5 actors by number of movies (released since 2015) they took part in (columns: first_name, last_name,
number_of_movies, sorted by number_of_movies in descending order)*/

/* task 3 with joins*/

SELECT
    a.first_name,
    a.last_name,
    COUNT(DISTINCT f.film_id) AS number_of_movies
FROM public.actor AS a
INNER JOIN public.film_actor AS fa ON a.actor_id = fa.actor_id
INNER JOIN public.film AS f ON fa.film_id = f.film_id
WHERE f.release_year >= 2015
GROUP BY a.actor_id, a.first_name, a.last_name
ORDER BY number_of_movies DESC, a.actor_id
LIMIT 5;

/*The JOIN solution connects actors with their movies and counts how many different films each actor appeared in
since 2015. It is quite direct and does not require additional query structures. If the number of records is large,
joining and grouping them may require more resources.*/

/*task 3 with subquery*/

SELECT
    a.first_name,
    a.last_name,
    ac.number_of_movies
FROM public.actor AS a
INNER JOIN (
    SELECT
        fa.actor_id,
        COUNT(DISTINCT f.film_id) AS number_of_movies
    FROM public.film_actor AS fa
    INNER JOIN public.film AS f
        ON fa.film_id = f.film_id
    WHERE f.release_year >= 2015
    GROUP BY fa.actor_id
) AS ac
    ON a.actor_id = ac.actor_id
ORDER BY ac.number_of_movies DESC, a.actor_id
LIMIT 5;

/*The correlated subquery calculates the number of movies separately for each actor. I think this approach is easy
to understand because it directly follows the business question. However, since the calculation depends on each
actor, it may require more processing, especially if there are many actors in the database.*/


/*task 3 with cte*/

WITH actor_movies AS (
    SELECT
        fa.actor_id,
        COUNT(DISTINCT f.film_id) AS number_of_movies
    FROM public.film_actor AS fa
    INNER JOIN public.film AS f ON fa.film_id = f.film_id
    WHERE f.release_year >= 2015
    GROUP BY fa.actor_id
)
SELECT
    a.first_name,
    a.last_name,
    am.number_of_movies
FROM public.actor AS a
INNER JOIN actor_movies AS am ON a.actor_id = am.actor_id
ORDER BY am.number_of_movies DESC, a.actor_id
LIMIT 5;

/* The CTE first calculates the number of movies for each actor and then connects these results to their names. This makes it
easier to separate the counting logic from the final ranking. However, it requires more code, and for this task, the additional
structure may not be necessary.*/

/* I would choose the JOIN solution because the main goal is to count movies for each actor and identify the top 5.
It allows us to perform the calculation and ranking in one query without unnecessary nesting. I also find it easier to maintain
for this particular problem.*/



/*TASK 4*/

/*The marketing team needs to track the production trends of Drama, Travel, and Documentary films to inform genre-specific marketing
strategies. Show number of Drama, Travel, Documentary per year (include columns: release_year, number_of_drama_movies,
number_of_travel_movies, number_of_documentary_movies), sorted by release year in descending order. Dealing with NULL values is
encouraged)*/

/*task 4 with joins*/

SELECT
    f.release_year,
    COUNT(DISTINCT f.film_id)
        FILTER (WHERE c.name = 'Drama') AS number_of_drama_movies,
    COUNT(DISTINCT f.film_id)
        FILTER (WHERE c.name = 'Travel') AS number_of_travel_movies,
    COUNT(DISTINCT f.film_id)
        FILTER (WHERE c.name = 'Documentary') AS number_of_documentary_movies
		
FROM public.film AS f
LEFT JOIN public.film_category AS fc ON f.film_id = fc.film_id
LEFT JOIN public.category AS c ON fc.category_id = c.category_id
GROUP BY f.release_year
ORDER BY f.release_year DESC;

/*The JOIN solution is the shortest and most direct approach. It connects the three tables and uses FILTER to count
Drama, Travel, and Documentary movies separately. However, if we need to add more complicated calculations later, the query
may become harder to read.*/



/*task 4 with subqueries*/

SELECT
    y.release_year,
    COALESCE(SUM(
        CASE WHEN counts.category_name = 'Drama'
             THEN counts.number_of_movies ELSE 0 END
    ), 0) AS number_of_drama_movies,
    COALESCE(SUM(
        CASE WHEN counts.category_name = 'Travel'
             THEN counts.number_of_movies ELSE 0 END
    ), 0) AS number_of_travel_movies,
    COALESCE(SUM(
        CASE WHEN counts.category_name = 'Documentary'
             THEN counts.number_of_movies ELSE 0 END
    ), 0) AS number_of_documentary_movies

FROM (
    SELECT DISTINCT release_year
    FROM public.film
) AS y

LEFT JOIN (
    SELECT
        f.release_year,
        c.name AS category_name,
        COUNT(DISTINCT f.film_id) AS number_of_movies
    FROM public.film AS f
    INNER JOIN public.film_category AS fc ON f.film_id = fc.film_id
    INNER JOIN public.category AS c ON fc.category_id = c.category_id
    WHERE c.name IN ('Drama', 'Travel', 'Documentary')
    GROUP BY f.release_year, c.name
) AS counts ON y.release_year = counts.release_year
GROUP BY y.release_year
ORDER BY y.release_year DESC;

/*The subquery solution first calculates the number of movies for each year and category, then organizes the
results into separate columns. This is good because now in this method it separates the counting logic from the final result.
However, it is longer than the JOIN solution and uses additional grouping and CASE expressions, which makes it more hard to
read as a code.
*/


/*task 4 with cte*/

WITH movie_counts AS (
    SELECT
        f.release_year,
        c.name AS category_name,
        COUNT(DISTINCT f.film_id) AS number_of_movies
    FROM public.film AS f
    INNER JOIN public.film_category AS fc ON f.film_id = fc.film_id
    INNER JOIN public.category AS c ON fc.category_id = c.category_id
    WHERE c.name IN ('Drama', 'Travel', 'Documentary')
    GROUP BY f.release_year, c.name
),
release_years AS (
    SELECT DISTINCT
        release_year
    FROM public.film
)
SELECT
    ry.release_year,
    COALESCE(
        SUM(CASE
            WHEN mc.category_name = 'Drama'
            THEN mc.number_of_movies
            ELSE 0
        END), 0
    ) AS number_of_drama_movies,
    COALESCE(
        SUM(CASE
            WHEN mc.category_name = 'Travel'
            THEN mc.number_of_movies
            ELSE 0
        END), 0
    ) AS number_of_travel_movies,
    COALESCE(
        SUM(CASE
            WHEN mc.category_name = 'Documentary'
            THEN mc.number_of_movies
            ELSE 0
        END), 0
    ) AS number_of_documentary_movies
FROM release_years AS ry
LEFT JOIN movie_counts AS mc ON ry.release_year = mc.release_year
GROUP BY ry.release_year
ORDER BY ry.release_year DESC;

/*The CTE solution separates the calculations into named parts, making the query easier to read and modify.
It is especially useful if we want to expand the report later. However, as we can see its code is way longer and it requires more
code, and for this specific task, the additional structure in my opinion is not necessary.
*/






/*PART 2*/

/*TASK 1*/

/*task 1 with joins*/
SELECT
    s.first_name,
    s.last_name,
    SUM(p.amount) AS total_revenue,
    last_store.store_id AS last_store_id
FROM public.staff AS s
INNER JOIN public.payment AS p ON s.staff_id = p.staff_id
LEFT JOIN LATERAL (
    SELECT
        i2.store_id
    FROM public.payment AS p2
    INNER JOIN public.rental AS r2 ON p2.rental_id = r2.rental_id
    INNER JOIN public.inventory AS i2 ON r2.inventory_id = i2.inventory_id
    WHERE p2.staff_id = s.staff_id
      AND p2.payment_date >= '2017-01-01'
      AND p2.payment_date < '2018-01-01'
    ORDER BY p2.payment_date DESC, p2.payment_id DESC
    LIMIT 1
) AS last_store ON TRUE
WHERE p.payment_date >= '2017-01-01' AND p.payment_date < '2018-01-01'
GROUP BY
    s.staff_id,
    s.first_name,
    s.last_name,
    last_store.store_id
ORDER BY
    total_revenue DESC,
    s.staff_id
LIMIT 3;

/*The JOIN solution connects the employees with their payments and calculates the total revenue directly. The advantage is
that most of the logic is in one query. However, combining revenue calculations and store information makes the query
longer and harder to read. The lateral subquery may also require additional processing for each employee.
*/


/*task 1 with subquery*/

SELECT
    s.first_name,
    s.last_name,
    revenue.total_revenue,
    (
        SELECT
            i.store_id
        FROM public.payment AS p2
        INNER JOIN public.rental AS r ON p2.rental_id = r.rental_id
        INNER JOIN public.inventory AS i ON r.inventory_id = i.inventory_id
        WHERE p2.staff_id = s.staff_id
          AND p2.payment_date >= '2017-01-01'
          AND p2.payment_date < '2018-01-01'
        ORDER BY p2.payment_date DESC, p2.payment_id DESC
        LIMIT 1
    ) AS last_store_id
FROM public.staff AS s
INNER JOIN (
    SELECT
        p.staff_id,
        SUM(p.amount) AS total_revenue
    FROM public.payment AS p
    WHERE p.payment_date >= '2017-01-01' AND p.payment_date < '2018-01-01'
    GROUP BY p.staff_id
) AS revenue ON s.staff_id = revenue.staff_id
ORDER BY revenue.total_revenue DESC, s.staff_id
LIMIT 3;


/* The subquery solution separates the revenue calculation from finding the last store. I find it easier to understand
because each subquery has a specific purpose. However, the subqueries depend on each employee,
which may require more processing when there are many employees. It also makes the query more nested.
*/



/*task 1 with cte*/

WITH employee_revenue AS (
    SELECT
        p.staff_id,
        SUM(p.amount) AS total_revenue
    FROM public.payment AS p
    WHERE p.payment_date >= '2017-01-01' AND p.payment_date < '2018-01-01'
    GROUP BY p.staff_id
),

employee_last_store AS (
    SELECT
        er.staff_id,
        last_payment.store_id AS last_store_id
    FROM employee_revenue AS er
    LEFT JOIN LATERAL (
        SELECT
            i.store_id
        FROM public.payment AS p
        INNER JOIN public.rental AS r ON p.rental_id = r.rental_id
        INNER JOIN public.inventory AS i ON r.inventory_id = i.inventory_id
        WHERE p.staff_id = er.staff_id
          AND p.payment_date >= '2017-01-01'
          AND p.payment_date < '2018-01-01'
        ORDER BY p.payment_date DESC, p.payment_id DESC
        LIMIT 1
    ) AS last_payment ON TRUE
)

SELECT
    s.first_name,
    s.last_name,
    er.total_revenue,
    els.last_store_id
FROM public.staff AS s
INNER JOIN employee_revenue AS er ON s.staff_id = er.staff_id
INNER JOIN employee_last_store AS els ON s.staff_id = els.staff_id
ORDER BY er.total_revenue DESC, s.staff_id
LIMIT 3;

/*The CTE solution divides the problem into named parts. One part calculates employee revenue, and another finds
the last store. This makes the business logic easier to follow and modify. But as we can even visually see it requires more code and
uses multiple query sections. */

/*I would choose the CTE solution because this task has two separate calculations which are finding the total revenue
and identifying the last store where an employee worked. Using CTEs makes these steps clearer and easier to maintain.
It would also be easier to change the calculations later.*/

/*TASK 2*/

/*task 2 with joins*/

SELECT
    f.title,
    COUNT(r.rental_id) AS number_of_rentals,
    f.rating,
    CASE
        WHEN f.rating = 'G' THEN 'All ages'
        WHEN f.rating = 'PG' THEN 'All ages (parental guidance suggested)'
        WHEN f.rating = 'PG-13' THEN '13+ (parental guidance for younger viewers)'
        WHEN f.rating = 'R' THEN '17+ (under 17 with parent or guardian)'
        WHEN f.rating = 'NC-17' THEN '18+ only'
        ELSE 'Unknown'
    END AS expected_audience_age
FROM public.film AS f
INNER JOIN public.inventory AS i ON f.film_id = i.film_id
INNER JOIN public.rental AS r ON i.inventory_id = r.inventory_id
GROUP BY f.film_id, f.title, f.rating
ORDER BY number_of_rentals DESC, f.film_id
LIMIT 5;

/*The JOIN solution is the most direct approach. It connects films, inventory, and rentals, then counts
the rentals for each movie. I think it is easy to understand because everything is calculated in one query.
However, if we need more calculations later, the query could become longer and more difficult to maintain.
The joins and grouping may also require more resources when working with large amounts of data.
*/

/*task 2 with subqueries*/

SELECT
    f.title,
    rc.number_of_rentals,
    f.rating,
    CASE
        WHEN f.rating = 'G' THEN 'All ages'
        WHEN f.rating = 'PG' THEN 'All ages (parental guidance suggested)'
        WHEN f.rating = 'PG-13' THEN '13+ (parental guidance for younger viewers)'
        WHEN f.rating = 'R' THEN '17+ (under 17 with parent or guardian)'
        WHEN f.rating = 'NC-17' THEN '18+ only'
        ELSE 'Unknown'
    END AS expected_audience_age
FROM public.film AS f
INNER JOIN (
    SELECT
        i.film_id,
        COUNT(r.rental_id) AS number_of_rentals
    FROM public.inventory AS i
    INNER JOIN public.rental AS r ON i.inventory_id = r.inventory_id
    GROUP BY i.film_id
) AS rc ON f.film_id = rc.film_id
ORDER BY rc.number_of_rentals DESC, f.film_id
LIMIT 5;

/*The subquery solution calculates rental counts separately and then connects them to movie information.
This makes it easier to separate the counting logic from the audience age calculation.
However, it introduces an additional nested query, which can make the structure more complicated.*/

/*task 2 with cte*/

WITH rental_counts AS (
    SELECT
        i.film_id,
        COUNT(r.rental_id) AS number_of_rentals
    FROM public.inventory AS i
    INNER JOIN public.rental AS r ON i.inventory_id = r.inventory_id
    GROUP BY i.film_id
)
SELECT
    f.title,
    rc.number_of_rentals,
    f.rating,
    CASE
        WHEN f.rating = 'G' THEN 'All ages'
        WHEN f.rating = 'PG' THEN 'All ages (parental guidance suggested)'
        WHEN f.rating = 'PG-13' THEN '13+ (parental guidance for younger viewers)'
        WHEN f.rating = 'R' THEN '17+ (under 17 with parent or guardian)'
        WHEN f.rating = 'NC-17' THEN '18+ only'
        ELSE 'Unknown'
    END AS expected_audience_age
FROM public.film AS f
INNER JOIN rental_counts AS rc ON f.film_id = rc.film_id
ORDER BY rc.number_of_rentals DESC, f.film_id
LIMIT 5;

/*The CTE solution uses a named section to calculate rental counts before selecting the movie information.
I find it readable because the two steps are clearly separated. It would also be easier to expand the query
if management requests additional movie statistics. However, it requires more code than the JOIN solution.
A CTE does not automatically make the query faster.*/


/* I would choose the CTE solution because it separates the rental counting from the movie information and
audience age calculation. This makes the query easier to read and maintain, especially if we want to add
more statistics later.
*/






/*PART 3*/

/*V1*/

/*V1 with joins*/
SELECT
    a.first_name,
    a.last_name,
    MAX(f.release_year) AS latest_release_year,
    EXTRACT(YEAR FROM CURRENT_DATE)::int - MAX(f.release_year) AS inactivity_years
FROM public.actor AS a
INNER JOIN public.film_actor AS fa ON a.actor_id = fa.actor_id
INNER JOIN public.film AS f ON fa.film_id = f.film_id
GROUP BY a.actor_id, a.first_name, a.last_name
ORDER BY inactivity_years DESC, a.actor_id;

/*V1 with subqueries*/

SELECT
    actor_data.first_name,
    actor_data.last_name,
    actor_data.latest_release_year,
    EXTRACT(YEAR FROM CURRENT_DATE)::int - actor_data.latest_release_year AS inactivity_years

FROM (
    SELECT
        a.actor_id,
        a.first_name,
        a.last_name,

        (
            SELECT MAX(f.release_year)
            FROM public.film_actor AS fa
            INNER JOIN public.film AS f ON fa.film_id = f.film_id
            WHERE fa.actor_id = a.actor_id
        ) AS latest_release_year

    FROM public.actor AS a
) AS actor_data
WHERE actor_data.latest_release_year IS NOT NULL
ORDER BY inactivity_years DESC, actor_data.actor_id;


/*V1 with cte*/

WITH latest_movies AS (
    SELECT
        fa.actor_id,
        MAX(f.release_year) AS latest_release_year
    FROM public.film_actor AS fa
    INNER JOIN public.film AS f ON fa.film_id = f.film_id
    GROUP BY fa.actor_id
)
SELECT
    a.first_name,
    a.last_name,
    lm.latest_release_year,
    EXTRACT(YEAR FROM CURRENT_DATE)::int - lm.latest_release_year AS inactivity_years
FROM public.actor AS a
INNER JOIN latest_movies AS lm ON a.actor_id = lm.actor_id
ORDER BY inactivity_years DESC, a.actor_id;


/*V2*/

/*V2 with joins*/

SELECT
    a.first_name,
    a.last_name,
    MAX(gaps.end_year - gaps.start_year) AS longest_gap_years,
    MIN(gaps.start_year) FILTER (
        WHERE gaps.end_year - gaps.start_year = (
            SELECT MAX(g2.end_year - g2.start_year)
            FROM (
                SELECT
                    y3.actor_id,
                    y3.release_year AS start_year,
                    MIN(y4.release_year) AS end_year
                FROM (
                    SELECT DISTINCT fa.actor_id, f.release_year
                    FROM public.film_actor AS fa
                    INNER JOIN public.film AS f ON fa.film_id = f.film_id
                ) AS y3
                INNER JOIN (
                    SELECT DISTINCT fa.actor_id, f.release_year
                    FROM public.film_actor AS fa
                    INNER JOIN public.film AS f ON fa.film_id = f.film_id
                ) AS y4
                    ON y3.actor_id = y4.actor_id
                   AND y4.release_year > y3.release_year
                GROUP BY y3.actor_id, y3.release_year
            ) AS g2
            WHERE g2.actor_id = gaps.actor_id
        )
    ) AS gap_start_year

FROM public.actor AS a

INNER JOIN (
    SELECT
        y1.actor_id,
        y1.release_year AS start_year,
        MIN(y2.release_year) AS end_year
    FROM (
        SELECT DISTINCT fa.actor_id, f.release_year
        FROM public.film_actor AS fa
        INNER JOIN public.film AS f ON fa.film_id = f.film_id
    ) AS y1
    INNER JOIN (
        SELECT DISTINCT fa.actor_id, f.release_year
        FROM public.film_actor AS fa
        INNER JOIN public.film AS f ON fa.film_id = f.film_id
    ) AS y2
        ON y1.actor_id = y2.actor_id
       AND y2.release_year > y1.release_year
    GROUP BY y1.actor_id, y1.release_year
) AS gaps ON a.actor_id = gaps.actor_id
GROUP BY a.actor_id, a.first_name, a.last_name
ORDER BY longest_gap_years DESC, a.actor_id;

/*v2 with subqueires*/

SELECT
    a.first_name,
    a.last_name,
    MAX(gaps.gap_years) AS longest_gap_years,
    MIN(gaps.previous_year) AS gap_start_year,
    MIN(gaps.release_year) FILTER (
        WHERE gaps.gap_years = (
            SELECT MAX(g2.gap_years)
            FROM (
                SELECT
                    fa2.actor_id,
                    f2.release_year -
                    (
                        SELECT MAX(f3.release_year)
                        FROM public.film_actor AS fa3
                        INNER JOIN public.film AS f3 ON fa3.film_id = f3.film_id
                        WHERE fa3.actor_id = fa2.actor_id AND f3.release_year < f2.release_year
                    ) AS gap_years
                FROM public.film_actor AS fa2
                INNER JOIN public.film AS f2 ON fa2.film_id = f2.film_id
            ) AS g2
            WHERE g2.actor_id = gaps.actor_id
        )
    ) AS gap_end_year

FROM public.actor AS a

INNER JOIN (
    SELECT DISTINCT
        fa.actor_id,
        f.release_year,

        (
            SELECT MAX(f2.release_year)
            FROM public.film_actor AS fa2
            INNER JOIN public.film AS f2 ON fa2.film_id = f2.film_id
            WHERE fa2.actor_id = fa.actor_id AND f2.release_year < f.release_year
        ) AS previous_year,
        f.release_year - (
            SELECT MAX(f2.release_year)
            FROM public.film_actor AS fa2
            INNER JOIN public.film AS f2 ON fa2.film_id = f2.film_id
            WHERE fa2.actor_id = fa.actor_id AND f2.release_year < f.release_year
        ) AS gap_years
    FROM public.film_actor AS fa
    INNER JOIN public.film AS f ON fa.film_id = f.film_id
) AS gaps ON a.actor_id = gaps.actor_id
WHERE gaps.previous_year IS NOT NULL
GROUP BY a.actor_id, a.first_name, a.last_name
ORDER BY longest_gap_years DESC, a.actor_id;

/*V2 with cte*/

WITH actor_years AS (
    SELECT DISTINCT
        fa.actor_id,
        f.release_year
    FROM public.film_actor AS fa
    INNER JOIN public.film AS f ON fa.film_id = f.film_id
),

previous_years AS (
    SELECT
        current_year.actor_id,
        current_year.release_year,
        MAX(earlier_year.release_year) AS previous_year
    FROM actor_years AS current_year

    LEFT JOIN actor_years AS earlier_year ON current_year.actor_id = earlier_year.actor_id
       AND earlier_year.release_year < current_year.release_year
    GROUP BY current_year.actor_id, current_year.release_year
),

gaps AS (
    SELECT
        actor_id,
        previous_year AS gap_start_year,
        release_year AS gap_end_year,
        release_year - previous_year AS gap_years
    FROM previous_years
    WHERE previous_year IS NOT NULL
),

longest_gaps AS (
    SELECT
        actor_id,
        MAX(gap_years) AS longest_gap_years
    FROM gaps
    GROUP BY actor_id
)

SELECT
    a.first_name,
    a.last_name,
    lg.longest_gap_years,
    MIN(g.gap_start_year) AS gap_start_year,
    MIN(g.gap_end_year) AS gap_end_year
FROM public.actor AS a
INNER JOIN longest_gaps AS lg ON a.actor_id = lg.actor_id
INNER JOIN gaps AS g ON lg.actor_id = g.actor_id
   AND lg.longest_gap_years = g.gap_years
GROUP BY
    a.actor_id,
    a.first_name,
    a.last_name,
    lg.longest_gap_years
ORDER BY lg.longest_gap_years DESC, a.actor_id;

/*

The JOIN approach connects actors to their films and calculates inactivity using release years. For V1,
it is short and easy to understand. For V2, the self-joins make the query much more complicated
because we need to identify consecutive years.

The subquery approach allows us to calculate the latest or previous release year separately for each
actor. It follows the problem logic quite naturally. However, correlated subqueries may require more
processing, especially for V2, where previous release years must be checked repeatedly.

The CTE approach divides the problem into smaller steps. For V1, it separates the latest release year
from the inactivity calculation. For V2, it separates active years, previous years, and inactivity gaps.
This makes the query easier to understand and modify. However, it requires more code, and performance
still depends on the execution plan.



For V1, I would choose the JOIN solution because the calculation is simple and can be done directly
using MAX and GROUP BY.

For V2, I would choose the CTE solution because finding gaps between consecutive releases is more
complicated. The CTE makes each step clearer and would be easier to maintain or extend later.

*/