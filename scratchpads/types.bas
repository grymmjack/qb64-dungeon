'$INCLUDE:'const.bas'

TYPE POSITION
    x AS INTEGER
    y AS INTEGER
END TYPE

TYPE GRID
    columns         AS INTEGER
    rows            AS INTEGER
    odd_char        AS STRING
    even_char       AS STRING
    odd_char_color  AS LONG
    even_char_color AS LONG
END TYPE

TYPE LAYER
    filename AS STRING
    handle   AS LONG
    label    AS STRING
    pos      AS POSITION
    opacity  AS LONG
    visible  AS _UNSIGNED INTEGER
    width    AS INTEGER
    height   AS INTEGER
END TYPE

TYPE BOARD
    grid       AS GRID
    img_grid   AS LONG
    img_tokens AS LONG
    img_rooms  AS LONG
    img_paths  AS LONG
    img_scene  AS LONG
END TYPE

TYPE TOKEN
    pos      AS POSITION
    bg_color AS _UNSIGNED LONG
    fg_color AS _UNSIGNED LONG
    char     AS STRING
END TYPE

TYPE ENUM
    index AS INTEGER
    label AS STRING
END TYPE

TYPE CARD
    name AS STRING
    type AS INTEGER
END TYPE

TYPE TREASURE_CARD
    name       AS STRING
    gold_value AS INTEGER
    img_face   AS LONG
END TYPE

TYPE PLAYER
    index AS INTEGER
    piece AS TOKEN
    gold  AS INTEGER
    name  AS STRING
END TYPE

DIM CARD_TYPES(0 TO 3) AS ENUM
CARD_TYPES(0).index = 0
CARD_TYPES(0).label = "Treasure"
CARD_TYPES(1).index = 1
CARD_TYPES(1).label = "Monster"
CARD_TYPES(2).index = 2
CARD_TYPES(2).label = "Spell"

DIM MARKERS(0 TO 3) AS ENUM
MARKERS(0).index = 0
MARKERS(0).label = "Skull"
MARKERS(1).index = 0
MARKERS(1).label = "Trap"
