/*
Для каждого дня в таблице orders рассчитайте следующие показатели:

Выручку, полученную в этот день.
Суммарную выручку на текущий день.
Прирост выручки, полученной в этот день, относительно значения выручки за предыдущий день.
*/

SELECT 
    dt,
    revenue,
    SUM(revenue) OVER (ORDER BY dt) AS total_revenue,
    ROUND(100 * (revenue - LAG(revenue, 1) OVER (ORDER BY dt)) :: DECIMAL / LAG(revenue, 1) OVER (ORDER BY dt), 2) AS revenue_change
FROM   
    (
    SELECT 
        creation_time :: DATE as dt,
               SUM(price) AS revenue
    FROM   
        (
        SELECT 
            creation_time,
            UNNEST(product_ids) AS product_id
        FROM
            orders
        WHERE
            order_id NOT IN 
                (
                SELECT
                    order_id
                FROM
                    user_actions
                WHERE
                    action = 'cancel_order'
                )
        ) AS t1
    LEFT JOIN
        products
    USING
        (product_id)
    GROUP BY
        dt
    ) AS t2

/*
Теперь на основе данных о выручке рассчитаем несколько относительных показателей, которые покажут, 
сколько в среднем потребители готовы платить за услуги нашего сервиса доставки. 

Остановимся на следующих метриках:
1. ARPU 
2. ARPPU
3. AOV 
*/

SELECT 
    dt,
    ROUND(revenue :: DECIMAL / users, 2) AS arpu,
    ROUND(revenue :: DECIMAL / paying_users, 2) AS arppu,
    ROUND(revenue :: DECIMAL / orders, 2) AS aov
FROM   
    (
    SELECT 
        creation_time :: DATE AS dt,
        COUNT(DISTINCT order_id) AS orders,
        SUM(price) AS revenue
    FROM   
        (
        SELECT 
            order_id,
            creation_time,
            UNNEST(product_ids) AS product_id
        FROM   
            orders
        WHERE  
            order_id NOT IN 
                (
                SELECT 
                    order_id
                FROM   
                    user_actions
                WHERE  
                    action = 'cancel_order'
                )
        ) AS t1
    LEFT JOIN 
        products
    USING
        (product_id)
    GROUP BY
        dt
    ) AS t2
LEFT JOIN 
    (
    SELECT 
        time :: DATE AS dt,
        COUNT(DISTINCT user_id) AS users
    FROM   
        user_actions
    GROUP BY
        dt
    ) AS t3 
USING 
    (dt)
LEFT JOIN
    (
    SELECT 
        time :: DATE AS dt,
        COUNT(DISTINCT user_id) AS paying_users
    FROM   
        user_actions
    WHERE  
        order_id NOT IN 
            (
            SELECT 
                order_id
            FROM
                user_actions
            WHERE  
                action = 'cancel_order'
            )
    GROUP BY 
        dt
    ) AS t4 
USING 
    (dt)
ORDER BY 
    dt

/*
По таблицам orders и user_actions для каждого дня рассчитайте следующие показатели:

Накопленную выручку на пользователя (Running ARPU).
Накопленную выручку на платящего пользователя (Running ARPPU).
Накопленную выручку с заказа, или средний чек (Running AOV).
*/

SELECT 
    dt,
    ROUND(SUM(revenue) OVER (ORDER BY dt) :: DECIMAL / SUM(new_users) OVER (ORDER BY dt), 2) AS running_arpu,
    ROUND(SUM(revenue) OVER (ORDER BY dt) :: DECIMAL / SUM(new_paying_users) OVER (ORDER BY dt), 2) AS running_arppu,
    ROUND(SUM(revenue) OVER (ORDER BY dt) :: DECIMAL / SUM(orders) OVER (ORDER BY dt), 2) AS running_aov
FROM  
    (
    SELECT
        creation_time :: DATE AS dt,
        COUNT(DISTINCT order_id) AS orders,
        SUM(price) AS revenue
    FROM
        (
        SELECT
            order_id,
            creation_time,
            UNNEST(product_ids) AS product_id
        FROM
            orders
        WHERE  
            order_id NOT IN 
                (
                SELECT
                    order_id
                FROM
                    user_actions
                WHERE
                    action = 'cancel_order'
                )
        ) AS t1
    LEFT JOIN 
        products 
    USING
        (product_id)
    GROUP BY
        dt
    ) AS t2
LEFT JOIN
    (
    SELECT
        time :: DATE AS dt,
        COUNT(DISTINCT user_id) AS users
    FROM   
        user_actions
    GROUP BY
        dt
    ) AS t3 
USING 
    (dt)
LEFT JOIN
    (
    SELECT 
        time :: DATE AS dt,
        COUNT(DISTINCT user_id) AS paying_users
    FROM
        user_actions
    WHERE  
        order_id NOT IN 
            (
            SELECT
                order_id
            FROM
                user_actions
            WHERE
                action = 'cancel_order'
            )
    GROUP BY
        dt
    ) AS t4
USING 
    (dt)
LEFT JOIN 
    (
    SELECT
        dt,
        COUNT(user_id) AS new_users
    FROM
        (
        SELECT
            user_id,
            MIN(time :: DATE) AS dt
        FROM
            user_actions
        GROUP BY
            user_id
        ) AS t5
    GROUP BY
        dt
    ) AS t6
USING 
    (dt)
LEFT JOIN 
    (
    SELECT 
        dt,
        COUNT(user_id) AS new_paying_users
    FROM
        (
        SELECT
            user_id,
            MIN(time :: DATE) AS dt
        FROM   
            user_actions
        WHERE
            order_id NOT IN 
                (
                SELECT
                    order_id
                FROM
                    user_actions
                WHERE
                    action = 'cancel_order'
                )
        GROUP BY
            user_id
        ) AS t7
    GROUP BY
        dt
    ) AS t8 
USING 
    (dt)

/* Для каждого дня недели в таблицах orders и user_actions рассчитайте следующие показатели:

Выручку на пользователя (ARPU).
Выручку на платящего пользователя (ARPPU).
Выручку на заказ (AOV). */

SELECT 
    weekday,
    t1.weekday_number AS weekday_number,
    ROUND(revenue :: DECIMAL / users, 2) AS arpu,
    ROUND(revenue :: DECIMAL / paying_users, 2) AS arppu,
    ROUND(revenue :: DECIMAL / orders, 2) AS aov
FROM
    (
    SELECT
        TO_CHAR(creation_time, 'Day') AS weekday,
        MAX(DATE_PART('isodow', creation_time)) AS weekday_number,
        COUNT(DISTINCT order_id) AS orders,
        SUM(price) AS revenue
    FROM
        (
        SELECT
            order_id,
            creation_time,
            UNNEST(product_ids) AS product_id
        FROM
            orders
        WHERE
            order_id NOT IN 
                (
                SELECT
                    order_id
                FROM
                    user_actions
                WHERE
                    action = 'cancel_order'
                )
            AND 
                creation_time >= '2022-08-26'
            AND creation_time < '2022-09-09'
        ) AS t4
    LEFT JOIN
        products 
    USING 
        (product_id)
    GROUP BY 
        weekday
    ) AS t1
LEFT JOIN
    (
    SELECT
        TO_CHAR(time, 'Day') AS weekday,
        MAX(DATE_PART('isodow', time)) AS weekday_number,
        COUNT(DISTINCT user_id) AS users
    FROM
        user_actions
    WHERE
        time >= '2022-08-26'
        and time < '2022-09-09'
    GROUP BY
        weekday
    ) AS t2 
USING 
    (weekday)
LEFT JOIN 
    (
    SELECT 
        TO_CHAR(time, 'Day') AS weekday,
        MAX(DATE_PART('isodow', time)) AS weekday_number,
        COUNT(DISTINCT user_id) AS paying_users
    FROM
        user_actions
    WHERE  
        order_id NOT IN 
            (
            SELECT
                order_id
            FROM
                user_actions
            WHERE  
                action = 'cancel_order'
            )
        AND time >= '2022-08-26'
        AND time < '2022-09-09'
    GROUP BY
        weekday
    ) AS t3
USING 
    (weekday)
ORDER BY 
    weekday_number

/*
Для каждого дня в таблицах orders и user_actions рассчитайте следующие показатели:

Выручку, полученную в этот день.
Выручку с заказов новых пользователей, полученную в этот день.
Долю выручки с заказов новых пользователей в общей выручке, полученной за этот день.
Долю выручки с заказов остальных пользователей в общей выручке, полученной за этот день.
*/

SELECT 
    dt,
    revenue,
    new_users_revenue,
    ROUND(new_users_revenue / revenue * 100, 2) AS new_users_revenue_share,
    100 - ROUND(new_users_revenue / revenue * 100, 2) AS old_users_revenue_share
FROM
    (
    SELECT
        creation_time :: DATE AS dt,
        SUM(price) AS revenue
    FROM
        (
        SELECT
            order_id,
            creation_time,
            UNNEST(product_ids) AS product_id
        FROM
            orders
        WHERE
            order_id NOT IN 
                (
                SELECT
                    order_id
                FROM
                    user_actions
                WHERE
                    action = 'cancel_order'
                )
        ) AS t3
    LEFT JOIN
        products
    USING 
        (product_id)
    GROUP BY
        dt
    ) AS t1
LEFT JOIN
    (
    SELECT 
        start_date AS dt,
        SUM(revenue) AS new_users_revenue
    FROM
        (
        SELECT
            t5.user_id,
            t5.start_date,
            COALESCE(t6.revenue, 0) AS revenue
        FROM
            (
            SELECT
                user_id,
                MIN(time :: DATE) AS start_date
            FROM 
                user_actions
            GROUP BY
                user_id
            ) AS t5
        LEFT JOIN
            (
            SELECT
                user_id,
                dt,
                SUM(order_price) AS revenue
            FROM
                (
                SELECT
                    user_id,
                    time :: DATE AS dt,
                    order_id
                FROM
                    user_actions
                WHERE
                    order_id NOT IN 
                        (
                        SELECT
                            order_id
                        FROM
                            user_actions
                        WHERE
                            action = 'cancel_order'
                        )
                ) AS t7
            LEFT JOIN 
                (
                SELECT
                    order_id,
                    SUM(price) AS order_price
                FROM
                    (
                    SELECT
                        order_id,
                        UNNEST(product_ids) AS product_id
                    FROM
                        orders
                    WHERE
                        order_id NOT IN 
                            (
                            SELECT
                                order_id
                            FROM
                                user_actions
                            WHERE
                                action = 'cancel_order'
                            )
                    ) AS t9
                LEFT JOIN
                    products
                USING 
                    (product_id)
                GROUP BY 
                    order_id
                ) AS t8 
            USING 
                (order_id)
            GROUP BY 
                user_id, 
                dt
            ) AS t6
        ON 
            t5.user_id = t6.user_id 
            AND t5.start_date = t6.dt
        ) AS t4
    GROUP BY 
        start_date
    ) AS t2
USING 
    (dt)

/*
Для каждого товара, представленного в таблице products, за весь период времени в таблице orders рассчитайте следующие показатели:

Суммарную выручку, полученную от продажи этого товара за весь период.
Долю выручки от продажи этого товара в общей выручке, полученной за весь период.

Товары, округлённая доля которых в выручке составляет менее 0.5%, объедините в общую группу с названием «ДРУГОЕ».
*/

SELECT 
    product_name,
    SUM(revenue) AS revenue,
    SUM(share_in_revenue) AS share_in_revenue
FROM
    (
    SELECT
        CASE 
            WHEN ROUND(100 * revenue / SUM(revenue) OVER (), 2) >= 0.5 THEN name
            ELSE 'ДРУГОЕ' 
        END AS product_name,
        revenue,
        ROUND(100 * revenue / SUM(revenue) OVER (), 2) AS share_in_revenue
    FROM   
        (
        SELECT
            name,
            SUM(price) AS revenue
        FROM   
            (
            SELECT
                order_id,
                UNNEST(product_ids) AS product_id
            FROM
                orders
            WHERE
                order_id NOT IN 
                    (
                    SELECT
                        order_id
                    FROM
                        user_actions
                    WHERE
                        action = 'cancel_order'
                    )
            ) AS t1
        LEFT JOIN
            products
        USING
            (product_id)
        GROUP BY
            name
        ) AS t2
    ) AS t3
GROUP BY 
    product_name
ORDER BY 
    revenue DESC

/*
Для каждого дня в таблицах orders и courier_actions рассчитайте следующие показатели:

Выручку, полученную в этот день.
Затраты, образовавшиеся в этот день.
Сумму НДС с продажи товаров в этот день.
Валовую прибыль в этот день (выручка за вычетом затрат и НДС).
Суммарную выручку на текущий день.
Суммарные затраты на текущий день.
Суммарный НДС на текущий день.
Суммарную валовую прибыль на текущий день.
Долю валовой прибыли в выручке за этот день (долю п.4 в п.1).
Долю суммарной валовой прибыли в суммарной выручке на текущий день (долю п.8 в п.5).
*/

SELECT 
    dt,
    revenue,
    costs,
    tax,
    gross_profit,
    total_revenue,
    total_costs,
    total_tax,
    total_gross_profit,
    ROUND(gross_profit / revenue * 100, 2) AS gross_profit_ratio,
    ROUND(total_gross_profit / total_revenue * 100, 2) AS total_gross_profit_ratio
FROM
    (
    SELECT
        dt,
        revenue,
        costs,
        tax,
        revenue - costs - tax AS gross_profit,
        SUM(revenue) OVER (ORDER BY dt) AS total_revenue,
        SUM(costs) OVER (ORDER BY dt) AS total_costs,
        SUM(tax) OVER (ORDER BY dt) AS total_tax,
        SUM(revenue - costs - tax) OVER (ORDER BY dt) AS total_gross_profit
    FROM
        (
        SELECT
            dt,
            orders_packed,
            orders_delivered,
            couriers_count,
            revenue,
            CASE 
                WHEN DATE_PART('month', dt) = 8 THEN 120000.0 + 140 * COALESCE(orders_packed, 0) + 150 * COALESCE(orders_delivered, 0) + 400 * COALESCE(couriers_count, 0)
                WHEN DATE_PART('month', dt) = 9 THEN 150000.0 + 115 * COALESCE(orders_packed, 0) + 150 * COALESCE(orders_delivered, 0) + 500 * COALESCE(couriers_count, 0) 
            END AS costs,
            tax
        FROM
            (
            SELECT
                creation_time :: DATE AS dt,
                COUNT(DISTINCT order_id) AS orders_packed,
                SUM(price) AS revenue,
                SUM(tax) AS tax
            FROM
                (
                SELECT
                    order_id,
                    creation_time,
                    product_id,
                    name,
                    price,
                    CASE 
                        WHEN name IN ('сахар', 'сухарики', 'сушки', 'семечки', 'масло льняное', 'виноград', 'масло оливковое', 'арбуз', 'батон', 'йогурт', 'сливки', 'гречка', 'овсянка', 'макароны', 'баранина', 'апельсины', 'бублики', 'хлеб', 'горох', 'сметана', 'рыба копченая', 'мука', 'шпроты', 'сосиски', 'свинина', 'рис', 'масло кунжутное', 'сгущенка', 'ананас', 'говядина', 'соль', 'рыба вяленая', 'масло подсолнечное', 'яблоки', 'груши', 'лепешка', 'молоко', 'курица', 'лаваш', 'вафли', 'мандарины') THEN ROUND(price/110*10, 2)
                        ELSE ROUND(price/120*20, 2) 
                    END AS tax
                FROM
                    (
                    SELECT
                        order_id,
                        creation_time,
                        UNNEST(product_ids) AS product_id
                    FROM
                        orders
                    WHERE
                        order_id NOT IN 
                            (
                            SELECT
                                order_id
                            FROM
                                user_actions
                            WHERE
                                action = 'cancel_order'
                            )
                    ) AS t1
                LEFT JOIN
                    products
                USING
                    (product_id)
                ) AS t2
            GROUP BY
                dt
            ) AS t3
        LEFT JOIN
            (  
            SELECT
                time :: DATE AS dt,
                COUNT(DISTINCT order_id) AS orders_delivered
            FROM
                courier_actions
            WHERE 
                order_id NOT IN
                    (
                    SELECT
                        order_id
                    FROM
                        user_actions
                    WHERE
                        action = 'cancel_order')
                AND action = 'deliver_order'
            GROUP BY
                dt
            ) AS t4 
        USING
            (dt)
        LEFT JOIN 
            (
            SELECT
                dt,
                COUNT(courier_id) AS couriers_count
            FROM
                (
                SELECT
                    time :: DATE AS dt,
                    courier_id,
                    COUNT(DISTINCT order_id) AS orders_delivered
                FROM
                    courier_actions
                WHERE
                    order_id NOT IN
                        (
                        SELECT
                            order_id
                        FROM
                            user_actions
                        WHERE
                            action = 'cancel_order'
                        )
                    AND action = 'deliver_order'
                GROUP BY
                    dt,
                    courier_id 
                HAVING 
                    COUNT(DISTINCT order_id) >= 5
                ) AS t5
            GROUP BY
                dt
            ) AS t6
        USING
            (dt)
        ) AS t7
    ) AS t8