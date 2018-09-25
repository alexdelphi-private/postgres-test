DROP ROLE IF EXISTS dispatcher;
CREATE ROLE dispatcher;

DROP ROLE IF EXISTS controller; /* оператор */
CREATE ROLE controller;

DROP TYPE IF EXISTS type_driver_status;
CREATE TYPE type_driver_status AS ENUM('работает', 'не работает');

DROP TYPE IF EXISTS type_route_status;
CREATE TYPE type_route_status AS ENUM('открыт', 'не открыт');

DROP TYPE IF EXISTS type_driver_sex;
CREATE TYPE type_driver_sex AS ENUM('мужской', 'женский');

DROP TABLE IF EXISTS car;
CREATE TABLE car
(
     id             SERIAL          PRIMARY KEY NOT NULL
    ,license_plate  VARCHAR(50)     NOT NULL CONSTRAINT license_unique UNIQUE
    ,vin            VARCHAR(100)    NOT NULL CONSTRAINT vin_unique UNIQUE
    ,series         VARCHAR(100)    NOT NULL
);

GRANT SELECT ON car TO PUBLIC;
GRANT INSERT, UPDATE, DELETE ON car TO dispatcher;

DROP TABLE IF EXISTS driver;
CREATE TABLE driver
(
     id             SERIAL              PRIMARY KEY NOT NULL
    ,last_name      VARCHAR(100)        NOT NULL
    ,first_name     VARCHAR(100)        NOT NULL
    ,patronymic     VARCHAR(100)        NOT NULL
    ,birth_date     TIMESTAMP
    ,sex            type_driver_sex
    ,hire_date      TIMESTAMP
    ,is_working     type_driver_status  DEFAULT 'не работает' 
    ,license_type   VARCHAR(10)
    ,address        VARCHAR(1000)
    ,phone          VARCHAR(50)     
    ,CONSTRAINT name_unique 
     UNIQUE 
     (
          last_name
         ,first_name
         ,patronymic 
     )
    ,CONSTRAINT phone_match
     CHECK(phone ~ '^7\d{10}$')
);

GRANT SELECT ON driver TO controller;
GRANT SELECT, INSERT, UPDATE, DELETE ON driver TO dispatcher;

/* Соответствие водитель-маршрут */
DROP TABLE IF EXISTS routed_driver;
CREATE TABLE routed_driver
(
     id             SERIAL          NOT NULL PRIMARY KEY 
    ,route_id       INTEGER         NOT NULL
    ,driver_id      INTEGER         NOT NULL
);

GRANT SELECT ON routed_driver TO controller;
GRANT SELECT, INSERT, UPDATE, DELETE ON routed_driver TO dispatcher;

/* Маршруты */
DROP TABLE IF EXISTS route;
CREATE TABLE route
(
     id                 SERIAL              NOT NULL PRIMARY KEY 
    ,car_id             INTEGER             NOT NULL
    ,type_name          VARCHAR(100)        NOT NULL DEFAULT 'Прямая доставка'
    ,is_open            type_route_status   NOT NULL DEFAULT 'не открыт'
    ,open_dtm           TIMESTAMP           NOT NULL
    ,user_opened        VARCHAR(100)        NOT NULL /* водители маршрута привязаны отдельно */
);

GRANT SELECT ON route TO controller;
GRANT SELECT, INSERT, UPDATE, DELETE ON route TO dispatcher;

DROP TABLE IF EXISTS route_point;
CREATE TABLE route_point
(
     id                     SERIAL          NOT NULL PRIMARY KEY 
    ,route_id               INTEGER         NOT NULL
    ,point_id               INTEGER         NOT NULL
    ,point_type             VARCHAR(50)     NOT NULL
    ,point_name             VARCHAR(100)    NOT NULL
    ,arrival_plan_dtm       TIMESTAMP       NOT NULL
    ,departure_plan_dtm     TIMESTAMP       NOT NULL
    ,arrival_fact_dtm       TIMESTAMP       NOT NULL
    ,departure_fact_dtm     TIMESTAMP       NOT NULL
    ,CONSTRAINT correct_plan_dtm CHECK(arrival_plan_dtm < departure_plan_dtm)
    ,CONSTRAINT correct_fact_dtm CHECK(arrival_fact_dtm < departure_fact_dtm)
     /* в продакшне потребуются проверки на IS NULL */
);

GRANT SELECT ON route_point TO controller;
GRANT SELECT, INSERT, UPDATE, DELETE ON route_point TO dispatcher;
