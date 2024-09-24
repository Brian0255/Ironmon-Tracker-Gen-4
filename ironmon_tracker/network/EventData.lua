EventData = {}

-- Helper Functions and Variables

---Searches for a Pokémon by name, finds the best match; returns 0 if no good match
---@param name string?
---@param threshold number? Default threshold distance of 3
---@return number pokemonId
local function findPokemonId(name, threshold)
	if name == nil or name == "" then
		return 0
	end
	threshold = threshold or 3
	-- Format list of Pokemon as id, name pairs
	local pokemonNames = {}
	for id, pokemon in ipairs(PokemonData.POKEMON) do
		if (pokemon.name ~= "---") then
			pokemonNames[id - 1] = pokemon.name:lower()
		end
	end
	-- Try and find a name match
	local id, _ = NetworkUtils.getClosestWord(name:lower(), pokemonNames, threshold)
	return id or 0
end

---Searches for a Move by name, finds the best match; returns 0 if no good match
---@param name string?
---@param threshold number? Default threshold distance of 3
---@return number moveId
local function findMoveId(name, threshold)
	if name == nil or name == "" then
		return 0
	end
	threshold = threshold or 3
	-- Format list of Moves as id, name pairs
	local moveNames = {}
	for id, move in ipairs(MoveData.MOVES) do
		if (move.name ~= "---") then
			moveNames[id - 1] = move.name:lower()
		end
	end
	-- Try and find a name match
	local id, _ = NetworkUtils.getClosestWord(name:lower(), moveNames, threshold)
	return id or 0
end

---Searches for an Ability by name, finds the best match; returns 0 if no good match
---@param name string?
---@param threshold number? Default threshold distance of 3
---@return number abilityId
local function findAbilityId(name, threshold)
	if name == nil or name == "" then
		return 0
	end
	threshold = threshold or 3
	-- Format list of Abilities as id, name pairs
	local abilityNames = {}
	for id, ability in ipairs(AbilityData.ABILITIES) do
		if (ability.name ~= "---") then
			abilityNames[id - 1] = ability.name:lower()
		end
	end
	-- Try and find a name match
	local id, _ = NetworkUtils.getClosestWord(name:lower(), abilityNames, threshold)
	return id or 0
end

---Searches for a Route by name, finds the best match; returns 0 if no good match
---@param name string?
---@param threshold number? Default threshold distance of 5!
---@return number mapId
local function findRouteId(name, threshold)
	if name == nil or name == "" then
		return 0
	end
	threshold = threshold or 5
	-- If the lookup is just a route number, allow it to be searchable
	if tonumber(name) ~= nil then
		name = string.format("route %s", name)
	end
	local routes = gameInfo and gameInfo.LOCATION_DATA.locations or {}
	-- Format list of Routes as id, name pairs
	local routeNames = {}
	for id, route in pairs(routes) do
		routeNames[id] = (route.name or "Unnamed Route"):lower()
	end
	-- Try and find a name match
	local id, _ = NetworkUtils.getClosestWord(name:lower(), routeNames, threshold)
	return id or 0
end

-- The max # of items to show for any commands that output a list of items (try keep chat message output short)
local MAX_ITEMS = 12
local OUTPUT_CHAR = ">"
local DEFAULT_OUTPUT_MSG = "No info found."

---Returns a response message by combining information into a single string
---@param prefix string? [Optional] Prefixes the response with this header as "HEADER RESPONSE"
---@param infoList table|string? [Optional] A string or list of strings to combine
---@param infoDelimeter string? [Optional] Defaults to " | "
---@return string response Example: "Prefix Info Item 1 | Info Item 2 | Info Item 3"
local function buildResponse(prefix, infoList, infoDelimeter)
	prefix = (prefix or "") ~= "" and (prefix .. " ") or ""
	if not infoList or #infoList == 0 then
		return prefix .. DEFAULT_OUTPUT_MSG
	elseif type(infoList) ~= "table" then
		return prefix .. tostring(infoList)
	else
		return prefix .. table.concat(infoList, infoDelimeter or " | ")
	end
end
local function buildDefaultResponse(input)
	if (input or "") ~= "" then
		return buildResponse()
	else
		return buildResponse(string.format("%s %s", input, OUTPUT_CHAR))
	end
end

local function getPokemonOrDefault(input)
	local id
	if (input or "") ~= "" then
		id = findPokemonId(input)
	else
		local pokemon = Tracker.getPokemon(1, true) or {}
		id = pokemon.pokemonID
	end
	return PokemonData.POKEMON[id or false]
end
local function getMoveOrDefault(input)
	if (input or "") ~= "" then
		return MoveData.Moves[findMoveId(input) or false]
	else
		return nil
	end
end
local function getAbilityOrDefault(input)
	local id
	if (input or "") ~= "" then
		id = findAbilityId(input)
	else
		local pokemon = Tracker.getPokemon(1, true) or {}
		if PokemonData.isValid(pokemon.pokemonID) then
			id = PokemonData.getAbilityId(pokemon.pokemonID, pokemon.abilityNum)
		end
	end
	return AbilityData.ABILITIES[id or false]
end
local function getRouteIdOrDefault(input)
	if (input or "") ~= "" then
		local id = findRouteId(input)
		-- Special check for Route 21 North/South in FRLG
		if not RouteData.Info[id or false] and Utils.containsText(input, "21") then
			-- Okay to default to something in route 21
			return (Utils.containsText(input, "north") and 109) or 219
		else
			return id
		end
	else
		return TrackerAPI.getMapId()
	end
end

-- Data Calculation Functions

---@param params string?
---@return string response
function EventData.getPokemon(params)
	-- TODO: Implement this function
	if true then return buildDefaultResponse(params) end

	local pokemon = getPokemonOrDefault(params)
	if not pokemon then
		return buildDefaultResponse(params)
	end

	local info = {}
	local types
	if pokemon.types[2] ~= PokemonData.Types.EMPTY and pokemon.types[2] ~= pokemon.types[1] then
		types = Utils.formatUTF8("%s/%s", PokemonData.getTypeResource(pokemon.types[1]), PokemonData.getTypeResource(pokemon.types[2]))
	else
		types = PokemonData.getTypeResource(pokemon.types[1])
	end
	local coreInfo = string.format("%s #%03d (%s) %s: %s",
		pokemon.name,
		pokemon.pokemonID,
		types,
		Resources.TrackerScreen.StatBST,
		pokemon.bst
	)
	table.insert(info, coreInfo)
	local evos = table.concat(Utils.getDetailedEvolutionsInfo(pokemon.evolution), ", ")
	table.insert(info, string.format("%s: %s", Resources.InfoScreen.LabelEvolution, evos))
	local moves
	if #pokemon.movelvls[GameSettings.versiongroup] > 0 then
		moves = table.concat(pokemon.movelvls[GameSettings.versiongroup], ", ")
	else
		moves = "None."
	end
	table.insert(info, string.format("%s. %s: %s", Resources.TrackerScreen.LevelAbbreviation, Resources.TrackerScreen.HeaderMoves, moves))
	local trackedPokemon = Tracker.Data.allPokemon[pokemon.pokemonID] or {}
	if (trackedPokemon.eT or 0) > 0 then
		table.insert(info, string.format("%s: %s", Resources.TrackerScreen.BattleSeenOnTrainers, trackedPokemon.eT))
	end
	if (trackedPokemon.eW or 0) > 0 then
		table.insert(info, string.format("%s: %s", Resources.TrackerScreen.BattleSeenInTheWild, trackedPokemon.eW))
	end
	return buildResponse(OUTPUT_CHAR, info)
end

---@param params string?
---@return string response
function EventData.getBST(params)
	-- TODO: Implement this function
	if true then return buildDefaultResponse(params) end
	local pokemon = getPokemonOrDefault(params)
	if not pokemon then
		return buildDefaultResponse(params)
	end

	local info = {}
	table.insert(info, string.format("%s: %s", Resources.TrackerScreen.StatBST, pokemon.bst))
	local prefix = string.format("%s %s", pokemon.name, OUTPUT_CHAR)
	return buildResponse(prefix, info)
end

---@param params string?
---@return string response
function EventData.getWeak(params)
	-- TODO: Implement this function
	if true then return buildDefaultResponse(params) end
	local pokemon = getPokemonOrDefault(params)
	if not pokemon then
		return buildDefaultResponse(params)
	end

	local info = {}
	local pokemonDefenses = PokemonData.getEffectiveness(pokemon.pokemonID)
	local weak4x = Utils.firstToUpperEachWord(table.concat(pokemonDefenses[4] or {}, ", "))
	if not Utils.isNilOrEmpty(weak4x) then
		table.insert(info, string.format("[4x] %s", weak4x))
	end
	local weak2x = Utils.firstToUpperEachWord(table.concat(pokemonDefenses[2] or {}, ", "))
	if not Utils.isNilOrEmpty(weak2x) then
		table.insert(info, string.format("[2x] %s", weak2x))
	end
	local types
	if pokemon.types[2] ~= PokemonData.Types.EMPTY and pokemon.types[2] ~= pokemon.types[1] then
		types = Utils.formatUTF8("%s/%s", PokemonData.getTypeResource(pokemon.types[1]), PokemonData.getTypeResource(pokemon.types[2]))
	else
		types = PokemonData.getTypeResource(pokemon.types[1])
	end

	if #info == 0 then
		table.insert(info, Resources.InfoScreen.LabelNoWeaknesses)
	end

	local prefix = string.format("%s (%s) %s %s", pokemon.name, types, Resources.TypeDefensesScreen.Weaknesses, OUTPUT_CHAR)
	return buildResponse(prefix, info)
end

---@param params string?
---@return string response
function EventData.getMove(params)
	-- TODO: Implement this function
	if true then return buildDefaultResponse(params) end
	local move = getMoveOrDefault(params)
	if not move then
		return buildDefaultResponse(params)
	end

	local info = {}
	table.insert(info, string.format("%s: %s",
		Resources.InfoScreen.LabelContact,
		move.iscontact and Resources.AllScreens.Yes or Resources.AllScreens.No))
	table.insert(info, string.format("%s: %s", Resources.InfoScreen.LabelPP, move.pp or Constants.BLANKLINE))
	table.insert(info, string.format("%s: %s", Resources.InfoScreen.LabelPower, move.power or Constants.BLANKLINE))
	table.insert(info, string.format("%s: %s", Resources.TrackerScreen.HeaderAcc, move.accuracy or Constants.BLANKLINE))
	table.insert(info, string.format("%s: %s", Resources.InfoScreen.LabelMoveSummary, move.summary))
	local prefix = string.format("%s (%s, %s) %s",
		move.name,
		Utils.firstToUpperEachWord(move.type),
		Utils.firstToUpperEachWord(move.category),
		OUTPUT_CHAR)
	return buildResponse(prefix, info)
end

---@param params string?
---@return string response
function EventData.getAbility(params)
	-- TODO: Implement this function
	if true then return buildDefaultResponse(params) end
	local ability = getAbilityOrDefault(params)
	if not ability then
		return buildDefaultResponse(params)
	end

	local info = {}
	table.insert(info, string.format("%s: %s", ability.name, ability.description))
	-- Emerald only
	if GameSettings.game == 2 and ability.descriptionEmerald then
		table.insert(info, string.format("%s: %s", Resources.InfoScreen.LabelEmeraldAbility, ability.descriptionEmerald))
	end
	return buildResponse(OUTPUT_CHAR, info)
end

---@param params string?
---@return string response
function EventData.getRoute(params)
	-- TODO: Implement this function
	if true then return buildDefaultResponse(params) end
	-- Check for optional parameters
	local paramsLower = Utils.toLowerUTF8(params or "")
	local option
	for key, val in pairs(RouteData.EncounterArea or {}) do
		if Utils.containsText(paramsLower, val, true) then
			paramsLower = Utils.replaceText(paramsLower, Utils.toLowerUTF8(val), "", true)
			option = key
			break
		end
	end
	-- If option keywords were removed, trim any whitespace
	if option then
		-- Removes duplicate, consecutive whitespaces, and leading/trailer whitespaces
		paramsLower = ((paramsLower:gsub("(%s)%s+", "%1")):gsub("^%s*(.-)%s*$", "%1"))
	end

	local routeId = getRouteIdOrDefault(paramsLower)
	local route = RouteData.Info[routeId or false]
	if not route then
		return buildDefaultResponse(params)
	end

	local info = {}
	-- Check for trainers in the route, but only if a specific encounter area wasnt requested
	if not option and route.trainers and #route.trainers > 0 then
		local defeatedTrainers, totalTrainers = Program.getDefeatedTrainersByLocation(routeId)
		table.insert(info, string.format("%s: %s/%s", "Trainers defeated", #defeatedTrainers, totalTrainers))
	end
	-- Check for wilds in the route
	local encounterArea
	if option then
		encounterArea = RouteData.EncounterArea[option] or RouteData.EncounterArea.LAND
	else
		-- Default to the first area type (usually Walking)
		encounterArea = RouteData.getNextAvailableEncounterArea(routeId, RouteData.EncounterArea.TRAINER)
	end
	local wildIds = RouteData.getEncounterAreaPokemon(routeId, encounterArea)
	if #wildIds > 0 then
		local seenIds = Tracker.getRouteEncounters(routeId, encounterArea or RouteData.EncounterArea.LAND)
		local pokemonNames = {}
		for _, pokemonId in ipairs(seenIds) do
			if PokemonData.isValid(pokemonId) then
				table.insert(pokemonNames, PokemonData.Pokemon[pokemonId].name)
			end
		end
		local wildsText = string.format("%s: %s/%s", "Wild Pokémon seen", #seenIds, #wildIds)
		if #seenIds > 0 then
			wildsText = wildsText .. string.format(" (%s)", table.concat(pokemonNames, ", "))
		end
		table.insert(info, wildsText)
	end

	local prefix
	if option then
		prefix = string.format("%s: %s %s", route.name, Utils.firstToUpperEachWord(encounterArea), OUTPUT_CHAR)
	else
		prefix = string.format("%s %s", route.name, OUTPUT_CHAR)
	end
	return buildResponse(prefix, info)
end

---@param params string?
---@return string response
function EventData.getDungeon(params)
	-- TODO: Implement this function
	if true then return buildDefaultResponse(params) end
	local routeId = getRouteIdOrDefault(params)
	local route = RouteData.Info[routeId or false]
	if not route then
		return buildDefaultResponse(params)
	end

	local info = {}
	-- Check for trainers in the area/route
	local defeatedTrainers, totalTrainers
	if route.area ~= nil then
		defeatedTrainers, totalTrainers = Program.getDefeatedTrainersByCombinedArea(route.area)
	elseif route.trainers and #route.trainers > 0 then
		defeatedTrainers, totalTrainers = Program.getDefeatedTrainersByLocation(routeId)
	end
	if defeatedTrainers and totalTrainers then
		local trainersText = string.format("%s: %s/%s", "Trainers defeated", #defeatedTrainers, totalTrainers)
		table.insert(info, trainersText)
	end
	local routeName = route.area and route.area.name or route.name
	local prefix = string.format("%s %s", routeName, OUTPUT_CHAR)
	return buildResponse(prefix, info)
end

---@param params string?
---@return string response
function EventData.getUnfoughtTrainers(params)
	-- TODO: Implement this function
	if true then return buildDefaultResponse(params) end
	local allowPartialDungeons = Utils.containsText(params, "dungeon", true)
	local includeSevii
	if GameSettings.game == 3 then
		includeSevii = Utils.containsText(params, "sevii", true)
	else
		includeSevii = true -- to allow routes above the sevii route id for RSE
	end

	local MAX_AREAS_TO_CHECK = 7
	local saveBlock1Addr = Utils.getSaveBlock1Addr()
	local trainersToExclude = TrainerData.getExcludedTrainers()
	local currentRouteId = TrackerAPI.getMapId()

	-- For a given unfought trainer, this function returns unfought trainer counts for its route/area
	local checkedIds = {}
	local function getUnfinishedRouteInfo(trainerId)
		local trainer = TrainerData.Trainers[trainerId] or {}
		local routeId = trainer.routeId or -1
		local route = RouteData.Info[routeId] or {}

		-- If sevii is excluded (default option), skip those routes and non-existent routes
		if routeId == -1 or (routeId >= 230 and not includeSevii) then
			return nil
		end
		-- Skip certain trainers, only checking unfought trainers
		if checkedIds[trainerId] or trainersToExclude[trainerId] or not TrainerData.shouldUseTrainer(trainerId) then
			return nil
		end
		if Program.hasDefeatedTrainer(trainerId, saveBlock1Addr) then
			return nil
		end

		-- Check area for defeated trainers and mark each trainer as checked
		local defeatedTrainers = {}
		local totalTrainers = 0
		local ifDungeonAndIncluded = true -- true for non-dungeons, otherwise gets excluded if partially completed
		if route.area and #route.area > 0 then
			defeatedTrainers, totalTrainers = Program.getDefeatedTrainersByCombinedArea(route.area, saveBlock1Addr)
			-- Don't include dungeons that are partially completed unless the player is currently there
			if route.area.dungeon and #defeatedTrainers > 0 then
				local isThere = false
				for _, id in ipairs(route.area or {}) do
					if id == currentRouteId then
						isThere = true
						break
					end
				end
				ifDungeonAndIncluded = isThere or allowPartialDungeons
			end
			for _, areaRouteId in ipairs(route.area) do
				local areaRoute = RouteData.Info[areaRouteId] or {}
				for _, id in ipairs(areaRoute.trainers or {}) do
					checkedIds[id] = true
				end
			end
		elseif route.trainers and #route.trainers > 0 then
			defeatedTrainers, totalTrainers = Program.getDefeatedTrainersByLocation(routeId, saveBlock1Addr)
			-- Don't include dungeons that are partially completed unless the player is currently there
			if route.dungeon and #defeatedTrainers > 0 and currentRouteId ~= routeId then
				ifDungeonAndIncluded = allowPartialDungeons
			end
			for _, id in ipairs(route.trainers) do
				checkedIds[id] = true
			end
		else
			return nil
		end

		-- Add to info if route/area has unfought trainers (not all defeated)
		if #defeatedTrainers < totalTrainers and ifDungeonAndIncluded then
			local routeName = route.area and route.area.name or route.name
			return string.format("%s (%s/%s)", routeName, #defeatedTrainers, totalTrainers)
		end
	end

	local info = {}
	for _, trainerId in ipairs(TrainerData.OrderedIds or {}) do
		local routeText = getUnfinishedRouteInfo(trainerId)
		if routeText ~= nil then
			table.insert(info, routeText)
		end
		if #info >= MAX_AREAS_TO_CHECK then
			table.insert(info, "...")
			break
		end
	end
	if #info == 0 then
		local reminderText = ""
		if not allowPartialDungeons or not includeSevii then
			reminderText = ' (Use param "dungeon" and/or "sevii" to check partially completed dungeons or Sevii Islands.)'
		end
		table.insert(info, string.format("%s %s", "All available trainers have been defeated!", reminderText))
	end

	local prefix = string.format("%s %s", "Unfought Trainers", OUTPUT_CHAR)
	return buildResponse(prefix, info, ", ")
end

---@param params string?
---@return string response
function EventData.getPivots(params)
	-- TODO: Implement this function
	if true then return buildDefaultResponse(params) end
	local info = {}
	local mapIds
	if GameSettings.game == 3 then -- FRLG
		mapIds = { 89, 90, 110, 117 } -- Route 1, 2, 22, Viridian Forest
	else -- RSE
		local offset = GameSettings.versioncolor == "Emerald" and 0 or 1 -- offset all "mapId > 107" by +1
		mapIds = { 17, 18, 19, 20, 32, 135 + offset } -- Route 101, 102, 103, 104, 116, Petalburg Forest
	end
	for _, mapId in ipairs(mapIds) do
		-- Check for tracked wild encounters in the route
		local seenIds = Tracker.getRouteEncounters(mapId, RouteData.EncounterArea.LAND)
		local pokemonNames = {}
		for _, pokemonId in ipairs(seenIds) do
			if PokemonData.isValid(pokemonId) then
				table.insert(pokemonNames, PokemonData.Pokemon[pokemonId].name)
			end
		end
		if #seenIds > 0 then
			local route = RouteData.Info[mapId or false] or {}
			table.insert(info, string.format("%s: %s", route.name or "Unknown Route", table.concat(pokemonNames, ", ")))
		end
	end
	local prefix = string.format("%s %s", "Pivots", OUTPUT_CHAR)
	return buildResponse(prefix, info)
end

---@param params string?
---@return string response
function EventData.getRevo(params)
	-- TODO: Implement this function
	if true then return buildDefaultResponse(params) end
	local pokemonID, targetEvoId
	if not Utils.isNilOrEmpty(params) then
		pokemonID = DataHelper.findPokemonId(params)
		-- If more than one Pokémon name is provided, set the other as the target evo (i.e. "Eevee Vaporeon")
		if pokemonID == 0 then
			local s = Utils.split(params, " ", true)
			pokemonID = DataHelper.findPokemonId(s[1])
			targetEvoId = DataHelper.findPokemonId(s[2])
		end
	else
		local pokemon = Tracker.getPokemon(1, true) or {}
		pokemonID = pokemon.pokemonID
	end
	local revo = PokemonRevoData.getEvoTable(pokemonID, targetEvoId)
	if not revo then
		local pokemon = PokemonData.Pokemon[pokemonID or false] or {}
		if pokemon.evolution == PokemonData.Evolutions.NONE then
			local prefix = string.format("%s %s %s", pokemon.name, "Evos", OUTPUT_CHAR)
			return buildResponse(prefix, "Does not evolve.")
		else
			return buildDefaultResponse(pokemon.name or params)
		end
	end

	local info = {}
	local shortenPerc = function(p)
		if p < 0.01 then return "<0.01%"
		elseif p < 0.1 then return string.format("%.2f%%", p)
		else return string.format("%.1f%%", p) end
	end
	local extraMons = 0
	for _, revoInfo in ipairs(revo or {}) do
		if #info < MAX_ITEMS then
			table.insert(info, string.format("%s %s", PokemonData.Pokemon[revoInfo.id].name, shortenPerc(revoInfo.perc)))
		else
			extraMons = extraMons + 1
		end
	end
	if extraMons > 0 then
		table.insert(info, string.format("(+%s more Pokémon)", extraMons))
	end
	local prefix = string.format("%s %s %s", PokemonData.Pokemon[pokemonID].name, "Evos", OUTPUT_CHAR)
	return buildResponse(prefix, info, ", ")
end

---@param params string?
---@return string response
function EventData.getCoverage(params)
	-- TODO: Implement this function
	if true then return buildDefaultResponse(params) end
	local calcFromLead = true
	local onlyFullyEvolved = false
	local moveTypes = {}
	if not Utils.isNilOrEmpty(params) then
		params = Utils.replaceText(params or "", ",%s*", " ") -- Remove any list commas
		for _, word in ipairs(Utils.split(params, " ", true) or {}) do
			if Utils.containsText(word, "evolve", true) or Utils.containsText(word, "fully", true) then
				onlyFullyEvolved = true
			else
				local moveType = DataHelper.findPokemonType(word)
				if moveType and moveType ~= "EMPTY" then
					calcFromLead = false
					table.insert(moveTypes, PokemonData.Types[moveType] or moveType)
				end
			end
		end
	end
	if calcFromLead then
		moveTypes = CoverageCalcScreen.getPartyPokemonEffectiveMoveTypes(1) or {}
	end
	if #moveTypes == 0 then
		return buildDefaultResponse(params)
	end

	local info = {}
	local coverageData = CoverageCalcScreen.calculateCoverageTable(moveTypes, onlyFullyEvolved)
	local multipliers = {}
	for _, tab in pairs(CoverageCalcScreen.Tabs) do
		table.insert(multipliers, tab)
	end
	table.sort(multipliers, function(a,b) return a < b end)
	for _, tab in ipairs(multipliers) do
		local mons = coverageData[tab] or {}
		if #mons > 0 then
			local format = "[%0dx] %s"
			if tab == CoverageCalcScreen.Tabs.Half then
				format = "[%0.1fx] %s"
			elseif tab == CoverageCalcScreen.Tabs.Quarter then
				format = "[%0.2fx] %s"
			end
			table.insert(info, string.format(format, tab, #mons))
		end
	end

	local pokemon = Tracker.getPokemon(1, true) or {}
	local typesText = Utils.firstToUpperEachWord(table.concat(moveTypes, ", "))
	local fullyEvoText = onlyFullyEvolved and " Fully Evolved" or ""
	local prefix = string.format("%s (%s)%s %s", "Coverage", typesText, fullyEvoText, OUTPUT_CHAR)
	if calcFromLead and PokemonData.isValid(pokemon.pokemonID) then
		prefix = string.format("%s's %s", PokemonData.Pokemon[pokemon.pokemonID].name, prefix)
	end
	return buildResponse(prefix, info, ", ")
end

---@param params string?
---@return string response
function EventData.getHeals(params)
	-- TODO: Implement this function
	if true then return buildDefaultResponse(params) end
	local info = {}

	local displayHP, displayStatus, displayPP, displayBerries
	if not Utils.isNilOrEmpty(params) then
		local paramToLower = Utils.toLowerUTF8(params)
		displayHP = Utils.containsText(paramToLower, "hp", true)
		displayPP = Utils.containsText(paramToLower, "pp", true)
		displayStatus = Utils.containsText(paramToLower, "status", true)
		displayBerries = Utils.containsText(paramToLower, "berries", true)
	end
	-- Default to showing all (except redundant berries)
	if not (displayHP or displayPP or displayStatus or displayBerries) then
		displayHP = true
		displayPP = true
		displayStatus = true
	end
	local function sortFunc(a,b) return a.value > b.value or (a.value == b.value and a.id < b.id) end
	local function getSortableItem(id, quantity)
		if not MiscData.Items[id or 0] or (quantity or 0) <= 0 then return nil end
		local item = MiscData.HealingItems[id] or MiscData.PPItems[id] or MiscData.StatusItems[id] or {}
		local text = MiscData.Items[item.id]
		if quantity > 1 then
			text = string.format("%s (%s)", text, quantity)
		end
		local value = item.amount or 0
		if item.type == MiscData.HealingType.Percentage then
			value = value + 1000
		elseif item.type == MiscData.StatusType.All then -- The really good status items
			value = value + 2
		elseif MiscData.StatusItems[id] then -- All other status items
			value = value + 1
		end
		return { id = id, text = text, value = value }
	end
	local function sortAndCombine(label, items)
		table.sort(items, sortFunc)
		local t = {}
		for _, item in ipairs(items) do table.insert(t, item.text) end
		table.insert(info, string.format("[%s] %s", label, table.concat(t, ", ")))
	end
	local healingItems, ppItems, statusItems, berryItems = {}, {}, {}, {}
	for id, quantity in pairs(Program.GameData.Items.HPHeals) do
		local itemInfo = getSortableItem(id, quantity)
		if itemInfo then
			table.insert(healingItems, itemInfo)
			if displayBerries and MiscData.HealingItems[id].pocket == MiscData.BagPocket.Berries then
				table.insert(berryItems, itemInfo)
			end
		end
	end
	for id, quantity in pairs(Program.GameData.Items.PPHeals) do
		local itemInfo = getSortableItem(id, quantity)
		if itemInfo then
			table.insert(ppItems, itemInfo)
			if displayBerries and MiscData.PPItems[id].pocket == MiscData.BagPocket.Berries then
				table.insert(berryItems, itemInfo)
			end
		end
	end
	for id, quantity in pairs(Program.GameData.Items.StatusHeals) do
		local itemInfo = getSortableItem(id, quantity)
		if itemInfo then
			table.insert(statusItems, itemInfo)
			if displayBerries and MiscData.StatusItems[id].pocket == MiscData.BagPocket.Berries then
				table.insert(berryItems, itemInfo)
			end
		end
	end
	if displayHP and #healingItems > 0 then
		sortAndCombine("HP", healingItems)
	end
	if displayPP and #ppItems > 0 then
		sortAndCombine("PP", ppItems)
	end
	if displayStatus and #statusItems > 0 then
		sortAndCombine("Status", statusItems)
	end
	if displayBerries and #berryItems > 0 then
		sortAndCombine("Berries", berryItems)
	end
	local prefix = string.format("%s %s", Resources.TrackerScreen.HealsInBag, OUTPUT_CHAR)
	return buildResponse(prefix, info)
end

---@param params string?
---@return string response
function EventData.getTMsHMs(params)
	-- TODO: Implement this function
	if true then return buildDefaultResponse(params) end
	local info = {}
	local prefix = string.format("%s %s", "TMs", OUTPUT_CHAR)
	local canSeeTM = Options["Open Book Play Mode"]

	local singleTmLookup
	local displayGym, displayNonGym, displayHM
	if params and not Utils.isNilOrEmpty(params) then
		displayGym = Utils.containsText(params, "gym", true)
		displayHM = Utils.containsText(params, "hm", true)
		singleTmLookup = tonumber(params:match("(%d+)") or "")
	end
	-- Default to showing just tms (gym & other)
	if not displayGym and not displayHM and not singleTmLookup then
		displayGym = true
		displayNonGym = true
	end
	local tms, hms = Program.getTMsHMsBagItems()
	if singleTmLookup then
		if not canSeeTM then
			for _, item in ipairs(tms or {}) do
				local tmInBag = item.id - 289 + 1 -- 289 is the item ID of the first TM
				if singleTmLookup == tmInBag then
					canSeeTM = true
					break
				end
			end
		end
		local moveId = Program.getMoveIdFromTMHMNumber(singleTmLookup)
		local textToAdd
		if canSeeTM and MoveData.isValid(moveId) then
			textToAdd = MoveData.Moves[moveId].name
		else
			textToAdd = string.format("%s %s", Constants.BLANKLINE, "(not acquired yet)")
		end
		return buildResponse(prefix, string.format("%s %02d: %s", "TM", singleTmLookup, textToAdd))
	end
	if displayGym or displayNonGym then
		local isGymTm = {}
		for _, gymInfo in ipairs(TrainerData.GymTMs) do
			if gymInfo.number then
				isGymTm[gymInfo.number] = true
			end
		end
		local tmsObtained = {}
		local otherTMs, gymTMs = {}, {}
		for _, item in ipairs(tms or {}) do
			local tmNumber = item.id - 289 + 1 -- 289 is the item ID of the first TM
			local moveId = Program.getMoveIdFromTMHMNumber(tmNumber)
			if MoveData.isValid(moveId) then
				tmsObtained[tmNumber] = string.format("#%02d %s", tmNumber, MoveData.Moves[moveId].name)
				if not isGymTm[tmNumber] then
					table.insert(otherTMs, tmsObtained[tmNumber])
				end
			end
		end
		if displayGym then
			-- Get them sorted in Gym ordered
			for _, gymInfo in ipairs(TrainerData.GymTMs) do
				if tmsObtained[gymInfo.number] then
					table.insert(gymTMs, tmsObtained[gymInfo.number])
				elseif canSeeTM then
					local moveId = Program.getMoveIdFromTMHMNumber(gymInfo.number)
					table.insert(gymTMs, string.format("#%02d %s", gymInfo.number, MoveData.Moves[moveId].name))
				end
			end
			local textToAdd = #gymTMs > 0 and table.concat(gymTMs, ", ") or "None"
			table.insert(info, string.format("[%s] %s", "Gym", textToAdd))
		end
		if displayNonGym then
			local textToAdd
			if #otherTMs > 0 then
				local otherMax = math.min(#otherTMs, MAX_ITEMS - #gymTMs)
				textToAdd = table.concat(otherTMs, ", ", 1, otherMax)
				if #otherTMs > otherMax then
					textToAdd = string.format("%s, (+%s more TMs)", textToAdd, #otherTMs - otherMax)
				end
			else
				textToAdd = "None"
			end
			table.insert(info, string.format("[%s] %s", "Other", textToAdd))
		end
	end
	if displayHM then
		local hmTexts = {}
		for _, item in ipairs(hms or {}) do
			local hmNumber = item.id - 339 + 1 -- 339 is the item ID of the first HM
			local moveId = Program.getMoveIdFromTMHMNumber(hmNumber, true)
			if MoveData.isValid(moveId) then
				local hmText = string.format("%s (HM%02d)", MoveData.Moves[moveId].name, hmNumber)
				table.insert(hmTexts, hmText)
			end
		end
		local textToAdd = #hmTexts > 0 and table.concat(hmTexts, ", ") or "None"
		table.insert(info, string.format("%s: %s", "HMs", textToAdd))
	end
	return buildResponse(prefix, info)
end

---@param params string?
---@return string response
function EventData.getSearch(params)
	-- TODO: Implement this function
	if true then return buildDefaultResponse(params) end
	local helpResponse = "Search tracked info for a Pokémon, move, or ability."
	if Utils.isNilOrEmpty(params, true) then
		return buildResponse(params, helpResponse)
	end
	local function getModeAndId(input, threshold)
		local id = DataHelper.findPokemonId(input, threshold)
		if id ~= 0 then return "pokemon", id end
		id = DataHelper.findMoveId(input, threshold)
		if id ~= 0 then return "move", id end
		id = DataHelper.findAbilityId(input, threshold)
		if id ~= 0 then return "ability", id end
		return nil, 0
	end
	local searchMode, searchId
	for i=1, 4, 1 do
		searchMode, searchId = getModeAndId(params, i)
		if searchMode then
			break
		end
	end
	if not searchMode then
		local prefix = string.format("%s %s", params, OUTPUT_CHAR)
		return buildResponse(prefix, "Can't find a Pokémon, move, or ability with that name.")
	end

	local info = {}
	if searchMode == "pokemon" then
		local pokemon = PokemonData.Pokemon[searchId]
		if not pokemon then
			return buildDefaultResponse(params)
		end
		-- Tracked Abilities
		local trackedAbilities = {}
		for _, ability in ipairs(Tracker.getAbilities(pokemon.pokemonID) or {}) do
			if AbilityData.isValid(ability.id) then
				table.insert(trackedAbilities, AbilityData.Abilities[ability.id].name)
			end
		end
		if #trackedAbilities > 0 then
			table.insert(info, string.format("%s: %s", "Abilities", table.concat(trackedAbilities, ", ")))
		end
		-- Tracked Stat Markings
		local statMarksToAdd = {}
		local trackedStatMarkings = Tracker.getStatMarkings(pokemon.pokemonID) or {}
		for _, statKey in ipairs(Constants.OrderedLists.STATSTAGES) do
			local markVal = trackedStatMarkings[statKey]
			if markVal ~= 0 then
				local marking = Constants.STAT_STATES[markVal] or {}
				local symbol = string.sub(marking.text or " ", 1, 1) or ""
				table.insert(statMarksToAdd, string.format("%s(%s)", Utils.toUpperUTF8(statKey), symbol))
			end
		end
		if #statMarksToAdd > 0 then
			table.insert(info, string.format("%s: %s", "Stats", table.concat(statMarksToAdd, ", ")))
		end
		-- Tracked Moves
		local extra = 0
		local trackedMoves = {}
		for _, move in ipairs(Tracker.getMoves(pokemon.pokemonID) or {}) do
			if MoveData.isValid(move.id) then
				if #trackedMoves < MAX_ITEMS then
					-- { id = moveId, level = level, minLv = level, maxLv = level, },
					local lvText
					if move.minLv and move.maxLv and move.minLv ~= move.maxLv then
						lvText = string.format(" (%s.%s-%s)", Resources.TrackerScreen.LevelAbbreviation, move.minLv, move.maxLv)
					elseif move.level > 0 then
						lvText = string.format(" (%s.%s)", Resources.TrackerScreen.LevelAbbreviation, move.level)
					end
					table.insert(trackedMoves, string.format("%s%s", MoveData.Moves[move.id].name, lvText or ""))
				else
					extra = extra + 1
				end
			end
		end
		if #trackedMoves > 0 then
			table.insert(info, string.format("%s: %s", "Moves", table.concat(trackedMoves, ", ")))
			if extra > 0 then
				table.insert(info, string.format("(+%s more)", extra))
			end
		end
		-- Tracked Encounters
		local seenInWild = Tracker.getEncounters(pokemon.pokemonID, true)
		local seenOnTrainers = Tracker.getEncounters(pokemon.pokemonID, false)
		local trackedSeen = {}
		if seenInWild > 0 then
			table.insert(trackedSeen, string.format("%s in wild", seenInWild))
		end
		if seenOnTrainers > 0 then
			table.insert(trackedSeen, string.format("%s on trainers", seenOnTrainers))
		end
		if #trackedSeen > 0 then
			table.insert(info, string.format("%s: %s", "Seen", table.concat(trackedSeen, ", ")))
		end
		-- Tracked Notes
		local trackedNote = Tracker.getNote(pokemon.pokemonID)
		if #trackedNote > 0 then
			table.insert(info, string.format("%s: %s", "Note", trackedNote))
		end
		local prefix = string.format("%s %s %s", "Tracked", pokemon.name, OUTPUT_CHAR)
		return buildResponse(prefix, info)
	elseif searchMode == "move" or searchMode == "moves" then
		local move = MoveData.Moves[searchId]
		if not move then
			return buildDefaultResponse(params)
		end
		local moveId = tonumber(move.id) or 0
		local foundMons = {}
		for pokemonID, trackedPokemon in pairs(Tracker.Data.allPokemon or {}) do
			for _, trackedMove in ipairs(trackedPokemon.moves or {}) do
				if trackedMove.id == moveId and trackedMove.level > 0 then
					local lvText = tostring(trackedMove.level)
					if trackedMove.minLv and trackedMove.maxLv and trackedMove.minLv ~= trackedMove.maxLv then
						lvText = string.format("%s-%s", trackedMove.minLv, trackedMove.maxLv)
					end
					local pokemon = PokemonData.Pokemon[pokemonID]
					local notes = string.format("%s (%s.%s)", pokemon.name, Resources.TrackerScreen.LevelAbbreviation, lvText)
					table.insert(foundMons, { id = pokemonID, bst = tonumber(pokemon.bst or "0"), notes = notes})
					break
				end
			end
		end
		table.sort(foundMons, function(a,b) return a.bst > b.bst or (a.bst == b.bst and a.id < b.id) end)
		local extra = 0
		for _, mon in ipairs(foundMons) do
			if #info < MAX_ITEMS then
				table.insert(info, mon.notes)
			else
				extra = extra + 1
			end
		end
		if extra > 0 then
			table.insert(info, string.format("(+%s more Pokémon)", extra))
		end
		local prefix = string.format("%s %s %s Pokémon:", move.name, OUTPUT_CHAR, #foundMons)
		return buildResponse(prefix, info, ", ")
	elseif searchMode == "ability" or searchMode == "abilities" then
		local ability = AbilityData.Abilities[searchId]
		if not ability then
			return buildDefaultResponse(params)
		end
		local foundMons = {}
		for pokemonID, trackedPokemon in pairs(Tracker.Data.allPokemon or {}) do
			for _, trackedAbility in ipairs(trackedPokemon.abilities or {}) do
				if trackedAbility.id == ability.id then
					local pokemon = PokemonData.Pokemon[pokemonID]
					table.insert(foundMons, { id = pokemonID, bst = tonumber(pokemon.bst or "0"), notes = pokemon.name })
					break
				end
			end
		end
		table.sort(foundMons, function(a,b) return a.bst > b.bst or (a.bst == b.bst and a.id < b.id) end)
		local extra = 0
		for _, mon in ipairs(foundMons) do
			if #info < MAX_ITEMS then
				table.insert(info, mon.notes)
			else
				extra = extra + 1
			end
		end
		if extra > 0 then
			table.insert(info, string.format("(+%s more Pokémon)", extra))
		end
		local prefix = string.format("%s %s %s Pokémon:", ability.name, OUTPUT_CHAR, #foundMons)
		return buildResponse(prefix, info, ", ")
	end
	-- Unused
	local prefix = string.format("%s %s", params, OUTPUT_CHAR)
	return buildResponse(prefix, helpResponse)
end

---@param params string?
---@return string response
function EventData.getSearchNotes(params)
	-- TODO: Implement this function
	if true then return buildDefaultResponse(params) end
	if Utils.isNilOrEmpty(params, true) then
		return buildDefaultResponse(params)
	end

	local info = {}
	local foundMons = {}
	for pokemonID, trackedPokemon in pairs(Tracker.Data.allPokemon or {}) do
		if trackedPokemon.note and Utils.containsText(trackedPokemon.note, params, true) then
			local pokemon = PokemonData.Pokemon[pokemonID]
			table.insert(foundMons, { id = pokemonID, bst = tonumber(pokemon.bst or "0"), notes = pokemon.name })
		end
	end
	table.sort(foundMons, function(a,b) return a.bst > b.bst or (a.bst == b.bst and a.id < b.id) end)
	local extra = 0
	for _, mon in ipairs(foundMons) do
		if #info < MAX_ITEMS then
			table.insert(info, mon.notes)
		else
			extra = extra + 1
		end
	end
	if extra > 0 then
		table.insert(info, string.format("(+%s more Pokémon)", extra))
	end
	local prefix = string.format("%s: \"%s\" %s %s Pokémon:", "Note", params, OUTPUT_CHAR, #foundMons)
	return buildResponse(prefix, info, ", ")
end

---@param params string?
---@return string response
function EventData.getFavorites(params)
	-- TODO: Implement this function
	if true then return buildDefaultResponse(params) end
	local info = {}
	local faveButtons = {
		StreamerScreen.Buttons.PokemonFavorite1,
		StreamerScreen.Buttons.PokemonFavorite2,
		StreamerScreen.Buttons.PokemonFavorite3,
	}
	local favesList = {}
	for i, button in ipairs(faveButtons or {}) do
		local name
		if PokemonData.isValid(button.pokemonID) then
			name = PokemonData.Pokemon[button.pokemonID].name
		else
			name = Constants.BLANKLINE
		end
		table.insert(favesList, string.format("#%s %s", i, name))
	end
	if #favesList > 0 then
		table.insert(info, table.concat(favesList, ", "))
	end
	local prefix = string.format("%s %s", "Favorites", OUTPUT_CHAR)
	return buildResponse(prefix, info)
end

---@param params string?
---@return string response
function EventData.getTheme(params)
	-- TODO: Implement this function
	if true then return buildDefaultResponse(params) end
	local info = {}
	local themeCode = Theme.exportThemeToText()
	local themeName = Theme.getThemeNameFromCode(themeCode)
	table.insert(info, string.format("%s: %s", themeName, themeCode))
	local prefix = string.format("%s %s", "Theme", OUTPUT_CHAR)
	return buildResponse(prefix, info)
end

---@param params string?
---@return string response
function EventData.getGameStats(params)
	-- TODO: Implement this function
	if true then return buildDefaultResponse(params) end
	local info = {}
	for _, statPair in ipairs(StatsScreen.StatTables or {}) do
		if type(statPair.getText) == "function" and type(statPair.getValue) == "function" then
			local statValue = statPair.getValue() or 0
			if type(statValue) == "number" then
				statValue = Utils.formatNumberWithCommas(statValue)
			end
			table.insert(info, string.format("%s: %s", statPair:getText(), statValue))
		end
	end
	local prefix = string.format("%s %s", Resources.GameOptionsScreen.ButtonGameStats, OUTPUT_CHAR)
	return buildResponse(prefix, info)
end

---@param params string?
---@return string response
function EventData.getProgress(params)
	-- TODO: Implement this function
	if true then return buildDefaultResponse(params) end
	local includeSevii = Utils.containsText(params, "sevii", true)
	local info = {}
	local badgesObtained, maxBadges = 0, 8
	for i = 1, maxBadges, 1 do
		local badgeButton = TrackerScreen.Buttons["badge" .. i] or {}
		if (badgeButton.badgeState or 0) ~= 0 then
			badgesObtained = badgesObtained + 1
		end
	end
	table.insert(info, string.format("%s: %s/%s", "Gym badges", badgesObtained, maxBadges))
	local saveBlock1Addr = Utils.getSaveBlock1Addr()
	local totalDefeated, totalTrainers = 0, 0
	for mapId, route in pairs(RouteData.Info) do
		-- Don't check sevii islands (id = 230+) by default
		if mapId < 230 or includeSevii then
			if route.trainers and #route.trainers > 0 then
				local defeatedTrainers, totalInRoute = Program.getDefeatedTrainersByLocation(mapId, saveBlock1Addr)
				totalDefeated = totalDefeated + #defeatedTrainers
				totalTrainers = totalTrainers + totalInRoute
			end
		end
	end
	table.insert(info, string.format("%s%s: %s/%s (%0.1f%%)",
		"Trainers defeated",
		includeSevii and ", including Sevii" or "",
		totalDefeated,
		totalTrainers,
		totalDefeated / totalTrainers * 100))
	local fullyEvolvedSeen, fullyEvolvedTotal = 0, 0
	-- local legendarySeen, legendaryTotal = 0, 0
	for pokemonID, pokemon in ipairs(PokemonData.Pokemon) do
		if pokemon.evolution == PokemonData.Evolutions.NONE then
			fullyEvolvedTotal = fullyEvolvedTotal + 1
			local trackedPokemon = Tracker.Data.allPokemon[pokemonID] or {}
			if (trackedPokemon.eT or 0) > 0 then
				fullyEvolvedSeen = fullyEvolvedSeen + 1
			end
		end
	end
	table.insert(info, string.format("%s: %s/%s (%0.1f%%)", --, Legendary: %s/%s (%0.1f%%)",
		"Pokémon seen fully evolved",
		fullyEvolvedSeen,
		fullyEvolvedTotal,
		fullyEvolvedSeen / fullyEvolvedTotal * 100))
	local prefix = string.format("%s %s", "Progress", OUTPUT_CHAR)
	return buildResponse(prefix, info)
end

---@param params string?
---@return string response
function EventData.getLog(params)
	-- TODO: Implement this function
	if true then return buildDefaultResponse(params) end
	-- TODO: add "previous" as a parameter; requires storing this information somewhere
	local prefix = string.format("%s %s", "Log", OUTPUT_CHAR)
	local hasParsedThisLog = RandomizerLog.Data.Settings and string.find(RandomizerLog.loadedLogPath or "", FileManager.PostFixes.AUTORANDOMIZED, 1, true)
	if not hasParsedThisLog then
		return buildResponse(prefix, "This game's log file hasn't been opened yet.")
	end

	local info = {}
	for _, button in ipairs(Utils.getSortedList(LogTabMisc.Buttons or {})) do
		table.insert(info, string.format("%s %s", button:getText(), button:getValue()))
	end
	return buildResponse(prefix, info)
end

---@param params string?
---@return string response
function EventData.getBallQueue(params)
	local prefix = string.format("%s %s", "BallQueue", OUTPUT_CHAR)

	local info = {}

	local queueSize = 0
	for _, _ in pairs(EventHandler.Queues.BallRedeems.Requests or {}) do
		queueSize = queueSize + 1
	end
	if queueSize == 0 then
		return buildResponse(prefix, "The pick ball queue is empty.")
	end
	table.insert(info, string.format("%s: %s", "Size", queueSize))

	local request = EventHandler.Queues.BallRedeems.ActiveRequest
	if request and request.Username then
		table.insert(info, string.format("%s: %s - %s", "Current pick", request.Username, request.SanitizedInput or "N/A"))
	end

	return buildResponse(prefix, info)
end

---@param params string?
---@return string response
function EventData.getAbout(params)
	local info = {}
	table.insert(info, string.format("Version: %s", MiscConstants.TRACKER_VERSION))
	table.insert(info, string.format("Game: %s", "HGSS" or GameSettings.gamename)) -- TODO: Fix
	table.insert(info, string.format("Attempts: %s", 1234 or Main.currentSeed or 1)) -- TODO: Fix
	table.insert(info, string.format("Streamerbot Code: v%s", Network.currentStreamerbotVersion or "N/A"))
	local prefix = string.format("NDS Ironmon Tracker %s", OUTPUT_CHAR)
	return buildResponse(prefix, info)
end

---@param params string?
---@return string response
function EventData.getHelp(params)
	local availableCommands = {}
	for _, event in pairs(EventHandler.Events or {}) do
		if event.Type == EventHandler.EventTypes.Command and event.Command and event.IsEnabled then
			availableCommands[event.Command] = event
		end
	end
	local info = {}
	if params ~= nil and params ~= "" then
		local paramsAsLower = params:lower()
		if paramsAsLower:sub(1, 1) ~= EventHandler.COMMAND_PREFIX then
			paramsAsLower = EventHandler.COMMAND_PREFIX .. paramsAsLower
		end
		local command = availableCommands[paramsAsLower]
		if not command or (command.Help or "") == "" then
			return buildDefaultResponse(params)
		end
		table.insert(info, string.format("%s %s", paramsAsLower, command.Help))
	else
		for commandWord, _ in pairs(availableCommands) do
			table.insert(info, commandWord)
		end
		table.sort(info, function(a,b) return a < b end)
	end
	local prefix = string.format("Tracker Commands %s", OUTPUT_CHAR)
	return buildResponse(prefix, info, ", ")
end