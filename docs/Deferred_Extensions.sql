-- Design-only migration for the features deferred in Part 1. Not applied at startup.
CREATE TABLE tournaments (
 id TEXT PRIMARY KEY, room_id TEXT NOT NULL REFERENCES rooms(id), owner_id TEXT NOT NULL REFERENCES users(id),
 topic_id TEXT NOT NULL REFERENCES topics(id), band INTEGER NOT NULL CHECK(band BETWEEN 0 AND 3),
 season_id TEXT NOT NULL REFERENCES seasons(id), state TEXT NOT NULL CHECK(state IN ('draft','open','running','completed','void')),
 capacity INTEGER NOT NULL CHECK(capacity BETWEEN 2 AND 8), starts REAL NOT NULL, created REAL NOT NULL
);
CREATE INDEX ix_tournament_room ON tournaments(room_id,state,starts);
CREATE TABLE tournament_entries (
 tournament_id TEXT NOT NULL REFERENCES tournaments(id) ON DELETE CASCADE,
 user_id TEXT NOT NULL REFERENCES users(id), seed INTEGER NOT NULL CHECK(seed BETWEEN 1 AND 8),
 joined REAL NOT NULL, PRIMARY KEY(tournament_id,user_id), UNIQUE(tournament_id,seed)
);
CREATE TABLE tournament_matches (
 tournament_id TEXT NOT NULL REFERENCES tournaments(id) ON DELETE CASCADE,
 round INTEGER NOT NULL CHECK(round BETWEEN 1 AND 3), slot INTEGER NOT NULL CHECK(slot BETWEEN 1 AND 4),
 duel_id TEXT UNIQUE REFERENCES duels(id), winner_id TEXT REFERENCES users(id),
 state TEXT NOT NULL CHECK(state IN ('pending','active','complete','bye','void')),
 PRIMARY KEY(tournament_id,round,slot)
);
CREATE TABLE peer_comparison_optins (
 room_id TEXT NOT NULL REFERENCES rooms(id) ON DELETE CASCADE,
 user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE, enabled INTEGER NOT NULL CHECK(enabled IN (0,1)),
 updated REAL NOT NULL, PRIMARY KEY(room_id,user_id)
);
CREATE TABLE seasonal_standings (
 season_id TEXT NOT NULL REFERENCES seasons(id), room_id TEXT NOT NULL REFERENCES rooms(id),
 user_id TEXT NOT NULL REFERENCES users(id), band INTEGER NOT NULL CHECK(band BETWEEN 0 AND 3),
 points INTEGER NOT NULL DEFAULT 0 CHECK(points>=0), valid_matches INTEGER NOT NULL DEFAULT 0 CHECK(valid_matches>=0),
 PRIMARY KEY(season_id,room_id,user_id)
);
CREATE INDEX ix_standings_scope ON seasonal_standings(season_id,room_id,band,points DESC);
