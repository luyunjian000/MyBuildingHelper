if not BuildMaps then
    BuildMaps = class({})
end

-- if not BuildMaps.buildToNumber then BuildMaps:Init() else BuildMaps:ReloadSettings() end
-- BuildMaps:Init()

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
    BuildMaps:LoadSettings()
    local x_number = keys.x_number
    local y_number = keys.y_number

    local map = {}
    for i = 1, x_number  do
        map[i] = {}
        for j = 1, y_number do 
            -- map[i][j] = RandomInt(0,2)
            map[i][j] = 1
        end
    end

    Tools:CommonPrint(BuildMaps.buildToNumber)
    -- 施法者选取第一个player控制的单位
    local caster = PlayerResource:GetSelectedHeroEntity(0)
    Tools:CommonPrint(caster)

    local count = 0
    for i = 1, x_number do
        for j = 1, y_number  do
            local abilityName = BuildMaps.buildToNumber[tostring(map[i][j])]
            -- 这边用技能的名字
            local event = {}
            event.caster = caster
            event.ability = caster:FindAbilityByName(abilityName)
            event.isSentEvent = false
            event.model = "2"

            count = count + 1
            if abilityName ~= "empty" then
                Tools:CommonPrint("count=>" .. count)
                -- Tools:CommonPrint(event.caster:GetUnitName())
                -- Tools:CommonPrint(abilityName)
                -- Tools:CommonPrint(event.ability:GetAbilityName())

                local receiveEvent = Build(event)
                Tools:CommonPrint(receiveEvent)
                -- local receiveEvent = BuildingHelper:AddBuilding(event)

                -- 这边一个格子64,不转换
                -- 0     64    128 
                -- -64    
                -- -128
                
                local args = {}
                args.x = 32 + 64 * (i - 1)
                args.y = -32 - 64 * (j - 1)
                -- z 默认取128
                args.z = 128
                args.model = "2"
                args.Queue = 0
                args.PlayerID = 0
                args.builder = receiveEvent.builderIndex

                local location = {}
                location.x = args.x
                location.y = args.y
                location.z = args.z

                args.location = location
                BuildingHelper:BuildCommand(args)
            end
        end
    end

end