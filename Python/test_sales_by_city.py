#!/usr/bin/env python3

"""Заполнение продаж в аптеках"""
import psycopg2
import datetime

"""
Исходные данные:
    * аптеки пронумерованы от pharmacy_1 до pharmacy_140
    * товары пронумерованы от product_1 до product_25
    * 7 городов, включая Краснодар и Ставрополь
"""


def setup(cr):
    query = "TRUNCATE TABLE sales;"
    cr.execute(query)


def teardown(cr):
    query = "TRUNCATE TABLE sales;"
    cr.execute(query)


def test(cr):
    cur_date = datetime.datetime.now()
    # Чистим таблицу продаж

    query = "TRUNCATE TABLE sales;"
    cr.execute(query)
    # получим аптеки
    query = """
    SELECT
         main.id
    FROM
    (
        SELECT
             ptr.id
        FROM partner AS ptr
        JOIN city AS cty
        ON cty.id = ptr.city_id
        WHERE cty.name = 'Краснодар'
        ORDER BY ptr.id ASC
        LIMIT 1
    ) AS main
    UNION ALL
    SELECT
         main.id
    FROM
    (
        SELECT
             ptr.id
        FROM partner AS ptr
        JOIN city AS cty
        ON cty.id = ptr.city_id
        WHERE cty.name <> 'Краснодар'
        ORDER BY ptr.id ASC
        LIMIT 1
    ) AS main;
    """
    cr.execute(query)
    # sales_points[0] - краснодар
    sales_points = [r[0] for r in cr.fetchall()]

    # Товары; просто топ 3
    query = """
    SELECT
         pdt.id
    FROM product AS pdt
    ORDER BY pdt.id ASC
    LIMIT 3;
    """
    cr.execute(query)
    products = [r[0] for r in cr.fetchall()]

    """
    Вставка данных для теста.
    Условия:
        1-й товар продавался только в Краснодаре
        2-й товар - в другом городе (в другой аптеке)
        3-й товар - и там, и там
    """
    vals_to_insert = [
        (products[0], sales_points[0]),
        (products[1], sales_points[1]),
        (products[2], sales_points[0]),
        (products[2], sales_points[1]),
    ]
    query = """
    INSERT INTO sales
    (
         product_id
        ,partner_id
        ,product_qty
        ,price
        ,sale_date
    )
    VALUES
    (
         %(product_id)s
        ,%(partner_id)s
        ,1
        ,1
        ,%(sale_date)s
    )
    """
    for product, sales_point in vals_to_insert:
        cr.execute(query, {
            'product_id': product,
            'partner_id': sales_point,
            'sale_date': cur_date  # потому что дата должна быть одна и консолидированная
        })

    query = """
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
    """
    cr.execute(query)
    actual_result = [r[0] for r in cr.fetchall()]

    query = """
    SELECT DISTINCT
         pdt.name
    FROM product AS pdt
    WHERE pdt.id = %(id)s            
    """
    cr.execute(query, {'id': products[1]})
    expected_result = [r[0] for r in cr.fetchall()]
    if expected_result == actual_result:
        return None
    else:
        return expected_result, actual_result
