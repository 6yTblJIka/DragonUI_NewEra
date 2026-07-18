-- DragonUI_NewEra/modules/guild/Chat.lua — Guild chat (CHAT mode).
--
-- DOWNPORT of NewEra/Guild/Chat.lua. NewEra uses retail's C_Club stream + CommunitiesChatFrame.
-- On 3.3.5a there is no C_Club: guild chat is the CHAT_MSG_GUILD / CHAT_MSG_OFFICER channels. We
-- mirror those into a ScrollingMessageFrame and send via SendChatMessage(msg, "GUILD").
--
-- HISTORY SYNC (owner steer 2026-07-18): 3.3.5a has no server-side chat log, so a fresh /reload or
-- login shows an empty window. We keep a small rolling log per guild in SavedVariables and, on
-- login, ask other online guildmates (SendAddonMessage over the "GUILD" distribution) for anything
-- newer than what we already have. Two problems the owner flagged up front, and how this avoids
-- both:
--   * Dedup: every entry is stamped with the epoch time() of the client that FIRST witnessed it
--     live, and that stamp is carried through every relay untouched (never re-stamped on receipt).
--     The dedup key (author+epoch+message) is therefore identical no matter who relays it to you.
--   * Timezones: we never do manual TZ math. epoch is a plain time() value (already UTC-based on
--     any sane system clock); each client formats it for display with its OWN date() call, so
--     everyone sees times in their own computer's local time automatically.
-- Scope/safety: only regular guild chat (kind "G") is ever relayed over the addon channel. Officer
-- chat (kind "O") is still logged+restored locally (so YOUR OWN officer scrollback survives a
-- reload) but is never broadcast — CHAT_MSG_OFFICER only ever fires for clients already privileged
-- to see it, and relaying it over the guild-wide "GUILD" addon distribution would leak it to
-- non-officers. There is no sync request/response for officer chat in this version.
--
-- 3.3.5a API notes: SendAddonMessage/CHAT_MSG_ADDON(prefix, message, channel, sender) and time()/
-- date() are unchanged core APIs in this era. RegisterAddonMessagePrefix does not exist yet (a
-- later-expansion addition), so the prefix is just used directly with no registration step.

local NE = DragonUI_NewEra
if not NE then return end

NE.guild = NE.guild or {}
local G = NE.guild

-- Guild/officer channel colours (ChatTypeInfo, with sane fallbacks).
local function chanColor(kind)
  local info = ChatTypeInfo and ChatTypeInfo[kind]
  if info then return info.r, info.g, info.b end
  if kind == "OFFICER" then return 0.4, 0.78, 0.94 end
  return 0.25, 1, 0.25
end

-- ----------------------------------------------------------------------------
-- Class-coloured names (owner ask 2026-07-18). name -> classFileName, rebuilt from
-- GetGuildRosterInfo() on GUILD_ROSTER_UPDATE — same roster API Roster.lua already uses.
-- ----------------------------------------------------------------------------
local nameClass = {}

-- Forward-declared: assigned once printBacklogLine()/store() exist below. refreshRosterClasses
-- only ever CALLS this from an event handler (never at file-load time), so by the time it runs
-- the assignment further down has already happened — this is just working around Lua's top-to-
-- bottom local scoping, not a real ordering hazard.
local repaintLog

-- Backlog is replayed exactly once, the first time the chat panel is built (see G.SetupChat) —
-- which can easily happen before GUILD_ROSTER_UPDATE has fired even once (window opened right
-- after login, before the roster request completes). That first replay falls back to the "unknown
-- class" colour for everyone since nameClass is still empty. G.SetupChat flags
-- panel._needsRecolor in that case; once we actually get roster data, repaint the log so history
-- picks up real class colours instead of staying stuck on the fallback forever.
local function refreshRosterClasses()
  if not GetNumGuildMembers or not GetGuildRosterInfo then return end
  -- GetGuildRosterInfo only enumerates OFFLINE members while GetGuildRosterShowOffline() is true
  -- (the same flag behind the Roster tab's own "Show Offline" checkbox, Roster.lua:264) — owner
  -- report 2026-07-18: someone offline at login stayed the fallback colour forever, even though
  -- the roster "knows" their class once that checkbox is ticked. Flip it on for this synchronous
  -- scan (no server round-trip involved, just a client-side filter on already-cached data) and
  -- restore whatever the Roster tab had it set to, so we don't silently change that checkbox's
  -- visible state out from under the user.
  local prevShowOffline = GetGuildRosterShowOffline and GetGuildRosterShowOffline()
  if SetGuildRosterShowOffline and not prevShowOffline then SetGuildRosterShowOffline(true) end
  local total = GetNumGuildMembers() or 0
  for i = 1, total do
    local name, _, _, _, _, _, _, _, _, _, classFile = GetGuildRosterInfo(i)
    if name then
      -- CHAT_MSG_GUILD author names are never realm-qualified on 3.3.5a's single-realm chat,
      -- but the roster can list "Name-Realm" on some servers — key on the bare name either way.
      nameClass[name:match("^([^%-]+)") or name] = classFile
    end
  end
  if SetGuildRosterShowOffline and not prevShowOffline then SetGuildRosterShowOffline(false) end
  local panel = G.frame and G.frame.ChatFrame
  if total > 0 and panel and panel._needsRecolor then
    panel._needsRecolor = nil
    if repaintLog then repaintLog() end
  end
end

-- Same RAID_CLASS_COLORS convention as Roster.lua's classColor(), just hex-packed for inline
-- |cffRRGGBB codes instead of separate r,g,b floats.
local function classColorHex(classFile)
  local c = classFile and RAID_CLASS_COLORS and RAID_CLASS_COLORS[classFile]
  local r, g, b = 1, 0.82, 0
  if c then r, g, b = c.r, c.g, c.b end
  return string.format("%02x%02x%02x", math.floor(r * 255 + 0.5), math.floor(g * 255 + 0.5), math.floor(b * 255 + 0.5))
end

-- Builds the "[Author]: " lead-in with the author's name (only) class-coloured; the rest of the
-- line keeps using AddMessage's own r,g,b (the channel colour), same as before this feature.
local function nameSegment(author)
  return string.format("|cff%s[%s]|r: ", classColorHex(nameClass[author]), author or "?")
end

-- ----------------------------------------------------------------------------
-- Rolling per-guild log (NE.db.guildChat[guildKey]) + history sync protocol.
-- ----------------------------------------------------------------------------
local PREFIX     = "DUINE_GCH"
local FS         = "\1"   -- field separator: a control byte normal chat text can't type
local MAX_STORED = 300    -- ring buffer cap per guild
local MAX_RELAY  = 30     -- most entries we'll hand a single sync requester
local MAX_MSG    = 200    -- truncate relayed message text to this before adding protocol overhead

local function guildKey()
  local name = GetGuildInfo and GetGuildInfo("player")
  if not name then return nil end
  return (GetRealmName() or "?") .. "-" .. name
end

local function store()
  local db = NE.db
  if not db then return nil end
  db.guildChat = db.guildChat or {}
  local key = guildKey()
  if not key then return nil end
  local s = db.guildChat[key]
  if not s then s = { entries = {}, seen = {}, newest = 0 }; db.guildChat[key] = s end
  return s
end

-- Insert (kind, author, message, epoch) if not already known. Returns true if newly added.
local function remember(kind, author, message, epoch)
  local s = store()
  if not s then return false end
  local dedupKey = (author or "?") .. FS .. kind .. FS .. epoch .. FS .. message
  if s.seen[dedupKey] then return false end
  s.seen[dedupKey] = true
  local entries = s.entries
  entries[#entries + 1] = { kind = kind, author = author, message = message, epoch = epoch }
  if epoch > s.newest then s.newest = epoch end
  if #entries > MAX_STORED then
    local drop = table.remove(entries, 1)
    s.seen[(drop.author or "?") .. FS .. drop.kind .. FS .. drop.epoch .. FS .. drop.message] = nil
  end
  return true
end

-- Shared line text: a dim [HH:MM] stamp + the class-coloured name segment + the message. Used for
-- BOTH backlog and live lines so the timestamp is always there either way (owner report 2026-07-18:
-- history had timestamps but live-session lines didn't — inconsistent); only the base AddMessage
-- colour (full brightness live vs toned-down for backlog) still tells the two apart.
local function formatLine(author, message, epoch)
  local stamp = date and date("%H:%M", epoch) or ""
  return string.format("|cff888888[%s]|r ", stamp) .. nameSegment(author) .. (message or "")
end

-- Render one line into the log's ScrollingMessageFrame with the dim "backlog" treatment: toned-
-- down channel colour, distinguishing it from freshly-arriving lines.
local function printBacklogLine(log, kind, author, message, epoch)
  local r, g, b = chanColor(kind == "O" and "OFFICER" or "GUILD")
  log:AddMessage(formatLine(author, message, epoch), r * 0.75, g * 0.75, b * 0.75)
end

-- Every live message is also `remember()`-ed (see the event handler below), so the stored log is
-- always a complete record of everything ever shown — safe to wipe and fully replay at any time.
repaintLog = function()
  local f = G.frame
  local log = f and f.ChatFrame and f.ChatFrame.Log
  local s = store()
  if not log or not s then return end
  log:Clear()
  for _, e in ipairs(s.entries) do
    printBacklogLine(log, e.kind, e.author, e.message, e.epoch)
  end
end

function G.SetupChat(f)
  local panel = f.ChatFrame
  if not panel or panel._built then return end
  panel._built = true

  -- Dark recessed backdrop behind the whole chat panel (same treatment as the Roster panel,
  -- owner steer 2026-07-17: "add that same dark background inset behind the guild chat").
  local panelBg = panel:CreateTexture(nil, "BACKGROUND")
  panelBg:SetTexture("Interface\\Buttons\\WHITE8X8")
  panelBg:SetVertexColor(0.06, 0.06, 0.07, 0.90)
  panelBg:SetAllPoints(panel)
  panel.Bg = panelBg
  if NE.nineslice and NE.nineslice.AttachInset then pcall(NE.nineslice.AttachInset, panel, 0, 0, 0, 0) end

  -- Recessed message well.
  local well = CreateFrame("Frame", nil, panel)
  well:SetPoint("TOPLEFT", panel, "TOPLEFT", 2, -2)
  well:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -2, 30)
  if NE.nineslice and NE.nineslice.AttachInset then pcall(NE.nineslice.AttachInset, well, 0, 0, 0, 0) end

  local msg = CreateFrame("ScrollingMessageFrame", "NE_GuildChatLog", well)
  msg:SetPoint("TOPLEFT", well, "TOPLEFT", 8, -6)
  msg:SetPoint("BOTTOMRIGHT", well, "BOTTOMRIGHT", -24, 6)
  msg:SetFontObject(ChatFontNormal or GameFontHighlightSmall)
  msg:SetJustifyH("LEFT")
  msg:SetFading(false)
  msg:SetMaxLines(500)
  msg:EnableMouseWheel(true)
  if msg.SetHyperlinksEnabled then msg:SetHyperlinksEnabled(true) end
  msg:SetScript("OnMouseWheel", function(self, delta)
    if delta > 0 then
      if IsShiftKeyDown() and self.ScrollToTop then self:ScrollToTop() else self:ScrollUp() end
    else
      if IsShiftKeyDown() and self.ScrollToBottom then self:ScrollToBottom() else self:ScrollDown() end
    end
  end)
  msg:SetScript("OnHyperlinkClick", function(self, link, text, button)
    if SetItemRef then SetItemRef(link, text, button) end
  end)
  panel.Log = msg

  -- Send edit box.
  local edit = CreateFrame("EditBox", "NE_GuildChatEdit", panel, "InputBoxTemplate")
  edit:SetHeight(20)
  edit:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", 8, 6)
  edit:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -8, 6)
  edit:SetAutoFocus(false)
  edit:SetScript("OnEnterPressed", function(self)
    local text = self:GetText()
    if text and text ~= "" and SendChatMessage then
      SendChatMessage(text, "GUILD")
    end
    self:SetText("")
    self:ClearFocus()
  end)
  edit:SetScript("OnEscapePressed", function(self) self:SetText(""); self:ClearFocus() end)
  panel.Edit = edit

  -- Replay whatever we already have logged (earlier this session, or synced from a guildmate) so
  -- opening the window doesn't start blank. Backlog lines get the dim timestamp treatment; live
  -- lines arriving from here on print with the plain style via appendGuild() below.
  local s = store()
  if s then
    if next(nameClass) == nil then panel._needsRecolor = true end -- roster not loaded yet
    for _, e in ipairs(s.entries) do
      printBacklogLine(msg, e.kind, e.author, e.message, e.epoch)
    end
  end
end

local function appendGuild(kind, message, author, epoch)
  local f = G.frame
  local log = f and f.ChatFrame and f.ChatFrame.Log
  if not log then return end
  local r, g, b = chanColor(kind)
  log:AddMessage(formatLine(author, message, epoch), r, g, b)
end
G.AppendGuildMessage = appendGuild

-- ----------------------------------------------------------------------------
-- Outbound send throttle: a sync reply can be several messages back-to-back; space them out so we
-- don't trip a private server's chat-flood protection (addon messages share that same queue).
-- ----------------------------------------------------------------------------
local sendQueue = {}
local function pumpQueue()
  local job = table.remove(sendQueue, 1)
  if not job then return end
  SendAddonMessage(PREFIX, job, "GUILD")
  if #sendQueue > 0 then C_Timer.After(0.2, pumpQueue) end
end
local function queueSend(payload)
  sendQueue[#sendQueue + 1] = payload
  if #sendQueue == 1 then pumpQueue() end
end

-- Reply to a sync request: hand over our newest guild-chat (kind "G" only) entries after `since`.
local function replyWithHistory(since)
  local s = store()
  if not s then return end
  local out = {}
  for _, e in ipairs(s.entries) do
    if e.kind == "G" and e.epoch > since then out[#out + 1] = e end
  end
  if #out == 0 then return end
  if #out > MAX_RELAY then -- a huge gap shouldn't turn into a message storm; newest wins
    local trimmed = {}
    for i = #out - MAX_RELAY + 1, #out do trimmed[#trimmed + 1] = out[i] end
    out = trimmed
  end
  for _, e in ipairs(out) do
    local text = e.message or ""
    if #text > MAX_MSG then text = text:sub(1, MAX_MSG) .. "..." end
    queueSend("H" .. FS .. (e.author or "?") .. FS .. e.epoch .. FS .. text)
  end
end

-- Split on FS but cap the piece count, so message text (the last piece) is taken verbatim even if
-- it happens to contain a stray FS byte — it's never chopped up looking for more separators.
local function splitFields(payload, maxParts)
  local parts, from = {}, 1
  for i = 1, maxParts - 1 do
    local at = payload:find(FS, from, true)
    if not at then return nil end
    parts[i] = payload:sub(from, at - 1)
    from = at + 1
  end
  parts[maxParts] = payload:sub(from)
  return parts
end

local hasSynced = false
local function requestSync()
  if hasSynced or not IsInGuild or not IsInGuild() then return end
  hasSynced = true
  local s = store()
  local since = s and s.newest or 0
  SendAddonMessage(PREFIX, "R" .. FS .. since, "GUILD")
end

local ev = CreateFrame("Frame")
ev:RegisterEvent("CHAT_MSG_GUILD")
ev:RegisterEvent("CHAT_MSG_OFFICER")
ev:RegisterEvent("CHAT_MSG_ADDON")
ev:RegisterEvent("PLAYER_ENTERING_WORLD")
ev:RegisterEvent("GUILD_ROSTER_UPDATE")
ev:SetScript("OnEvent", function(_, event, a1, a2, a3)
  if event == "GUILD_ROSTER_UPDATE" then
    refreshRosterClasses()
    return
  end

  if event == "PLAYER_ENTERING_WORLD" then
    refreshRosterClasses()
    if GuildRoster then GuildRoster() end   -- request a fresh roster so classes resolve promptly
    C_Timer.After(5, requestSync)   -- let the guild roster populate first
    return
  end

  if event == "CHAT_MSG_GUILD" or event == "CHAT_MSG_OFFICER" then
    local message, author = a1, a2
    local kind = event == "CHAT_MSG_OFFICER" and "OFFICER" or "GUILD"
    local epoch = time()
    remember(kind == "OFFICER" and "O" or "G", author, message, epoch)
    appendGuild(kind, message, author, epoch)
    return
  end

  -- CHAT_MSG_ADDON: prefix, message, channel
  local prefix, payload, channel = a1, a2, a3
  if prefix ~= PREFIX or channel ~= "GUILD" then return end
  local tag = payload:sub(1, 1)

  if tag == "R" then
    local since = tonumber(payload:sub(3))
    if since then
      -- Stagger replies so a login doesn't make every online guildmate answer at once.
      C_Timer.After(0.5 + math.random() * 2.5, function() replyWithHistory(since) end)
    end
  elseif tag == "H" then
    local parts = splitFields(payload:sub(3), 3)
    if not parts then return end
    local author, epoch, text = parts[1], tonumber(parts[2]), parts[3]
    if author and epoch and text then
      local isNew = remember("G", author, text, epoch)
      if isNew then
        local f = G.frame
        local log = f and f.ChatFrame and f.ChatFrame.Log
        if log then printBacklogLine(log, "G", author, text, epoch) end
      end
    end
  end
end)
