#!/usr/bin/env python3
import argparse
import collections
import psycopg2
import test_sales_by_city
"""
Запускатор для тестов.
Справка по параметрам доступна по ключу -h
"""


def main():
    # Парсинг аргументов
    # Параметры соответствуют ключевым параметрам psycopg2.connect(), для удобства
    Arguments = collections.namedtuple('Arguments', [
        'help_text', 'default_value'
    ])
    args = {
        'dbname': Arguments('имя БД', 'test'),
        'user': Arguments('пользователь', None),
        'password': Arguments('пароль', None),
        'host': Arguments('имя либо IP сервера', '127.0.0.1'),  # потому что -h зарезервирован argparse
        'port': Arguments('порт', 5432)
    }
    parser = argparse.ArgumentParser()
    for key, value in args.items():
        parser.add_argument('--{}'.format(key),
                            help='{0} (по умолчанию {1})'.format(value.help_text, value.default_value),
                            default=value.default_value)
    parsed_args = vars(parser.parse_args())
    with psycopg2.connect(**parsed_args) as conn:
        with conn.cursor() as cr:
            print('Тест 1. Вывести все товары, которые не продавались в Краснодаре')
            try:
                test_sales_by_city.setup(cr)
                res = test_sales_by_city.test(cr)
                if res is None:
                    print('Контрольная точка пройдена')
                else:
                    expected_result, actual_result = res
                    print('Контрольная точка не пройдена')
                    print('Ожидаемый результат: {}'.format(expected_result))
                    print('Реальный результат: {}'.format(actual_result))
            finally:
                test_sales_by_city.teardown(cr)


if __name__ == '__main__':
    main()

