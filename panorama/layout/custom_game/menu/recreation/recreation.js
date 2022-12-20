var SelectHeroList = [
    "legion_commander",
    "skeleton_king",
    "centaur",
    "tiny",
    "axe",
    "slardar",
    "sven",
    "sand_king",
    "tidehunter",
    "marci",
    "huskar",
    "magnataur",
    "riki",
    "nyx_assassin",
    "dazzle",
    "lina",
    "lion",
    "windrunner",
    "vengefulspirit",
    "ogre_magi",
    "earth_spirit",
    "tusk",
    "pudge",
    "kunkka",
    "chaos_knight",
    "alchemist",
    "primal_beast",
    "mars",
    "dragon_knight",
    "hoodwink",
    "faceless_void",
    "earthshaker",
    "disruptor"
];

(function () {

    GameUI.HideSkillOptionDialog = $('#HideSkillOptionDialog')
    GameUI.AddWoodenStakeDialog = $('#AddWoodenStakeDialog')
    GameUI.recreationPanelContainer = $("#recreationPanelContainer")
    GameUI.LeaderboardPanel = $("#LeaderboardPanel")

    $("#HideSkillHeroCategory").BLoadLayout("", false, false)
    for (var i = 0; i < SelectHeroList.length; i++) {
        let SelectHeroCategoryImgPanel = $.CreatePanel('Panel', $("#HideSkillHeroCategory"), '')
        SelectHeroCategoryImgPanel.BLoadLayoutSnippet('SelectHeroCategoryImgPanel')
        let SelectHeroCategoryImg = SelectHeroCategoryImgPanel.GetChild(0)
        SelectHeroCategoryImg.heroname = "npc_dota_hero_" + SelectHeroList[i]
        SelectHeroCategoryImg.checked = 1
        SelectHeroCategoryImgPanel.SetPanelEvent("onactivate", function () {
            if (SelectHeroCategoryImg.checked == 1) {
                SelectHeroCategoryImg.checked = 0
                SelectHeroCategoryImgPanel.GetChild(0).RemoveClass('active')
            } else {
                SelectHeroCategoryImg.checked = 1
                SelectHeroCategoryImgPanel.GetChild(0).AddClass('active')
            }
        })
    }

    $("#invis").GetChild(2).checked = true
    $("#blink").GetChild(2).checked = true
    $("#delay").GetChild(0).checked = true

    GameEvents.Subscribe("SetLeaderboard", SetLeaderboard)
})();

function ControlPanelCloseButton() {
    $("#recreationPanelContainer").AddClass('Minimized')
}

function ShowHideSkillOption() {
    $("#HideSkillOptionDialog").ToggleClass('Minimized')
    $("#AddWoodenStakeDialog").AddClass('Minimized')
    $("#LeaderboardPanel").AddClass('Minimized')
    GameUI.MouseClickListen = true
    GameUI.MouseClickStatus = ""
}

function ShowAddWoodenStake() {
    $("#AddWoodenStakeDialog").ToggleClass('Minimized')
    $("#HideSkillOptionDialog").AddClass('Minimized')
    $("#LeaderboardPanel").AddClass('Minimized')
    GameUI.MouseClickListen = true
    GameUI.MouseClickStatus = ""
}

function ShowLeaderboard() {
    $("#LeaderboardPanel").ToggleClass('Minimized')
    $("#HideSkillOptionDialog").AddClass('Minimized')
    $("#AddWoodenStakeDialog").AddClass('Minimized')
    if (!$("#LeaderboardPanel").BHasClass('Minimized')) {
        FireCustomGameEvent('GetLeaderboard', {})
    }

    GameUI.MouseClickListen = true
    GameUI.MouseClickStatus = ""
}

function SetLeaderboard(data) {
    $('#LeaderboardContainer').BLoadLayout("", false, false)

    let Leaderboard = data.data
    let i = 1
    for (element in Leaderboard) {
        LeaderboardSinglePanel = $.CreatePanel('Panel', $('#LeaderboardContainer'), '');
        LeaderboardSinglePanel.BLoadLayoutSnippet('LeaderboardSingle');
        let score = Leaderboard[element].bestResults
        score != null ? score = score : score = 0
        LeaderboardSinglePanel.FindChildTraverse('rank').text = i
        LeaderboardSinglePanel.FindChildTraverse('avatar').accountid = Leaderboard[element].dotaid
        LeaderboardSinglePanel.FindChildTraverse('username').accountid = Leaderboard[element].dotaid
        LeaderboardSinglePanel.FindChildTraverse('score').text = score.toFixed(2) + 's'
        i++
    }
}

function SelectHeroCategoryImgSelectAll() {
    let SelectHeroCategoryImgList = $("#HideSkillHeroCategory")
    for (var i = 0; i < SelectHeroCategoryImgList.GetChildCount(); i++) {
        let SelectHeroCategoryImg = SelectHeroCategoryImgList.GetChild(i).GetChild(0)
        SelectHeroCategoryImg.checked = 1
        SelectHeroCategoryImg.AddClass('active')
    }
}

function SelectHeroCategoryImgSelectBack() {
    let SelectHeroCategoryImgList = $("#HideSkillHeroCategory")
    for (var i = 0; i < SelectHeroCategoryImgList.GetChildCount(); i++) {
        let SelectHeroCategoryImg = SelectHeroCategoryImgList.GetChild(i).GetChild(0)
        if (SelectHeroCategoryImg.checked == 1) {
            SelectHeroCategoryImg.checked = 0
            SelectHeroCategoryImg.RemoveClass('active')
        } else {
            SelectHeroCategoryImg.checked = 1
            SelectHeroCategoryImg.AddClass('active')
        }
    }
}

function HideSkillOptionOk() {
    let data = {}
    let invisRadioButton = $("#invis").GetChild(0)
    let blinkRadioButton = $("#blink").GetChild(0)
    let delayRadioButton = $("#delay").GetChild(0)
    data.invis = invisRadioButton.GetSelectedButton().tabindex
    data.blink = blinkRadioButton.GetSelectedButton().tabindex
    data.delay = delayRadioButton.GetSelectedButton().tabindex
    let SelectHeroCategoryImgList = $("#HideSkillHeroCategory")
    for (var i = 0; i < SelectHeroCategoryImgList.GetChildCount(); i++) {
        let SelectHeroCategoryImg = SelectHeroCategoryImgList.GetChild(i).GetChild(0)
        data[SelectHeroCategoryImg.heroname] = SelectHeroCategoryImg.checked
    }

    FireCustomGameEvent('HideSkillOption', data)
    $("#HideSkillOptionDialog").AddClass('Minimized')
}

function HideSkillOptionReset() {
    SelectHeroCategoryImgSelectAll()
    $("#invis").GetChild(2).checked = true
    $("#blink").GetChild(2).checked = true
    $("#delay").GetChild(0).checked = true
}

function HideSkillOptionCancel() {
    $("#HideSkillOptionDialog").AddClass('Minimized')
}

function AddWoodenStake(heroname, abilityName) {
    $('#AddWoodenStakeDialog').AddClass('Minimized');
    FireCustomGameEvent('AddWoodenStake', { heroname: heroname, abilityName: abilityName })
}

function AddWoodenStakeOther(type) {
    $('#AddWoodenStakeDialog').AddClass('Minimized');
    FireCustomGameEvent('AddWoodenStakeOther', { type: type })
}
