-- Question: What is the most popular MPAA rating at Store 1 overall?

-- CREATE new Function which reformats the store_id from a single int to a more descriptive string
CREATE OR REPLACE FUNCTION fn_store_name(store_id SMALLINT)
RETURNS VARCHAR
LANGUAGE plpgsql
AS
$$BEGIN
	RETURN CONCAT('Store ', store_id);
END$$;

-- Show store_id default below:
-- SELECT store_id FROM store;

-- CREATE new Function to calculate the rating's percentage of total rentals
CREATE OR REPLACE FUNCTION calc_percentage(rating_total BIGINT, total_sum BIGINT)
RETURNS VARCHAR
LANGUAGE plpgsql
AS
$$
BEGIN
	RETURN CONCAT(round(100 * rating_total::numeric / total_sum::numeric, 2), '%');
END;
$$;

-- CREATES new details table 'rented_films'
DROP TABLE IF EXISTS rented_films;
CREATE TABLE rented_films (
	film_id			INT,
	title			VARCHAR(100),
	rating			VARCHAR(20),
	rental_id		INT,
	inventory_id	INT,
	store_id		VARCHAR(10)
);
-- Insert data into details table 'rented_films'
INSERT INTO rented_films
SELECT 
	f.film_id, 
	f.title, 
	f.rating, 
	r.rental_id, 
	r.inventory_id, 
	fn_store_name(i.store_id) -- Using custom fn_store_name() function
FROM inventory i
INNER JOIN film f ON f.film_id = i.film_id
INNER JOIN rental r ON r.inventory_id = i.inventory_id
ORDER BY f.film_id;

-- CREATES new summary table 'store1_ratings'
DROP TABLE IF EXISTS store1_ratings;
CREATE TABLE store1_ratings (
	"store id"	VARCHAR(10),
	rating     	VARCHAR(10),
	total	   	BIGINT,
	percentage 	VARCHAR(10)
);

-- CREATE TRIGGER to auto-populate the 'percentage' field AFTER updates to the store1_ratings table
CREATE OR REPLACE FUNCTION insert_percentages()
	RETURNS TRIGGER
	LANGUAGE plpgsql
AS
$$
DECLARE rec RECORD;
DECLARE total_sum BIGINT := (SELECT SUM(total) FROM store1_ratings);
BEGIN
    FOR rec IN SELECT * FROM store1_ratings LOOP
        UPDATE store1_ratings
        SET percentage = calc_percentage(rec.total, total_sum) -- Uses custom function calc_percentage()
        WHERE rating = rec.rating AND "store id" = rec."store id";
    END LOOP;
	RETURN NEW;
END$$;

DROP TRIGGER IF EXISTS insert_percentages_trigger ON store1_ratings;

CREATE TRIGGER insert_percentages_trigger
	AFTER INSERT
	ON store1_ratings
	FOR EACH STATEMENT
EXECUTE PROCEDURE insert_percentages();

-- Inserts data into 'store1_ratings'
INSERT INTO store1_ratings
SELECT 
	store_id, 
	rating, 
	COUNT(rating)
FROM rented_films
WHERE store_id = 'Store 1'
GROUP BY store_id, rating
ORDER BY store_id, COUNT(rating) DESC;


SELECT * FROM rented_films;
SELECT * FROM store1_ratings;

-- Create Procedure to update both summary and details tables
CREATE OR REPLACE PROCEDURE update_rented_store1_ratings()
LANGUAGE plpgsql
AS 
$$
BEGIN
	
-- Remove data from detail table and fetch fresh data
TRUNCATE rented_films;
INSERT INTO rented_films
SELECT 
	f.film_id, 
	f.title, 
	f.rating, 
	r.rental_id, 
	r.inventory_id, 
	fn_store_name(i.store_id) -- Using custom fn_store_name function
FROM inventory i
INNER JOIN film f ON f.film_id = i.film_id
INNER JOIN rental r ON r.inventory_id = i.inventory_id
ORDER BY f.film_id;

-- Remove data from summary table and fetch fresh data
TRUNCATE store1_ratings;
INSERT INTO store1_ratings
SELECT 
	store_id, 
	rating, 
	COUNT(rating)
FROM rented_films
WHERE store_id = 'Store 1'
GROUP BY store_id, rating
ORDER BY store_id, COUNT(rating) DESC;

RETURN;
END;
$$;

-- Queries below are for testing the new procedure above:
DELETE FROM rented_films;
SELECT * FROM rented_films;
DELETE FROM store1_ratings;
SELECT * FROM store1_ratings;
CALL update_rented_store1_ratings();



-- CREATES trigger 'update_store1_ratings' ON details table 'rented_films' to update on changes
CREATE OR REPLACE FUNCTION update_store1_ratings()
	RETURNS TRIGGER
	LANGUAGE plpgsql
AS
$$BEGIN
-- TRUNCATE store1_ratings rows, before inserting fresh data into it again:
TRUNCATE store1_ratings;
INSERT INTO store1_ratings
SELECT 
	store_id, 
	rating, 
	COUNT(rating)
FROM rented_films
WHERE store_id = 'Store 1'
GROUP BY store_id, rating
ORDER BY store_id, COUNT(rating) DESC;
RETURN NEW;
END$$;

DROP TRIGGER IF EXISTS update_store1_ratings_trigger ON rented_films;

CREATE TRIGGER update_store1_ratings_trigger
	AFTER INSERT OR DELETE OR UPDATE
	ON rented_films
	FOR EACH STATEMENT
EXECUTE PROCEDURE update_store1_ratings();


-- Functions below are for testing the implemented trigger:
SELECT * FROM store1_ratings WHERE rating = 'PG';

INSERT INTO rented_films VALUES(1, 'Academy Dinosaur', 'PG', 1, 3, 'Store 1');
SELECT * FROM rented_films WHERE title = 'Academy Dinosaur' AND store_id = 'Store 1';

-- Clean the table data:
CALL update_rented_store1_ratings();
SELECT * FROM store1_ratings WHERE rating = 'PG';
SELECT * FROM store1_ratings;


-- Wipe all tables, triggers, functions, and procedures:
--CALL total_refresh();

-- Personal Procedure to wipe all changes made to the DB
CREATE OR REPLACE PROCEDURE total_refresh()
LANGUAGE plpgsql
AS
$$BEGIN
DROP TABLE IF EXISTS rented_films;
DROP TABLE IF EXISTS store1_ratings;
DROP PROCEDURE IF EXISTS update_rented_store1_ratings;
DROP FUNCTION IF EXISTS fn_store_name;
DROP FUNCTION IF EXISTS calc_percentage;
DROP TRIGGER IF EXISTS update_store1_ratings ON rented_films;
END$$;