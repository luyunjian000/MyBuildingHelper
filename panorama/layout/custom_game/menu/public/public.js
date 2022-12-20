// 发送自定义事件
function FireCustomGameEvent(eventName, data) {
    let playerId = Players.GetLocalPlayer()
    let selectedUnits = Players.GetSelectedEntities(playerId)
    data.playerId = playerId
    data.selectedUnits = selectedUnits
    GameEvents.SendCustomGameEventToServer(eventName, data)
}


function FireToggleEvent(eventName) {

    let data = {
        checked: $('#' + eventName).checked
    }
    FireCustomGameEvent(eventName, data);
}

// tooltip
function ShowDOTATooltip(panel, text) {
    //  DispatchEvent 调度事件
    //  DOTAShowTextTooltip 显示包含指定信息的提示栏。同时应用名为“style”的CSS类来使用定制样式。
    $.DispatchEvent("DOTAShowTextTooltip", panel, text)
}

function HideDOTATooltip() {
    $.DispatchEvent("DOTAHideTextTooltip")
    $.DispatchEvent("DOTAHideTitleTextTooltip")
}
