BH_VERSION = "1.2.9"

--[[
    For installation, usage and implementation examples check the wiki:
        https://github.com/MNoya/BuildingHelper/wiki
]]

-- require('libraries/timers')
-- require('libraries/selection')
-- require('libraries/keyvalues')

if not BuildingHelper then
    BuildingHelper = class({})
end

-- Loads Key Values into the BuildingAbilities
function BuildingHelper:Init()
    -- building_settings nettable from buildings.kv
    BuildingHelper:LoadSettings()

    BuildingHelper:print("BuildingHelper Init")
    BuildingHelper.Players = {} -- Holds a table for each player ID
    BuildingHelper.Dummies = {} -- Holds up to one entity for each building name
    BuildingHelper.TreeDummies = {} -- Holds tree chopped dummies
    BuildingHelper.Grid = {}    -- Construction grid
    BuildingHelper.Terrain = {} -- 地形网格，仅当树木被砍伐时才会改变
    BuildingHelper.Encoded = "" -- String containing the base terrain, networked to clients
    BuildingHelper.squareX = 0  -- Number of X grid points
    BuildingHelper.squareY = 0  -- Number of Y grid points

    -- Grid States
    BuildingHelper.GridTypes = {}
    BuildingHelper.NextGridValue = 1
    BuildingHelper:NewGridType("BLOCKED")
    BuildingHelper:NewGridType("BUILDABLE")

    -- Panorama Event Listeners
    CustomGameEventManager:RegisterListener("building_helper_build_command", Dynamic_Wrap(BuildingHelper, "BuildCommand"))
    CustomGameEventManager:RegisterListener("building_helper_cancel_command", Dynamic_Wrap(BuildingHelper, "CancelCommand"))
    CustomGameEventManager:RegisterListener("building_helper_repair_command", Dynamic_Wrap(BuildingHelper, "RepairCommand"))
    CustomGameEventManager:RegisterListener("selection_update", Dynamic_Wrap(BuildingHelper, 'OnSelectionUpdate')) --Hook selection library
    CustomGameEventManager:RegisterListener("gnv_request", Dynamic_Wrap(BuildingHelper, "SendGNV"))
    CustomGameEventManager:RegisterListener("change_angles", Dynamic_Wrap(BuildingHelper, "changeAngles"))

     -- Game Event Listeners
    ListenToGameEvent('game_rules_state_change', Dynamic_Wrap(BuildingHelper, 'OnGameRulesStateChange'), self)
    ListenToGameEvent('npc_spawned', Dynamic_Wrap(BuildingHelper, 'OnNPCSpawned'), self)
    ListenToGameEvent('entity_killed', Dynamic_Wrap(BuildingHelper, 'OnEntityKilled'), self)
    if BuildingHelper.Settings["UPDATE_TREES"] then
        ListenToGameEvent('tree_cut', Dynamic_Wrap(BuildingHelper, 'OnTreeCut'), self)
    end

    -- Lua Modifiers
    LinkLuaModifier("modifier_building", "buildinghelper/modifiers/modifier_building", LUA_MODIFIER_MOTION_NONE)
    LinkLuaModifier("modifier_out_of_world", "buildinghelper/modifiers/modifier_out_of_world", LUA_MODIFIER_MOTION_NONE)
    LinkLuaModifier("modifier_builder_hidden", "buildinghelper/modifiers/modifier_builder_hidden", LUA_MODIFIER_MOTION_NONE)
    LinkLuaModifier("modifier_repairing", "buildinghelper/modifiers/repair_modifiers", LUA_MODIFIER_MOTION_NONE)
    LinkLuaModifier("modifier_builder_repairing", "buildinghelper/modifiers/repair_modifiers", LUA_MODIFIER_MOTION_NONE)
    LinkLuaModifier("modifier_tree_cut", "buildinghelper/modifiers/modifier_tree_cut", LUA_MODIFIER_MOTION_NONE)

    -- Check KVs and set relevant construction_size nettable values
    self:ParseKV()

    -- Order Filter override
    self:HookBoilerplate()

    -- Some game function overrides
    self:HookFunctions()

    -- Reload settings file
    self:OnScriptReload()
end

function BuildingHelper:OnScriptReload()
    BuildingHelper:LoadSettings()
    if BuildingHelper.Settings["REPAIR_PATH"] then
        require(BuildingHelper.Settings["REPAIR_PATH"])
    end
    if BuildingHelper.Settings["BUILD_PATH"] then
        require(BuildingHelper.Settings["BUILD_PATH"])
    end
end

function BuildingHelper:HookBoilerplate()
    if not __ACTIVATE_HOOK then
        __ACTIVATE_HOOK = {funcs={}}
        setmetatable(__ACTIVATE_HOOK, {
          __call = function(t, func)
            table.insert(t.funcs, func)
          end
        })

        debug.sethook(function(...)
          local info = debug.getinfo(2)
          local src = tostring(info.short_src)
          local name = tostring(info.name)
          if name ~= "__index" then
            if string.find(src, "addon_game_mode") then
              if GameRules:GetGameModeEntity() then
                for _, func in ipairs(__ACTIVATE_HOOK.funcs) do
                  local status, err = pcall(func)
                  if not status then
                    print("__ACTIVATE_HOOK callback error: " .. err)
                  end
                end

                debug.sethook(nil, "c")
              end
            end
          end
        end, "c")
    end

    -- Hook the order filter
    __ACTIVATE_HOOK(function()
        local mode = GameRules:GetGameModeEntity()
        mode:SetExecuteOrderFilter(Dynamic_Wrap(BuildingHelper, 'OrderFilter'), BuildingHelper)
        self.oldFilter = mode.SetExecuteOrderFilter
        mode.SetExecuteOrderFilter = function(mode, fun, context)
            BuildingHelper.nextFilter = fun
            BuildingHelper.nextContext = context
        end
    end)
end

-- This requires that buildinghelper is required before the usage of these functions
function BuildingHelper:HookFunctions()
    local oldSetTreeRegrowTime = GameRules.SetTreeRegrowTime
    BuildingHelper.TreeRegrowTime = 300
    GameRules.SetTreeRegrowTime = function(gameRules, time)
        BuildingHelper.TreeRegrowTime = time
        oldSetTreeRegrowTime(gameRules, time)
    end

    local oldRegrowAllTrees = GridNav.RegrowAllTrees
    GridNav.RegrowAllTrees = function(gridNav)
        for _,dummy in pairs(BuildingHelper.TreeDummies) do
            UTIL_Remove(dummy)
        end
        BuildingHelper.TreeDummies = {}
        oldRegrowAllTrees(gridNav)
    end

    local oldCutDownRegrowAfter = CDOTA_MapTree.CutDownRegrowAfter
    CDOTA_MapTree.CutDownRegrowAfter = function(tree, time, team)
        oldCutDownRegrowAfter(tree, time, team)
        Timers:CreateTimer(time, function()
            BuildingHelper.TreeDummies[tree:GetEntityIndex()] = nil
            UTIL_Remove(tree.chopped_dummy)
        end)
    end

    local oldGrowBack = CDOTA_MapTree.GrowBack
    CDOTA_MapTree.GrowBack = function(tree)
        BuildingHelper.TreeDummies[tree:GetEntityIndex()] = nil
        UTIL_Remove(tree.chopped_dummy)
        oldGrowBack(tree)
    end
end

function BuildingHelper:LoadSettings()
    BuildingHelper.Settings = LoadKeyValues("scripts/kv/building_settings.kv")
    
    BuildingHelper.Settings["TESTING"] = tobool(BuildingHelper.Settings["TESTING"])
    BuildingHelper.Settings["RECOLOR_BUILDING_PLACED"] = tobool(BuildingHelper.Settings["RECOLOR_BUILDING_PLACED"])
    BuildingHelper.Settings["UPDATE_TREES"] = tobool(BuildingHelper.Settings["UPDATE_TREES"])
    BuildingHelper.Settings["MAGIC_IMMUNE_BUILDINGS"] = tobool(BuildingHelper.Settings["MAGIC_IMMUNE_BUILDINGS"])
    BuildingHelper.Settings["DENIABLE_BUILDINGS"] = tobool(BuildingHelper.Settings["DENIABLE_BUILDINGS"])
    BuildingHelper.Settings["DISABLE_BUILDING_TURNING"] = tobool(BuildingHelper.Settings["DISABLE_BUILDING_TURNING"])
    BuildingHelper.Settings["RIGHT_CLICK_REPAIR"] = tobool(BuildingHelper.Settings["RIGHT_CLICK_REPAIR"])

    CustomNetTables:SetTableValue("building_settings", "grid_alpha", { value = BuildingHelper.Settings["GRID_ALPHA"] })
    CustomNetTables:SetTableValue("building_settings", "alt_grid_alpha", { value = BuildingHelper.Settings["ALT_GRID_ALPHA"] })
    CustomNetTables:SetTableValue("building_settings", "alt_grid_squares", { value = BuildingHelper.Settings["ALT_GRID_SQUARES"] })
    CustomNetTables:SetTableValue("building_settings", "range_overlay_alpha", { value = BuildingHelper.Settings["RANGE_OVERLAY_ALPHA"] })
    CustomNetTables:SetTableValue("building_settings", "model_alpha", { value = BuildingHelper.Settings["MODEL_ALPHA"] })
    CustomNetTables:SetTableValue("building_settings", "recolor_ghost", { value = tobool(BuildingHelper.Settings["RECOLOR_GHOST_MODEL"]) })
    CustomNetTables:SetTableValue("building_settings", "turn_red", { value = tobool(BuildingHelper.Settings["RED_MODEL_WHEN_INVALID"]) })
    CustomNetTables:SetTableValue("building_settings", "permanent_alt_grid", { value = tobool(BuildingHelper.Settings["PERMANENT_ALT_GRID"]) })
    CustomNetTables:SetTableValue("building_settings", "update_trees", { value = BuildingHelper.Settings["UPDATE_TREES"] })
    CustomNetTables:SetTableValue("building_settings", "right_click_repair", { value = BuildingHelper.Settings["RIGHT_CLICK_REPAIR"] })

    if BuildingHelper.Settings["HEIGHT_RESTRICTION"] and BuildingHelper.Settings["HEIGHT_RESTRICTION"] ~= "" then
        CustomNetTables:SetTableValue("building_settings", "height_restriction", { value = BuildingHelper.Settings["HEIGHT_RESTRICTION"] })
    end
end

function BuildingHelper:ParseKV()
    for name,info in pairs(KeyValues.All) do
        if type(info) == "table" then
            local isBuilding = info["Building"] or info["ConstructionSize"]
            if isBuilding then
                -- Build NetTable with the building properties
                local values = {}
                if info['ConstructionSize'] then
                    values.size = info['ConstructionSize']
                end

                -- Add proximity restriction
                if info['RestrictGoldMineDistance'] then
                    values.distance_to_gold_mine = info['RestrictGoldMineDistance']
                end

                -- Add special grid types generated by this building
                if info['Grid'] then
                    values.grid = info['Grid']
                end

                -- Add required grid types
                if info['Requires'] then
                    values.requires = string.upper(info['Requires'])
                end

                -- Add denied grid types
                if info['Prevents'] then
                    values.requires = string.upper(info['Prevents'])
                end

                CustomNetTables:SetTableValue("construction_size", name, values)
            end
        end
    end
end

function BuildingHelper:OnGameRulesStateChange(keys)
    local newState = GameRules:State_Get()
    if newState == DOTA_GAMERULES_STATE_CUSTOM_GAME_SETUP then
        -- The base terrain GridNav is obtained directly from the vmap
        BuildingHelper:InitGNV()
    end
end

function BuildingHelper:OnNPCSpawned(keys)
    local npc = EntIndexToHScript(keys.entindex)
    if IsBuilder(npc) then
        BuildingHelper:InitializeBuilder(npc)
    end
end

function BuildingHelper:OnEntityKilled(keys)
    local killed = EntIndexToHScript(keys.entindex_killed)
    local unitTable = killed:GetKeyValue()
    local gridTable = unitTable and unitTable["Grid"]

    if IsBuilder(killed) then
        BuildingHelper:ClearQueue(killed)
    elseif IsCustomBuilding(killed) or gridTable then
        -- Building Helper grid cleanup
        BuildingHelper:RemoveBuilding(killed, false)

        if gridTable then
            for grid_type,v in pairs(gridTable) do
                if tobool(v.RemoveOnDeath) then --Only use if there is no overlapping!
                    local location = killed:GetAbsOrigin()
                    BuildingHelper:print("Clearing special grid of "..grid_type)
                    if (v.Radius) then
                        BuildingHelper:RemoveGridType(v.Radius, location, grid_type, "radius")
                    elseif (v.Square) then
                        BuildingHelper:RemoveGridType(v.Square, location, grid_type)
                    end                
                end
            end
        end
    end
end

function BuildingHelper:OnTreeCut(keys)
    local treePos = Vector(keys.tree_x,keys.tree_y,0)
    local tree -- Figure out which tree was cut
    for _,t in pairs(BuildingHelper.AllTrees) do
        local pos = t:GetAbsOrigin()
        if pos.x == treePos.x and pos.y == treePos.y then
            tree = t
            break
        end
    end

    if not tree then
        BuildingHelper:print("ERROR: OnTreeCut couldn't find a tree for pos "..treePos.x..","..treePos.y)
        return
    elseif tree.chopped_dummy then
        UTIL_Remove(tree.chopped_dummy)
    end

    -- Create a dummy for clients to be able to detect trees standing and block their grid
    tree.chopped_dummy = CreateUnitByName("npc_dota_units_base", treePos, false, nil, nil, 0)
    tree.chopped_dummy:AddNewModifier(tree.chopped_dummy,nil,"modifier_tree_cut",{})
    BuildingHelper.TreeDummies[tree:GetEntityIndex()] = tree.chopped_dummy

    -- Allow construction
    if not GridNav:IsBlocked(treePos) then
        BuildingHelper:FreeGridSquares(2, treePos)
    end

    -- Remove the dummy, allowing the tree to regrow
    Timers:CreateTimer(BuildingHelper.TreeRegrowTime, function()
        if IsValidEntity(tree.chopped_dummy) then
            BuildingHelper.TreeDummies[tree:GetEntityIndex()] = nil
            UTIL_Remove(tree.chopped_dummy)
        end
    end)
end

function BuildingHelper:InitGNV()
    local worldMin = Vector(GetWorldMinX(), GetWorldMinY(), 0)
    local worldMax = Vector(GetWorldMaxX(), GetWorldMaxY(), 0)

    local boundX1 = GridNav:WorldToGridPosX(worldMin.x)
    local boundX2 = GridNav:WorldToGridPosX(worldMax.x)
    local boundY1 = GridNav:WorldToGridPosY(worldMin.y)
    local boundY2 = GridNav:WorldToGridPosY(worldMax.y)
   
    BuildingHelper:print("Max World Bounds: ")
    BuildingHelper:print(GetWorldMinX()..' '..GetWorldMaxX()..' '..GetWorldMinY()..' '..GetWorldMaxY())
    BuildingHelper:print(boundX1..' '..boundX2..' '..boundY1..' '..boundY2)

    local blockedCount = 0
    local unblockedCount = 0

    local gnv = {}
    local line = {}
    local ASCII_ART = false

    -- 名为“bh_blocked”的触发区将封锁施工地形
    local blocked_map_zones = Entities:FindAllByName("*bh_blocked")

    for y=boundY1,boundY2 do
        local shift = 4
        local byte = 0
        BuildingHelper.Terrain[y] = {}
        for x=boundX1,boundX2 do
            local gridX = GridNav:GridPosToWorldCenterX(x)
            local gridY = GridNav:GridPosToWorldCenterY(y)
            local position = Vector(gridX, gridY, 0)
            local treeBlocked = GridNav:IsNearbyTree(position, 30, true)

            -- 如果启用了树更新，则树不会联网，而是在客户端上检测为ent_dota_树实体
            local terrainBlocked = not GridNav:IsTraversable(position) or GridNav:IsBlocked(position)
            if BuildingHelper.Settings["UPDATE_TREES"] then
                terrainBlocked = terrainBlocked and not treeBlocked
            end

            if not terrainBlocked then
                -- Check if the position is inside any blocking trigger
                for _,ent in pairs(blocked_map_zones) do
                    local triggerBlocked = BuildingHelper:IsInsideEntityBounds(ent, position)
                    if triggerBlocked then
                        terrainBlocked = true
                        break
                    end
                end
            end

            if terrainBlocked then
                BuildingHelper.Terrain[y][x] = BuildingHelper.GridTypes["BLOCKED"]
                byte = byte + bit.lshift(2,shift)
                blockedCount = blockedCount+1
                if ASCII_ART then
                    line[#line+1] = '='
                end
            else
                BuildingHelper.Terrain[y][x] = BuildingHelper.GridTypes["BUILDABLE"]
                byte = byte + bit.lshift(1,shift)
                unblockedCount = unblockedCount+1
                if ASCII_ART then
                    line[#line+1] = '.'
                end
            end

            if treeBlocked then
                BuildingHelper.Terrain[y][x] = BuildingHelper.GridTypes["BLOCKED"]
            end

            shift = shift - 2

            if shift == -2 then
                gnv[#gnv+1] = string.char(byte+32)
                shift = 4
                byte = 0
            end
        end

        if shift ~= 4 then
            gnv[#gnv+1] = string.char(byte+32)
        end

        if ASCII_ART then
            print(table.concat(line,''))
            line = {}
        end
    end

    local gnv_string = table.concat(gnv,'')

    local squareX = boundX2 - boundX1 + 1
    local squareY = boundY2 - boundY1 + 1

    BuildingHelper:print("Free: "..unblockedCount.." Blocked: "..blockedCount)

    -- 最初，构造网格等于地形网格
    -- 客户将完全了解地形网格
    -- 构造网格仅由服务器知道
    BuildingHelper.Grid = BuildingHelper.Terrain

    BuildingHelper.Encoded = gnv_string
    BuildingHelper.squareX = squareX
    BuildingHelper.squareY = squareY
    BuildingHelper.minBoundX = boundX1
    BuildingHelper.minBoundY = boundY1

    BuildingHelper.AllTrees = Entities:FindAllByClassname("ent_dota_tree")
end

function BuildingHelper:SendGNV(args)
    -- add by lyjian 不知道random_fame_td修改是干啥的
    -- gnv11 = string.sub(BuildingHelper.Encoded, 0, 32765)
    -- gnv22 = string.sub(BuildingHelper.Encoded, 32766, 65532)
    -- gnv33 = string.sub(BuildingHelper.Encoded, 65533, 87552)

    local playerID = args.PlayerID
    if playerID then
        local player = PlayerResource:GetPlayer(playerID)
        if player then
            BuildingHelper:print("Sending GNV to player "..playerID)
            CustomGameEventManager:Send_ServerToPlayer(player, "gnv_register", {gnv=BuildingHelper.Encoded, squareX = BuildingHelper.squareX, squareY = BuildingHelper.squareY, boundX = BuildingHelper.minBoundX, boundY = BuildingHelper.minBoundY })
            -- CustomGameEventManager:Send_ServerToPlayer(player, "gnv_register", {gnv1=gnv11, gnv2=gnv22, gnv3=gnv33, squareX = BuildingHelper.squareX, squareY = BuildingHelper.squareY, boundX = BuildingHelper.minBoundX, boundY = BuildingHelper.minBoundY})
        end
    end
end

-- 用于查找离建筑位置最近的建筑商
local GetClosestToPosition = function(unitList, position)
    local distance = math.huge
    local closest
    for _,unit in pairs(unitList) do
        local thisDistance = (unit:GetAbsOrigin()-position):Length2D()
        if thisDistance < distance then
            closest = unit
            distance = thisDistance
        end
    end
    return closest
end

-- 通过全景图检测生成器的左键单击
function BuildingHelper:BuildCommand(args)
    local playerID = args['PlayerID']
    local x = args['X']
    local y = args['Y']
    local z = args['Z']
    local location = Vector(x, y, z)
    local queue = args['Queue'] == 1
    local builder = EntIndexToHScript(args['builder']) --activeBuilder
    local name = builder:GetUnitName()
    local builders = {}
    local idle_builders = {}
    local entityList = PlayerResource:GetSelectedEntities(playerID)

    -- 筛选所有选定的生成器
    for k,entIndex in pairs(entityList) do
        local unit = EntIndexToHScript(entIndex)
        if unit:GetUnitName() == name then
            if unit:IsIdle() then
                table.insert(idle_builders, unit)
            end
            table.insert(builders, unit)
        end
    end

    -- First select from idle builders
    if #idle_builders > 0 then
        builder = GetClosestToPosition(idle_builders, location)
    else
        builder = GetClosestToPosition(builders, location)
    end

    -- Cancel current action
    if not queue then
        builder:Stop()
    end

    BuildingHelper:AddToQueue(builder, location, queue)
end

-- Detects a Right Click/Tab with a builder through Panorama
function BuildingHelper:CancelCommand(args)
    local playerID = args.PlayerID
    local playerTable = BuildingHelper:GetPlayerTable(playerID)
    playerTable.activeBuilding = nil

    local selectedEntities = PlayerResource:GetSelectedEntities(playerID)
    for _,entityIndex in pairs(selectedEntities) do
        local unit = EntIndexToHScript(entityIndex)
        if IsBuilder(unit) then
            BuildingHelper:ClearQueue(unit)
        end
    end
end

-- Detects a RightClick on a building with health deficit
function BuildingHelper:RepairCommand(args)
    local playerID = args.PlayerID
    local building = EntIndexToHScript(args.targetIndex)
    local selectedEntities = PlayerResource:GetSelectedEntities(playerID)
    local queue = tobool(args.queue)

    for _,entityIndex in pairs(selectedEntities) do
        local unit = EntIndexToHScript(entityIndex)

        if IsBuilder(unit) then
            -- Cancel current action
            if not queue then
                ExecuteOrderFromTable({UnitIndex = entityIndex, OrderType = DOTA_UNIT_ORDER_STOP, Queue = false}) 
            end

            -- Repair added to the queue
            BuildingHelper:AddRepairToQueue(unit, building, queue)
        end
    end
end

function BuildingHelper:OnSelectionUpdate(event)
    local playerID = event.PlayerID
    if not playerID then return end
    
    -- This is for Building Helper to know which is the currently active builder
    local mainSelected = PlayerResource:GetMainSelectedEntity(playerID)
    if not mainSelected then return end
    mainSelected = EntIndexToHScript(mainSelected)
    local player = BuildingHelper:GetPlayerTable(playerID)

    if IsValidEntity(mainSelected) then
        if IsBuilder(mainSelected) then
            player.activeBuilder = mainSelected
        else
            if IsValidEntity(player.activeBuilder) then
                -- Clear ghost particles when swapping to a non-builder
                BuildingHelper:StopGhost(player.activeBuilder)
            end
        end
    end
end

function BuildingHelper:OrderFilter(order)
    local ret = true    

    if BuildingHelper.nextFilter then
        ret = BuildingHelper.nextFilter(BuildingHelper.nextContext, order)
    end

    if not ret then
        return false
    end

    local issuerID = order.issuer_player_id_const

    if issuerID == -1 then return true end

    local queue = order.queue == 1
    local order_type = order.order_type
    local units = order.units
    local abilityIndex = order.entindex_ability
    local targetIndex = order.entindex_target
    local unit = nil
    if units["0"] then
        unit = EntIndexToHScript(units["0"])
    end

    -- Item is dropped
    if order_type == DOTA_UNIT_ORDER_DROP_ITEM and IsBuilder(unit) then
        BuildingHelper:ClearQueue(unit)
        return true

    -- Stop and Hold
    elseif order_type == DOTA_UNIT_ORDER_STOP or order_type == DOTA_UNIT_ORDER_HOLD_POSITION then
        if unit and IsBuilder(unit) then --Hold Stops instead
            order.order_type = DOTA_UNIT_ORDER_STOP
        end
        for n, unit_index in pairs(units) do 
            local unit = EntIndexToHScript(unit_index)
            if IsBuilder(unit) then
                BuildingHelper:ClearQueue(unit)
            end
        end
        return true

    -- Casting non building abilities
    elseif (abilityIndex and abilityIndex ~= 0) and unit and IsBuilder(unit) then
        local ability = EntIndexToHScript(abilityIndex)
        if not IsBuildingAbility(ability) then
            BuildingHelper:ClearQueue(unit)
        end

        -- Repair Multi Order
        if order_type == DOTA_UNIT_ORDER_CAST_TARGET and BuildingHelper:GetRepairAbility(unit) then
            local ability = EntIndexToHScript(abilityIndex) 
            local abilityName = ability:GetAbilityName()
            local target_handle = EntIndexToHScript(targetIndex)
            local target_name = target_handle:GetUnitName()
            
            if self:OnPreRepair(target_handle, unit) then
                self:print("Order: Repair "..target_handle:GetUnitName())

                -- Get the currently selected units and send new orders
                local entityList = PlayerResource:GetSelectedEntities(unit:GetPlayerOwnerID())
                if not entityList or #entityList == 1 then return true end

                for k,entityIndex in pairs(entityList) do
                    local ent = EntIndexToHScript(entityIndex)
                    local repair_aretbility = BuildingHelper:GetRepairAbility(ent)
                    if ent ~= unit and repair_ability then
                        if repair_ability:IsHidden() and ent.ReturnAbility then -- Swap to the repair ability
                            ent:SwapAbilities(repair_ability:GetAbilityName(), ent.ReturnAbility:GetAbilityName(), true, false)
                        end

                        ent.skip = true
                        BuildingHelper:print("Repair Multi Order "..target_handle:GetUnitName())
                        ExecuteOrderFromTable({UnitIndex = entityIndex, OrderType = DOTA_UNIT_ORDER_CAST_TARGET, TargetIndex = targetIndex, AbilityIndex = repair_ability:GetEntityIndex(), Queue = queue})
                    end
                end
            end
        end
    end


    return ret
end    

-- Manages each workers build queue. Will run once per builder
function BuildingHelper:InitializeBuilder(builder)
    BuildingHelper:print("InitializeBuilder "..builder:GetUnitName().." "..builder:GetEntityIndex())

    if not builder.buildingQueue then
        builder.buildingQueue = {}
    end

    -- Store the builder entity indexes on a net table
    CustomNetTables:SetTableValue("builders", tostring(builder:GetEntityIndex()), { IsBuilder = true })
end

function BuildingHelper:RemoveBuilder(builder)
    -- Store the builder entity indexes on a net table
    CustomNetTables:SetTableValue("builders", tostring(builder:GetEntityIndex()), { IsBuilder = false })
end

-- Makes a building dummy and starts panorama ghosting
-- Builder calls this and sets the callbacks with the required values
function BuildingHelper:AddBuilding(keys)
    -- Callbacks
    local callbacks = BuildingHelper:SetCallbacks(keys)
    local builder = keys.caster
    local ability = keys.ability
    local abilName = ability:GetAbilityName()
    -- npc_units_custom.txt 这个里面的配置
    local buildingTable = BuildingHelper:SetupBuildingTable(abilName, builder)
    buildingTable:SetVal("AbilityHandle", ability)

    -- 这边重新设置下yaw
    -- buildingTable:SetVal("ModelRotation", keys.yaw)

    -- Prepare the builder, if it hasn't already been done
    if not builder.buildingQueue then  
        BuildingHelper:InitializeBuilder(builder)
    end

    -- local size = buildingTable:GetVal("ConstructionSize", "number")
    local size = buildingTable:GetVal("ConstructionSize")
    local unitName = buildingTable:GetVal("UnitName", "string")

    -- Handle self-ghosting
    if unitName == "self" then
        unitName = builder:GetUnitName()
    end

    local fMaxScale = buildingTable:GetVal("MaxScale", "float")
    if not fMaxScale then
        -- If no MaxScale is defined, check the "ModelScale" KeyValue. Otherwise just default to 1
        local fModelScale = GetUnitKV(unitName, "ModelScale")
        if fModelScale then
          fMaxScale = fModelScale
        else
            fMaxScale = 1
        end
    end
    buildingTable:SetVal("MaxScale", fMaxScale)

    local color = Vector(255,255,255)
    if RECOLOR_GHOST_MODEL then
        color = Vector(0,255,0)
    end

    -- Basic event table to send
    local xysize = BuildingHelper:getXYSize(size)
    local event = { state = "active", size = size, size_x = xysize.x, size_y = xysize.y, scale = fMaxScale, builderIndex = builder:GetEntityIndex() }

    -- Set the active variables and callbacks
    local playerID = builder:GetMainControllingPlayer()
    local player = PlayerResource:GetPlayer(playerID)
    local playerTable = BuildingHelper:GetPlayerTable(playerID)
    playerTable.activeBuilder = builder
    playerTable.activeBuilding = unitName
    playerTable.activeBuildingTable = buildingTable
    playerTable.activeCallbacks = callbacks

    -- Offset Z on the model particle
    event.modelOffset = GetUnitKV(unitName, "ModelOffset") or 0

    -- npc_dota_creature doesn't render cosmetics on the particle ghost, use hero names instead
    unitName = GetUnitKV(unitName, "OverrideBuildingGhost") or unitName

    -- 让模型假人将其传递给全景
    local mgd = BuildingHelper:GetOrCreateDummy(unitName)
    event.entindex = mgd:GetEntityIndex()

    -- Range overlay  HasAttackCapability 是否有攻击能力
    if mgd:HasAttackCapability() then
        event.range = buildingTable:GetVal("AttackRange", "number") + mgd:GetHullRadius()
    end

    -- Make a pedestal dummy if required
    -- 有个底座这个东西
    local pedestal = buildingTable:GetVal("PedestalModel")

    if pedestal then
        local prop = BuildingHelper:GetOrCreateProp(pedestal)
        mgd.prop = prop

        -- Add values to the event table
        event.propIndex = prop:GetEntityIndex()
        event.propScale = buildingTable:GetVal("PedestalModelScale", "float") or mgd:GetModelScale()
        event.offsetZ = buildingTable:GetVal("PedestalOffset", "float") or 0
    end

    -- 调整模型方向
    local yaw = buildingTable:GetVal("ModelRotation", "float")
    mgd:SetAngles(0, -yaw, 0)

    -- add by lyjian 
    event.abilityname =  abilName
    CustomGameEventManager:Send_ServerToPlayer(player, "building_helper_enable", event)
end

-- Defines a series of callbacks to be returned in the builder module
function BuildingHelper:SetCallbacks(keys)
    local callbacks = {}

    function keys:OnPreConstruction(callback)
        callbacks.onPreConstruction = callback -- Return false to abort the build
    end

     function keys:OnBuildingPosChosen(callback)
        callbacks.onBuildingPosChosen = callback -- Spend resources here
    end

    function keys:OnConstructionFailed(callback) -- Called if there is a mechanical issue with the building (cant be placed)
        callbacks.onConstructionFailed = callback
    end

    function keys:OnConstructionCancelled(callback) -- Called when player right clicks to cancel a queue
        callbacks.onConstructionCancelled = callback
    end

    function keys:OnConstructionStarted(callback)
        callbacks.onConstructionStarted = callback
    end

    function keys:OnConstructionCompleted(callback)
        callbacks.onConstructionCompleted = callback
    end

    function keys:OnBelowHalfHealth(callback)
        callbacks.onBelowHalfHealth = callback
    end

    function keys:OnAboveHalfHealth(callback)
        callbacks.onAboveHalfHealth = callback
    end

    return callbacks
end

-- 设置生成表，返回构造的表.
function BuildingHelper:SetupBuildingTable(abilityName, builderHandle)

    local buildingTable = GetKeyValue(abilityName)

    function buildingTable:GetVal(key, expectedType)
        local val = buildingTable[key]

        -- 如果没有第二个参数，则直接返回值
        if not expectedType then
            -- 这边兼容下，如果是传的nil就直接false
            if val == "nil" then
                return nil
            end
            return val
        end

        -- Handle missing values.
        if val == nil then
            if expectedType == "bool" then
                return false
            else
                return nil
            end
        end
        
        -- Handle empty values
        local sVal = tostring(val)
        if sVal == "" then
            return nil
        end

        if expectedType == "bool" then
            return sVal == "1"
        elseif expectedType == "number" or expectedType == "float" then
            return tonumber(val)
        end
        
        return sVal
    end

    function buildingTable:SetVal(key, value)
        buildingTable[key] = value
    end

    -- Extract data from the KV files, set is called to guarantee these have values later on in execution
    local unitName = buildingTable:GetVal("UnitName", "string")
    if not unitName then
        BuildingHelper:print('Error: ' .. abilityName .. ' does not have a UnitName KeyValue')
        return
    end
    buildingTable:SetVal("UnitName", unitName)

    -- Self ghosting
    if unitName == "self" then
        unitName = builderHandle:GetUnitName()
    end

    -- Ensure that the unit actually exists
    local unitTable = GetUnitKV(unitName)
    if not unitTable then
        BuildingHelper:print('Error: Definition for Unit ' .. unitName .. ' could not be found in the KeyValue files.')
        return
    end

    local construction_size = unitTable["ConstructionSize"]
    if not construction_size then
        BuildingHelper:print('Error: Unit ' .. unitName .. ' does not have a ConstructionSize KeyValue.')
        return
    end
    buildingTable:SetVal("ConstructionSize", construction_size)

    -- OverrideBuildingGhost
    local override_ghost = GetUnitKV(unitName, "OverrideBuildingGhost")
    if override_ghost then
        buildingTable:SetVal("OverrideBuildingGhost", override_ghost)
    end

    local build_time = buildingTable["BuildTime"] or unitTable["BuildTime"]
    if not build_time then
        BuildingHelper:print('Error: No BuildTime for ' .. unitName .. '. Default to 0.1')
        build_time = 0.1
    end
    buildingTable:SetVal("BuildTime", build_time)

    local attack_range = unitTable["AttackRange"] or 0
    buildingTable:SetVal("AttackRange", attack_range)

    local pathing_size = unitTable["BlockPathingSize"]
    if not pathing_size then
        BuildingHelper:print('Warning: Unit ' .. unitName .. ' does not have a BlockPathingSize KeyValue. Defaulting to 0')
        pathing_size = 0
    end
    buildingTable:SetVal("BlockPathingSize", pathing_size)

    -- Pedestal Model
    local pedestal_model = GetUnitKV(unitName, "PedestalModel")
    if pedestal_model then
        buildingTable:SetVal("PedestalModel", pedestal_model)
    end

    -- Pedestal Scale
    local pedestal_scale = GetUnitKV(unitName, "PedestalModelScale")
    if pedestal_scale then
        buildingTable:SetVal("PedestalModelScale", pedestal_scale)
    end

    -- Pedestal Offset
    local pedestal_offset = GetUnitKV(unitName, "PedestalOffset")
    if pedestal_offset then
        buildingTable:SetVal("PedestalOffset", pedestal_offset)
    end

    -- If the construction requires certain grid type, store it
    local requires = unitTable["Requires"]
    if not requires then
        requires = "Buildable"
    end
    buildingTable:SetVal("Requires", string.upper(requires))

    local prevents = unitTable["Prevents"]
    if prevents then
        buildingTable:SetVal("Prevents", string.upper(prevents))
    end

    local castRange = buildingTable:GetVal("AbilityCastRange", "number")
    if not castRange then
        castRange = 200
    end
    buildingTable:SetVal("AbilityCastRange", castRange)

    local fMaxScale = buildingTable:GetVal("MaxScale", "float")
    if not fMaxScale then
        -- If no MaxScale is defined, check the Units "ModelScale" KeyValue. Otherwise just default to 1
        fMaxScale = GetUnitKV(unitName, "ModelScale") or 1
    end
    buildingTable:SetVal("MaxScale", fMaxScale)

    local fModelRotation = buildingTable:GetVal("ModelRotation", "float")
    if not fModelRotation then
        -- If no defined, check the Units KeyValue. Otherwise just default to 0
        fModelRotation = GetUnitKV(unitName, "ModelRotation") or 0
    end
    buildingTable:SetVal("ModelRotation", fModelRotation)

    return buildingTable
end

-- 派一个建筑工人开始建筑
function BuildingHelper:OrderBuildingConstruction(builder, ability, position)
    ExecuteOrderFromTable({UnitIndex = builder:GetEntityIndex(), OrderType = DOTA_UNIT_ORDER_STOP, Queue = false}) 
    Build({caster=builder, ability=ability})
    BuildingHelper:AddToQueue(builder, position, false)
end

-- 将新建筑置于完全健康状态并返回句柄。放置栅格导航拦截器
-- 跳过建造阶段，不需要建造者，这一点在游戏开始时为玩家放置“基础”建筑是最重要的。
-- 在调用此代码之前，请确保该位置有效.
function BuildingHelper:PlaceBuilding(player, name, location, construction_size, pathing_size, angle)
    construction_size = construction_size or BuildingHelper:GetConstructionSize(name)
    pathing_size = pathing_size or BuildingHelper:GetBlockPathingSize(name)
    -- BuildingHelper:SnapToGrid(construction_size, location)
    BuildingHelper:SnapToGridXY(construction_size, location)

    local playerID = type(player)=="number" and player or player:GetPlayerID() --accept pass player ID or player Handle
    local player = PlayerResource:GetPlayer(playerID)
    local playersHero = PlayerResource:GetSelectedHeroEntity(playerID)
    BuildingHelper:print("PlaceBuilding for playerID ".. playerID)

    -- 放置建筑前生成点障碍物
    local gridNavBlockers = BuildingHelper:BlockGridSquares(construction_size, pathing_size, location)

    -- Adjust the model position z
    local model_offset = GetUnitKV(name, "ModelOffset") or 0
    local model_location = Vector(location.x, location.y, location.z + model_offset)

    -- 生成建筑
    local building = CreateUnitByName(name, model_location, false, playersHero, player, playersHero:GetTeamNumber())
    building:SetControllableByPlayer(playerID, true)
    building:SetNeverMoveToClearSpace(true)
    building:SetOwner(playersHero)
    building:SetAbsOrigin(model_location)
    building.construction_size = construction_size
    building.blockers = gridNavBlockers

    -- Building Settings
    BuildingHelper:AddModifierBuilding(building)

    -- Create pedestal
    local pedestal = GetUnitKV(name, "PedestalModel")
    if pedestal then
        BuildingHelper:CreatePedestalForBuilding(building, name, GetGroundPosition(location, nil), pedestal)
    end

    if angle then
        building:SetAngles(0,-angle,0)
    end

    BuildingHelper:AddBuildingToPlayerTable(playerID, building)

    -- Return the created building
    return building
end

-- 按名称将建筑替换为新建筑，更新必要的参照并返回新创建的单元
function BuildingHelper:UpgradeBuilding(keys)
    local builder = keys.caster
    local building = keys.unit
    local ability = keys.ability
    local newName = keys.UnitName

    local oldBuildingName = building:GetUnitName()
    BuildingHelper:print("Upgrading Building: "..oldBuildingName.." -> "..newName)
    local playerID = building:GetPlayerOwnerID()
    local position = building:GetAbsOrigin()
    local angle = GetUnitKV(newName, "ModelRotation") or -building:GetAngles().y
    
    local old_offset = GetUnitKV(oldBuildingName, "ModelOffset") or 0
    position.z = position.z - old_offset

    -- Kill the old building
    building:AddEffects(EF_NODRAW) --Hide it, so that it's still accessible after this script
    building.upgraded = true --Skips visual effects
    building:ForceKill(true) --This will call RemoveBuilding
    
    -- Create the new building
    local new_building = BuildingHelper:PlaceBuilding(playerID, newName, position, BuildingHelper:GetConstructionSize(newName), BuildingHelper:GetBlockPathingSize(newName), angle)

    -- 尝试加上建造时间 
    local abilName = ability:GetAbilityName()
    -- npc_units_custom.txt 这个里面的配置
    local buildingTable = BuildingHelper:SetupBuildingTable(abilName, builder)

    -- local bRequiresRepair = buildingTable:GetVal("RequiresRepair", "bool")
    local bBuilderInside = buildingTable:GetVal("BuilderInside", "bool")
    local bConsumesBuilder = buildingTable:GetVal("ConsumesBuilder", "bool")
    -- buildTime can be overriden in the construction start callback
    local buildTime = buildingTable:GetVal("BuildTime", "float")
    new_building.buildTime = buildTime
    if new_building.overrideBuildTime then buildTime = new_building.overrideBuildTime end

    local startTime = GameRules:GetGameTime()
    -- 建筑应该在什么时间建造完成
    local fTimeBuildingCompleted = startTime + buildTime

    -- Dota服务器以每秒30帧的速度更新
    local fserverFrameRate = 1/30

    -- Max and Initial Health factor
    local fMaxHealth = new_building:GetMaxHealth()
    local fInitialHealthFactor = BuildingHelper.Settings["INITIAL_HEALTH_FACTOR"]
    -- fInitialHealthFactor 建筑物应开始的血量百分比  fMaxHealth 建筑的最大血量
    -- 这边nInitialHealth 就是建筑的初始血量
    local nInitialHealth = math.floor(fInitialHealthFactor * (fMaxHealth))
    -- 刷新率 和 增加血量的那什么的 最大值
    local fUpdateHealthInterval = math.max(fserverFrameRate, buildTime / math.floor(fMaxHealth-nInitialHealth)) -- health tick interval
    -- 设置一下初始血量
    new_building:SetHealth(nInitialHealth)

    local fAddedHealth = 0
    local nHealthInterval = (fMaxHealth-nInitialHealth) / (buildTime / fserverFrameRate)
    local fSmallHealthInterval = nHealthInterval - math.floor(nHealthInterval) -- just the floating point component
    nHealthInterval = math.floor(nHealthInterval)
    local fHPAdjustment = 0

    new_building.updateHealthTimer = Timers:CreateTimer(function()
        if IsValidEntity(new_building) and new_building:IsAlive() then
            -- timesUp 时间到了建造完成时间 或者建筑血量到了建筑的最大血量的时候
            local timesUp = GameRules:GetGameTime() >= fTimeBuildingCompleted or new_building:GetHealth() == new_building:GetMaxHealth()
            if not timesUp then
                -- Use +1 every frame or float adjustment
                local hpGain = 0
                if fUpdateHealthInterval <= fserverFrameRate then
                    fHPAdjustment = fHPAdjustment + fSmallHealthInterval
                    if fHPAdjustment > 1 then
                        hpGain = nHealthInterval + 1
                        fHPAdjustment = fHPAdjustment - 1
                    else
                        hpGain = nHealthInterval
                    end
                else
                    hpGain = 1
                end

                -- Fasten up
                if GameRules.WarpTen then
                    hpGain = hpGain * 42
                end

                if hpGain > 0 then
                    fAddedHealth = fAddedHealth + hpGain
                    new_building:SetHealth(new_building:GetHealth() + hpGain)
                end
            else
                local adjustment = fMaxHealth - fAddedHealth - nInitialHealth
                if adjustment > 0 then
                    new_building:SetHealth(new_building:GetHealth() + fMaxHealth - fAddedHealth - nInitialHealth) -- round up the last little bit
                end
                BuildingHelper:print(string.format("Finished %s in %.2f seconds. HP was off by %.2f",new_building:GetUnitName(),GameRules:GetGameTime()-startTime,adjustment))

                -- completion: timesUp is true
                -- if callbacks.onConstructionCompleted then
                --    building.constructionCompleted = true
                --    building.builder = builder
                --    BuildingHelper:AddBuildingToPlayerTable(playerID, building)
                --    callbacks.onConstructionCompleted(building)
                -- end

                -- Eject Builder
                if bBuilderInside then
                
                    -- Consume Builder
                    if bConsumesBuilder then
                        new_building:ForceKill(true)
                    else
                        BuildingHelper:ShowBuilder(new_building)
                    end

                    -- Advance Queue
                    BuildingHelper:AdvanceQueue(new_building)
                end
            
                return
            end
        else
            -- Building destroyed

            -- Eject Builder
            if bBuilderInside then
                new_building:RemoveModifierByName("modifier_builder_hidden")
                new_building:RemoveNoDraw()
            end

            -- Advance Queue
            BuildingHelper:AdvanceQueue(new_building)

            return nil
        end
        return fUpdateHealthInterval
    end)    

    -- 如果有单位在维修旧建筑，请将其重定向到新建筑
    if building.units_repairing then
        for _,builder in pairs(building.units_repairing) do
            builder.repair_target = new_building
        end
    end
    new_building.units_repairing = building.units_repairing
    building.upgraded_to = new_building

    return new_building
end

-- 移除建筑，将其从gridnav中移除，并使用可选参数跳过粒子效果
function BuildingHelper:RemoveBuilding(building, bSkipEffects)
    local buildingName = building:GetUnitName()
    BuildingHelper:print("Removing Building: "..buildingName)

    -- Don't show the destruction effects when specified or killed to due UpgradeBuilding
    if not bSkipEffects and building.upgraded ~= true then
        local particleName = building:GetKeyValue("DestructionEffect")
        if particleName then
            local particle = ParticleManager:CreateParticle(particleName, PATTACH_CUSTOMORIGIN, building)
            ParticleManager:SetParticleControlEnt(particle, 0, building, PATTACH_POINT_FOLLOW, "attach_origin", building:GetAbsOrigin(), true)
        end

        if building.fireEffectParticle then
            ParticleManager:DestroyParticle(building.fireEffectParticle, false)
        end
    end

    if building.prop then
        UTIL_Remove(building.prop)
    end

    BuildingHelper:FreeGridSquares(BuildingHelper:GetConstructionSize(building), building:GetAbsOrigin())

    -- Remove handle and decrement count tracking
    local playerID = building:GetPlayerOwnerID()
    local buidingList = BuildingHelper:GetBuildings(playerID)
    local index = getIndexTable(buidingList, building)
    if index then
        table.remove(buidingList, index)
        BuildingHelper:SetBuildingCount(playerID, buildingName, BuildingHelper:GetBuildingCount(playerID, buildingName)-1)
    else
        buildingList = BuildingHelper:GetBuildingsUnderConstruction(playerID)
        index = getIndexTable(buildingList, building)
        if index then
            table.remove(buildingList, index)
            local constructionCount = self:GetBuildingCount(playerID, buildingName, true)
            self:SetBuildingCount(playerID, buildingName, constructionCount-1, true)
        end
    end

    if not building.blockers then return end
    for k, v in pairs(building.blockers) do
        UTIL_Remove(v)
    end
end

-- 创建建筑并开始施工过程
function BuildingHelper:StartBuilding(builder)
    local playerID = builder:GetMainControllingPlayer()
    local work = builder.work
    local callbacks = work.callbacks
    local building = work.entity -- The building entity
    local unitName = work.name
    local location = work.location
    local player = PlayerResource:GetPlayer(playerID)
    local playersHero = PlayerResource:GetSelectedHeroEntity(playerID)
    local buildingTable = work.buildingTable
    -- local construction_size = buildingTable:GetVal("ConstructionSize", "number")
    local construction_size = buildingTable:GetVal("ConstructionSize")
    -- local pathing_size = buildingTable:GetVal("BlockPathingSize", "number")
    local pathing_size = buildingTable:GetVal("BlockPathingSize")

    -- 检查gridnav，如果无效则取消
    if not BuildingHelper:ValidPosition(construction_size, location, builder, callbacks) then
        
        -- 移除模型粒子并前进队列
        BuildingHelper:AdvanceQueue(builder)
        BuildingHelper:ClearWorkParticles(work)

        -- Remove pedestal
        BuildingHelper:RemoveEntity(work.entity.prop)

        -- 大楼被取消了，退还资源
        work.refund = true
        callbacks.onConstructionCancelled(work)
        return
    end

    BuildingHelper:print("Initializing Building Entity: "..unitName.." at "..VectorString(location))

    -- 标记此正在进行的工作，如果取消，则跳过退款，因为建筑已放置
    work.inProgress = true

    -- 放置建筑前生成点障碍物
    local gridNavBlockers = BuildingHelper:BlockGridSquares(construction_size, pathing_size, location)

    -- 对于覆盖的幽灵，我们需要创建另一个单位
    if building:GetUnitName() ~= unitName then
        building = CreateUnitByName(unitName, location, false, playersHero, player, builder:GetTeam())
        building:SetNeverMoveToClearSpace(true)
    else
        building:RemoveModifierByName("modifier_out_of_world")
        building:RemoveEffects(EF_NODRAW)
    end

    -- Make pedestal
    local pedestal = GetUnitKV(unitName, "PedestalModel")
    if pedestal then
        BuildingHelper:CreatePedestalForBuilding(building, unitName, location, pedestal)
    end

    -- Initialize the building
    local model_offset = GetUnitKV(unitName, "ModelOffset") or 0
    location.z = location.z + model_offset
    building:SetAbsOrigin(location)
    building.blockers = gridNavBlockers
    building.construction_size = construction_size
    building.buildingTable = buildingTable
    self:AddBuildingToPlayerTable(playerID, building, true)

    -- Adjust the Model Orientation
    local yaw = buildingTable:GetVal("ModelRotation", "float")
    building:SetAngles(0, -yaw, 0)

    -- Building Settings
    BuildingHelper:AddModifierBuilding(building)

    -- Prevent regen messing with the building spawn hp gain
    local regen = building:GetBaseHealthRegen()
    building:SetBaseHealthRegen(0)

    ------------------------------------------------------------------
    -- Build Behaviours
    --  RequiresRepair: 如果设置为1，它将放置建筑，并且不会更新其运行状况，也不会发送OnConstructionCompleted回调，直到其完全修复
    --  BuilderInside: 将建筑商置于建筑中的不可选择/不可攻击/不可健康栏中
    --  ConsumesBuilder: 施工结束后杀死建筑工人
    local bRequiresRepair = buildingTable:GetVal("RequiresRepair", "bool")
    local bBuilderInside = buildingTable:GetVal("BuilderInside", "bool")
    local bConsumesBuilder = buildingTable:GetVal("ConsumesBuilder", "bool")
    -------------------------------------------------------------------

    -- whether the building is controllable or not
    local bPlayerCanControl = buildingTable:GetVal("PlayerCanControl", "bool")
    if bPlayerCanControl then
        building:SetControllableByPlayer(playerID, true)
        building:SetOwner(playersHero)
    end

    -- Start construction
    if callbacks.onConstructionStarted then
        callbacks.onConstructionStarted(building)
    end

    -- buildTime can be overriden in the construction start callback
    local buildTime = buildingTable:GetVal("BuildTime", "float")
    building.buildTime = buildTime
    if building.overrideBuildTime then buildTime = building.overrideBuildTime end

    local startTime = GameRules:GetGameTime()
    -- 建筑应该在什么时间建造完成
    local fTimeBuildingCompleted = startTime + buildTime

    -- Dota服务器以每秒30帧的速度更新
    local fserverFrameRate = 1/30

    -- Max and Initial Health factor
    local fMaxHealth = building:GetMaxHealth()
    local fInitialHealthFactor = BuildingHelper.Settings["INITIAL_HEALTH_FACTOR"]
    -- fInitialHealthFactor 建筑物应开始的血量百分比  fMaxHealth 建筑的最大血量
    -- 这边nInitialHealth 就是建筑的初始血量
    local nInitialHealth = math.floor(fInitialHealthFactor * (fMaxHealth))
    -- 刷新率 和 增加血量的那什么的 最大值
    local fUpdateHealthInterval = math.max(fserverFrameRate, buildTime / math.floor(fMaxHealth-nInitialHealth)) -- health tick interval
    -- 设置一下初始血量
    building:SetHealth(nInitialHealth)

    local bScale = buildingTable:GetVal("Scale", "bool") -- whether we should scale the building.
    local fInitialModelScale = 0.2 -- initial size
    local fMaxScale = building.overrideMaxScale or buildingTable:GetVal("MaxScale", "float") or 1 -- the amount to scale to
    local fScaleInterval = (fMaxScale-fInitialModelScale) / (buildTime / fserverFrameRate) -- scale to add every frame, distributed by build time
    local fCurrentScale = fInitialModelScale -- start the building at the initial model scale
    local bScaling = false -- Keep tracking if we're currently model scaling.
    
    -- Set initial scale
    if bScale then
        building:SetModelScale(fCurrentScale)
        bScaling = true
    end

    -- Put the builder invulnerable inside the building in construction
    if bBuilderInside then
        BuildingHelper:HideBuilder(builder, location, building)
    end

    -- 运行状况更新计时器和行为
    if not bRequiresRepair then

        if not bBuilderInside then
            -- Advance Queue
            BuildingHelper:AdvanceQueue(builder)
        end

        local fAddedHealth = 0
        local nHealthInterval = (fMaxHealth-nInitialHealth) / (buildTime / fserverFrameRate)
        local fSmallHealthInterval = nHealthInterval - math.floor(nHealthInterval) -- just the floating point component
        nHealthInterval = math.floor(nHealthInterval)
        local fHPAdjustment = 0

        building.updateHealthTimer = Timers:CreateTimer(function()
            if IsValidEntity(building) and building:IsAlive() then
                -- timesUp 时间到了建造完成时间 或者建筑血量到了建筑的最大血量的时候
                local timesUp = GameRules:GetGameTime() >= fTimeBuildingCompleted or building:GetHealth() == building:GetMaxHealth()
                if not timesUp then
                    -- Use +1 every frame or float adjustment
                    local hpGain = 0
                    if fUpdateHealthInterval <= fserverFrameRate then
                        fHPAdjustment = fHPAdjustment + fSmallHealthInterval
                        if fHPAdjustment > 1 then
                            hpGain = nHealthInterval + 1
                            fHPAdjustment = fHPAdjustment - 1
                        else
                            hpGain = nHealthInterval
                        end
                    else
                        hpGain = 1
                    end

                    -- Fasten up
                    if GameRules.WarpTen then
                        hpGain = hpGain * 42
                    end

                    if hpGain > 0 then
                        fAddedHealth = fAddedHealth + hpGain
                        building:SetHealth(building:GetHealth() + hpGain)
                    end
                else
                    local adjustment = fMaxHealth - fAddedHealth - nInitialHealth
                    if adjustment > 0 then
                        building:SetHealth(building:GetHealth() + fMaxHealth - fAddedHealth - nInitialHealth) -- round up the last little bit
                    end
                    BuildingHelper:print(string.format("Finished %s in %.2f seconds. HP was off by %.2f",building:GetUnitName(),GameRules:GetGameTime()-startTime,adjustment))

                    -- completion: timesUp is true
                    if callbacks.onConstructionCompleted then
                        building.constructionCompleted = true
                        building.builder = builder
                        BuildingHelper:AddBuildingToPlayerTable(playerID, building)
                        callbacks.onConstructionCompleted(building)
                    end

                    -- Eject Builder
                    if bBuilderInside then
                    
                        -- Consume Builder
                        if bConsumesBuilder then
                            builder:ForceKill(true)
                        else
                            BuildingHelper:ShowBuilder(builder)
                        end

                        -- Advance Queue
                        BuildingHelper:AdvanceQueue(builder)
                    end
                
                    return
                end
            else
                -- Building destroyed

                -- Eject Builder
                if bBuilderInside then
                    builder:RemoveModifierByName("modifier_builder_hidden")
                    builder:RemoveNoDraw()
                end

                -- Advance Queue
                BuildingHelper:AdvanceQueue(builder)

                return nil
            end
            return fUpdateHealthInterval
        end)    
    else
        -- The building will have to be assisted through a repair ability
        local repair_ability = BuildingHelper:GetRepairAbility(builder)
        if repair_ability then
            self:print("Building "..building:GetUnitName().." will be constructed using RepairAbility")
            building.repair_distance = (builder:GetAbsOrigin() - building:GetAbsOrigin()):Length2D() -- To instantly start repairing
            building.callbacks = callbacks
            BuildingHelper:StartRepair(builder, building)
        else
            self:print("Error, couldn't find \"RepairAbility\" of "..builder:GetUnitName())
        end
    end

    -- Scale Update Timer
    if bScale then
        building.updateScaleTimer = Timers:CreateTimer(function()
            if IsValidEntity(building) and building:IsAlive() then
                local timesUp = GameRules:GetGameTime() >= fTimeBuildingCompleted
                if not timesUp then
                    if bScaling then
                        if fCurrentScale < fMaxScale then
                            fCurrentScale = fCurrentScale+fScaleInterval
                            building:SetModelScale(fCurrentScale)
                        else
                            building:SetModelScale(fMaxScale)
                            bScaling = false
                        end
                    end
                else
                    
                    BuildingHelper:print("Scale was off by: "..(fMaxScale - fCurrentScale))
                    building:SetModelScale(fMaxScale)
                    return
                end
            else
                -- not valid ent
                return
            end
            
            return fserverFrameRate
        end)
    end

    -- OnBelowHalfHealth timer
    building.onBelowHalfHealthProc = false
    building.healthChecker = Timers:CreateTimer(.2, function()
        local fireEffect = GetUnitKV(unitName, "FireEffect")
        local attachPoint = GetUnitKV(unitName, "AttachPoint")

        if IsValidEntity(building) and building:IsAlive() then
            local health_percentage = building:GetHealthPercent() * 0.01
            local belowThreshold = health_percentage < BuildingHelper.Settings["FIRE_EFFECT_FACTOR"]
            if belowThreshold and not building.onBelowHalfHealthProc and building.state == "complete" then
                if fireEffect then
                    -- Fire particle
                    if attachPoint then
                        building.fireEffectParticle = ParticleManager:CreateParticle(fireEffect, PATTACH_CUSTOMORIGIN_FOLLOW, building)
                        ParticleManager:SetParticleControlEnt(building.fireEffectParticle, 0, building, PATTACH_POINT_FOLLOW, attachPoint, building:GetAbsOrigin(), true)
                    else
                        building.fireEffectParticle = ParticleManager:CreateParticle(fireEffect, PATTACH_ABSORIGIN_FOLLOW, building)
                    end
                end
            
                callbacks.onBelowHalfHealth(building)
                building.onBelowHalfHealthProc = true
            elseif not belowThreshold and building.onBelowHalfHealthProc and building.state == "complete" then
                if fireEffect then
                    ParticleManager:DestroyParticle(building.fireEffectParticle, false)
                end

                callbacks.onAboveHalfHealth(building)
                building.onBelowHalfHealthProc = false
            end
        else
            return nil
        end
        return .2
    end)

    -- Remove the work particles
    BuildingHelper:ClearWorkParticles(work)
end

-- Starts the repair process when the builder is on range of the target
function BuildingHelper:StartRepair(builder, target)
    local work = builder.work
    local underConstruction = IsCustomBuilding(target) and target:IsUnderConstruction() -- For RequiresRepair building behaviour
    
    -- Check target and cancel if invalid
    local repair_ability = BuildingHelper:GetRepairAbility(builder)
    if underConstruction and repair_ability and not repair_ability:GetKeyValue("CanAssistConstruction") then
        self:print("The Repair Ability "..repair_ability:GetAbilityName().." can't be used to assist construction! Cancelling")

        -- Advance Queue
        BuildingHelper:AdvanceQueue(builder)

        BuildingHelper:OnRepairCancelled(builder, target)
        return
    end

    -- External repair callback
    self:OnRepairStarted(builder, target)

    -- Initialize builder list
    target.units_repairing = target.units_repairing or {}
    table.insert(target.units_repairing, builder)
    builder.repair_target = target

    -- Look towards the building
    builder:Stop()
    builder:SetForwardVector((target:GetAbsOrigin() - builder:GetAbsOrigin()):Normalized())

    local buildTime = target.buildTime or target:GetKeyValue("BuildTime")
    local costRatio = repair_ability and repair_ability:GetKeyValue("RepairCostRatio") or BuildingHelper.Settings.REPAIR_SETTINGS["RepairCostRatio"]
    local timeRatio = repair_ability and repair_ability:GetKeyValue("RepairTimeRatio") or BuildingHelper.Settings.REPAIR_SETTINGS["RepairTimeRatio"]
    local powerBuildCost = repair_ability and repair_ability:GetKeyValue("PowerbuildCost") or BuildingHelper.Settings.REPAIR_SETTINGS["PowerbuildCost"]
    local powerBuildRate = repair_ability and repair_ability:GetKeyValue("PowerbuildRate") or BuildingHelper.Settings.REPAIR_SETTINGS["PowerbuildRate"]

    -- C++ -> Lua Double nonsense
    function correctFloat(f) return tonumber(string.format("%.4f", f)) end
    timeRatio = correctFloat(timeRatio)
    costRatio = correctFloat(costRatio)
    powerBuildCost = correctFloat(powerBuildCost)
    powerBuildRate = correctFloat(powerBuildRate)

    local fserverFrameRate = 1/30
    local fAddedHealth = 0
    local fHPAdjustment = 0

    local repairing = {}
    for k,v in pairs(target.units_repairing) do
        if IsValidEntity(v) and v:IsAlive() then
            table.insert(repairing, v)
        end
    end
    target.units_repairing = repairing

    builder.state = "repairing"
    builder.lastRepairPosition = builder:GetAbsOrigin()
    builder:AddNewModifier(builder, repair_ability, "modifier_builder_repairing", {})
    target:AddNewModifier(target, repair_ability, "modifier_repairing", {})
    target:SetModifierStackCount("modifier_repairing", target, getTableCount(target.units_repairing))

    -- If its an unfinished building, keep track of how much does it require to mark as finished
    if underConstruction and not target.missingHealthToComplete then
        target.missingHealthToComplete = target:GetHealthDeficit()
    end

    -- Repair Dynamic Tick
    if not target.repairTimer then
        target.repairTimer = Timers:CreateTimer(function()
            local builderCount = 0
            for k,v in pairs(target.units_repairing) do
                if IsValidEntity(v) and v:IsAlive() then builderCount = builderCount + 1 end
            end

            if not IsValidEntity(target) or not target:IsAlive() then
                if target and target.units_repairing and not target.upgraded then
                    self:CancelRepair(target)
                    return
                end

                -- Redirect in case of upgrade
                if target.upgraded and target.units_repairing then
                    target = target.upgraded_to
                    if not IsValidEntity(repair_ability) then
                        repair_ability = target.units_repairing[1]:GetRepairAbility()
                    end
                    if not IsValidEntity(repair_ability) then
                        self:print("Something went wrong, couldn't get a RepairAbility on the first repairing unit")
                    else
                        target:AddNewModifier(target, repair_ability, "modifier_repairing", {})
                    end
                end
            end

            target:SetModifierStackCount("modifier_repairing", target, builderCount)
            if builderCount == 0 then
                self:CancelRepair(target)
                return
            end

            -- Finished repairing?
            local health_deficit = target.missingHealthToComplete or target:GetHealthDeficit()
            if health_deficit <= 0 then
                target.missingHealthToComplete = nil
                self:CancelRepair(target)

                if target.callbacks and target.callbacks.onConstructionCompleted then
                    target.constructionCompleted = true
                    BuildingHelper:AddBuildingToPlayerTable(target:GetPlayerOwnerID(), target)
                    target.callbacks.onConstructionCompleted(target)
                end

                self:OnRepairFinished(builder, target)
                return
            end

            -- Builders must be stopped and close to the target to count and heal hitpoints
            builderCount = BuildingHelper:GetNumBuildersRepairing(target)
            if builderCount == 0 then return fserverFrameRate end

            local buildTimeFactor = timeRatio*(powerBuildRate^(builderCount-1))
            local nextTick = (buildTime*buildTimeFactor)/target:GetMaxHealth()
            local hpGain = 0

            -- Calculate the HP to be gained on this tick
            if nextTick > fserverFrameRate then
                hpGain = 1
            else
                local nHealthInterval = target:GetMaxHealth() / (buildTime*buildTimeFactor / fserverFrameRate)
                local fSmallHealthInterval = nHealthInterval - math.floor(nHealthInterval) --floating point component
                nHealthInterval = math.floor(nHealthInterval)

                -- How much HP do we add this frame?
                fHPAdjustment = fHPAdjustment + fSmallHealthInterval
                if fHPAdjustment > 1 then
                    fHPAdjustment = fHPAdjustment - 1
                    hpGain = nHealthInterval + 1
                elseif nHealthInterval > 0 then
                    hpGain = nHealthInterval
                end

                nextTick = fserverFrameRate
            end

            local buildCostFactor = costRatio + powerBuildCost*(builderCount-1)

            -- Don't expend resources for the first unit repairing a building if its a construction
            if underConstruction then
                if builderCount == 1 then
                    buildCostFactor = 0
                else
                    buildCostFactor = costRatio + powerBuildCost*(builderCount-2)
                end
            end

            -- Fasten up
            if GameRules.WarpTen then
                hpGain = hpGain * 42
                buildCostFactor = buildCostFactor * 42
            end
            
            if hpGain > 0 then
                if target.missingHealthToComplete then
                    target.missingHealthToComplete = target.missingHealthToComplete - hpGain
                end
                local bCanPayResource = true
                if buildCostFactor > 0 then
                    bCanPayResource = self:OnRepairTick(target, hpGain, buildCostFactor) ~= false
                end
                
                if bCanPayResource then
                    --self:print("Repaired "..target:GetUnitName().." with "..builderCount.." builders for "..hpGain.." | Time Factor: "..buildTimeFactor.." | Cost Factor: "..buildCostFactor)
                    target:SetHealth(target:GetHealth() + hpGain)
                else
                    self:print("Repair Ended, not enough resources!")
                    self:CancelRepair(target)
                    return
                end
            end

            return nextTick
        end)
    end
end

function BuildingHelper:GetNumBuildersRepairing(target)
    if not target.units_repairing then return 0 end

    local targetPos = target:GetAbsOrigin()
    local numReparing = 0
    for _,unit in pairs(target.units_repairing) do
        if IsValidEntity(unit) then
            local currentPos = unit:GetAbsOrigin()
            if not unit.lastRepairPosition then
                unit.lastRepairPosition = currentPos
                unit.state = "repairing"
                numReparing = numReparing + 1
            else
                local changedPosition = (unit.lastRepairPosition-currentPos):Length2D() > 1
                if changedPosition or (targetPos-currentPos):Length2D() > (unit.repairRange or unit:GetFollowRange(target)) then
                    unit.state = "moving_to_repair"
                    unit:MoveToNPC(target)
                else
                    unit.state = "repairing"
                    numReparing = numReparing + 1
                end
                unit.lastRepairPosition = currentPos
            end
        end
    end
    return numReparing
end

function BuildingHelper:CancelRepair(building)
    building.repairTimer = nil
    if building.units_repairing == nil then return end
    for k,v in pairs(building.units_repairing) do
        if IsValidEntity(v) and v:IsAlive() then
            v:RemoveModifierByName("modifier_builder_repairing")
            local repair_ability = BuildingHelper:GetRepairAbility(v)
            if repair_ability and repair_ability:GetToggleState() then
                repair_ability:ToggleAbility()
            end
            v.state = "idle"
            if IsValidEntity(building) then
                self:OnRepairCancelled(v, building)
            end
            BuildingHelper:AdvanceQueue(v)
        end
    end
    building.units_repairing = {}

    if IsValidEntity(building) then
        building:RemoveModifierByName("modifier_repairing")
        self:print("Repair of "..building:GetUnitName().." fully cancelled")
    else
        self:print("Building removed during the repair process")
    end
end

-- 在服务器网格上的某个位置阻止具有特定结构和路径大小的正方形
-- construction_size: 要阻止施工的网格点的平方
-- pathing_size: 将产生的路径障碍物的平方 
function BuildingHelper:BlockGridSquares(construction_size, pathing_size, location)
    BuildingHelper:RemoveGridType(construction_size, location, "BUILDABLE")
    BuildingHelper:AddGridType(construction_size, location, "BLOCKED")

    -- return BuildingHelper:BlockPSO(5, location)
    return BuildingHelper:BlockPSOXY(pathing_size, location)
end

function BuildingHelper:BlockPSOXY(size, location)
    local sizexy = BuildingHelper:getXYSize(size)
    if sizexy.x == 0 or sizexy.y == 0 then return end

    local pos = Vector(location.x, location.y, location.z)
    BuildingHelper:SnapToGridXY(size, pos)
    
    local gridNavBlockers = {}
    if sizexy.x % 2 == 1 then
        if sizexy.y % 2 == 1 then 
            for x = pos.x - (sizexy.x-2) * 32, pos.x + (sizexy.x-2) * 32, 64 do
                for y = pos.y - (sizexy.y-2) * 32, pos.y + (sizexy.y-2) * 32, 64 do
                    local blockerLocation = Vector(x, y, pos.z)
                    local ent = SpawnEntityFromTableSynchronous("point_simple_obstruction", {origin = blockerLocation})
                    table.insert(gridNavBlockers, ent)
                end
            end
        else
            local leny = sizexy.y * 32 - 64
            for x = pos.x - (sizexy.x-2) * 32, pos.x + (sizexy.x-2) * 32, 64 do
                for y = pos.y - leny, pos.y + leny, 128 do
                    local blockerLocation = Vector(x, y, pos.z)
                    local ent = SpawnEntityFromTableSynchronous("point_simple_obstruction", {origin = blockerLocation})
                    table.insert(gridNavBlockers, ent)
                end
            end
        end 
    else
        local lenx = sizexy.x * 32 - 64
        if sizexy.y % 2 == 1 then 
            for x = pos.x - lenx, pos.x + lenx, 128 do
                for y = pos.y - (sizexy.y-2) * 32, pos.y + (sizexy.y-2) * 32, 64 do
                    local blockerLocation = Vector(x, y, pos.z)
                    local ent = SpawnEntityFromTableSynchronous("point_simple_obstruction", {origin = blockerLocation})
                    table.insert(gridNavBlockers, ent)
                end
            end
        else
            local leny = sizexy.y * 32 - 64
            if lenx == 0 and leny == 0 then
                local ent = SpawnEntityFromTableSynchronous("point_simple_obstruction", {origin = pos})
                table.insert(gridNavBlockers, ent)
            else
                for x = pos.x - lenx, pos.x + lenx, 128 do
                    for y = pos.y - leny, pos.y + leny, 128 do
                        local blockerLocation = Vector(x, y, pos.z)
                        local ent = SpawnEntityFromTableSynchronous("point_simple_obstruction", {origin = blockerLocation})
                        table.insert(gridNavBlockers, ent)
                    end
                end
            end
        end 
    end

    return gridNavBlockers
end

-- 在一个位置生成一个正方形的点_简单_障碍实体
-- 就是设置拦截的实体
function BuildingHelper:BlockPSO(size, location)
    if size == 0 then return end

    local pos = Vector(location.x, location.y, location.z)
    BuildingHelper:SnapToGrid(size, pos)

    local gridNavBlockers = {}
    if size % 2 == 1 then
        for x = pos.x - (size-2) * 32, pos.x + (size-2) * 32, 64 do
            for y = pos.y - (size-2) * 32, pos.y + (size-2) * 32, 64 do
                local blockerLocation = Vector(x, y, pos.z)
                local ent = SpawnEntityFromTableSynchronous("point_simple_obstruction", {origin = blockerLocation})
                table.insert(gridNavBlockers, ent)
            end
        end
    else
        local len = size * 32 - 64
        if len == 0 then
            local ent = SpawnEntityFromTableSynchronous("point_simple_obstruction", {origin = pos})
            table.insert(gridNavBlockers, ent)
        else
            for x = pos.x - len, pos.x + len, 128 do
                for y = pos.y - len, pos.y + len, 128 do
                    local blockerLocation = Vector(x, y, pos.z)
                    local ent = SpawnEntityFromTableSynchronous("point_simple_obstruction", {origin = blockerLocation})
                    table.insert(gridNavBlockers, ent)
                end
            end
        end
    end

    return gridNavBlockers
end

-- Clears out an area for construction
function BuildingHelper:FreeGridSquares(construction_size, location)
    BuildingHelper:RemoveGridType(construction_size, location, "BLOCKED")
    BuildingHelper:AddGridType(construction_size, location, "BUILDABLE")
end

function BuildingHelper:NewGridType(grid_type)
    grid_type = string.upper(grid_type)
    BuildingHelper.GridTypes[grid_type] = BuildingHelper.NextGridValue
    BuildingHelper.NextGridValue = BuildingHelper.NextGridValue * 2
    CustomNetTables:SetTableValue("building_settings", "grid_types", BuildingHelper.GridTypes)
end

-- 将网格类型添加到以某个位置为中心的正方形中
function BuildingHelper:AddGridType(size, location, grid_type, shape)
    -- If it doesn't exist, add it
    grid_type = string.upper(grid_type)
    if not BuildingHelper.GridTypes[grid_type] then
        BuildingHelper:NewGridType(grid_type)
    end

    if shape == "radius" then
        BuildingHelper:SetGridTypeRadiusXY(size, location, grid_type, "add")
    else
        BuildingHelper:SetGridTypeXY(size, location, grid_type, "add")
    end
end

-- Removes grid_type from every cell of a square around the location
function BuildingHelper:RemoveGridType(size, location, grid_type, shape)
    if shape == "radius" then
        BuildingHelper:SetGridTypeRadiusXY(size, location, grid_type, "remove")
    else
        BuildingHelper:SetGridTypeXY(size, location, grid_type, "remove")
    end
end

function BuildingHelper:SetGridTypeXY(size, location, grid_type, option)
    if not size or size == 0 then return end
    local sizexy = BuildingHelper:getXYSize(size)

    local originX = GridNav:WorldToGridPosX(location.x)
    local originY = GridNav:WorldToGridPosY(location.y)
    local halfSize_x = math.floor(sizexy.x/2)
    local halfSize_y = math.floor(sizexy.y/2)
    local boundX1 = originX + halfSize_x
    local boundX2 = originX - halfSize_x
    local boundY1 = originY + halfSize_y
    local boundY2 = originY - halfSize_y

    local lowerBoundX = math.min(boundX1, boundX2)
    local upperBoundX = math.max(boundX1, boundX2)
    local lowerBoundY = math.min(boundY1, boundY2)
    local upperBoundY = math.max(boundY1, boundY2)

    -- Adjust even size
    if (sizexy.x % 2) == 0 then
        upperBoundX = upperBoundX-1
    end

    if (sizexy.y % 2) == 0 then
        upperBoundY = upperBoundY-1
    end

    -- Adjust to upper case
    grid_type = string.upper(grid_type)

    -- 默认情况下，省略会覆盖旧值
    if not option then
        for y = lowerBoundY, upperBoundY do
            for x = lowerBoundX, upperBoundX do
                BuildingHelper.Grid[y][x] = BuildingHelper.GridTypes[grid_type]
            end
        end

    elseif option == "add" then
        for y = lowerBoundY, upperBoundY do
            for x = lowerBoundX, upperBoundX do
                -- Only add if it doesn't have it yet
                local hasGridType = BuildingHelper:CellHasGridType(x,y,grid_type)
                if not hasGridType then
                    BuildingHelper.Grid[y][x] = BuildingHelper.Grid[y][x] + BuildingHelper.GridTypes[grid_type]
                end
            end
        end

    elseif option == "remove" then
        for y = lowerBoundY, upperBoundY do
            for x = lowerBoundX, upperBoundX do
                -- Only remove if it has it
                local hasGridType = BuildingHelper:CellHasGridType(x,y,grid_type)
                if hasGridType then
                    BuildingHelper.Grid[y][x] = BuildingHelper.Grid[y][x] - BuildingHelper.GridTypes[grid_type]
                end
            end
        end
    end     
end

-- 用于一次添加、删除或覆盖多个网格正方形的中心函数
function BuildingHelper:SetGridType(size, location, grid_type, option)
    if not size or size == 0 then return end

    local originX = GridNav:WorldToGridPosX(location.x)
    local originY = GridNav:WorldToGridPosY(location.y)
    local halfSize = math.floor(size/2)
    local boundX1 = originX + halfSize
    local boundX2 = originX - halfSize
    local boundY1 = originY + halfSize
    local boundY2 = originY - halfSize

    local lowerBoundX = math.min(boundX1, boundX2)
    local upperBoundX = math.max(boundX1, boundX2)
    local lowerBoundY = math.min(boundY1, boundY2)
    local upperBoundY = math.max(boundY1, boundY2)

    -- Adjust even size
    if (size % 2) == 0 then
        upperBoundX = upperBoundX-1
        upperBoundY = upperBoundY-1
    end

    -- Adjust to upper case
    grid_type = string.upper(grid_type)

    -- 默认情况下，省略会覆盖旧值
    if not option then
        for y = lowerBoundY, upperBoundY do
            for x = lowerBoundX, upperBoundX do
                BuildingHelper.Grid[y][x] = BuildingHelper.GridTypes[grid_type]
            end
        end

    elseif option == "add" then
        for y = lowerBoundY, upperBoundY do
            for x = lowerBoundX, upperBoundX do
                -- Only add if it doesn't have it yet
                local hasGridType = BuildingHelper:CellHasGridType(x,y,grid_type)
                if not hasGridType then
                    BuildingHelper.Grid[y][x] = BuildingHelper.Grid[y][x] + BuildingHelper.GridTypes[grid_type]
                end
            end
        end

    elseif option == "remove" then
        for y = lowerBoundY, upperBoundY do
            for x = lowerBoundX, upperBoundX do
                -- Only remove if it has it
                local hasGridType = BuildingHelper:CellHasGridType(x,y,grid_type)
                if hasGridType then
                    BuildingHelper.Grid[y][x] = BuildingHelper.Grid[y][x] - BuildingHelper.GridTypes[grid_type]
                end
            end
        end
    end     
end

-- Alternative with radius
function BuildingHelper:SetGridTypeRadiusXY(radius, location, grid_type, option)
    if not radius or radius == 0 then return end
    local sizexy = BuildingHelper:getXYSize(radius)
    local size_x = (sizexy.x - (sizexy.x%32))/32
    local size_y = (sizexy.y - (sizexy.y%32))/32

    local originX = GridNav:WorldToGridPosX(location.x)
    local originY = GridNav:WorldToGridPosY(location.y)
    local halfSize_x = math.floor(size_x/2)
    local halfSize_y = math.floor(size_y/2)
    local boundX1 = originX + halfSize_x
    local boundX2 = originX - halfSize_x
    local boundY1 = originY + halfSize_y
    local boundY2 = originY - halfSize_y

    local lowerBoundX = math.min(boundX1, boundX2)
    local upperBoundX = math.max(boundX1, boundX2)
    local lowerBoundY = math.min(boundY1, boundY2)
    local upperBoundY = math.max(boundY1, boundY2)

    -- Adjust to upper case
    grid_type = string.upper(grid_type)

    -- 默认情况下，省略会覆盖旧值
    if not option then
        for y = lowerBoundY, upperBoundY do
            for x = lowerBoundX, upperBoundX do
                local current_pos = Vector(GridNav:GridPosToWorldCenterX(x), GridNav:GridPosToWorldCenterY(y), 0)
                local distance = (current_pos - location):Length2D()
                BuildingHelper:print("distance="..distance)
                BuildingHelper:print("types="..BuildingHelper.GridTypes[grid_type])
                -- radius 3x3 
                if distance <= radius then
                    BuildingHelper.Grid[y][x] = BuildingHelper.GridTypes[grid_type]
                end
            end
        end

    elseif option == "add" then
        for y = lowerBoundY, upperBoundY do
            for x = lowerBoundX, upperBoundX do
                -- 只有在它还没有的时候才添加
                local hasGridType = BuildingHelper:CellHasGridType(x,y,grid_type)
                if not hasGridType then
                    local current_pos = Vector(GridNav:GridPosToWorldCenterX(x), GridNav:GridPosToWorldCenterY(y), 0)
                    local distance = (current_pos - location):Length2D()
                    BuildingHelper:print("distance="..distance)
                    BuildingHelper:print("types="..BuildingHelper.GridTypes[grid_type])
                    if distance <= radius then
                        BuildingHelper.Grid[y][x] = BuildingHelper.Grid[y][x] + BuildingHelper.GridTypes[grid_type]
                    end
                end
            end
        end

    elseif option == "remove" then
         for y = lowerBoundY, upperBoundY do
            for x = lowerBoundX, upperBoundX do
                -- Only remove if it has it
                local hasGridType = BuildingHelper:CellHasGridType(x,y,grid_type)
                if hasGridType then
                    local current_pos = Vector(GridNav:GridPosToWorldCenterX(x), GridNav:GridPosToWorldCenterY(y), 0)
                    local distance = (current_pos - location):Length2D()
                    BuildingHelper:print("distance="..distance)
                    BuildingHelper:print("types="..BuildingHelper.GridTypes[grid_type])
                    if distance <= radius then
                        BuildingHelper.Grid[y][x] = BuildingHelper.Grid[y][x] - BuildingHelper.GridTypes[grid_type]
                    end
                end
            end
        end
    end     
end

-- Alternative with radius
function BuildingHelper:SetGridTypeRadius(radius, location, grid_type, option)
    if not radius or radius == 0 then return end

    -- Adjust radius to size
    local size = (radius - (radius%32))/32

    local originX = GridNav:WorldToGridPosX(location.x)
    local originY = GridNav:WorldToGridPosY(location.y)
    local halfSize = math.floor(size/2)
    local boundX1 = originX + halfSize
    local boundX2 = originX - halfSize
    local boundY1 = originY + halfSize
    local boundY2 = originY - halfSize

    local lowerBoundX = math.min(boundX1, boundX2)
    local upperBoundX = math.max(boundX1, boundX2)
    local lowerBoundY = math.min(boundY1, boundY2)
    local upperBoundY = math.max(boundY1, boundY2)

    -- Adjust to upper case
    grid_type = string.upper(grid_type)

    -- Default by omission is to override the old value
    if not option then
        for y = lowerBoundY, upperBoundY do
            for x = lowerBoundX, upperBoundX do
                local current_pos = Vector(GridNav:GridPosToWorldCenterX(x), GridNav:GridPosToWorldCenterY(y), 0)
                local distance = (current_pos - location):Length2D()
                if distance <= radius then
                    BuildingHelper.Grid[y][x] = BuildingHelper.GridTypes[grid_type]
                end
            end
        end

    elseif option == "add" then
        for y = lowerBoundY, upperBoundY do
            for x = lowerBoundX, upperBoundX do
                -- Only add if it doesn't have it yet
                local hasGridType = BuildingHelper:CellHasGridType(x,y,grid_type)
                if not hasGridType then
                    local current_pos = Vector(GridNav:GridPosToWorldCenterX(x), GridNav:GridPosToWorldCenterY(y), 0)
                    local distance = (current_pos - location):Length2D()
                    if distance <= radius then
                        BuildingHelper.Grid[y][x] = BuildingHelper.Grid[y][x] + BuildingHelper.GridTypes[grid_type]
                    end
                end
            end
        end

    elseif option == "remove" then
         for y = lowerBoundY, upperBoundY do
            for x = lowerBoundX, upperBoundX do
                -- Only remove if it has it
                local hasGridType = BuildingHelper:CellHasGridType(x,y,grid_type)
                if hasGridType then
                    local current_pos = Vector(GridNav:GridPosToWorldCenterX(x), GridNav:GridPosToWorldCenterY(y), 0)
                    local distance = (current_pos - location):Length2D()
                    if distance <= radius then
                        BuildingHelper.Grid[y][x] = BuildingHelper.Grid[y][x] - BuildingHelper.GridTypes[grid_type]
                    end
                end
            end
        end
    end     
end

-- Returns a string with each of the grid types of the cell, mostly to debug
function BuildingHelper:GetCellGridTypes(x,y)
    local s = ""
    for grid_string,value in pairs(BuildingHelper.GridTypes) do
        local hasGridType = BuildingHelper:CellHasGridType(x,y,grid_string)
        if hasGridType then
            s = s..grid_string.." "
        end
    end
    return s
end

-- 按名称检查单元格是否具有特定网格类型
function BuildingHelper:CellHasGridType(x, y, grid_type)
    if BuildingHelper.GridTypes[grid_type] then
        return bit.band(BuildingHelper.Grid[y][x], BuildingHelper.GridTypes[grid_type]) ~= 0
    end
end

-- 在某个位置检查特定大小的GridNav square。如果无效，则发送OnConstruction失败
function BuildingHelper:ValidPosition(size, location, unit, callbacks)
    local bBlocked

    -- Check for special requirement
    local playerTable = BuildingHelper:GetPlayerTable(unit:GetPlayerOwnerID())
    local buildingName = playerTable.activeBuilding
    if unit.work then buildingName = unit.work.name end
    local buildingTable = buildingName and GetUnitKV(buildingName)
    local requires = buildingTable and buildingTable["Requires"]
    local prevents = buildingTable and buildingTable["Prevents"]

    if requires then
        bBlocked = not BuildingHelper:AreaMeetsCriteriaXY(size, location, requires, "all")
    else
        bBlocked = BuildingHelper:IsAreaBlocked(size, location)
    end

    if prevents then
        bBlocked = bBlocked or BuildingHelper:AreaMeetsCriteriaXY(size, location, prevents, "one")
    end

    if bBlocked then
        if callbacks.onConstructionFailed then
            callbacks.onConstructionFailed()
            return false
        end
    end

    -- 检查封锁该地区的敌军单位
    -- local construction_radius = size * 64
    -- 这边放大一点应该没什么问题把
    local sizexy = BuildingHelper:getXYSize(size)
    local construction_radius = math.max(sizexy.x, sizexy.y)

    local target_type = DOTA_UNIT_TARGET_HERO + DOTA_UNIT_TARGET_BASIC
    local flags = DOTA_UNIT_TARGET_FLAG_MAGIC_IMMUNE_ENEMIES + DOTA_UNIT_TARGET_FLAG_FOW_VISIBLE + DOTA_UNIT_TARGET_FLAG_NO_INVIS
    local enemies = FindUnitsInRadius(unit:GetTeamNumber(), location, nil, construction_radius, DOTA_UNIT_TARGET_TEAM_ENEMY, target_type, flags, FIND_ANY_ORDER, false)

    for _,enemy in pairs(enemies) do
        -- local origin = enemy:GetAbsOrigin()
        if not IsCustomBuilding(enemy) and BuildingHelper:EnemyIsInsideBuildingArea(enemy:GetAbsOrigin(), location, size) then
            if callbacks.onConstructionFailed then
                callbacks.onConstructionFailed()
                return false
            end
        end      
    end

    return true
end

function BuildingHelper:GetBoundsXY(point, size)
    local sizexy = BuildingHelper:getXYSize(size)
    local bounds = {}
    local X1 = point.x + sizexy.x * 32
    local X2 = point.x - sizexy.x * 32
    local Y1 = point.y + sizexy.y * 32
    local Y2 = point.y - sizexy.y * 32
    bounds.Min = {x=math.min(X1, X2),y=math.min(Y1, Y2)}
    bounds.Max = {x=math.max(X1, X2),y=math.max(Y1, Y2)}
    return bounds
end

function BuildingHelper:GetBounds(point, len)
    local bounds = {}
    local X1 = point.x + len
    local X2 = point.x - len
    local Y1 = point.y + len
    local Y2 = point.y - len
    bounds.Min = {x=math.min(X1, X2),y=math.min(Y1, Y2)}
    bounds.Max = {x=math.max(X1, X2),y=math.max(Y1, Y2)}
    return bounds
end

-- 敌人是否在建筑范围内，感觉有点奇怪
function BuildingHelper:EnemyIsInsideBuildingArea(enemy_location, building_location, size)
    -- local bBounds = BuildingHelper:GetBoundsXY(building_location, size * 32)
    local bBounds = BuildingHelper:GetBoundsXY(building_location, size)
    -- 敌人占领了2x2个方格
    BuildingHelper:SnapToGrid(2, enemy_location)
    local eBounds = BuildingHelper:GetBounds(enemy_location, 64)

    local function between(num, lower, upper)
        return num < upper and num > lower
    end

    local betweenX = between(eBounds.Min.x, bBounds.Min.x, bBounds.Max.x) or between(eBounds.Max.x, bBounds.Min.x, bBounds.Max.x) or between(enemy_location.x,bBounds.Min.x,bBounds.Max.x)
    local betweenY = between(eBounds.Min.y, bBounds.Min.y, bBounds.Max.y) or between(eBounds.Max.y, bBounds.Min.y, bBounds.Max.y) or between(enemy_location.y,bBounds.Min.y,bBounds.Max.y)

    return betweenX and betweenY
end

-- 如果不是所有的广场都可以建造，那么这个区域就会被封锁
function BuildingHelper:IsAreaBlocked(size, location)
    return BuildingHelper:AreaMeetsCriteriaXY(size, location, "BLOCKED", "one")
end

-- 检查所有正方形是否符合每个通过的栅格类型标准（可以是多个，按空间分割）
function BuildingHelper:AreaMeetsCriteriaXY(size, location, grid_type, option)
    local sizexy = BuildingHelper:getXYSize(size)
    local originX = GridNav:WorldToGridPosX(location.x)
    local originY = GridNav:WorldToGridPosY(location.y)
    local halfSize_x = math.floor(sizexy.x/2)
    local halfSize_y = math.floor(sizexy.y/2)
    local boundX1 = originX + halfSize_x
    local boundX2 = originX - halfSize_x
    local boundY1 = originY + halfSize_y
    local boundY2 = originY - halfSize_y

    local lowerBoundX = math.min(boundX1, boundX2)
    local upperBoundX = math.max(boundX1, boundX2)
    local lowerBoundY = math.min(boundY1, boundY2)
    local upperBoundY = math.max(boundY1, boundY2)

    -- Adjust even size
    if (sizexy.x % 2) == 0 then
        upperBoundX = upperBoundX-1
    end
    if (sizexy.y % 2) == 0 then
        upperBoundY = upperBoundY-1
    end

    -- Default by omission is to check if all the cells meet the criteria
    if not option or option == "all" then
        for y = lowerBoundY, upperBoundY do
            for x = lowerBoundX, upperBoundX do
                local grid_types = split(grid_type, " ")
                for k,v in pairs(grid_types) do
                    local t = string.upper(v)
                    local hasGridType = BuildingHelper:CellHasGridType(x,y,t)
                    if not hasGridType then
                        return false
                    end
                end
            end
        end
        return true -- all cells have the grid types

    -- When searching for one block, stop at the first grid point found with every type
    elseif option == "one" then
        for y = lowerBoundY, upperBoundY do
            for x = lowerBoundX, upperBoundX do
                local grid_types = split(grid_type, " ")
                local hasGridType = true
                for k,v in pairs(grid_types) do
                    local t = string.upper(v)
                    hasGridType = hasGridType and BuildingHelper:CellHasGridType(x,y,t)
                end

                if hasGridType then
                    return true
                end
            end
        end
        return false -- no cells meet the criteria
    end
end

-- 检查所有正方形是否符合每个通过的栅格类型标准（可以是多个，按空间分割）
function BuildingHelper:AreaMeetsCriteria(size, location, grid_type, option)
    local originX = GridNav:WorldToGridPosX(location.x)
    local originY = GridNav:WorldToGridPosY(location.y)
    local halfSize = math.floor(size/2)
    local boundX1 = originX + halfSize
    local boundX2 = originX - halfSize
    local boundY1 = originY + halfSize
    local boundY2 = originY - halfSize

    local lowerBoundX = math.min(boundX1, boundX2)
    local upperBoundX = math.max(boundX1, boundX2)
    local lowerBoundY = math.min(boundY1, boundY2)
    local upperBoundY = math.max(boundY1, boundY2)

    -- Adjust even size
    if (size % 2) == 0 then
        upperBoundX = upperBoundX-1
        upperBoundY = upperBoundY-1
    end

    -- Default by omission is to check if all the cells meet the criteria
    if not option or option == "all" then
        for y = lowerBoundY, upperBoundY do
            for x = lowerBoundX, upperBoundX do
                local grid_types = split(grid_type, " ")
                for k,v in pairs(grid_types) do
                    local t = string.upper(v)
                    local hasGridType = BuildingHelper:CellHasGridType(x,y,t)
                    if not hasGridType then
                        return false
                    end
                end
            end
        end
        return true -- all cells have the grid types

    -- When searching for one block, stop at the first grid point found with every type
    elseif option == "one" then
        for y = lowerBoundY, upperBoundY do
            for x = lowerBoundX, upperBoundX do
                local grid_types = split(grid_type, " ")
                local hasGridType = true
                for k,v in pairs(grid_types) do
                    local t = string.upper(v)
                    hasGridType = hasGridType and BuildingHelper:CellHasGridType(x,y,t)
                end

                if hasGridType then
                    return true
                end
            end
        end
        return false -- no cells meet the criteria
    end
end

-- Adds a location to the builders work queue
-- bQueued will be true if the command was done with shift pressed
-- If bQueued is false, the queue is cleared and this building is put on top
-- 加个模型角度的参数
function BuildingHelper:AddToQueue(builder, location, bQueued)
    local playerID = builder:GetMainControllingPlayer()
    local player = PlayerResource:GetPlayer(playerID)
    local playerTable = BuildingHelper:GetPlayerTable(playerID)
    local buildingName = playerTable.activeBuilding
    local buildingTable = playerTable.activeBuildingTable
    local fMaxScale = buildingTable:GetVal("MaxScale", "float")
    -- local size = buildingTable:GetVal("ConstructionSize", "number")
    local size = buildingTable:GetVal("ConstructionSize")
    local pathing_size = buildingTable:GetVal("BlockGridNavSize", "number")
    local callbacks = playerTable.activeCallbacks

    BuildingHelper:SnapToGridXY(size, location)

    -- Check gridnav
    if not BuildingHelper:ValidPosition(size, location, builder, callbacks) then
        return
    end

    -- External pre construction checks
    if callbacks.onPreConstruction then
        local result = callbacks.onPreConstruction(location)
        if result == false then
            return
        end
    end

    BuildingHelper:print("AddToQueue "..builder:GetUnitName().." "..builder:GetEntityIndex().." -> location "..VectorString(location))
    
    -- Make the new work entry
    local work = {["location"] = location, ["name"] = buildingName, ["buildingTable"] = buildingTable, ["callbacks"] = callbacks}

    -- 所选职位最初有效，发送回拨以支付黄金
    callbacks.onBuildingPosChosen(location)

    -- “自放置”不会在放置区域上生成重影粒子
    if builder:GetUnitName() == buildingName then
        -- Never queued
        BuildingHelper:ClearQueue(builder)
        table.insert(builder.buildingQueue, work)

        BuildingHelper:AdvanceQueue(builder)
        BuildingHelper:print("Starting self placement of "..buildingName)

    else
        -- Adjust the model position z
        local model_offset = GetUnitKV(buildingName, "ModelOffset") or 0
        local model_location = Vector(location.x, location.y, location.z + model_offset)

        -- npc_dota_creature doesn't render cosmetics on the particle ghost, use hero names instead
        local overrideGhost = buildingTable:GetVal("OverrideBuildingGhost", "string")
        local unitName = overrideGhost or buildingName
        local entity
        if overrideGhost then
            -- Use a hero dummy to project the queue particles
            entity = BuildingHelper:GetOrCreateDummy(unitName)
        else
            -- Create the building entity that will be used to start construction and project the queue particles
            entity = CreateUnitByName(unitName, model_location, false, nil, nil, builder:GetTeam())
            entity:SetNeverMoveToClearSpace(true)
            function entity:IsUnderConstruction() return true end
        end
        entity:AddEffects(EF_NODRAW)
        entity:AddNewModifier(entity, nil, "modifier_out_of_world", {})
        work.entity = entity

        local modelParticle = ParticleManager:CreateParticleForPlayer("particles/buildinghelper/ghost_model.vpcf", PATTACH_CUSTOMORIGIN, nil, player)
        ParticleManager:SetParticleControl(modelParticle, 0, model_location)
        ParticleManager:SetParticleControlEnt(modelParticle, 1, entity, 1, "attach_hitloc", entity:GetAbsOrigin(), true) -- Model attach          
        ParticleManager:SetParticleControl(modelParticle, 3, Vector(BuildingHelper.Settings["MODEL_ALPHA"],0,0)) -- Alpha
        ParticleManager:SetParticleControl(modelParticle, 4, Vector(fMaxScale,0,0)) -- Scale
        work.particleIndex = modelParticle

        local color = BuildingHelper.Settings["RECOLOR_BUILDING_PLACED"] and Vector(0,255,0) or Vector(255,255,255)
        ParticleManager:SetParticleControl(modelParticle, 2, color) -- Color

        -- Create pedestal for particles
        local pedestal = buildingTable:GetVal("PedestalModel")
        if pedestal then
            local prop = BuildingHelper:GetOrCreateProp(pedestal)
            local scale = buildingTable:GetVal("PedestalModelScale", "float") or entity:GetModelScale()
            local offset = buildingTable:GetVal("PedestalOffset", "float") or 0
            local offset_location = Vector(location.x, location.y, location.z + offset)

            prop:AddEffects(EF_NODRAW)
            prop.pedestalParticle = ParticleManager:CreateParticleForPlayer("particles/buildinghelper/ghost_model.vpcf", PATTACH_CUSTOMORIGIN, nil, player)
            ParticleManager:SetParticleControl(prop.pedestalParticle, 0, offset_location)
            ParticleManager:SetParticleControlEnt(prop.pedestalParticle, 1, prop, 1, "attach_hitloc", prop:GetAbsOrigin(), true) -- Model attach
            ParticleManager:SetParticleControl(prop.pedestalParticle, 2, color) -- Color
            ParticleManager:SetParticleControl(prop.pedestalParticle, 3, Vector(BuildingHelper.Settings["MODEL_ALPHA"],0,0)) -- Alpha
            ParticleManager:SetParticleControl(prop.pedestalParticle, 4, Vector(scale,0,0)) -- Scale
            work.propParticleIndex = prop.pedestalParticle
        end

        -- Adjust the Model Orientation
        local yaw = buildingTable:GetVal("ModelRotation", "float")
        entity:SetAngles(0, -yaw, 0)

        -- If the ability wasn't queued, override the building queue
        if not bQueued then
            BuildingHelper:ClearQueue(builder)
        end

        -- Add this to the builder queue
        table.insert(builder.buildingQueue, work)

        -- 如果生成器没有当前工作，请启动队列
        -- 额外检查建设者的内部行为，这些能力总是排队的
        if builder.work == nil and not builder:HasModifier("modifier_builder_hidden") and not (builder.state == "repairing" or builder.state == "moving_to_repair") then
            builder.work = builder.buildingQueue[1]
            BuildingHelper:print("Builder doesn't have work to do, start right away")
            BuildingHelper:AdvanceQueue(builder)
        else
            BuildingHelper:print("Work was queued, builder already has work to do")
            BuildingHelper:PrintQueue(builder)
        end
    end
end

-- Adds a repair to the builders work queue
-- bQueued will be true if the command was done with shift pressed
-- If bQueued is false, the queue is cleared and this repair is put on top
function BuildingHelper:AddRepairToQueue(builder, building, bQueued)
    -- External pre repair checks
    local bResult = self:OnPreRepair(builder, building)
    if not bResult then return end

    local playerID = builder:GetMainControllingPlayer()
    local player = PlayerResource:GetPlayer(playerID)
    local playerTable = BuildingHelper:GetPlayerTable(playerID)
    local buildingName = building:GetUnitName()
    local buildingTable = playerTable.activeBuildingTable
    local callbacks = playerTable.activeCallbacks

    BuildingHelper:print("AddRepairToQueue "..builder:GetUnitName().." "..builder:GetEntityIndex().." -> building "..building:GetUnitName())
    
    -- Make the new work entry
    local work = {["building"] = building, ["name"] = buildingName, ["buildingTable"] = buildingTable, ["callbacks"] = callbacks}

    -- If the ability wasn't queued, override the building queue
    if not bQueued then
        BuildingHelper:ClearQueue(builder)
    end

    -- Add this to the builder queue
    table.insert(builder.buildingQueue, work)

    -- If the builder doesn't have a current work, start the queue
    -- Extra check for builder-inside behaviour, those abilities are always queued
    if builder.work == nil and not builder:HasModifier("modifier_builder_hidden") and not (builder.state == "repairing" or builder.state == "moving_to_repair") then
        builder.work = builder.buildingQueue[1]
        BuildingHelper:print("Builder doesn't have work to do, start moving to repair right away")
        BuildingHelper:AdvanceQueue(builder)
    else
        BuildingHelper:print("Repair Work was queued, builder already has work to do")
        BuildingHelper:PrintQueue(builder)
    end
end

-- Processes an item of the builders work queue
function BuildingHelper:AdvanceQueue(builder)
    if (builder.move_to_build_timer) then Timers:RemoveTimer(builder.move_to_build_timer) end

    if builder.buildingQueue and #builder.buildingQueue > 0 then
        BuildingHelper:PrintQueue(builder)

        local work = builder.buildingQueue[1]
        table.remove(builder.buildingQueue, 1) --Pop

        if work.building then
            -- Repair Queued
            if not IsValidEntity(work.building) or not work.building:IsAlive() then
                self:print("Queued Repair "..work.name.." but it was removed, continue with the queue")
                self:AdvanceQueue(builder)                
            else
                local building = work.building
                local callbacks = work.callbacks
                local castRange = builder:GetFollowRange(building)
                if building.repair_distance then castRange = math.max(building.repair_distance, castRange) end
                builder.work = work
                builder.repair_target = building
                builder.state = "moving_to_repair"

                self:print("AdvanceQueue: Repair "..work.name.." "..work.building:GetEntityIndex())

                -- Move towards the building until close range
                ExecuteOrderFromTable({UnitIndex = builder:GetEntityIndex(), OrderType = DOTA_UNIT_ORDER_MOVE_TO_TARGET, TargetIndex = building:GetEntityIndex(), Queue = false}) 
                builder.move_to_build_timer = Timers:CreateTimer(function()
                    if not IsValidEntity(builder) or not builder:IsAlive() then return end -- End if killed
                    if not IsValidEntity(building) or not building:IsAlive() then return end -- End if killed
                    
                    local distance = (building:GetAbsOrigin() - builder:GetAbsOrigin()):Length()
                    if distance > castRange then
                        return 0.03
                    else
                        self:print("Reached building, start the Repair process!")
                        --builder:Stop()
                        
                        builder.repairRange = castRange
                        BuildingHelper:StartRepair(builder, building)
                        return
                    end
                end)
            end
        else
            -- Construction Queued
            local buildingTable = work.buildingTable
            local castRange = buildingTable:GetVal("AbilityCastRange", "number")
            local callbacks = work.callbacks
            local location = work.location
            builder.work = work

            -- Move towards the point at cast range
            builder:MoveToPosition(location)
            builder.move_to_build_timer = Timers:CreateTimer(0.03, function()
                builder:MoveToPosition(location)
                if not IsValidEntity(builder) or not builder:IsAlive() then return end
                builder.state = "moving_to_build"

                local distance = (location - builder:GetAbsOrigin()):Length2D()
                if distance > castRange then
                    return 0.03
                else
                    builder:Stop()
                    
                    -- Self placement goes directly to the OnConstructionStarted callback
                    if work.name == builder:GetUnitName() then
                        local callbacks = work.callbacks
                        if callbacks.onConstructionStarted then
                            callbacks.onConstructionStarted(builder)
                        end

                    else
                        BuildingHelper:StartBuilding(builder)
                    end
                    return
                end
            end)
        end
    else
        -- Set the builder work to nil to accept next work directly
        BuildingHelper:print("Builder "..builder:GetUnitName().." "..builder:GetEntityIndex().." finished its building Queue")
        builder.state = "idle"
        builder.repair_target = nil
        builder.work = nil
    end
end

-- Clear the build queue, the player right clicked
function BuildingHelper:ClearQueue(builder)

    local work = builder.work
    builder.work = nil
    builder.state = "idle"

    BuildingHelper:StopGhost(builder)

    -- Clear movement
    if builder.move_to_build_timer then Timers:RemoveTimer(builder.move_to_build_timer) end

    -- Clear repair
    if builder.repair_target then
        local target = builder.repair_target
        local index = getIndexTable(target.units_repairing, builder)
        if index then
            table.remove(target.units_repairing, index)
            self:print("Builder stopped repairing, currently "..getTableCount(target.units_repairing).." left.")
        end
        builder.repair_target = nil
        self:OnRepairCancelled(builder, target)
    end

    local repair_ability = self:GetRepairAbility(builder)
    if repair_ability then
        if repair_ability:GetToggleState() then repair_ability:ToggleAbility() end
        builder:RemoveModifierByName("modifier_builder_repairing")
    end

    -- Skip if there's nothing to clear
    if not builder.buildingQueue or (not work and #builder.buildingQueue == 0) then
        return
    end

    BuildingHelper:print("ClearQueue "..builder:GetUnitName().." "..builder:GetEntityIndex())

    -- Main work  
    if work then
        BuildingHelper:ClearWorkParticles(work)
        if work.entity then BuildingHelper:RemoveEntity(work.entity.prop) end

        -- Only refund work that hasn't been placed yet
        if not work.inProgress then
            BuildingHelper:RemoveEntity(work.entity)
            work.refund = true
        end

        if work.name and work.callbacks and work.callbacks.onConstructionCancelled then
            work.callbacks.onConstructionCancelled(work)
        end
    end

    -- Queued work
    while #builder.buildingQueue > 0 do
        work = builder.buildingQueue[1]
        work.refund = true --Refund this
        BuildingHelper:ClearWorkParticles(work)
        if work.entity then
            BuildingHelper:RemoveEntity(work.entity.prop)
            BuildingHelper:RemoveEntity(work.entity)
        end
        table.remove(builder.buildingQueue, 1)

        if work.name and work.callbacks.onConstructionCancelled then
            work.callbacks.onConstructionCancelled(work)
        end
    end
end

-- Remove the entity if it was not marked as a bh dummy
function BuildingHelper:RemoveEntity(ent)
    if ent and not ent.BHDUMMY then
        UTIL_Remove(ent)
    end
end

function BuildingHelper:ClearWorkParticles(work)
    if work.particleIndex then ParticleManager:DestroyParticle(work.particleIndex, true) end
    if work.propParticleIndex then ParticleManager:DestroyParticle(work.propParticleIndex, true) end
end

-- Stop panorama ghost
function BuildingHelper:StopGhost(builder)
    local player = builder:GetPlayerOwner()
    
    CustomGameEventManager:Send_ServerToPlayer(player, "building_helper_end", {})
end

-- Shows the current queued work for this builder
function BuildingHelper:PrintQueue(builder)
    BuildingHelper:print("Builder Queue of "..builder:GetUnitName().. " "..builder:GetEntityIndex())
    local buildingQueue = builder.buildingQueue
    for k,v in pairs(buildingQueue) do
        if buildingQueue[k]["location"] then
            BuildingHelper:print(" #"..k..": "..buildingQueue[k]["name"].." at "..VectorString(buildingQueue[k]["location"]))
        elseif buildingQueue[k]["building"] then
            BuildingHelper:print(" #"..k..": ".." repair "..buildingQueue[k]["name"])
        end
    end
    BuildingHelper:print("------------------------------------")
end

-- Toggles fast building/repairing cheat
function BuildingHelper:WarpTen(bEnabled)
    if bEnabled == nil then -- Toggle
        GameRules.WarpTen = not GameRules.WarpTen
    else
        GameRules.WarpTen = bEnabled
    end
end

function BuildingHelper:SnapToGrid(size, location)
    if size % 2 ~= 0 then
        location.x = BuildingHelper:SnapToGrid32(location.x)
        location.y = BuildingHelper:SnapToGrid32(location.y)
    else
        location.x = BuildingHelper:SnapToGrid64(location.x)
        location.y = BuildingHelper:SnapToGrid64(location.y)
    end
end

function BuildingHelper:SnapToGridXY(size, location)
    local sizexy = BuildingHelper:getXYSize(size)
    if sizexy.x % 2 ~= 0 then
        location.x = BuildingHelper:SnapToGrid32(location.x)
    else
        location.x = BuildingHelper:SnapToGrid64(location.x)
    end

    if sizexy.y % 2 ~= 0 then
        location.y = BuildingHelper:SnapToGrid32(location.y)
    else
        location.y = BuildingHelper:SnapToGrid64(location.y)
    end
end

function BuildingHelper:SnapToGrid64(coord)
    return 64*math.floor(0.5+coord/64)
end

function BuildingHelper:SnapToGrid32(coord)
    return 32+64*math.floor(coord/64)
end

function BuildingHelper:print(...)
    if BuildingHelper.Settings["TESTING"] then
        Tools:CommonPrint('[BH] '.. ...)
        -- print('[BH] '.. ...)
    end
end

function BuildingHelper:GetPlayerTable(playerID)
    if not BuildingHelper.Players[playerID] then
        BuildingHelper.Players[playerID] = {}
    end

    return BuildingHelper.Players[playerID]
end

-- 在地图原点创建一个世界外的虚拟对象并将其存储，从而减少创建单位的负载
function BuildingHelper:GetOrCreateDummy(unitName)
    if BuildingHelper.Dummies[unitName] then
        return BuildingHelper.Dummies[unitName]
    else
        BuildingHelper:print("AddBuilding "..unitName)
        local mgd = CreateUnitByName(unitName, Vector(0,0,0), false, nil, nil, 0)
        -- EF_NODRAW 防止将有关实体的任何数据传输到客户端，而不会影响服务器上的实体。换句话说，它使实体从玩家的视图中消失而不删除它。
        mgd:AddEffects(EF_NODRAW)
        mgd:AddNewModifier(mgd, nil, "modifier_out_of_world", {})
        BuildingHelper.Dummies[unitName] = mgd
        mgd.BHDUMMY = true -- Skip removing this entity
        return mgd
    end
end

function BuildingHelper:GetOrCreateProp(propName)
    if BuildingHelper.Dummies[propName] then
        return BuildingHelper.Dummies[propName]
    else
        local prop = SpawnEntityFromTableSynchronous("prop_dynamic", {model = propName})
        prop:AddEffects(EF_NODRAW)
        BuildingHelper.Dummies[propName] = prop
        prop.BHDUMMY = true -- Skip removing this entity
        return prop
    end
end

function BuildingHelper:CreatePedestalForBuilding(entity, buildingName, location, pedestalName)
    local offset = GetUnitKV(buildingName, "PedestalOffset") or 0
    local prop = SpawnEntityFromTableSynchronous("prop_dynamic", {model = pedestalName})
    local scale = GetUnitKV(buildingName, "PedestalModelScale") or entity:GetModelScale()
    local offset_location = Vector(location.x, location.y, location.z + offset)
    prop:SetModelScale(scale)
    prop:SetAbsOrigin(offset_location)
    entity.prop = prop -- Store the pedestal prop
    return prop
end

function BuildingHelper:AddModifierBuilding(building)
    local magicImmune = BuildingHelper.Settings["MAGIC_IMMUNE_BUILDINGS"]
    local deniable = BuildingHelper.Settings["DENIABLE_BUILDINGS"]
    local disableTurning = GetUnitKV(name, "DisableTurning") == 1 or BuildingHelper.Settings["DISABLE_BUILDING_TURNING"]
    building:AddNewModifier(building, nil, "modifier_building", {disable_turning = disableTurning, magic_immune = magicImmune, deniable = deniable})
end

-- Retrieves the handle of the ability marked as "RepairAbility" on the unit key values
function BuildingHelper:GetRepairAbility(unit)
    local unitName = unit:GetUnitName()
    local abilityName = GetUnitKV(unitName, "RepairAbility")
    if abilityName then
        return unit:FindAbilityByName(abilityName)
    end
end

-- Retrieves a list of all the buildings built by a player
function BuildingHelper:GetBuildings(playerID)
    local playerTable = self:GetPlayerTable(playerID)
    playerTable.BuildingHandles = playerTable.BuildingHandles or {}
    return playerTable.BuildingHandles
end

function BuildingHelper:GetBuildingsUnderConstruction(playerID)
    local playerTable = self:GetPlayerTable(playerID)
    playerTable.BuildingConstructionHandles = playerTable.BuildingConstructionHandles or {}
    return playerTable.BuildingConstructionHandles
end

-- This includes both buildings completed and under construction
function BuildingHelper:GetAllBuildings(playerID)
    local buildings = {}
    local finished = self:GetBuildings(playerID)
    local construction = self:GetBuildingsUnderConstruction(playerID) 
    for k,v in pairs(finished) do
        table.insert(buildings, v)
    end
    for k,v in pairs(construction) do
        table.insert(buildings, v)
    end
    return buildings
end

-- Returns number of buildings by name of a player
function BuildingHelper:GetBuildingCount(playerID, buildingName, bIncludeUnderConstruction)
    local playerTable = self:GetPlayerTable(playerID)
    playerTable.BuildingCount = playerTable.BuildingCount or {}
    playerTable.BuildingCount[buildingName] = playerTable.BuildingCount[buildingName] or 0
    local count = playerTable.BuildingCount[buildingName]
    if bIncludeUnderConstruction then
        playerTable.BuildingConstructionCount = playerTable.BuildingConstructionCount or {}
        playerTable.BuildingConstructionCount[buildingName] = playerTable.BuildingConstructionCount[buildingName] or 0
        count = count + playerTable.BuildingConstructionCount[buildingName]
    end
    return count
end

-- Sets the number of buildings by name of a player
function BuildingHelper:SetBuildingCount(playerID, buildingName, number, bUnderConstruction)
    local playerTable = self:GetPlayerTable(playerID)
    if bUnderConstruction then
        playerTable.BuildingConstructionCount = playerTable.BuildingConstructionCount or {}
        playerTable.BuildingConstructionCount[buildingName] = number
    else
        playerTable.BuildingCount = playerTable.BuildingCount or {}
        playerTable.BuildingCount[buildingName] = number
    end
end

-- 存储句柄和增量计数跟踪
function BuildingHelper:AddBuildingToPlayerTable(playerID, building, bUnderConstruction)
    local buildingName = building:GetUnitName()
    if bUnderConstruction then
        building.state = "building"
        table.insert(self:GetBuildingsUnderConstruction(playerID), building)
        self:SetBuildingCount(playerID, buildingName, self:GetBuildingCount(playerID, buildingName, true)+1, true)
        function building:IsUnderConstruction() return true end
    else
        -- Remove from construction
        local buildingList = self:GetBuildingsUnderConstruction(playerID)
        local index = getIndexTable(buildingList, building)
        if index then
            table.remove(buildingList, index)
            local constructionCount = self:GetBuildingCount(playerID, buildingName, true)
            self:SetBuildingCount(playerID, buildingName, constructionCount-1, true)
        end

        building.state = "complete"
        table.insert(self:GetBuildings(playerID), building)
        self:SetBuildingCount(playerID, buildingName, self:GetBuildingCount(playerID, buildingName)+1)
        function building:IsUnderConstruction() return false end
    end
end

-- Returns "ConstructionSize" value of a unit handle or unit name
function BuildingHelper:GetConstructionSize(unit)
    local unitTable = (type(unit) == "table") and unit:GetKeyValue() or GetUnitKV(unit)
    return unitTable["ConstructionSize"]
end

-- Returns "BlockPathingSize" kv of a unit handle or unit name
function BuildingHelper:GetBlockPathingSize(unit)
    local unitTable = (type(unit) == "table") and unit:GetKeyValue() or GetUnitKV(unit)
    return unitTable["BlockPathingSize"]
end

function BuildingHelper:HideBuilder(unit, location, building)
    unit:AddNewModifier(unit, nil, "modifier_builder_hidden", {})
    unit.entrance_to_build = unit:GetAbsOrigin()

    local location_builder = Vector(location.x, location.y, location.z - 200)
    building.builder_inside = unit
    unit:AddNoDraw()

    Timers:CreateTimer(function()
        unit:SetAbsOrigin(location_builder)
    end)
end

function BuildingHelper:ShowBuilder(unit)
    unit:RemoveModifierByName("modifier_builder_hidden")
    FindClearSpaceForUnit(unit, unit.entrance_to_build, true)
    -- 这个在我们这好像没什么用，先不管了把
    unit:RemoveNoDraw()
end

-- 没发现有什么地方用到了这个东西，有问题再说把
function BuildingHelper:FindClosestEmptyPositionNearbyXY(location, construction_size, maxDistance, avoidUnits)
    local sizexy = BuildingHelper:getXYSize(construction_size)
    local originX = GridNav:WorldToGridPosX(location.x)
    local originY = GridNav:WorldToGridPosY(location.y)

    local boundX1 = originX + math.floor(maxDistance/64)
    local boundX2 = originX - math.floor(maxDistance/64)
    local boundY1 = originY + math.floor(maxDistance/64)
    local boundY2 = originY - math.floor(maxDistance/64)

    local lowerBoundX = math.min(boundX1, boundX2)
    local upperBoundX = math.max(boundX1, boundX2)
    local lowerBoundY = math.min(boundY1, boundY2)
    local upperBoundY = math.max(boundY1, boundY2)

    -- Restrict to the map edges
    lowerBoundX = math.max(lowerBoundX, -BuildingHelper.squareX/2+1)
    upperBoundX = math.min(upperBoundX, BuildingHelper.squareX/2-1)
    lowerBoundY = math.max(lowerBoundY, -BuildingHelper.squareY/2+1)
    upperBoundY = math.min(upperBoundY, BuildingHelper.squareY/2-1)

    -- Adjust even size
    if (sizexy.x % 2) == 0 then
        upperBoundX = upperBoundX-1
    end
    if (sizexy.y % 2) == 0 then
        upperBoundY = upperBoundY-1
    end

    local towerPos = nil
    local closestDistance = maxDistance

    for x = lowerBoundX, upperBoundX do
        for y = lowerBoundY, upperBoundY do
            if BuildingHelper:CellHasGridType(x,y,"BUILDABLE") then
                local pos = GetGroundPosition(Vector(GridNav:GridPosToWorldCenterX(x), GridNav:GridPosToWorldCenterY(y), 0), nil)
                BuildingHelper:SnapToGridXY(construction_size, pos)
                if BuildingHelper:MeetsHeightCondition(pos) and not BuildingHelper:IsAreaBlocked(construction_size, pos) then
                    local distance = (pos - location):Length2D()
                    if distance < closestDistance then
                        if avoidUnits then
                            local units = FindUnitsInRadius(DOTA_TEAM_GOODGUYS, pos, nil, 64, DOTA_UNIT_TARGET_TEAM_BOTH, DOTA_UNIT_TARGET_BASIC+DOTA_UNIT_TARGET_HERO, DOTA_UNIT_TARGET_FLAG_MAGIC_IMMUNE_ENEMIES, FIND_ANY_ORDER, false)
                            if #units == 0 then
                                towerPos = pos
                                closestDistance = distance
                            end
                        else
                            towerPos = pos
                            closestDistance = distance
                        end                        
                    end
                end
            end
        end
    end
    if towerPos then
        BuildingHelper:SnapToGridXY(construction_size, towerPos)
    end
    return towerPos
end

-- Find the closest position of construction_size, within maxDistance
function BuildingHelper:FindClosestEmptyPositionNearby(location, construction_size, maxDistance, avoidUnits)
    local originX = GridNav:WorldToGridPosX(location.x)
    local originY = GridNav:WorldToGridPosY(location.y)

    local boundX1 = originX + math.floor(maxDistance/64)
    local boundX2 = originX - math.floor(maxDistance/64)
    local boundY1 = originY + math.floor(maxDistance/64)
    local boundY2 = originY - math.floor(maxDistance/64)

    local lowerBoundX = math.min(boundX1, boundX2)
    local upperBoundX = math.max(boundX1, boundX2)
    local lowerBoundY = math.min(boundY1, boundY2)
    local upperBoundY = math.max(boundY1, boundY2)

    -- Restrict to the map edges
    lowerBoundX = math.max(lowerBoundX, -BuildingHelper.squareX/2+1)
    upperBoundX = math.min(upperBoundX, BuildingHelper.squareX/2-1)
    lowerBoundY = math.max(lowerBoundY, -BuildingHelper.squareY/2+1)
    upperBoundY = math.min(upperBoundY, BuildingHelper.squareY/2-1)

    -- Adjust even size
    if (construction_size % 2) == 0 then
        upperBoundX = upperBoundX-1
        upperBoundY = upperBoundY-1
    end

    local towerPos = nil
    local closestDistance = maxDistance

    for x = lowerBoundX, upperBoundX do
        for y = lowerBoundY, upperBoundY do
            if BuildingHelper:CellHasGridType(x,y,"BUILDABLE") then
                local pos = GetGroundPosition(Vector(GridNav:GridPosToWorldCenterX(x), GridNav:GridPosToWorldCenterY(y), 0), nil)
                BuildingHelper:SnapToGrid(construction_size, pos)
                if BuildingHelper:MeetsHeightCondition(pos) and not BuildingHelper:IsAreaBlocked(construction_size, pos) then
                    local distance = (pos - location):Length2D()
                    if distance < closestDistance then
                        if avoidUnits then
                            local units = FindUnitsInRadius(DOTA_TEAM_GOODGUYS, pos, nil, 64, DOTA_UNIT_TARGET_TEAM_BOTH, DOTA_UNIT_TARGET_BASIC+DOTA_UNIT_TARGET_HERO, DOTA_UNIT_TARGET_FLAG_MAGIC_IMMUNE_ENEMIES, FIND_ANY_ORDER, false)
                            if #units == 0 then
                                towerPos = pos
                                closestDistance = distance
                            end
                        else
                            towerPos = pos
                            closestDistance = distance
                        end                        
                    end
                end
            end
        end
    end
    if towerPos then
        BuildingHelper:SnapToGrid(construction_size, towerPos)
    end
    return towerPos
end

-- 用于查找位置是否位于触发器实体边界内
function BuildingHelper:IsInsideEntityBounds(entity, location)
    local origin = entity:GetAbsOrigin()
    local bounds = entity:GetBounds()
    local min = bounds.Mins
    local max = bounds.Maxs
    local X = location.x
    local Y = location.y
    local minX = min.x + origin.x
    local minY = min.y + origin.y
    local maxX = max.x + origin.x
    local maxY = max.y + origin.y
    local betweenX = X >= minX and X <= maxX
    local betweenY = Y >= minY and Y <= maxY

    return betweenX and betweenY
end

-- In case a height restriction was defined, checks if the location passes the height test
function BuildingHelper:MeetsHeightCondition(location)
    if BuildingHelper.Settings["HEIGHT_RESTRICTION"] and BuildingHelper.Settings["HEIGHT_RESTRICTION"] ~= "" then
        return location.z >= BuildingHelper.Settings["HEIGHT_RESTRICTION"]
    else
        return true
    end
end

-- A BuildingHelper ability is identified by the "Building" key.
function IsBuildingAbility(ability)
    if not IsValidEntity(ability) then
        return
    end

    local ability_name = ability:GetAbilityName()
    return GetKeyValue(ability_name, "Building")
end

-- Builders are stored in a nettable in addition to the builder label
function IsBuilder(unit)
    local table = CustomNetTables:GetTableValue("builders", tostring(unit:GetEntityIndex()))
    return unit:GetUnitLabel() == "builder" or (table and (table["IsBuilder"] == 1)) or false
end

function CDOTA_BaseNPC:GetFollowRange(target)
    return self:GetHullRadius() + target:GetHullRadius() + 100
end

function IsCustomBuilding(unit)
    return unit:HasModifier("modifier_building")
end

function PrintGridCoords(pos)
    print('('..string.format("%.1f", pos.x)..','..string.format("%.1f", pos.y)..') = ['.. GridNav:WorldToGridPosX(pos.x)..','..GridNav:WorldToGridPosY(pos.y)..']')
end

function VectorString(v)
    return '[' .. math.floor(v.x) .. ', ' .. math.floor(v.y) .. ', ' .. math.floor(v.z) .. ']'
end

function StringStartsWith(fullstring, substring)
    local strlen = string.len(substring)
    local first_characters = string.sub(fullstring, 1 , strlen)
    return (first_characters == substring)
end

function tobool(s)
    return s==true or s=="true" or s=="1" or s==1
end

function split(inputstr, sep)
    if sep == nil then sep = "%s" end
    local t={} ; i=1
    for str in string.gmatch(inputstr, "([^"..sep.."]+)") do
        t[i] = str
        i = i + 1
    end
    return t
end

function getTableCount(t)
    local n = 0
    for _ in pairs( t ) do
        n = n + 1
    end
    return n
end

function getIndexTable(list, element)
    if list == nil then return false end
    for k,v in pairs(list) do if v == element then return k end end
end

function DrawGridSquare(x, y, color, duration)
    local pos = Vector(GridNav:GridPosToWorldCenterX(x), GridNav:GridPosToWorldCenterY(y), 0)
    duration = duration or 10
    BuildingHelper:SnapToGrid(1, pos)
    pos = GetGroundPosition(pos, nil)
        
    local particle = ParticleManager:CreateParticle("particles/buildinghelper/square_overlay.vpcf", PATTACH_CUSTOMORIGIN, nil)
    ParticleManager:SetParticleControl(particle, 0, pos)
    ParticleManager:SetParticleControl(particle, 1, Vector(32,0,0))
    ParticleManager:SetParticleControl(particle, 2, color)
    ParticleManager:SetParticleControl(particle, 3, Vector(90,0,0))

    Timers:CreateTimer(duration, function() 
        ParticleManager:DestroyParticle(particle, true)
    end)
end

if not BuildingHelper.Players then BuildingHelper:Init() else BuildingHelper:OnScriptReload() end

function BuildingHelper:getXYSize(size)
    local xysize = {}
    xysize.x = tonumber(split(size,"x")[1])
    xysize.y = tonumber(split(size,"x")[2])
    return xysize
end
-- add by lyjian 旋转模型角度
function BuildingHelper:changeAngles(args)
    local caster = EntIndexToHScript(args.caster)
    local ability = EntIndexToHScript(args.ability)
    --BuildingHelper:print("caster=="..caster:GetUnitName())
    --BuildingHelper:print("ability=="..ability:GetAbilityName())
    args.caster = caster
    args.ability = ability
    BuildingHelper:AddBuilding(args)
end