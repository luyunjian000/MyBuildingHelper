'use strict';

$.Msg( "test!" );

var panel = $.GetContextPanel();
$.Msg(panel);

var topPanel = $.CreatePanel( "Panel", panel, "" );
topPanel.AddClass("topmenu");
topPanel.SetDraggable(true);
$.Msg(topPanel);

// Players.GetMaxPlayers()
for(var i = 1;i <= 4 ;i++) {
    var topPanel2 = $.CreatePanel( "Panel", topPanel, "" );
    topPanel2.AddClass(`topmenuson${i}`);
    topPanel2.BLoadLayout("file://{resources}/layout/custom_game/test2.xml",true,true);
}