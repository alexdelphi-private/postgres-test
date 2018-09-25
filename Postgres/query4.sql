/* 4.	Создайте представление, которое будет выводить точки маршрутов 
 * с информацией о маршруте, автомобиле и водителях. 
 * Права на просмотр имеют роли диспетчер и оператор.  
 */
 
/* 
 * Подводные камни в ТЗ:
 * витрина покажет инфо о не открытых маршрутах и не работающих водителях
 */
DROP VIEW IF EXISTS route_point_report;
CREATE VIEW route_point_report
AS
SELECT
     cr.series
    ,cr.license_plate
    ,CASE
         WHEN rtd.route_id IS NULL
         THEN ''
         ELSE rtd.drivers
     END AS drivers
    ,rte.open_dtm
    ,rtp.point_id
    ,CONCAT_WS(' ', rtp.point_type, rtp.point_name) AS point_info
    ,rtp.arrival_plan_dtm      
    ,rtp.departure_plan_dtm    
    ,rtp.arrival_fact_dtm      
    ,rtp.departure_fact_dtm    
FROM route AS rte
LEFT JOIN 
(
    SELECT 
         string_agg(
            CONCAT_WS(
                ' ', drv.last_name, drv.first_name, drv.patronymic
         ), ',' 
            ORDER BY 
                 drv.last_name ASC
                ,drv.first_name ASC) AS drivers
        ,rtd.route_id
    FROM routed_driver AS rtd
    JOIN driver AS drv
    ON rtd.driver_id = drv.id    
    GROUP BY rtd.route_id
) AS rtd
ON rte.id = rtd.route_id
JOIN car AS cr
ON cr.id = rte.car_id
JOIN route_point AS rtp
ON rtp.route_id = rte.id;

GRANT SELECT ON route_point_report TO controller;
GRANT SELECT ON route_point_report TO dispatcher;