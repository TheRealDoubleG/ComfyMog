ComfyMog = ComfyMog or {}
local A = ComfyMog

A.version = "0.6"
A.buildDate = "04.10.2026"

local function EnsureDefaults()
    if not A.db then return end
    A.db.mog = A.db.mog or {}
    if A.db.mog.scanInspectedPlayers == nil then A.db.mog.scanInspectedPlayers = true end
end

local originalInitializeDB = A.InitializeDB
function A:InitializeDB(...)
    local result
    if originalInitializeDB then result = originalInitializeDB(self, ...) end
    EnsureDefaults()
    return result
end

local function FindInspectUnit(guid)
    if type(UnitGUID) ~= "function" then return nil end
    for _, unit in ipairs({"target", "mouseover", "focus"}) do
        local ok, unitGUID = pcall(UnitGUID, unit)
        if ok and unitGUID and unitGUID == guid then return unit end
    end
    return nil
end

function A:ScanInspectedPlayer(guid)
    EnsureDefaults()
    if not self.db or not self.db.enabled or not self.db.mog.scanInspectedPlayers then return end
    if type(GetInventoryItemLink) ~= "function" then return end

    local unit = FindInspectUnit(guid)
    if not unit then return end

    for slot = 1, 19 do
        local ok, link = pcall(GetInventoryItemLink, unit, slot)
        if ok and link then self:RecordSeen(link, "inspect") end
    end

    if self.browser and self.browser:IsShown() then self:RefreshBrowser() end
end

local e = CreateFrame("Frame")
pcall(e.RegisterEvent, e, "INSPECT_READY")
e:SetScript("OnEvent", function(_, _, guid)
    A:ScanInspectedPlayer(guid)
end)
A.inspectScannerEventFrame = e

local originalBuildGeneralOptions = A.BuildGeneralOptions
function A:BuildGeneralOptions(page, ui)
    if originalBuildGeneralOptions then originalBuildGeneralOptions(self, page, ui) end
    EnsureDefaults()
    if not ui then return end
    ui.CreateCheck(page, "Items von inspizierten Spielern merken", 360, -200,
        function() return A.db.mog.scanInspectedPlayers end,
        function(v) A.db.mog.scanInspectedPlayers = v end)
end
