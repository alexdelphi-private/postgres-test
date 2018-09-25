/* Моделирование данных для теста */
DO $$
DECLARE var_products INTEGER;
BEGIN
    /* Таблица с натуральными числами создана техникой tally table, 
     * потом пригодится при наполнении продаж 
     */
    DROP TABLE IF EXISTS numbers;
    
    CREATE TABLE numbers
    (
         id             INTEGER PRIMARY KEY NOT NULL
    );
    
    WITH
         cteZero (id) AS (SELECT 1 UNION ALL SELECT 1) 
        ,cteOne AS (SELECT 1 FROM cteZero AS a CROSS JOIN cteZero AS b) /* 4 записи */
        ,cteTwo AS (SELECT 1 FROM cteOne AS a CROSS JOIN cteOne AS b)
        ,cteThree AS (SELECT 1 FROM cteTwo AS a CROSS JOIN cteTwo AS b)
        ,cteFour AS (SELECT 1 FROM cteThree AS a CROSS JOIN cteThree AS b)
    INSERT INTO numbers(id)
    SELECT 
         ROW_NUMBER() OVER (ORDER BY NULL)
    FROM cteFour;
        
    TRUNCATE TABLE city;
        
    INSERT INTO city (name)
    VALUES 
         ('Краснодар')
        ,('Ставрополь')
        ,('Пятигорск')
        ,('Черкесск')
        ,('Ростов-на-Дону')
        ,('Москва')
        ,('Казань');
    
    /* Моделируем аптеки; в разном городе разное количество
     * В одном городе 5 аптек, во втором 10 и т.д. 
     */
     
    TRUNCATE TABLE partner;
    
    WITH
     cte_pharmacy_cnt AS
    (
        SELECT
             id
            ,name
            ,ROW_NUMBER() OVER (ORDER BY name ASC) AS qty
        FROM city AS cty
        ORDER BY name ASC
    )
    INSERT INTO partner (name, city_id)
    SELECT
         CONCAT('pharmacy_', num.id) AS name
        ,cph.id AS city_id
    FROM cte_pharmacy_cnt AS cph
    JOIN numbers AS num
    ON 1 = 1
        AND (num.id BETWEEN 5 * (cph.qty*cph.qty - cph.qty)/2 AND 5 * (cph.qty*cph.qty + cph.qty)/2 - 1);
        
    /* Моделируем 25 товаров */  
    
    var_products := 25;
    
    TRUNCATE TABLE product;
    INSERT INTO product (name)
    SELECT
         CONCAT('product_', num.id)
    FROM numbers AS num
    WHERE 1 = 1
        AND num.id <= var_products;
        
    
    
END $$;