GameEvents.Subscribe("display_custom_error", function(msg) {
    GameEvents.SendEventClientSide("dota_hud_error_message", {
        "splitscreenplayer": Players.GetLocalPlayer(),
        "reason": 80,
        "message": msg.message
    });
});