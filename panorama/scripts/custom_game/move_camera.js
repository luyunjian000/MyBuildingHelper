function MoveCamera(data) {
    $.Msg(data);
    var cameraTarget = [];
    if (data.unitTargetEntIndex) {
        cameraTarget = Entities.GetAbsOrigin(data.unitTargetEntIndex)
    } else if (data.cameraTarget) {
        var cameraTargetString = data.cameraTarget.split(" ");
        cameraTarget[0] = parseFloat(cameraTargetString[0]);
        cameraTarget[1] = parseFloat(cameraTargetString[1]);
        cameraTarget[2] = parseFloat(cameraTargetString[2]);
    }
    GameUI.SetCameraTargetPosition(cameraTarget, data.lerp);
}

function SetCamera(data) {
    $.Msg(data);
    GameUI.MoveCameraToEntity(data.target);
}

function CameraLookat(data) {
    $.Msg(data);
    GameUI.SetCameraTarget(data.target);
}

function SelectUnit(data) {
    if (data.single) {
        GameUI.SelectUnit(data.target, false);
    } else {
        GameUI.SelectUnit(data.target, true);
    }
}

(function() {
    GameEvents.Subscribe("move_camera", MoveCamera);
    GameEvents.Subscribe("set_camera", SetCamera);
    GameEvents.Subscribe("camera_lookat", CameraLookat);
    GameEvents.Subscribe("select_unit", SelectUnit);

})();