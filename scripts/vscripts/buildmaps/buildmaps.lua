if not BuildMaps then
    BuildMaps = class({})
end

function BuildMaps:Init()
    BuildMaps:LoadSettings()

    BuildMaps:BuildRandomMap()
end

function BuildMaps:LoadSettings()
    BuildingHelper.buildToNumber = LoadKeyValues("scripts/vscripts/buildmaps/kv/build_to_number.kv")
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

    for i = 1, x_number do
        for j = 1, y_number  do
            local unitName = BuildingHelper.buildToNumber[tostring(map[i][j])]
            print(unitName)
        end
    end

end