CREATE TABLE IF NOT EXISTS VT261117917969__STAGING.group_log (
    group_id INT NOT NULL,
    user_id INT NOT NULL,
    user_id_from INT,
    event VARCHAR(10) NOT NULL,
    event_dt TIMESTAMP(6) NOT NULL
);

CREATE TABLE IF NOT EXISTS VT261117917969__DWH.l_user_group_activity (
    hk_l_user_group_activity INT NOT NULL,
    hk_user_id INT NOT NULL,
    hk_group_id INT NOT NULL,
    load_dt TIMESTAMP NOT NULL,
    load_src VARCHAR(20) NOT NULL,
    PRIMARY KEY (hk_l_user_group_activity),
    FOREIGN KEY (hk_user_id) REFERENCES VT261117917969__DWH.h_users(hk_user_id),
    FOREIGN KEY (hk_group_id) REFERENCES VT261117917969__DWH.h_groups(hk_group_id)
);

CREATE TABLE IF NOT EXISTS VT261117917969__DWH.s_auth_history (
    hk_l_user_group_activity INT NOT NULL,
    user_id_from INT,
    event VARCHAR(10) NOT NULL,
    event_dt TIMESTAMP(6) NOT NULL,
    load_dt TIMESTAMP NOT NULL,
    load_src VARCHAR(20) NOT NULL,
    FOREIGN KEY (hk_l_user_group_activity)
        REFERENCES VT261117917969__DWH.l_user_group_activity(hk_l_user_group_activity)
);
