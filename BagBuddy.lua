function BagBuddy_OnLoad(self)
  UIPanelWindows["BagBuddy"] = {
    area = "left",
    pushable = 1,
    whileDead = 1,
  }

  SetPortraitToTexture(self.portrait, "Interface\\Icons\\INV_Misc_EngGizmos_30")

  -- Create the item slots
  self.items = {}
  for idx = 1, 24 do
    local item = CreateFrame("Button", "BagBuddy_Item" .. idx, self, "BagBuddyItemTemplate")
    item:RegisterForClicks("RightButtonUp")
    self.items[idx] = item
    if idx == 1 then
      item:SetPoint("TOPLEFT", 40, -73)
    elseif idx == 7 or idx == 13 or idx == 19 then
      item:SetPoint("TOPLEFT", self.items[idx-6], "BOTTOMLEFT", 0, -7)
    else
      item:SetPoint("TOPLEFT", self.items[idx-1], "TOPRIGHT", 12, 0)
    end
  end

  -- Create the filter buttons
  self.filters = {}
  for idx=0,5 do
    local button = CreateFrame("CheckButton", "BagBuddy_Filter" .. idx, self, "BagBuddyFilterTemplate")
    SetItemButtonTexture(button, "Interface\\ICONS\\INV_Misc_Gem_Pearl_03")
    self.filters[idx] = button
    if idx == 0 then
      button:SetPoint("BOTTOMLEFT", 40, 200)
    else
      button:SetPoint("TOPLEFT", self.filters[idx-1], "TOPRIGHT", 12, 0)
    end

    -- This code has changed since the printing of the book, and has been
    -- altered to work with 'heirloom' items instead of 'legendary' items,
    -- since most users are likely to have the first and not the second.
    -- This just sets the quality and color to match heirloom rather than
    -- legendary when creating the last button.
    if idx == 5 then
        idx = 7
    end
    button.icon:SetVertexColor(GetItemQualityColor(idx))
    button:SetChecked(false)
    button.quality = idx
    button.glow:Hide()
  end

  -- Map -1 (poor) quality items to the filter button 0 (poor)
  -- Map 7 (heirloom) quality items to the filter button 5 (legendary) 
  self.filters[-1] = self.filters[0]
  self.filters[7] = self.filters[5]

  -- Initialize to show the first page
  self.page = 1

  self.bagCounts = {}

  self:RegisterEvent("ADDON_LOADED")
end

local function itemNameSort(a, b)
  return a.name < b.name
end

local function itemTimeNameSort(a, b)
  -- If the two items were looted at the same time
  local aTime = BagBuddy_ItemTimes[a.num]
  local bTime = BagBuddy_ItemTimes[b.num]
  if aTime == bTime then
    return a.name < b.name
  else
    return aTime >= bTime
  end
end

function BagBuddy_Update()
  local items = {}

  local nameFilter = BagBuddy.input:GetText():lower()

  -- Scan through the bag slots, looking for items
  for bag = 0, NUM_BAG_SLOTS do
    for slot = 1, GetContainerNumSlots(bag) do
      -- This code has changed since the book was printed. The return from
      -- GetContainerItemInfo is not consistent for all items, so we will
      -- use the return from GetItemInfo instead.
      local texture, count, locked, qualityBroken, readable, lootable, link = GetContainerItemInfo(bag, slot)

      if texture then
        -- Fetch the name and quality returns so we can use them later
        local name, link, quality = GetItemInfo(link)
        local shown = true


        if BagBuddy.qualityFilter then
          shown = shown and BagBuddy.filters[quality]:GetChecked()
        end

        if #nameFilter > 0 then
          local lowerName = name:lower()
          shown = shown and string.find(lowerName, nameFilter, 1, true)
        end


        if shown then
          -- If an item is found, grab the item number and store other data
          local itemNum = tonumber(link:match("|Hitem:(%d+):"))

          if not items[itemNum] then
            items[itemNum] = {
              texture = texture,
              count = count,
              quality = quality,
              name = GetItemInfo(link),
              link = link,
              num = itemNum,
            }
          else
            -- The item already exists in our table, just update the count
            items[itemNum].count = items[itemNum].count + count
          end
        end
      end
    end
  end

  local sortTbl = {}
  for link, entry in pairs(items) do
    table.insert(sortTbl, entry)
  end
  table.sort(sortTbl, itemTimeNameSort)

  -- Now update the BagBuddyFrame with the listed items (in order)
  local max = BagBuddy.page * 24
  local min = max - 23

  for idx = min, max do
    local button = BagBuddy.items[idx - min + 1]
    local entry = sortTbl[idx]

    if entry then
      -- There is an item in this slot

      button:SetAttribute("item2", entry.name)
      button.link = entry.link
      button.icon:SetTexture(entry.texture)
      if entry.count > 1 then
        button.count:SetText(entry.count)
        button.count:Show()
      else
        button.count:Hide()
      end

      if entry.quality > 1 then
        button.glow:SetVertexColor(GetItemQualityColor(entry.quality))
        button.glow:Show()
      else
        button.glow:Hide()
      end
      button:Show()
    else
      button.link = nil
      button:Hide()
    end
  end

  -- Update page buttons
  if min > 1 then
    BagBuddy.prev:Enable()
  else
    BagBuddy.prev:Disable()
  end
  if max < #sortTbl then
    BagBuddy.next:Enable()
  else
    BagBuddy.next:Disable()
  end

  -- Update the status text
  if #sortTbl > 24 then
    local max = math.min(max, #sortTbl)
    local msg = string.format("Showing items %d - %d of %d", min, max, #sortTbl)
    BagBuddy.status:SetText(msg)
  else
    BagBuddy.status:SetText("Found " .. #sortTbl .. " items")
  end

end 

function BagBuddy_Button_OnEnter(self, motion)
  if self.link then
    GameTooltip:SetOwner(self, "ANCHOR_TOPRIGHT")
    GameTooltip:SetHyperlink(self.link)
    GameTooltip:Show()
  end
end

function BagBuddy_Button_OnLeave(self, motion)
  GameTooltip:Hide()
end

function BagBuddy_Filter_OnEnter(self, motion)
  GameTooltip:SetOwner(self, "ANCHOR_TOPRIGHT")
  GameTooltip:SetText(_G["ITEM_QUALITY" .. self.quality .. "_DESC"])
  GameTooltip:Show()
end

function BagBuddy_Filter_OnLeave(self, motion)
  GameTooltip:Hide()
end

function BagBuddy_Filter_OnClick(self, button)
  BagBuddy.qualityFilter = false
  for idx = 0, 5 do
    local button = BagBuddy.filters[idx]
    if button:GetChecked() then
      BagBuddy.qualityFilter = true
    end
  end
  BagBuddy.page = 1
  BagBuddy_Update()
end

function BagBuddy_NextPage(self)
  BagBuddy.page = BagBuddy.page + 1
  BagBuddy_Update(BagBuddy)
end

function BagBuddy_PrevPage(self)
  BagBuddy.page = BagBuddy.page - 1
  BagBuddy_Update(BagBuddy)
end

function BagBuddy_ScanBag(bag, initial)
  if not BagBuddy.bagCounts[bag] then
    BagBuddy.bagCounts[bag] = {}
  end

  local itemCounts = {}
  for slot = 0, GetContainerNumSlots(bag) do
    local texture, count, locked, quality, readable, lootable, link = GetContainerItemInfo(bag, slot)

    if texture then
      local itemId = tonumber(link:match("|Hitem:(%d+):"))
      if not itemCounts[itemId] then
        itemCounts[itemId] = count
      else
        itemCounts[itemId] = itemCounts[itemId] + count
      end
    end
  end

  if initial then
    for itemId, count in pairs(itemCounts) do
      BagBuddy_ItemTimes[itemId] = BagBuddy_ItemTimes[itemId] or time()
    end
  else
    for itemId, count in pairs(itemCounts) do
      local oldCount = BagBuddy.bagCounts[bag][itemId] or 0
      if count > oldCount then
        BagBuddy_ItemTimes[itemId] = time()
      end
    end
  end

  BagBuddy.bagCounts[bag] = itemCounts
end

function BagBuddy_OnEvent(self, event, ...)
  if event == "ADDON_LOADED" and ... == "BagBuddy" then
    if not BagBuddy_ItemTimes then
      BagBuddy_ItemTimes = {}
    end
    for bag = 0, NUM_BAG_SLOTS do
      -- Use the optional flag to skip updating times
      BagBuddy_ScanBag(bag, true)
    end
    self:UnregisterEvent("ADDON_LOADED")
    self:RegisterEvent("BAG_UPDATE")
  elseif event == "BAG_UPDATE" then
    local bag = ...
    if bag >= 0 then
      BagBuddy_ScanBag(bag)
      if BagBuddy:IsVisible() then
        BagBuddy_Update()
      end
    end
  end
end

SLASH_BAGBUDDY1 = "/bb"
SLASH_BAGBUDDY2 = "/bagbuddy"
SlashCmdList["BAGBUDDY"] = function(msg, editbox)
  BagBuddy.input:SetText(msg)
  ShowUIPanel(BagBuddy)
end
