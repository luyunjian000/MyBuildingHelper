(function () {
    MoveToDialog = new FiveDialog({
        el: $("#MoveToDialog"),
        title: '移动至坐标',
        defaultValue: '0,0,128',
        content: '输入xyz坐标，以半角逗号分隔，高度可省略，目标坐标不可到达时，会移动到附近。',
        ok: function () {
            let v = MoveToDialog.getinput()
            if (v.indexOf(',') == -1) {
                MoveToDialog.setErrorInfo('输入的格式不正确')
                return false
            }
            let tempArr = v.split(',')
            var pos = {
                x: Number(tempArr[0]),
                y: Number(tempArr[1]),
                z: Number(tempArr[2])
            }
            FireCustomGameEvent("MoveTo", { pos })
            MoveToDialog.close()
        }
    })

    SetCameraDistanceDialog = new FiveDialog({
        el: $("#SetCameraDistanceDialog"),
        title: '调整视角高度',
        defaultValue: '1200',
        content: '调太高会卡，量力而行，建议不要超过2000。',
        ok: function () {
            let v = Number(SetCameraDistanceDialog.getinput())
            GameUI.SetCameraDistance(v)
            FireCustomGameEvent("SetCameraDistanceDialog", { v: v })
            SetCameraDistanceDialog.close()
        }
    })

    SetGoldDialog = new FiveDialog({
        el: $("#SetGoldDialog"),
        title: '设置金钱',
        defaultValue: '0',
        content: '设置当前金钱。',
        ok: function () {
            let v = Number(SetGoldDialog.getinput())
            FireCustomGameEvent("SetGold", { v: v })
            SetGoldDialog.close()
        }
    })

    RoshanUpgradeRateDialog = new FiveDialog({
        el: $("#RoshanUpgradeRateDialog"),
        title: '设置Roshan升级间隔',
        defaultValue: 240,
        content: '单位为秒',
        ok: function () {
            let v = RoshanUpgradeRateDialog.getinput()
            FireCustomGameEvent('SendToServerConsole', { command: 'dota_roshan_upgrade_rate ' + v })
            RoshanUpgradeRateDialog.close()
        }
    })

    ShowRangeDialog = new FiveDialog({
        el: $("#ShowRangeDialog"),
        title: '显示作用范围',
        defaultValue: 0,
        content: '设置为0取消',
        ok: function () {
            let v = ShowRangeDialog.getinput()
            FireCustomGameEvent('SendToServerConsole', { command: 'dota_range_display ' + v })
            ShowRangeDialog.close()
        }
    })

    HostTimescaleDialog = new FiveDialog({
        el: $("#HostTimescaleDialog"),
        title: '设置游戏速度',
        defaultValue: 1,
        content: '建议范围0~8，支持小数。',
        ok: function () {
            let v = HostTimescaleDialog.getinput()
            FireCustomGameEvent('SendToServerConsole', { command: 'host_timescale ' + v })
            HostTimescaleDialog.close()
        }
    })

    GameEvents.Subscribe("ToHeroKVByName", ToHeroKVByName)
    GameEvents.Subscribe("ToHeroKVById", ToHeroKVById)
    GameEvents.Subscribe("ToAbilityKVByName", ToAbilityKVByName)

    GameEvents.Subscribe("AddAbilitySuccess", getLocalHeroAbility)
    GameEvents.Subscribe("SwapAbilitySuccess", getLocalHeroAbility)

    GameEvents.Subscribe("WaTuDou", WaTuDou)

    $("#easyBuy").checked = true
    FireToggleEvent('easyBuy')


    $("#heroFastRespawn").checked = true
    FireToggleEvent('heroFastRespawn')

    $("#heroSituRespawn").checked = true
    FireToggleEvent('heroSituRespawn')

    $.RegisterEventHandler('DOTAUIHeroPickerHeroSelected', $('#SelectAbilityContainer'), SwitchToNewHero)

    GameUI.SelectAbilityContainer = $('#SelectAbilityContainer')
    GameUI.SelectUnitContainer = $('#SelectUnitContainer')

    // 初始化更换技能面板
    for (let i = 0; i < 36; i++) {
        addAbilityPanel = $.CreatePanel('Panel', $("#SelectAbilityAdd"), '')
        addAbilityPanel.AddClass('addAbilityPanel')
        addAbilityPanel.BLoadLayoutSnippet('addAbilityContainer')
        addAbilityPanel.visible = false

        existingAbilityPanel = $.CreatePanel('Panel', $("#SelectAbilityExisting"), '')
        existingAbilityPanel.AddClass('existingAbilityPanel')
        existingAbilityPanel.BLoadLayoutSnippet('existingAbilityContainer')
        existingAbilityPanel.visible = false
        RegisterSlotEvent(existingAbilityPanel)

        existingAbilityPanel2 = $.CreatePanel('Panel', $("#SelectAbilityExisting2"), '')
        existingAbilityPanel2.AddClass('existingAbilityPanel')
        existingAbilityPanel2.BLoadLayoutSnippet('existingAbilityContainer2')
        existingAbilityPanel2.visible = false

    }

})();

var v2Schedule = null
var v2ThinkStatus = false
var ShowKVSchedule = null
var ShowKVThinkStatus = false
var heroInfo = null
var prevEnt = null
var currentAction = null
var prevAction = null
var replaceHeroId = null
var prevAbilityname = null

var arrowParticle = null
var mtpSchedule = null
var mtpThinkStatus = false
var watudou = false

function WaTuDou() {
    if (watudou) {
        watudou = false
    } else {
        watudou = true
    }
}

function MoveToPoint() {
    GameUI.MouseClickListen = true
    GameUI.MouseClickStatus = 'MoveToPoint'

    var entindex = Players.GetLocalPlayerPortraitUnit()

    if (arrowParticle != null) {
        Particles.DestroyParticleEffect(arrowParticle, true)
        Particles.ReleaseParticleIndex(arrowParticle);
    }
    arrowParticle = Particles.CreateParticle("particles/ui/selection/selection_grid_drag.vpcf", ParticleAttachment_t.PATTACH_ABSORIGIN_FOLLOW, entindex);

    const origin = Entities.GetAbsOrigin(entindex);

    origin[2] += 50;
    Particles.SetParticleControl(arrowParticle, 4, origin);

    Particles.SetParticleAlwaysSimulate(arrowParticle);

    MoveToParticlesThink()
}

function MoveToParticlesThink() {
    var entindex = Players.GetLocalPlayerPortraitUnit()
    if (GameUI.MouseClickListen) {
        var coordinates = GameUI.GetScreenWorldPosition(GameUI.GetCursorPosition())

        const origin = Entities.GetAbsOrigin(entindex)
        origin[2] += 50;
        Particles.SetParticleControl(arrowParticle, 4, origin);
        Particles.SetParticleControl(arrowParticle, 5, coordinates)
        Particles.SetParticleControl(arrowParticle, 2, [128, 128, 128]);

        mtpSchedule = $.Schedule(0, MoveToParticlesThink)
    } else {
        Particles.DestroyParticleEffect(arrowParticle, true)
        Particles.ReleaseParticleIndex(arrowParticle);

        Particles.CreateParticle("particles/units/heroes/hero_antimage/antimage_blink_end_b.vpcf", ParticleAttachment_t.PATTACH_ABSORIGIN_FOLLOW, entindex);

    }
}

function ControlPanelCloseButton() {
    $("#toolPanelContainer").AddClass('Minimized')
}

function MouseOverRune(strRuneID, strRuneTooltip) {
    var runePanel = $('#' + strRuneID);
    runePanel.StartAnimating();
    // 触发ToolTip
    $.DispatchEvent('UIShowTextTooltip', runePanel, strRuneTooltip);
}

function MouseOutRune(strRuneID) {
    var runePanel = $('#' + strRuneID);
    runePanel.StopAnimating();
    // 触发ToolTip
    $.DispatchEvent('UIHideTextTooltip', runePanel);
}

function ReplaceHero() {
    currentAction = 'ReplaceHero'
    ToggleHeroPicker()
}

function AddHero(isFriend) {
    if (isFriend) {
        currentAction = 'AddHeroIsFriend'
    } else {
        currentAction = 'AddHeroIsEnemy'
    }

    ToggleHeroPicker()
}

function AddUnit(isFriend) {
    if (isFriend) {
        currentAction = 'AddUnitIsFriend'
    } else {
        currentAction = 'AddUnitIsEnemy'
    }

    ToggleUnitPicker()
}

function ToggleHeroPicker() {
    $('#SelectUnitContainer').RemoveClass('SelectUnitVisible')

    let checked = $('#SelectAbilityContainer').BHasClass('SelectAbilityContainerVisible')

    if (checked && prevAction != currentAction) {
        $('#SelectAbilityContainer').RemoveClass('SelectAbilityContainerVisible')
        $.Schedule(0.2, function () {
            $('#SelectAbilityContainer').AddClass('SelectAbilityContainerVisible')
        })
    } else {
        $('#SelectAbilityContainer').ToggleClass('SelectAbilityContainerVisible')
    }

    GameUI.MouseClickListen = true
    GameUI.MouseClickStatus = 'ToggleHeroPicker'

    if (currentAction == 'ReplaceAbility') {
        if (prevAction != currentAction) {
            if (checked) {
                $.Schedule(0.2, function () {
                    $('#SelectAbilityAdd').visible = true
                    $('#SelectAbilityExisting').visible = true
                })

            } else {
                $('#SelectAbilityAdd').visible = true
                $('#SelectAbilityExisting').visible = true
            }
        }
    } else {
        if (checked) {
            $.Schedule(0.2, function () {
                $('#SelectAbilityAdd').visible = false
                $('#SelectAbilityExisting').visible = false
            })
        } else {
            $('#SelectAbilityAdd').visible = false
            $('#SelectAbilityExisting').visible = false
        }
    }

    prevAction = currentAction
}

function ToggleUnitPicker() {
    $('#SelectAbilityContainer').RemoveClass('SelectAbilityContainerVisible');
    $('#SelectUnitContainer').ToggleClass('SelectUnitVisible');
    GameUI.MouseClickListen = true
    GameUI.MouseClickStatus = 'ToggleUnitPicker'
}

function ReplaceAbility() {
    currentAction = 'ReplaceAbility'

    getLocalHeroAbility()
    ToggleHeroPicker()
}

function getLocalHeroAbility() {
    let playerId = Players.GetLocalPlayer()
    replaceHeroId = Players.GetSelectedEntities(playerId)[0]

    let AbilityCount = Entities.GetAbilityCount(replaceHeroId)

    for (let i = 0; i < AbilityCount; i++) {
        let abilityid = Entities.GetAbility(replaceHeroId, i)
        let abilityPanel = $("#SelectAbilityExisting").GetChild(i)
        if (!Abilities.IsDisplayedAbility(abilityid)) {
            abilityPanel.visible = false
        } else {
            let abilityButton = abilityPanel.GetChild(0)
            let abilityImg = abilityButton.GetChild(0)

            let abilityname = Abilities.GetAbilityName(abilityid)

            abilityButton.abilityname = abilityname
            abilityImg.contextEntityIndex = abilityid

            if (abilityname.indexOf('special_bonus_') >= 0 || abilityname == "generic_hidden" || abilityname == "") {
                abilityPanel.visible = false
            } else {
                abilityPanel.visible = true
                abilityImg.SetPanelEvent("onmouseover", function () {
                    $.DispatchEvent("DOTAShowAbilityTooltip", abilityImg, abilityname)
                })
                abilityImg.SetPanelEvent("onmouseout", function () {
                    $.DispatchEvent("DOTAHideAbilityTooltip")
                })
                abilityButton.SetPanelEvent("onactivate", function () {
                    abilityPanel.visible = false
                    RemoveAbility(abilityname)
                })
            }
        }
    }
}

function AddAbility(abilityname) {
    let data = {
        replaceHeroId: replaceHeroId,
        abilityName: abilityname
    }
    FireCustomGameEvent('AddAbility', data)

}

function RemoveAbility(abilityname) {
    let data = {
        replaceHeroId: replaceHeroId,
        abilityName: abilityname
    }
    FireCustomGameEvent('RemoveAbility', data)
}

function CreateUnit(unit) {
    $('#SelectUnitContainer').RemoveClass('SelectUnitVisible');

    if (currentAction == 'AddUnitIsFriend') {
        FireCustomGameEvent('CreateUnit', { unit: unit, isFriend: true })
    }
    if (currentAction == 'AddUnitIsEnemy') {
        FireCustomGameEvent('CreateUnit', { unit: unit, isFriend: false })
    }
}

function SwitchToNewHero(heroId) {
    if (currentAction == 'ReplaceHero') {
        FireCustomGameEvent('ReplaceHero', { heroId: heroId })
        $('#SelectAbilityContainer').RemoveClass('SelectAbilityContainerVisible');
    }
    if (currentAction == 'AddHeroIsFriend') {
        FireCustomGameEvent('AddHero', { heroId: heroId, isFriend: true })
        $('#SelectAbilityContainer').RemoveClass('SelectAbilityContainerVisible');
    }
    if (currentAction == 'AddHeroIsEnemy') {
        FireCustomGameEvent('AddHero', { heroId: heroId, isFriend: false })
        $('#SelectAbilityContainer').RemoveClass('SelectAbilityContainerVisible');
    }
    if (currentAction == 'ReplaceAbility') {
        FireCustomGameEvent('GetHeroKVByHeroId', { heroId: heroId })
    }
}

function ToHeroKVById(data) {
    let HeroKVById = data.data

    for (let i = 0; i < 32; i++) {
        let tempAbility = HeroKVById['Ability' + (i + 1)]
        let abilityPanel = $("#SelectAbilityAdd").GetChild(i)
        if (tempAbility != undefined) {
            if (tempAbility.indexOf('special_bonus_') == -1 && tempAbility != 'generic_hidden') {
                let abilityButton = abilityPanel.GetChild(0)
                let abilityImg = abilityButton.GetChild(0)

                abilityButton.abilityname = tempAbility
                abilityImg.abilityname = tempAbility
                abilityPanel.visible = true
                abilityImg.SetPanelEvent("onmouseover", function () {
                    $.DispatchEvent("DOTAShowAbilityTooltip", abilityImg, tempAbility)
                })
                abilityImg.SetPanelEvent("onmouseout", function () {
                    $.DispatchEvent("DOTAHideAbilityTooltip")
                })
                abilityButton.SetPanelEvent("onactivate", function () {
                    AddAbility(tempAbility)
                })
            } else {
                abilityPanel.visible = false
            }
        } else {
            abilityPanel.visible = false
        }
    }
}

function showDetail() {
    let checked = $('#showDetail').checked
    if (checked) {
        $("#entTextPanelContainer").RemoveClass('Minimized')
        ShowKVCloseButton()
        let ent = Players.GetLocalPlayerPortraitUnit()
        FireCustomGameEvent('GetHeroInfoStart', { ent: ent })
        entTextThink()
    } else {
        entTextTitlePanelCloseButton()
    }
}

function entTextTitlePanelCloseButton() {
    $("#showDetail").checked = false
    $("#entTextPanelContainer").AddClass('Minimized')
    if (v2ThinkStatus) {
        $.CancelScheduled(v2Schedule)
        v2ThinkStatus = false
    }
    FireCustomGameEvent('GetHeroInfoEnd', {})
}

function showKV() {
    let checked = $('#showKV').checked
    if (checked) {
        $("#ShowKVContainer").RemoveClass('Minimized')
        entTextTitlePanelCloseButton()

        ShowKVThink()
    } else {
        ShowKVCloseButton()
    }
}

function ShowKVCloseButton() {
    $("#showKV").checked = false
    $("#ShowKVContainer").AddClass('Minimized')
    if (ShowKVThinkStatus) {
        $.CancelScheduled(ShowKVSchedule)
        ShowKVThinkStatus = false
    }
}

function ShowKVThink() {
    let ThinkInterval = 0
    ShowKVThinkStatus = true

    let ent = Players.GetLocalPlayerPortraitUnit()

    if (ent != prevEnt) {
        prevEnt = ent
        let unitName = Entities.GetUnitName(ent)
        if (Entities.IsHero(ent)) {
            FireCustomGameEvent('GetHeroKVByHeroName', { unitName: unitName })
        } else {
            FireCustomGameEvent('GetUnitKVByUnitName', { unitName: unitName })
        }

    }

    ShowKVSchedule = $.Schedule(ThinkInterval, ShowKVThink)
}

function ToHeroKVByName(data) {
    let HeroKVByName = data.data

    let ordered = {}
    Object.keys(HeroKVByName).sort().forEach(function (key) {
        ordered[key] = HeroKVByName[key];
    })

    $("#ShowKVText").BLoadLayout("", false, false)

    let entTextPanelCowCenter = $.CreatePanel('Label', $("#ShowKVText"), '')
    entTextPanelCowCenter.AddClass('ShowKVPanelCowCenter')
    entTextPanelCowCenter.text = Entities.GetUnitName(prevEnt)

    for (let key in ordered) {
        CreateShowKVPanel(key, HeroKVByName[key], $("#ShowKVText"))
    }

}

function showAbilityKV() {
    $('#showKV').checked = true
    $("#ShowKVContainer").RemoveClass('Minimized')
    entTextTitlePanelCloseButton()
}

function ToAbilityKVByName(data) {
    showAbilityKV()
    let AbilityKVByName = data.data

    let ordered = {}
    Object.keys(AbilityKVByName).sort().forEach(function (key) {
        ordered[key] = AbilityKVByName[key];
    })

    $("#ShowKVText").BLoadLayout("", false, false)

    let entTextPanelCowCenter = $.CreatePanel('Label', $("#ShowKVText"), '')
    entTextPanelCowCenter.AddClass('ShowKVPanelCowCenter')
    entTextPanelCowCenter.text = prevAbilityname

    for (let key in ordered) {
        CreateShowKVPanel(key, AbilityKVByName[key], $("#ShowKVText"))
    }

}

function CreateShowKVPanel(k, v, panel) {
    if (typeof (v) == 'object') {
        let entTextPanelRow = $.CreatePanel('Panel', panel, '')
        entTextPanelRow.AddClass('entTextPanelRowisObject')
        let entTextPanelCow = $.CreatePanel('Panel', entTextPanelRow, '')
        entTextPanelCow.AddClass('entTextPanelCow')
        let entTextPanelCowCenter = $.CreatePanel('Label', entTextPanelCow, '')
        entTextPanelCowCenter.AddClass('ShowKVPanelCowCenter')
        entTextPanelCowCenter.text = k
        for (let key in v) {
            CreateShowKVPanel(key, v[key], entTextPanelRow)
        }
    } else {
        let entTextPanelRow = $.CreatePanel('Panel', panel, '')
        entTextPanelRow.AddClass('entTextPanelRow')
        let entTextPanelCow = $.CreatePanel('Panel', entTextPanelRow, '')
        entTextPanelCow.AddClass('entTextPanelCow')
        let entTextPanelCowLeft = $.CreatePanel('Label', entTextPanelCow, '')
        entTextPanelCowLeft.AddClass('ShowKVPanelCowLeft')
        entTextPanelCowLeft.text = k
        let entTextPanelCowRight = $.CreatePanel('Label', entTextPanelCow, '')
        entTextPanelCowRight.AddClass('ShowKVPanelCowRight')
        entTextPanelCowRight.text = v
    }
}

function entTextThink() {
    let ThinkInterval = 0
    v2ThinkStatus = true

    let ent = Players.GetLocalPlayerPortraitUnit()

    if (ent != prevEnt) {
        heroInfo = null
        prevEnt = ent
        FireCustomGameEvent('GetHeroInfoStart', { ent: ent })
    }

    UpdateBuffs(ent)
    UpdateAbility(ent)

    heroInfo = CustomNetTables.GetTableValue("heroInfo", "entText")

    if (ent) {
        $("#entId").text = ent
        $("#GetUnitName").text = Entities.GetUnitName(ent)

        let tempAbsOrigin = Entities.GetAbsOrigin(ent).toString().split(',')
        if (watudou) {
            $("#GetAbsOrigin").text = tempAbsOrigin[0] + ' \n ' + tempAbsOrigin[1] + ' \n ' + tempAbsOrigin[2]
        } else {
            $("#GetAbsOrigin").text = parseFloat(tempAbsOrigin[0]).toFixed(2) + ' | ' + parseFloat(tempAbsOrigin[1]).toFixed(2) + ' | ' + parseFloat(tempAbsOrigin[2]).toFixed(2)
        }

        $("#GetDayTimeVisionRange").text = Entities.GetDayTimeVisionRange(ent)
        $("#GetNightTimeVisionRange").text = Entities.GetNightTimeVisionRange(ent)
        $("#GetBaseAttackTime").text = Entities.GetBaseAttackTime(ent).toFixed(2)
        $("#GetAttackSpeed").text = (Entities.GetAttackSpeed(ent) * 100).toFixed(0)
        $("#GetAttacksPerSecond").text = Entities.GetAttacksPerSecond(ent).toFixed(2)
        $("#GetHullRadius").text = Entities.GetHullRadius(ent).toFixed(2)
        $("#GetPaddedCollisionRadius").text = Entities.GetPaddedCollisionRadius(ent).toFixed(2)
        // $("#GetProjectileCollisionSize").text = Entities.GetProjectileCollisionSize(ent).toFixed(2)
        // $("#GetRingRadius").text = Entities.GetRingRadius(ent)
        $("#GetClassNameAsCStr").text = Entities.GetClassNameAsCStr(ent)
        if (heroInfo != null) {
            $("#GetAttackAnimationPoint").text = heroInfo.GetAttackAnimationPoint.toFixed(2)
            $("#GetCooldownReduction").text = heroInfo.GetCooldownReduction.toFixed(2)
            $("#GetCastPoint").text = heroInfo.GetCastPoint.toFixed(2)
            $("#GetIdealSpeed").text = heroInfo.GetIdealSpeed.toFixed(0)
            $("#GetProjectileSpeed").text = heroInfo.GetProjectileSpeed.toFixed(0)
            let tempAbsOrigin2 = heroInfo.GetAbsOrigin.split(' ')
            if (watudou) {
                $("#GetAbsOrigin2").text = tempAbsOrigin2[0] + ' \n ' + tempAbsOrigin2[1] + ' \n ' + tempAbsOrigin2[2]
                $("#GetAbsOrigin3").text = (Number(tempAbsOrigin[0]) - Number(tempAbsOrigin2[0])) + ' \n ' + (Number(tempAbsOrigin[1]) - Number(tempAbsOrigin2[1])) + ' \n ' + (Number(tempAbsOrigin[2]) - Number(tempAbsOrigin2[2]))
                $('#GetAbsOrigin3Box').style.visibility = "visible";
            } else {
                $("#GetAbsOrigin2").text = parseFloat(tempAbsOrigin2[0]).toFixed(2) + ' | ' + parseFloat(tempAbsOrigin2[1]).toFixed(2) + ' | ' + parseFloat(tempAbsOrigin2[2]).toFixed(2)
                $('#GetAbsOrigin3Box').style.visibility = "collapse";
            }

            $("#GetAverageTrueAttackDamage").text = heroInfo.GetAverageTrueAttackDamage
            $("#GetDamage").text = heroInfo.GetBaseDamageMin + ' - ' + heroInfo.GetBaseDamageMax
            $("#GetPhysicalArmorValue").text = heroInfo.GetPhysicalArmorValue.toFixed(2)
            $("#GetMagicalArmorValue").text = (heroInfo.GetMagicalArmorValue * 100).toFixed(2) + '%'
        } else {
            $("#GetAttackAnimationPoint").text = '-'
            $("#GetCooldownReduction").text = '-'
            $("#GetCastPoint").text = '-'
            $("#GetIdealSpeed").text = '-'
            $("#GetProjectileSpeed").text = '-'
            $("#GetAbsOrigin2").text = '-'
            $("#GetAbsOrigin3").text = '-'
            $("#GetAverageTrueAttackDamage").text = '-'
            $("#GetDamage").text = '-'
            $("#GetPhysicalArmorValue").text = '-'
            $("#GetMagicalArmorValue").text = '-'
        }
    }

    v2Schedule = $.Schedule(ThinkInterval, entTextThink)

}

function UpdateBuffs(unit) {

    var nBuffs = Entities.GetNumBuffs(unit);
    var BuffList = $("#BuffList");

    $("#BuffList").BLoadLayout("", false, false)

    for (var i = 0; i < nBuffs; i++) {
        var buffSerial = Entities.GetBuff(unit, i);
        if (buffSerial == -1)
            continue;

        let buffPanel = $.CreatePanel('Panel', BuffList, '');
        buffPanel.AddClass('entTextPanelRow')
        let buffLabel = $.CreatePanel('Label', buffPanel, '');
        buffLabel.AddClass('entTextPanelCowRight')
        let buffLabelText = "";
        let buffName = Buffs.GetName(unit, buffSerial);
        buffLabelText += buffName;
        let GetStackCount = Buffs.GetStackCount(unit, buffSerial);
        if (GetStackCount > 0) {
            buffLabelText += " (" + GetStackCount + ")";
        }
        let GetDuration = Buffs.GetDuration(unit, buffSerial);
        // let GetDieTime = Buffs.GetDieTime(unit, buffSerial).toFixed(2);
        let GetRemainingTime = Buffs.GetRemainingTime(unit, buffSerial).toFixed(2);
        // let GetElapsedTime = Buffs.GetElapsedTime(unit, buffSerial).toFixed(2);
        // let GetCreationTime = Buffs.GetCreationTime(unit, buffSerial).toFixed(2);

        if (GetDuration > 0) {
            buffLabelText += " | " + GetRemainingTime;
        }

        // let GetCaster = Buffs.GetCaster(unit, buffSerial);
        // let GetParent = Buffs.GetParent(unit, buffSerial);
        // let GetAbility = Buffs.GetAbility(unit, buffSerial);
        buffLabel.text = buffLabelText
    }

}

function UpdateAbility(ent) {
    let AbilityCount = Entities.GetAbilityCount(ent)
    for (let i = 0; i < AbilityCount; i++) {
        let abilityid = Entities.GetAbility(ent, i)
        let abilityPanel = $("#SelectAbilityExisting2").GetChild(i)
        if (abilityid == -1) {
            abilityPanel.visible = false
        } else {

            let abilityImg = abilityPanel.GetChild(0)
            let abilityname = Abilities.GetAbilityName(abilityid)

            abilityImg.contextEntityIndex = abilityid

            if (abilityname.indexOf('special_bonus_') >= 0 || abilityname == "generic_hidden" || abilityname == "") {
                abilityPanel.visible = false
            } else {
                abilityPanel.visible = true
                abilityImg.SetPanelEvent("onmouseover", function () {
                    $.DispatchEvent("DOTAShowAbilityTooltip", abilityImg, abilityname)
                })
                abilityImg.SetPanelEvent("onmouseout", function () {
                    $.DispatchEvent("DOTAHideAbilityTooltip")
                })
                abilityImg.SetPanelEvent("onactivate", function () {
                    prevAbilityname = abilityname
                    FireCustomGameEvent('GetAblityKVByAblityName', { abilityName: abilityname })
                })
            }
        }
    }
}

// 注册拖拽事件
function RegisterSlotEvent(slot) {
    slot.SetDraggable(true);
    $.RegisterEventHandler('DragEnter', slot, OnDragEnter);
    $.RegisterEventHandler('DragDrop', slot, OnDragDrop);
    $.RegisterEventHandler('DragLeave', slot, OnDragLeave);
    $.RegisterEventHandler('DragStart', slot, OnDragStart);
    $.RegisterEventHandler('DragEnd', slot, OnDragEnd);
}

// 开始拖动
// panel 被拖动的那个DOTAItemImage
// draggedPanel 拖出来的东西
function OnDragStart(panel, draggedPanel) {
    $.Msg('OnDragStart')
    $.DispatchEvent("DOTAHideAbilityTooltip")

    var displayPanel = $.CreatePanel("DOTAAbilityImage", panel, "")
    displayPanel.abilityname = panel.GetChild(0).GetChild(0).abilityname

    draggedPanel.displayPanel = displayPanel;
    draggedPanel.offsetX = 0
    draggedPanel.offsetY = 0
}

// 拖动进入某个区域
// panel 进入的板
// draggedPanel 拖动的板
function OnDragEnter(panel, draggedPanel) {
    $.Msg('OnDragEnter')
}

// 拖动离开某个区域
// panel 离开的板 如果拖动结束，在拖动事件中离开的板已经被变成新的物品了
// draggedPanel 拖动的板
function OnDragLeave(panel, draggedPanel) {
    $.Msg('OnDragLeave')
}

// 松开拖动
// panel 松开时候指向的板
// draggedPanel 拖动的板
// caster 拖动的物品 target 交换的物品
function OnDragDrop(panel, draggedPanel) {
    $.Msg('OnDragDrop')
    if (panel.paneltype == 'DOTAAbilityImage') {
        FireCustomGameEvent('SwapAbility', { replaceHeroId: replaceHeroId, ability1: panel.abilityname, ability2: draggedPanel.abilityname })
    }

}

// 拖动结束
// panel 最初的板
// draggedPanel 拖动的板
function OnDragEnd(panel, draggedPanel) {
    $.Msg('OnDragEnd')
    draggedPanel.DeleteAsync(0)
}



GameEvents.Subscribe("UpdateServerStatus", UpdateServerStatus);

function UpdateServerStatus(data) {
    if (data.data == 1) {
        $('#' + data.name).checked = true
    } else {
        $('#' + data.name).checked = false
    }
}