function refreshGold(data) {
    var gold = data.gold;
    $('#gold_label').text = gold;
}

var gPlayerData = CustomNetTables.GetAllTableValues("player")
CustomNetTables.SubscribeNetTableListener("player", function() {
    gPlayerData = CustomNetTables.GetAllTableValues("player")
    UpdateResourceBoard()
})

function getPlayerData(pid) {
    var v = gPlayerData.find(v => {
        return parseInt(v.key) == pid
    })
    if (v) {
        return v.value
    }
    return null
}


function btnGoldClicked() {
    GameEvents.SendEventClientSide("show_give_gold", {});
}

function UpdateResourceBoard(params) {
    var queryUnit = Players.GetLocalPlayerPortraitUnit();
    var id = Entities.GetPlayerOwnerID(queryUnit);
    var localPid = Players.GetLocalPlayer()
    if (Players.GetTeam(id) != Players.GetTeam(localPid)) {
        $('#wood_label').text = "-";
        $('#gold_label').text = "-";
        $('#food_label').text = "-/-";
    } else {
        var pdata = getPlayerData(id)
        if (id >= 0 && pdata) {
            var wood = pdata.wood || 0;
            $('#wood_label').text = wood;
            var gold = pdata.gold || 0
            $('#gold_label').text = gold;
            var food = pdata.food || 0
            var maxFood = pdata.maxFood || 0
            var foodRemain = maxFood - food
            $('#food_label').text = foodRemain + "/" + maxFood;
        }
    }
}

(function() {
    UpdateResourceBoard();
    //GameEvents.Subscribe( "__refresh__gold", refreshGold );
    GameUI.SetDefaultUIEnabled(DotaDefaultUIElement_t.DOTA_DEFAULT_UI_INVENTORY_GOLD, false);
    GameEvents.Subscribe("dota_player_update_selected_unit", UpdateResourceBoard);
    GameEvents.Subscribe("dota_player_update_query_unit", UpdateResourceBoard);
    /*  GameEvents.Subscribe( "top_notification", TopNotification );
      GameEvents.Subscribe( "bottom_notification", BottomNotification );
      GameEvents.Subscribe( "top_remove_notification", TopRemoveNotification );
      GameEvents.Subscribe( "bottom_remove_notification", BottomRemoveNotification );
      GameEvents.Subscribe( "midleft_notification", MidLeftNotification );
      GameEvents.Subscribe( "midleft_remove_notification", MidLeftRemoveNotification );
      GameUI.CustomUIConfig().errorMessage = BottomNotification;*/
})();