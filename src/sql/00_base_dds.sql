-- Выполняется после загрузки users, groups и dialogs на чистом стенде.
CREATE TABLE IF NOT EXISTS VT261117917969__DWH.h_users (
    hk_user_id INT NOT NULL PRIMARY KEY,
    user_id INT NOT NULL
);

CREATE TABLE IF NOT EXISTS VT261117917969__DWH.h_groups (
    hk_group_id INT NOT NULL PRIMARY KEY,
    group_id INT NOT NULL,
    registration_dt TIMESTAMP(6)
);

INSERT INTO VT261117917969__DWH.h_users (hk_user_id, user_id)
SELECT DISTINCT HASH(u.id), u.id
FROM VT261117917969__STAGING.users AS u
WHERE NOT EXISTS (
    SELECT 1 FROM VT261117917969__DWH.h_users AS h WHERE h.user_id = u.id
);

INSERT INTO VT261117917969__DWH.h_groups (hk_group_id, group_id, registration_dt)
SELECT HASH(g.id), g.id, MIN(g.registration_dt)
FROM VT261117917969__STAGING.groups AS g
WHERE NOT EXISTS (
    SELECT 1 FROM VT261117917969__DWH.h_groups AS h WHERE h.group_id = g.id
)
GROUP BY g.id;

CREATE TABLE IF NOT EXISTS VT261117917969__DWH.l_groups_dialogs AS
SELECT DISTINCT g.hk_group_id, HASH(d.message_id) AS hk_message_id
FROM VT261117917969__STAGING.dialogs AS d
JOIN VT261117917969__DWH.h_groups AS g ON g.group_id = d.message_group;

CREATE TABLE IF NOT EXISTS VT261117917969__DWH.l_user_message AS
SELECT DISTINCT u.hk_user_id, HASH(d.message_id) AS hk_message_id
FROM VT261117917969__STAGING.dialogs AS d
JOIN VT261117917969__DWH.h_users AS u ON u.user_id = d.message_from;
