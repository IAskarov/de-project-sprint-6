-- Сверьте эти значения с логом задачи load_group_log.
SELECT event, COUNT(*) AS rows_in_staging
FROM VT261117917969__STAGING.group_log
GROUP BY event
ORDER BY event;

-- Ненулевые значения означают, что часть строк не сопоставилась с хабами.
SELECT COUNT(*) AS unmatched_rows
FROM VT261117917969__STAGING.group_log AS gl
LEFT JOIN VT261117917969__DWH.h_users AS u ON u.user_id = gl.user_id
LEFT JOIN VT261117917969__DWH.h_groups AS g ON g.group_id = gl.group_id
WHERE u.hk_user_id IS NULL OR g.hk_group_id IS NULL;

-- Выполните дважды, до и после повторного запуска 02_load_dds.sql.
SELECT event, COUNT(*) AS rows_in_dds
FROM VT261117917969__DWH.s_auth_history
WHERE load_src = 'group_log'
GROUP BY event
ORDER BY event;

-- Сравните с числом событий в DDS по каждому типу.
SELECT event, COUNT(*) AS unique_events
FROM (
    SELECT DISTINCT group_id, user_id, user_id_from, event, event_dt
    FROM VT261117917969__STAGING.group_log
) AS events
GROUP BY event
ORDER BY event;
