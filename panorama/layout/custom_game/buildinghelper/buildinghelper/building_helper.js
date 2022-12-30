'use strict';

GameUI.SetRenderBottomInsetOverride( 0 );

var state = 'disabled';
var frame_rate = 1/30;  // 1/30 原来，这个不知道控制什么的
var tree_update_interval = 1;
var size = 0;
var size_x = 0;
var size_y = 0;
var overlay_size = 0;
var overlay_size_x = 0;
var overlay_size_y = 0;
var range = 0;
var pressedShift = false;
var altDown = false;
var invalid = false;
var requires;
var modelParticle;
var propParticle;
var propScale;
var offsetZ;
var modelOffset;
var gridParticles;
var overlayParticles;
var rangeOverlay;
var rangeOverlayActive;
var builderIndex;
var entityGrid = [];
var tree_entities = [];
var distance_to_gold_mine;
var last_tree_update = Game.GetGameTime();
var treeGrid = [];
var cutTrees = [];
var abilityname = "";
var yaw = -45;

// building_settings.kv options
var grid_alpha = CustomNetTables.GetTableValue( "building_settings", "grid_alpha").value
var alt_grid_alpha = CustomNetTables.GetTableValue( "building_settings", "alt_grid_alpha").value
var alt_grid_squares = CustomNetTables.GetTableValue( "building_settings", "alt_grid_squares").value;
var range_overlay_alpha = CustomNetTables.GetTableValue( "building_settings", "range_overlay_alpha").value
var model_alpha = CustomNetTables.GetTableValue( "building_settings", "model_alpha").value
var recolor_ghost = CustomNetTables.GetTableValue( "building_settings", "recolor_ghost").value;
var turn_red = CustomNetTables.GetTableValue( "building_settings", "turn_red").value;
var permanent_alt_grid = CustomNetTables.GetTableValue( "building_settings", "permanent_alt_grid").value;
var update_trees = CustomNetTables.GetTableValue( "building_settings", "update_trees").value;

var height_restriction
if (CustomNetTables.GetTableValue( "building_settings", "height_restriction") !== undefined)
    height_restriction = CustomNetTables.GetTableValue( "building_settings", "height_restriction").value;

var GRID_TYPES = CustomNetTables.GetTableValue( "building_settings", "grid_types")
CustomNetTables.SubscribeNetTableListener( "building_settings", function() {
    GRID_TYPES = CustomNetTables.GetTableValue( "building_settings", "grid_types")
})

var Root = $.GetContextPanel()
var localHeroIndex

if (! Root.loaded)
{
    Root.GridNav = [];
    Root.squareX = 0;
    Root.squareY = 0;
    Root.loaded = true;
}

function StartBuildingHelper( params )
{   
    if (params !== undefined)
    {
        // 设置AddBuilding传递的参数
        localHeroIndex = Players.GetPlayerHeroEntityIndex( Players.GetLocalPlayer() );
        state = params.state;
        // 设置的3
        // size = params.size;
        size_x = params.size_x;
        size_y = params.size_y;
        //$.Msg("size_x=="+size_x+";size_y=="+size_y)
        range = params.range;
        // 定义要在建筑结构尺寸的每一侧创建的小正方形数 设置的 6
        //overlay_size = size + alt_grid_squares * 2;
        overlay_size_x = size_x + alt_grid_squares * 2;
        overlay_size_y = size_y + alt_grid_squares * 2;
        builderIndex = params.builderIndex;
        var scale = params.scale;
        var entindex = params.entindex; //建筑单位的index把
        var propScale = params.propScale;
        offsetZ = params.offsetZ;
        modelOffset = params.modelOffset;
        abilityname = params.abilityname;

        requires = GetRequiredGridType(entindex)
        
        distance_to_gold_mine = HasGoldMineDistanceRestriction(entindex)
        // 如果我们选择不重新激活幽灵模型，请将其设置为白色
        var ghost_color = [0, 255, 0] // 绿色
        if (!recolor_ghost)
            ghost_color = [255,255,255]
  
        pressedShift = GameUI.IsShiftDown();

        if (modelParticle !== undefined) {
            Particles.DestroyParticleEffect(modelParticle, true)
            // Release 释放
            Particles.ReleaseParticleIndex(modelParticle)
        }
        if (propParticle !== undefined) {
            Particles.DestroyParticleEffect(propParticle, true)
            Particles.ReleaseParticleIndex(propParticle)
        }
        if (gridParticles !== undefined) {
            for (var i in gridParticles) {
                Particles.DestroyParticleEffect(gridParticles[i], true)
                Particles.ReleaseParticleIndex(gridParticles[i])
            }
        }
        if (overlayParticles !== undefined) {
            for (var i in overlayParticles) {
                Particles.DestroyParticleEffect(overlayParticles[i], true)
                Particles.ReleaseParticleIndex(overlayParticles[i])
            }
        }
        if (rangeOverlay !== undefined) {
            Particles.DestroyParticleEffect(rangeOverlay, true)
            Particles.ReleaseParticleIndex(rangeOverlay)
        }

        // Building Ghost
        modelParticle = Particles.CreateParticle("particles/buildinghelper/ghost_model.vpcf", ParticleAttachment_t.PATTACH_CUSTOMORIGIN, 0);
        Particles.SetParticleControlEnt(modelParticle, 1, entindex, ParticleAttachment_t.PATTACH_ABSORIGIN_FOLLOW, "follow_origin", Entities.GetAbsOrigin(entindex), true)
        Particles.SetParticleControl(modelParticle, 2, ghost_color)
        Particles.SetParticleControl(modelParticle, 3, [model_alpha,0,0])
        Particles.SetParticleControl(modelParticle, 4, [scale,0,0])

        // Grid squares
        gridParticles = [];
        //for (var x=0; x < size*size; x++)
        for (var x=0; x < size_x*size_y; x++)
        {
            var particle = Particles.CreateParticle("particles/buildinghelper/square_sprite.vpcf", ParticleAttachment_t.PATTACH_CUSTOMORIGIN, 0)
            Particles.SetParticleControl(particle, 1, [32,0,0])
            Particles.SetParticleControl(particle, 3, [grid_alpha,0,0])
            gridParticles.push(particle)
        }

        // Prop particle attachment
        if (params.propIndex !== undefined)
        {
            propParticle = Particles.CreateParticle("particles/buildinghelper/ghost_model.vpcf", ParticleAttachment_t.PATTACH_CUSTOMORIGIN, 0);
            Particles.SetParticleControlEnt(propParticle, 1, params.propIndex, ParticleAttachment_t.PATTACH_ABSORIGIN_FOLLOW, "attach_hitloc", Entities.GetAbsOrigin(params.propIndex), true)
            Particles.SetParticleControl(propParticle, 2, ghost_color)
            Particles.SetParticleControl(propParticle, 3, [model_alpha,0,0])
            Particles.SetParticleControl(propParticle, 4, [propScale,0,0])
        }
            
        rangeOverlayActive = false;
        overlayParticles = [];
    }

    if (state == 'active')
    {   
        $.Schedule(frame_rate, StartBuildingHelper);

        // 获取所有可见的实体
        var entities = Entities.GetAllEntitiesByClassname('npc_dota_building')
        var hero_entities = Entities.GetAllHeroEntities()
        var creature_entities = Entities.GetAllEntitiesByClassname('npc_dota_creature')
        var dummy_entities = Entities.GetAllEntitiesByName('npc_dota_base')
        var building_entities = Entities.GetAllBuildingEntities()
        entities = entities.concat(hero_entities)
        entities = entities.concat(building_entities)
        entities = entities.concat(creature_entities)
        entities = entities.concat(dummy_entities)

        // 使用构造尺寸和实体原点构建实体网格
        entityGrid = []
        for (var i = 0; i < entities.length; i++)
        {   
            if (!Entities.IsAlive(entities[i]) || Entities.IsOutOfGame(entities[i]) || !HasModifier(entities[i], "modifier_building")) continue
            var entPos = Entities.GetAbsOrigin( entities[i] )
            // var squares = GetConstructionSize(entities[i])
            var squaresstr = GetConstructionSize(entities[i])
            var squares_x = squaresstr.split("x")[0];
            var squares_y = squaresstr.split("x")[1];

            //if (squares > 0)
            if (squares_x > 0 && squares_y > 0)
            {
                // 以原点为中心的方块
                // BlockGridSquares(entPos, squares, GRID_TYPES["BLOCKED"])
                BlockGridSquaresXY(entPos, squares_x, squares_y, GRID_TYPES["BLOCKED"])
            }
            else
            {
                // Put tree dummies on a separate table to skip trees
                if (Entities.GetUnitName(entities[i]) == 'npc_dota_units_base')
                {
                    if (HasModifier(entities[i], "modifier_tree_cut"))
                        cutTrees[entPos] = entities[i]
                }
                // Block 2x2 squares if its an enemy unit
                else if (Entities.GetTeamNumber(entities[i]) != Entities.GetTeamNumber(builderIndex) && !HasModifier(entities[i], "modifier_out_of_world"))
                {
                    //BlockGridSquares(entPos, 2, GRID_TYPES["BLOCKED"])
                    BlockGridSquaresXY(entPos, 2, 2, GRID_TYPES["BLOCKED"])
                }
            }

            var specialGrid = GetCustomGrid(entities[i])
            if (specialGrid)
            {
                for (var gridType in specialGrid)
                {
                    if (specialGrid[gridType].Square)
                    {
                        //$.Msg("Setting ",specialGrid[gridType].Square," grid squares with ",gridType.toUpperCase()," [",GRID_TYPES[gridType.toUpperCase()],"]")
                        BlockGridSquares(entPos, Number(specialGrid[gridType].Square), GRID_TYPES[gridType.toUpperCase()])
                    }
                    else if (specialGrid[gridType].Radius)
                    {
                        //$.Msg("Setting ",specialGrid[gridType].Radius," grid radius with ",gridType.toUpperCase()," [",GRID_TYPES[gridType.toUpperCase()],"]")
                        BlockGridInRadius(entPos, Number(specialGrid[gridType].Radius), GRID_TYPES[gridType.toUpperCase()])
                    }
                }              
            }
        }

        // Update treeGrid (slowly, as its the most expensive)
        if (update_trees)
        {
            var time = Game.GetGameTime()
            var time_since_last_tree_update = time - last_tree_update
            if (time_since_last_tree_update > tree_update_interval)
            {
                last_tree_update = time
                tree_entities = Entities.GetAllEntitiesByClassname('ent_dota_tree')
                treeGrid = [];
                for (var i = 0; i < tree_entities.length; i++)
                {
                    var treePos = Entities.GetAbsOrigin(tree_entities[i])
                    // Block the grid if the tree isn't chopped
                    if (cutTrees[treePos] === undefined)
                        BlockGridSquares(treePos, 2, "TREE")                    
                }
            }
        }

        // 获取当前鼠标位置
        var mPos = GameUI.GetCursorPosition();
        var GamePos = Game.ScreenXYToWorld(mPos[0], mPos[1]);
        if ( GamePos !== null ) 
        {
            //SnapToGrid(GamePos, size)
            SnapToGridXY(GamePos, size_x ,size_y)

            invalid = false
            var color = [0,255,0]
            var part = 0
            //var halfSide = (size/2)*64
            var halfSide_x = (size_x/2)*64
            var halfSide_y = (size_y/2)*64
            var boundingRect = {}
            boundingRect["leftBorderX"] = GamePos[0]-halfSide_x
            boundingRect["rightBorderX"] = GamePos[0]+halfSide_x
            boundingRect["topBorderY"] = GamePos[1]+halfSide_y
            boundingRect["bottomBorderY"] = GamePos[1]-halfSide_y

            if (GamePos[0] > 10000000) return

            var closeToGoldMine = TooCloseToGoldmine(GamePos)

            // 建筑基础网格
            for (var x=boundingRect["leftBorderX"]+32; x <= boundingRect["rightBorderX"]-32; x+=64)
            {
                for (var y=boundingRect["topBorderY"]-32; y >= boundingRect["bottomBorderY"]+32; y-=64)
                {
                    var pos = SnapHeight(x,y,GamePos[2])
                    //if (part>size*size) {
                    if (part>size_x*size_y) {
                        return
                    }

                    var gridParticle = gridParticles[part]
                    //pos[2] = pos[2] + 20 // add by lyjian
                    Particles.SetParticleControl(gridParticle, 0, pos)     
                    part++; 

                    // 当超过无效位置时，网格颜色变为红色
                    color = [0,255,0]
                    if (IsBlocked(pos) || closeToGoldMine)
                    {
                        color = [255,0,0]
                        invalid = true
                    }

                    Particles.SetParticleControl(gridParticle, 2, color)   
                }
            }

            // 叠加网格，按住Alt键可见
            altDown = permanent_alt_grid || GameUI.IsAltDown();
            if (altDown)
            {
                // Create the particles
                if (overlayParticles && overlayParticles.length == 0)
                {
                    //for (var y=0; y < overlay_size*overlay_size; y++)
                    for (var y=0; y < overlay_size_x*overlay_size_y; y++)
                    {
                        var particle = Particles.CreateParticle("particles/buildinghelper/square_overlay.vpcf", ParticleAttachment_t.PATTACH_CUSTOMORIGIN, 0)
                        Particles.SetParticleControl(particle, 1, [32,0,0])
                        Particles.SetParticleControl(particle, 3, [alt_grid_alpha,0,0])
                        overlayParticles.push(particle)
                    }
                }

                color = [255,255,255]
                var part2 = 0
                // var halfSide2 = (overlay_size/2)*64
                var halfSide_x = (overlay_size_x/2)*64
                var halfSide_y = (overlay_size_y/2)*64
                var boundingRect2 = {}
                //boundingRect2["leftBorderX"] = GamePos[0]-halfSide2
                //boundingRect2["rightBorderX"] = GamePos[0]+halfSide2
                //boundingRect2["topBorderY"] = GamePos[1]+halfSide2
                //boundingRect2["bottomBorderY"] = GamePos[1]-halfSide2
                boundingRect2["leftBorderX"] = GamePos[0]-halfSide_x
                boundingRect2["rightBorderX"] = GamePos[0]+halfSide_x
                boundingRect2["topBorderY"] = GamePos[1]+halfSide_y
                boundingRect2["bottomBorderY"] = GamePos[1]-halfSide_y


                for (var x2=boundingRect2["leftBorderX"]+32; x2 <= boundingRect2["rightBorderX"]-32; x2+=64)
                {
                    for (var y2=boundingRect2["topBorderY"]-32; y2 >= boundingRect2["bottomBorderY"]+32; y2-=64)
                    {
                        var pos2 = SnapHeight(x2,y2,GamePos[2])

                        // if (part2>=overlay_size*overlay_size) {
                        if (part2>=overlay_size_x*overlay_size_y) {
                            return
                        }

                        color = [255,255,255] //White on empty positions
                        var overlayParticle = overlayParticles[part2]
                        //pos2[2] = pos2[2] + 20 // add by lyjian
                        Particles.SetParticleControl(overlayParticle, 0, pos2)     
                        part2++;

                        if (IsBlocked(pos2) || TooCloseToGoldmine(pos2))
                            color = [255,0,0]                        

                        Particles.SetParticleControl(overlayParticle, 2, color)
                    }
                }
            }
            else
            {
                // Destroy the particles, only once
                if (overlayParticles && overlayParticles.length != 0)
                {
                    for (var i in overlayParticles) {
                        Particles.DestroyParticleEffect(overlayParticles[i], true)
                        Particles.ReleaseParticleIndex(overlayParticles[i])
                    }
                    overlayParticles = [];
                }
            }

            var modelPos = SnapHeight(GamePos[0],GamePos[1],GamePos[2])

            // 如果不是有效的建筑位置，请销毁范围覆盖
            if (invalid)
            {
                if (rangeOverlayActive && rangeOverlay !== undefined)
                {
                    Particles.DestroyParticleEffect(rangeOverlay, true)
                    Particles.ReleaseParticleIndex(rangeOverlay)
                    rangeOverlayActive = false
                }
            }
            else
            {
                if (!rangeOverlayActive)
                {
                    rangeOverlay = Particles.CreateParticle("particles/buildinghelper/range_overlay.vpcf", ParticleAttachment_t.PATTACH_CUSTOMORIGIN, localHeroIndex)
                    Particles.SetParticleControl(rangeOverlay, 1, [range,0,0])
                    Particles.SetParticleControl(rangeOverlay, 2, [255,255,255])
                    Particles.SetParticleControl(rangeOverlay, 3, [range_overlay_alpha,0,0])
                    rangeOverlayActive = true
                }              
            }

            if (rangeOverlay !== undefined)
                Particles.SetParticleControl(rangeOverlay, 0, modelPos)

            // Update the model particle
            modelPos[2]+=modelOffset
            Particles.SetParticleControl(modelParticle, 0, modelPos)

            if (propParticle !== undefined)
            {
                var pedestalPos = SnapHeight(GamePos[0],GamePos[1],GamePos[2])
                pedestalPos[2]+=offsetZ
                Particles.SetParticleControl(propParticle, 0, pedestalPos)
            }

            // 如果我们不能在那里建造，就把模型变成红色
            if (turn_red){
                invalid ? Particles.SetParticleControl(modelParticle, 2, [255,0,0]) : Particles.SetParticleControl(modelParticle, 2, [255,255,255])
                if (propParticle !== undefined)
                    invalid ? Particles.SetParticleControl(propParticle, 2, [255,0,0]) : Particles.SetParticleControl(propParticle, 2, [255,255,255])
            }
        }

        if ( (!GameUI.IsShiftDown() && pressedShift) || !Entities.IsAlive( builderIndex ) )
        {
            EndBuildingHelper();
        }
    }
}

function EndBuildingHelper()
{
    state = 'disabled'
    if (modelParticle !== undefined){
         Particles.DestroyParticleEffect(modelParticle, true)
         Particles.ReleaseParticleIndex(modelParticle)
    }
    if (propParticle !== undefined){
         Particles.DestroyParticleEffect(propParticle, true)
         Particles.ReleaseParticleIndex(propParticle)
    }
    if (rangeOverlay !== undefined){
        Particles.DestroyParticleEffect(rangeOverlay, true)
        Particles.ReleaseParticleIndex(rangeOverlay)
    }
    for (var i in gridParticles) {
        Particles.DestroyParticleEffect(gridParticles[i], true)
        Particles.ReleaseParticleIndex(gridParticles[i])
    }
    for (var i in overlayParticles) {
        Particles.DestroyParticleEffect(overlayParticles[i], true)
        Particles.ReleaseParticleIndex(overlayParticles[i])
    }
}

// 发送指令开始建造了
function SendBuildCommand( params )
{
    if (invalid)
    {
        CreateErrorMessage({message:"#error_invalid_build_position"})
        return true
    }

    pressedShift = GameUI.IsShiftDown();
    var mainSelected = Players.GetLocalPlayerPortraitUnit(); 

    var mPos = GameUI.GetCursorPosition();
    var GamePos = Game.ScreenXYToWorld(mPos[0], mPos[1]);

    GameEvents.SendCustomGameEventToServer( "building_helper_build_command", { "builder": mainSelected, "X" : GamePos[0], "Y" : GamePos[1], "Z" : GamePos[2] , "Queue" : pressedShift , "model" : "1"} );

    // Cancel unless the player is holding shift
    if (!GameUI.IsShiftDown())
    {
        EndBuildingHelper(params);
        return true;
    }
    return true;
}

function SendCancelCommand( params )
{
    EndBuildingHelper();
    GameEvents.SendCustomGameEventToServer( "building_helper_cancel_command", {} );
}

function CreateErrorMessage(msg)
{
    var reason = msg.reason || 80;
    if (msg.message){
        GameEvents.SendEventClientSide("dota_hud_error_message", {"splitscreenplayer":0,"reason":reason ,"message":msg.message} );
    }
    else{
        GameEvents.SendEventClientSide("dota_hud_error_message", {"splitscreenplayer":0,"reason":reason} );
    }
}

function RegisterGNV(msg){
    var GridNav = [];
    var squareX = msg.squareX
    var squareY = msg.squareY
    var boundX = msg.boundX
    var boundY = msg.boundY

    var arr = [];

    //add by lyjian
    /**
    var fullMsg = msg.gnv1 + msg.gnv2 + msg.gnv3
    for (var i=0; i<fullMsg.length; i++){
        var code = fullMsg.charCodeAt(i)-32;
        for (var j=4; j>=0; j-=2){
            var g = (code & (3 << j)) >> j;
            if (g != 0)
              arr.push(g);
        }
    } 
    **/
    
    for (var i=0; i<msg.gnv.length; i++){
        var code = msg.gnv.charCodeAt(i)-32;
        for (var j=4; j>=0; j-=2){
            var g = (code & (3 << j)) >> j;
            if (g != 0)
              arr.push(g);
        }
    }

    // Load the GridNav
    var x = 0;
    for (var i = 0; i < squareY; i++) {
        GridNav[i] = []
        for (var j = 0; j < squareX; j++) {
          GridNav[i][j] = (arr[x] == 1) ? GRID_TYPES["BUILDABLE"] : GRID_TYPES["BLOCKED"]
          x++
        }
    }

    Root.GridNav = GridNav
    Root.squareX = squareX
    Root.squareY = squareY
    Root.boundX = boundX
    Root.boundY = boundY

    // ASCII Art
    /*
    for (var i = 0; i<squareY; i++) {
        var a = [];
        for (var j = 0; j<squareX; j++){
            a.push((GridNav[i][j] == 1 ) ? '=' : '.');
        }

        $.Msg(a.join(''))
    }*/

    // Debug Prints
    var tab = {"0":0, "1":0, "2":0, "3":0};
    for (i=0; i<arr.length; i++)
    {
        tab[arr[i].toString()]++;
    }
}

// Ask the server for the Terrain grid
function RequestGNV () {
    GameEvents.SendCustomGameEventToServer( "gnv_request", {} )
}

(function () {    
    RequestGNV()

    GameEvents.Subscribe( "building_helper_enable", StartBuildingHelper);
    GameEvents.Subscribe( "building_helper_end", EndBuildingHelper);

    GameEvents.Subscribe( "gnv_register", RegisterGNV);
})();

//-----------------------------------

function SnapToGrid(vec, size) {
    // Buildings are centered differently when the size is odd.
    if (size % 2 != 0) 
    {
        vec[0] = SnapToGrid32(vec[0])
        vec[1] = SnapToGrid32(vec[1])
    } 
    else 
    {
        vec[0] = SnapToGrid64(vec[0])
        vec[1] = SnapToGrid64(vec[1])
    }
}

function SnapToGridXY(vec, size_x ,size_y) {
    // Buildings are centered differently when the size is odd.
    if (size_x % 2 != 0) 
    {
        vec[0] = SnapToGrid32(vec[0])
    } 
    else 
    {
        vec[0] = SnapToGrid64(vec[0])
    }

    if (size_y % 2 != 0) 
    {
        vec[1] = SnapToGrid32(vec[1])
    } 
    else 
    {
        vec[1] = SnapToGrid64(vec[1])
    }
}

function SnapToGrid64(coord) {
    return 64*Math.floor(0.5+coord/64);
}

function SnapToGrid32(coord) {
    return 32+64*Math.floor(coord/64);
}

function SnapHeight(x,y,z){
    return [x, y, z - ((z+1)%128)]
}

function IsBlocked(position) {
    var y = WorldToGridPosX(position[0]) - Root.boundX
    var x = WorldToGridPosY(position[1]) - Root.boundY

    //{"BLIGHT":8,"BUILDABLE":2,"GOLDMINE":4,"BLOCKED":1}
    // 检查高度限制
    if (height_restriction !== undefined && position[2] < height_restriction)
        return true

    // 将网格合并到同一个值中
    var flag = Root.GridNav[x][y]
    var entGridValue = (entityGrid[x] !== undefined && entityGrid[x][y] !== undefined) ? entityGrid[x][y] : GRID_TYPES["BUILDABLE"]
    if (entityGrid[x] && entityGrid[x][y])
        flag = flag | entityGrid[x][y]

    // Don't count buildable if its blocked
    var adjust = (GRID_TYPES["BUILDABLE"]+GRID_TYPES["BLOCKED"])
    if ((flag & adjust)==adjust)
        flag-=GRID_TYPES["BUILDABLE"]

    //$.Msg('GRID:',Root.GridNav[x][y],' ENTGRID:',entGridValue,' FLAG:',flag,' REQUIRES:', requires)

    // If the bits don't match, its invalid
    if ((flag & requires) != requires)
        return true

    // If there's a tree standing, its invalid
    if (update_trees && treeGrid[x] && (treeGrid[x][y] & GRID_TYPES["BLOCKED"]))
        return true

    return false
}

function BlockEntityGrid(position, gridType) {
    // Root.boundX 这个是什么啊
    var y = WorldToGridPosX(position[0]) - Root.boundX
    var x = WorldToGridPosY(position[1]) - Root.boundY

    if (entityGrid[x] === undefined) entityGrid[x] = []
    if (entityGrid[x][y] === undefined) entityGrid[x][y] = 0

    entityGrid[x][y] = entityGrid[x][y] | gridType
}

// Trees block 2x2
function BlockTreeGrid (position) {
    var y = WorldToGridPosX(position[0]) - Root.boundX
    var x = WorldToGridPosY(position[1]) - Root.boundY

    if (treeGrid[x] === undefined) treeGrid[x] = []

    treeGrid[x][y] = GRID_TYPES["BLOCKED"]
}

function BlockGridSquares (position, squares, gridType) {
    var halfSide = (squares/2)*64
    var boundingRect = {}
    boundingRect["leftBorderX"] = position[0]-halfSide
    boundingRect["rightBorderX"] = position[0]+halfSide
    boundingRect["topBorderY"] = position[1]+halfSide
    boundingRect["bottomBorderY"] = position[1]-halfSide

    if (gridType == "TREE")
    {
        for (var x=boundingRect["leftBorderX"]+32; x <= boundingRect["rightBorderX"]-32; x+=64)
        {
            for (var y=boundingRect["topBorderY"]-32; y >= boundingRect["bottomBorderY"]+32; y-=64)
            {
                BlockTreeGrid([x,y,0])
            }
        }
    }
    else
    {
        for (var x=boundingRect["leftBorderX"]+32; x <= boundingRect["rightBorderX"]-32; x+=64)
        {
            for (var y=boundingRect["topBorderY"]-32; y >= boundingRect["bottomBorderY"]+32; y-=64)
            {
                BlockEntityGrid([x,y,0], gridType)
            }
        }
    }
}

function BlockGridSquaresXY (position, squares_x, squares_y,  gridType) {
    var halfSide_x = (squares_x/2)*64
    var halfSide_y = (squares_y/2)*64
    var boundingRect = {}
    boundingRect["leftBorderX"] = position[0]-halfSide_x
    boundingRect["rightBorderX"] = position[0]+halfSide_x
    boundingRect["topBorderY"] = position[1]+halfSide_y
    boundingRect["bottomBorderY"] = position[1]-halfSide_y

    if (gridType == "TREE")
    {
        for (var x=boundingRect["leftBorderX"]+32; x <= boundingRect["rightBorderX"]-32; x+=64)
        {
            for (var y=boundingRect["topBorderY"]-32; y >= boundingRect["bottomBorderY"]+32; y-=64)
            {
                BlockTreeGrid([x,y,0])
            }
        }
    }
    else
    {
        for (var x=boundingRect["leftBorderX"]+32; x <= boundingRect["rightBorderX"]-32; x+=64)
        {
            for (var y=boundingRect["topBorderY"]-32; y >= boundingRect["bottomBorderY"]+32; y-=64)
            {
                BlockEntityGrid([x,y,0], gridType)
            }
        }
    }
}

function BlockGridInRadius (position, radius, gridType) {
    var boundingRect = {}
    boundingRect["leftBorderX"] = position[0]-radius
    boundingRect["rightBorderX"] = position[0]+radius
    boundingRect["topBorderY"] = position[1]+radius
    boundingRect["bottomBorderY"] = position[1]-radius

    for (var x=boundingRect["leftBorderX"]+32; x <= boundingRect["rightBorderX"]+32; x+=64)
    {
        for (var y=boundingRect["topBorderY"]+32; y >= boundingRect["bottomBorderY"]+32; y-=64)
        {
            if (Length2D(position, [x,y]) <= radius)
            {
                BlockEntityGrid([x,y,0], gridType)
            }
        }
    }
}

function WorldToGridPosX(x){
    return Math.floor(x/64)
}

function WorldToGridPosY(y){
    return Math.floor(y/64)
}

function GetConstructionSize(entIndex) {
    var entName = Entities.GetUnitName(entIndex)
    var table = CustomNetTables.GetTableValue("construction_size", entName)
    // return table ? table.size : 0 
    return table ? table.size : "0x0"
}

function GetRequiredGridType(entIndex) {
    var entName = Entities.GetUnitName(entIndex)
    var table = CustomNetTables.GetTableValue("construction_size", entName)
    if (table && table.requires !== undefined)
    {
        var types = table.requires.split(" ")
        var value = 0
        for (var i = 0; i < types.length; i++)
        {
            value+=GRID_TYPES[types[i]]
        }
        return value
    }
    else
        return GRID_TYPES["BUILDABLE"]
}

function GetCustomGrid(entIndex) {
    var entName = Entities.GetUnitName(entIndex)
    var table = CustomNetTables.GetTableValue("construction_size", entName)
    if (table && table.grid !== undefined)
    {
        var gridType = table.grid
        for (var type in gridType)
            if (HasModifier(entIndex, "modifier_grid_"+type.toLowerCase()))
                return table.grid
    }    
}

function HasGoldMineDistanceRestriction(entIndex) {
    var entName = Entities.GetUnitName(entIndex)
    var table = CustomNetTables.GetTableValue("construction_size", entName)
    return table ? table.distance_to_gold_mine : 0
}

function GetClosestDistanceToGoldMine(position) {
    var building_entities = Entities.GetAllEntitiesByClassname('npc_dota_building')

    var minDistance = 99999
    for (var i = 0; i < building_entities.length; i++)
    {
        if (Entities.GetUnitName(building_entities[i]) == "gold_mine")
        {
            var distance_to_this_mine = Length2D(position, Entities.GetAbsOrigin(building_entities[i]))
            if (distance_to_this_mine < minDistance)
                minDistance = distance_to_this_mine
        }
    }
    return minDistance
}

function TooCloseToGoldmine(position) {
    return (distance_to_gold_mine > 0 && GetClosestDistanceToGoldMine(position) < distance_to_gold_mine)
}

function Length2D(v1, v2) {
    return Math.sqrt( (v2[0]-v1[0])*(v2[0]-v1[0]) + (v2[1]-v1[1])*(v2[1]-v1[1]) )
}

function PrintGridCoords(x,y) {
    $.Msg('(',x,',',y,') = [',WorldToGridPosX(x),',',WorldToGridPosY(y),']')
}

function HasModifier(entIndex, modifierName) {
    var nBuffs = Entities.GetNumBuffs(entIndex)
    for (var i = 0; i < nBuffs; i++) {
        if (Buffs.GetName(entIndex, Entities.GetBuff(entIndex, i)) == modifierName)
            return true
    };
    return false
};


// 旋转模型角度,有点问题，设置了没用
function changeAngles(){
    // var yaw = -45;
    var ability = Entities.GetAbilityByName(localHeroIndex,abilityname);
    // 这边要用index的
    // var caster = Abilities.GetCaster(ability)
    var params = {"caster":localHeroIndex,"ability":ability,"yaw":yaw};
    GameEvents.SendCustomGameEventToServer( "change_angles", params);
}

// 把 clicks.js 移过来
"use strict"
var right_click_repair = CustomNetTables.GetTableValue("building_settings", "right_click_repair").value;

function GetMouseTarget()
{
    var mouseEntities = GameUI.FindScreenEntities( GameUI.GetCursorPosition() )
    var localHeroIndex = Players.GetPlayerHeroEntityIndex( Players.GetLocalPlayer() )

    for ( var e of mouseEntities )
    {
        if ( !e.accurateCollision )
            continue
        return e.entityIndex
    }

    for ( var e of mouseEntities )
    {
        return e.entityIndex
    }

    return 0
}

// 处理右键事件
function OnRightButtonPressed()
{
    var iPlayerID = Players.GetLocalPlayer()
    var selectedEntities = Players.GetSelectedEntities( iPlayerID )
    var mainSelected = Players.GetLocalPlayerPortraitUnit() 
    var targetIndex = GetMouseTarget()
    var pressedShift = GameUI.IsShiftDown()

    // 生成器右键单击
    if ( IsBuilder( mainSelected ) )
    {
        // Cancel BH
        if (!pressedShift) SendCancelCommand()

        // 修复右键单击
        if (right_click_repair && IsCustomBuilding(targetIndex) && Entities.GetHealthPercent(targetIndex) < 100 && IsAlliedUnit(targetIndex, mainSelected)) {
            GameEvents.SendCustomGameEventToServer( "building_helper_repair_command", {targetIndex: targetIndex, queue: pressedShift})
            return true
        }
    }

    return false
}

// 处理左键事件
function OnLeftButtonPressed() {
    return false
}

function IsCustomBuilding(entIndex) {
    return (Entities.GetAbilityByName( entIndex, "ability_building") != -1)
}

function IsBuilder(entIndex) {
    var tableValue = CustomNetTables.GetTableValue( "builders", entIndex.toString())
    return (tableValue !== undefined) && (tableValue.IsBuilder == 1)
}

function IsAlliedUnit(entIndex, targetIndex) {
    return (Entities.GetTeamNumber(entIndex) == Entities.GetTeamNumber(targetIndex))
}

// 主鼠标事件回调

GameUI.SetMouseCallback( function( eventName, arg ) {
    var CONSUME_EVENT = true
    var CONTINUE_PROCESSING_EVENT = false
    // 0左键，1右键，2中键
    var LEFT_CLICK = (arg === 0)
    var RIGHT_CLICK = (arg === 1)
    var MIDDLE_CLICK = (arg === 2)
    if ( GameUI.GetClickBehaviors() !== CLICK_BEHAVIORS.DOTA_CLICK_BEHAVIOR_NONE )
        return CONTINUE_PROCESSING_EVENT

    var mainSelected = Players.GetLocalPlayerPortraitUnit()
    if ( eventName === "pressed" || eventName === "doublepressed")
    {   
        // Builder Clicks
        if (IsBuilder(mainSelected)) {
            if (LEFT_CLICK) 
                return (state == "active") ? SendBuildCommand() : OnLeftButtonPressed()
            else if (RIGHT_CLICK) 
                return OnRightButtonPressed()
        }
        if (LEFT_CLICK) {
            return OnLeftButtonPressed()
        }
        else if (RIGHT_CLICK) {
            return OnRightButtonPressed() 
        }
        /** else if(MIDDLE_CLICK && state === 'active') {
            return changeAngles()
        }
        **/
    }
    return CONTINUE_PROCESSING_EVENT
} )
