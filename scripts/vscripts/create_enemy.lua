
-- 创建敌人
function createRowEnemy()
    print("createRowEnemy"..GameRules:GetDOTATime(false,false))

    local vector = Vector(0,0,0)

    --创建单位
    local ShuaGuai = CreateUnitByName("npc_dota_hero_meepo",vector,false,nil,nil,DOTA_TEAM_BADGUYS)

    --禁止单位寻找最短路径
    -- ShuaGuai:SetMustReachEachGoalEntity(true)

    --让单位沿着设置好的路线开始行动
    --ShuaGuai:SetInitialGoalEntity(ShuaGuai_entity)

    --添加相位移动的modifier，持续时间0.1秒
    --当相位移动的modifier消失，系统会自动计算碰撞，这样就避免了卡位
    ShuaGuai:AddNewModifier(nil, nil, "modifier_phased", {duration=0.1})

    -- 这个移动好像没什么用
    local targetvector = Vector(400,400,0)
    ShuaGuai:MoveToPosition(targetvector)

    -- 可能是英雄会导致复活，这边要去掉复活的
end