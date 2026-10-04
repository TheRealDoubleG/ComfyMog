ComfyMog = ComfyMog or {}
local A = ComfyMog

A.version = "0.5"
A.buildDate = "04.10.2026"
A.browserOffset = A.browserOffset or 0
A.browserFilter = A.browserFilter or "all"
A.browserCategory = A.browserCategory or "ALL"

local function Epoch()
    return type(time) == "function" and time() or 0
end

local function CurrentCharacterKey()
    local name = type(UnitName) == "function" and UnitName("player") or "?"
    local realm = type(GetRealmName) == "function" and GetRealmName() or ""
    return tostring(realm or "") .. ":" .. tostring(name or "?")
end

local function EnsureDB()
    if not A.db then return end
    A.db.mog = A.db.mog or {}
    A.db.mog.catalog = A.db.mog.catalog or {}
    A.db.mog.characters = A.db.mog.characters or {}
    if A.db.mog.showOwned == nil then A.db.mog.showOwned = true end
    if A.db.mog.showSeen == nil then A.db.mog.showSeen = true end
    if A.db.mog.scanInventory == nil then A.db.mog.scanInventory = true end
end

local originalInitializeDB = A.InitializeDB
function A:InitializeDB(...)
    local result
    if originalInitializeDB then result = originalInitializeDB(self, ...) end
    EnsureDB()
    return result
end

local function ItemIDFromLink(link)
    if type(link) ~= "string" then return nil end
    return tonumber(link:match("item:(%d+)"))
end

local function GetItemLinkForSlot(bag, slot)
    if C_Container and type(C_Container.GetContainerItemLink) == "function" then
        local ok, link = pcall(C_Container.GetContainerItemLink, bag, slot)
        if ok then return link end
    end
    if type(GetContainerItemLink) == "function" then
        local ok, link = pcall(GetContainerItemLink, bag, slot)
        if ok then return link end
    end
    return nil
end

local function GetNumSlots(bag)
    if C_Container and type(C_Container.GetContainerNumSlots) == "function" then
        local ok, n = pcall(C_Container.GetContainerNumSlots, bag)
        if ok then return tonumber(n) or 0 end
    end
    if type(GetContainerNumSlots) == "function" then
        local ok, n = pcall(GetContainerNumSlots, bag)
        if ok then return tonumber(n) or 0 end
    end
    return 0
end

local function ReadTransmog(link)
    if not link or not C_TransmogCollection or type(C_TransmogCollection.GetItemInfo) ~= "function" then return nil, nil, nil end
    local ok, appearanceID, sourceID = pcall(C_TransmogCollection.GetItemInfo, link)
    if not ok then return nil, nil, nil end

    local collected
    if sourceID and type(C_TransmogCollection.GetAppearanceInfoBySource) == "function" then
        local ok2, info = pcall(C_TransmogCollection.GetAppearanceInfoBySource, sourceID)
        if ok2 and type(info) == "table" and info.isCollected ~= nil then collected = info.isCollected and true or false end
    end
    if collected == nil and sourceID and type(C_TransmogCollection.GetAppearanceSourceInfo) == "function" then
        local values = {pcall(C_TransmogCollection.GetAppearanceSourceInfo, sourceID)}
        if values[1] then
            for i = 2, #values do
                if type(values[i]) == "boolean" then collected = values[i] and true or false; break end
            end
        end
    end
    return collected, sourceID, appearanceID
end

local function ReadItemMeta(link)
    local itemID = ItemIDFromLink(link)
    local name, quality, equipLoc, icon
    if type(GetItemInfo) == "function" then
        local ok, n, _, q, _, _, _, _, loc, tex = pcall(GetItemInfo, link or itemID)
        if ok then name, quality, equipLoc, icon = n, tonumber(q), loc, tex end
    end
    if not icon and itemID and C_Item and type(C_Item.GetItemIconByID) == "function" then
        local ok, tex = pcall(C_Item.GetItemIconByID, itemID); if ok then icon = tex end
    end
    return itemID, name, quality, equipLoc, icon
end

function A:RecordSeen(link, origin)
    EnsureDB()
    if not self.db or not link then return nil end
    local itemID, name, quality, equipLoc, icon = ReadItemMeta(link)
    if not itemID then return nil end
    local collected, sourceID, appearanceID = ReadTransmog(link)
    if collected == nil and not sourceID and not appearanceID then return nil end

    local key = sourceID and ("source:" .. tostring(sourceID)) or ("item:" .. tostring(itemID))
    local r = self.db.mog.catalog[key]
    if type(r) ~= "table" then
        r = {firstSeen=Epoch(), ownedBy={}}
        self.db.mog.catalog[key] = r
    end
    r.key = key
    r.itemID = itemID
    r.link = link
    r.name = name or r.name or ("Item " .. tostring(itemID))
    r.quality = quality or r.quality
    r.equipLoc = equipLoc or r.equipLoc or ""
    r.icon = icon or r.icon
    r.sourceID = sourceID or r.sourceID
    r.appearanceID = appearanceID or r.appearanceID
    if collected ~= nil then r.collected = collected end
    r.lastSeen = Epoch()
    r.lastOrigin = origin or r.lastOrigin or "tooltip"
    r.ownedBy = r.ownedBy or {}
    return r
end

local function MarkOwned(record, location)
    if not record then return end
    local charKey = CurrentCharacterKey()
    record.ownedBy = record.ownedBy or {}
    local entry = record.ownedBy[charKey]
    if type(entry) ~= "table" then entry = {locations={}}; record.ownedBy[charKey] = entry end
    entry.locations = entry.locations or {}
    entry.locations[location] = true
    entry.lastSeen = Epoch()
end

local function ClearCurrentOwnedLocations(prefixes)
    EnsureDB()
    local charKey = CurrentCharacterKey()
    for _, r in pairs(A.db.mog.catalog) do
        local entry = r.ownedBy and r.ownedBy[charKey]
        if entry and entry.locations then
            for location in pairs(entry.locations) do
                for _, prefix in ipairs(prefixes) do
                    if location:sub(1, #prefix) == prefix then entry.locations[location] = nil break end
                end
            end
            if not next(entry.locations) then r.ownedBy[charKey] = nil end
        end
    end
end

function A:ScanInventory(includeBank)
    EnsureDB()
    if not self.db or not self.db.mog.scanInventory then return end
    local charKey = CurrentCharacterKey()
    local char = self.db.mog.characters[charKey] or {}
    self.db.mog.characters[charKey] = char
    char.name = type(UnitName) == "function" and UnitName("player") or char.name
    char.realm = type(GetRealmName) == "function" and GetRealmName() or char.realm
    char.lastScan = Epoch()

    ClearCurrentOwnedLocations({"bag:", "equip:"})
    local bagIDs = {0,1,2,3,4}
    local reagent = _G.REAGENTBAG_CONTAINER
    if reagent and tonumber(reagent) and tonumber(reagent) > 4 then bagIDs[#bagIDs+1] = tonumber(reagent) end
    for _, bag in ipairs(bagIDs) do
        for slot = 1, GetNumSlots(bag) do
            local link = GetItemLinkForSlot(bag, slot)
            if link then MarkOwned(self:RecordSeen(link, "inventory"), "bag:" .. tostring(bag)) end
        end
    end

    if type(GetInventoryItemLink) == "function" then
        for slot = 1, 19 do
            local ok, link = pcall(GetInventoryItemLink, "player", slot)
            if ok and link then MarkOwned(self:RecordSeen(link, "equipped"), "equip:" .. tostring(slot)) end
        end
    end

    if includeBank then
        ClearCurrentOwnedLocations({"bank:"})
        local bankIDs = {}
        local bankContainer = tonumber(_G.BANK_CONTAINER) or -1
        bankIDs[#bankIDs+1] = bankContainer
        local firstBankBag = 5
        local count = tonumber(_G.NUM_BANKBAGSLOTS) or 7
        for i=0,count-1 do bankIDs[#bankIDs+1] = firstBankBag + i end
        local reagentBank = tonumber(_G.REAGENTBANK_CONTAINER)
        if reagentBank then bankIDs[#bankIDs+1] = reagentBank end
        for _, bag in ipairs(bankIDs) do
            for slot=1,GetNumSlots(bag) do
                local link=GetItemLinkForSlot(bag,slot)
                if link then MarkOwned(self:RecordSeen(link,"bank"),"bank:"..tostring(bag)) end
            end
        end
    end

    if self.browser and self.browser:IsShown() then self:RefreshBrowser() end
end

local function OwnedSummary(record)
    local out = {}
    for charKey, entry in pairs(record.ownedBy or {}) do
        local char = A.db.mog.characters and A.db.mog.characters[charKey] or {}
        local locations = {}
        local hasBag, hasEquip, hasBank = false, false, false
        for location in pairs(entry.locations or {}) do
            if location:find("^bag:") then hasBag=true elseif location:find("^equip:") then hasEquip=true elseif location:find("^bank:") then hasBank=true end
        end
        if hasEquip then locations[#locations+1]="ausgerüstet" end
        if hasBag then locations[#locations+1]="Tasche" end
        if hasBank then locations[#locations+1]="Bank" end
        out[#out+1] = (char.name or charKey) .. (#locations>0 and (" ("..table.concat(locations,", ")..")") or "")
    end
    table.sort(out)
    return out
end

local originalAddTooltipStatus = A.AddTooltipStatus
function A:AddTooltipStatus(t, link)
    if not link and t and type(t.GetItem)=="function" then local _, l=t:GetItem(); link=l end
    local record = link and self:RecordSeen(link, "tooltip") or nil
    if originalAddTooltipStatus then originalAddTooltipStatus(self, t, link) end
    if not record or not t or t.__ComfyMogExtraLink == link then return end
    t.__ComfyMogExtraLink = link
    if self.db.mog.showSeen then
        t:AddLine("ComfyMog: gesehen", 0.45, 0.75, 1.00)
    end
    if self.db.mog.showOwned then
        local owners = OwnedSummary(record)
        for i, text in ipairs(owners) do
            t:AddLine((i==1 and "Im Besitz: " or "          ") .. text, 0.35, 1.00, 0.55)
        end
    end
    t:Show()
end

local CATEGORIES = {
    {id="ALL", label="Alle"},
    {id="HEAD", label="Kopf"}, {id="SHOULDER", label="Schulter"}, {id="CHEST", label="Brust"},
    {id="HANDS", label="Hände"}, {id="WAIST", label="Taille"}, {id="LEGS", label="Beine"},
    {id="FEET", label="Füße"}, {id="CLOAK", label="Rücken"}, {id="WEAPON", label="Waffen"},
    {id="OFFHAND", label="Nebenhand"}, {id="OTHER", label="Sonstiges"},
}

local function CategoryOf(record)
    local loc = tostring(record.equipLoc or "")
    if loc == "INVTYPE_HEAD" then return "HEAD" end
    if loc == "INVTYPE_SHOULDER" then return "SHOULDER" end
    if loc == "INVTYPE_CHEST" or loc == "INVTYPE_ROBE" then return "CHEST" end
    if loc == "INVTYPE_HAND" then return "HANDS" end
    if loc == "INVTYPE_WAIST" then return "WAIST" end
    if loc == "INVTYPE_LEGS" then return "LEGS" end
    if loc == "INVTYPE_FEET" then return "FEET" end
    if loc == "INVTYPE_CLOAK" then return "CLOAK" end
    if loc:find("WEAPON") or loc == "INVTYPE_RANGED" or loc == "INVTYPE_RANGEDRIGHT" or loc == "INVTYPE_2HWEAPON" then return "WEAPON" end
    if loc == "INVTYPE_SHIELD" or loc == "INVTYPE_HOLDABLE" then return "OFFHAND" end
    return "OTHER"
end

local function IsOwned(record)
    return record.ownedBy and next(record.ownedBy) ~= nil
end

function A:GetBrowserRecords()
    EnsureDB()
    local out = {}
    local query = tostring(self.browserSearch or ""):lower()
    for _, r in pairs(self.db.mog.catalog or {}) do
        local matchesState = self.browserFilter == "all"
            or (self.browserFilter == "collected" and r.collected == true)
            or (self.browserFilter == "uncollected" and r.collected == false)
            or (self.browserFilter == "owned" and IsOwned(r))
            or (self.browserFilter == "seen")
        local matchesCategory = self.browserCategory == "ALL" or CategoryOf(r) == self.browserCategory
        local matchesSearch = query == "" or tostring(r.name or ""):lower():find(query, 1, true) ~= nil or tostring(r.itemID or ""):find(query,1,true) ~= nil
        if matchesState and matchesCategory and matchesSearch then out[#out+1] = r end
    end
    table.sort(out, function(a,b)
        if (a.collected==true) ~= (b.collected==true) then return a.collected==true end
        return tostring(a.name or ""):lower() < tostring(b.name or ""):lower()
    end)
    return out
end

local function SetBrowserFilter(filter)
    A.browserFilter=filter; A.browserOffset=0; A:RefreshBrowser()
end
local function SetBrowserCategory(category)
    A.browserCategory=category; A.browserOffset=0; A:RefreshBrowser()
end

function A:CreateBrowser()
    if self.browser then return end
    local f=CreateFrame("Frame","ComfyMogBrowser",UIParent,"BasicFrameTemplateWithInset")
    f:SetSize(940,650); f:SetPoint("CENTER"); f:SetFrameStrata("HIGH"); f:SetClampedToScreen(true); f:SetMovable(true); f:EnableMouse(true); f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart",function(self) self:StartMoving() end); f:SetScript("OnDragStop",function(self) self:StopMovingOrSizing() end)
    f.TitleText:SetText("ComfyMog · Sammlung"); f:Hide(); self.browser=f

    local search=CreateFrame("EditBox",nil,f,"InputBoxTemplate"); search:SetSize(270,28); search:SetPoint("TOPRIGHT",-30,-32); search:SetAutoFocus(false)
    search:SetScript("OnTextChanged",function(self) A.browserSearch=self:GetText() or ""; A.browserOffset=0; A:RefreshBrowser() end); search:SetScript("OnEscapePressed",function(self) self:ClearFocus() end)

    local filters={{"Alle","all"},{"Gesammelt","collected"},{"Nicht gesammelt","uncollected"},{"Im Besitz","owned"},{"Gesehen","seen"}}
    for i,d in ipairs(filters) do
        local b=CreateFrame("Button",nil,f,"UIPanelButtonTemplate"); b:SetSize(115,24); b:SetPoint("TOPLEFT",190+(i-1)*120,-32); b:SetText(d[1]); b:SetScript("OnClick",function() SetBrowserFilter(d[2]) end)
    end

    local catTitle=f:CreateFontString(nil,"ARTWORK","GameFontNormalLarge"); catTitle:SetPoint("TOPLEFT",24,-78); catTitle:SetText("Kategorien")
    for i,d in ipairs(CATEGORIES) do
        local b=CreateFrame("Button",nil,f,"UIPanelButtonTemplate"); b:SetSize(135,24); b:SetPoint("TOPLEFT",24,-105-(i-1)*30); b:SetText(d.label); b:SetScript("OnClick",function() SetBrowserCategory(d.id) end)
    end

    local status=f:CreateFontString(nil,"ARTWORK","GameFontHighlightSmall"); status:SetPoint("BOTTOMLEFT",190,18); status:SetWidth(610); status:SetJustifyH("LEFT"); self.browserStatus=status

    self.browserRows={}
    for i=1,16 do
        local row=CreateFrame("Button",nil,f,"BackdropTemplate"); row:SetSize(715,30); row:SetPoint("TOPLEFT",190,-85-(i-1)*32)
        row:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8"}); row:SetBackdropColor(1,1,1,i%2==0 and 0.035 or 0.015)
        row.icon=row:CreateTexture(nil,"ARTWORK"); row.icon:SetSize(26,26); row.icon:SetPoint("LEFT",2,0); row.icon:SetTexCoord(.07,.93,.07,.93)
        row.name=row:CreateFontString(nil,"ARTWORK","GameFontHighlight"); row.name:SetPoint("LEFT",34,0); row.name:SetWidth(330); row.name:SetJustifyH("LEFT")
        row.state=row:CreateFontString(nil,"ARTWORK","GameFontHighlightSmall"); row.state:SetPoint("LEFT",375,0); row.state:SetWidth(115); row.state:SetJustifyH("LEFT")
        row.owner=row:CreateFontString(nil,"ARTWORK","GameFontHighlightSmall"); row.owner:SetPoint("LEFT",500,0); row.owner:SetWidth(205); row.owner:SetJustifyH("LEFT")
        row:SetScript("OnEnter",function(self)
            if not self.data or not GameTooltip then return end
            GameTooltip:SetOwner(self,"ANCHOR_RIGHT")
            if self.data.link then GameTooltip:SetHyperlink(self.data.link) else GameTooltip:SetText(self.data.name or "?") end
            GameTooltip:Show()
        end)
        row:SetScript("OnLeave",function() if GameTooltip then GameTooltip:Hide() end end)
        self.browserRows[i]=row
    end

    local prev=CreateFrame("Button",nil,f,"UIPanelButtonTemplate"); prev:SetSize(90,24); prev:SetPoint("BOTTOMRIGHT",-126,14); prev:SetText("Zurück"); prev:SetScript("OnClick",function() A.browserOffset=math.max(0,(A.browserOffset or 0)-16); A:RefreshBrowser() end)
    local nextb=CreateFrame("Button",nil,f,"UIPanelButtonTemplate"); nextb:SetSize(90,24); nextb:SetPoint("BOTTOMRIGHT",-30,14); nextb:SetText("Weiter"); nextb:SetScript("OnClick",function() A.browserOffset=(A.browserOffset or 0)+16; A:RefreshBrowser() end)

    f:EnableMouseWheel(true); f:SetScript("OnMouseWheel",function(_,delta) A.browserOffset=math.max(0,(A.browserOffset or 0)+(delta<0 and 4 or -4)); A:RefreshBrowser() end)
end

function A:RefreshBrowser()
    if not self.browser or not self.browser:IsShown() then return end
    local records=self:GetBrowserRecords(); local offset=math.max(0,math.min(tonumber(self.browserOffset) or 0,math.max(0,#records-1))); self.browserOffset=offset
    for i,row in ipairs(self.browserRows) do
        local r=records[offset+i]
        if r then
            row.data=r; row.icon:SetTexture(r.icon or "Interface\\Icons\\INV_Misc_QuestionMark"); row.name:SetText(r.name or ("Item "..tostring(r.itemID or "?")))
            if r.collected==true then row.state:SetText("Gesammelt"); row.state:SetTextColor(.2,1,.2) elseif r.collected==false then row.state:SetText("Nicht gesammelt"); row.state:SetTextColor(1,.35,.2) else row.state:SetText("Gesehen"); row.state:SetTextColor(.45,.75,1) end
            local owners=OwnedSummary(r); row.owner:SetText(#owners>0 and table.concat(owners,"; ") or "—"); row:Show()
        else row.data=nil; row:Hide() end
    end
    if self.browserStatus then self.browserStatus:SetText(string.format("%d Einträge · Filter: %s · Kategorie: %s",#records,tostring(self.browserFilter),tostring(self.browserCategory))) end
end

function A:ShowBrowser()
    self:CreateBrowser(); self.browser:Show(); self.browser:Raise(); self:RefreshBrowser()
end

function A:HandleSlash(msg)
    msg=tostring(msg or ""):lower()
    if msg=="options" or msg=="config" then return false end
    self:ShowBrowser(); return true
end

local originalInitializeFeature=A.InitializeFeature
function A:InitializeFeature(...)
    if originalInitializeFeature then originalInitializeFeature(self,...) end
    EnsureDB()
    local e=CreateFrame("Frame")
    local events={"PLAYER_ENTERING_WORLD","BAG_UPDATE_DELAYED","PLAYER_EQUIPMENT_CHANGED","BANKFRAME_OPENED","GET_ITEM_INFO_RECEIVED"}
    for _,ev in ipairs(events) do pcall(e.RegisterEvent,e,ev) end
    e:SetScript("OnEvent",function(_,ev)
        if ev=="BANKFRAME_OPENED" then A:ScanInventory(true)
        elseif ev=="GET_ITEM_INFO_RECEIVED" then if A.browser and A.browser:IsShown() then A:RefreshBrowser() end
        else
            if C_Timer and C_Timer.After then C_Timer.After(.15,function() A:ScanInventory(false) end) else A:ScanInventory(false) end
        end
    end)
    self.databaseEvents=e
    if C_Timer and C_Timer.After then C_Timer.After(1,function() A:ScanInventory(false) end) else self:ScanInventory(false) end
end

local originalBuildGeneralOptions=A.BuildGeneralOptions
function A:BuildGeneralOptions(page,ui)
    if originalBuildGeneralOptions then originalBuildGeneralOptions(self,page,ui) end
    EnsureDB()
    if not ui then return end
    ui.CreateCheck(page,"Gesehen-Status im Tooltip",360,-95,function() return A.db.mog.showSeen end,function(v) A.db.mog.showSeen=v end)
    ui.CreateCheck(page,"Besitz auf Charakteren anzeigen",360,-130,function() return A.db.mog.showOwned end,function(v) A.db.mog.showOwned=v end)
    ui.CreateCheck(page,"Inventar automatisch scannen",360,-165,function() return A.db.mog.scanInventory end,function(v) A.db.mog.scanInventory=v; if v then A:ScanInventory(false) end end)
    ui.CreateButton(page,"Transmog-Datenbank öffnen",360,-210,220,function() A:ShowBrowser() end)
end
