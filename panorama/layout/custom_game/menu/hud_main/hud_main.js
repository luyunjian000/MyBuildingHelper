// 载入面板
(function () {
    $("#toolPanelContainer").BLoadLayout("file://{resources}/layout/custom_game/menu/tool/tool.xml", false, false)
    $("#localToolPanelContainer").BLoadLayout("file://{resources}/layout/custom_game/menu/localTool/localTool.xml", false, false)
    $("#recreationPanelContainer").BLoadLayout("file://{resources}/layout/custom_game/menu/recreation/recreation.xml", false, false)

    // 订阅自定义游戏事件
    GameEvents.Subscribe("CustomHUDError", CustomHUDError)
    GameEvents.Subscribe("CustomHUDInfo", CustomHUDInfo)
    GameEvents.Subscribe("CallSuperAxe", CallSuperAxe)
    GameEvents.Subscribe("KillSuperAxe", KillSuperAxe)
})();

var CustomHUDInfoSchedule = null
var CustomHUDInfoScheduleStatus = false
GameUI.HappyAxeMode = false

// 自定义显示隐藏面板
function toolPanelToggle() {
    if (GameUI.HappyAxeMode == false || GameUI.HappyAxeMode == null) {
        $("#recreationPanelContainer").AddClass('Minimized')
        $("#localToolPanelContainer").AddClass('Minimized')
        $("#toolPanelContainer").ToggleClass('Minimized')
    } else {
        GameUI.SendCustomHUDError("击杀斧王之前禁用此菜单", "")
    }
}

function localToolPanelToggle() {
    if (GameUI.HappyAxeMode == false || GameUI.HappyAxeMode == null) {
        $("#recreationPanelContainer").AddClass('Minimized')
        $("#toolPanelContainer").AddClass('Minimized')
        $("#localToolPanelContainer").ToggleClass('Minimized')
    } else {
        GameUI.SendCustomHUDError("击杀斧王之前禁用此菜单", "")
    }
}


function recreationPanelToggle() {
    if (GameUI.HappyAxeMode == false || GameUI.HappyAxeMode == null) {
        $("#toolPanelContainer").AddClass('Minimized')
        $("#localToolPanelContainer").AddClass('Minimized')
        $("#recreationPanelContainer").ToggleClass('Minimized')
    } else {
        GameUI.SendCustomHUDError("击杀斧王之前禁用此菜单", "")
    }
}


function UrlToWiki() {
    $.DispatchEvent("ExternalBrowserGoToURL", "http://dota.huijiwiki.com/p/140255");
}

function CustomHUDError(data) {
    GameUI.SendCustomHUDError(data.v, "")
}

function CustomHUDInfo(data) {
    if (CustomHUDInfoScheduleStatus) {
        // 取消定时函数
        $.CancelScheduled(CustomHUDInfoSchedule)
    }
    if ($("#CustomHUDInfo").GetChildCount() > 10) {
        $("#CustomHUDInfo").GetChild(0).DeleteAsync(0)
    }
    let Panel = $.CreatePanel('Panel', $("#CustomHUDInfo"), '')
    let Label = $.CreatePanel('Label', Panel, '')
    Label.text = data.v
    $("#CustomHUDInfo").RemoveClass('Minimized')
    CustomHUDInfoScheduleStatus = true
    CustomHUDInfoSchedule = $.Schedule(10, function () {
        $("#CustomHUDInfo").AddClass('Minimized')
        CustomHUDInfoScheduleStatus = false
    })
}

function feedbackPanelToggle() {
    $("#feedbackPanelContainer").ToggleClass('Minimized')
}

function feedbackok() {
    let feedbackcontent = $('#feedbackInput').text

    let data = {
        feedbackcontent: feedbackcontent
    }
    FireCustomGameEvent('feedback', data)
    feedbackreset()
    feedbackcancel()
}

function feedbackreset() {
    $('#feedbackInput').text = ''
}

function feedbackcancel() {
    $("#feedbackPanelContainer").AddClass('Minimized')
    $('#feedbackcancel').SetFocus()
}

let hpEffect = 100
let axeEnt = null
function CallSuperAxe(data) {
    hpEffect = 100
    axeEnt = data.unit
    $('#axeStatus').RemoveClass('Minimized')

    GameUI.SelectAbilityContainer.RemoveClass('SelectAbilityContainerVisible');
    GameUI.SelectUnitContainer.RemoveClass('SelectUnitVisible');
    GameUI.AddWoodenStakeDialog.AddClass('Minimized')
    GameUI.HideSkillOptionDialog.AddClass('Minimized')
    $('#recreationPanelContainer').AddClass('Minimized')
    GameUI.HappyAxeMode = true

    UpdatedAxeHealthBar()
}

function KillSuperAxe() {
    GameUI.HappyAxeMode = false
}


function UpdatedAxeHealthBar() {
    const ThinkInterval = 0
    const hpBar = $('#axeHealthProgress_left')
    const hpBarEffect = $('#axeHealthProgress_center')
    const hpBarLabel = $('#axeHealthLabel')

    if (axeEnt && Entities.IsAlive(axeEnt)) {
        let hp = Entities.GetHealth(axeEnt) / Entities.GetMaxHealth(axeEnt) * 100
        let hpText = hp.toFixed(2)
        if (hpEffect > hp) {
            hpEffect = hpEffect - 0.1
        } else {
            hpEffect = hp
        }

        hpBar.style.width = hp + '%'
        hpBarEffect.style.width = hpEffect + '%'
        hpBarLabel.text = hpText + '%'

        UpdateBuffs(axeEnt);

        $.Schedule(ThinkInterval, UpdatedAxeHealthBar)
    } else {
        $('#axeStatus').AddClass('Minimized')
    }

}

function UpdateBuffs(unit) {

    var nBuffs = Entities.GetNumBuffs(unit);
    var BuffList = $("#BuffList");

    var BuffListIndex = 0;

    for (var i = 0; i < nBuffs; i++) {
        var buffSerial = Entities.GetBuff(unit, i);
        if (buffSerial == -1)
            continue;

        if (Buffs.IsHidden(unit, buffSerial))
            continue;

        var buffPanel = BuffList.GetChild(BuffListIndex++);

        if (!buffPanel) {
            buffPanel = $.CreatePanel('Panel', BuffList, '');
            buffPanel.BLoadLayoutSnippet('buff');
            RegisterEvents(buffPanel)
        }

        UpdateBuff(buffPanel, unit, buffSerial);
        buffPanel.visible = true;
    }

    var max = BuffList.GetChildCount();
    for (var i = BuffListIndex; i < max; i++) {
        BuffList.GetChild(i).visible = false;
    }

}


function RegisterEvents(buffPanel) {
    // 设置面板事件
    buffPanel.SetPanelEvent('onmouseover', function () {
        OnMouseOver(buffPanel);
    })
    buffPanel.SetPanelEvent('onmouseout', function () {
        OnMouseOut();
    })
}

function OnMouseOver(buffPanel) {
    $.DispatchEvent('DOTAShowBuffTooltip', buffPanel, buffPanel.unit, buffPanel.m_BuffSerial, Entities.IsEnemy(buffPanel.unit));
}

function OnMouseOut() {
    $.DispatchEvent('DOTAHideBuffTooltip');
}

function UpdateBuff(buffPanel, unit, buffSerial) {
    let nNumStacks = Buffs.GetStackCount(unit, buffSerial);
    buffPanel.SetHasClass("is_debuff", Buffs.IsDebuff(unit, buffSerial));
    buffPanel.SetHasClass("has_stacks", (nNumStacks > 0));
    buffPanel.FindChildTraverse('stack-count').text = nNumStacks;
    buffPanel.m_BuffSerial = buffSerial;
    buffPanel.unit = unit;

    let buffTexture = Buffs.GetTexture(unit, buffSerial);

    if (buffTexture.indexOf("item_") === 0) {
        buffPanel.SetHasClass("is_item", true);
        buffPanel.SetHasClass("is_ability", false);
        buffPanel.SetHasClass("is_buff", false);
        buffPanel.FindChildTraverse('item').itemname = buffTexture;
    }
    else {
        let buff_ability = Buffs.GetAbility(unit, buffSerial);
        if (Abilities.IsItem(buff_ability)) {
            buffPanel.SetHasClass("is_item", true);
            buffPanel.SetHasClass("is_ability", false);
            buffPanel.SetHasClass("is_buff", false);
            buffPanel.FindChildTraverse('item').contextEntityIndex = buff_ability;
        }
        else if (buff_ability > 0) {
            buffPanel.SetHasClass("is_item", false);
            buffPanel.SetHasClass("is_ability", true);
            buffPanel.SetHasClass("is_buff", false);
            buffPanel.FindChildTraverse('ability').contextEntityIndex = buff_ability;
        }
        else {
            buffPanel.SetHasClass("is_item", false);
            buffPanel.SetHasClass("is_ability", false);
            buffPanel.SetHasClass("is_buff", true);
            let imagesrc = `file://{images}/spellicons/${buffTexture}.png`
            buffPanel.FindChildTraverse('dotabuff').SetImage(imagesrc);
        }
    }

    let deg = -360 * (Buffs.GetRemainingTime(unit, buffSerial) / Buffs.GetDuration(unit, buffSerial));
    deg = (isFinite(deg)) ? deg : 0;
    buffPanel.FindChildTraverse('background').style.clip = "radial(50% 50%,0deg," + deg.toFixed(2) + "deg)";
}