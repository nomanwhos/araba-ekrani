-- Torpido on-device database (SQLite via GRDB.swift). Migration v1.
-- Single user, single device: no owner columns, no row-level security.
-- Access control is the iOS app sandbox plus Data Protection; secrets live in
-- the Keychain, never in this file. Times are INTEGER Unix seconds, UTC.
-- IDs are TEXT UUIDs generated in Swift (UUID().uuidString).

PRAGMA foreign_keys = ON;

-- A playlist or media server the owner added (S09, S09b).
CREATE TABLE sources (
  id                TEXT PRIMARY KEY,
  kind              TEXT NOT NULL CHECK (kind IN ('m3u', 'xtream', 'jellyfin', 'emby', 'plex')),
  name              TEXT NOT NULL,
  url               TEXT NOT NULL,              -- playlist URL or server base URL; never contains a password
  username          TEXT,                       -- xtream / media server user; password or token is in the Keychain
  keychain_account  TEXT,                       -- Keychain account key for the secret, NULL for plain m3u
  status            TEXT NOT NULL DEFAULT 'new' CHECK (status IN ('new', 'ok', 'failed')),
  last_error        TEXT,
  last_refreshed_at INTEGER,
  position          INTEGER NOT NULL DEFAULT 0, -- order in Manage Sources
  created_at        INTEGER NOT NULL,
  updated_at        INTEGER NOT NULL
);

-- group-title values of a playlist, in playlist order (S01 rows).
CREATE TABLE channel_groups (
  id         TEXT PRIMARY KEY,
  source_id  TEXT NOT NULL REFERENCES sources(id) ON DELETE CASCADE,  -- removing a source removes its groups
  title      TEXT NOT NULL,
  position   INTEGER NOT NULL,
  UNIQUE (source_id, title)
);
CREATE INDEX channel_groups_source ON channel_groups (source_id, position);

-- One playable entry of a playlist (S01, S01b, S14).
-- stable_key survives a refresh (hash of tvg-id or name + group), so favourites
-- and resume positions keep pointing at the same channel after re-download.
CREATE TABLE channels (
  id              TEXT PRIMARY KEY,
  source_id       TEXT NOT NULL REFERENCES sources(id) ON DELETE CASCADE,
  group_id        TEXT REFERENCES channel_groups(id) ON DELETE SET NULL, -- ungrouped entries stay listed
  stable_key      TEXT NOT NULL,
  name            TEXT NOT NULL,
  logo_url        TEXT,                         -- tvg-logo
  tvg_id          TEXT,
  position        INTEGER NOT NULL,             -- order inside its group
  health          TEXT NOT NULL DEFAULT 'unknown' CHECK (health IN ('unknown', 'ok', 'down')),
  latency_ms      INTEGER,
  last_checked_at INTEGER,
  UNIQUE (source_id, stable_key)
);
CREATE INDEX channels_group ON channels (group_id, position);
CREATE INDEX channels_source_health ON channels (source_id, health);

-- A channel can have several playback URLs; the player can switch (FAQ #9).
CREATE TABLE channel_streams (
  id         TEXT PRIMARY KEY,
  channel_id TEXT NOT NULL REFERENCES channels(id) ON DELETE CASCADE,
  url        TEXT NOT NULL,                     -- may embed xtream credentials: never log it
  position   INTEGER NOT NULL,
  UNIQUE (channel_id, position)
);
CREATE INDEX channel_streams_channel ON channel_streams (channel_id);

-- Search over 100k+ channel names (S18). remove_diacritics folds ç/ş/ğ/ü/ö;
-- Turkish dotted/dotless i is folded in Swift before insert and before query.
CREATE VIRTUAL TABLE channels_fts USING fts5 (
  name, content = 'channels', content_rowid = 'rowid',
  tokenize = "unicode61 remove_diacritics 2"
);
CREATE TRIGGER channels_ai AFTER INSERT ON channels BEGIN
  INSERT INTO channels_fts (rowid, name) VALUES (new.rowid, new.name);
END;
CREATE TRIGGER channels_ad AFTER DELETE ON channels BEGIN
  INSERT INTO channels_fts (channels_fts, rowid, name) VALUES ('delete', old.rowid, old.name);
END;
CREATE TRIGGER channels_au AFTER UPDATE OF name ON channels BEGIN
  INSERT INTO channels_fts (channels_fts, rowid, name) VALUES ('delete', old.rowid, old.name);
  INSERT INTO channels_fts (rowid, name) VALUES (new.rowid, new.name);
END;

-- Cached Jellyfin / Emby / Plex library entries (S16). The server stays the source of truth.
CREATE TABLE media_items (
  id               TEXT PRIMARY KEY,
  source_id        TEXT NOT NULL REFERENCES sources(id) ON DELETE CASCADE,
  remote_id        TEXT NOT NULL,
  kind             TEXT NOT NULL CHECK (kind IN ('library', 'movie', 'series', 'season', 'episode')),
  parent_remote_id TEXT,
  index_number     INTEGER,                     -- season or episode number, for automatic sorting
  title            TEXT NOT NULL,
  image_url        TEXT,
  fetched_at       INTEGER NOT NULL,
  UNIQUE (source_id, remote_id)
);
CREATE INDEX media_items_parent ON media_items (source_id, parent_remote_id, index_number);

-- Videos imported from Files or Photos into the app container (S02 Local, S19).
CREATE TABLE local_videos (
  id           TEXT PRIMARY KEY,
  file_name    TEXT NOT NULL UNIQUE,            -- name inside Application Support/Videos
  display_name TEXT NOT NULL,                   -- renamable
  folder       TEXT NOT NULL DEFAULT '',
  sort_order   INTEGER NOT NULL,
  byte_size    INTEGER NOT NULL,
  duration_s   REAL,
  imported_at  INTEGER NOT NULL
);
CREATE INDEX local_videos_folder ON local_videos (folder, sort_order);

-- Favourites point at a channel, a media item or a local video by stable key.
-- Polymorphic, so no foreign key: a cleanup step drops rows whose target is gone.
CREATE TABLE favorites (
  id         TEXT PRIMARY KEY,
  item_kind  TEXT NOT NULL CHECK (item_kind IN ('channel', 'media', 'local')),
  item_key   TEXT NOT NULL,                     -- channels: source_id || ':' || stable_key; media: source_id || ':' || remote_id; local: local_videos.id
  sort_order INTEGER NOT NULL,                  -- drag to reorder
  created_at INTEGER NOT NULL,
  UNIQUE (item_kind, item_key)
);
CREATE INDEX favorites_order ON favorites (sort_order);

-- Resume where you left off; also feeds "Recently played".
CREATE TABLE playback_positions (
  item_kind  TEXT NOT NULL CHECK (item_kind IN ('channel', 'media', 'local')),
  item_key   TEXT NOT NULL,
  position_s REAL NOT NULL CHECK (position_s >= 0),
  duration_s REAL,                              -- NULL for live streams
  updated_at INTEGER NOT NULL,
  PRIMARY KEY (item_kind, item_key)
);
CREATE INDEX playback_positions_recent ON playback_positions (updated_at DESC);

-- Search history with re-search and clear.
CREATE TABLE search_queries (
  id          TEXT PRIMARY KEY,
  text        TEXT NOT NULL UNIQUE,             -- re-searching bumps searched_at instead of duplicating
  searched_at INTEGER NOT NULL
);
CREATE INDEX search_queries_recent ON search_queries (searched_at DESC);

-- In-app browser bookmarks (S07). Sign-in cookies live in WKWebsiteDataStore, not here.
CREATE TABLE bookmarks (
  id         TEXT PRIMARY KEY,
  url        TEXT NOT NULL UNIQUE,
  title      TEXT NOT NULL,
  position   INTEGER NOT NULL,
  created_at INTEGER NOT NULL
);
