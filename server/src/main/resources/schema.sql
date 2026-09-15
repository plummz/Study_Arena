PRAGMA foreign_keys=ON;
CREATE TABLE IF NOT EXISTS users (
 id TEXT PRIMARY KEY, email TEXT NOT NULL UNIQUE COLLATE NOCASE, password_hash TEXT NOT NULL,
 school_hash TEXT NOT NULL UNIQUE, school_cipher TEXT NOT NULL, display_name TEXT NOT NULL CHECK(length(display_name) BETWEEN 2 AND 40),
 age_band TEXT NOT NULL CHECK(age_band IN ('minor','adult')), consent_ref TEXT,
 role TEXT NOT NULL DEFAULT 'student' CHECK(role IN ('student','teacher','admin')),
 verified INTEGER NOT NULL DEFAULT 0 CHECK(verified IN (0,1)), competition INTEGER NOT NULL DEFAULT 0 CHECK(competition IN (0,1)),
 course TEXT NOT NULL DEFAULT '', year INTEGER NOT NULL DEFAULT 1 CHECK(year BETWEEN 1 AND 6), subjects TEXT NOT NULL DEFAULT '[]',
 timezone TEXT NOT NULL DEFAULT 'Asia/Manila', daily_goal INTEGER NOT NULL DEFAULT 25 CHECK(daily_goal BETWEEN 5 AND 180),
 weekly_goal INTEGER NOT NULL DEFAULT 125 CHECK(weekly_goal BETWEEN 5 AND 1260), band INTEGER NOT NULL DEFAULT 0 CHECK(band BETWEEN 0 AND 3),
 band_evidence INTEGER NOT NULL DEFAULT 0, version INTEGER NOT NULL DEFAULT 1, suspended INTEGER NOT NULL DEFAULT 0,
 created REAL NOT NULL, delete_after REAL
);
CREATE TABLE IF NOT EXISTS auth_sessions (
 token_hash TEXT PRIMARY KEY, user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
 device TEXT NOT NULL, created REAL NOT NULL, expires REAL NOT NULL, recent_auth REAL NOT NULL
);
CREATE INDEX IF NOT EXISTS ix_auth_user ON auth_sessions(user_id);
CREATE TABLE IF NOT EXISTS auth_tokens (
 token_hash TEXT PRIMARY KEY, user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
 purpose TEXT NOT NULL CHECK(purpose IN ('verify','reset')), expires REAL NOT NULL
);
CREATE TABLE IF NOT EXISTS rate_limits (key TEXT PRIMARY KEY, window REAL NOT NULL, count INTEGER NOT NULL CHECK(count>=0));
CREATE TABLE IF NOT EXISTS flags (name TEXT PRIMARY KEY, enabled INTEGER NOT NULL CHECK(enabled IN (0,1)));
CREATE TABLE IF NOT EXISTS topics (id TEXT PRIMARY KEY, subject TEXT NOT NULL, title TEXT NOT NULL, course TEXT NOT NULL, UNIQUE(subject,title));
CREATE TABLE IF NOT EXISTS decks (
 id TEXT PRIMARY KEY, owner_id TEXT REFERENCES users(id) ON DELETE CASCADE, title TEXT NOT NULL CHECK(length(title) BETWEEN 1 AND 120),
 topic_id TEXT NOT NULL REFERENCES topics(id), visibility TEXT NOT NULL DEFAULT 'private' CHECK(visibility IN ('private','public','room')),
 room_id TEXT, status TEXT NOT NULL DEFAULT 'private' CHECK(status IN ('private','pending','approved','quarantined')),
 version INTEGER NOT NULL DEFAULT 1, updated REAL NOT NULL, source TEXT NOT NULL DEFAULT '', license TEXT NOT NULL DEFAULT ''
);
CREATE INDEX IF NOT EXISTS ix_deck_owner ON decks(owner_id,updated);
CREATE INDEX IF NOT EXISTS ix_deck_topic ON decks(topic_id,status);
CREATE TABLE IF NOT EXISTS cards (
 id TEXT PRIMARY KEY, deck_id TEXT NOT NULL REFERENCES decks(id) ON DELETE CASCADE,
 front TEXT NOT NULL CHECK(length(front) BETWEEN 1 AND 4000), back TEXT NOT NULL CHECK(length(back) BETWEEN 1 AND 4000),
 image_id TEXT, image_alt TEXT NOT NULL DEFAULT '', fingerprint TEXT NOT NULL, position INTEGER NOT NULL CHECK(position>=0)
);
CREATE INDEX IF NOT EXISTS ix_card_deck ON cards(deck_id,position);
CREATE TABLE IF NOT EXISTS card_schedule (
 user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE, card_id TEXT NOT NULL REFERENCES cards(id) ON DELETE CASCADE,
 due REAL NOT NULL, interval_days REAL NOT NULL CHECK(interval_days>=0), ease REAL NOT NULL CHECK(ease>=1.3), repetitions INTEGER NOT NULL CHECK(repetitions>=0),
 PRIMARY KEY(user_id,card_id)
);
CREATE TABLE IF NOT EXISTS quizzes (
 id TEXT PRIMARY KEY, owner_id TEXT REFERENCES users(id) ON DELETE CASCADE, title TEXT NOT NULL, topic_id TEXT NOT NULL REFERENCES topics(id),
 status TEXT NOT NULL CHECK(status IN ('private','pending','approved','quarantined')), duration INTEGER CHECK(duration BETWEEN 30 AND 7200),
 version INTEGER NOT NULL DEFAULT 1, updated REAL NOT NULL, source TEXT NOT NULL, license TEXT NOT NULL
);
CREATE INDEX IF NOT EXISTS ix_quiz_topic ON quizzes(topic_id,status);
CREATE TABLE IF NOT EXISTS questions (
 id TEXT PRIMARY KEY, quiz_id TEXT NOT NULL REFERENCES quizzes(id) ON DELETE CASCADE,
 kind TEXT NOT NULL CHECK(kind IN ('mcq','boolean','identification')), prompt TEXT NOT NULL CHECK(length(prompt) BETWEEN 1 AND 4000),
 options TEXT NOT NULL DEFAULT '[]', accepted TEXT NOT NULL, explanation TEXT NOT NULL CHECK(length(explanation) BETWEEN 1 AND 4000),
 topic_id TEXT NOT NULL REFERENCES topics(id), position INTEGER NOT NULL
);
CREATE INDEX IF NOT EXISTS ix_question_quiz ON questions(quiz_id,position);
CREATE TABLE IF NOT EXISTS study_sessions (
 id TEXT PRIMARY KEY, user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE, topic_id TEXT NOT NULL REFERENCES topics(id),
 state TEXT NOT NULL CHECK(state IN ('running','paused','completed','discarded','uncredited')), started REAL NOT NULL,
 ended REAL, elapsed REAL NOT NULL DEFAULT 0 CHECK(elapsed>=0), credited INTEGER NOT NULL DEFAULT 0 CHECK(credited BETWEEN 0 AND 180),
 last_heartbeat REAL NOT NULL, timezone TEXT NOT NULL, notes_cipher TEXT NOT NULL, offline INTEGER NOT NULL DEFAULT 0,
 reason TEXT NOT NULL DEFAULT ''
);
CREATE UNIQUE INDEX IF NOT EXISTS ix_one_active_session ON study_sessions(user_id) WHERE state IN ('running','paused');
CREATE INDEX IF NOT EXISTS ix_session_user ON study_sessions(user_id,started);
CREATE TABLE IF NOT EXISTS attempts (
 id TEXT PRIMARY KEY, user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE, quiz_id TEXT NOT NULL REFERENCES quizzes(id),
 state TEXT NOT NULL CHECK(state IN ('active','completed','discarded','void')), started REAL NOT NULL, deadline REAL,
 ended REAL, question_order TEXT NOT NULL, score INTEGER NOT NULL DEFAULT 0, total INTEGER NOT NULL, offline INTEGER NOT NULL DEFAULT 0,
 flagged TEXT NOT NULL DEFAULT '', snapshot TEXT NOT NULL
);
CREATE INDEX IF NOT EXISTS ix_attempt_user ON attempts(user_id,started);
CREATE UNIQUE INDEX IF NOT EXISTS ix_one_active_attempt ON attempts(user_id,quiz_id) WHERE state='active';
CREATE TABLE IF NOT EXISTS answers (
 attempt_id TEXT NOT NULL REFERENCES attempts(id) ON DELETE CASCADE, question_id TEXT NOT NULL,
 answer TEXT NOT NULL, correct INTEGER NOT NULL CHECK(correct IN (0,1)), answered REAL NOT NULL,
 PRIMARY KEY(attempt_id,question_id)
);
CREATE TABLE IF NOT EXISTS review_events (
 id TEXT PRIMARY KEY, user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE, card_id TEXT NOT NULL REFERENCES cards(id) ON DELETE CASCADE,
 known INTEGER NOT NULL CHECK(known IN (0,1)), occurred REAL NOT NULL, rewarded INTEGER NOT NULL CHECK(rewarded IN (0,1))
);
CREATE INDEX IF NOT EXISTS ix_review_user ON review_events(user_id,occurred);
CREATE TABLE IF NOT EXISTS evidence (
 id TEXT PRIMARY KEY, user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE, topic_id TEXT NOT NULL REFERENCES topics(id),
 correct REAL NOT NULL CHECK(correct BETWEEN 0 AND 1), weight REAL NOT NULL CHECK(weight>0), occurred REAL NOT NULL, origin TEXT NOT NULL
);
CREATE INDEX IF NOT EXISTS ix_evidence_topic ON evidence(user_id,topic_id,occurred);
CREATE TABLE IF NOT EXISTS materials (
 id TEXT PRIMARY KEY, owner_id TEXT REFERENCES users(id) ON DELETE CASCADE, title TEXT NOT NULL, topic_id TEXT NOT NULL REFERENCES topics(id),
 year INTEGER NOT NULL CHECK(year BETWEEN 1 AND 6), file_type TEXT NOT NULL CHECK(file_type IN ('text','pdf','png','jpeg')),
 body TEXT NOT NULL DEFAULT '', file_key TEXT, bytes INTEGER NOT NULL DEFAULT 0 CHECK(bytes>=0), sha256 TEXT,
 source TEXT NOT NULL, license TEXT NOT NULL, status TEXT NOT NULL CHECK(status IN ('pending','approved','quarantined')),
 verified_by TEXT REFERENCES users(id) ON DELETE SET NULL, created REAL NOT NULL
);
CREATE INDEX IF NOT EXISTS ix_material_filter ON materials(status,topic_id,year,file_type);
CREATE TABLE IF NOT EXISTS rooms (
 id TEXT PRIMARY KEY, owner_id TEXT NOT NULL REFERENCES users(id), title TEXT NOT NULL, topic_id TEXT NOT NULL REFERENCES topics(id),
 band INTEGER NOT NULL CHECK(band BETWEEN 0 AND 3), code_hash TEXT NOT NULL UNIQUE, code_expires REAL NOT NULL,
 state TEXT NOT NULL CHECK(state IN ('active','archived')), scheduled REAL, timer_end REAL,
 last_active REAL NOT NULL, archived REAL, warned INTEGER NOT NULL DEFAULT 0
);
CREATE INDEX IF NOT EXISTS ix_room_match ON rooms(state,topic_id,band);
CREATE TABLE IF NOT EXISTS memberships (
 room_id TEXT NOT NULL REFERENCES rooms(id) ON DELETE CASCADE, user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
 joined REAL NOT NULL, PRIMARY KEY(room_id,user_id)
);
CREATE TABLE IF NOT EXISTS room_resources (
 room_id TEXT NOT NULL REFERENCES rooms(id) ON DELETE CASCADE, kind TEXT NOT NULL CHECK(kind IN ('deck','material')),
 resource_id TEXT NOT NULL, added_by TEXT REFERENCES users(id) ON DELETE SET NULL, PRIMARY KEY(room_id,kind,resource_id)
);
CREATE TABLE IF NOT EXISTS messages (
 id TEXT PRIMARY KEY, room_id TEXT NOT NULL REFERENCES rooms(id) ON DELETE CASCADE, user_id TEXT REFERENCES users(id) ON DELETE SET NULL,
 body TEXT NOT NULL CHECK(length(body) BETWEEN 1 AND 2000), created REAL NOT NULL, hidden INTEGER NOT NULL DEFAULT 0
);
CREATE INDEX IF NOT EXISTS ix_message_room ON messages(room_id,created);
CREATE TABLE IF NOT EXISTS blocks (
 user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE, blocked_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
 PRIMARY KEY(user_id,blocked_id), CHECK(user_id!=blocked_id)
);
CREATE TABLE IF NOT EXISTS duel_queue (
 user_id TEXT PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE, topic_id TEXT NOT NULL REFERENCES topics(id),
 band INTEGER NOT NULL CHECK(band BETWEEN 0 AND 3), queued REAL NOT NULL, heartbeat REAL NOT NULL
);
CREATE TABLE IF NOT EXISTS seasons (id TEXT PRIMARY KEY, title TEXT NOT NULL, starts REAL NOT NULL, ends REAL NOT NULL, CHECK(ends>starts));
CREATE TABLE IF NOT EXISTS duels (
 id TEXT PRIMARY KEY, a_id TEXT NOT NULL REFERENCES users(id), b_id TEXT REFERENCES users(id), topic_id TEXT NOT NULL REFERENCES topics(id),
 season_id TEXT REFERENCES seasons(id), state TEXT NOT NULL CHECK(state IN ('active','completed','forfeit','void')),
 created REAL NOT NULL, deadline REAL NOT NULL, a_seen REAL NOT NULL, b_seen REAL NOT NULL, question_data TEXT NOT NULL,
 a_score INTEGER NOT NULL DEFAULT 0, b_score INTEGER NOT NULL DEFAULT 0, result TEXT NOT NULL DEFAULT '', bot INTEGER NOT NULL DEFAULT 0
);
CREATE INDEX IF NOT EXISTS ix_duel_players ON duels(a_id,b_id,state);
CREATE TABLE IF NOT EXISTS duel_answers (
 duel_id TEXT NOT NULL REFERENCES duels(id) ON DELETE CASCADE, user_id TEXT NOT NULL REFERENCES users(id),
 question_id TEXT NOT NULL, answer TEXT NOT NULL, correct INTEGER NOT NULL CHECK(correct IN (0,1)), received REAL NOT NULL,
 PRIMARY KEY(duel_id,user_id,question_id)
);
CREATE TABLE IF NOT EXISTS ledger (
 id TEXT PRIMARY KEY, user_id TEXT REFERENCES users(id) ON DELETE SET NULL, xp INTEGER NOT NULL, coins INTEGER NOT NULL,
 origin TEXT NOT NULL, reason TEXT NOT NULL, created REAL NOT NULL, actor_id TEXT REFERENCES users(id) ON DELETE SET NULL,
 UNIQUE(user_id,origin)
);
CREATE INDEX IF NOT EXISTS ix_ledger_user ON ledger(user_id,created);
CREATE TRIGGER IF NOT EXISTS immutable_ledger_update BEFORE UPDATE OF xp,coins,origin,reason,created ON ledger BEGIN SELECT RAISE(ABORT,'immutable ledger'); END;
CREATE TRIGGER IF NOT EXISTS immutable_ledger_delete BEFORE DELETE ON ledger BEGIN SELECT RAISE(ABORT,'immutable ledger'); END;
CREATE TABLE IF NOT EXISTS catalog (
 id TEXT PRIMARY KEY, title TEXT NOT NULL, kind TEXT NOT NULL CHECK(kind IN ('skin','border','hat','theme','content','freeze','prize')),
 price INTEGER NOT NULL CHECK(price>=0), stock INTEGER CHECK(stock>=0), adult_only INTEGER NOT NULL DEFAULT 0,
 rules TEXT NOT NULL DEFAULT '', rules_version INTEGER NOT NULL DEFAULT 1, sponsor TEXT NOT NULL DEFAULT '', active INTEGER NOT NULL DEFAULT 1,
 value TEXT NOT NULL DEFAULT ''
);
CREATE TABLE IF NOT EXISTS inventory (
 user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE, item_id TEXT NOT NULL REFERENCES catalog(id),
 acquired REAL NOT NULL, equipped INTEGER NOT NULL DEFAULT 0, consumed INTEGER NOT NULL DEFAULT 0,
 PRIMARY KEY(user_id,item_id)
);
CREATE TABLE IF NOT EXISTS claims (
 id TEXT PRIMARY KEY, user_id TEXT REFERENCES users(id) ON DELETE SET NULL, item_id TEXT NOT NULL REFERENCES catalog(id),
 state TEXT NOT NULL CHECK(state IN ('pending','approved','denied','fulfilled','cancelled')),
 rules_version INTEGER NOT NULL, rules_snapshot TEXT NOT NULL, created REAL NOT NULL, updated REAL NOT NULL,
 reviewer TEXT REFERENCES users(id) ON DELETE SET NULL, receipt TEXT NOT NULL DEFAULT '', reason TEXT NOT NULL DEFAULT '',
 UNIQUE(user_id,item_id)
);
CREATE TABLE IF NOT EXISTS badges (
 user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE, badge TEXT NOT NULL, earned REAL NOT NULL, PRIMARY KEY(user_id,badge)
);
CREATE TABLE IF NOT EXISTS streak_days (
 user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE, day TEXT NOT NULL, kind TEXT NOT NULL CHECK(kind IN ('study','grace','freeze')),
 created REAL NOT NULL, PRIMARY KEY(user_id,day)
);
CREATE TABLE IF NOT EXISTS login_days (
 user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE, day TEXT NOT NULL, created REAL NOT NULL,
 PRIMARY KEY(user_id,day)
);
CREATE INDEX IF NOT EXISTS ix_login_days_user ON login_days(user_id,day);
CREATE TABLE IF NOT EXISTS studio_sources (
 id TEXT PRIMARY KEY, owner_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
 title TEXT NOT NULL CHECK(length(title) BETWEEN 1 AND 120), filename TEXT NOT NULL CHECK(length(filename) BETWEEN 1 AND 180),
 mime TEXT NOT NULL CHECK(length(mime) BETWEEN 1 AND 120), bytes INTEGER NOT NULL CHECK(bytes BETWEEN 1 AND 26214400),
 sha256 TEXT NOT NULL CHECK(length(sha256)=64), file_key TEXT, uploaded INTEGER NOT NULL DEFAULT 0 CHECK(uploaded>=0),
 state TEXT NOT NULL DEFAULT 'uploading' CHECK(state IN ('uploading','ready','failed')), created REAL NOT NULL
);
CREATE INDEX IF NOT EXISTS ix_studio_source_owner ON studio_sources(owner_id,created);
CREATE TABLE IF NOT EXISTS studio_artifacts (
 id TEXT PRIMARY KEY, owner_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
 source_id TEXT NOT NULL REFERENCES studio_sources(id) ON DELETE CASCADE,
 kind TEXT NOT NULL CHECK(kind IN ('reviewer','summary','study_plan','flashcards','quizlet','quiz','slides','transcript')),
 title TEXT NOT NULL CHECK(length(title) BETWEEN 1 AND 160), body TEXT NOT NULL,
 ai INTEGER NOT NULL DEFAULT 0 CHECK(ai IN (0,1)), created REAL NOT NULL
);
CREATE INDEX IF NOT EXISTS ix_studio_artifact_owner ON studio_artifacts(owner_id,created);
CREATE TABLE IF NOT EXISTS notification_settings (
 user_id TEXT PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE, reminders INTEGER NOT NULL DEFAULT 1, streak INTEGER NOT NULL DEFAULT 1,
 invitations INTEGER NOT NULL DEFAULT 1, challenges INTEGER NOT NULL DEFAULT 0, rewards INTEGER NOT NULL DEFAULT 1,
 quiet_start INTEGER NOT NULL DEFAULT 22 CHECK(quiet_start BETWEEN 0 AND 23), quiet_end INTEGER NOT NULL DEFAULT 7 CHECK(quiet_end BETWEEN 0 AND 23),
 reminder_time TEXT NOT NULL DEFAULT '18:00', daily_cap INTEGER NOT NULL DEFAULT 3 CHECK(daily_cap BETWEEN 0 AND 3)
);
CREATE TABLE IF NOT EXISTS notifications (
 id TEXT PRIMARY KEY, user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE, category TEXT NOT NULL,
 body TEXT NOT NULL, created REAL NOT NULL, day TEXT NOT NULL, read INTEGER NOT NULL DEFAULT 0
);
CREATE INDEX IF NOT EXISTS ix_notify_user ON notifications(user_id,day);
CREATE TABLE IF NOT EXISTS reports (
 id TEXT PRIMARY KEY, reporter TEXT REFERENCES users(id) ON DELETE SET NULL,
 kind TEXT NOT NULL CHECK(kind IN ('deck','quiz','material','message','user','duel')),
 target_id TEXT NOT NULL, reason TEXT NOT NULL, evidence TEXT NOT NULL, state TEXT NOT NULL DEFAULT 'pending' CHECK(state IN ('pending','resolved','dismissed')),
 created REAL NOT NULL, action TEXT NOT NULL DEFAULT '', reviewed_by TEXT REFERENCES users(id) ON DELETE SET NULL
);
CREATE INDEX IF NOT EXISTS ix_report_queue ON reports(state,created);
CREATE TABLE IF NOT EXISTS audit (
 id TEXT PRIMARY KEY, actor_id TEXT REFERENCES users(id) ON DELETE SET NULL, action TEXT NOT NULL, target TEXT NOT NULL,
 reason TEXT NOT NULL, created REAL NOT NULL, previous_hash TEXT NOT NULL, entry_hash TEXT NOT NULL UNIQUE
);
CREATE TRIGGER IF NOT EXISTS immutable_audit_update BEFORE UPDATE OF action,target,reason,created,previous_hash,entry_hash ON audit BEGIN SELECT RAISE(ABORT,'immutable audit'); END;
CREATE TRIGGER IF NOT EXISTS immutable_audit_delete BEFORE DELETE ON audit BEGIN SELECT RAISE(ABORT,'immutable audit'); END;
CREATE TABLE IF NOT EXISTS idempotency (
 user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE, key TEXT NOT NULL, fingerprint TEXT NOT NULL,
 response TEXT NOT NULL, created REAL NOT NULL, PRIMARY KEY(user_id,key)
);
CREATE TABLE IF NOT EXISTS outbox (
 id TEXT PRIMARY KEY, user_id TEXT REFERENCES users(id) ON DELETE CASCADE, recipient_cipher TEXT NOT NULL,
 subject TEXT NOT NULL, body_cipher TEXT NOT NULL, created REAL NOT NULL, attempts INTEGER NOT NULL DEFAULT 0, delivered REAL
);
CREATE TABLE IF NOT EXISTS risk_events (
 id TEXT PRIMARY KEY, user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE, signal TEXT NOT NULL,
 evidence TEXT NOT NULL, created REAL NOT NULL, resolved INTEGER NOT NULL DEFAULT 0
);
CREATE INDEX IF NOT EXISTS ix_risk_user ON risk_events(user_id,created);
CREATE TABLE IF NOT EXISTS cohorts (id TEXT PRIMARY KEY, title TEXT NOT NULL);
CREATE TABLE IF NOT EXISTS cohort_members (cohort_id TEXT NOT NULL REFERENCES cohorts(id) ON DELETE CASCADE, user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE, PRIMARY KEY(cohort_id,user_id));
CREATE TABLE IF NOT EXISTS cohort_moderators (cohort_id TEXT NOT NULL REFERENCES cohorts(id) ON DELETE CASCADE, user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE, PRIMARY KEY(cohort_id,user_id));
CREATE TABLE IF NOT EXISTS push_tokens (token TEXT PRIMARY KEY, user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE, platform TEXT NOT NULL CHECK(platform='android'), updated REAL NOT NULL);
CREATE TABLE IF NOT EXISTS push_delivery (notification_id TEXT NOT NULL REFERENCES notifications(id) ON DELETE CASCADE, token TEXT NOT NULL REFERENCES push_tokens(token) ON DELETE CASCADE, delivered REAL NOT NULL, PRIMARY KEY(notification_id,token));
