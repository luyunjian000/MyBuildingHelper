
-- 方便调试
function OnPlayerChat(keys)
    print("OnPlayerChat")
	for k,v in pairs(keys) do
		print(k)
		print(v)
	end

    local operation = keys.text
    print(operation)
    if operation == "-GetDOTATime" then
        local time = GameRules:GetDOTATime(false,false)
        print(time)
    elseif operation == "-GetTimeOfDay" then 
        local time = GameRules:GetTimeOfDay()
        print(time)
    elseif operation == "-GetGameTime" then 
        local time = GameRules:GetGameTime()
        print(time)
    end
end