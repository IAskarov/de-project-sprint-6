WITH oldest_groups AS (
    SELECT group_id, hk_group_id
    FROM VT261117917969__DWH.h_groups
    WHERE registration_dt IS NOT NULL
    ORDER BY registration_dt, hk_group_id
    LIMIT 10
),
joined_users AS (
    SELECT DISTINCT activity.hk_group_id, activity.hk_user_id
    FROM oldest_groups AS groups
    JOIN VT261117917969__DWH.l_user_group_activity AS activity
        ON activity.hk_group_id = groups.hk_group_id
    JOIN VT261117917969__DWH.s_auth_history AS history
        ON history.hk_l_user_group_activity = activity.hk_l_user_group_activity
    WHERE history.event = 'add'
),
user_group_messages AS (
    SELECT gd.hk_group_id, COUNT(DISTINCT authors.hk_user_id) AS cnt_users_in_group_with_messages
    FROM VT261117917969__DWH.l_groups_dialogs AS gd
    JOIN VT261117917969__DWH.l_user_message AS authors ON authors.hk_message_id = gd.hk_message_id
    JOIN joined_users AS members
        ON members.hk_group_id = gd.hk_group_id
       AND members.hk_user_id = authors.hk_user_id
    GROUP BY gd.hk_group_id
),
user_group_log AS (
    SELECT groups.hk_group_id, COUNT(members.hk_user_id) AS cnt_added_users
    FROM oldest_groups AS groups
    LEFT JOIN joined_users AS members ON members.hk_group_id = groups.hk_group_id
    GROUP BY groups.hk_group_id
)
SELECT
    g.group_id,
    ugl.hk_group_id,
    ugl.cnt_added_users,
    COALESCE(ugm.cnt_users_in_group_with_messages, 0) AS cnt_users_in_group_with_messages,
    CAST(COALESCE(ugm.cnt_users_in_group_with_messages, 0) AS NUMERIC(24, 10))
        / NULLIF(ugl.cnt_added_users, 0) AS group_conversion
FROM user_group_log AS ugl
JOIN oldest_groups AS g ON g.hk_group_id = ugl.hk_group_id
LEFT JOIN user_group_messages AS ugm ON ugm.hk_group_id = ugl.hk_group_id
ORDER BY
    CASE WHEN ugl.cnt_added_users = 0 THEN 1 ELSE 0 END,
    group_conversion DESC,
    ugl.hk_group_id;
