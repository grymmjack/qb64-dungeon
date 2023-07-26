TYPE SECTOR
    start_x AS INTEGER
    start_y AS INTEGER
    end_x   AS INTEGER
    end_y   AS INTEGER
    w       AS INTEGER
    h       AS INTEGER
    kolor   AS _UNSIGNED LONG
    label   AS STRING
END TYPE
DIM SHARED SECTORS(1 TO 9) AS SECTOR