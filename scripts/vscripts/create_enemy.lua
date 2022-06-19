
-- 创建敌人
function createRowEnemy()
    print("createRowEnemy"..GameRules:GetDOTATime(false,false))

    local vector = Vector(0,0,0)

    --创建单位
    local ShuaGuai = CreateUnitByName("npc_dota_enemy_1",vector,false,nil,nil,DOTA_TEAM_BADGUYS)

    --禁止单位寻找最短路径
    -- ShuaGuai:SetMustReachEachGoalEntity(true)

    --让单位沿着设置好的路线开始行动
    --ShuaGuai:SetInitialGoalEntity(ShuaGuai_entity)

    --添加相位移动的modifier，持续时间0.1秒
    --当相位移动的modifier消失，系统会自动计算碰撞，这样就避免了卡位
    ShuaGuai:AddNewModifier(nil, nil, "modifier_phased", {duration=0.1})

    -- 可能是英雄会导致复活，这边要去掉复活的

    -- 创建单位，根据每个单位都要绑定计时器(那种小的单位太多会不会很占资源)
    ShuaGuai:SetContextThink( "onEnemyThink", function()
        -- 不知道这个name是什么东西，当然后面要弄的话，每个建筑都要有对应的权重的，类似仇恨系统
        -- local tower = Entities:FindByClassnameNearest( "npc_dota_creature", ShuaGuai:GetOrigin(), 2000)

        local target = Entities:FindByName(nil,"testtarget")
        -- 有问题
        print(target:GetOrigin())

        -- 这个move也有问题，我服了
        ShuaGuai:MoveToPositionAggressive(target:GetOrigin())

        return 0.5
    end, 0.5 )

    --[[
    Timers:CreateTimer("enemy"..ShuaGuai:GetEntityIndex(),{	    
    endTime = 0.5, 
    useGameTime = true,
    callback = function()
        print("CreateTimer")
    end})
    --]]
end

-- 怎么获取这个定时绑定的entity啊
function EnemyThink()
    print("EnemyThink")
    print(Entities:GetOrigin())
    local tower = Entities:FindByClassnameNearest( "npc_dota_creature", Entities:GetOrigin(), 2000)
    print(tower)

    if tower then
        Entities:MoveToPositionAggressive(tower:GetOrigin())
    end

    return 0.25
end
