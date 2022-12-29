-- Generated from template

if CAddonTemplateGameMode == nil then
	CAddonTemplateGameMode = class({})
end

require("buildinghelper/index")
require("others/create_enemy")
require("others/player_chat")
require("buildmaps/buildmaps")


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
	-- 分配队伍的颜色
	self.m_TeamColors = {}
	self.m_TeamColors[DOTA_TEAM_GOODGUYS] = { 61, 210, 150 }	--		Teal
	self.m_TeamColors[DOTA_TEAM_BADGUYS]  = { 243, 201, 9 }		--		Yellow
	self.m_TeamColors[DOTA_TEAM_CUSTOM_1] = { 197, 77, 168 }	--      Pink
	self.m_TeamColors[DOTA_TEAM_CUSTOM_2] = { 255, 108, 0 }		--		Orange
	self.m_TeamColors[DOTA_TEAM_CUSTOM_3] = { 52, 85, 255 }		--		Blue
	self.m_TeamColors[DOTA_TEAM_CUSTOM_4] = { 101, 212, 19 }	--		Green
	self.m_TeamColors[DOTA_TEAM_CUSTOM_5] = { 129, 83, 54 }		--		Brown
	self.m_TeamColors[DOTA_TEAM_CUSTOM_6] = { 27, 192, 216 }	--		Cyan
	self.m_TeamColors[DOTA_TEAM_CUSTOM_7] = { 199, 228, 13 }	--		Olive
	self.m_TeamColors[DOTA_TEAM_CUSTOM_8] = { 140, 42, 244 }	--		Purple

	for team = 0, (DOTA_TEAM_COUNT-1) do
		color = self.m_TeamColors[ team ]
		if color then
			SetTeamCustomHealthbarColor( team, color[1], color[2], color[3] )
		end
	end

	if GetMapName() == "main" then
		GameRules:SetCustomGameTeamMaxPlayers( DOTA_TEAM_GOODGUYS, 0 )
		GameRules:SetCustomGameTeamMaxPlayers( DOTA_TEAM_BADGUYS, 0 )
		GameRules:SetCustomGameTeamMaxPlayers( DOTA_TEAM_CUSTOM_1, 1 )
		GameRules:SetCustomGameTeamMaxPlayers( DOTA_TEAM_CUSTOM_2, 1 )
		GameRules:SetCustomGameTeamMaxPlayers( DOTA_TEAM_CUSTOM_3, 1 )
		GameRules:SetCustomGameTeamMaxPlayers( DOTA_TEAM_CUSTOM_4, 1 )
		GameRules:SetCustomGameTeamMaxPlayers( DOTA_TEAM_CUSTOM_5, 1 )
		GameRules:SetCustomGameTeamMaxPlayers( DOTA_TEAM_CUSTOM_6, 1 )
		GameRules:SetCustomGameTeamMaxPlayers( DOTA_TEAM_CUSTOM_7, 1 )
		GameRules:SetCustomGameTeamMaxPlayers( DOTA_TEAM_CUSTOM_8, 1 )
	end

	GameRules:GetGameModeEntity().AddonTemplate = self



	-- 调试要去掉战争迷雾
	GameRules:GetGameModeEntity():SetFogOfWarDisabled(true)
	-- GameRules:GetGameModeEntity():SetUnseenFogOfWarEnabled(true)

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

		-- 刷兵
		--createTimer(nil,"shuabing",createRowEnemy,10,10)
		
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

-- 分配队伍
function CAddonTemplateGameMode:AssignTeams()
	--print( "Assigning teams" )
	local vecTeamValid = {}
	local vecTeamNeededPlayers = {}
	for nTeam = 0, (DOTA_TEAM_COUNT-1) do
		local nMax = GameRules:GetCustomGameTeamMaxPlayers( nTeam )
		if nMax > 0 then
			--print( "Found team " .. nTeam .. " with max players " .. nMax )
			vecTeamNeededPlayers[ nTeam ] = nMax
			vecTeamValid[ nTeam ] = true
		else
			vecTeamValid[ nTeam ] = false
		end
	end

	-- loop 1: count up players on each team
	local hPlayers = {}
	for nPlayerID = 0, DOTA_MAX_TEAM_PLAYERS-1 do
		if PlayerResource:IsValidPlayerID( nPlayerID ) then
			local nTeam = PlayerResource:GetTeam( nPlayerID )
			if vecTeamValid[ nTeam ] == false then
				nTeam = PlayerResource:GetCustomTeamAssignment( nPlayerID )
			end
			--print( "Found player " .. nPlayerID .. " on team " .. nTeam )
			if vecTeamValid[ nTeam ] then
				vecTeamNeededPlayers[ nTeam ] = vecTeamNeededPlayers[ nTeam ] - 1
			else
				table.insert( hPlayers, nPlayerID )
			end
		end
	end

	-- loop 2: 分配玩家。对于无效团队中的每个球员，找到所需球员数量最多的团队，并将球员分配到该队
	for _,nPlayerID in pairs( hPlayers ) do
		--print( "Finding team for player " .. nPlayerID )
		local nTeamNumber = -1
		local nHighest = 0
		for nTeam = 0, (DOTA_TEAM_COUNT-1) do
			if vecTeamValid[ nTeam ] then
				local nVal = vecTeamNeededPlayers[ nTeam ]
				if nVal > nHighest then
					--print( "found team " .. nTeam .. " with needed " .. nVal .. " but highest was only " .. nHighest )
					nHighest = nVal
					nTeamNumber = nTeam
				end
			end
		end
		if nTeamNumber > 0 then
			PlayerResource:SetCustomTeamAssignment( nPlayerID, nTeamNumber )
			vecTeamNeededPlayers[ nTeamNumber ] = vecTeamNeededPlayers[ nTeamNumber ] - 1
		end
	end
		
	if self.m_bFillWithBots == true then
		GameRules:BotPopulate()
	end
end

