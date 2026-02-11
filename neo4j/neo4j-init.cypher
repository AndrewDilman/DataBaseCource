// создание пользователей
CREATE USER reader SET PASSWORD '12345678' CHANGE NOT REQUIRED;
CREATE USER publisher SET PASSWORD '12345678' CHANGE NOT REQUIRED;

// назначение ролей
GRANT ROLE reader TO reader;
GRANT ROLE publisher TO publisher;
GRANT ROLE admin TO publisher;

// чтоб паблишер мог и читать и писать
GRANT WRITE ON GRAPH * TO publisher;
GRANT MATCH {*} ON GRAPH * TO publisher;