"use strict"
var right_click_repair = CustomNetTables.GetTableValue("building_settings", "right_click_repair").value;

function GetMouseTarget()
{
    var mouseEntities = GameUI.FindScreenEntities( GameUI.GetCursorPosition() )
    var localHeroIndex = Players.GetPlayerHeroEntityIndex( Players.GetLocalPlayer() )

    for ( var e of mouseEntities )
    {
        if ( !e.accurateCollision )
            continue
        return e.entityIndex
    }

    for ( var e of mouseEntities )
    {
        return e.entityIndex
    }

    return 0
}

// 处理右键事件
function OnRightButtonPressed()
{
    var iPlayerID = Players.GetLocalPlayer()
    var selectedEntities = Players.GetSelectedEntities( iPlayerID )
    var mainSelected = Players.GetLocalPlayerPortraitUnit() 
    var targetIndex = GetMouseTarget()
    var pressedShift = GameUI.IsShiftDown()

    // 生成器右键单击
    if ( IsBuilder( mainSelected ) )
    {
        // Cancel BH
        if (!pressedShift) SendCancelCommand()

        // 修复右键单击
        if (right_click_repair && IsCustomBuilding(targetIndex) && Entities.GetHealthPercent(targetIndex) < 100 && IsAlliedUnit(targetIndex, mainSelected)) {
            GameEvents.SendCustomGameEventToServer( "building_helper_repair_command", {targetIndex: targetIndex, queue: pressedShift})
            return true
        }
    }

    return false
}

// 处理左键事件
function OnLeftButtonPressed() {
    return false
}

function IsCustomBuilding(entIndex) {
    return (Entities.GetAbilityByName( entIndex, "ability_building") != -1)
}

function IsBuilder(entIndex) {
    var tableValue = CustomNetTables.GetTableValue( "builders", entIndex.toString())
    return (tableValue !== undefined) && (tableValue.IsBuilder == 1)
}

function IsAlliedUnit(entIndex, targetIndex) {
    return (Entities.GetTeamNumber(entIndex) == Entities.GetTeamNumber(targetIndex))
}

// 主鼠标事件回调 
/** 
GameUI.SetMouseCallback( function( eventName, arg ) {
    var CONSUME_EVENT = true
    var CONTINUE_PROCESSING_EVENT = false
    // 0左键，1右键，2中键
    var LEFT_CLICK = (arg === 0)
    var RIGHT_CLICK = (arg === 1)
    // var MIDDLE_CLICK = (arg === 2)

    if ( GameUI.GetClickBehaviors() !== CLICK_BEHAVIORS.DOTA_CLICK_BEHAVIOR_NONE )
        return CONTINUE_PROCESSING_EVENT

    var mainSelected = Players.GetLocalPlayerPortraitUnit()

    if ( eventName === "pressed" || eventName === "doublepressed")
    {
        // Builder Clicks
        if (IsBuilder(mainSelected))
            if (LEFT_CLICK) 
                return (state == "active") ? SendBuildCommand() : OnLeftButtonPressed()
            else if (RIGHT_CLICK) 
                return OnRightButtonPressed()

        if (LEFT_CLICK) {
            return OnLeftButtonPressed()
        }
        else if (RIGHT_CLICK) {
            return OnRightButtonPressed() 
        }
    }
    return CONTINUE_PROCESSING_EVENT
} )
**/
