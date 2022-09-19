local game = Game()
local blacklist
local holdMapDesc
local currentPlayer
EID.InsideItemReminder = false

-- Simple function to help with adding properly formatted sections to the desc
local function append(icon, title, newDesc)
	holdMapDesc = holdMapDesc .. (icon or "{{Blank}}") .. " {{ColorEIDObjName}}" .. title .. "#" .. newDesc .. "#"
end

-- Simple function to quickly get an item's RNG seed. We have no use for the RNG object itself because every other function it can do will advance the item's RNG, altering the game state
local function getSeed(id, variant)
	if variant == nil or variant == 100 then return currentPlayer:GetCollectibleRNG(id):GetSeed()
	elseif variant == 350 then return currentPlayer:GetTrinketRNG(id):GetSeed()
	elseif variant == 300 then return currentPlayer:GetCardRNG(id):GetSeed()
	elseif variant == 70 then return currentPlayer:GetPillRNG(id):GetSeed() end
end

-- Helper function to easily add an item's stock description to the desc
-- Don't use if you need to customize the desc! (Like Sanguine Bond's result highlighting)
-- extraIcon is for when we want a special icon before the line (like {{Dice Bag Icon}} {{Dice Item Icon}})
local variantToName = { [70] = "Pill", [100] = "Collectible", [300] = "Card", [350] = "Trinket" }
local function addObjectDesc(type, variant, subtype, extraIcon)
	local objectID = type .. "." .. variant .. "." .. subtype
	if not blacklist[objectID] then
		blacklist[objectID] = true
		local demoDescObj = EID:getDescriptionObj(type, variant, subtype)
		local iconString = "{{" .. variantToName[variant] .. subtype .. "}}"
		if extraIcon then iconString = extraIcon .. " " .. iconString end
		append(iconString, demoDescObj.Name, demoDescObj.Description)
	end
end

-- Data Tables --
-- Rainbow Worm's trinket IDs it grants, in order
local rainbowWormEffects = { [0] = 9, 11, 65, 27, 10, 12, 26, 66, 96, 144 }
-- Mysterious Paper does not play well with displaying Error 404's effect
local mysteriousPaperBlacklist = { [23] = true, [48] = true }


function EID:getHoldMapDescription(player, checkingTwin)
	EID.InsideItemReminder = true
	-- Starting Blacklist: Recall, Hold
	blacklist = { ["5.100.714"] = true, ["5.100.715"] = true, }
	holdMapDesc = ""

	currentPlayer = player
	
	-- TODO:
	-- D1, crooked penny cheats. 404/liberty cap/etc. "what item is it"
	-- (Zodiac and Modeling Clay have functions for it?)
	-- pandora's box? it shows the whole desc which is kinda useful but too big
	-- Void's absorbed items list
	-- D Infinity current dice; track our Drop presses and resync it each time D Infinity is used by watching for the next dice effect triggered (Predict its next dice in AB+?)
	
	-- Tainted ??? Poop Descriptions
	if REPENTANCE and EID.Config["ItemReminderShowPoopDesc"] > 0 and player:GetPlayerType() == 25 then
		for i = 0, EID.Config["ItemReminderShowPoopDesc"]-1 do
			local poopInfo = EID:getDescriptionEntry("poopSpells")
			local nextPoop = player:GetPoopSpell(i)
			append("{{PoopSpell" .. nextPoop .. "}}", poopInfo[nextPoop][1], poopInfo[nextPoop][2])
		end
	end
	
	-- Echo Chamber Description
	if REPENTANCE and player:HasCollectible(700) then
		local playerID = EID:getPlayerID(player)
		local pickupHistory = EID.PlayerItemInteractions[playerID].pickupHistory
		-- Dead Tainted Lazarus exception
		if player:GetPlayerType() == 38 then
			pickupHistory = EID.PlayerItemInteractions[playerID].altPickupHistory or pickupHistory
		end
		if pickupHistory then
			local pickupNames = ""
			for i = 1, math.min(3, #pickupHistory) do
				if pickupHistory[i][4] then -- Echo chamber was owned before this card/pill was used
					if pickupHistory[i][1] == "pill" then
						local name = EID:getPillName(pickupHistory[i][3], false)
						pickupNames = pickupNames .. "{{Pill}} " .. name .. "#"
					else
						local name = EID:getObjectName(5, 300, pickupHistory[i][3])
						pickupNames = pickupNames .. "{{Card" .. pickupHistory[i][3] .. "}} " .. name .. "#"
					end
				end
			end
			if pickupNames ~= "" then
				append("{{Collectible700}}", EID:getObjectName(5, 100, 700), pickupNames)
			end
		end
	end

	-- Modeling Clay
	if REPENTANCE and (player:HasTrinket(166) or player:GetEffects():HasTrinketEffect(166)) then
		local modelingClayItem = player:GetModelingClayEffect()
		if modelingClayItem > 0 then
			append("{{Trinket166}}", EID:getObjectName(5, 350, 166),
				"{{Collectible" .. modelingClayItem .. "}} " .. EID:getObjectName(5, 100, modelingClayItem))
			blacklist["5.350.166"] = true
		end
	end

	-- Zodiac
	if player:HasCollectible(CollectibleType.COLLECTIBLE_ZODIAC) then
		local zodiacItem = player:GetZodiacEffect()
		if zodiacItem > 0 then
			local descObj = EID:getDescriptionObj(5,100,CollectibleType.COLLECTIBLE_ZODIAC)
			append("{{Collectible392}}", EID:getObjectName(5, 100, 392),
			descObj.Description.."#{{Collectible" .. zodiacItem .. "}} {{ColorYellow}}" .. EID:getObjectName(5, 100, zodiacItem))
			blacklist["5.100.392"] = true
		end
	end

	-- Recently Acquired Item Descriptions
	if EID.Config["ItemReminderShowRecentItem"] > 0 then
		local printedItems = 0
		local playerNum = EID:getPlayerID(player)
		if EID.RecentlyTouchedItems[playerNum] then
			for i = #EID.RecentlyTouchedItems[playerNum], 1, -1 do
				if printedItems >= EID.Config["ItemReminderShowRecentItem"] then break end
				printedItems = printedItems + 1
				local recentID = EID.RecentlyTouchedItems[playerNum][i] % 4294967296
				addObjectDesc(5, 100, recentID)
			end
		end
	end
	
	-- Active Item Descriptions
	if EID.Config["ItemReminderShowActiveDesc"] > 0 then
		for i = 0, EID.Config["ItemReminderShowActiveDesc"]-1 do
			-- the modulo is to convert negative IDs (glitched items) to positive IDs
			local heldActive = player:GetActiveItem(i) % 4294967296
			if heldActive > 0 and not blacklist["5.100." .. heldActive] then
				-- Metronome result
				if heldActive == 488 and EID.Config["ItemReminderShowRNGCheats"] then
					blacklist["5.100.488"] = true
					addObjectDesc(5, 100, EID:MetronomePrediction(getSeed(488)), "{{Collectible488}}")
				-- Teleport! location
				elseif heldActive == 44 and EID.Config["ItemReminderShowRNGCheats"] then
					blacklist["5.100.44"] = true
					-- The result preview changes as soon as we activate Teleport, which looks awkward, so try to not display the result while mid-teleport. Doesn't work perfectly and only in Rep
					if not REPENTANCE or player:GetSprite():GetAnimation() ~= "TeleportUp" then
						append("{{Collectible44}}", EID:getObjectName(5,100,44) .. EID:getDescriptionEntry("HoldMapHeader"), EID:Teleport1Prediction(getSeed(44)))
					end
				-- Teleport 2.0 location
				elseif heldActive == 419 and not EID.isMirrorRoom then
					blacklist["5.100.419"] = true
					append("{{Collectible419}}", EID:getObjectName(5,100,419) .. EID:getDescriptionEntry("HoldMapHeader"), EID:Teleport2Prediction())
				-- D Infinity
				elseif heldActive == 489 then
					blacklist["5.100.489"] = true
					addObjectDesc(5, 100, EID:CurrentDInfinity(getSeed(489), player), "{{Collectible489}}")
				-- D1
				elseif heldActive == 476 and EID.Config["ItemReminderShowRNGCheats"] then
					blacklist["5.100.476"] = true
					append("{{Collectible476}}", EID:getObjectName(5,100,476) .. EID:getDescriptionEntry("HoldMapHeader"), EID:D1Prediction(getSeed(476)))
				-- Void
				elseif heldActive == 477 then
					local absorbedActives = ""
					local printNormalDesc = true
					local absorbedItems = EID.absorbedItems[tostring(EID:getPlayerID(player))]
					if absorbedItems then
						local countItems = 0
						for _, _ in pairs(absorbedItems) do
							countItems = countItems + 1
						end
						if countItems > 0 then
							if countItems > 5 then
								absorbedActives = "{{Blank}} "
							end
							for k, _ in pairs(absorbedItems) do
								absorbedActives = absorbedActives .. "{{Collectible" .. k .. "}} "
								if countItems <= 5 then
									absorbedActives = absorbedActives .. EID:getObjectName(5, 100, tonumber(k)) .. "#"
								end
							end
							blacklist["5.100.477"] = true
							append("{{Collectible477}}", EID:getObjectName(5, 100, 477) .. EID:getDescriptionEntry("HoldMapHeader"), absorbedActives)
							printNormalDesc = false
						end
					end
					if printNormalDesc then addObjectDesc(5, 100, heldActive) end
				else
					addObjectDesc(5, 100, heldActive)
				end
			end
		end
	end
	
	-- Pocket Item Descriptions
	-- Annoying because there's no easy way to just get the info of a slot
	if EID.Config["ItemReminderShowPocketDesc"] > 0 then
		local numPrinted = 0
		-- I don't think we can actually know what slot the player is on, so, save these to display (if they exist) for when Card and Pill in a slot are both 0, to attempt to always show them in slot order
		local dicePrinted = false
		local diceBag = REPENTANCE and player:GetActiveItem(3) or 0
		local pocketPrinted = false
		local pocketActive = REPENTANCE and player:GetActiveItem(2) or 0
		for i = 0, EID.Config["ItemReminderShowPocketDesc"]-1 do
			local heldCard = player:GetCard(i)
			local heldPill = player:GetPill(i)
			if heldCard > 0 then
				addObjectDesc(5, 300, heldCard)
			elseif heldPill > 0 then
				-- Check if our held pill is identified
				EID.pillPlayer = player
				local identified = game:GetItemPool():IsPillIdentified(heldPill)
				if REPENTANCE and heldPill % PillColor.PILL_GIANT_FLAG == PillColor.PILL_GOLD then identified = true end
				if (identified or EID.Config["ShowUnidentifiedPillDescriptions"]) then
					addObjectDesc(5, 70, heldPill)
				end
				EID.pillPlayer = nil
			elseif diceBag > 0 and not dicePrinted then
				dicePrinted = true
				addObjectDesc(5, 100, diceBag, "{{Trinket154}}")
			elseif pocketActive > 0 and not pocketPrinted then
				pocketPrinted = true
				addObjectDesc(5, 100, pocketActive)
				-- we'll have to add tainted char specific text for their actives with unique effects for that character!
			end
		end
	end
	
	-- Trinket Descriptions
	if EID.Config["ItemReminderShowTrinketDesc"] > 0 then
		for t = 0, EID.Config["ItemReminderShowTrinketDesc"]-1 do
			local heldTrinket = player:GetTrinket(t)
			if heldTrinket > 0 and not blacklist["5.350." .. heldTrinket] then
				-- Rainbow Worm
				if EID.Config["ItemReminderShowHiddenInfo"] and heldTrinket == 64 then
					blacklist["5.350.64"] = true
					local rainbowWormEffect = rainbowWormEffects[math.floor(game.TimeCounter / 30 / 3) % (REPENTANCE and 10 or 8)]
					addObjectDesc(5, 350, rainbowWormEffect, "{{Trinket64}}")
				-- 404 Error
				-- Unfortunately, includes other temporary trinket givers, such as Glitched Items. We'd need to predict 404's result using RNG to actually know which it specifically is granting
				-- And unfortunately, HasTrinket can't differentiate between real and fake trinkets in AB+
				elseif EID.Config["ItemReminderShowHiddenInfo"] and REPENTANCE and heldTrinket == 75 then
					blacklist["5.350.75"] = true
					-- Don't display Mysterious Paper's 1-frame temporary trinket granting
					local hasPaper = player:HasTrinket(21)
					for i = 1, TrinketType.NUM_TRINKETS - 1 do
						local tempTrinketFound = player:HasTrinket(i, true) ~= player:HasTrinket(i, false)
						if tempTrinketFound and (not mysteriousPaperBlacklist[i] or not hasPaper) then
							addObjectDesc(5, 350, i, "{{Trinket75}}")
						end
					end
				else
					addObjectDesc(5, 350, heldTrinket)
				end
				
			end
		end
	end
	
	--
	
	-- Finally, check the twin player of this controller
	-- If both twins have a desc, show their player icon / name to separate the two descs
	if REPENTANCE and not checkingTwin then
		local twin = player:GetOtherTwin()
		local mainTwinDesc = holdMapDesc
		local otherTwinDesc = ""
		if twin then otherTwinDesc = EID:getHoldMapDescription(twin, true) end
		if otherTwinDesc ~= "" then
			-- Only the other twin had a desc
			if mainTwinDesc == "" then holdMapDesc = otherTwinDesc
			else
				-- Both twins had a desc; merge them with player icon headers
				holdMapDesc = (EID:getIcon("Player"..player:GetPlayerType()) ~= EID.InlineIcons["ERROR"] and "{{Player"..player:GetPlayerType().."}}" or "{{CustomTransformation}}") .. " {{ColorGray}}" .. player:GetName() .. "#" .. mainTwinDesc .. "#"
				holdMapDesc = holdMapDesc .. (EID:getIcon("Player"..twin:GetPlayerType()) ~= EID.InlineIcons["ERROR"] and "{{Player"..twin:GetPlayerType().."}}" or "{{CustomTransformation}}") .. " {{ColorGray}}" .. twin:GetName() .. "#" .. otherTwinDesc
			end
		else
			-- Only the main twin had a desc
			holdMapDesc = mainTwinDesc
		end
	end
	
	EID.InsideItemReminder = false
	return holdMapDesc
end
