-- A build ability is used (not yet confirmed)
function Build( event )
    -- Tools:CommonPrint(event)
    local caster = event.caster
    local ability = event.ability
    local ability_name = ability:GetAbilityName()
    local building_name = ability:GetAbilityKeyValues()['UnitName']
    local gold_cost = ability:GetGoldCost(1) 
    local hero = caster:IsRealHero() and caster or caster:GetOwner()
    local playerID = hero:GetPlayerID()

    -- 如果该异能具有异能黄金成本，则不可能在第一次施放时没有足够的黄金
    -- 一定要在这里退金，因为这栋楼还没建好
    hero:ModifyGold(gold_cost, false, 0)

    -- 为了方便处理
    -- event.yaw = 0
    -- 制作一个建筑假人并开始全景重影
    BuildingHelper:AddBuilding(event)

    -- Additional checks to confirm a valid building position can be performed here
    event:OnPreConstruction(function(vPos)

        -- 检查最小高度（如果定义）
        if not BuildingHelper:MeetsHeightCondition(vPos) then
            BuildingHelper:print("Failed placement of " .. building_name .." - Placement is below the min height required")
            SendErrorMessage(playerID, "#error_invalid_build_position")
            return false
        end

        -- 如果没有足够的资源排队，请停止
        if PlayerResource:GetGold(playerID) < gold_cost then
            BuildingHelper:print("Failed placement of " .. building_name .." - Not enough gold!")
            SendErrorMessage(playerID, "#error_not_enough_gold")
            return false
        end

        return true
    end)

    -- 建筑物位置已确认且有效
    event:OnBuildingPosChosen(function(vPos)
        -- Spend resources
        hero:ModifyGold(-gold_cost, false, 0)

        -- Play a sound
        EmitSoundOnClient("DOTA_Item.ObserverWard.Activate", PlayerResource:GetPlayer(playerID))
    end)

    -- 由于gridnav在尝试的区域被阻塞，施工失败，从未得到确认
    event:OnConstructionFailed(function()
        local playerTable = BuildingHelper:GetPlayerTable(playerID)
        local building_name = playerTable.activeBuilding

        BuildingHelper:print("Failed placement of " .. building_name)
    end)

    -- 由于ClearQueue而取消
    event:OnConstructionCancelled(function(work)
        local building_name = work.name
        BuildingHelper:print("Cancelled construction of " .. building_name)

        -- Refund resources for this cancelled work
        if work.refund then
            hero:ModifyGold(gold_cost, false, 0)
        end
    end)

    -- 已创建建筑单元
    event:OnConstructionStarted(function(unit)
        BuildingHelper:print("Started construction of " .. unit:GetUnitName() .. " " .. unit:GetEntityIndex())
        -- Play construction sound

        -- If it's an item-ability and has charges, remove a charge or remove the item if no charges left
        if ability.GetCurrentCharges and not ability:IsPermanent() then
            local charges = ability:GetCurrentCharges()
            charges = charges-1
            if charges == 0 then
                ability:RemoveSelf()
            else
                ability:SetCurrentCharges(charges)
            end
        end

        -- 建造时单位不能攻击
        unit.original_attack = unit:GetAttackCapability()
        unit:SetAttackCapability(DOTA_UNIT_CAP_NO_ATTACK)

        -- Give item to cancel
        unit.item_building_cancel = CreateItem("item_building_cancel", hero, hero)
        if unit.item_building_cancel then 
            unit:AddItem(unit.item_building_cancel)
            unit.gold_cost = gold_cost
        end

        -- FindClearSpace for the builder
        FindClearSpaceForUnit(caster, caster:GetAbsOrigin(), true)
        caster:AddNewModifier(caster, nil, "modifier_phased", {duration=0.03})

        -- Remove invulnerability on npc_dota_building baseclass
        unit:RemoveModifierByName("modifier_invulnerable")
    end)

    -- 已完工的建筑物
    event:OnConstructionCompleted(function(unit)
        BuildingHelper:print("Completed construction of " .. unit:GetUnitName() .. " " .. unit:GetEntityIndex())
        
        -- Play construction complete sound
        
        -- Remove the item
        if unit.item_building_cancel then
            UTIL_Remove(unit.item_building_cancel)
        end

        -- Give the unit their original attack capability
        unit:SetAttackCapability(unit.original_attack)

    end)

    -- These callbacks will only fire when the state between below half health/above half health changes.
    -- i.e. it won't fire multiple times unnecessarily.
    event:OnBelowHalfHealth(function(unit)
        BuildingHelper:print(unit:GetUnitName() .. " is below half health.")
    end)

    event:OnAboveHalfHealth(function(unit)
        BuildingHelper:print(unit:GetUnitName().. " is above half health.")        
    end)
end

-- 使用取消能力项时调用
function CancelBuilding( keys )
    local building = keys.unit
    local hero = building:GetOwner()
    local playerID = building:GetPlayerOwnerID()

    BuildingHelper:print("CancelBuilding "..building:GetUnitName().." "..building:GetEntityIndex())

    -- Refund here
    if building.gold_cost then
        hero:ModifyGold(building.gold_cost, false, 0)
    end

    -- Eject builder
    local builder = building.builder_inside
    if builder then
        BuildingHelper:ShowBuilder(builder)
    end

    building:ForceKill(true) --This will call RemoveBuilding
end

function DeleteBuilding( keys )
    local building = keys.unit
    BuildingHelper:print("DeleteBuilding "..building:GetUnitName().." "..building:GetEntityIndex())
    -- 弹出生成器
    local builder = building.builder_inside

    if builder then
        BuildingHelper:ShowBuilder(builder)
    end

    -- 强制击杀该单位
    building:ForceKill(true) --This will call RemoveBuilding
end

function UpgradeBuilding( keys )
    -- 这边是否要检查满足条件（钱什么的）
    local newbuilding = BuildingHelper:UpgradeBuilding(keys)
    -- 据说是防止建筑停止攻击
    -- newbuilding:SetMoveCapability(0)
end

-- 需要来自bmddota/barebones的通知库
function SendErrorMessage( pID, string )
    Notifications:ClearBottom(pID)
    Notifications:Bottom(pID, {text=string, style={color='#E62020'}, duration=2})
    EmitSoundOnClient("General.Cancel", PlayerResource:GetPlayer(pID))
end

function SelectBornPosition(event)
    print(event);
end