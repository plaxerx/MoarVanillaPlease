-- Default mod config, merged from every component. One SMODS config table serves the
-- whole bundle, so no two components may use the same key.
return {
    -- Pinochle
    peek_mode = 1,    -- 1 always off, 2 endless and seeded runs only, 3 always on
    peek_depth = 5,   -- number of future rerolls to look ahead

    -- MoarThemesPlease
    -- The theme in use, as a share code: its name plus every color it changes from Standard.
    -- Empty is Standard.
    active = '',

    -- Show every color group in the Themes menu instead of the nineteen Basic colors.
    advanced = false,

    -- MoarStatsPlease
    -- Add the Stats tab to the in-run Run Info overlay.
    run_tab = true,

    -- Add the extra rows to the Game Over / win screen.
    game_over_rows = true,

    -- Keep a record of every finished run. Off keeps only the aggregate counters.
    run_log = true,

    -- Hard cap on stored run records; the oldest are dropped past this. 0 = unlimited.
    run_log_max = 0,
}
