local ADDON_NAME = ...

ComfyMog=ComfyMog or {}
local A=ComfyMog
A.name=ADDON_NAME or "ComfyMog"
A.version="0.4"
A.buildDate="28.09.2026"
A.status="Beta"
A.gameVersion="WoW Forever 1.60.1"
A.targetBuild="70009"
A.interface=16001
A.author="TheRealDoubleG"
A.discord="the.real.double.g"
A.github="https://github.com/TheRealDoubleG/ComfyMog"
local defaults={
    enabled = true,
    mog = {
        showCollected = true,
        showUncollected = true,
        showSourceID = false,
    },
    optionsWindow = {
        point = "CENTER",
        relativePoint = "CENTER",
        x = 0,
        y = 20,
    },
    ui = {
        windowLocked = false,
        windowOpacity = 100,
        showWindowBorder = true,
        backgroundAlpha = 92,
    },
}
local function CopyTable(src) if type(src)~="table" then return src end local d={} for k,v in pairs(src) do d[k]=CopyTable(v) end return d end
local function ApplyDefaults(dst,src) if type(dst)~="table" or type(src)~="table" then return end for k,v in pairs(src) do if type(v)=="table" then if type(dst[k])~="table" then dst[k]={} end ApplyDefaults(dst[k],v) elseif dst[k]==nil then dst[k]=v end end end
function A:Print(msg) if DEFAULT_CHAT_FRAME then DEFAULT_CHAT_FRAME:AddMessage("|cffffd200ComfyMog:|r "..tostring(msg)) end end
function A:GetClientBuildInfo() if type(GetBuildInfo)~="function" then return "?","?","?",nil end local v,b,d,i=GetBuildInfo(); return tostring(v or "?"),tostring(b or "?"),tostring(d or "?"),tonumber(i) end
function A:GetCompatibilityStatus() local _,_,_,i=self:GetClientBuildInfo(); if i and tonumber(i)==tonumber(self.interface) then return true,self:T("COMPAT_MATCH") end return false,self:T("COMPAT_UPDATE_REQUIRED") end
function A:InitializeDB() if self.InitializeProfileStorage then self:InitializeProfileStorage(defaults,"ComfyMogDB") else if type(_G["ComfyMogDB"])~="table" then _G["ComfyMogDB"]=CopyTable(defaults) else ApplyDefaults(_G["ComfyMogDB"],defaults) end self.db=_G["ComfyMogDB"] end end
function A:SetEnabled(v) if not self.db then return false end self.db.enabled=v and true or false if self.RefreshFeature then self:RefreshFeature() end if self.RefreshOptions then self:RefreshOptions() end return true end
function A:GetComfyProfileProvider() return self end
function A:OpenOptions() if self.ShowOptions then self:ShowOptions() end end
SLASH_COMFYMOG1="/comfymog" SLASH_COMFYMOG2="/cmog"
SlashCmdList.COMFYMOG=function(msg) msg=tostring(msg or ""):lower():match("^%s*(.-)%s*$"); if A.HandleSlash and A:HandleSlash(msg) then return end; A:OpenOptions() end
local e=CreateFrame("Frame"); e:RegisterEvent("ADDON_LOADED"); e:RegisterEvent("PLAYER_LOGIN")
e:SetScript("OnEvent",function(_,ev,arg1) if ev=="ADDON_LOADED" and arg1==A.name then A:InitializeDB(); if A.InitializeFeature then A:InitializeFeature() end; if A.InitializeOptions then A:InitializeOptions() end elseif ev=="PLAYER_LOGIN" and A.RefreshFeature then A:RefreshFeature() end end)
