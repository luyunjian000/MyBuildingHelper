if not BuildMaps then
    BuildMaps = class({})
end
-- if not BuildMaps.buildToNumber then BuildMaps:Init() else BuildMaps:ReloadSettings() end
BuildMaps:Init()

function BuildMaps:Init()
    Tools:CommonPrint("BuildMaps Init")
    BuildMaps:LoadSettings()
end

function BuildMaps:LoadSettings()
    BuildMaps.buildToNumber = LoadKeyValues("scripts/vscripts/buildmaps/kv/build_to_number.kv")
end

function BuildMaps:ReloadSettings()
    BuildMaps:ReloadSettings()
end

function BuildMaps:BuildRandomMap(keys)
    local x_number = keys.x_number
    local y_number = keys.y_number

    local map = {}
    for i = 1, x_number  do
        map[i] = {}
        for j = 1, y_number do 
            map[i][j] = RandomInt(0,2)
        end
    end

    Tools:CommonPrint(BuildMaps.buildToNumber)
    -- 施法者选取第一个player控制的单位
    local caster = PlayerResource:GetSelectedHeroEntity(0)
    Tools:CommonPrint(caster)

    for i = 1, x_number do
        for j = 1, y_number  do
            local abilityName = BuildMaps.buildToNumber[tostring(map[i][j])]
            -- 这边用技能的名字
            local event
            event.caster = caster
            event.ability = caster:FindAbilityByName(abilityName)

            --BuildingHelper:AddBuilding(event)
            Tools:CommonPrint(event)


            -- BuildingHelper:BuildCommand()
        end
    end

end