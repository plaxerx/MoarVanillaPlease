-- Moar Stats Please - the store. Where numbers live, how they persist, how a run folds into
-- a career.
--
-- TWO SCOPES:
--   run    - G.GAME.mstat. Rides inside the run save, so it survives quit-and-resume and is
--            thrown away with the run. Nothing else needs to persist it.
--   career - G.PROFILES[n].mstat. Per profile, split into two buckets (normal / seeded) so a
--            seeded practice run never pollutes an honest career total. Challenge runs have
--            no bucket: they are tracked at run scope only and never reach the career.
--
-- ONE DIRECTION: everything is written to the RUN, and the run folds into the career at a
-- flush. Nothing is written to both at once. This holds for flat counters, nested tallies,
-- high-water marks and records alike.
--
-- Additive values fold by DELTA - the run's value minus the last flushed snapshot - and the
-- snapshot rides in the run save alongside the values, so loading a save mid-run and playing
-- on cannot double-count what was already banked. Maxima fold by being OFFERED: a high-water
-- mark needs no snapshot, because offering the same value twice changes nothing.
--
-- The only direct career writes are the counters a run cannot own: runs_started, runs_won,
-- runs_lost, runs_abandoned and the streak state.

MSP.VERSION = 3

local DOUBLE_MAX = 1.7976931348623157e308

--============================================================
-- Bucket
--============================================================
MSP.BUCKETS = {
    { id = 'normal', label = 'Normal' },
    { id = 'seeded', label = 'Seeded' },
}

-- Which career bucket the run in progress belongs to, or nil for a run that does not belong
-- in the career at all.
--
-- Challenge runs return nil: they are still tracked at RUN scope, so the Run Info tab works
-- normally while you play one, but nothing folds into a career bucket. Every career write
-- already guards on a nil bucket, so this one return does the whole job.
function MSP.bucket_id()
    local g = G.GAME
    if not g then return 'normal' end
    if g.challenge then return nil end
    if g.seeded then return 'seeded' end
    return 'normal'
end

--============================================================
-- Phase
--============================================================
-- Base game versus Endless. The boundary is the run's OWN win ante, never a hard-coded 8: a
-- challenge, a deck or a mod can move it, and vanilla itself tests
-- `round_resets.ante <= win_ante` (game.lua:3790).
--
-- Cached rather than recomputed. MSP.tally sits on the Joker trigger hot path, where this
-- would otherwise be three table hops per call; the sampler refreshes it far more often than
-- an ante can turn over.
MSP.PHASES = {
    { id = 'all',     label = 'All' },
    { id = 'base',    label = 'Ante 8' },
    { id = 'endless', label = 'Endless' },
}

MSP.endless = false

function MSP.refresh_phase()
    local g = G and G.GAME
    MSP.endless = not not (g and g.round_resets and g.win_ante
        and MSP.num(g.round_resets.ante) > MSP.num(g.win_ante))
end

-- Suffix the endless copy of an additive field carries. Base-game figures are not stored:
-- they are the total less the endless part, which keeps one number per field instead of two
-- and leaves every pre-split profile reading correctly as all-base.
local ENDLESS = '_endless'

--============================================================
-- Career store
--============================================================
local function new_bucket()
    return { t = {}, records = {}, groups = {} }
end

-- Stake key for a ladder position. Exposed on MSP because the migrations need it and they
-- run before the run-lifecycle section is reached.
function MSP.stake_key_for(index)
    if SMODS and SMODS.stake_from_index then
        local ok, k = pcall(SMODS.stake_from_index, index)
        if ok and k then return k end
    end
    local center = G.P_CENTER_POOLS and G.P_CENTER_POOLS.Stake and G.P_CENTER_POOLS.Stake[index]
    return center and center.key or nil
end

--============================================================
-- Migration
--============================================================
-- THE CONTRACT, for every version after this one:
--
--   * Stored data is never deleted. Not a bucket, not a group, not a counter. A key this
--     version no longer writes stays exactly where it is, so a profile that has been through
--     a newer build and back does not lose what that build recorded.
--   * Stat keys are never renamed or repurposed. Renaming loses the history behind the old
--     name. Add a new key and leave the old one to sit.
--   * New fields are additive and must read correctly as absent - MSP.num turns a missing
--     counter into 0, so a fresh stat simply starts from zero on an old profile.
--   * A store stamped NEWER than this build is left completely alone. A downgrade must not
--     rewrite a format it does not understand.
--
-- Anything that cannot be expressed additively - a change of key SHAPE, as in v2 - gets a
-- migration below, which rewrites in place rather than starting over.

-- Rebuilds a group under new keys, merging where two old keys map onto one new one.
local function remap_group(g, to_new)
    if type(g) ~= 'table' then return end
    local moves = {}
    for k in pairs(g) do
        local nk = to_new(k)
        if nk and nk ~= k then moves[#moves + 1] = { k, nk } end
    end
    for _, m in ipairs(moves) do
        local old, new = m[1], m[2]
        local src, dst = g[old], g[new]
        g[old] = nil
        if not dst then
            g[new] = src
        else
            for f, v in pairs(src) do
                if f:sub(-4) == '_log' then
                    local base = f:sub(1, -5)
                    if not dst[f] or v > dst[f] then
                        dst[f] = v
                        dst[base .. '_str'] = src[base .. '_str']
                        dst[base .. '_num'] = src[base .. '_num']
                    end
                elseif not MSP.is_mag_field(f) then
                    dst[f] = (dst[f] or 0) + v
                end
            end
        end
    end
end

-- Each entry upgrades a store from version n-1 to version n.
local MIGRATIONS = {
    -- v1 keyed stakes by their POSITION in G.P_CENTER_POOLS.Stake. That position moves the
    -- moment a stake mod is added or removed, which silently reassigns results to the wrong
    -- stake. v2 keys them by the stake's own key. Anything that still looks like an index is
    -- remapped; anything already a key is left alone, so this is safe to re-run.
    [2] = function(st)
        local function key_for(part)
            if not part:match('^%d+$') then return nil end
            return MSP.stake_key_for(tonumber(part))
        end

        for _, bucket in pairs(st.buckets or {}) do
            local g = bucket.groups or {}
            remap_group(g.stakes, key_for)

            -- Matrix keys carry the stake in the last @-separated part.
            for _, gid in ipairs({ 'deck_stakes', 'sleeve_stakes', 'combo_stakes' }) do
                remap_group(g[gid], function(k)
                    local head, tail = k:match('^(.*)@([^@]+)$')
                    if not head then return nil end
                    local nk = key_for(tail)
                    return nk and (head .. '@' .. nk) or nil
                end)
            end
        end

        for _, rec in ipairs(st.runs or {}) do
            if not rec.stake_key and rec.stake then
                rec.stake_key = MSP.stake_key_for(MSP.num(rec.stake, 1))
            end
        end
    end,

    -- v1 and v2 read a hand's score from G.GAME.current_round.current_hand AFTER
    -- G.FUNCS.evaluate_play returned. Those fields are driven by queued events, so that read
    -- landed on mid-animation state, not the final score. v3 reads
    -- SMODS.calculate_round_score() inside evaluate_play_after, which is the same value
    -- vanilla passes to check_and_set_high_score (state_events.lua:905).
    --
    -- Everything derived from the old read is WRONG rather than merely incomplete, so it is
    -- cleared. This is the one case where dropping stored data is right: keeping it means
    -- keeping a "best hand ever" that was never played. Counts of hands, cards and money are
    -- untouched - only the score-derived figures go.
    --
    -- cards_scored / cards_unscored go too: they were split on card.debuff, which answers a
    -- different question. The cards that do not score in a Pair are not debuffed, they are
    -- simply not part of the hand.
    [3] = function(st)
        local WIPE_RECORDS  = { 'best_hand', 'best_chips', 'best_mult', 'best_overkill' }
        local WIPE_COUNTERS = { 'total_score', 'cards_scored', 'cards_unscored' }

        for _, bucket in pairs(st.buckets or {}) do
            local recs, t = bucket.records or {}, bucket.t or {}
            for _, k in ipairs(WIPE_RECORDS) do recs[k] = nil end
            for _, k in ipairs(WIPE_COUNTERS) do t[k] = nil end

            -- Per-hand best scores were computed the same wrong way. The played counts on
            -- the same entries are correct and stay.
            for _, e in pairs((bucket.groups or {}).hands or {}) do
                e.best_log, e.best_str, e.best_num = nil, nil, nil
            end
        end

        for _, rec in ipairs(st.runs or {}) do rec.best_hand = nil end
    end,
}

-- Brings a store up to MSP.VERSION, in order, once. Reports what it did so a migration that
-- goes wrong is visible rather than silent.
local function migrate(st)
    local from = math.floor(MSP.num(st.v, 1))
    if from >= MSP.VERSION then
        -- Written by this build or a newer one. A newer store is left untouched on purpose:
        -- rewriting a format this build does not understand is how progress gets lost.
        return
    end

    for v = from + 1, MSP.VERSION do
        local step = MIGRATIONS[v]
        if step then
            local ok, err = pcall(step, st)
            if not ok then
                -- Stop at the failed step rather than stamping a version the data has not
                -- reached. The store stays readable and the next launch tries again.
                if sendWarnMessage then
                    sendWarnMessage(('migration to v%d failed: %s'):format(v, tostring(err)), 'MoarVanillaPlease')
                end
                st.v = v - 1
                return
            end
        end
    end
    st.v = MSP.VERSION
end

-- The profile's stat store, created on first touch. Called from UI and hooks alike, so it
-- must tolerate being reached before a profile is loaded.
--
-- The cache is not premature: the Joker trigger hook reaches this on every calculate_joker
-- call, which is thousands of times in a single big hand. Re-walking the bucket list to
-- re-assert tables that already exist would be the most-executed code in the mod.
local cached_owner, cached_store

function MSP.profile()
    if not (G and G.PROFILES and G.SETTINGS and G.PROFILES[G.SETTINGS.profile]) then return nil end
    local p = G.PROFILES[G.SETTINGS.profile]
    if cached_owner == p and cached_store and p.mstat == cached_store then return cached_store end

    if not p.mstat then
        p.mstat = { v = MSP.VERSION, buckets = {}, runs = {} }
    end
    local st = p.mstat
    st.buckets = st.buckets or {}
    st.runs = st.runs or {}

    migrate(st)

    -- Only ever fills in what is missing. Buckets this build no longer uses - the challenge
    -- bucket from before challenges were dropped - are left in place untouched, not cleaned
    -- up: they cost nothing and throwing them away would be throwing away someone's history.
    for _, b in ipairs(MSP.BUCKETS) do
        st.buckets[b.id] = st.buckets[b.id] or new_bucket()
        local bk = st.buckets[b.id]
        bk.t, bk.records, bk.groups = bk.t or {}, bk.records or {}, bk.groups or {}
    end
    cached_owner, cached_store = p, st
    return st
end

-- One career bucket, or nil when the run in progress does not belong to one (a challenge).
-- Every caller already treats nil as "there is nowhere to write", which is what keeps
-- challenge runs out of the career without a single extra branch anywhere else.
function MSP.career(bucket)
    local id = bucket or MSP.bucket_id()
    if not id then return nil end
    local st = MSP.profile()
    if not st then return nil end
    return st.buckets[id]
end

local save_pending = false

-- Profile writes are batched: vanilla saves on every career stat bump, which is fine at its
-- once-a-round cadence and is not at ours. Flush points call this, and it collapses to one
-- write.
function MSP.mark_dirty()
    save_pending = true
end

function MSP.save_now()
    if not save_pending then return end
    save_pending = false
    if G and G.save_settings then pcall(function() G:save_settings() end) end
end

--============================================================
-- Run store
--============================================================
-- The live run's stats. Returns nil outside a run so every caller can bail in one check.
function MSP.run()
    if not G or not G.GAME then return nil end
    local g = G.GAME
    -- Fast path for the same reason MSP.profile caches: this is on the trigger hot path. It
    -- checks every table the writers index, so a store saved by an older version still falls
    -- through to the full init below rather than being handed back half-built.
    local m = g.mstat
    if m and m.t and m.records and m.groups and m.flushed and m.meta then return m end
    if not g.mstat then
        g.mstat = {
            v = MSP.VERSION,
            t = {}, flushed = {}, records = {}, groups = {}, flushed_groups = {},
            meta = {}, time = 0, finished = false,
        }
    end
    local r = g.mstat
    r.t, r.flushed, r.records, r.groups = r.t or {}, r.flushed or {}, r.records or {}, r.groups or {}
    r.flushed_groups, r.meta = r.flushed_groups or {}, r.meta or {}
    return r
end

--============================================================
-- Writing
--============================================================
-- Saturating add. A Talisman-sized total can pass the double ceiling; parking it at the
-- ceiling keeps the number displayable, where inf or NaN would poison every later sum.
local function add(t, key, n)
    local cur = t[key] or 0
    local v = cur + n
    if v ~= v then return end                       -- NaN in, nothing out
    if v > DOUBLE_MAX then v = DOUBLE_MAX end
    if v < -DOUBLE_MAX then v = -DOUBLE_MAX end
    t[key] = v
end

-- Bump a flat counter on the run. Career gets it at the next flush.
function MSP.inc(key, n)
    local r = MSP.run()
    if not r then return end
    add(r.t, key, MSP.num(n == nil and 1 or n))
end

-- Bump a nested tally on the run, e.g.
--   MSP.tally('jokers', 'j_blueprint', 'bought')
--   MSP.tally('suits', 'Hearts', 'played', 3)
-- Group keys come from the game, so a modded suit or Joker lands here without a schema edit.
--
-- This is the hot path - the Joker trigger hook reaches it thousands of times in one big
-- hand - so it does the minimum: three table lookups and an add. The career sees it at the
-- next flush.
function MSP.tally(group, key, field, n)
    local r = MSP.run()
    if not (r and key) then return end
    key, field = tostring(key), field or 'n'

    local g = r.groups[group]
    if not g then
        g = {}
        r.groups[group] = g
    end
    local e = g[key]
    if not e then
        e = {}
        g[key] = e
    end
    local v = MSP.num(n == nil and 1 or n)
    add(e, field, v)
    -- Endless play is also counted under its own field, so the Breakdown can separate the
    -- two without keeping a second copy of every group.
    if MSP.endless then add(e, field .. ENDLESS, v) end
end

-- Record a high-water mark in a nested group instead of a running total. Held as a
-- magnitude, because the things worth a high-water mark - a scaling Joker's X-mult, a hand's
-- score - are exactly the things that outgrow a double.
--
-- `prefix` names the mark, so one key can carry more than one: a poker hand tracks both its
-- best score and its highest level. It becomes the <prefix>_log / _str / _num triple, and
-- the folding code keys off the _log suffix rather than a fixed field name.
function MSP.tally_best(group, key, value, prefix)
    local r = MSP.run()
    if not (r and key) then return end
    local m = MSP.mag(value)
    if m.log <= -1e300 then return end

    local g = r.groups[group]
    if not g then
        g = {}
        r.groups[group] = g
    end
    key = tostring(key)
    local e = g[key]
    if not e then
        e = {}
        g[key] = e
    end
    prefix = prefix or 'best'
    local function put(p)
        local lk, sk, nk = p .. '_log', p .. '_str', p .. '_num'
        if not e[lk] or m.log > e[lk] then
            e[lk], e[sk], e[nk] = m.log, m.str, m.num
        end
    end
    put(prefix)                                                     -- the overall mark
    put(prefix .. (MSP.endless and ENDLESS or '_base'))             -- and its phase
end

--============================================================
-- Reading a group entry for a phase
--============================================================
-- One additive field, for a phase. Endless is stored outright; the base game is whatever is
-- left when endless is taken off the total. A profile written before the split has no endless
-- field at all, so it reads as entirely base game, which is what it was.
function MSP.field_for(entry, field, phase)
    if not entry then return 0 end
    if phase == 'endless' then return MSP.num(entry[field .. ENDLESS]) end
    local total = MSP.num(entry[field])
    if phase == 'base' then return math.max(0, total - MSP.num(entry[field .. ENDLESS])) end
    return total
end

-- One high-water mark, for a phase. Unlike an additive field a maximum cannot be subtracted
-- back out, so each phase keeps its own; `all` takes the best of everything on the entry,
-- including the unsuffixed mark left by versions before the split.
function MSP.mag_for(entry, prefix, phase)
    if not entry then return nil end
    prefix = prefix or 'best'

    local function get(p)
        local l = entry[p .. '_log']
        if l == nil then return nil end
        return { log = l, str = entry[p .. '_str'], num = entry[p .. '_num'] }
    end

    if phase == 'endless' then return get(prefix .. ENDLESS) end
    if phase == 'base' then return get(prefix .. '_base') end

    local best
    for _, p in ipairs({ prefix, prefix .. '_base', prefix .. ENDLESS }) do
        local e = get(p)
        if e and (not best or MSP.num(e.log, -1e300) > MSP.num(best.log, -1e300)) then best = e end
    end
    return best
end

-- True for a field that is part of a magnitude triple rather than an additive count. Folding
-- and display both need to keep these out of their sums.
function MSP.is_mag_field(f)
    return f:sub(-4) == '_log' or f:sub(-4) == '_str' or f:sub(-4) == '_num'
end

-- Read one nested tally field without creating it.
function MSP.tally_get(store, group, key, field)
    local g = store and store.groups and store.groups[group]
    local e = g and g[tostring(key)]
    return e and MSP.num(e[field or 'n']) or 0
end

--============================================================
-- Records
--============================================================
local REC_BY_KEY = {}
for _, r in ipairs(MSP.RECORDS) do REC_BY_KEY[r.key] = r end

-- Offer a value to one of the run's records. Kept as a magnitude so a score past the double
-- ceiling still compares and still displays; see MSP.mag. The career is offered the run's
-- record at the next flush.
function MSP.record(key, value, ctx)
    local def = REC_BY_KEY[key]
    local r = MSP.run()
    if not (def and r) then return end
    local m = MSP.mag(value)
    if m.log <= -1e300 and not def.lowest then return end   -- nothing worth recording

    local cur = r.records[key]
    local better
    if not cur then better = true
    elseif def.lowest then better = (m.log < (cur.log or 1e300))
    else better = (m.log > (cur.log or -1e300)) end
    if not better then return end

    ctx = ctx or {}
    r.records[key] = {
        num = m.num, log = m.log, str = m.str,
        seed = ctx.seed, deck = ctx.deck, stake = ctx.stake, date = ctx.date or MSP.today(),
    }
end

-- Offer a record entry to a career bucket, honouring whether the record wants the highest or
-- the lowest value.
local function offer_record(c, key, entry)
    local def = REC_BY_KEY[key]
    local cur = c.records[key]
    local better
    if not cur then better = true
    elseif def and def.lowest then better = (entry.log or 1e300) < (cur.log or 1e300)
    else better = (entry.log or -1e300) > (cur.log or -1e300) end
    if better then c.records[key] = entry end
end

-- Display text for a stored record entry, respecting its declared format.
function MSP.record_text(def, entry)
    if not entry then return '-' end
    if def.fmt == 'score' then return entry.str or '0' end
    return MSP.format(entry.num or 0, def.fmt)
end

--============================================================
-- Flushing run -> career
--============================================================
-- Nested tallies. Additive fields fold by delta against a mirror of the last flush; the
-- best_* triple is a high-water mark and is simply offered, which needs no mirror.
local function fold_groups(r, c)
    r.flushed_groups = r.flushed_groups or {}
    for gid, g in pairs(r.groups) do
        c.groups[gid] = c.groups[gid] or {}
        r.flushed_groups[gid] = r.flushed_groups[gid] or {}
        local cg, fg = c.groups[gid], r.flushed_groups[gid]

        for key, fields in pairs(g) do
            cg[key] = cg[key] or {}
            fg[key] = fg[key] or {}
            local ce, fe = cg[key], fg[key]

            for f, v in pairs(fields) do
                if f:sub(-4) == '_log' then
                    -- The matching _str and _num belong to this magnitude, so they move with
                    -- it rather than being folded on their own.
                    local base = f:sub(1, -5)
                    if not ce[f] or MSP.num(v) > MSP.num(ce[f]) then
                        ce[f] = v
                        ce[base .. '_str'] = fields[base .. '_str']
                        ce[base .. '_num'] = fields[base .. '_num']
                    end
                elseif not MSP.is_mag_field(f) then
                    local delta = MSP.num(v) - MSP.num(fe[f])
                    if delta ~= 0 then
                        add(ce, f, delta)
                        fe[f] = v
                    end
                end
            end
        end
    end
end

-- Fold everything banked since the last flush into the career bucket. Safe to call often;
-- calling it twice in a row is a no-op.
function MSP.flush(run, career)
    local r = run or MSP.run()
    local c = career or MSP.career(run and run.meta and run.meta.bucket or nil)
    if not (r and c) then return end

    for key, v in pairs(r.t) do
        local delta = MSP.num(v) - MSP.num(r.flushed[key])
        if delta ~= 0 then
            add(c.t, key, delta)
            r.flushed[key] = v
        end
    end

    fold_groups(r, c)
    for key, entry in pairs(r.records) do offer_record(c, key, entry) end

    MSP.mark_dirty()
    MSP.save_now()
end

-- A run left behind rather than finished. Reached from the start_run hook with the previous
-- run's table, once a new run has already taken over G.GAME, so it reads its bucket from the
-- stashed meta and never touches the live game.
function MSP.abandon(r)
    if not r or r.finished then return end
    local c = MSP.career(r.meta and r.meta.bucket)
    if not c then return end
    r.finished = true
    MSP.flush(r, c)
    add(c.t, 'runs_abandoned', 1)
    MSP.mark_dirty()
    MSP.save_now()
end

--============================================================
-- Run lifecycle
--============================================================
-- Identity of the run in progress, stamped once at start so a record's context survives even
-- after the run ends.
function MSP.run_ctx()
    local r = MSP.run()
    local m = r and r.meta or {}
    return { seed = m.seed, deck = m.deck, stake = m.stake, date = MSP.today() }
end

local function deck_key()
    local b = G.GAME and G.GAME.selected_back
    local c = b and b.effect and b.effect.center
    return (c and c.key) or (b and b.name) or '?'
end

-- Stakes are stored by KEY, never by index. G.GAME.stake is a position in
-- G.P_CENTER_POOLS.Stake, and that position moves the moment a stake mod is added or
-- removed - which would silently reassign every stored result to a different stake. This is
-- the same reason SMODS added wins_by_key alongside vanilla's index-keyed deck_usage.wins.
local function stake_key_for(index)
    if SMODS and SMODS.stake_from_index then
        local ok, k = pcall(SMODS.stake_from_index, index)
        if ok and k then return k end
    end
    local center = G.P_CENTER_POOLS and G.P_CENTER_POOLS.Stake and G.P_CENTER_POOLS.Stake[index]
    return (center and center.key) or ('stake_' .. tostring(index))
end

-- Composite key for a completion matrix cell. The parts are game keys, none of which
-- contain '@', so the join is unambiguous and splits back cleanly.
function MSP.matrix_key(...)
    local parts = {}
    for _, v in ipairs({ ... }) do parts[#parts + 1] = tostring(v) end
    return table.concat(parts, '@')
end

local function sleeve_key()
    -- CardSleeves is optional; absent, a run simply has no sleeve.
    local s = G.GAME and (G.GAME.selected_sleeve or (G.GAME.selected_back and G.GAME.selected_back.sleeve))
    if type(s) == 'table' then return s.key or s.name end
    return s
end

-- Called once from the start_run hook, after G.GAME exists.
function MSP.begin_run()
    local r = MSP.run()
    if not r then return end
    -- Held so a run that gets replaced by a new one can still be closed out, and so a
    -- resumed run is tracked again rather than looking abandoned.
    MSP.active_run = r
    if r.meta.started then return end   -- resumed save, not a new run

    r.meta = {
        started  = true,
        bucket   = MSP.bucket_id(),
        seed     = G.GAME.pseudorandom and G.GAME.pseudorandom.seed or '?',
        deck     = deck_key(),
        sleeve   = sleeve_key(),
        stake    = MSP.num(G.GAME.stake, 1),
        stake_key = stake_key_for(MSP.num(G.GAME.stake, 1)),
        challenge = G.GAME.challenge,
        date     = MSP.today(),
    }

    local c = MSP.career()
    if c then
        -- runs_started is a career-only counter: the run cannot own a count of itself.
        add(c.t, 'runs_started', 1)
        MSP.tally('decks', r.meta.deck, 'plays')
        MSP.tally('stakes', r.meta.stake_key, 'plays')
        if r.meta.sleeve then MSP.tally('sleeves', r.meta.sleeve, 'plays') end
    end
    MSP.refresh_phase()

    -- Flush after the tallies, not before: they are written to the run, and this is what
    -- carries them across.
    MSP.flush()
end

-- Streaks live on the bucket rather than in the counter table: they are state, not a total,
-- and must not be delta-folded.
local function apply_streak(c, won)
    c.streak = c.streak or { win = 0, loss = 0 }
    if won then
        c.streak.win, c.streak.loss = c.streak.win + 1, 0
        MSP.record('win_streak', c.streak.win)
    else
        c.streak.loss, c.streak.win = c.streak.loss + 1, 0
        MSP.record('loss_streak', c.streak.loss)
    end
end

-- `result` is 'win', 'loss' or 'quit'. Idempotent: a run only ends once, however many seams
-- report it.
function MSP.finish_run(result, extra)
    local r = MSP.run()
    if not r or r.finished then return end

    local c = MSP.career()
    if not c then
        -- A challenge run. It was tracked for its own Run Info tab, and it ends here without
        -- touching the career. Marked finished so the sampler stops offering it every frame.
        r.finished = true
        MSP.active_run = nil
        return
    end
    r.finished = true
    MSP.active_run = nil
    extra = extra or {}

    -- Career-only: a run cannot count its own outcome.
    add(c.t, result == 'win' and 'runs_won' or result == 'loss' and 'runs_lost' or 'runs_abandoned', 1)

    local won = (result == 'win')
    if result ~= 'quit' then
        apply_streak(c, won)
        local field = won and 'wins' or 'losses'
        MSP.tally('decks', r.meta.deck, field)
        MSP.tally('stakes', r.meta.stake_key, field)
        if r.meta.sleeve then MSP.tally('sleeves', r.meta.sleeve, field) end

        -- Completion matrices. Stored sparsely - only combinations actually played get an
        -- entry - so a big modded roster costs nothing until it is used.
        local sk, deck, sleeve = r.meta.stake_key, r.meta.deck, r.meta.sleeve
        if sk and deck then
            MSP.tally('deck_stakes', MSP.matrix_key(deck, sk), field)
            if sleeve then
                MSP.tally('sleeve_stakes', MSP.matrix_key(sleeve, sk), field)
                MSP.tally('combo_stakes', MSP.matrix_key(deck, sleeve, sk), field)
            end
        end
        -- Every Joker held at the end shares the credit or the blame.
        if G.jokers and G.jokers.cards then
            for _, card in ipairs(G.jokers.cards) do
                local k = card.config and card.config.center_key
                if k then MSP.tally('jokers', k, field) end
            end
        end
    end

    local ctx = MSP.run_ctx()
    MSP.record('longest_run', r.time, ctx)
    if won then
        MSP.record('fastest_win', r.time, ctx)
        MSP.record('fewest_hands_win', MSP.num(r.t.hands_played), ctx)
    end

    if MSP.CFG and MSP.CFG.run_log then
        MSP.log_run(result, extra)
    end

    -- Last, so everything above - the outcome tallies, the end-of-run records, the Jokers
    -- that were still on the table - is carried across in one go.
    MSP.flush()
end

--============================================================
-- Run log
--============================================================
-- One compact record per finished run. Deliberately flat and small: the profile is written
-- out on every save, so a fat record costs on every write for the rest of the profile's life.
function MSP.log_run(result, extra)
    local st = MSP.profile()
    local r = MSP.run()
    if not (st and r) then return end

    local jokers = {}
    if G.jokers and G.jokers.cards then
        for _, card in ipairs(G.jokers.cards) do
            jokers[#jokers + 1] = card.config and card.config.center_key
        end
    end

    local best = r.records.best_hand
    st.runs[#st.runs + 1] = {
        date      = r.meta.date or MSP.today(),
        bucket    = r.meta.bucket,
        seed      = r.meta.seed,
        deck      = r.meta.deck,
        sleeve    = r.meta.sleeve,
        stake     = r.meta.stake,
        stake_key = r.meta.stake_key,
        challenge = r.meta.challenge,
        result    = result,
        ante      = MSP.num(G.GAME and G.GAME.round_resets and G.GAME.round_resets.ante),
        round     = MSP.num(G.GAME and G.GAME.round),
        hands     = MSP.num(r.t.hands_played),
        discards  = MSP.num(r.t.discards_used),
        best_hand = best and best.str or '0',
        earned    = MSP.num(r.t.earned_total),
        time      = math.floor(MSP.num(r.time)),
        jokers    = jokers,
        beaten_by = extra.beaten_by,
    }

    local cap = MSP.num(MSP.CFG and MSP.CFG.run_log_max)
    if cap > 0 then
        while #st.runs > cap do table.remove(st.runs, 1) end
    end
end

--============================================================
-- Reading for display
--============================================================
-- The value of one schema stat in a store, computing derived entries on the fly.
function MSP.stat_value(store, entry)
    if not store then return 0 end
    if entry.derive then return entry.derive(store.t or {}) end
    return MSP.num((store.t or {})[entry.key])
end

-- Sum of every bucket, for the "All" view on the career page.
function MSP.combined_career()
    local st = MSP.profile()
    if not st then return nil end
    -- No streak on the combined view: a win streak only means something inside the bucket it
    -- was played in, and summing three of them would invent a number nobody achieved.
    local out = new_bucket()
    for _, b in ipairs(MSP.BUCKETS) do
        local bk = st.buckets[b.id]
        if bk then
            for k, v in pairs(bk.t or {}) do add(out.t, k, MSP.num(v)) end
            for k, e in pairs(bk.records or {}) do offer_record(out, k, e) end
            for gid, g in pairs(bk.groups or {}) do
                out.groups[gid] = out.groups[gid] or {}
                for key, fields in pairs(g) do
                    local oe = out.groups[gid][key] or {}
                    out.groups[gid][key] = oe
                    for f, v in pairs(fields) do
                        if f:sub(-4) == '_log' then
                            -- A high-water mark across buckets is the highest of them, not
                            -- their sum.
                            local base = f:sub(1, -5)
                            if not oe[f] or MSP.num(v) > MSP.num(oe[f]) then
                                oe[f] = v
                                oe[base .. '_str'] = fields[base .. '_str']
                                oe[base .. '_num'] = fields[base .. '_num']
                            end
                        elseif not MSP.is_mag_field(f) then
                            add(oe, f, MSP.num(v))
                        end
                    end
                end
            end
        end
    end
    return out
end
