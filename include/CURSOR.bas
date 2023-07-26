TYPE CURSOR
    x              AS INTEGER
    y              AS INTEGER
    prev_x         AS INTEGER
    prev_y         AS INTEGER
    cursor_color   AS _UNSIGNED LONG
    in_sector      AS INTEGER
    in_room        AS INTEGER
    on_path        AS INTEGER
    on_door        AS INTEGER
    on_secret_door AS INTEGER
END TYPE
DIM SHARED CURSOR AS CURSOR