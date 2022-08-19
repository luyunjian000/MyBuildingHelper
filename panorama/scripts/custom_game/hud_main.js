"use strict";

GameUI.SetCameraTerrainAdjustmentEnabled(false);


var damageItemList = $.GetContextPanel().FindChildInLayoutFile("damageItemList");


var damage_table = CustomNetTables.GetTableValue("damage_table", "all")
CustomNetTables.SubscribeNetTableListener("damage_table", function() {
    damage_table = CustomNetTables.GetTableValue("damage_table", "all")
    UpdateDamageTable()
})

if (!damage_table) {
    damage_table = {}
}

function formatString(str, args) {
    for (var i in args) {
        var arg = args[i];
        str = str.replace("s" + i, arg);
    }
    return str;
}

function localHiddenMsg() {
    $('#errorMsgBG').SetHasClass("AniScaleOut", false);
    $('#errorMsgBG').SetHasClass("Hidden", true);
}

function localShowMsg() {
    $('#errorMsgBG').SetHasClass("AniScaleOut", true);
    $('#errorMsgBG').SetHasClass("Hidden", false);
}
var g_func_hiddenClass = null;

function onErrorMsg(data) {
    var text = data.text
    var errorMsgBG = $('#errorMsgBG');
    Game.EmitSound("General.CastFail_AbilityNotLearned");
    if (errorMsgBG.BHasClass("AniScaleOut")) {
        localHiddenMsg();
        $.CancelScheduled(g_func_hiddenClass);
    }
    localShowMsg();
    $('#errorMsgTxt').text = $.Localize(text);
    g_func_hiddenClass = $.Schedule(1.2, localHiddenMsg);
}
GameUI.onErrorMsg = onErrorMsg;
GameEvents.Subscribe("S2C_ERROR_MSG", onErrorMsg);
localHiddenMsg();


function MouseOver(str, panelname) {
    $.DispatchEvent("DOTAShowTextTooltip", $('#btn_' + str), $.Localize("#" + str + "_desc"));
}

function MouseOut() {
    $.DispatchEvent("DOTAHideTextTooltip");
}

function ShowResPanel() {
    $('#kill_num').visible = !$('#kill_num').visible;
}

function ShowBuildPanel() {
    $('#setRoot2').visible = !$('#setRoot2').visible;
}


function LookAtBoss(data) {
    GameUI.SetCameraTarget(data["boss_ent_index"]);
}

function FixCamera() {
    GameUI.SetCameraTarget(-1);
}

function SlideThumbActivate() {
    var slideThumb = $.GetContextPanel();
    var bMinimized = slideThumb.BHasClass('Minimized');
    if (bMinimized) {
        Game.EmitSound("ui_settings_slide_out");
    } else {
        Game.EmitSound("ui_settings_slide_in");
    }
    slideThumb.ToggleClass('Minimized');
}

function UpdateDamageTable() {
    let pid = Players.GetLocalPlayer();
    damageItemList.RemoveAndDeleteChildren()

    if (!damage_table[pid]) {
        return
    }

    let list = []
    for (const name in damage_table[pid]) {
        for (const idx in damage_table[pid][name]) {
            const node = {
                name: name,
                damage: Math.ceil(damage_table[pid][name][idx]),
            }
            list.push(node)
        }
    }
    if (list.length == 0) {
        return
    }
    list.sort(function(a, b) {
        return -a.damage + b.damage
    })
    const maxDamage = list[0].damage
    if (maxDamage == 0) {
        maxDamage = 1
    }
    for (const idx in list) {
        const node = list[idx]
        var item = $.CreatePanel("Panel", damageItemList, "");
        item.BLoadLayoutSnippet("damage_item");
        item.SetDialogVariable("unit_name", $.Localize("#" + node.name));
        item.SetDialogVariable("damage_value", node.damage);

        var damageItemColor = item.FindChildTraverse("damageItemColor")
        const progress = Math.ceil(100 * node.damage / maxDamage)
        damageItemColor.style.width = "" + progress + "%"
    }
}
UpdateDamageTable()


GameEvents.Subscribe("lookat_boss", LookAtBoss);

(function() {
    GameEvents.SendCustomGameEventToServer("C2S_RECONNECT", {});
})();