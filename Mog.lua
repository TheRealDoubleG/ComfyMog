ComfyMog=ComfyMog or {}
local A=ComfyMog
local function Status(link)
 if not link or not C_TransmogCollection or type(C_TransmogCollection.GetItemInfo)~="function" then return nil end
 local ok,appearanceID,sourceID=pcall(C_TransmogCollection.GetItemInfo,link); if not ok or not sourceID then return nil end
 local collected=nil
 if type(C_TransmogCollection.GetAppearanceInfoBySource)=="function" then local ok2,info=pcall(C_TransmogCollection.GetAppearanceInfoBySource,sourceID); if ok2 and type(info)=="table" and info.isCollected~=nil then collected=info.isCollected and true or false end end
 if collected==nil and type(C_TransmogCollection.GetAppearanceSourceInfo)=="function" then local v={pcall(C_TransmogCollection.GetAppearanceSourceInfo,sourceID)}; if v[1] then for i=2,#v do if type(v[i])=="boolean" then collected=v[i] and true or false; break end end end end
 local canCollect=nil
 if type(C_TransmogCollection.PlayerCanCollectSource)=="function" then local ok3,v=pcall(C_TransmogCollection.PlayerCanCollectSource,sourceID); if ok3 then canCollect=v and true or false end end
 return collected,canCollect,sourceID,appearanceID
end
function A:AddTooltipStatus(t, link)
 if not self.db or not self.db.enabled or not t then return end
 if not link and type(t.GetItem)=="function" then local _,itemLink=t:GetItem(); link=itemLink end
 if not link or t.__ComfyMogLink==link then return end; t.__ComfyMogLink=link
 local collected,canCollect,sourceID=Status(link); if collected==nil and canCollect==nil then return end
 if collected and self.db.mog.showCollected then t:AddLine(self:T("COLLECTED"),.2,1,.2) elseif collected==false and self.db.mog.showUncollected then t:AddLine(self:T("NOT_COLLECTED"),1,.35,.2) end
 if canCollect==false then t:AddLine(self:T("CANNOT_COLLECT"),.7,.7,.7) end
 if self.db.mog.showSourceID and sourceID then t:AddLine("Source ID: "..tostring(sourceID),.55,.55,.55) end
 t:Show()
end
function A:InitializeFeature()
 if TooltipDataProcessor and type(TooltipDataProcessor.AddTooltipPostCall)=="function" and Enum and Enum.TooltipDataType and Enum.TooltipDataType.Item then
  TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item,function(t,data)
   local link=data and data.hyperlink
   if not link and data and data.guid and C_Item and type(C_Item.GetItemLinkByGUID)=="function" then
    local ok,v=pcall(C_Item.GetItemLinkByGUID,data.guid); if ok then link=v end
   end
   A:AddTooltipStatus(t,link)
  end)
  for _,t in ipairs({GameTooltip,ItemRefTooltip}) do if t and type(t.HookScript)=="function" then t:HookScript("OnHide",function(x) x.__ComfyMogLink=nil end) end end
 else
  for _,t in ipairs({GameTooltip,ItemRefTooltip}) do
   if t and type(t.HookScript)=="function" then
    pcall(t.HookScript,t,"OnTooltipSetItem",function(x) A:AddTooltipStatus(x) end)
    t:HookScript("OnHide",function(x) x.__ComfyMogLink=nil end)
   end
  end
 end
end
function A:RefreshFeature() end
function A:BuildGeneralOptions(page,ui) ui.CreateCheck(page,A:T("SHOW_COLLECTED"),20,-95,function() return A.db.mog.showCollected end,function(v) A.db.mog.showCollected=v end); ui.CreateCheck(page,A:T("SHOW_UNCOLLECTED"),20,-130,function() return A.db.mog.showUncollected end,function(v) A.db.mog.showUncollected=v end); ui.CreateCheck(page,A:T("SHOW_SOURCE"),20,-165,function() return A.db.mog.showSourceID end,function(v) A.db.mog.showSourceID=v end); local n=page:CreateFontString(nil,"ARTWORK","GameFontHighlightSmall"); n:SetPoint("TOPLEFT",20,-245); n:SetWidth(680); n:SetJustifyH("LEFT"); n:SetText(A:T("FOREVER_NOTE")) end
