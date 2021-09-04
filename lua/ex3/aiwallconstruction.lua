-- ########################################################################## --
-- #  Wall Construction                                                     # --
-- #  --------------------------------------------------------------------  # --
-- #    Author:   totalwarANGEL                                             # --
-- ########################################################################## --

---
-- This module implements the construction of walls.
--
-- Walls have a higher defence then usual and can be build by continuing towers
-- or wall corners with new segments.
--
-- If you planning on activating this mod in a map with AI players, ensure that
-- the armies are smart enouth do attack walls. The easiest way is to use the
-- in the QSB included army function with waypoints instead of default AI. 
--
-- <b>Required modules:</b>
-- <ul>
-- <li>qsb.lib.aiarmy</li>
-- </ul>
-- 
-- @set sort=true
--

---
-- Activates the wall construction.
--
function InstallWallConstruction()
    AiWallConstruction:Initalize();
end

---
-- Starts the upgrade of the passed wall corner
--
-- <b>Note:</b> This function does not synchronize. Use it only in synchronized
-- calls or you get an desync in multiplayer.
--
-- <b>Note:</b> The function always adds the construction costs to the owner of
-- the entity. Use this only for AI.
--
-- @param              _Entity    Script name or ID of gate
-- @param[type=number] _Direction Direction constant
-- @param[type=number] _Mode      Mode constant
-- @param[type=number] _Variant   Variant constant
-- @return[type=number] ID of corner, ID of wall
-- @see PlacementAction
-- @see WallPlacement
-- @see WallVariant
--
function RemoteBuildPlaceWall(_Entity, _Direction, _Mode, _Variant)
    if not IsExisting(_Entity) then
        return;
    end
    local PlayerID = Logic.EntityGetPos(GetID(_Entity));
    local x, y, z = Logic.EntityGetPos(GetID(_Entity));
    if _Mode then
        AiWallConstruction:SetPlacementMode(PlayerID, _Mode);
    end
    if _Variant then
        AiWallConstruction:SetPlacementMode(PlayerID, _Variant);
    end
    local Costs = AiWallConstruction:WallSegmendGetCosts(PlayerID);
    QuestTools.AddResourcesToPlayer(PlayerID, Costs);
    local CornerID, WallID = AiWallConstruction:PlaceSegment(PlayerID, x, y, _Direction);
    return CornerID, WallID;
end

---
-- Starts the upgrade of the passed wall corner
--
-- <b>Note:</b> This function does not synchronize. Use it only in synchronized
-- calls or you get an desync in multiplayer.
--
-- <b>Note:</b> The function always adds the upgrade costs to the owner of the
-- entity. Use this only for AI.
--
-- @param _Entity Script name or ID of gate
--
function RemoteBuildUpgradeCorner(_Entity)
    if not IsExisting(_Entity) then
        return;
    end
    local PlayerID = Logic.EntityGetPos(GetID(_Entity));
    local Costs = {
        [ResourceType.Stone] = 200,
        [ResourceType.Wood]  = 200,
    };
    QuestTools.AddResourcesToPlayer(PlayerID, Costs);
    AiWallConstruction:WallSegmendPlace(
        GetID(_Entity),
        PlacementAction.UpgradeCorner
    );
end

---
-- Open or closes a gate.
--
-- Returns 0 if action failed.
--
-- <b>Note:</b> This function does not synchronize. Use it only in synchronized
-- calls or you get an desync in multiplayer.
--
-- @param _Entity Script name or ID of gate
-- @return[type=number] New ID of gate
--
function RemoteBuildToggleGate(_Entity)
    if not IsExisting(_Entity) then
        return 0;
    end
    return AiWallConstruction:ToggleOpenCloseGate(GetID(_Entity));
end

---
-- Changes the duration of the construction of segment types.
--
-- @param[type=number] _Type     Entity type
-- @param[type=number] _Time     Construction duration
-- @param[type=number] _PlayerID ID opf player
--
function ChangeSegmentConstructionDuration(_Type, _Time, _PlayerID)
    if AiWallConstruction.Data[_Type] then
        AiWallConstruction.Data:Set(_Type, _PlayerID, "BuildTime", Round(_Time * 10));
    end
end

---
-- Changes the duration of wall corner upgrades. Duration is ignored for all
-- that is not a wall corner.
--
-- @param[type=number] _Type     Entity type
-- @param[type=number] _Time     Upgrade duration
-- @param[type=number] _PlayerID ID opf player
--
function ChangeSegmentUpgradeDuration(_Type, _Time, _PlayerID)
    if AiWallConstruction.Data[_Type] then
        AiWallConstruction.Data:Set(_Type, _PlayerID, "UpgradeTime", Round(_Time * 10));
    end
end

---
-- Changes the construction costs of the segment type.
--
-- @param[type=number] _Type     Entity type
-- @param[type=number] _Gold     Amount of gold
-- @param[type=number] _Clay     Amount of clay
-- @param[type=number] _Wood     Amount of wood
-- @param[type=number] _Stone    Amount of stone
-- @param[type=number] _Iron     Amount of iron
-- @param[type=number] _Sulfur   Amount of sulfur
-- @param[type=number] _PlayerID ID opf player
--
function ChangeSegmentCosts(_Type, _Gold, _Clay, _Wood, _Stone, _Iron, _Sulfur, _PlayerID)
    if AiWallConstruction.Data[_Type] then
        AiWallConstruction.Data:Set(_Type, _PlayerID, "Costs", {
            [ResourceType.Gold]   = _Gold,
            [ResourceType.Clay]   = _Clay,
            [ResourceType.Wood]   = _Wood,
            [ResourceType.Stone]  = _Stone,
            [ResourceType.Iron]   = _Iron,
            [ResourceType.Sulfur] = _Sulfur,
            [ResourceType.Silver] = 0,
        });
    end
end

---
-- Changes the maximum health of the segment type.
--
-- @param[type=number] _Type     Entity type
-- @param[type=number] _Health   Maximum health
-- @param[type=number] _PlayerID ID opf player
--
function ChangeSegmentHealth(_Type, _Health, _PlayerID)
    if AiWallConstruction.Data[_Type] then
        AiWallConstruction.Data:Set(_Type, _PlayerID, "MaxHealth", _Health);
    end
end

---
-- Changes the armor of the segment type.
--
-- @param[type=number] _Type     Entity type
-- @param[type=number] _Base     Base armor
-- @param[type=number] _Upgrade  T_Masonry bonus
-- @param[type=number] _PlayerID ID opf player
--
function ChangeSegmentArmor(_Type, _Base, _Upgrade, _PlayerID)
    if AiWallConstruction.Data[_Type] then
        AiWallConstruction.Data:Set(_Type, _PlayerID, "ArmorBase", _Base);
        AiWallConstruction.Data:Set(_Type, _PlayerID, "ArmorUpgrade", _Upgrade);
    end
end

---
-- Changes the factor of the health regeneration of the segment type. Health is
-- only regenerated if no enemies are near.
--
-- @param[type=number] _Type     Entity type
-- @param[type=number] _Factor   Regeneration factor
-- @param[type=number] _PlayerID ID opf player
--
function ChangeSegmentRegeneration(_Type, _Factor, _PlayerID)
    if AiWallConstruction.Data[_Type] then
        AiWallConstruction.Data:Set(_Type, _PlayerID, "HealthFactor", _Factor);
    end
end

---
-- Changes the factor the base damage of an enemy is multiplied with. If the
-- factor is not set for a type 0.1 is taken by default.
--
-- @param[type=number] _Type     Entity type
-- @param[type=number] _Factor   Damage factor
-- @param[type=number] _PlayerID ID opf player
--
function ChangeEnemyDamageFactor(_Type, _Factor, _PlayerID)
    self.Mapping:Set(_PlayerID, "DamageFactor", _Type, _Factor);
end

---
-- Helper function to get enemies for targeting. This function will also include
-- entities registered as a wall.
--
-- <b>Note:</b> List is not sorted by distance.
--
-- @param[type=number] _PlayerID ID opf player
-- @param[type=table]  _Position Center of area
-- @param[type=number] _Area     Radius of area
-- @return[type=table] List of Enemies
--
function GetEnemiesInAreaIncludingWalls(_PlayerID, _Position, _Area)
    local Enemies = {};
    for i= 1, table.getn(Score.Player), 1 do
        if i ~= _PlayerID and Logic.GetDiplomacyState(_PlayerID, i) == Diplomacy.Hostile then
            local PlayerEntities = {Logic.GetPlayerEntitiesInArea(i, 0, _Position.X, _Position.Y, _Area, 16)};
            for j= PlayerEntities[1] +1, 2, -1 do
                local IsAlive = Logic.GetEntityHealth(PlayerEntities[j]) > 0;
                local IsBuilding = Logic.IsBuilding(PlayerEntities[j]) == 1;
                local IsCannon = Logic.IsEntityInCategory(PlayerEntities[j], EntityCategories.Cannon) == 1;
                local IsCamouflaged = Logic.GetCamouflageDuration(PlayerEntities[j]) == 0;
                local IsHero = Logic.IsHero(PlayerEntities[j]) == 1;
                local IsLeader = Logic.IsLeader(PlayerEntities[j]) == 1;
                local IsThief = Logic.IsEntityInCategory(PlayerEntities[j], EntityCategories.Thief) == 1;
                local IsWorkplace = Logic.IsEntityInCategory(PlayerEntities[j], EntityCategories.Workplace) == 1;
                
                if (
                    IsAlive and not IsThief and (
                        (IsBuilding and not IsWorkplace) or
                        (IsHero and not IsCamouflaged) or
                        IsLeader or
                        IsCannon or
                        AiWallConstruction.m_Walls[PlayerEntities[j]]
                    )
                )
                then
                    table.insert(Enemies, PlayerEntities[j]);
                end
            end
        end
    end
    return Enemies;
end

-- - Core Script ------------------------------------------------------------ --

AiWallConstruction = {
    Events = {},

    m_Walls = {},
    m_PlacedWallMode = {},
    m_PlacedWallType = {},
    m_AreaLimitation = {},
    m_TowerLimit = -1,

    l_CornerSelected = false,
};

function AiWallConstruction:Initalize()
    for i= 1, table.getn(Score.Player), 1 do
        self.m_PlacedWallMode[i] = WallPlacement.Wall;
        self.m_PlacedWallType[i] = WallVariant.Normal;
        self.m_AreaLimitation[i] = {};
    end

    self:WallSegmendRegisterExisting();
    self:CreateControllerJobs();
    self:CreateSyncEvents();
    self:InitInterface();
end

function AiWallConstruction:CreateControllerJobs()
    -- Save game action
    AddOnSaveLoadedAction(function()
        AiWallConstruction:SaveCornerSelected(false);
        AiWallConstruction:InitInterface();
    end);

    -- Inflict damage to walls
    QuestTools.StartInlineJob(Events.LOGIC_EVENT_EVERY_TURN, function()
        AiWallConstruction:WallBehaviorManager();
    end);

    -- Control wall segments (health and construction)
    QuestTools.StartInlineJob(Events.LOGIC_EVENT_ENTITY_HURT_ENTITY, function()
        local AttackerID = Event.GetEntityID1();
        local AttackedID = Event.GetEntityID2();
        AiWallConstruction:EntityAttackedManager(AttackerID, AttackedID);
    end);

    -- Control wall segments (health and construction)
    QuestTools.StartInlineJob(Events.LOGIC_EVENT_ENTITY_CREATED, function()
        local EntityID = Event.GetEntityID();
        local PlayerID = Logic.EntityGetPlayer(EntityID);
        -- TODO: Not needed here?
        -- AiWallConstruction:WallSegmendRegister(EntityID);
        AiWallConstruction:UpdateTowerAvailabilityForPlayer(PlayerID);
    end);
end

function AiWallConstruction:CreateSyncEvents()
    -- Segment is demolished
    self.Events.SellWallSegment = QuestSync:CreateScriptEvent(function(name, _EntityID)
        if Logic.EntityGetPlayer(_EntityID) == GUI.GetPlayerID() then
            GUI.ClearSelection();
        end
        AiWallConstruction:WallSegmendSold(_EntityID);
    end);

    -- Segment is placed
    self.Events.PlaceWallSegment = QuestSync:CreateScriptEvent(function(name, _EntityID, _Action)
        local CornerID, WallID = AiWallConstruction:WallSegmendPlace(_EntityID, _Action);
        local PlayerID = GUI.GetPlayerID();
        if (CornerID ~= 0 or WallID ~= 0) then
            if Logic.EntityGetPlayer(CornerID) == PlayerID or Logic.EntityGetPlayer(WallID) == PlayerID then
                GUI.ClearSelection();
            end
        end
        if (CornerID ~= 0 and Logic.EntityGetPlayer(CornerID) == PlayerID) then
            GUI.SelectEntity(CornerID);
        end
    end);

    -- Corner is Upgraded
    self.Events.UpgradeWallCorner = QuestSync:CreateScriptEvent(function(name, _EntityID)
        local NewID = AiWallConstruction:WallSegmendPlace(_EntityID, PlacementAction.UpgradeCorner);
        if NewID ~= 0 and Logic.EntityGetPlayer(NewID) == GUI.GetPlayerID() then
            GUI.ClearSelection();
            GUI.SelectEntity(NewID);
        end
    end);

    -- Corner Upgrade stopped
    self.Events.CancleCornerUpgrade = QuestSync:CreateScriptEvent(function(name, _EntityID)
        local NewID = AiWallConstruction:WallSegmendPlace(_EntityID, PlacementAction.CancleCornerUpgrade);
        if NewID ~= 0 and Logic.EntityGetPlayer(NewID) == GUI.GetPlayerID() then
            GUI.ClearSelection();
            GUI.SelectEntity(NewID);
        end
    end);

    -- Player opens/closes gate
    self.Events.ToggleOpenCloseGate = QuestSync:CreateScriptEvent(function(name, _EntityID)
        local NewID = AiWallConstruction:ToggleOpenCloseGate(_EntityID);
        if NewID ~= 0 and Logic.EntityGetPlayer(NewID) == GUI.GetPlayerID() then
            GUI.ClearSelection();
            GUI.SelectEntity(NewID);
        end
    end);

    -- Player toggles placement mode
    self.Events.ToggleWallPlacement = QuestSync:CreateScriptEvent(function(name, _EntityID)
        AiWallConstruction:TogglePlacementMode(Logic.EntityGetPlayer(_EntityID));
        local PlayerID = GUI.GetPlayerID();
        if Logic.EntityGetPlayer(_EntityID) == PlayerID then
            AiWallConstruction:PrepareCornerControls(_EntityID);
        end
    end);
end

-- - Controller-------------------------------------------------------------- --

function AiWallConstruction:EntityAttackedManager(_AttackerID, _AttackedID)
    local PlayerID = Logic.EntityGetPlayer(_AttackerID);
    local EntityType = Logic.GetEntityType(_AttackerID);
    if self.m_Walls[_AttackedID] then
        local Damage = Logic.GetEntityDamage(_AttackerID);
        if self.m_Walls[_AttackedID].ConstructionProgress == 1 then
            Damage = Damage * (self.Mapping:Get(PlayerID, "DamageFactor", EntityType) or 0.1);
        end
        self:WallSegmendDamage(_AttackedID, Damage);
    end
end

function AiWallConstruction:WallBehaviorManager()
    local CurrentTime = Logic.GetTime() * 10;
    for k, v in pairs(self.m_Walls) do
        if IsExisting(k) and Logic.GetEntityHealth(k) > 0 then
            local PlayerID = Logic.EntityGetPlayer(k);
            local EntityType = Logic.GetEntityType(k);
            local x, y, z  = Logic.EntityGetPos(k);
            
            if self.m_Walls[k].ConstructionProgress == 1 then
                -- Alter health
                if self.m_Walls[k].CurrentHealth > 0 then
                    local MaxHealth = self.Data:Get(EntityType, PlayerID, "MaxHealth");
                    if self.Data[EntityType] and MaxHealth > self.m_Walls[k].CurrentHealth then
                        if not QuestTools.AreEnemiesInArea(PlayerID, {X= x, Y= y}, 5000) then
                            local Factor = self.Data:Get(EntityType, PlayerID, "HealthFactor") or 0.001;
                            if Factor > 0 then
                                self.m_Walls[k].CurrentHealth = math.min(
                                    self.m_Walls[k].CurrentHealth + (MaxHealth * Factor),
                                    MaxHealth
                                );
                            end
                        end
                    end
                end
                MakeVulnerable(k);
                SetHealth(k, (self.m_Walls[k].CurrentHealth / AiWallConstruction.Data:Get(EntityType, PlayerID, "MaxHealth")) * 100);
                MakeInvulnerable(k);

                -- Control "upgrade"
                if self.Mapping.CornerType[EntityType] and v.UpgradeProgress ~= -1 then
                    if v.UpgradeProgress == 1 then
                        self.m_Walls[k].UpgradeProgress = -1;
                        local PlayerID = Logic.EntityGetPlayer(k);

                        local NewID = ReplaceEntity(k, self.Mapping.CornerToTower[EntityType]);
                        Logic.SetEntityScriptingValue(k, 20, 0);
                        DestroyEntity(v.ConstructionSiteID);
                        GameCallback_OnBuildingUpgradeComplete(k, NewID);
                    else
                        local ProgressTime = (Logic.GetTime()*10) - self.m_Walls[k].UpgradeStartTime;
                        local FinishTime = AiWallConstruction.Data:Get(EntityType, PlayerID, "UpgradeTime");
                        if not IsExisting(v.ConstructionSiteID) then
                            local SiteID = Logic.CreateEntity(Entities.XD_Rock1, x, y, 0, PlayerID);
                            Logic.SetModelAndAnimSet(SiteID, Models.ZB_ConstructionSiteTower1);
                            self.m_Walls[k].ConstructionSiteID = SiteID;
                        end
                        self.m_Walls[k].UpgradeProgress = math.min(1, ProgressTime / FinishTime);
                        Logic.SetEntityScriptingValue(k, 20, Float2Int(v.UpgradeProgress));
                    end
                end
            else
                -- Control "construction"
                local ProgressTime = (Logic.GetTime()*10) - self.m_Walls[k].PlacementTime;
                local FinishTime = AiWallConstruction.Data:Get(EntityType, PlayerID, "BuildTime");
                if not IsExisting(self.m_Walls[k].ConstructionSiteID) then
                    local SiteID = Logic.CreateEntity(Entities.XD_Rock1, x, y, 0, PlayerID);
                    Logic.SetModelAndAnimSet(SiteID, Models.ZB_ConstructionSiteTower1);
                    self.m_Walls[k].ConstructionSiteID = SiteID;
                end
                if math.mod(Logic.GetTimeMs(), 1000) == 0 then
                    Logic.CreateEffect(GGL_Effects.FXBuildingSmokeLarge, x, y, 0);
                end
                
                self.m_Walls[k].ConstructionProgress = math.min(1, ProgressTime / FinishTime);
                QuestTools.SetBuildingHeight(k, self.m_Walls[k].ConstructionProgress);
                if self.m_Walls[k].ConstructionProgress == 1 then
                    self.m_Walls[k].CurrentHealth = AiWallConstruction.Data:Get(EntityType, PlayerID, "MaxHealth");
                    GameCallback_OnBuildingConstructionComplete(k, PlayerID);
                    DestroyEntity(self.m_Walls[k].ConstructionSiteID);
                end
            end
        else
            DestroyEntity(self.m_Walls[k].ConstructionSiteID);
            self.m_Walls[k] = nil;
        end
    end
end

-- - Logic ------------------------------------------------------------------ --

function AiWallConstruction:WallSegmendPlace(_EntityID, _Action)
    if not IsExisting(_EntityID) then
        return;
    end
    local CornerID = 0;
    local WallID = 0;
    local PlayerID = Logic.EntityGetPlayer(_EntityID);
    local CornerType = self:GetCornerVariantType(PlayerID);
    local SegmentType = self:GetSegmentVariantType(PlayerID);

    if _Action == PlacementAction.UpStraight then
        local X1, Y1, X2, Y2, O = self:WallSegmendCalculatePosition(_EntityID, _Action);
        if self.m_Walls[_EntityID].UpgradeProgress == -1 then
            CornerID, WallID = self:WallSegmendConstructed(PlayerID, SegmentType, CornerType, X1, Y1, X2, Y2, O);
        end
    elseif _Action == PlacementAction.LeftStraight then
        local X1, Y1, X2, Y2, O = self:WallSegmendCalculatePosition(_EntityID, _Action);
        if self.m_Walls[_EntityID].UpgradeProgress == -1 then
            CornerID, WallID = self:WallSegmendConstructed(PlayerID, SegmentType, CornerType, X1, Y1, X2, Y2, O);
        end
    elseif _Action == PlacementAction.RightStraight then
        local X1, Y1, X2, Y2, O = self:WallSegmendCalculatePosition(_EntityID, _Action);
        if self.m_Walls[_EntityID].UpgradeProgress == -1 then
            CornerID, WallID = self:WallSegmendConstructed(PlayerID, SegmentType, CornerType, X1, Y1, X2, Y2, O);
        end
    elseif _Action == PlacementAction.DownStraight then
        local X1, Y1, X2, Y2, O = self:WallSegmendCalculatePosition(_EntityID, _Action);
        if self.m_Walls[_EntityID].UpgradeProgress == -1 then
            CornerID, WallID = self:WallSegmendConstructed(PlayerID, SegmentType, CornerType, X1, Y1, X2, Y2, O);
        end
    elseif _Action == PlacementAction.UpLeft then
        local X1, Y1, X2, Y2, O = self:WallSegmendCalculatePosition(_EntityID, _Action);
        if self.m_Walls[_EntityID].UpgradeProgress == -1 then
            CornerID, WallID = self:WallSegmendConstructed(PlayerID, SegmentType, CornerType, X1, Y1, X2, Y2, O);
        end
    elseif _Action == PlacementAction.DownLeft then
        local X1, Y1, X2, Y2, O = self:WallSegmendCalculatePosition(_EntityID, _Action);
        if self.m_Walls[_EntityID].UpgradeProgress == -1 then
            CornerID, WallID = self:WallSegmendConstructed(PlayerID, SegmentType, CornerType, X1, Y1, X2, Y2, O);
        end
    elseif _Action == PlacementAction.UpRight then
        local X1, Y1, X2, Y2, O = self:WallSegmendCalculatePosition(_EntityID, _Action);
        if self.m_Walls[_EntityID].UpgradeProgress == -1 then
            CornerID, WallID = self:WallSegmendConstructed(PlayerID, SegmentType, CornerType, X1, Y1, X2, Y2, O);
        end
    elseif _Action == PlacementAction.DownRight then
        local X1, Y1, X2, Y2, O = self:WallSegmendCalculatePosition(_EntityID, _Action);
        if self.m_Walls[_EntityID].UpgradeProgress == -1 then
            CornerID, WallID = self:WallSegmendConstructed(PlayerID, SegmentType, CornerType, X1, Y1, X2, Y2, O);
        end
    elseif _Action == PlacementAction.UpgradeCorner then
        self:WallSegmendStartCornerUpgrade(_EntityID);
    -- FIXME: Is this needed?
    elseif _Action == PlacementAction.CancleCornerUpgrade then
        self:WallSegmendStopCornerUpgrade(_EntityID);
    end
    return CornerID, WallID;
end

function AiWallConstruction:WallSegmendCalculatePosition(_EntityID, _Action)
    local PlayerID = Logic.EntityGetPlayer(_EntityID);
    local x, y, z = Logic.EntityGetPos(_EntityID);
    local SegmentType = self:GetSegmentVariantType(PlayerID);

    local PosX1, PosY1, PosX2, PosY2, Orientation;
    if _Action == PlacementAction.UpStraight then
        PosX1 = x + 300*0.7;
        PosY1 = y + 300*0.7;
        PosX2 = x + 600*0.7;
        PosY2 = y + 600*0.7;
        Orientation = 90;
        if self.Mapping.GateType[SegmentType] then
            Orientation = -45;
        end
    elseif _Action == PlacementAction.LeftStraight then
        PosX1 = x - 300*0.7;
        PosY1 = y + 300*0.7;
        PosX2 = x - 600*0.7;
        PosY2 = y + 600*0.7;
        Orientation = 0;
        if self.Mapping.GateType[SegmentType] then
            Orientation = 45;
        end
    elseif _Action == PlacementAction.RightStraight then
        PosX1 = x + 300*0.7;
        PosY1 = y - 300*0.7;
        PosX2 = x + 600*0.7;
        PosY2 = y - 600*0.7;
        Orientation = 0;
        if self.Mapping.GateType[SegmentType] then
            Orientation = 225;
        end
    elseif _Action == PlacementAction.DownStraight then
        PosX1 = x - 300*0.7;
        PosY1 = y - 300*0.7;
        PosX2 = x - 600*0.7;
        PosY2 = y - 600*0.7;
        Orientation = 270;
        if self.Mapping.GateType[SegmentType] then
            Orientation = 135;
        end
    elseif _Action == PlacementAction.UpLeft then
        PosX1 = x;
        PosY1 = y + 300;
        PosX2 = x;
        PosY2 = y + 600;
        Orientation = 135;
        if self.Mapping.GateType[SegmentType] then
            Orientation = 0;
        end
    elseif _Action == PlacementAction.DownLeft then
        PosX1 = x - 300;
        PosY1 = y;
        PosX2 = x - 600;
        PosY2 = y;
        Orientation = 225;
        if self.Mapping.GateType[SegmentType] then
            Orientation = -90;
        end
    elseif _Action == PlacementAction.UpRight then
        PosX1 = x + 300;
        PosY1 = y;
        PosX2 = x + 600;
        PosY2 = y;
        Orientation = 45;
        if self.Mapping.GateType[SegmentType] then
            Orientation = 90;
        end
    elseif _Action == PlacementAction.DownRight then
        PosX1 = x;
        PosY1 = y - 300;
        PosX2 = x;
        PosY2 = y - 600;
        Orientation = 315;
        if self.Mapping.GateType[SegmentType] then
            Orientation = 180;
        end
    end

    local Position1 = {X= PosX1, Y= PosY1};
    if not QuestTools.IsValidPosition(Position1) then
        return;
    end
    local Position2 = {X= PosX2, Y= PosY2};
    if not QuestTools.IsValidPosition(Position2) then
        return;
    end
    if self.Mapping.GateType[SegmentType] and self:IsAnyWallGateNear(PosX1, PosY1, 1000) then
        return;
    end
    return PosX1, PosY1, PosX2, PosY2, Orientation;
end

function AiWallConstruction:WallSegmendStartCornerUpgrade(_EntityID)
    if not IsExisting(_EntityID) then
        return;
    end
    local x, y, z    = Logic.EntityGetPos(_EntityID);
    local EntityType = Logic.GetEntityType(_EntityID);
    local PlayerID   = Logic.EntityGetPlayer(_EntityID);
    if  self.m_Walls[_EntityID] and self.m_Walls[_EntityID].ConstructionProgress == 1
    and not self:IsAnyWallGateNear(x, y, 500)
    and self.Mapping.CornerType[EntityType] then
        if self.m_Walls[_EntityID].UpgradeProgress == -1 then
            self.m_Walls[_EntityID].UpgradeProgress = 0;
            self.m_Walls[_EntityID].UpgradeStartTime = Logic.GetTime() * 10;
            QuestTools.RemoveResourcesFromPlayer(PlayerID, {
                [ResourceType.Stone] = 200,
                [ResourceType.Wood]  = 200,
            });
            if GUI.GetPlayerID() == PlayerID then
                GameCallback_GUI_SelectionChanged();
            end
        end
    end
end

function AiWallConstruction:WallSegmendStopCornerUpgrade(_EntityID)
    if not IsExisting(_EntityID) then
        return;
    end
    local EntityType = Logic.GetEntityType(_EntityID);
    local PlayerID   = Logic.EntityGetPlayer(_EntityID);
    if self.m_Walls[_EntityID] and self.Mapping.CornerType[EntityType] then
        if self.m_Walls[_EntityID].UpgradeProgress ~= -1 then
            self.m_Walls[_EntityID].UpgradeProgress = -1;
            Logic.SetEntityScriptingValue(_EntityID, 20, 0);
            DestroyEntity(self.m_Walls[_EntityID].ConstructionSiteID);
            QuestTools.AddResourcesToPlayer(PlayerID, {
                [ResourceType.Stone] = 200,
                [ResourceType.Wood]  = 200,
            });
            if GUI.GetPlayerID() == PlayerID then
                GameCallback_GUI_SelectionChanged();
            end
        end
    end
end

function AiWallConstruction:WallSegmendRegister(_EntityID, _Progress)
    _Progress = _Progress or 0;
    if IsExisting(_EntityID) and not self.m_Walls[_EntityID] then
        local PlayerID   = Logic.EntityGetPlayer(_EntityID);
        local EntityType = Logic.GetEntityType(_EntityID);
        if AiWallConstruction.Data[EntityType] then
            local Health   = AiWallConstruction.Data:Get(EntityType, PlayerID, "MaxHealth");
            self.m_Walls[_EntityID] = {
                CurrentHealth        = Health,
                PlacementTime        = Logic.GetTime() * 10,
                UpgradeStartTime     = 0,
                ConstructionProgress = _Progress,
                UpgradeProgress      = -1,
                ConstructionSiteID   = 0,
            };
        end
    end
end

function AiWallConstruction:WallSegmendRegisterExisting()
    for i= 1, table.getn(Score.Player), 1 do
        local PlayerEntities = QuestTools.GetPlayerEntities(i, 0);
        for j= 1, table.getn(PlayerEntities), 1 do
            local Type = Logic.GetEntityType(PlayerEntities[j]);
            if self.Data[Type] and not self.m_Walls[PlayerEntities[j]] then
                self:WallSegmendRegister(PlayerEntities[j], 1);
            end
        end
    end
end

function AiWallConstruction:WallSegmendGetCosts(_PlayerID)
    local Costs = {};
    local SegmentType = self:GetSegmentVariantType(_PlayerID);
    local CornerType  = self:GetCornerVariantType(_PlayerID);
    for k, v in pairs(self.Data:Get(SegmentType, _PlayerID, "Costs")) do
        Costs[k] = (Costs[k] or 0) + v
    end
    for k, v in pairs(self.Data:Get(CornerType, _PlayerID, "Costs")) do
        Costs[k] = (Costs[k] or 0) + v
    end
    return Costs;
end

function AiWallConstruction:WallSegmendDamage(_EntityID, _Damage, _IgnoreArmor)
    if not IsExisting(_EntityID) then
        return;
    end
    local EntityType = Logic.GetEntityType(_EntityID);
    local PlayerID   = Logic.EntityGetPlayer(_EntityID);
    if self.Data[EntityType] and self.m_Walls[_EntityID] then
        local Data = self.m_Walls[_EntityID];
        -- Apply damage
        local Damage = _Damage;
        if not _IgnoreArmor then
            local Armor = self.Data:Get(EntityType, PlayerID, "ArmorBase");
            if Logic.IsTechnologyResearched(PlayerID, Technologies.T_Masonry) == 1 then
                Armor = Armor + self.Data:Get(EntityType, PlayerID, "ArmorUpgrade");
            end
            Damage = math.max(0.1, (_Damage * 0.6) - Armor);
        end
        self.m_Walls[_EntityID].CurrentHealth = math.max(0, Data.CurrentHealth - Damage);

        -- Replace with tower if destroyed
        if Data.CurrentHealth / self.Data:Get(EntityType, PlayerID, "MaxHealth") < 0.01 then
            if self.Mapping.TowerType[EntityType] then
                ReplaceEntity(_EntityID, self.Mapping.TowerToCorner[EntityType]);
            end
        end
    end
end

function AiWallConstruction:WallSegmendSold(_EntityID)
    if not IsExisting(_EntityID) then
        return;
    end
    local PlayerID   = Logic.EntityGetPlayer(_EntityID);
    local x, y, z    = Logic.EntityGetPos(_EntityID);
    local EntityType = Logic.GetEntityType(_EntityID);
    if self.Data[EntityType] then
        local Costs = copy(self.Data:Get(EntityType, PlayerID, "Costs"));
        for i= 2, table.getn(Costs), 2 do
            Costs[i] = math.floor(Costs[i] / 2);
        end
        QuestTools.AddResourcesToPlayer(PlayerID, Costs);
    end
    Logic.CreateEffect(GGL_Effects.FXCrushBuilding, x, y, 0);
    DestroyEntity(_EntityID);
end

function AiWallConstruction:WallSegmendConstructed(_PlayerID, _WallType, _CornerType, _X1, _Y1, _X2, _Y2, _Orientation)
    local WallID, CornerID;
    
    local Position1 = {X= _X1, Y= _Y1};
    if not _X1 or not QuestTools.IsValidPosition(Position1) then
        return 0;
    end
    local Position2 = {X= _X2, Y= _Y2};
    if not _X2 or not QuestTools.IsValidPosition(Position2) then
        return 0;
    end

    if not QuestTools.AreEnemiesInArea(_PlayerID, Position1, 5000) then
        if  not self:IsAnyWallNear(_X1, _Y1, 250) and not self:IsAreaOffLimitsForPlayer(_PlayerID, _X1, _Y1) 
        and self:IsShallowEnough(_X1, _Y1, 250) then
            WallID = Logic.CreateEntity(_WallType, _X1, _Y1, _Orientation, _PlayerID);
            if  not self:IsAnyWallNear(_X2, _Y2, 250) and not self:IsAreaOffLimitsForPlayer(_PlayerID, _X2, _Y2) 
            and self:IsShallowEnough(_X2, _Y2, 100) then
                CornerID = Logic.CreateEntity(_CornerType, _X2, _Y2, _Orientation -45, _PlayerID);
            end
        end
    end
    if self.Data[_WallType] and IsExisting(WallID) then
        QuestTools.RemoveResourcesFromPlayer(_PlayerID, self.Data:Get(_WallType, _PlayerID, "Costs"));
        self:WallSegmendRegister(WallID);
    end
    if self.Data[_CornerType] and IsExisting(CornerID) then
        QuestTools.RemoveResourcesFromPlayer(_PlayerID, self.Data:Get(_CornerType, _PlayerID, "Costs"));
        self:WallSegmendRegister(CornerID);
    end
    return CornerID, WallID;
end

function AiWallConstruction:WallSegmendIsConstructionComplete(_EntityID)
    if not IsExisting(_EntityID) or not self.m_Walls[_EntityID] then
        return false;
    end
    return self.m_Walls[_EntityID].ConstructionProgress == 1;
end

function AiWallConstruction:IsAnyWallNear(_X, _Y, _Area)
    for i= 1, table.getn(Score.Player), 1 do
        for k, v in pairs(AiWallConstruction.Data) do
            local n, EntityID = Logic.GetPlayerEntitiesInArea(i, k, _X, _Y, _Area, 1);
            if n > 0 then
                return true;
            end
        end
        for k, v in pairs(self.Mapping.TowerType) do
            local n, EntityID = Logic.GetPlayerEntitiesInArea(i, k, _X, _Y, _Area, 1);
            if n > 0 then
                return true;
            end
        end
    end
    return false;
end

function AiWallConstruction:IsAnyWallGateNear(_X, _Y, _Area)
    for i= 1, table.getn(Score.Player), 1 do
        for k, v in pairs(AiWallConstruction.Mapping.GateType) do
            local n, EntityID = Logic.GetPlayerEntitiesInArea(i, k, _X, _Y, _Area, 1);
            if n > 0 then
                return true;
            end
        end
    end
    return false;
end

function AiWallConstruction:IsShallowEnough(_X, _Y, _Height)
    local Heights = {};
    for x = -200, 200, 200 do
        for y = -200, 200, 200 do
            local ID = Logic.CreateEntity(Entities.XD_ScriptEntity, _X+x, _Y+y, 0, 8);
            if IsExisting(ID) then
                local _,_,z = Logic.EntityGetPos(ID);
                table.insert(Heights, z);
                DestroyEntity(ID);
            end
        end
    end

    local Highest = math.max(unpack(Heights));
    local Lowest  = math.min(unpack(Heights));
    if math.abs(Highest-Lowest) <= _Height then
        return true
    end
    return false;
end

function AiWallConstruction:GetSegmentVariantType(_PlayerID)
    if self.m_PlacedWallMode[_PlayerID] == WallPlacement.Gate then
        if self.m_PlacedWallType[_PlayerID] == WallVariant.Dark then
            return Entities.XD_DarkWallStraightGate;
        end
        return Entities.XD_WallStraightGate;
    else
        if self.m_PlacedWallType[_PlayerID] == WallVariant.Dark then
            return Entities.XD_DarkWallDistorted;
        end
        return Entities.XD_WallDistorted;
    end
end

function AiWallConstruction:GetCornerVariantType(_PlayerID)
    if self.m_PlacedWallType[_PlayerID] == WallVariant.Dark then
        return Entities.XD_DarkWallCorner;
    end
    return Entities.XD_WallCorner;
end

function AiWallConstruction:GetTowerVariantType(_PlayerID)
    if self.m_PlacedWallType[_PlayerID] == WallVariant.Dark then
        return Entities.PB_DarkTower1;
    end
    return Entities.PB_Tower1;
end

function AiWallConstruction:ToggleOpenCloseGate(_EntityID)
    if not self.m_Walls[_EntityID] or self.m_Walls[_EntityID].ConstructionProgress < 1 then
        return 0;
    end
    local EntityType = Logic.GetEntityType(_EntityID);
    if self.Mapping.OpenCloseGate[EntityType] == nil then
        return 0;
    end
    local Segment = copy(self.m_Walls[_EntityID]);
    local NewID = ReplaceEntity(_EntityID, self.Mapping.OpenCloseGate[EntityType]);
    self.m_Walls[_EntityID] = nil;
    self.m_Walls[NewID] = Segment;
    return NewID;
end

function AiWallConstruction:TogglePlacementMode(_PlayerID)
    if self.m_PlacedWallMode[_PlayerID] then
        if self.m_PlacedWallMode[_PlayerID] == WallPlacement.Gate then
            self.m_PlacedWallMode[_PlayerID] = WallPlacement.Wall;
        else
            self.m_PlacedWallMode[_PlayerID] = WallPlacement.Gate;
        end
    end
end

function AiWallConstruction:SetPlacementMode(_PlayerID, _Mode)
    if self.m_PlacedWallMode[_PlayerID] then
        self.m_PlacedWallMode[_PlayerID] = _Mode;
    end
end

function AiWallConstruction:ToggleVariantType(_PlayerID)
    if self.m_PlacedWallType[_PlayerID] then
        if self.m_PlacedWallType[_PlayerID] == WallPlacement.Dark then
            self.m_PlacedWallType[_PlayerID] = WallPlacement.Normal;
        else
            self.m_PlacedWallType[_PlayerID] = WallPlacement.Dark;
        end
    end
end

function AiWallConstruction:SetPlacementType(_PlayerID, _Type)
    if self.m_PlacedWallType[_PlayerID] then
        self.m_PlacedWallType[_PlayerID] = _Type;
    end
end

function AiWallConstruction:IsTowerLimitReached(_PlayerID)
    if self.m_TowerLimit == -1 then
        return false;
    end
    if self.m_TowerLimit == 0 then
        return true;
    end
    local TowerAmount = 0;
    for k, v in pairs (TowerLimitTypes) do
        TowerAmount = TowerAmount + Logic.GetNumberOfEntitiesOfTypeOfPlayer(_PlayerID, v);
    end
    for k, v in pairs(self.m_Walls) do
        if AiWallConstruction.Mapping.TowerType[k] and v.Upgrade > 0 then
            TowerAmount = TowerAmount + 1;
        end
    end
    return TowerAmount >= self.m_TowerLimit;
end

function AiWallConstruction:SetTowerLimit(_Limit)
    self.m_TowerLimit = _Limit;
end

function AiWallConstruction:UpdateTowerAvailabilityForPlayer(_PlayerID)
    if self:IsTowerLimitReached(_PlayerID) then
        ForbidTechnology(Technologies.B_Tower, _PlayerID);
    else
        AllowTechnology(Technologies.B_Tower, _PlayerID);
    end
end

function AiWallConstruction:SetAreaLimitationMode(_PlayerID, _Mode)
    self.m_AreaLimitation[_PlayerID].Mode = _Mode;
end

function AiWallConstruction:SetConstructionDisabledInAreaForPlayer(_ScriptName, _PlayerID, _Area)
    self.m_AreaLimitation[_PlayerID] = self.m_AreaLimitation[_PlayerID] or {};
    if _Area == nil then
        self.m_AreaLimitation[_PlayerID][_ScriptName] = nil;
    else
        self.m_AreaLimitation[_PlayerID][_ScriptName] = _Area;
    end
end

function AiWallConstruction:IsAreaOffLimitsForPlayer(_PlayerID, _X, _Y)
    for k, v in pairs(self.m_AreaLimitation[_PlayerID]) do
        -- TODO: Use polygone?
        if QuestTools.GetDistance({X= _X, Y= _Y}, k) <= v then
            return true;
        end
    end
    return false;
end

-- - GUI -------------------------------------------------------------------- --

function AiWallConstruction:InitInterface()
    self:InitLocalKeyBingings();
    self:InitLocalOverride();
    self:HealthAndArmorDisplay();
    self:OverrideInterfaceAction();
    self:OverrideInterfaceTooltip();
    self:OverrideInterfaceUpdate();
end

function AiWallConstruction:HealthAndArmorDisplay()
    GUIUpdate_Armor_Orig_WallConstruction = GUIUpdate_Armor;
    GUIUpdate_Armor = function()		
        local SelectedID = GUI.GetSelectedEntity();
        if AiWallConstruction.m_Walls[SelectedID] then
            local PlayerID = Logic.EntityGetPlayer(SelectedID);
            local EntityType = Logic.GetEntityType(SelectedID);
            local Armor = AiWallConstruction.Data:Get(EntityType, PlayerID, "ArmorBase");
            if Logic.IsTechnologyResearched(PlayerID, Technologies.T_Masonry) == 1 then
                Armor = Armor + AiWallConstruction.Data:Get(EntityType, PlayerID, "ArmorUpgrade");
            end
            XGUIEng.SetText("DetailsArmor_Amount"," @ra "..Armor);
        else
            GUIUpdate_Armor_Orig_WallConstruction()
        end
	end

    GUIUpdate_DetailsHealthPoints_Orig_WallConstruction = GUIUpdate_DetailsHealthPoints;
	GUIUpdate_DetailsHealthPoints = function()	
        local SelectedID = GUI.GetSelectedEntity();
        if AiWallConstruction.m_Walls[SelectedID] then
            local PlayerID = Logic.EntityGetPlayer(SelectedID);
            local EntityType = Logic.GetEntityType(SelectedID);
            local Health = math.ceil(AiWallConstruction.m_Walls[SelectedID].CurrentHealth);
            local MaxHealth = AiWallConstruction.Data:Get(EntityType, PlayerID, "MaxHealth");
            XGUIEng.SetText("DetailsHealth_Amount"," @center "..Health.."/"..MaxHealth);
        else
            GUIUpdate_DetailsHealthPoints_Orig_WallConstruction()
        end
	end

    GUIUpate_DetailsHealthBar_Orig_WallConstruction = GUIUpate_DetailsHealthBar;
	GUIUpate_DetailsHealthBar = function()
        local SelectedID = GUI.GetSelectedEntity();
        if AiWallConstruction.m_Walls[SelectedID] then
            local CurrentWidgetID = XGUIEng.GetCurrentWidgetID();
            local PlayerID = Logic.EntityGetPlayer(SelectedID);
            local PlayerColor = {GUI.GetPlayerColor(PlayerID)};
            local EntityType = Logic.GetEntityType(SelectedID);
            local Health = AiWallConstruction.m_Walls[SelectedID].CurrentHealth;
            local MaxHealth = AiWallConstruction.Data:Get(EntityType, PlayerID, "MaxHealth");
            XGUIEng.SetMaterialColor(CurrentWidgetID, 0, PlayerColor[1], PlayerColor[2], PlayerColor[3], 170);
            XGUIEng.SetProgressBarValues(CurrentWidgetID, Health, MaxHealth);
        else
            GUIUpate_DetailsHealthBar_Orig_WallConstruction()
        end
	end
end

function AiWallConstruction:OverrideInterfaceAction()
    if not GUIAction_ReserachTechnology_Orig_WallConstruction then
        GUIAction_ReserachTechnology_Orig_WallConstruction = GUIAction_ReserachTechnology;
        GUIAction_ReserachTechnology = function(_Technology)
            local WidgetID = XGUIEng.GetCurrentWidgetID();
            local SelectedID = GUI.GetSelectedEntity();
            local EntityType = Logic.GetEntityType(SelectedID);
            if self.Mapping.CornerType[EntityType] or self.Mapping.TowerType[EntityType] then
                if _Technology == Technologies.GT_Tactics then
                    AiWallConstruction:FeedbackPlacementMode(SelectedID)
                -- Upper Left
                elseif _Technology == Technologies.GT_Trading then
                    AiWallConstruction:FeedbackPlaceSegment(SelectedID, PlacementAction.UpLeft);
                -- Up
                elseif _Technology == Technologies.GT_Printing then
                    AiWallConstruction:FeedbackPlaceSegment(SelectedID, PlacementAction.UpStraight);
                -- Upper Right
                elseif _Technology == Technologies.GT_Library then
                    AiWallConstruction:FeedbackPlaceSegment(SelectedID, PlacementAction.UpRight);
                -- Left
                elseif _Technology == Technologies.GT_StandingArmy then
                    AiWallConstruction:FeedbackPlaceSegment(SelectedID, PlacementAction.LeftStraight);
                -- Right
                elseif _Technology == Technologies.GT_Strategies then
                    AiWallConstruction:FeedbackPlaceSegment(SelectedID, PlacementAction.RightStraight);
                -- Lower Left
                elseif _Technology == Technologies.GT_Taxation then
                    AiWallConstruction:FeedbackPlaceSegment(SelectedID, PlacementAction.DownLeft);
                -- Down
                elseif _Technology == Technologies.GT_Laws then
                    AiWallConstruction:FeedbackPlaceSegment(SelectedID, PlacementAction.DownStraight);
                -- Lower Right
                elseif _Technology == Technologies.GT_Banking then
                    AiWallConstruction:FeedbackPlaceSegment(SelectedID, PlacementAction.DownRight);
                end
            else
                GUIAction_ReserachTechnology_Orig_WallConstruction(_Technology);
            end
        end
    end

    if not GUIAction_UpgradeSelectedBuilding_Orig_WallConstruction then
        GUIAction_UpgradeSelectedBuilding_Orig_WallConstruction = GUIAction_UpgradeSelectedBuilding;
        GUIAction_UpgradeSelectedBuilding = function()
            local SelectedID = GUI.GetSelectedEntity();
            local EntityType = Logic.GetEntityType(SelectedID);
            if AiWallConstruction.Mapping.CornerType[EntityType] then
                AiWallConstruction:FeedbackUpgradeWallCorner(SelectedID);
            elseif AiWallConstruction.Mapping.GateType[EntityType] then
                AiWallConstruction:FeedbackOpenCloseGame(SelectedID);
            else
                GUIAction_UpgradeSelectedBuilding_Orig_WallConstruction();
            end
        end
    end

    if not GUIAction_CancelUpgrade_Orig_WallConstruction then
        GUIAction_CancelUpgrade_Orig_WallConstruction = GUIAction_CancelUpgrade;
        GUIAction_CancelUpgrade = function()
            local SelectedID = GUI.GetSelectedEntity();
            local EntityType = Logic.GetEntityType(SelectedID);
            if AiWallConstruction.Mapping.CornerType[EntityType] then
                AiWallConstruction:FeedbackStopUpgradeWallCorner(SelectedID);
            else
                GUIAction_CancelUpgrade_Orig_WallConstruction();
            end
        end
    end
end

function AiWallConstruction:OverrideInterfaceTooltip()
    if not GUITooltip_ResearchTechnologies_Orig_WallConstruction then
        GUITooltip_ResearchTechnologies_Orig_WallConstruction = GUITooltip_ResearchTechnologies;
        GUITooltip_ResearchTechnologies = function(_Technology, _Tooltip, _HotKey)
            local WidgetID = XGUIEng.GetCurrentWidgetID();
            local SelectedID = GUI.GetSelectedEntity();
            local PlayerID = Logic.EntityGetPlayer(SelectedID);
            local EntityType = Logic.GetEntityType(SelectedID);
            if AiWallConstruction.Mapping.CornerType[EntityType] or AiWallConstruction.Mapping.TowerType[EntityType] then
                if XGUIEng.IsButtonDisabled(WidgetID) == 0 then
                    local ToolTip = AiWallConstruction.Text.Tooltip.Technologies[_Technology];
                    if ToolTip then
                        local Costs = AiWallConstruction:WallSegmendGetCosts(PlayerID);
                        local CostString = InterfaceTool_CreateCostString(Costs);
                        local DescString = QuestTools.GetLocalizedTextInTable(ToolTip);
                        local KeyString = QuestTools.GetLocalizedTextInTable(ToolTip.Hotkey);
                        XGUIEng.SetText(gvGUI_WidgetID.TooltipBottomCosts, CostString);
                        XGUIEng.SetText(gvGUI_WidgetID.TooltipBottomText, DescString);
                        XGUIEng.SetText(gvGUI_WidgetID.TooltipBottomShortCut, KeyString);
                    end
                else
                    local DescTable  = AiWallConstruction.Text.Tooltip.DisabledConstruction;
                    local DescString = QuestTools.GetLocalizedTextInTable(DescTable);
                    XGUIEng.SetText(gvGUI_WidgetID.TooltipBottomCosts, "");
                    XGUIEng.SetText(gvGUI_WidgetID.TooltipBottomText, DescString);
                    XGUIEng.SetText(gvGUI_WidgetID.TooltipBottomShortCut, "");
                end
            else
                GUITooltip_ResearchTechnologies_Orig_WallConstruction(_Technology, _Tooltip, _HotKey);
            end
        end
    end

    if not GUITooltip_UpgradeBuilding_Orig_WallConstruction then
        GUITooltip_UpgradeBuilding_Orig_WallConstruction = GUITooltip_UpgradeBuilding;
        GUITooltip_UpgradeBuilding = function(_EntityType, _Disabled, _Normal, _Technology)
            local SelectedID = GUI.GetSelectedEntity();
            local EntityType = Logic.GetEntityType(SelectedID);
            if AiWallConstruction.Mapping.CornerType[EntityType] then
                GUITooltip_ConstructBuilding(UpgradeCategories.Tower,"MenuSerf/Tower_normal","MenuSerf/Tower_disabled", Technologies.B_Tower,"KeyBindings/UpgradeBuilding");
            else
                GUITooltip_UpgradeBuilding_Orig_WallConstruction(_EntityType, _Disabled, _Normal, _Technology);
            end
        end
    end
end

function AiWallConstruction:OverrideInterfaceUpdate()
    if not GUIUpdate_GlobalTechnologiesButtons_Orig_WallConstruction then
        GUIUpdate_GlobalTechnologiesButtons_Orig_WallConstruction = GUIUpdate_GlobalTechnologiesButtons;
        GUIUpdate_GlobalTechnologiesButtons = function(_Button, _Technology, _Type)
            local SelectedID = GUI.GetSelectedEntity();
            local EntityType = Logic.GetEntityType(SelectedID);
            if AiWallConstruction.Mapping.CornerType[EntityType] or AiWallConstruction.Mapping.TowerType[EntityType] then
                -- Do nothing
            elseif EntityType == Entities.PB_University1 or EntityType == Entities.PB_University2 then
                GUIUpdate_GlobalTechnologiesButtons_Orig_WallConstruction(_Button, _Technology, _Type);
            else
                GUIUpdate_GlobalTechnologiesButtons_Orig_WallConstruction(_Button, _Technology, _Type);
            end
        end
    end

    if GUIUpdate_UpgradeButtons then
        GUIUpdate_UpgradeButtons_Orig_WallConstruction = GUIUpdate_UpgradeButtons;
        GUIUpdate_UpgradeButtons = function(_Button, _Technology)
            local SelectedID = GUI.GetSelectedEntity();
            local PlayerID = Logic.EntityGetPlayer(SelectedID);
            local EntityType = Logic.GetEntityType(SelectedID);
            if _Button == "Upgrade_University1" then
                if not AiWallConstruction.Mapping.CornerType[EntityType] and not AiWallConstruction.Mapping.TowerType[EntityType] then
                    GUIUpdate_UpgradeButtons_Orig_WallConstruction(_Button, _Technology);
                else
                    if Logic.IsTechnologyResearched(PlayerID, Technologies.GT_Construction) == 1 then
                        XGUIEng.DisableButton(_Button, 0);
                    end
                end
            else
                GUIUpdate_UpgradeButtons_Orig_WallConstruction(_Button, _Technology);
            end
        end
    end

    if not GUIUpdate_UpgradeProgress_Orig_WallConstruction then
        GUIUpdate_UpgradeProgress_Orig_WallConstruction = GUIUpdate_UpgradeProgress;
        GUIUpdate_UpgradeProgress = function()
            GUIUpdate_UpgradeProgress_Orig_WallConstruction();

            local CurrentWidgetID = XGUIEng.GetCurrentWidgetID();
            local BuildingID = GUI.GetSelectedEntity();
            local EntityType = Logic.GetEntityType(BuildingID);
            if AiWallConstruction.Mapping.CornerType[EntityType] then
                local Data = AiWallConstruction.m_Walls[BuildingID];
                if Data and Data.UpgradeProgress ~= -1 then
                    XGUIEng.SetProgressBarValues(CurrentWidgetID, 100 * Data.UpgradeProgress, 100);
                end
            end
        end
    end
    
    if not GameCallback_GUI_SelectionChanged_Orig_WallConstruction then
        GameCallback_GUI_SelectionChanged_Orig_WallConstruction = GameCallback_GUI_SelectionChanged;
        GameCallback_GUI_SelectionChanged = function()
            GameCallback_GUI_SelectionChanged_Orig_WallConstruction()
            AiWallConstruction:PrepareCornerControls();
            AiWallConstruction:ResetCornerControls();
            -- TODO: Put this on a hotkey?
            -- AiWallConstruction:ShowDebugInformation();
        end
    end

    if not GameCallback_OnBuildingConstructionComplete_Orig_WallConstruction then
        GameCallback_OnBuildingConstructionComplete_Orig_WallConstruction = GameCallback_OnBuildingConstructionComplete;
        GameCallback_OnBuildingConstructionComplete = function(_EntityID, _PlayerID)
            GameCallback_OnBuildingConstructionComplete_Orig_WallConstruction(_EntityID, _PlayerID)
            AiWallConstruction:WallSegmendRegister(_EntityID);
            AiWallConstruction:PrepareCornerControls();
            AiWallConstruction:ResetCornerControls();
        end
    end

    if not GameCallback_OnBuildingUpgradeComplete_Orig_WallConstruction then
        GameCallback_OnBuildingUpgradeComplete_Orig_WallConstruction = GameCallback_OnBuildingUpgradeComplete;
        GameCallback_OnBuildingUpgradeComplete = function(_EntityID_Old, _EntityID_New)
            GameCallback_OnBuildingUpgradeComplete_Orig_WallConstruction(_EntityID_Old, _EntityID_New)
            AiWallConstruction:PrepareCornerControls();
            AiWallConstruction:ResetCornerControls();
            AiWallConstruction:UpdateTowerAvailabilityForPlayer(Logic.EntityGetPlayer(_EntityID_New));
        end
    end

    if not GameCallback_OnTechnologyResearched_Orig_WallConstruction then
        GameCallback_OnTechnologyResearched_Orig_WallConstruction = GameCallback_OnTechnologyResearched;
        GameCallback_OnTechnologyResearched = function(_PlayerID, _Technology, _EntityID)
            GameCallback_OnTechnologyResearched_Orig_WallConstruction(_PlayerID, _Technology, _EntityID);
            AiWallConstruction:PrepareCornerControls();
            AiWallConstruction:ResetCornerControls();
        end
    end
end

function AiWallConstruction:WasCornerSelected()
    return self.l_CornerSelected == true;
end

function AiWallConstruction:SaveCornerSelected(_Flag)
    self.l_CornerSelected = _Flag == true;
end

function AiWallConstruction:ShowDebugInformation()
    local SelectedID = GUI.GetSelectedEntity();
    local PlayerID   = Logic.EntityGetPlayer(SelectedID);
    local GUIPlayer  = GUI.GetPlayerID();
    local EntityType = Logic.GetEntityType(SelectedID);
    if IsExisting(SelectedID) and (self.Mapping.CornerType[EntityType] or self.Mapping.TowerType[EntityType]) then
        Display.SetRenderLandscapeDebugInfo(1);
    else
        Display.SetRenderLandscapeDebugInfo(0);
    end
end

function AiWallConstruction:PrepareCornerControls()
    local SelectedID = GUI.GetSelectedEntity();
    local PlayerID = Logic.EntityGetPlayer(SelectedID);
    if not IsExisting(SelectedID) or GUI.GetPlayerID() ~= PlayerID then
        return;
    end
    local EntityType = Logic.GetEntityType(SelectedID);
    if self.Mapping.CornerType[EntityType] or self.Mapping.TowerType[EntityType] then
        if not self:WasCornerSelected() then
            self:SaveCornerSelected(true);
            XGUIEng.TransferMaterials("Research_Construction", "Upgrade_Farm1");
            XGUIEng.TransferMaterials("Research_Literacy", "Upgrade_Farm2");
            XGUIEng.TransferMaterials("Research_Trading", "Upgrade_Residence1");
            XGUIEng.TransferMaterials("Research_Printing", "Upgrade_Residence2");
            XGUIEng.TransferMaterials("Research_Library", "Upgrade_Blacksmith1");
            XGUIEng.TransferMaterials("Research_Taxation", "Upgrade_Blacksmith2");
            XGUIEng.TransferMaterials("Research_Banking", "Upgrade_Alchemist1");
            XGUIEng.TransferMaterials("Research_Guilds", "Upgrade_Archery1");
            XGUIEng.TransferMaterials("Research_Laws", "Upgrade_Barracks1");
            XGUIEng.TransferMaterials("Research_Mercenaries", "Trade_Market_DecreaseClay");
            XGUIEng.TransferMaterials("Research_StandingArmy", "Trade_Market_IncreaseClay");
            XGUIEng.TransferMaterials("Research_Tactics", "Trade_Market_DecreaseWood");
            XGUIEng.TransferMaterials("Research_Strategies", "Trade_Market_IncreaseWood");
        end

        local Construction = Logic.IsTechnologyResearched(PlayerID, Technologies.GT_Construction) == 1;
        XGUIEng.ShowWidget("University", 1);
        XGUIEng.ShowWidget("Commands_University", 1);
        XGUIEng.ShowWidget("Upgrade_University1", (Construction and self.Mapping.TowerType[EntityType] and 0) or 1);
        XGUIEng.TransferMaterials("Upgrade_Claymine1", "Upgrade_University1");

        XGUIEng.SetWidgetPosition("Research_Trading", 160, 4);
        XGUIEng.SetWidgetPosition("Research_Printing", 196, 4);
        XGUIEng.SetWidgetPosition("Research_Library", 233, 4);
        XGUIEng.SetWidgetPosition("Research_StandingArmy", 160, 40);
        XGUIEng.SetWidgetPosition("Research_Tactics", 196, 40);
        XGUIEng.SetWidgetPosition("Research_Strategies", 233, 40);
        XGUIEng.SetWidgetPosition("Research_Taxation", 160, 74);
        XGUIEng.SetWidgetPosition("Research_Laws", 196, 74);
        XGUIEng.SetWidgetPosition("Research_Banking", 233, 74);
        
        if self.m_PlacedWallMode[PlayerID] == WallPlacement.Gate then
            XGUIEng.TransferMaterials("ExpelSerf", "Research_Tactics");
        else
            XGUIEng.TransferMaterials("Upgrade_Farm1", "Research_Tactics");
        end
        XGUIEng.TransferMaterials("SetVeryHighTaxes", "Research_Trading");
        XGUIEng.TransferMaterials("SetVeryHighTaxes", "Research_Printing");
        XGUIEng.TransferMaterials("SetVeryHighTaxes", "Research_Library");
        XGUIEng.TransferMaterials("SetVeryHighTaxes", "Research_StandingArmy");
        XGUIEng.TransferMaterials("SetVeryHighTaxes", "Research_Strategies");
        XGUIEng.TransferMaterials("SetVeryHighTaxes", "Research_Banking");
        XGUIEng.TransferMaterials("SetVeryHighTaxes", "Research_Taxation");
        XGUIEng.TransferMaterials("SetVeryHighTaxes", "Research_Laws");

        XGUIEng.DisableButton("Upgrade_University1", (Construction and 0) or 1);
        XGUIEng.DisableButton("Research_StandingArmy", (Construction and 0) or 1);
        XGUIEng.DisableButton("Research_Tactics", (Construction and 0) or 1);
        XGUIEng.DisableButton("Research_Strategies", (Construction and 0) or 1);
        XGUIEng.DisableButton("Research_Trading", (Construction and 0) or 1);
        XGUIEng.DisableButton("Research_Printing", (Construction and 0) or 1);
        XGUIEng.DisableButton("Research_Library", (Construction and 0) or 1);
        XGUIEng.DisableButton("Research_Taxation", (Construction and 0) or 1);
        XGUIEng.DisableButton("Research_Laws", (Construction and 0) or 1);
        XGUIEng.DisableButton("Research_Banking", (Construction and 0) or 1);
        
        XGUIEng.ShowWidget("Research_Construction", 0);
        XGUIEng.ShowWidget("Research_ChainBlock", 0);
        XGUIEng.ShowWidget("Research_GearWheel", 0);
        XGUIEng.ShowWidget("Research_Architecture", 0);
        XGUIEng.ShowWidget("Research_Alchemy", 0);
        XGUIEng.ShowWidget("Research_Alloying", 0);
        XGUIEng.ShowWidget("Research_Metallurgy", 0);
        XGUIEng.ShowWidget("Research_Chemistry", 0);
        XGUIEng.ShowWidget("Research_Mercenaries", 0);
        XGUIEng.ShowWidget("Research_StandingArmy", 1);
        XGUIEng.ShowWidget("Research_Tactics", 1);
        XGUIEng.ShowWidget("Research_Strategies", 1);
        XGUIEng.ShowWidget("Research_Literacy", 0);
        XGUIEng.ShowWidget("Research_Trading", 1);
        XGUIEng.ShowWidget("Research_Printing", 1);
        XGUIEng.ShowWidget("Research_Library", 1);
        XGUIEng.ShowWidget("Research_Mathematics", 0);
        XGUIEng.ShowWidget("Research_Binocular", 0);
        XGUIEng.ShowWidget("Research_Matchlock", 0);
        XGUIEng.ShowWidget("Research_PulledBarrel", 0);
        XGUIEng.ShowWidget("Research_Taxation", 1);
        XGUIEng.ShowWidget("Research_Banking", 1);
        XGUIEng.ShowWidget("Research_Guilds", 0);
        XGUIEng.ShowWidget("Research_Laws", 1);

        if self.m_Walls[SelectedID] and self.m_Walls[SelectedID].UpgradeProgress ~= -1 then
            if self.Mapping.CornerType[EntityType] then
                XGUIEng.TransferMaterials("Upgrade_University1", "Cancelupgrade");
                XGUIEng.ShowWidget("UpgradeInProgress", 1);
                XGUIEng.ShowWidget("University", 0);
            end
        end
    end
end

function AiWallConstruction:ResetCornerControls()
    local SelectedID = GUI.GetSelectedEntity();
    local PlayerID = Logic.EntityGetPlayer(SelectedID);
    if not IsExisting(SelectedID) or GUI.GetPlayerID() ~= PlayerID then
        return;
    end
    local EntityType = Logic.GetEntityType(SelectedID);
    if  (not self.Mapping.CornerType[EntityType] and not self.Mapping.TowerType[EntityType]) then
        local ButtonVisible = 0;
        if EntityType == Entities.PB_University1 or EntityType == Entities.PB_University2 then
            ButtonVisible = 1;
        end
        
        if self:WasCornerSelected() and ButtonVisible == 1 then
            self:SaveCornerSelected(false);
            XGUIEng.TransferMaterials("Upgrade_Farm1", "Research_Construction");
            XGUIEng.TransferMaterials("Upgrade_Claymine1", "Upgrade_Farm1");
            XGUIEng.TransferMaterials("Upgrade_Farm2", "Research_Literacy");
            XGUIEng.TransferMaterials("Upgrade_Claymine1", "Upgrade_Farm2");
            XGUIEng.TransferMaterials("Upgrade_Residence1", "Research_Trading");
            XGUIEng.TransferMaterials("Upgrade_Claymine1", "Upgrade_Residence1");
            XGUIEng.TransferMaterials("Upgrade_Residence2", "Research_Printing");
            XGUIEng.TransferMaterials("Upgrade_Claymine1", "Upgrade_Residence2");
            XGUIEng.TransferMaterials("Upgrade_Blacksmith1", "Research_Library");
            XGUIEng.TransferMaterials("Upgrade_Claymine1", "Upgrade_Blacksmith1");
            XGUIEng.TransferMaterials("Upgrade_Blacksmith2", "Research_Taxation");
            XGUIEng.TransferMaterials("Upgrade_Claymine1", "Upgrade_Blacksmith2");
            XGUIEng.TransferMaterials("Upgrade_Alchemist1", "Research_Banking");
            XGUIEng.TransferMaterials("Upgrade_Claymine1", "Upgrade_Alchemist1");
            XGUIEng.TransferMaterials("Upgrade_Archery1", "Research_Guilds");
            XGUIEng.TransferMaterials("Upgrade_Claymine1", "Upgrade_Archery1");
            XGUIEng.TransferMaterials("Upgrade_Barracks1", "Research_Laws");
            XGUIEng.TransferMaterials("Upgrade_Claymine1", "Upgrade_Barracks1");
            XGUIEng.TransferMaterials("Trade_Market_DecreaseClay", "Research_Mercenaries");
            XGUIEng.TransferMaterials("Trade_Market_DecreaseMoney", "Trade_Market_DecreaseClay");
            XGUIEng.TransferMaterials("Trade_Market_IncreaseClay", "Research_StandingArmy");
            XGUIEng.TransferMaterials("Trade_Market_IncreaseMoney", "Trade_Market_IncreaseClay");
            XGUIEng.TransferMaterials("Trade_Market_DecreaseWood", "Research_Tactics");
            XGUIEng.TransferMaterials("Trade_Market_DecreaseMoney", "Trade_Market_DecreaseWood");
            XGUIEng.TransferMaterials("Trade_Market_IncreaseWood", "Research_Strategies");
            XGUIEng.TransferMaterials("Trade_Market_IncreaseMoney", "Trade_Market_IncreaseWood");
        end

        if self.Mapping.GateType[EntityType] then
            if self.m_Walls[SelectedID] and self.m_Walls[SelectedID].ConstructionProgress == 1 then
                if EntityType == Entities.XD_DarkWallStraightGate
                or EntityType == Entities.XD_WallStraightGate then
                    XGUIEng.TransferMaterials("HQ_CallMilitia", "Upgrade_University1");
                else
                    XGUIEng.TransferMaterials("HQ_BackToWork", "Upgrade_University1");
                end
                XGUIEng.ShowWidget("University", 1);
                XGUIEng.ShowWidget("Upgrade_University1", 1);
                XGUIEng.DisableButton("Upgrade_University1", 0);
            end
        else
            XGUIEng.TransferMaterials("Upgrade_Claymine1", "Upgrade_University1");
        end
        XGUIEng.SetWidgetPosition("Research_Trading", 220, 4);
        XGUIEng.SetWidgetPosition("Research_Printing", 256, 4);
        XGUIEng.SetWidgetPosition("Research_Library", 293, 4);
        XGUIEng.SetWidgetPosition("Research_StandingArmy", 220, 40);
        XGUIEng.SetWidgetPosition("Research_Tactics", 256, 40);
        XGUIEng.SetWidgetPosition("Research_Strategies", 293, 40);
        XGUIEng.SetWidgetPosition("Research_Taxation", 220, 74);
        XGUIEng.SetWidgetPosition("Research_Laws", 256, 74);
        XGUIEng.SetWidgetPosition("Research_Banking", 293, 74);

        XGUIEng.ShowWidget("Upgrade_University1", 1);
        XGUIEng.ShowWidget("Research_Construction", ButtonVisible);
        XGUIEng.ShowWidget("Research_ChainBlock", ButtonVisible);
        XGUIEng.ShowWidget("Research_GearWheel", ButtonVisible);
        XGUIEng.ShowWidget("Research_Architecture", ButtonVisible);
        XGUIEng.ShowWidget("Research_Alchemy", ButtonVisible);
        XGUIEng.ShowWidget("Research_Alloying", ButtonVisible);
        XGUIEng.ShowWidget("Research_Metallurgy", ButtonVisible);
        XGUIEng.ShowWidget("Research_Chemistry", ButtonVisible);
        XGUIEng.ShowWidget("Research_Mercenaries", ButtonVisible);
        XGUIEng.ShowWidget("Research_StandingArmy", ButtonVisible);
        XGUIEng.ShowWidget("Research_Tactics", ButtonVisible);
        XGUIEng.ShowWidget("Research_Strategies", ButtonVisible);
        XGUIEng.ShowWidget("Research_Literacy", ButtonVisible);
        XGUIEng.ShowWidget("Research_Trading", ButtonVisible);
        XGUIEng.ShowWidget("Research_Printing", ButtonVisible);
        XGUIEng.ShowWidget("Research_Library", ButtonVisible);
        XGUIEng.ShowWidget("Research_Mathematics", ButtonVisible);
        XGUIEng.ShowWidget("Research_Binocular", ButtonVisible);
        XGUIEng.ShowWidget("Research_Matchlock", ButtonVisible);
        XGUIEng.ShowWidget("Research_PulledBarrel", ButtonVisible);
        XGUIEng.ShowWidget("Research_Taxation", 0);
        XGUIEng.ShowWidget("Research_Banking", 0);
        XGUIEng.ShowWidget("Research_Guilds", 0);
        XGUIEng.ShowWidget("Research_Laws", 0);
    end
end

function AiWallConstruction:InitLocalKeyBingings()
    Input.KeyBindDown(Keys.NumPad1, "AiWallConstruction:FeedbackPlaceSegment(GUI.GetSelectedEntity(), PlacementAction.DownLeft)", 2);
    Input.KeyBindDown(Keys.NumPad2, "AiWallConstruction:FeedbackPlaceSegment(GUI.GetSelectedEntity(), PlacementAction.DownStraight)", 2);
    Input.KeyBindDown(Keys.NumPad3, "AiWallConstruction:FeedbackPlaceSegment(GUI.GetSelectedEntity(), PlacementAction.DownRight)", 2);
    Input.KeyBindDown(Keys.NumPad4, "AiWallConstruction:FeedbackPlaceSegment(GUI.GetSelectedEntity(), PlacementAction.LeftStraight)", 2);
    Input.KeyBindDown(Keys.NumPad5, "AiWallConstruction:FeedbackPlacementMode(GUI.GetSelectedEntity())", 2);
    Input.KeyBindDown(Keys.NumPad6, "AiWallConstruction:FeedbackPlaceSegment(GUI.GetSelectedEntity(), PlacementAction.RightStraight)", 2);
    Input.KeyBindDown(Keys.NumPad7, "AiWallConstruction:FeedbackPlaceSegment(GUI.GetSelectedEntity(), PlacementAction.UpLeft)", 2);
    Input.KeyBindDown(Keys.NumPad8, "AiWallConstruction:FeedbackPlaceSegment(GUI.GetSelectedEntity(), PlacementAction.UpStraight)", 2);
    Input.KeyBindDown(Keys.NumPad9, "AiWallConstruction:FeedbackPlaceSegment(GUI.GetSelectedEntity(), PlacementAction.UpRight)", 2);
    Input.KeyBindDown(Keys.NumPad0, "AiWallConstruction:FeedbackOpenCloseGame(GUI.GetSelectedEntity())", 2);
end

function AiWallConstruction:InitLocalOverride()
    GUI.SellBuilding_Orig_WallConstruction = GUI.SellBuilding
    GUI.SellBuilding = function(_EntityID)
        local Type = Logic.GetEntityType(_EntityID);
        if AiWallConstruction.Data[Type] then
            QuestSync:SynchronizedCall(AiWallConstruction.Events.SellWallSegment, _EntityID);
        else
            GUI.SellBuilding_Orig_WallConstruction(_EntityID);
        end
        GUI.DeselectEntity(_EntityID);
    end
end

function AiWallConstruction:FeedbackPlaceSegment(_EntityID, _Action)
    if not IsExisting(_EntityID) then
        return;
    end
    local PlayerID = Logic.EntityGetPlayer(_EntityID);
    local x, y, z  = Logic.EntityGetPos(_EntityID);
    local Costs    = self:WallSegmendGetCosts(PlayerID);
    
    local X1, Y1, X2, Y2, O = self:WallSegmendCalculatePosition(_EntityID, _Action);

    if Logic.IsTechnologyResearched(PlayerID, Technologies.GT_Construction) == 0 then
        return;
    end
    if not InterfaceTool_HasPlayerEnoughResources_Feedback(Costs) then
        return;
    end
    if not X1 or not X2 or not self:IsShallowEnough(X1, Y1, 250)
    or self:IsAreaOffLimitsForPlayer(PlayerID, X1, Y1)
    or self:IsAnyWallNear(X1, Y1, 250) then
        local Text = QuestTools.GetLocalizedTextInTable(self.Text.Message.GeneralImpossible);
        Message(Text);
        Sound.PlayFeedbackSound(Sounds.Leader_LEADER_NO_rnd_01);
        return;
    end
    if QuestTools.AreEnemiesInArea(PlayerID, {X= X1, Y= Y1}, 5000) then
        local Text = QuestTools.GetLocalizedTextInTable(self.Text.Message.EnemyToClose);
        Message(Text);
        Sound.PlayFeedbackSound(Sounds.Leader_LEADER_NO_rnd_01);
        return;
    end
    QuestSync:SynchronizedCall(self.Events.PlaceWallSegment, _EntityID, _Action);
end

function AiWallConstruction:FeedbackUpgradeWallCorner(_EntityID)
    if not IsExisting(_EntityID) then
        return;
    end
    local PlayerID = Logic.EntityGetPlayer(_EntityID);
    if Logic.IsTechnologyResearched(PlayerID, Technologies.GT_Construction) == 0 then
        return;
    end
    if self.m_Walls[_EntityID] and self.m_Walls[_EntityID].ConstructionProgress ~= 1 then
        return;
    end
    local Costs = {
        [ResourceType.Stone] = 200,
        [ResourceType.Wood]  = 200,
    };
    if not InterfaceTool_HasPlayerEnoughResources_Feedback(Costs) then
        return;
    end
    QuestSync:SynchronizedCall(self.Events.UpgradeWallCorner, _EntityID);
end

function AiWallConstruction:FeedbackStopUpgradeWallCorner(_EntityID)
    if not IsExisting(_EntityID) then
        return;
    end
    QuestSync:SynchronizedCall(self.Events.CancleCornerUpgrade, _EntityID);
end

function AiWallConstruction:FeedbackPlacementMode(_EntityID)
    if not IsExisting(_EntityID) then
        return;
    end
    local PlayerID = Logic.EntityGetPlayer(_EntityID);
    if Logic.IsTechnologyResearched(PlayerID, Technologies.GT_Construction) == 0 then
        return;
    end
    QuestSync:SynchronizedCall(self.Events.ToggleWallPlacement, _EntityID);
end

function AiWallConstruction:FeedbackOpenCloseGame(_EntityID)
    if not IsExisting(_EntityID) then
        return;
    end
    QuestSync:SynchronizedCall(self.Events.ToggleOpenCloseGate, _EntityID);
end

-- - Data ------------------------------------------------------------------- --

---
-- List of tower types.
--
TowerLimitTypes = {
    Entities.PB_DarkTower1,
    Entities.PB_DarkTower2,
    Entities.PB_DarkTower3,
    Entities.PB_Tower1,
    Entities.PB_Tower2,
    Entities.PB_Tower3
}

---
-- Placement mode for next segment.
-- @field Wall Wall is build next
-- @field Gate Gate is build next
--
WallPlacement = {
    Wall = 1,
    Gate = 2,
};

---
-- Placement mode for next segment.
-- @field Normal Normal types are placed
-- @field Dark Dark types are placed
--
WallVariant = {
    Normal = 1,
    Dark   = 2,
};

---
-- Possible placement actions.
-- @field UpStraight          Place segment north of position
-- @field LeftStraight        Place segment west of position
-- @field RightStraight       Place segment east of position
-- @field DownStraight        Place segment south of position
-- @field UpLeft              Place segment north west of position
-- @field UpRight             Place segment north east of position
-- @field DownLeft            Place segment south west of position
-- @field DownRight           Place segment south east of position
-- @field UpgradeCorner       Upgrade the current corner to a tower
-- @field CancleCornerUpgrade Cancel upgrade of current corner
--
PlacementAction = {
    UpStraight = 1,
    LeftStraight = 2,
    RightStraight = 3,
    DownStraight = 4,
    UpLeft = 5,
    UpRight = 6,
    DownLeft = 7,
    DownRight = 8,
    UpgradeCorner = 9,
    CancleCornerUpgrade = 10,
};

AiWallConstruction.Text = {
    Message = {
        EnemyToClose = {
            de = "Der Feind ist zu nahe um zu bauen!",
            en = "The enemy is to close to build!",
        },
        GeneralImpossible = {
            de = "Das ist hier nicht möglich!",
            en = "This is impossible here!",
        },
    },
    
    Tooltip = {
        Technologies = {
            -- Toggle gate
            [Technologies.GT_Tactics] = {
                Hotkey = {
                    de = "Taste: [Num 5]",
                    en = "Key: [Num 5]",
                },
                de     = " @color:180,180,180 Mauer/Tor umschalten @color:255,255,255 @cr Wählt den Baumodus für das nächste Segment.",
                en     = " @color:180,180,180 Toggle Gate/Wall @color:255,255,255 @cr Choose the construction mode for the next segment."
            },
            -- Upper Left
            [Technologies.GT_Trading] = {
                Hotkey = {
                    de = "Taste: [Num 7]",
                    en = "Key: [Num 7]",
                },
                de     = " @color:180,180,180 Mauerstück Nordwest @color:255,255,255 @cr Setzt die Mauer um ein weiteres Segment fort.",
                en     = " @color:180,180,180 Segment North-West @color:255,255,255 @cr Continue the wall with a new segment."
            },
            -- Up
            [Technologies.GT_Printing] = {
                Hotkey = {
                    de = "Taste: [Num 8]",
                    en = "Key: [Num 8]",
                },
                de     = " @color:180,180,180 Mauerstück Nord @color:255,255,255 @cr Setzt die Mauer um ein weiteres Segment fort.",
                en     = " @color:180,180,180 Segment North @color:255,255,255 @cr Continue the wall with a new segment."
            },
            -- Upper Right
            [Technologies.GT_Library] = {
                Hotkey = {
                    de = "Taste: [Num 9]",
                    en = "Key: [Num 9]",
                },
                de     = " @color:180,180,180 Mauerstück Nordost @color:255,255,255 @cr Setzt die Mauer um ein weiteres Segment fort.",
                en     = " @color:180,180,180 Segment North-East @color:255,255,255 @cr Continue the wall with a new segment."
            },
            -- Left
            [Technologies.GT_StandingArmy] = {
                Hotkey = {
                    de = "Taste: [Num 4]",
                    en = "Key: [Num 4]",
                },
                de     = " @color:180,180,180 Mauerstück Westen @color:255,255,255 @cr Setzt die Mauer um ein weiteres Segment fort.",
                en     = " @color:180,180,180 Segment West @color:255,255,255 @cr Continue the wall with a new segment."
            },
            -- Right
            [Technologies.GT_Strategies] = {
                Hotkey = {
                    de = "Taste: [Num 6]",
                    en = "Key: [Num 6]",
                },
                de     = " @color:180,180,180 Mauerstück Osten @color:255,255,255 @cr Setzt die Mauer um ein weiteres Segment fort.",
                en     = " @color:180,180,180 Segment East @color:255,255,255 @cr Continue the wall with a new segment."
            },
            -- Lower Left
            [Technologies.GT_Taxation] = {
                Hotkey = {
                    de = "Taste: [Num 1]",
                    en = "Key: [Num 1]",
                },
                de     = " @color:180,180,180 Mauerstück Südwest @color:255,255,255 @cr Setzt die Mauer um ein weiteres Segment fort.",
                en     = " @color:180,180,180 Segment South-West @color:255,255,255 @cr Continue the wall with a new segment."
            },
            -- Down
            [Technologies.GT_Laws] = {
                Hotkey = {
                    de = "Taste: [Num 2]",
                    en = "Key: [Num 2]",
                },
                de     = " @color:180,180,180 Mauerstück Süden @color:255,255,255 @cr Setzt die Mauer um ein weiteres Segment fort.",
                en     = " @color:180,180,180 Segment South @color:255,255,255 @cr Continue the wall with a new segment."
            },
            -- Lower Right
            [Technologies.GT_Banking] = {
                Hotkey = {
                    de = "Taste: [Num 3]",
                    en = "Key: [Num 4]",
                },
                de     = " @color:180,180,180 Mauerstück Südost @color:255,255,255 @cr Setzt die Mauer um ein weiteres Segment fort.",
                en     = " @color:180,180,180 Segment South-East @color:255,255,255 @cr Continue the wall with a new segment."
            },
        },
        DisabledConstruction = {
            de = " @color:180,180,180 Mauerbau @cr @color:255,200,0 benötigt: @color:255,255,255 Konstruktion",
            en = " @color:180,180,180 Wall Construction @cr @color:255,200,0 requires: @color:255,255,255 Construction"
        }
    },
};

AiWallConstruction.Data = {
    [Entities.XD_WallStraightGate_Closed]     = {
        MaxHealth    = 3000,
        HealthFactor = 0.0005,
        BuildTime    = 450,
        UpgradeTime  = 0,
        ArmorBase    = 10,
        ArmorUpgrade = 5,
        Costs        = {
            [ResourceType.Gold]   = 0,
            [ResourceType.Clay]   = 200,
            [ResourceType.Wood]   = 200,
            [ResourceType.Stone]  = 200,
            [ResourceType.Iron]   = 0,
            [ResourceType.Sulfur] = 0,
            [ResourceType.Silver] = 0,
        }
    },
    [Entities.XD_WallStraightGate]            = {
        MaxHealth    = 3000,
        HealthFactor = 0.0005,
        BuildTime    = 450,
        UpgradeTime  = 0,
        ArmorBase    = 10,
        ArmorUpgrade = 5,
        Costs        = {
            [ResourceType.Gold]   = 0,
            [ResourceType.Clay]   = 200,
            [ResourceType.Wood]   = 200,
            [ResourceType.Stone]  = 200,
            [ResourceType.Iron]   = 0,
            [ResourceType.Sulfur] = 0,
            [ResourceType.Silver] = 0,
        }
    },
    [Entities.XD_WallDistorted]               = {
        MaxHealth    = 3000,
        HealthFactor = 0.001,
        BuildTime    = 450,
        UpgradeTime  = 0,
        ArmorBase    = 12,
        ArmorUpgrade = 8,
        Costs        = {
            [ResourceType.Gold]   = 0,
            [ResourceType.Clay]   = 100,
            [ResourceType.Wood]   = 0,
            [ResourceType.Stone]  = 100,
            [ResourceType.Iron]   = 0,
            [ResourceType.Sulfur] = 0,
            [ResourceType.Silver] = 0,
        }
    },
    [Entities.XD_WallStraight]                = {
        MaxHealth    = 3000,
        HealthFactor = 0.001,
        BuildTime    = 450,
        UpgradeTime  = 0,
        ArmorBase    = 12,
        ArmorUpgrade = 8,
        Costs        = {
            [ResourceType.Gold]   = 0,
            [ResourceType.Clay]   = 100,
            [ResourceType.Wood]   = 0,
            [ResourceType.Stone]  = 100,
            [ResourceType.Iron]   = 0,
            [ResourceType.Sulfur] = 0,
            [ResourceType.Silver] = 0,
        }
    },
    [Entities.XD_WallCorner]                  = {
        MaxHealth    = 3000,
        HealthFactor = 0.001,
        BuildTime    = 450,
        UpgradeTime  = 100,
        ArmorBase    = 14,
        ArmorUpgrade = 9,
        Costs        = {
            [ResourceType.Gold]   = 0,
            [ResourceType.Clay]   = 50,
            [ResourceType.Wood]   = 0,
            [ResourceType.Stone]  = 50,
            [ResourceType.Iron]   = 0,
            [ResourceType.Sulfur] = 0,
            [ResourceType.Silver] = 0,
        }
    },
    [Entities.XD_DarkWallStraightGate_Closed] = {
        MaxHealth    = 3000,
        HealthFactor = 0.0005,
        BuildTime    = 450,
        UpgradeTime  = 0,
        ArmorBase    = 10,
        ArmorUpgrade = 5,
        Costs        = {
            [ResourceType.Gold]   = 0,
            [ResourceType.Clay]   = 200,
            [ResourceType.Wood]   = 200,
            [ResourceType.Stone]  = 200,
            [ResourceType.Iron]   = 0,
            [ResourceType.Sulfur] = 0,
            [ResourceType.Silver] = 0,
        }
    },
    [Entities.XD_DarkWallStraightGate]        = {
        MaxHealth    = 3000,
        HealthFactor = 0.0005,
        BuildTime    = 450,
        UpgradeTime  = 0,
        ArmorBase    = 10,
        ArmorUpgrade = 5,
        Costs        = {
            [ResourceType.Gold]   = 0,
            [ResourceType.Clay]   = 200,
            [ResourceType.Wood]   = 200,
            [ResourceType.Stone]  = 200,
            [ResourceType.Iron]   = 0,
            [ResourceType.Sulfur] = 0,
            [ResourceType.Silver] = 0,
        }
    },
        [Entities.XD_DarkWallDistorted]       = {
        MaxHealth    = 3000,
        HealthFactor = 0.001,
        BuildTime    = 450,
        UpgradeTime  = 0,
        ArmorBase    = 12,
        ArmorUpgrade = 8,
        Costs        = {
            [ResourceType.Gold]   = 0,
            [ResourceType.Clay]   = 100,
            [ResourceType.Wood]   = 0,
            [ResourceType.Stone]  = 100,
            [ResourceType.Iron]   = 0,
            [ResourceType.Sulfur] = 0,
            [ResourceType.Silver] = 0,
        }
    },
    [Entities.XD_DarkWallStraight]            = {
        MaxHealth    = 3000,
        HealthFactor = 0.001,
        BuildTime    = 450,
        UpgradeTime  = 0,
        ArmorBase    = 12,
        ArmorUpgrade = 8,
        Costs        = {
            [ResourceType.Gold]   = 0,
            [ResourceType.Clay]   = 100,
            [ResourceType.Wood]   = 0,
            [ResourceType.Stone]  = 100,
            [ResourceType.Iron]   = 0,
            [ResourceType.Sulfur] = 0,
            [ResourceType.Silver] = 0,
        }
    },
    [Entities.XD_DarkWallCorner]              = {
        MaxHealth    = 3000,
        HealthFactor = 0.001,
        BuildTime    = 450,
        UpgradeTime  = 100,
        ArmorBase    = 14,
        ArmorUpgrade = 9,
        Costs        = {
            [ResourceType.Gold]   = 0,
            [ResourceType.Clay]   = 50,
            [ResourceType.Wood]   = 0,
            [ResourceType.Stone]  = 50,
            [ResourceType.Iron]   = 0,
            [ResourceType.Sulfur] = 0,
            [ResourceType.Silver] = 0,
        }
    },

    Get = function(self, _Type, _PlayerID, _Property)
        self:Init(_Type, _PlayerID);
        if not _PlayerID then
            return self[_Type][_Property];
        end
        return self[_Type][_PlayerID][_Property];
    end,

    Set = function(self, _Type, _PlayerID, _Property, _Value)
        self:Init(_Type, _PlayerID);
        if not _PlayerID then
            self[_Type][_Property] = _Value;
        end
        self[_Type][_PlayerID][_Property] = _Value;
    end,

    Init = function(self, _Type, _PlayerID)
        if not self[_Type] then
            self[_Type] = {};
        end
        if _PlayerID and not self[_Type][_PlayerID] then
            self[_Type][_PlayerID] = {
                MaxHealth    = self[_Type].MaxHealth,
                HealthFactor = self[_Type].HealthFactor,
                BuildTime    = self[_Type].BuildTime,
                UpgradeTime  = self[_Type].UpgradeTime,
                ArmorBase    = self[_Type].ArmorBase,
                ArmorUpgrade = self[_Type].ArmorUpgrade,
                Costs        = copy(self[_Type].Costs);
            }
        end
    end,
};

AiWallConstruction.Mapping = {
    CornerType = {
        [Entities.XD_DarkWallCorner] = true,
        [Entities.XD_WallCorner]     = true,
    },
    CornerToTower = {
        [Entities.XD_DarkWallCorner] = Entities.PB_DarkTower1,
        [Entities.XD_WallCorner]     = Entities.PB_Tower1,
    },
    DamageFactor = {
        [Entities.PV_Cannon1] = 0.5,
        [Entities.PV_Cannon2] = 1.0,
        [Entities.PV_Cannon3] = 0.5,
        [Entities.PV_Cannon4] = 1.0,
    },
    GateType = {
        [Entities.XD_DarkWallStraightGate_Closed] = true,
        [Entities.XD_DarkWallStraightGate]        = true,
        [Entities.XD_WallStraightGate_Closed]     = true,
        [Entities.XD_WallStraightGate]            = true,
    },
    OpenCloseGate = {
        [Entities.XD_DarkWallStraightGate_Closed] = Entities.XD_DarkWallStraightGate,
        [Entities.XD_WallStraightGate_Closed]     = Entities.XD_WallStraightGate,
        [Entities.XD_DarkWallStraightGate]        = Entities.XD_DarkWallStraightGate_Closed,
        [Entities.XD_WallStraightGate]            = Entities.XD_WallStraightGate_Closed,
    },
    TowerToCorner = {
        [Entities.PB_DarkTower1] = Entities.XD_DarkWallCorner,
        [Entities.PB_Tower1]     = Entities.XD_WallCorner,
    },
    TowerType = {
        [Entities.PB_DarkTower1] = true,
        [Entities.PB_DarkTower2] = true,
        [Entities.PB_DarkTower2] = true,
        [Entities.PB_Tower1]     = true,
        [Entities.PB_Tower2]     = true,
        [Entities.PB_Tower3]     = true,
    },
    VariantDark = {
        [Entities.XD_DarkWallStraightGate_Closed] = true,
        [Entities.XD_DarkWallStraightGate]        = true,
        [Entities.XD_DarkWallStraight]            = true,
        [Entities.XD_DarkWallDistorted]           = true,
    },
    VariantNormal = {
        [Entities.XD_WallStraightGate_Closed] = true,
        [Entities.XD_WallStraightGate]        = true,
        [Entities.XD_WallStraight]            = true,
        [Entities.XD_WallDistorted]           = true,
    },
    WallType = {
        [Entities.XD_DarkWallStraight]  = true,
        [Entities.XD_DarkWallDistorted] = true,
        [Entities.XD_WallStraight]      = true,
        [Entities.XD_WallDistorted]     = true,
    },

    Get = function(self, _PlayerID, _Property, _Type)
        self:Init(_Property, _PlayerID);
        if not _PlayerID then
            return self[_Property][_Type];
        end
        return self[_PlayerID][_Property][_Type];
    end,

    Set = function(self, _Type, _PlayerID, _Property, _Type, _Value)
        self:Init(_Property, _PlayerID);
        if not _PlayerID then
            self[_Property][_Type] = _Value;
        end
        self[_PlayerID][_Property][_Type] = _Value;
    end,

    Init = function(self, _Property, _PlayerID)
        if not self[_Property] then
            self[_Property] = {};
        end
        if _PlayerID and (not self[_PlayerID] or not self[_PlayerID][_Property]) then
            self[_PlayerID]            = {};
            self[_PlayerID][_Property] = copy(self[_Property]);
        end
    end,
};

