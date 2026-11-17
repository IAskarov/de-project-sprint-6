
INSERT INTO VT261117917969__DWH.l_user_group_activity (
    hk_l_user_group_activity, hk_user_id, hk_group_id, load_dt, load_src
)
SELECT DISTINCT
    HASH(hu.hk_user_id, hg.hk_group_id),
    hu.hk_user_id,
    hg.hk_group_id,
    CURRENT_TIMESTAMP,
    'group_log'
FROM VT261117917969__STAGING.group_log AS gl
JOIN VT261117917969__DWH.h_users AS hu ON hu.user_id = gl.user_id
JOIN VT261117917969__DWH.h_groups AS hg ON hg.group_id = gl.group_id
WHERE NOT EXISTS (
    SELECT 1
    FROM VT261117917969__DWH.l_user_group_activity AS existing
    WHERE existing.hk_user_id = hu.hk_user_id
      AND existing.hk_group_id = hg.hk_group_id
);

INSERT INTO VT261117917969__DWH.s_auth_history (
    hk_l_user_group_activity, user_id_from, event, event_dt, load_dt, load_src
)
SELECT DISTINCT
    activity.hk_l_user_group_activity,
    gl.user_id_from,
    gl.event,
    gl.event_dt,
    CURRENT_TIMESTAMP,
    'group_log'
FROM VT261117917969__STAGING.group_log AS gl
JOIN VT261117917969__DWH.h_users AS hu ON hu.user_id = gl.user_id
JOIN VT261117917969__DWH.h_groups AS hg ON hg.group_id = gl.group_id
JOIN VT261117917969__DWH.l_user_group_activity AS activity
    ON activity.hk_user_id = hu.hk_user_id AND activity.hk_group_id = hg.hk_group_id
LEFT JOIN VT261117917969__DWH.s_auth_history AS existing
    ON existing.hk_l_user_group_activity = activity.hk_l_user_group_activity
   AND existing.event = gl.event
   AND existing.event_dt = gl.event_dt
   AND (existing.user_id_from = gl.user_id_from
        OR (existing.user_id_from IS NULL AND gl.user_id_from IS NULL))
WHERE existing.hk_l_user_group_activity IS NULL;

