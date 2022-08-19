var mainPanel = $.GetContextPanel().FindChildInLayoutFile("mainPanel");
var pageBtnsPanel = $.GetContextPanel().FindChildInLayoutFile("pageBtns");
var pageBtns = []
for (let i = 0; i < 4; i++) {
    pageBtns.push(pageBtnsPanel.GetChild(i))
}
// var rightBtnsPanel = $.GetContextPanel().FindChildInLayoutFile("rightBtns");
// var rightBtns = []
// for (let i = 0; i < 5; i++) {
//     rightBtns.push(rightBtnsPanel.GetChild(i))
// }

var leaderboard_linesPanel = $.GetContextPanel().FindChildInLayoutFile("leaderboard_lines");


var gLeaderboardData = null

var gPage = 0
var gDiff = 0

gLeaderboardData = CustomNetTables.GetTableValue("leaderboard", "value")
if (gLeaderboardData) {
    gLeaderboardData = JSON.parse(gLeaderboardData.v)
}
CustomNetTables.SubscribeNetTableListener("leaderboard", function() {
    const str = CustomNetTables.GetTableValue("leaderboard", "value").v
    gLeaderboardData = JSON.parse(str)

    Update()
})



function onClickLeaderboard() {
    mainPanel.RemoveClass("Hidden");
    loadData()
    gPage = 0
    gDiff = 1
    Update()
    $.Msg("onClickLeaderboard")
}

function onCloseBtn() {
    mainPanel.AddClass("Hidden");
}

function onClickPageBtn(page) {
    gPage = page
    Update()
}

function onClickDiffBtn(diff) {
    gDiff = diff
    Update()
}

function ToSteam64(steam32) {
    return "76561" + (197960265728 + steam32);
}

function formatDate(time) {
    var d = new Date(time * 1000);
    var datestring = d.getFullYear() + "/" + ("0" + (d.getMonth() + 1)).slice(-2) + "/" + ("0" + d.getDate()).slice(-2)
        //+ ("0" + d.getHours()).slice(-2) + ":" + ("0" + d.getMinutes()).slice(-2)
    return datestring
}

function Update() {
    $.Msg(gLeaderboardData)
    var iPlayerID = Players.GetLocalPlayer()
    var sPlayerName = Players.GetPlayerName(iPlayerID);
    mainPanel.SetDialogVariable("player_name", sPlayerName)
    if (gLeaderboardData) {
        const pinfo = gLeaderboardData.data.player
        mainPanel.SetDialogVariable("rank_score", gLeaderboardData.data.player.rank)
        const winrate = ((100 * pinfo.match_win / (pinfo.match_count || 1)).toFixed(2))
        mainPanel.SetDialogVariable("player_winrate", winrate + "%")
    } else {
        mainPanel.SetDialogVariable("rank_score", "--")
        mainPanel.SetDialogVariable("player_winrate", "--%")
    }

    for (const pageBtn of pageBtns) {
        pageBtn.AddClass("pageBtnUnselected")
    }
    pageBtns[gPage].RemoveClass("pageBtnUnselected")
        //
        // for (const rightBtn of rightBtns) {
        //     rightBtn.AddClass("rightBtnDisable")
        // }
        // rightBtns[5 - gDiff].RemoveClass("rightBtnDisable")
    leaderboard_linesPanel.RemoveAndDeleteChildren()
    if (gLeaderboardData && gLeaderboardData.data) {

        var players = gLeaderboardData.data.leaderboard
        var playersInPage = players.slice(10 * gPage, 10 * gPage + 10)

        for (let i = 0; i < playersInPage.length; i++) {
            const globalIndex = 10 * gPage + i
            const player = playersInPage[i]
            var newLine = null
            if (globalIndex == 0) {
                newLine = $.CreatePanel("Panel", leaderboard_linesPanel, "");
                newLine.BLoadLayoutSnippet("snippet_topScoreLine");
            } else {
                newLine = $.CreatePanel("Panel", leaderboard_linesPanel, "");
                newLine.BLoadLayoutSnippet("snippet_scoreLine");
            }
            newLine.SetDialogVariable("line_no", "#" + (globalIndex + 1))
            newLine.SetDialogVariable("rank_score", player.rank || 0)
            newLine.SetDialogVariable("player_name", player.playername)
            const winrate = ((100 * player.match_win / (player.match_count || 1)).toFixed(2))
            newLine.SetDialogVariable("winrate", winrate + "%")

            const playerList = newLine.FindChildTraverse("playerList")
            const heroList = newLine.FindChildTraverse("heroList")
            for (let j = 0; j < 4; j++) {
                playerList.GetChild(j).steamid = null
                playerList.GetChild(j).AddClass("Hidden")
            }
            for (let j = 0; j < 1; j++) {
                playerList.GetChild(j).RemoveClass("Hidden")
                playerList.GetChild(j).steamid = ToSteam64(Number(player.steamid))
            }
        }
    }
    //
    $.Msg("update done")


}

function loadData() {
    const pid = Players.GetLocalPlayer()
    GameEvents.SendCustomGameEventToServer("get_leaderboard", { pid: pid });
}


(function() {
    leaderboard_linesPanel.RemoveAndDeleteChildren()
    $.Msg("init")
})();