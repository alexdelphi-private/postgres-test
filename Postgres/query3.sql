/* 3.	Создайте хранимую процедуру добавления/изменения справочника «Водители» 
 * с проверками указанных выше ограничений. 
 * Права на запуск имеет роль диспетчер и администратор БД.
 */
 
DROP TABLE IF EXISTS error;
CREATE TABLE error
(
     id         SERIAL          PRIMARY KEY NOT NULL
    ,name       VARCHAR(200)    NOT NULL
);

INSERT INTO error (name)
VALUES
     ('Отсутствует фамилия')
    ,('Отсутствует имя')
    ,('Отсутствует отчество')
    ,('Связка ФИО не уникальна')
    ,('Телефон не находится в формате 79181112233')
    ,('Операция выполнена успешно'); 
     /* если процедура отработала, значение в таблице error_instance будет в любом случае */
    
GRANT SELECT ON error TO dispatcher;
GRANT SELECT, INSERT, UPDATE, DELETE ON error TO controller;
    
DROP TABLE IF EXISTS error_instance;
CREATE TABLE error_instance
(
     id             SERIAL          PRIMARY KEY NOT NULL
    ,instance_id    INTEGER         NOT NULL
    ,error_id       INTEGER         NOT NULL
);

/* 
 * Процедура возвращает ссылку на справочник статусов.
 */
CREATE OR REPLACE FUNCTION insert_driver
(
     last_name      VARCHAR(100)
    ,first_name     VARCHAR(100)
    ,patronymic     VARCHAR(100)
     /* В БД все параметры кроме ФИО - необязательные, отразим это в параметрах функции */
    ,birth_date     TIMESTAMP           DEFAULT NULL
    ,sex            type_driver_sex     DEFAULT NULL
    ,hire_date      TIMESTAMP           DEFAULT NULL
    ,is_working     type_driver_status  DEFAULT 'не работает'
    ,license_type   VARCHAR(10)         DEFAULT NULL
    ,address        VARCHAR(1000)       DEFAULT NULL
    ,phone          VARCHAR(50)         DEFAULT NULL
)
RETURNS INTEGER AS $$
DECLARE
    var_instance_id     INTEGER := 0; /* id записи */
    var_is_name_valid   BOOLEAN := TRUE; /* ФИО не NULL */
    var_is_phone_valid  BOOLEAN := TRUE; /* телефон в нормальном формате */
    var_names_present   INTEGER := 0; /* такое имя НЕ уникально  */
BEGIN
    /* Вставляем фиктивную запись в таблицу error_instance. 
     * Её id даёт новый instance_id справочника статусов.
     * Поскольку INSERT блокирует вставляемую таблицу (https://www.postgresql.org/docs/9.4/static/explicit-locking.html)
     * то мы гарантированно получим "свежий" id.
     * После его получения запись удаляется; поскольку значение id увеличилось, оно останется свободным и параллельные запуски процедуры на него не повлияют.
     */
    INSERT INTO error_instance (instance_id, error_id)
    VALUES (0, 0)
    RETURNING id INTO var_instance_id;
    
    DELETE FROM error_instance
    WHERE id = var_instance_id;
    /* Валидация. 
     * Дальнейшие ошибки будут записываться с параметром instance_id = var_instance_id 
     */
     
    /* По условиям ТЗ телефон может быть NULL */
    IF phone IS NOT NULL AND phone !~ '^7\d{10}$' THEN
        INSERT INTO error_instance (instance_id, error_id)
        VALUES (var_instance_id, 5); /* 'Телефон не находится в формате 79181112233' */    
        var_is_phone_valid := FALSE;    
    END IF;
     
    IF last_name IS NULL THEN
        INSERT INTO error_instance (instance_id, error_id)
        VALUES (var_instance_id, 1); /* 'Отсутствует фамилия' */
        var_is_name_valid := FALSE;
    END IF;
    IF first_name IS NULL THEN
        INSERT INTO error_instance (instance_id, error_id)
        VALUES (var_instance_id, 2); /* 'Отсутствует имя' */
        var_is_name_valid := FALSE;
    END IF;    
    IF patronymic IS NULL THEN
        INSERT INTO error_instance (instance_id, error_id)
        VALUES (var_instance_id, 3); /* 'Отсутствует отчество' */
        var_is_name_valid := FALSE;
    END IF;
    /* Если хотя бы одно поле ФИО отсутствует, не проверяем на уникальность и выходим */
    IF NOT var_is_name_valid THEN
        RETURN var_instance_id;
    END IF;
    
    /* Проверка уникальности ФИО */
    SELECT
        COUNT(*)
    INTO var_names_present
    FROM driver AS drv
    WHERE 1 = 1
        AND drv.last_name = insert_driver.last_name
        AND drv.patronymic = insert_driver.patronymic
        AND drv.first_name = insert_driver.first_name;
    
    IF var_names_present > 0 THEN
        INSERT INTO error_instance (instance_id, error_id)
        VALUES (var_instance_id, 4); /* 'Связка ФИО не уникальна' */
        RETURN var_instance_id;        
    END IF;
    
    IF NOT var_is_phone_valid THEN
        RETURN var_instance_id;
    END IF;
    
    INSERT INTO driver
    (
         last_name      
        ,first_name     
        ,patronymic     
        ,birth_date     
        ,sex            
        ,hire_date      
        ,is_working     
        ,license_type   
        ,address        
        ,phone          
    )
    VALUES
    (
         last_name     
        ,first_name    
        ,patronymic    
        ,birth_date    
        ,sex           
        ,hire_date     
        ,is_working    
        ,license_type  
        ,address       
        ,phone         
    );
    
    INSERT INTO error_instance (instance_id, error_id)
    VALUES (var_instance_id, 6); /* 'Операция выполнена успешно' */    
    RETURN var_instance_id;
    
END; $$
LANGUAGE plpgsql;
 
REVOKE ALL ON FUNCTION insert_driver
(
     last_name      VARCHAR(100)
    ,first_name     VARCHAR(100)
    ,patronymic     VARCHAR(100)
    ,birth_date     TIMESTAMP
    ,sex            type_driver_sex
    ,hire_date      TIMESTAMP
    ,is_working     type_driver_status
    ,license_type   VARCHAR(10)
    ,address        VARCHAR(1000)
    ,phone          VARCHAR(50) 
) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION insert_driver
(
     last_name      VARCHAR(100)
    ,first_name     VARCHAR(100)
    ,patronymic     VARCHAR(100)
    ,birth_date     TIMESTAMP
    ,sex            type_driver_sex
    ,hire_date      TIMESTAMP
    ,is_working     type_driver_status 
    ,license_type   VARCHAR(10)
    ,address        VARCHAR(1000)
    ,phone          VARCHAR(50) 
) TO dispatcher;