-- DragonUI_NewEra/modules/guild/Chat.lua — Guild chat (CHAT mode).
--
-- DOWNPORT of NewEra/Guild/Chat.lua. NewEra uses retail's C_Club stream + CommunitiesChatFrame.
-- On 3.3.5a there is no C_Club: guild chat is the CHAT_MSG_GUILD / CHAT_MSG_OFFICER channels. We
-- mirror those into a ScrollingMessageFrame and send via SendChatMessage(msg, "GUILD").

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
end

local function appendGuild(kind, message, author)
  local f = G.frame
  local log = f and f.ChatFrame and f.ChatFrame.Log
  if not log then return end
  local r, g, b = chanColor(kind)
  local prefix = author and ("[" .. author .. "]: ") or ""
  log:AddMessage(prefix .. (message or ""), r, g, b)
end
G.AppendGuildMessage = appendGuild

local ev = CreateFrame("Frame")
ev:RegisterEvent("CHAT_MSG_GUILD")
ev:RegisterEvent("CHAT_MSG_OFFICER")
ev:SetScript("OnEvent", function(_, event, message, author)
  appendGuild(event == "CHAT_MSG_OFFICER" and "OFFICER" or "GUILD", message, author)
end)
