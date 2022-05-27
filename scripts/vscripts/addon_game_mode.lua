-- Generated from template

if CAddonTemplateGameMode == nil then
	CAddonTemplateGameMode = class({})
end

require("libraries/buildinghelper")
require("create_enemy")
require("player_chat")
require("libraries/create_timer")

function Precache( context )
	--[[
		Precache things we know we'll use.  Possible file types include (but not limited to):
			PrecacheResource( "model", "*.vmdl", context )
			PrecacheResource( "soundfile", "*.vsndevts", context )
			PrecacheResource( "particle", "*.vpcf", context )
			PrecacheResource( "particle_folder", "particles/folder", context )
	]]

	PrecacheUnitByNameSync("npc_dota_tower_empty", context)
	PrecacheUnitByNameSync("npc_dota_tower_wall", context)
	PrecacheUnitByNameSync("npc_dota_tower_wall2", context)
	PrecacheUnitByNameSync("npc_dota_enemy_fish", context)
	PrecacheUnitByNameSync("npc_dota_enemy_1", context)


	PrecacheModel("models/create_01.vmdl", context)
	PrecacheModel("models/wall.vmdl", context)
	PrecacheModel("models/wall2.vmdl", context)
	PrecacheModel("models/gryphon_statue001.vmdl", context)
	PrecacheModel("maps/reef_assets/characters/anglerfish/darkreef_anglerfish.vmdl", context)

	PrecacheResource("particle_folder", "particles/buildinghelper", context)

	-- 注册控制台指令
	-- Convars:RegisterCommand( "holdout_status_report", function(...) return self:_StatusReportConsoleCommand( ... ) end, "Report the status of the current holdout game.", FCVAR_CHEAT )
end

-- Create the game mode when we activate
function Activate()
	GameRules.AddonTemplate = CAddonTemplateGameMode()
	GameRules.AddonTemplate:InitGameMode()
end

function CAddonTemplateGameMode:InitGameMode()
	print( "Template addon is loaded." )

	-- 调试要去掉战争迷雾
	GameRules:GetGameModeEntity():SetFogOfWarDisabled(true)

	-- 监听游戏状态
	ListenToGameEvent("game_rules_state_change", Dynamic_Wrap(CAddonTemplateGameMode,"OnGameRulesStateChange"), self)
	--监听玩家聊天事件
	ListenToGameEvent("player_chat", Dynamic_Wrap(CAddonTemplateGameMode, "OnPlayerChat"), self)

	GameRules:GetGameModeEntity():SetThink( "OnThink", self, "GlobalThink", 2 )  
end

-- Evaluate the state of the game
function CAddonTemplateGameMode:OnThink()

	-- 对所有玩家显示通用的弹出窗口
	-- ShowGenericPopup( "#holdout_instructions_title", "#holdout_instructions_body", "", "", DOTA_SHOWGENERICPOPUP_TINT_SCREEN )

	if GameRules:State_Get() == DOTA_GAMERULES_STATE_GAME_IN_PROGRESS then
		--print( "Template addon script is running." )
	elseif GameRules:State_Get() >= DOTA_GAMERULES_STATE_POST_GAME then
		return nil
	end
	return 1
end

function CAddonTemplateGameMode:OnGameRulesStateChange( keys )
	GameRules:SetPreGameTime( 10.0)  --设置等待游戏开始时间为10秒

	--获取游戏进度
	local newState = GameRules:State_Get()

	if newState == DOTA_GAMERULES_STATE_HERO_SELECTION then
		print("Player begin select hero")  --玩家处于选择英雄界面

	elseif newState == DOTA_GAMERULES_STATE_PRE_GAME then
		print("Player ready game begin")  --玩家处于游戏准备状态

	elseif newState == DOTA_GAMERULES_STATE_GAME_IN_PROGRESS then
		print("Player game begin")  --玩家开始游戏

		createTimer(nil,"shuabing",createRowEnemy,10,10)
		
		-- 这个不知道有没有用啊
		--Timers:CreateTimer({
		--	endTime = 30,
		--	callback = createRowEnemy()
		--})

	end
end

function CAddonTemplateGameMode:OnPlayerChat( keys )
	OnPlayerChat(keys)
end

