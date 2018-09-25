/* Создание схем */

DROP TABLE IF EXISTS sales;
DROP TABLE IF EXISTS partner;
DROP TABLE IF EXISTS city;
DROP TABLE IF EXISTS product;

CREATE TABLE product
(
     id            SERIAL           NOT NULL    PRIMARY KEY
    ,name          VARCHAR(200)     NOT NULL
);

CREATE TABLE city
(
     id             SERIAL          NOT NULL    PRIMARY KEY
    ,name           VARCHAR(200)    NOT NULL
);

CREATE TABLE partner
(
     id             SERIAL          NOT NULL    PRIMARY KEY
    ,name           VARCHAR(200)    NOT NULL    
    ,city_id        INTEGER         NOT NULL    /* CONSTRAINT fk_city_id REFERENCES city */
);

CREATE TABLE sales
(
     id             SERIAL          NOT NULL    PRIMARY KEY    
    ,sale_date      TIMESTAMP       NOT NULL
    ,product_id     INTEGER         NOT NULL    /* CONSTRAINT fk_product_id REFERENCES product */
    ,partner_id     INTEGER         NOT NULL    /* CONSTRAINT fk_partner_id REFERENCES partner */
    ,product_qty    NUMERIC (18, 2) NOT NULL /* почему не (18, 3)? */
    ,price          NUMERIC (18, 2) NOT NULL
);