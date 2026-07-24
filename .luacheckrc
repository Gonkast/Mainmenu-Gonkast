std = "lua51"
max_line_length = false

-- La API de WoW expone miles de globals (CreateFrame, GameMenuFrame, Settings,
-- etc.) que luacheck no conoce de fabrica. Se ignora el warning de LECTURA de
-- variable no declarada (113) -- son, casi siempre, llamadas legitimas a la
-- API de Blizzard. Se dejan ACTIVOS los de ESCRITURA (111/112): olvidarse el
-- `local` y filtrar una variable al scope global SI es un bug real que vale
-- la pena pescar.
ignore = {
    "113",
}

-- Globals que este addon SI escribe/muta a proposito: GameMenuFrame (le
-- colgamos campos propios __gonk* encima del frame nativo de Blizzard),
-- SavedVariables y los slash commands.
globals = {
    "GameMenuFrame",
    "MainmenuGonkastDB",
    "SlashCmdList",
    "SLASH_MAINMENUGONKAST1",
}

exclude_files = {
    "backup/**",
}
