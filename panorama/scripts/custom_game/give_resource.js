var pSelf = $.GetContextPanel();
var pQuickuse = $("#QuickusePanel");
var fSliderValue = 0;
var fEntryValue = 0;
var iTarget = -1;
var fEntryMaxValue = 0

var gPlayerList = $.GetContextPanel().FindChildInLayoutFile("playerList");

function getGold(id) {
    var gold = CustomNetTables.GetTableValue("gold", id);
    if (gold && gold.val) {
        gold = gold.val
    } else {
        gold = 0
    }
    return gold
}

function Round(fNumber, prec = 0) {
    let i = Math.pow(10, prec);
    return Math.round(fNumber * i) / i;
}

function Clamp(num, min, max) {
    return num <= min ? min : (num >= max ? max : num);
}

function Lerp(percent, a, b) {
    return a + percent * (b - a);
}


function RemapValClamped(num, a, b, c, d) {
    if (a == b)
        return c;
    var percent = (num - a) / (b - a);
    percent = Clamp(percent, 0.0, 1.0);
    return Lerp(percent, c, d);
}


function Update() {
    if (pQuickuse.BHasClass("Hidden")) return;

    let iPlayerID = Players.GetLocalPlayer();;
    let iPlayerGold = getGold(iPlayerID);
    //  $.Msg(iPlayerGold)
    let iMaxValue = iPlayerGold;
    $("#NumberEntry").max = iMaxValue;
    //   $.Msg(fSliderValue, $("#NumberSlider").value)
    if (fSliderValue != $("#NumberSlider").value) {
        $("#NumberEntry").value = RemapValClamped($("#NumberSlider").value, $("#NumberSlider").min, $("#NumberSlider").max, $("#NumberEntry").min, $("#NumberEntry").max);
    }
    //  $.Msg(fEntryValue, $("#NumberEntry").value)
    if (fEntryValue != $("#NumberEntry").value || fEntryMaxValue != $("#NumberEntry").max) {
        $("#NumberSlider").value = RemapValClamped($("#NumberEntry").value, $("#NumberEntry").min, $("#NumberEntry").max, $("#NumberSlider").min, $("#NumberSlider").max);
    }
    fSliderValue = $("#NumberSlider").value;
    fEntryMaxValue = $("#NumberEntry").max;
    fEntryValue = $("#NumberEntry").value;
    pQuickuse.SetDialogVariableInt("buy_cost", Math.max($("#NumberEntry").value, 0));
    $.Schedule(0.05, Update);
}

function Confirm() {
    if (Players.IsValidPlayerID(iTarget)) {
        var iPlayerID = Players.GetLocalPlayer();
        GameEvents.SendCustomGameEventToServer("on_give_gold", { sourcePid: iPlayerID, targetPid: iTarget, gold: $("#NumberEntry").value })
        End();
    } else {
        GameEvents.SendEventClientSide("dota_hud_error_message", { "splotscreenplayer": Players.GetLocalPlayer(), "reason": 80, "message": "player_not_choosed" });
    }

}

function intToARGB(i) {
    return ('00' + (i & 0xFF).toString(16)).substr(-2) +
        ('00' + ((i >> 8) & 0xFF).toString(16)).substr(-2) +
        ('00' + ((i >> 16) & 0xFF).toString(16)).substr(-2) +
        ('00' + ((i >> 24) & 0xFF).toString(16)).substr(-2);
}

function clearPlayer() {
    gPlayerList.RemoveAndDeleteChildren()
}

function addPlayer(pid) {
    if (!Players.IsValidPlayerID(pid)) {
        return
    }
    var sPlayerName = Players.GetPlayerName(pid);
    var iHeroEntIndex = Players.GetPlayerHeroEntityIndex(pid);
    var sPlayerColor = intToARGB(Players.GetPlayerColor(pid));
    var tPlayerInfo = Game.GetPlayerInfo(pid);
    var newButton = $.CreatePanel("RadioButton", gPlayerList, "");
    newButton.BLoadLayoutSnippet("give_resource_snippet_player");
    newButton.SetDialogVariable("item_name", "<font color='#" + sPlayerColor + "'>" + sPlayerName + "</font>");
    newButton.SetPanelEvent('onactivate', function() {
        iTarget = pid
    });
    newButton.FindChildTraverse("ItemImage").steamid = tPlayerInfo.player_steamid;
}

function End() {
    iTarget = -1;
    pQuickuse.AddClass("Hidden");
}

function Show(params) {
    pQuickuse.RemoveClass("Hidden");
    fSliderValue = 0
    fEntryValue = 0
    fEntryMaxValue = 0
    iTarget = -1;
    $("#NumberEntry").value = 0
    $("#NumberSlider").value = 0
    clearPlayer()
    let pid = Players.GetLocalPlayer();
    for (let i = 0; i < Players.GetMaxPlayers(); i++) {
        if (i != pid) {
            addPlayer(i)
        }
    }
    Update();
}

(function() {
    $("#NumberEntry").min = 0;

    GameEvents.Subscribe("show_give_gold", Show)
        // GameEvents.Subscribe("quick_use_consumable", Start);
        // GameEvents.Subscribe("select_hero_card", OnSelectHeroCard);
})();