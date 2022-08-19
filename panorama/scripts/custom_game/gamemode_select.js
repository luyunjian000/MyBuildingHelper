var mainContainer = $.GetContextPanel().FindChildInLayoutFile("mainContainer");
var gItems = $.GetContextPanel().FindChildInLayoutFile("items");

//
var exampleData = {
        type: "diff",
        items: ["diff1", "diff2", "diff3"],
        selected: "diff1"
    }
    //key:pid value:[]
var gGamemodeChoose = {}

var gTargetPlayerId = null

function OnItemClick(type, item) {
    var panel = $.GetContextPanel()
    GameEvents.SendCustomGameEventToServer("gamemode_choose", { type, item, targetPlayerId: gTargetPlayerId });
    Game.EmitSound("ui_generic_button_click")
    mainContainer.RemoveClass("Visible")
}

function GetCustomNetTable(sTableName) {
    var entries = CustomNetTables.GetAllTableValues(sTableName);
    var table = {};
    if (entries != null)
        entries.forEach(entry => table[entry.key] = entry.value);
    return table;
}

function updateUi() {
    var localPlayerId = Game.GetLocalPlayerID();
    var queryUnit = Players.GetLocalPlayerPortraitUnit();
    var unitPlayerId = Entities.GetPlayerOwnerID(queryUnit);



    var targetPlayerId = null
    if (!queryUnit) {
        targetPlayerId = localPlayerId
    } else {
        if (Entities.IsControllableByPlayer(queryUnit, localPlayerId)) {
            targetPlayerId = unitPlayerId
        } else {
            targetPlayerId = localPlayerId
        }
    }
    gTargetPlayerId = targetPlayerId
    var gameChoose = gGamemodeChoose[targetPlayerId + ""]
    var choose = null
    if (gameChoose) {
        gameChoose = gameChoose.value
        for (let i = 0; i < Object.keys(gameChoose).length; i++) {
            if (!gameChoose["" + (i + 1)].selected) {
                choose = gameChoose["" + (i + 1)]
                break
            }
        }
    }

    gItems.RemoveAndDeleteChildren()

    if (choose) {
        mainContainer.AddClass("Visible")
        mainContainer.SetDialogVariable("title", $.Localize("#" + choose.type));

        for (let i = 0; i < Object.keys(choose.items).length; i++) {
            const item = choose.items[(i + 1) + ""];
            var newButton = $.CreatePanel("Panel", gItems, "");
            var snippet = "ChooseItem"
            if (choose.type == "choose_hero") {
                snippet = "ChooseHero"
            }
            newButton.BLoadLayoutSnippet(snippet);
            newButton.SetDialogVariable("itemName", $.Localize("#" + item));
            newButton.SetPanelEvent('onactivate', function() { OnItemClick(choose.type, item); });
            if (snippet == "ChooseHero") {
                const heropanel = newButton.FindChildTraverse("heroPanel")
                heropanel.SetUnit(item, "default_camera", true);
                const panel = newButton
                    // newButton.SetPanelEvent('onmouseover', function() {
                    //     $.DispatchEvent("DOTAShowTextTooltip", panel, $.Localize(item));
                    // });
                    // newButton.SetPanelEvent('onmouseout', function() {
                    //     $.DispatchEvent("DOTAShowTextTooltip", panel, $.Localize(item));
                    // });
            }
        }
    } else {
        mainContainer.RemoveClass("Visible")
    }
}
//
function OnGamemodeChoose(table_name, key, data) {
    $.Msg("OnGamemodeChoose ", key)
    var localPlayerId = Game.GetLocalPlayerID();
    gGamemodeChoose[key] = data;
    if (localPlayerId == Number(key)) {
        updateUi();
    }
}

CustomNetTables.SubscribeNetTableListener("gamemode_choose", OnGamemodeChoose)

var updateFunc = function() {
    gGamemodeChoose = GetCustomNetTable("gamemode_choose");
    updateUi();
    //$.Schedule(10.0, updateFunc);
}

$.Schedule(1.0, updateFunc);

GameEvents.Subscribe("dota_player_update_selected_unit", updateUi);
GameEvents.Subscribe("dota_player_update_query_unit", updateUi);