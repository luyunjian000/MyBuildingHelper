-- 通用的计时器
function createTimer(entity,name,callback,firstdelaytime,everydelaytime)
    local entity_l
    if entity == nil then 
        entity_l = GameRules:GetGameModeEntity()
    end

    if firstdelaytime == nil then 
        firstdelaytime = 0
    end

    entity_l:SetContextThink(DoUniqueString(name),function()
        print("SetContextThink"..GameRules:GetDOTATime(false,false))

        -- 这边暂停也要处理下,只有不是暂停的时候才会执行callback
        if not GameRules:IsGamePaused() then
            callback()
        end

        if GameRules:State_Get() == DOTA_GAMERULES_STATE_GAME_IN_PROGRESS then
            return everydelaytime
        else
            return nil
        end
    end,firstdelaytime)

    --[[
    entity_l:SetContextThink(DoUniqueString(name),function()
        print("SetContextThink"..GameRules:GetDOTATime(false,false))
        if GameRules:State_Get() == DOTA_GAMERULES_STATE_GAME_IN_PROGRESS then
            return everydelaytime
        else
            return nil
        end
    end,firstdelaytime)
    --]]
    
end