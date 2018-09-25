/* a)	Вывести 10 самых продаваемых товаров (кол-во) за май 2017 года. */

WITH
     cte_sales_filter (product_id, qty) /* продажи за май 2017 в разрезе позиции */
AS
(
    SELECT
         sls.product_id
        ,SUM(sls.product_qty) AS qty
    FROM sales AS sls
    WHERE 1 = 1
        AND sls.sale_date >= CAST('2017-05-01' AS TIMESTAMP) 
        AND sls.sale_date < CAST('2017-06-01' AS TIMESTAMP)
    GROUP BY
         sls.product_id
)
SELECT
     pdc.name AS product_name
    ,csf.qty AS sale_qty
FROM cte_sales_filter AS csf
JOIN product AS pdc
ON csf.product_id = pdc.id
ORDER BY
     csf.qty DESC
LIMIT 10;

/* b)	Вывести товар, который продавался в наибольшем кол-ве аптек по итогам 2016 года. */

/* Замечание: если таких товаров несколько, выведем товар с минимальным названием 
 * в лексикографическом порядке
 */
WITH 
     cte_sales_by_partner (product_id, partner_cnt)
AS
(
    SELECT
         sls.product_id
        ,COUNT(sls.partner_id) AS partner_cnt
    FROM sales AS sls
    WHERE 1 = 1
        AND sls.sale_date >= CAST('2016-01-01' AS TIMESTAMP) 
        AND sls.sale_date < CAST('2017-01-01' AS TIMESTAMP)
    GROUP BY sls.product_id
)
SELECT
     prd.name
FROM cte_sales_by_partner AS csp
JOIN product AS prd
ON csp.product_id = prd.id
ORDER BY 
     sls.product_cnt DESC
    ,prd.name ASC
LIMIT 1;

/* c)	Вывести товары, которые не продавались в г. Краснодар */

/* Вариант 1 "в лоб" */

WITH
     cte_krasnodar_product (id) AS
(
    SELECT DISTINCT
         sls.product_id
    FROM sales AS sls
    JOIN partner AS sp
    ON sp.id = sls.partner_id
    JOIN city AS cty
    ON cty.id = sp.city_id
    WHERE cty.name = 'Краснодар'
)
SELECT DISTINCT /* иначе возникнут задвои из-за джойна к продажам */
     pdc.name
FROM product AS pdc
JOIN sales AS sls
ON sls.product_id = pdc.id /* исключаем товары, которые не продавались вообще */
LEFT JOIN cte_krasnodar_product AS ckp
ON ckp.id = pdc.id
WHERE 1 = 1
    AND ckp.id IS NULL;

/* Вариант 2, попытка оптимизации под большое количество записей в таблице sales */

/* Получаем аптеки Краснодара */
DROP TABLE IF EXISTS tmp_krasnodar_partner;

CREATE TEMPORARY TABLE tmp_krasnodar_partner
(
     id     INTEGER         PRIMARY KEY NOT NULL
);

INSERT INTO tmp_krasnodar_partner (id)
SELECT
     ptr.id
FROM partner AS ptr
JOIN city AS cty
ON 1 = 1
    AND cty.id = ptr.city_id
    AND cty.name = 'Краснодар';
    
/* id товаров + признак, продавались ли в данных аптеках */
    
DROP TABLE IF EXISTS tmp_product;

CREATE TEMPORARY TABLE tmp_product
(
     id         INTEGER     NOT NULL
    ,is_sold    BIT         NOT NULL
);

INSERT INTO tmp_product (id, is_sold)
SELECT
     sls.product_id
    ,CAST(MAX(CASE
                  WHEN tkp.id IS NULL
                  THEN 1
                  ELSE 0
              END) AS BIT) AS is_sold
FROM sales AS sls 
LEFT JOIN tmp_krasnodar_partner AS tkp
ON sls.partner_id = tkp.id
GROUP BY
     sls.product_id; /* здесь крайне нужно ограничение на период! */

CREATE UNIQUE INDEX idxu_product
ON tmp_product(id);
CLUSTER tmp_product USING idxu_product;
ANALYZE tmp_product;

SELECT
     pdc.name
FROM tmp_product AS filter
JOIN product AS pdc
ON pdc.id = filter.id
WHERE is_sold = 0;

DROP TABLE IF EXISTS tmp_product;

DROP TABLE IF EXISTS tmp_krasnodar_partner;

/* d)	Вывести 3 города, где больше всего аптек. */

/* Аптек немного, можно сделать подзапросом вместо материализации CTE */
SELECT
     city.name
FROM
(
    SELECT
         sp.city_id
        ,COUNT() AS partner_qty
    FROM partner AS sp
    GROUP BY 
         sp.city_id
) AS main
JOIN city AS cty
ORDER BY main.partner_qty DESC
LIMIT 3;

/* e) Вывести продажи самого дорогого товара за месяц, продажи которого превысили 10 шт. в месяц итого по всем аптекам. 
 * Вывести поля дата, аптека, город, товар, цена. 
 */

WITH
     cte_sales_extended
    (
         sales_id
        ,sale_date
        ,sale_month /* дата начала месяца продаж, например 2018-09-01 00:00:00 */
        ,product_id /* позиция */
    )
    AS
    (
        SELECT
             sls.id AS sales_id
            ,sls.sale_date
            ,date_trunc('month', sls.sale_date) AS sale_month
            ,sls.product_id
             /* для поиска средневзвешенной цены */
            ,sls.product_qty
            ,sls.price
        FROM sales AS sls
        /* здесь нужен фильтр на дату/время продажи! например, за последний 31 день */
    )
    ,cte_sales_grouped /* агрегат в разрезе позиция-месяц */
    (
         sale_month
        ,product_id
        ,total_income
        ,shipped_pcs
    )
    AS
    (
        SELECT
             sle.sale_month
            ,sle.product_id
            ,SUM(sle.product_qty * sle.price) AS total_income /* приход за месяц */
            ,SUM(sle.price) AS shipped_pcs /* объем по проданным позициям */
        FROM cte_sales_extended AS sle
        GROUP BY 
             sle.product_id
            ,sle.sale_month
    )
    ,cte_dearest_product /* Поиск самого дорогого товара за текущий месяц */
    (
         id
        ,avg_price /* для отладки */
    )
    AS
    (
        SELECT
             sgp.product_id AS id
            ,CASE
                 WHEN sgp.shipped_pcs = 0
                 THEN 0
                 ELSE sgp.total_income / sgp.shipped_pcs
             END AS avg_price
        FROM cte_sales_grouped AS sgp
        WHERE sgp.shipped_pcs > 10
        ORDER BY 
        (
             CASE
                 WHEN sgp.shipped_pcs = 0
                 THEN 0
                 ELSE sgp.total_income / sgp.shipped_pcs
             END
        ) DESC
        LIMIT 1
    )
SELECT
     sls.sale_date AS "Дата"
    ,sp.name AS "Аптека"
    ,cty.name AS "Город"
    ,pdc.name AS "Товар"
    ,sls.product_qty AS "Цена"
FROM sales AS sls
JOIN cte_dearest_product AS cdp
ON cdp.id = sls.product_id
JOIN product AS pdc
ON cdp.id = pdc.id
JOIN partner AS sp
ON sp.id = sls.partner_id
JOIN city AS cty
ON cty.id = sp.city_id
ORDER BY
     sls.sale_date ASC
    ,cty.name ASC
    ,sp.name ASC;

/* f)	В базе произошла ошибка. 
 * Все продажи за январь 2017 года для аптек г. Ставрополь сохранились в базе со знаком минус. 
 * Необходимо написать запрос, который исправит поле кол-во на положительное значение только для данных продаж. 
 */

WITH 
     cte_sales_monthly (id) AS
(
    SELECT
         sls.id
    FROM sales AS sls
    WHERE 1 = 1
        AND sls.sale_date < CAST('2017-02-01' AS TIMESTAMP)
        AND sls.sale_date >= CAST('2017-01-01' AS TIMESTAMP)
        AND sls.product_qty < 0
)
    ,cte_partner_stavropol (id) AS
(
    SELECT
         ptr.id
    FROM partner AS ptr
    JOIN city AS cty
    ON 1=1 
        AND cty.id = ptr.city_id
        AND cty.name = 'Ставрополь'
)
UPDATE sls
SET sls.product_qty = ABS(sls.product_qty)
FROM sales AS sls
JOIN cte_sales_monthly AS smt
ON smt.id = sls.id
JOIN cte_partner_stavropol AS cps
ON cps.id = sls.partner_id;

/* g)	В базе произошла ошибка. 
 * Произошло дублирование данных в таблице продажи для аптеки 5. 
 * Необходимо написать запрос удаления дубликатов
 */

/* Замечание: продажи считаются уникальными в разрезе дата/время-позиция-магазин */

WITH 
     cte_sales_dup 
    (
         id
        ,sale_date
        ,product_id
        ,partner_id
    ) 
    AS
(
    SELECT
         sls.id
        ,sls.sale_date
        ,sls.product_id
        ,sls.partner_id
    FROM sales AS sls
    WHERE sls.partner_id = 5
)
    ,cte_sales_dup_ranked
    (
         id
        ,sale_date
        ,product_id
        ,partner_id
        ,row_num
    )     
    AS
(
    SELECT
         sls.id
        ,sls.sale_date
        ,sls.product_id
        ,sls.partner_id
        ,ROW_NUMBER() OVER (
                            PARTITION BY
                                 sls.sale_date
                                ,sls.product_id
                                ,sls.partner_id          
                            ORDER BY
                                 sls.id ASC                       
                           )
    FROM cte_sales_dup AS sls
)    
    ,cte_sales_to_delete
    (
         id
         /* ещё 3 поля для отладки */
        ,sale_date
        ,product_id
        ,partner_id
    )     
    AS
(
    SELECT
         sls.id
        ,sls.sale_date
        ,sls.product_id
        ,sls.partner_id
    FROM cte_sales_dup_ranked AS sls
    WHERE sls.row_num > 1
)  
DELETE FROM sales AS main
USING cte_sales_to_delete AS csd
WHERE main.id = csd.id;
    


