GameUI.FiveDialog = []
GameUI.MouseClickListen = false
GameUI.MouseClickStatus = ''

// 鼠标响应
GameUI.SetMouseCallback(function (eventName, arg) {
    if (GameUI.MouseClickListen) {
        switch (GameUI.MouseClickStatus) {
            case 'MoveToPoint':
                if (eventName == "pressed") {
                    // Left-click is move to position,  GameUI.GetClickBehaviors 获取当前 UI 单击交互模式。
                    if (arg === 0 && GameUI.GetClickBehaviors() === 0) {
                        // GameUI.GetScreenWorldPosition 获取屏幕位置的世界位置，如果光标不在世界范围内，则为 null。
                        var coordinates = GameUI.GetScreenWorldPosition(GameUI.GetCursorPosition());
                        if (coordinates != null) {
                            var pos = {
                                x: coordinates[0],
                                y: coordinates[1],
                                z: coordinates[2]
                            }

                            FireCustomGameEvent("MoveTo", { pos });
                            GameUI.MouseClickListen = false
                        }
                    }
                    // 右键
                    if (arg === 1 && GameUI.GetClickBehaviors() === 0) {
                        GameUI.MouseClickListen = false
                    }
                }
                break
            default:
                if (eventName == "pressed") {
                    // Left-click is move to position
                    if (arg === 0 && GameUI.GetClickBehaviors() === 0) {
                        GameUI.SelectAbilityContainer.RemoveClass('SelectAbilityContainerVisible');
                        GameUI.SelectUnitContainer.RemoveClass('SelectUnitVisible');
                        GameUI.AddWoodenStakeDialog.AddClass('Minimized')
                        GameUI.HideSkillOptionDialog.AddClass('Minimized')
                        GameUI.LeaderboardPanel.AddClass('Minimized')
                        GameUI.MouseClickListen = false
                    }
                    // 右键
                    if (arg === 1 && GameUI.GetClickBehaviors() === 0) {

                    }
                }
                break
        }
    }

    return false;
})