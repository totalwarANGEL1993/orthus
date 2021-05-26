-- ########################################################################## --
-- #  AI Army                                                               # --
-- #  --------------------------------------------------------------------  # --
-- #    Author:   totalwarANGEL                                             # --
-- ########################################################################## --

---
-- This module is used by the AI controller to create armies. Overwriting
-- functions of the army is at your own risk.
--
-- <b>Required modules:</b>
-- <ul>
-- <li>qsb.oop</li>
-- <li>qsb.core.questsync</li>
-- <li>qsb.core.questtools</li>
-- <li>qsb.ext.aitrooprecruiter</li>
-- <li>qsb.ext.aitroopspawner</li>
-- </ul>
--
-- @set sort=true
--

---
-- Table of states.
-- @field Idle Army is waiting for a command
-- @field Advance Amry is moving to a target
-- @field Battle Army is defending itself
-- @field Obliberate Army is destroying all enemies at the target
-- @field Guard Army is guarding a position
-- @field Defeat Troops are defeated and remaining troops will be discarded
-- @field Retreat Army makes an orderly retreat to the home base
-- @field Refill Army is requesting new soldiers from the producers
--
ArmyStates = {
    Idle       = 1,
    Advance    = 2,
    Battle     = 3,
    Obliberate = 4,
    Guard      = 5,
    Defeat     = 6,
    Retreat    = 7,
    Refill     = 8,
};

---
-- Table of sub states.
-- @field None Army is doing their assiged task
-- @field Assemble Army is scattered and is moving together
--
ArmySubStates = {
    None      = 1,
    Assemble  = 2,
};

AiArmy = {
    PlayerID             = -1,
    ArmyID               = -1,
    State                = ArmyStates.Idle;
    Troops               = {},
    AbandonedTroops      = {},
    TroopProperties      = {};
    TroopCount           = 8;
    RodeLength           = 3000;
    OuterRange           = 0;
    AbandonStrength      = 0.15;
    RefillStrength       = 0.75;
    LastTick             = 0;
    Producers            = {},

    AttackAllowed        = true,
    DefendAllowed        = true,
    IsRespawningArmy     = false,
    InitialSpawned       = false,
    IsHiddenFromAI       = false,
    IsIgnoringProducer   = false,

    Target               = nil,
    AttackTarget         = nil,
    GuardTarget          = nil,
    BattleTarget         = nil,
    GuardStartTime       = 0,
    GuardMaximumTime     = 2*60*10,
    AssembleTimer        = 0,
    GuardPosList         = {Visited = {}},
    HomePosition         = nil,
}

AiArmyControllerJobId = nil;
AiArmyAttackedJobId = nil;
AiArmyCurrentArmy = 0;
AiArmyIdSequence = 0;
AiArmyTroopIDToArmyID = {};
AiArmyList = {};

-- -------------------------------------------------------------------------- --

function AiArmy:construct(_PlayerID, _Home, _Range, _TroopAmount)
    AiArmyIdSequence = AiArmyIdSequence +1;
    self.PlayerID = _PlayerID;
    self.ArmyID = AiArmyIdSequence;
    self.HomePosition = _Home;
    self.RodeLength = _Range;
    self.OuterRange = _Range * 0.75;
    self.TroopCount = _TroopAmount;

    self:StartControllerJob();
    table.insert(AiArmyList, self);
end
class(AiArmy);

function AiArmy:StartControllerJob()
    -- Controller
    if not AiArmyControllerJobId then
        AiArmyControllerJobId = QuestTools.StartSimpleHiResJobEx(function()
            return AiArmy:ArmyOperationController();
        end);
    end

    -- Attack reaction
    if not AiArmyAttackedJobId then
        AiArmyAttackedJobId = QuestTools.StartInlineJob(Events.LOGIC_EVENT_ENTITY_HURT_ENTITY, function()
            local Offender = Event.GetEntityID1();
            local Defender = {Event.GetEntityID2()};
            return AiArmy:ArmyAttackedReactionController(Offender, Defender);
        end);
    end
end

function AiArmy:GetTime()
    return math.floor(Logic.GetTime() * 10);
end

---
-- Adds the producer to the army.
--
-- @param[type=table] _Producer Producer instance
-- @within Properties
--
function AiArmy:AddProducer(_Producer)
    if not _Producer.IsSpawner and self.IsRespawningArmy then
        return;
    end
    if _Producer.IsRecruiter and not self.IsRespawningArmy then
        return;
    end
    for k, v in pairs(self.Producers) do
        if v and v.ScriptName == _Producer.ScriptName then
            return;
        end
    end
    table.insert(self.Producers, _Producer);
    return self;
end

---
-- Removes the producer from the army.
--
-- @param[type=string] _ScriptName Name of producer
-- @within Properties
--
function AiArmy:DropProducer(_ScriptName)
    local Index = 0;
    for k, v in pairs(self.Producers) do
        if v and v.ScriptName == _ScriptName then
            Index = k;
            break;
        end
    end
    if Index > 0 then
        self.Producers[Index] = nil;
    end
    table.sort(self.Producers);
    return self;
end

function AiArmy:Yield()
    self.Troops = {};
    self.ArmyIsPaused = true;
    return self;
end

function AiArmy:Resume()
    self.ArmyIsPaused = false;
    self.ArmyIsDead = false;
    self:StartControllerJob();
    return self;
end

function AiArmy:Disband(_DestroyTroops, _KillProducer)
    if _KillProducer then
        for k, v in pairs(self.Producers) do
            if v and IsExisting(v.ScriptName) then
                if Logic.IsBuilding(GetID(v.ScriptName)) == 1 then
                    SetHealth(v.ScriptName, 0);
                else
                    DestroyEntity(v.ScriptName);
                end
            end
        end
    end
    self.Producers = {};

    if _DestroyTroops then
        for i= table.getn(self.Troops), 1, -1 do
            if IsExisting(self.Troops[i]) then
                if Logic.IsHero(self.Troops[i]) == 0 then
                    if Logic.IsLeader(self.Troops[i]) == 1 then
                        local Soldiers = {Logic.GetSoldiersAttachedToLeader(self.Troops[i])};
                        for j= Soldiers[1]+1, 2, -1 do
                            SetHealth(Soldiers[j], 0);
                        end
                    end
                    SetHealth(self.Troops[i], 0);
                else
                    Logic.SetTaskList(self.Troops[i], TaskLists.TL_DIE);
                end
            end
        end
    end
    self.Troops = {};

    self.ArmyIsDead = true;
    return self;
end

function AiArmy:IsActive()
    return self.ArmyIsPaused ~= true;
end

---
-- Checks if an army is dead.
--
-- @return[type=boolean] Army is dead
-- @within Properties
--
function AiArmy:IsDead()
    if self.ArmyIsDead == true then
        return true;
    end
    for k, v in pairs(self.Producers) do
        if v and IsExisting(v.ScriptName) then
            return false;
        end
    end
    if not self.IsRespawningArmy or self.IsIgnoringProducer then
        return false;
    end
    return true;
end

---
-- Sets the IsDead flag of the army.
--
-- @param[type=boolean] _Flag Army defeated flag
-- @within Properties
--
function AiArmy:SetIsDead(_Flag)
    self.ArmyIsDead = _Flag == true;
    return self;
end

---
-- Checks if an army is fighting. If any member is fighting then the army is
-- fighting.
--
-- @return[type=boolean] Army is fighting
-- @within Properties
--
function AiArmy:IsFighting()
    for i= table.getn(self.Troops), 1, -1 do
        local Task = Logic.GetCurrentTaskList(self.Troops[i]);
        if Task then
            return string.find(Task, "BATTLE") ~= nil;
        end
    end
    return false;
end

---
-- Checks if an army is moving.
--
-- @return[type=boolean] Army is moving
-- @within Properties
--
function AiArmy:IsMoving()
    for i= table.getn(self.Troops), 1, -1 do
        if Logic.IsEntityMoving(self.Troops[i]) == true then
            return true;
        end
    end
    return false;
end

---
-- Checks if a troop of the army is fighting.
--
-- @param[type=number] _TroopID ID of troop
-- @return[type=boolean] Troop is fighting
-- @within Properties
--
function AiArmy:IsTroopFighting(_TroopID)
    if IsExisting(_TroopID) then
        local Task = Logic.GetCurrentTaskList(_TroopID);
        return not Task or string.find(Task, "BATTLE") ~= nil;
    end
    return false;
end

-- -------------------------------------------------------------------------- --

---
-- Checks if the passed entity ID is member of the army.
--
-- @param[type=number] _TroopID ID of troop
-- @return[type=number] Current army members
-- @within Properties
--
function AiArmy:GetArmyTroops()
    return self.Troops;
end

---
-- Checks if the passed entity ID is member of the army.
--
-- @param[type=number] _TroopID ID of troop
-- @return[type=boolean] Is in army
-- @within Properties
--
function AiArmy:IsInArmy(_TroopID)
    if AiArmyTroopIDToArmyID[_TroopID] then
        if IsExisting(_TroopID) and Logic.GetEntityHealth(_TroopID) > 0 then
            return AiArmyTroopIDToArmyID[_TroopID] == self.ArmyID;
        end
        AiArmyTroopIDToArmyID[_TroopID] = nil;
    end
    -- for i= 1, table.getn(self.Troops), 1 do
    --     if self.Troops[i] == _TroopID then
    --         return true;
    --     end
    -- end
    return false;
end

---
-- Hides the army from the AI.
--
-- @param[type=boolean] _Flag Hidden flag
-- @within Properties
--
function AiArmy:SetHiddenFromAI(_Flag)
    self.IsHiddenFromAI = _Flag == true;
    return self;
end

---
-- Returns the current target of the army. The target might be the attack target
-- or the guard target.
--
-- @return[type=number] Current target
-- @within Properties
--
function AiArmy:GetTarget()
    return self.Target;
end

---
-- Returns the current attack target or attack target path.
--
-- @return[type=table] Current attack target
-- @within Properties
--
function AiArmy:GetAttackTarget()
    return self.AttackTarget;
end

---
-- Returns the current attack target index.
--
-- @return[type=number] Index of attack target
-- @within Properties
--
function AiArmy:GetAttackTargetIndex()
    if self.AttackTarget then
        return self.AttackTarget.Current;
    end
    return 0;
end

---
-- Sets the attack target.
--
-- The target can also be a table of positions. In this case only the last
-- entry is the target position. The others before are the path the army
-- will walk while moving to the destination.
--
-- @param _Target Entity or table with path
-- @within Properties
--
function AiArmy:SetAttackTarget(_Target)
    if _Target ~= nil and type(_Target) ~= "table" then
        _Target = {_Target};
    end
    self.AttackTarget = _Target;
    if self.AttackTarget then
        self.AttackTarget.Current = 1;
    end
    return self;
end

function AiArmy:SetBattleTarget(_Target)
    self.BattleTarget = _Target;
    return self;
end

---
-- Sets the index of the current attack target. This is only relevant if a
-- path was set as attack target.
--
-- @param[type=number] _Index Index of current waypoint
-- @within Properties
--
function AiArmy:SetAttackTargetIndex(_Index)
    if self.AttackTarget then
        self.AttackTarget.Current = _Index;
        if _Index < 1 or table.getn(self.AttackTarget) > _Index then
            self.AttackTarget.Current = 1;
        end
    end
    return self;
end

---
-- Returns if the army is allowed to attack.
--
-- @return[type=boolean] Attack is allowed
-- @within Properties
--
function AiArmy:IsAttackAllowed()
    return self.AttackAllowed == true;
end

---
-- Set the flag if the army is allowed to attack. This must be taken into
-- account by the extern army controller.
--
-- @param[type=boolean] _Flag Attack allowed flag
-- @within Properties
--
function AiArmy:SetAttackAllowed(_Flag)
    self.AttackAllowed = _Flag == true;
    return self;
end

---
-- Sets the current guard target of the army.
--
-- @param[type=number] _Target Current guard target
-- @within Properties
--
function AiArmy:SetGuardTarget(_Target)
    self.GuardTarget = _Target;
    return self;
end

---
-- Sets how long a guard position is guarded before the army returns to the
-- home base. Set this to -1 to let them guard forever.
--
-- @param[type=number] _Time Guard time in seconds
-- @within Properties
--
function AiArmy:SetGuardDuration(_Time)
    self.GuardMaximumTime = _Time;
    return self;
end

---
-- Sets the List of guard positions.
--
-- @param[type=table] _List List of guard positions
-- @within Properties
--
function AiArmy:SetGuardPosList(_List)
    self.GuardPosList = _List;
    self.GuardPosList.Visited = {};
    return self;
end

---
-- Registers a guard position to be visited.
--
-- @param[type=number] _Position Position to be registered
-- @within Properties
--
function AiArmy:AddVisitedGuardPosition(_Position)
    table.insert(self.GuardPosList.Visited, _Position);
    return self;
end

---
-- Clears the list of visited guard positions.
--
-- @within Properties
--
function AiArmy:ClearVisitedGuardPositions()
    self.GuardPosList.Visited = {};
    return self;
end

---
-- Returns if the army is allowed to defend.
--
-- @return[type=boolean] Defend is allowed
-- @within Properties
--
function AiArmy:IsGuardAllowed()
    return self.DefendAllowed == true;
end

---
-- Set the flag if the army is allowed to defend. This must be taken into
-- account by the extern army controller.
--
-- @param[type=boolean] _Flag Defend allowed flag
-- @within Properties
--
function AiArmy:SetGuardAllowed(_Flag)
    self.DefendAllowed = _Flag == true;
    return self;
end

function AiArmy:SetState(_State)
    self.State = _State;
    return self;
end

function AiArmy:SetSubState(_State)
    self.SubState = _State;
    return self;
end

-- -------------------------------------------------------------------------- --

function AiArmy:CallGetArmyOrientation()
    if self.ArmyOrientationCache then
        return self.ArmyOrientationCache;
    end
    local Orientation;
    if not self.GetArmyOrientation then
        Orientation = self.DefaultGetArmyOrientation(self);
    else
        Orientation = self.GetArmyOrientation(self);
    end
    self.ArmyOrientationCache = Orientation;
    return Orientation;
end

---
-- Sets the function to calculate the army rotation.
--
-- The function is called with the following parameters:
-- <table border="1">
-- <tr><td><b>Parameter</b></td><td><b>Type</b></td></tr>
-- <tr><td>self</td><td>Army object instance</td></tr>
-- <tr><td>_TargetID</td><td>number</td></tr>
-- <tr><td>_TroopID</td><td>number</td></tr>
-- </table>
--
-- @param[type=function] _Function Calculate army rotation
-- @return[type=number] Army rotation
-- @within Behavior
--
function AiArmy:SetArmyOrientationCalculator(_Function)
    self.GetArmyOrientation = _Function;
end

function AiArmy:DefaultGetArmyOrientation()
    if table.getn(self.Troops) == 0 then
        return 0;
    else
        local ValueSum = 0;
        local Rotation = 0;
        for i= 1, table.getn(self.Troops), 1 do
            if Logic.IsLeader(self.Troops[i]) == 1 then
                local Soldiers = {Logic.GetSoldiersAttachedToLeader(self.Troops[i])};
                for j= 2, Soldiers[1]+1, 1 do
                    Rotation = Rotation + Logic.GetEntityOrientation(Soldiers[j]);
                    ValueSum = ValueSum + 1;
                end
            end
            Rotation = Rotation + Logic.GetEntityOrientation(self.Troops[i]);
            ValueSum = ValueSum + 1;
        end
        return Rotation / ValueSum;
    end
end

-- -------------------------------------------------------------------------- --

function AiArmy:GetArmyPosition()
    if self.ArmyPositionCache then
        return self.ArmyPositionCache;
    end
    local Position;
    if table.getn(self.Troops) == 0 then
        Position = self.HomePosition;
    else
        Position = QuestTools.GetGeometricFocus(unpack(self.Troops));
    end
    self.ArmyPositionCache = Position;
    return Position;
end

function AiArmy:CallGetArmyFront()
    if not self.GetArmyFront then
        return self.DefaultGetArmyFront(self);
    end
    return self.GetArmyFront(self);
end

---
-- Sets the function to calculate the army front position. The army will search
-- enemies always from the front and not from their center.
--
-- The function is called with the following parameters:
-- <table border="1">
-- <tr><td><b>Parameter</b></td><td><b>Type</b></td></tr>
-- <tr><td>self</td><td>Army object instance</td></tr>
-- </table>
--
-- @param[type=function] _Function Calculate army front
-- @return[type=number] Front position of army
-- @within Behavior
--
function AiArmy:SetArmyFrontCalculator(_Function)
    self.GetArmyOrientation = _Function;
end

function AiArmy:DefaultGetArmyFront()
    local TroopCount = table.getn(self.Troops);
    if TroopCount == 0 then
        return self.HomePosition;
    else
        local ArmyPosition = self:GetArmyPosition();
        local MaxDistance = 0;
        for i= 1, TroopCount, 1 do
            local CurrentDistance = GetDistance(self.Troops[i], ArmyPosition);
            if CurrentDistance > MaxDistance then
                MaxDistance = CurrentDistance;
            end
        end
        local Rotation = self:CallGetArmyOrientation();
        local Position = QuestTools.GetCirclePosition(
            ArmyPosition, MaxDistance * 1.5, Rotation
        );
        -- Uncomment for debug reasons
        -- if self.FrontPositionMarker then
        --     Logic.DestroyEntity(self.FrontPositionMarker);
        -- end
        -- self.FrontPositionMarker = Logic.CreateEntity(Entities.XD_CoordinateEntity, Position.X, Position.Y, 0, 0);
        return Position;
    end
end

-- -------------------------------------------------------------------------- --

function AiArmy:GetArmyBlockPositonMap(_Position)
    if self.ArmyFormationCache then
        return self.ArmyFormationCache;
    end
    local Position = _Position or self:GetArmyPosition();
    if type(_Position) ~= "table" then
        Position = GetPosition(_Position);
    end
    local RowCount = self.TroopsPerLine or 3;
    local Rotation = self:CallGetArmyOrientation() +180;
    local Distance = 500;

    local PositionMap = {};
    if table.getn(self.Troops) == 1 then
        PositionMap[self.Troops[1]] = Position;
    else
        local LeaderPerRow = math.ceil(table.getn(self.Troops)/RowCount);
        local getModLi = function(i)
            i = i -1;
            return -(math.floor(i/RowCount)-math.floor(LeaderPerRow/2)) * Distance
        end
        local getModRei = function(i)
            i = i -1;
            return (math.mod(i,RowCount)-math.floor(RowCount/2)) * Distance;
        end

        local Temp = {};
        for i= 1, table.getn(self.Troops), 1 do
            if Logic.IsHero(self.Troops[i]) == 1 then
                local Type = Logic.GetEntityType(self.Troops[i]);
                if Type == Entities.PU_Hero5 or Entities.PU_Hero10 then
                    table.insert(Temp, 1, self.Troops[i]);
                else
                    table.insert(Temp, self.Troops[i]);
                end
            elseif Logic.IsEntityInCategory(self.Troops[i], EntityCategories.Melee) == 1 then
                table.insert(Temp, self.Troops[i]);
            else
                table.insert(Temp, 1, self.Troops[i]);
            end
        end

        local n = table.getn(Temp);
        for i= 1, n do
            local FormationPos = QuestTools.GetCirclePosition(Position, getModLi(i), 0 + Rotation);
            FormationPos = QuestTools.GetCirclePosition(FormationPos, getModRei(i), 0 + Rotation + 270);
            FormationPos = QuestTools.GetReachablePosition(Temp[i], FormationPos);
            PositionMap[Temp[i]] = FormationPos;
        end
    end
    self.ArmyFormationCache = PositionMap;
    return PositionMap
end

function AiArmy:MoveAsBlock(_Position, _Agressive, _Abort)
    if not _Abort and self:IsMoving() then
        return;
    end
    local ArmyPosition = self:GetArmyPosition();
    local Position = _Position;
    if type(_Position) ~= "table" then
        Position = GetPosition(_Position);
    end
    local RowCount = self.TroopsPerLine or 3;
    local Rotation = self:CallGetArmyOrientation() -180;
    local Distance = 500;

    local PositionMap = self:GetArmyBlockPositonMap(Position);
    
    if table.getn(self.Troops) == 1 then
        local TroopPosition = PositionMap[self.Troops[1]];
        if not TroopPosition then
            TroopPosition = ArmyPosition;
        end
        if IsValidPosition(TroopPosition) then
            if _Agressive then
                Logic.GroupAttackMove(self.Troops[1], TroopPosition.X, TroopPosition.Y, 0 + Rotation);
            else
                Logic.MoveSettler(self.Troops[1], TroopPosition.X, TroopPosition.Y, 0 + Rotation);
            end
        end
    else
        for i= 1, table.getn(self.Troops), 1 do
            local TroopPosition = PositionMap[self.Troops[i]];
            if not TroopPosition then
                TroopPosition = ArmyPosition;
            end
            if IsValidPosition(TroopPosition) then
                if _Agressive then
                    Logic.GroupAttackMove(self.Troops[i], TroopPosition.X, TroopPosition.Y, 0 + Rotation);
                else
                    Logic.MoveSettler(self.Troops[i], TroopPosition.X, TroopPosition.Y, 0 + Rotation);
                end
            end
        end
    end
end

function AiArmy:Move(_Positon, _Abort)
    local Positon = _Positon;
    if type(Positon) ~= "table" then
        Positon = GetPosition(Positon);
    end
    if IsValidPosition(Positon) then
        for i= table.getn(self.Troops), 1, -1 do
            if _Abort or not Logic.IsEntityMoving(self.Troops[i]) then
                Logic.MoveSettler(self.Troops[i], Positon.X, Positon.Y, -1);
            end
        end
    end
end

function AiArmy:Attack(_TargetID, _Abort)
    for i= table.getn(self.Troops), 1, -1 do
        if self.Troops[i] and IsExisting(self.Troops[i]) and Logic.GetEntityHealth(self.Troops[i]) > 0 then
            if _Abort or not Logic.IsEntityMoving(self.Troops[i]) then
                Logic.GroupAttack(self.Troops[i], _TargetID);
            end
        end
    end
end

function AiArmy:AttackMove(_Positon, _Abort)
    local Positon = _Positon;
    if type(Positon) ~= "table" then
        Positon = GetPosition(Positon);
    end
    if IsValidPosition(Positon) then
        for i= table.getn(self.Troops), 1, -1 do
            if _Abort or not Logic.IsEntityMoving(self.Troops[i]) then
                Logic.GroupAttackMove(self.Troops[i], Positon.X, Positon.Y, -1);
            end
        end
    end
end

function AiArmy:MoveTroop(_TroopID, _Positon, _Abort)
    if _Abort or not Logic.IsEntityMoving(_TroopID) then
        local Positon = _Positon;
        if type(Positon) ~= "table" then
            Positon = GetPosition(Positon);
        end
        if IsValidPosition(Positon) then
            Logic.MoveSettler(_TroopID, Positon.X, Positon.Y, -1);
        end
    end
end

function AiArmy:TroopAttack(_TroopID, _Target, _Abort)
    if _Abort or not Logic.IsEntityMoving(_TroopID) then
        Logic.GroupAttack(_TroopID, _Target);
    end
end

function AiArmy:TroopAttackMove(_TroopID, _Positon, _Abort)
    if _Abort or not Logic.IsEntityMoving(_TroopID) then
        local Positon = _Positon;
        if type(Positon) ~= "table" then
            Positon = GetPosition(Positon);
        end
        if IsValidPosition(Positon) then
            Logic.GroupAttackMove(_TroopID, Positon.X, Positon.Y, -1);
        end
    end
end

-- -------------------------------------------------------------------------- --

function AiArmy:HasWeakTroops()
    for k, v in pairs(self.Troops) do
        if v then
            local Cur = Logic.LeaderGetNumberOfSoldiers(v);
            local Max = Logic.LeaderGetMaxNumberOfSoldiers(v);
            if Max > 0 and Cur < Max then
                return true;
            end
        end
    end
    return false;
end

function AiArmy:GetWeakTroops()
    local Weak = {};
    for i= table.getn(self.Troops), 1, -1 do
        local Cur = Logic.LeaderGetNumberOfSoldiers(self.Troops[i]);
        local Max = Logic.LeaderGetMaxNumberOfSoldiers(self.Troops[i]);
        if Max > 0 and Cur < Max then
            table.insert(Weak, self.Troops[i]);
            AiArmyTroopIDToArmyID[self.Troops[i]] = nil;
            table.remove(self.Troops, i);
        end
    end
    return Weak;
end

function AiArmy:DispatchTroopsToProducers(_Troops)
    local Troops = copy(_Troops);
    -- add to producers
    for i= table.getn(Troops), 1, -1 do
        local TroopType = Logic.GetEntityType(Troops[i]);
        for k, v in pairs(self.Producers) do
            if Logic.IsHero(v) == 0 then
                if v and v:IsAlive() and not QuestTools.IsInTable(Troops[i], v.Troops.Created) then
                    if v.IsSpawner and v:IsInTypeList(TroopType) then
                        AiArmy:MoveTroop(Troops[i], v.ApproachPosition, true);
                        self:SetTroopSpeed(Troops[i], 1.0);
                        table.insert(v.Troops.Created, Troops[i]);
                        table.remove(Troops, i);
                        break;
                    elseif v.IsRecruiter and v:IsSuitableUnitType(TroopType) then
                        AiArmy:MoveTroop(Troops[i], v.ApproachPosition, true);
                        self:SetTroopSpeed(Troops[i], 1.0);
                        table.insert(v.Troops.Created, Troops[i]);
                        table.remove(Troops, i);
                        break;
                    end
                end
            else
                SetPosition(v, GetPosition(self.HomePosition));
            end
        end
    end
    -- destroy rest
    for i= table.getn(Troops), 1, -1 do
        AiArmyTroopIDToArmyID[Troops[i]] = nil;
        DestroyEntity(Troops[i]);
    end
end

function AiArmy:GetSpawnerProducers()
    local SpawnerList = {};
    for k, v in pairs(self.Producers) do
        if v and v.IsSpawner then
            if QuestTools.SameSector(self.HomePosition, v.ApproachPosition) then
                table.insert(SpawnerList, v);
            end
        end
    end
    return SpawnerList;
end

function AiArmy:CountUnpickedProducerTroops()
    local SpawnedTroops = 0;
    for k, v in pairs(self.Producers) do
        if v then
            SpawnedTroops = SpawnedTroops + table.getn(v.Troops.Created);
        end
    end
    return SpawnedTroops;
end

function AiArmy:ClearDeadTroops()
    for i= table.getn(self.Troops), 1, -1 do
        if self.Troops[i] then
            if Logic.IsHero(self.Troops[i]) == 0 then
                if not IsExisting(self.Troops[i]) then
                    local ID = table.remove(self.Troops, i);
                    AiArmyTroopIDToArmyID[ID] = nil;
                end
            else
                if not IsExisting(self.Troops[i]) or Logic.GetEntityHealth(self.Troops[i]) == 0 then
                    -- TODO: What should we do with a drunken sailor?
                    -- SetPosition(self.Troops[i], GetPosition(self.HomePosition));
                    local ID = table.remove(self.Troops, i);
                    AiArmyTroopIDToArmyID[ID] = nil;
                end
            end
        end
    end
end

function AiArmy:AbandonRemainingTroops()
    for i= table.getn(self.Troops), 1, -1 do
        local ID = table.remove(self.Troops, i);
        if ID and IsExisting(ID) and Logic.GetEntityHealth(ID) > 0 then
            table.insert(self.AbandonedTroops, ID);
        end
    end
end

function AiArmy:CheckAbandonedTroops()
    for i= table.getn(self.AbandonedTroops), 1, -1 do
        local ID = self.AbandonedTroops[i];
        if IsExisting(ID) and Logic.GetEntityHealth(ID) > 0 then
            if not self:IsTroopFighting(ID) then
                table.remove(self.AbandonedTroops, i);
                if Logic.IsLeader(ID) == 1 then
                    local Soldiers = {Logic.GetSoldiersAttachedToLeader(ID)};
                    for j= Soldiers[1]+1, 2, -1 do
                        SetHealth(Soldiers[j], 0);
                    end
                end
                SetHealth(ID, 0);
            end
        else
            table.remove(self.AbandonedTroops, i);
        end
    end
end

function AiArmy:ClearDeadTroopTargets()
    for i= table.getn(self.Troops), 1, -1 do
        if self.Troops[i] then
            if not IsExisting(self.Troops[i]) then
                self.TroopProperties[self.Troops[i]] = nil;
            else
                if self.TroopProperties[self.Troops[i]] then
                    if self.TroopProperties[self.Troops[i]].Target ~= 0 then
                        local ID = self.TroopProperties[self.Troops[i]].Target;
                        if not IsExisting(ID) or Logic.GetEntityHealth(ID) == 0 then
                            self.TroopProperties[self.Troops[i]].Target = 0;
                            self.TroopProperties[self.Troops[i]].Time   = 0;
                        end
                    end
                end
            end
        end
    end
end

function AiArmy:ClearTargets()
    for i= 1, table.getn(self.Troops), 1 do
        if AiArmyList[self.ArmyID].TroopProperties[self.Troops[i]] then
            AiArmyList[self.ArmyID].TroopProperties[self.Troops[i]].Target = 0;
        end
    end
end

-- -------------------------------------------------------------------------- --

function AiArmy:Operate()
    self.ArmyOrientationCache = nil;
    self.ArmyPositionCache = nil;
    self.ArmyFormationCache = nil;

    if self.ArmyIsPaused then
        return;
    end

    self.AssembleTimer = self.AssembleTimer +1;

    self:ClearDeadTroops();
    self:ClearDeadTroopTargets();
    if self:IsDead() then
        self:AbandonRemainingTroops();
        self:CheckAbandonedTroops();
        return;
    end
    self:CheckAbandonedTroops();

    if self.State ~= ArmyStates.Fallback and self.State ~= ArmyStates.Refill then
        if self:CalculateStrength() < self.AbandonStrength then
            self:SetState(ArmyStates.Defeat);
            self:SetSubState(ArmySubStates.None);
            self:SetBattleTarget(nil);
            self:ClearTargets();
            self:ResetArmySpeed();
            self:AbandonRemainingTroops();
        end
    end

    if self.State == ArmyStates.Idle then
        self:IdleStateController();
    elseif self.State == ArmyStates.Advance then
        self:AdvanceStateController();
    elseif self.State == ArmyStates.Battle then
        self:BattleStateController();
    elseif self.State == ArmyStates.Obliberate then
        self:ObliberateStateController();
    elseif self.State == ArmyStates.Guard then
        self:GuardStateController();
    elseif self.State == ArmyStates.Defeat then
        self:DefeatStateController();
    elseif self.State == ArmyStates.Retreat then
        self:RetreatStateController();
    elseif self.State == ArmyStates.Refill then
        self:RefillStateController();
    end
    return false;
end

function AiArmy:ArmyOperationController()
    if AiArmy ~= self then
        return;
    end
    AiArmyCurrentArmy = AiArmyCurrentArmy +1;
    if table.getn(AiArmyList) < AiArmyCurrentArmy then
        AiArmyCurrentArmy = 1;
    end
    local ArmyID = AiArmyCurrentArmy;
    if AiArmyList[ArmyID] then
        if AiArmyList[ArmyID].LastTick == 0 
        or AiArmyList[ArmyID].LastTick +10 < self:GetTime() then
            AiArmyList[ArmyID].LastTick = self:GetTime();
            AiArmyList[ArmyID]:Operate();
        end
    end
end

function AiArmy:ArmyAttackedReactionController(_Attacker, _Attacked)
    for i= 1, table.getn(_Attacked), 1 do
        for j= 1, table.getn(AiArmyList), 1 do
            if not AiArmyList[j]:IsDead() then
                if AiArmyList[j].State == ArmyStates.Advance then
                    local VictimID = _Attacked[i];
                    if Logic.IsEntityInCategory(VictimID, EntityCategories.Soldier) == 1 then
                        VictimID = QuestTools.SoldierGetLeader(_eID);
                    end
                    if VictimID and QuestTools.IsInTable(VictimID, AiArmyList[j].Troops) then
                        AiArmyList[j].State = ArmyStates.Battle;
                        AiArmyList[j].BattleTarget = GetPosition(_Attacker);
                        for k= table.getn(AiArmyList[j].Troops), 1, -1 do
                            local TroopID = AiArmyList[j].Troops[k];
                            if not AiArmyList[j].TroopProperties[TroopID] then
                                AiArmyList[j].TroopProperties[TroopID] = {};
                            end
                            AiArmyList[j].TroopProperties[TroopID].Target = _Attacker;
                            AiArmyList[j].TroopProperties[TroopID].Time   = 15;
                        end
                        break;
                    end
                end
            end
        end
    end
end

-- -------------------------------------------------------------------------- --

function AiArmy:IdleStateController()
    -- handle attack/defend
    if self.AttackTarget then
        self.State = ArmyStates.Advance;
        self.Target = self.AttackTarget[self.AttackTarget.Current];
        self:NormalizedArmySpeed();
        self:ClearTargets();
        return;
    end
    if self.GuardTarget then
        self.State = ArmyStates.Advance;
        self.Target = self.GuardTarget;
        self:MoveAsBlock(self.Target, false, false);
        self:NormalizedArmySpeed();
        self:ClearTargets();
        return;
    end
    self.State = ArmyStates.Advance;
    self.Target = self.HomePosition;
    self:NormalizedArmySpeed();
    self:ClearTargets();
end

-- -------------------------------------------------------------------------- --

function AiArmy:AdvanceStateController()
    -- check has target
    if not self.AttackTarget and not self.GuardTarget then
        self.State = ArmyStates.Defeat;
        self.SubState = ArmySubStates.None;
        self.Target = nil;
        self:ResetArmySpeed();
        return;
    end

    -- find enemies closeby
    for i= table.getn(self.Troops), 1, -1 do
        local Exploration = Logic.GetEntityExplorationRange(self.Troops[i])*100;
        local Enemies = self:CallGetEnemiesInArea(self.Troops[i], Exploration+1000);
        if table.getn(Enemies) > 0 then
            self.BattleTarget = GetPosition(Enemies[1]);
            self.State = ArmyStates.Battle;
            self.SubState = ArmySubStates.None;
            self:ResetArmySpeed();
            return;
        end
    end

    -- abort attack without enemy
    if self.AttackTarget then
        local Position = self.AttackTarget[table.getn(self.AttackTarget)];
        if not QuestTools.AreEnemiesInArea(self.PlayerID, Position, self.RodeLength) then
            self.State = ArmyStates.Defeat;
            self.SubState = ArmySubStates.None;
            self.Target = nil;
            self:ResetArmySpeed();
            return;
        end
    end

    -- advance to target
    local Distance = (self.GuardTarget and 500) or 1500;
    if QuestTools.GetDistance(self.Target, self:GetArmyPosition()) > Distance then
        if not self:IsMoving() and not self:IsFighting() then
            self:MoveAsBlock(self.Target, false, false);
        end
    else
        if self.AttackTarget and self.Target == self.AttackTarget[self.AttackTarget.Current] then
            if table.getn(self.AttackTarget) > self.AttackTarget.Current then
                self.AttackTarget.Current = self.AttackTarget.Current +1;
                self.Target = self.AttackTarget[self.AttackTarget.Current];
                return;
            end
            self.AttackTarget.Current = 1;
            self.State = ArmyStates.Obliberate;
            self.SubState = ArmySubStates.None;
            self:ResetArmySpeed();
        elseif self.Target == self.GuardTarget then
            self.State = ArmyStates.Guard;
            self.SubState = ArmySubStates.None;
            self.GuardStartTime = self:GetTime();
            self:ResetArmySpeed();
        else
            self.State = ArmyStates.Defeat;
            self.SubState = ArmySubStates.None;
            self.Target = nil;
            self:ResetArmySpeed();
        end
        return;
    end
    self:Assemble(500);
end

-- -------------------------------------------------------------------------- --

function AiArmy:BattleStateController()
    -- find enemies
    local AreaSize = 4000; --self.RodeLength;
    local Enemies = self:CallGetEnemiesInArea(self.BattleTarget, AreaSize);
    if table.getn(Enemies) == 0 then
        self.BattleTarget = nil;
        self.State = ArmyStates.Retreat;
        self.SubState = ArmySubStates.None;
        self:NormalizedArmySpeed();
        self:MoveAsBlock(self.Target, false, true);
        return;
    else
        self:ControlTroops(self.BattleTarget, Enemies);
    end
    self:Assemble(AreaSize);
end

-- -------------------------------------------------------------------------- --

function AiArmy:ObliberateStateController()
    -- check has target
    if not self.AttackTarget then
        self.State = ArmyStates.Defeat;
        self.SubState = ArmySubStates.None;
        self.Target = nil;
        return;
    end

    -- find enemies
    local AreaSize = self.RodeLength + self.OuterRange;
    local AreaCenter = self:GetArmyPosition();
    local Enemies = self:CallGetEnemiesInArea(AreaCenter, AreaSize);
    if table.getn(Enemies) == 0 then
        self.State = ArmyStates.Defeat;
        self.SubState = ArmySubStates.None;
        self.Target = nil;
        return;
    else
        self:ControlTroops(AreaCenter, Enemies);
    end
    self:Assemble(AreaSize);
end

-- -------------------------------------------------------------------------- --

function AiArmy:GuardStateController()
    -- check has target
    if not self.GuardTarget then
        self.State = ArmyStates.Defeat;
        return;
    end

    -- end guard after time is up
    if self.GuardMaximumTime > -1 then
        if self.GuardStartTime + self.GuardMaximumTime < self:GetTime() then
            self:ClearTargets();
            self.SubState = ArmySubStates.None;
            if self:CalculateStrength() >= self.RefillStrength then
                self.State = ArmyStates.Idle;
            else
                self.State = ArmyStates.Retreat;
            end
            self.GuardTarget = nil;
            self.Target = nil;
            return;
        end
    end

    -- find enemies
    local AreaSize = self.RodeLength + self.OuterRange;
    local AreaCenter = self:GetArmyPosition();
    local Enemies = self:CallGetEnemiesInArea(AreaCenter, AreaSize);
    if table.getn(Enemies) == 0 then
        self:Assemble(self.RodeLength / 2);
        return;
    else
        self:ControlTroops(AreaCenter, Enemies);
    end
    self:Assemble(self.RodeLength);
end

-- -------------------------------------------------------------------------- --

function AiArmy:DefeatStateController()
    if table.getn(self.Troops) == 0 then
        self.State = ArmyStates.Refill;
        self.SubState = ArmySubStates.None;
        self.GuardTarget = nil;
        self.AttackTarget = nil;
    elseif QuestTools.GetDistance(self:GetArmyPosition(), self.HomePosition) <= 2000 then
        self.State = ArmyStates.Refill;
        self.SubState = ArmySubStates.None;
        self.GuardTarget = nil;
        self.AttackTarget = nil;
    else
        self:Move(self.HomePosition, self:IsFighting());
        self.GuardTarget = nil;
        self.AttackTarget = nil;
    end
    self:ClearTargets();
end

-- -------------------------------------------------------------------------- --

function AiArmy:RetreatStateController()
    -- find enemies closeby
    if not self.BattleTarget then
        for i= table.getn(self.Troops), 1, -1 do
            local Exploration = Logic.GetEntityExplorationRange(self.Troops[i])*100;
            local Enemies = self:CallGetEnemiesInArea(self.Troops[i], Exploration+1000);
            if table.getn(Enemies) > 0 then
                self.BattleTarget = GetPosition(Enemies[1]);
                self:ResetArmySpeed();
                return;
            end
        end
    end

    -- still enemies near
    if self.BattleTarget then
        local AreaSize = 4000;
        local Enemies = self:CallGetEnemiesInArea(self.BattleTarget, AreaSize);
        if table.getn(Enemies) == 0 then
            self.BattleTarget = nil;
            self:MoveAsBlock(self.HomePosition, false, false);
            self:NormalizedArmySpeed();
        else
            self:ControlTroops(self.BattleTarget, Enemies);
            self:Assemble(self.RodeLength);
        end
        return;
    end

    -- arrived at home basis
    if QuestTools.GetDistance(self:GetArmyPosition(), self.HomePosition) <= 2000 then
        self.State = ArmyStates.Refill;
        self.SubState = ArmySubStates.None;
        self.GuardTarget = nil;
        self.AttackTarget = nil;
        return;
    end

    -- move home
    self:MoveAsBlock(self.HomePosition, false, false);
    self:Assemble(500);
end

-- -------------------------------------------------------------------------- --

function AiArmy:RefillStateController()
    if self:HasWeakTroops() then
        local Weak = self:GetWeakTroops();
        self:DispatchTroopsToProducers(Weak);
        self:Move(self.HomePosition);
        return;
    end
    
    if table.getn(self.Troops) == self.TroopCount then
        local HomePosition = GetPosition(self.HomePosition);
        self:Move(self.HomePosition);
        self.State = ArmyStates.Idle;
    else
        -- Initial spawn
        if self.IsRespawningArmy then
            if not self.InitialSpawned then
                local Spawner = self:GetSpawnerProducers();
                for i= table.getn(Spawner), 1, -1 do
                    if Spawner[i]:IsAlive() and table.getn(self.Troops) < self.TroopCount then
                        Spawner[i]:CreateTroop(true, true);
                        local ID = Spawner[i]:GetTroop();
                        if ID > 0 then
                            self:CallChoseFormation(ID);
                            AiArmyTroopIDToArmyID[ID] = self.ArmyID;
                            table.insert(self.Troops, ID);
                        end
                    else
                        break;
                    end
                end
                if table.getn(self.Troops) >= self.TroopCount then
                    self.InitialSpawned = true;
                end
                return;
            end
        end
    
        -- normal spawn/recruitment
        local ProducerInTable = false;
        for k, v in pairs(self.Producers) do
            if v and v:IsAlive() then
                ProducerInTable = true;
                if table.getn(self.Troops) < self.TroopCount then
                    if QuestTools.SameSector(self.HomePosition, v.ApproachPosition) then
                        local ID = v:GetTroop();
                        if ID > 0 then
                            self:CallChoseFormation(ID);
                            AiArmyTroopIDToArmyID[ID] = self.ArmyID;
                            table.insert(self.Troops, ID);
                        elseif ID == 0 then
                            if self:CountUnpickedProducerTroops() < self.TroopCount - table.getn(self.Troops) then
                                v:CreateTroop(false);
                            end
                        end
                    end
                end
            end
        end

        -- return to decide state
        if not ProducerInTable then
            self.State = ArmyStates.Idle;
        end
    end
end

-- -------------------------------------------------------------------------- --

function AiArmy:GetTroopBaseSpeed(_TroopID)
    local Speed = 0;
    if not IsExisting(_TroopID) then
        return Speed;
    end
    for k, v in pairs(QuestTools.GetEntityCategoriesAsString(_TroopID)) do
        if UnitBaseSpeed[v] and Speed < UnitBaseSpeed[v] then
            Speed = UnitBaseSpeed[v];
        end
    end
    local TypeName = Logic.GetEntityTypeName(Logic.GetEntityType(_TroopID));
    if UnitBaseSpeed[TypeName] then
        Speed = UnitBaseSpeed[TypeName];
    end
    if Speed == 0 then
        Speed = 360;
    end
    return Speed;
end

function AiArmy:NormalizedArmySpeed()
    local TroopSpeed = 0;
    for i= 1, table.getn(self.Troops), 1 do
        TroopSpeed = TroopSpeed + self:GetTroopBaseSpeed(self.Troops[i]);
    end
    TroopSpeed = TroopSpeed / table.getn(self.Troops);
    for i= 1, table.getn(self.Troops), 1 do
        local Speed = self:GetTroopBaseSpeed(self.Troops[i]);
        self:SetTroopSpeed(self.Troops[i], TroopSpeed/Speed);
    end
end

function AiArmy:ResetArmySpeed()
    for i= 1, table.getn(self.Troops), 1 do
        self:SetTroopSpeed(self.Troops[i], 1.0);
    end
end

function AiArmy:SetTroopSpeed(_TroopID, _Factor)
    Logic.SetSpeedFactor(_TroopID, _Factor);
    if Logic.IsLeader(_TroopID) == 1 then
        local Soldiers = {Logic.GetSoldiersAttachedToLeader(_TroopID)};
        for i= 2, Soldiers[1]+1, 1 do
            Logic.SetSpeedFactor(Soldiers[i], _Factor);
        end
    end
end

-- -------------------------------------------------------------------------- --

function AiArmy:Assemble(_Area)
    local IsScattered = false;
    if self.AssembleTimer >= 15 then
        self.AssembleTimer = 0;
        local PositionMap = self:GetArmyBlockPositonMap(self:GetArmyPosition());
        local TroopCount = table.getn(self.Troops);
        local TotalDistance = 0;
        for i= 1, TroopCount, 1 do
            if self.SubState ~= ArmySubStates.Assemble then
                if PositionMap[self.Troops[i]] then
                    TotalDistance = TotalDistance + GetDistance(self.Troops[i], PositionMap[self.Troops[i]]);
                end
            end
        end
        if TotalDistance / TroopCount > _Area then
            IsScattered = true;
        end
    end
    if IsScattered then
        if self.SubState ~= ArmySubStates.Assemble then
            self:MoveAsBlock(self:GetArmyPosition(), false, true);
            self.SubState = ArmySubStates.Assemble;
        end
    else
        if self.SubState == ArmySubStates.Assemble then
            self.SubState = ArmySubStates.None;
        end
    end
end

-- -------------------------------------------------------------------------- --

function AiArmy:ControlTroops(_Position, _Enemies)
    local Position = _Position or self:GetArmyPosition();
    for i= 1, table.getn(self.Troops), 1 do
        if Logic.IsEntityInCategory(self.Troops[i], EntityCategories.Cannon) == 0 then
            if self:IsTroopFighting() then
                return;
            end
        end
        self.TroopProperties[self.Troops[i]] = self.TroopProperties[self.Troops[i]] or {
            Target  = 0,
            Time    = 0,
            Command = 0
        };
        self:ControlSingleTroop(self.Troops[i], Position, _Enemies);
    end
end

function AiArmy:ControlSingleTroop(_TroopID, _Position, _Enemies)
    local Target = self:TargetEnemy(_TroopID, _Enemies);
    if Target > 0 then
        if (self.State ~= ArmyStates.Defeat and self.State ~= ArmyStates.Refill) then
            if not self:IsTroopFighting(_TroopID) then
                if Logic.IsEntityInCategory(_TroopID, EntityCategories.Cannon) == 1 then
                    self:CannonTroopAttackTarget(_TroopID, Target);
                elseif Logic.IsEntityInCategory(_TroopID, EntityCategories.CavalryLight) == 1 then
                    self:TroopAttackMove(_TroopID, Target, true);
                elseif Logic.IsEntityInCategory(_TroopID, EntityCategories.LongRange) == 1 then
                    self:TroopAttack(_TroopID, Target, true);
                else
                    self:TroopAttackMove(_TroopID, Target, true);
                end
            end
        end
    else
        self:TroopAttackMove(_TroopID, _Position, false);
    end
end

function AiArmy:CannonTroopAttackTarget(_TroopID, _EnemyID)
    local Command = self.TroopProperties[_TroopID].Command;
    if not Command or Command +10 < self:GetTime() then
        local Sight = Logic.GetEntityExplorationRange(_TroopID) * 100;
        if  QuestTools.GetDistance(_TroopID, _EnemyID) < Sight then
            if not self:IsTroopFighting(_TroopID) then
                self:TroopAttack(_TroopID, _EnemyID, true);
            end
        else
            self:TroopAttackMove(_TroopID, _EnemyID, false);
        end
        self.TroopProperties[_TroopID].Command = self:GetTime();
    end
end

-- -------------------------------------------------------------------------- --

function AiArmy:CallChoseFormation(_TroopID)
    if not self.ChoseFormation then
        self.DefaultChoseFormation(self, _TroopID);
        return;
    end
    self.ChoseFormation(self, _TroopID);
end

---
-- Decides on the formation of the troop. To reset to default pass
-- nil as parameter.
--
-- The function is called with the following parameters:
-- <table border="1">
-- <tr><td><b>Parameter</b></td><td><b>Type</b></td></tr>
-- <tr><td>self</td><td>Army object instance</td></tr>
-- <tr><td>_TroopID</td><td>number</td></tr>
-- </table>
--
-- @param[type=function] _Function Function to detect enemies
-- @within Behavior
--
function AiArmy:SetTroopFormationSelector(_Function)
    self.GetEnemiesInArea = _Function;
end

function AiArmy:DefaultChoseFormation(_TroopID)
    if Logic.IsEntityInCategory(_TroopID, EntityCategories.EvilLeader) == 1 then
        return;
    elseif Logic.IsEntityInCategory(_TroopID, EntityCategories.Sword) == 1 then
        Logic.LeaderChangeFormationType(_TroopID, 2);
        return;
    elseif Logic.IsEntityInCategory(_TroopID, EntityCategories.CavalryHeavy) == 1 then
        Logic.LeaderChangeFormationType(_TroopID, 6);
        return;
    end
    Logic.LeaderChangeFormationType(_TroopID, 4);
end

-- -------------------------------------------------------------------------- --

function AiArmy:CallGetEnemiesInArea(_Position, _Range, _PlayerID)
    local Enemies;
    if not self.GetEnemiesInArea then
        Enemies = self.DefaultGetEnemiesInArea(self, _Position, _Range, _PlayerID);
    else
        Enemies = self.GetEnemiesInArea(self, _Position, _Range, _PlayerID);
    end
    return Enemies;
end

---
-- Sets the function to detect enemies in an area. To reset to default pass
-- nil as parameter.
--
-- The function is called with the following parameters:
-- <table border="1">
-- <tr><td><b>Parameter</b></td><td><b>Type</b></td></tr>
-- <tr><td>self</td><td>Army object instance</td></tr>
-- <tr><td>_Position</td><td>number or table</td></tr>
-- <tr><td>_Range</td><td>number</td></tr>
-- <tr><td>_TroopID</td><td>number</td></tr>
-- </table>
--
-- @param[type=function] _Function Function to detect enemies
-- @return[type=table] List of enemies in area
-- @within Behavior
--
function AiArmy:SetEnemiesInAreaDetector(_Function)
    self.GetEnemiesInArea = _Function;
end

function AiArmy:DefaultGetEnemiesInArea(_Position, _Range, _PlayerID)
    local PlayerID = _PlayerID or self.PlayerID;
    if type(_Position) ~= "table" then
        _Position = GetPosition(_Position);
    end
    local AllEnemiesInSight = {};
    for i= 1, 8, 1 do
        if i ~= PlayerID and Logic.GetDiplomacyState(PlayerID, i) == Diplomacy.Hostile then
            local PlayerEntities = QuestTools.FindAllEntities(i, 0, _Range, _Position);
            for j= table.getn(PlayerEntities), 1, -1 do
                if Logic.GetEntityHealth(PlayerEntities[j]) > 0 then
                    if (
                        Logic.IsEntityInCategory(PlayerEntities[j], EntityCategories.Cannon) == 1 or
                        (Logic.IsHero(PlayerEntities[j]) == 1 and Logic.GetCamouflageTimeLeft(PlayerEntities[j]) == 0) or
                        Logic.IsBuilding(PlayerEntities[j]) == 1 or
                        Logic.IsLeader(PlayerEntities[j]) == 1
                    )
                    and Logic.IsEntityInCategory(PlayerEntities[j], EntityCategories.Thief) == 0 then
                        table.insert(AllEnemiesInSight, PlayerEntities[j]);
                    end
                end
            end
        end
    end
    return AllEnemiesInSight;
end

function AiArmy:GetEnemiesInRodeLength(_Position)
    return self:CallGetEnemiesInArea(_Position, self.RodeLength);
end

-- -------------------------------------------------------------------------- --

function AiArmy:CalculateStrength()
    local CurStrength = 0;
    local MaxStrength = self.TroopCount;
    for i= table.getn(self.Troops), 1, -1 do
        if Logic.IsLeader(self.Troops[i]) == 1 then
            local MaxSoldiers = Logic.LeaderGetMaxNumberOfSoldiers(self.Troops[i]);
            if MaxSoldiers > 0 then
                local CurSoldiers = Logic.LeaderGetNumberOfSoldiers(self.Troops[i]);
                CurStrength = CurStrength + (CurSoldiers/MaxSoldiers);
            else
                CurStrength = CurStrength + 1;
            end
        else
            CurStrength = CurStrength + 1;
        end
    end
    return CurStrength/MaxStrength;
end

-- -------------------------------------------------------------------------- --

function AiArmy:TargetEnemy(_TroopID, _Enemies)
    if self.TroopProperties[_TroopID] then
        if self.TroopProperties[_TroopID].Target ~= 0 then
            local OldTarget = self.TroopProperties[_TroopID].Target;
            if IsExisting(OldTarget) and Logic.GetEntityHealth(OldTarget) > 0 then
                self.TroopProperties[_TroopID].Time = self.TroopProperties[_TroopID].Time -1;
                if self.TroopProperties[_TroopID].Time > 0 then
                    local OtherArmy = nil
                    for k, v in pairs(AiArmyList) do
                        if v and self.ArmyID ~= v.ArmyID and not v:IsDead() then
                            if v:IsInArmy(OldTarget) then
                                OtherArmy = v;
                            end
                        end
                    end
                    if OtherArmy then
                        if OtherArmy.State ~= ArmyStates.Defeat then
                            return OldTarget;
                        end
                    else
                        return OldTarget;
                    end
                end
            end
        end

        local Enemies = self:SelectEnemy(_TroopID, _Enemies);
        if table.getn(Enemies) > 0 then
            self.TroopProperties[_TroopID].Target = Enemies[1];
            self.TroopProperties[_TroopID].Time   = 15;
            return Enemies[1];
        end
    end
    return 0;
end

function AiArmy:SelectEnemy(_TroopID, _Enemies)
    local Range = self.RodeLength + self.OuterRange;
    local Enemies = _Enemies or self:CallGetEnemiesInArea(_TroopID, Range);

    -- Remove if dead
    for i= table.getn(Enemies), 1, -1 do
        if not IsExisting(Enemies[i]) or Logic.GetEntityHealth(Enemies[i]) == 0 then
            table.remove(Enemies, i);
        end
    end
    -- Remove if fleeing
    for i= table.getn(Enemies), 1, -1 do
        for k, v in pairs(AiArmyList) do
            if v and self.ArmyID ~= v.ArmyID and not v:IsDead() then
                if v:IsInArmy(_TroopID) then
                    if v.State == ArmyStates.Defeat then
                        table.remove(Enemies, i);
                    end
                end
            end
        end
    end

    if table.getn(Enemies) > 1 then
        table.sort(Enemies, function(a, b)
            if self then
                return self:CallComputeEnemyPriority(_TroopID, a, b);
            end
            return false;
        end);
    end
    return Enemies;
end

function AiArmy:CallComputeEnemyPriority(_TroopID, _EnemyID1, _EnemyID2)
    if not self.ComputeEnemyPriority then
        return self.DefaultComputeEnemyPriority(self, _TroopID, _EnemyID1, _EnemyID2);
    end
    return self.ComputeEnemyPriority(self, _TroopID, _EnemyID1, _EnemyID2);
end

---
-- Sets the function to sort the list of enemies by priority. To reset to
-- default pass nil as parameter.
--
-- The function is called with the following parameters:
-- <table border="1">
-- <tr><td><b>Parameter</b></td><td><b>Type</b></td></tr>
-- <tr><td>self</td><td>Army object instance</td></tr>
-- <tr><td>_TroopID</td><td>number</td></tr>
-- <tr><td>_EnemyID1</td><td>number</td></tr>
-- <tr><td>_EnemyID2</td><td>number</td></tr>
-- </table>
--
-- @param[type=function] _Function Function to detect enemies
-- @return[type=table] Sorted enemy list
-- @within Behavior
--
function AiArmy:SetEnemyPriorityComperator(_Function)
    self.ComputeEnemyPriority = _Function;
end

function AiArmy:DefaultComputeEnemyPriority(_TroopID, _EnemyID1, _EnemyID2)
    local Position;
    if self.State == ArmyStates.Advance or self.State == ArmyStates.Battle then
        Position = self:CallGetArmyFront();
    else
        Position = self:GetArmyPosition();
    end    
    local Cost1 = QuestTools.GetDistance(Position, _EnemyID1);
    local Factor1 = self:CallGetTargetThreatFactor(_EnemyID1, _TroopID);
    local Priority1 = math.floor(Cost1 * Factor1);
    
    local Cost2 = QuestTools.GetDistance(Position, _EnemyID2);
    local Factor2 = self:CallGetTargetThreatFactor(_EnemyID2, _TroopID);
    local Priority2 = math.floor(Cost2 * Factor2);

    if Priority1 == 0 then
        return false;
    elseif Priority2 == 0 then
        return true;
    elseif Priority1 == 0 and Priority2 == 0 then
        return false;
    else
        return Priority1 < Priority2;
    end
end

-- -------------------------------------------------------------------------- --

function AiArmy:CallGetTargetThreatFactor(_TargetID, _TroopID)
    if not self.GetTargetThreatFactor then
        return self.DefaultGetTargetThreatFactor(self, _TargetID, _TroopID);
    end
    return self.GetTargetThreatFactor(self, _TargetID, _TroopID);
end

---
-- Sets the function to sort the list of enemies by priority. To reset to
-- default pass nil as parameter.
--
-- The function is called with the following parameters:
-- <table border="1">
-- <tr><td><b>Parameter</b></td><td><b>Type</b></td></tr>
-- <tr><td>self</td><td>Army object instance</td></tr>
-- <tr><td>_TargetID</td><td>number</td></tr>
-- <tr><td>_TroopID</td><td>number</td></tr>
-- </table>
--
-- @param[type=function] _Function Function to calculate thread factor
-- @return[type=table] Enemy cost factor
-- @within Behavior
--
function AiArmy:SetTargetThreatFactorComperator(_Function)
    self.GetTargetThreatFactor = _Function;
end

function AiArmy:DefaultGetTargetThreatFactor(_TargetID, _TroopID)
    local Factor = 1.0;
    local Priority = self:GetTargetCostFactors(_TargetID);
    for k, v in pairs(QuestTools.GetEntityCategoriesAsString(_TargetID)) do
        if Priority[v] then
            if Priority[v] > 0 then
                Factor = Factor * ((1/Priority[v]) or 1);
            else
                Factor = 0;
                break;
            end
        end
    end
    if Factor > 0 then
        local Cur = 1;
        local Max = 0;
        if Logic.IsLeader(_TargetID) == 1 then
            Cur = Logic.LeaderGetNumberOfSoldiers(_TargetID);
            Max = Logic.LeaderGetMaxNumberOfSoldiers(_TargetID);
        end
        Factor = Factor * ((Max > 0 and 1 - (Cur/Max)) or 1);
    end
    return Factor;
end

function AiArmy:GetTargetCostFactors(_TargetID)
    if Logic.IsEntityInCategory(_TargetID, EntityCategories.Hero) == 1 then
        if Logic.GetEntityType(_TargetID) == Entities.PU_Hero5 then
            return GroupTargetingPriorities.Ranged;
        elseif Logic.GetEntityType(_TargetID) == Entities.PU_Hero10 then
            return GroupTargetingPriorities.Rifle;
        else
            return GroupTargetingPriorities.Sword;
        end
    end
    if Logic.IsEntityInCategory(_TargetID, EntityCategories.EvilLeader) == 1 then
        if Logic.GetEntityType(_TargetID) == Entities.CU_Evil_LeaderSkirmisher then
            return GroupTargetingPriorities.Ranged;
        end
        return GroupTargetingPriorities.Sword;
    end
    if Logic.IsEntityInCategory(_TargetID, EntityCategories.CavalryHeavy) == 1 then
        return GroupTargetingPriorities.HeavyCavalry;
    end
    if Logic.IsEntityInCategory(_TargetID, EntityCategories.CavalryLight) == 1 then
        return GroupTargetingPriorities.LightCavalry;
    end
    if Logic.IsEntityInCategory(_TargetID, EntityCategories.Sword) == 1 then
        return GroupTargetingPriorities.Sword;
    end
    if Logic.IsEntityInCategory(_TargetID, EntityCategories.Spear) == 1 then
        return GroupTargetingPriorities.Spear;
    end
    if Logic.IsEntityInCategory(_TargetID, EntityCategories.Rifle) == 1 then
        return GroupTargetingPriorities.Rifle;
    end
    if Logic.IsEntityInCategory(_TargetID, EntityCategories.LongRange) == 1 then
        return GroupTargetingPriorities.Ranged;
    end
    if Logic.IsEntityInCategory(_TargetID, EntityCategories.Cannon) == 1 then
        return GroupTargetingPriorities.Cannon;
    end
    return {};
end

-- -------------------------------------------------------------------------- --

GroupTargetingPriorities = {};

GroupTargetingPriorities.Cannon = {
    ["MilitaryBuilding"] = 12,
    ["EvilLeader"] = 10,
    ["LongRange"] = 5,
};
GroupTargetingPriorities.LightCavalry = {
    ["Hero"] = 12,
    ["Cannon"] = 10,
    ["MilitaryBuilding"] = 8,
    ["Spear"] = 4,
    ["Sword"] = 4,
    ["EvilLeader"] = 0,
    ["LongRange"] = 0,
    ["Rifle"] = 0,
};
GroupTargetingPriorities.HeavyCavalry = {
    ["Hero"] = 12,
    ["Cannon"] = 12,
    ["LongRange"] = 10,
    ["MilitaryBuilding"] = 6,
    ["Sword"] = 6,
    ["Spear"] = 0,
};
GroupTargetingPriorities.Sword = {
    ["Hero"] = 12,
    ["Spear"] = 10,
    ["Cannon"] = 9,
    ["LongRange"] = 8,
    ["Serf"] = 3,
    ["CavalryHeavy"] = 0,
};
GroupTargetingPriorities.Spear = {
    ["CavalryHeavy"] = 12,
    ["CavalryLight"] = 12,
    ["MilitaryBuilding"] = 10,
    ["Serf"] = 0,
    ["Sword"] = 0,
    ["LongRange"] = 0,
};
GroupTargetingPriorities.Ranged = {
    ["MilitaryBuilding"] = 12,
    ["CavalryHeavy"] = 10,
    ["CavalryLight"] = 10,
    ["VillageCenter"] = 6,
    ["Headquarters"] = 6,
    ["Hero"] = 5,
    ["EvilLeader"] = 0,
};
GroupTargetingPriorities.Rifle = {
    ["EvilLeader"] = 12,
    ["LongRange"] = 12,
    ["MilitaryBuilding"] = 12,
    ["Cannon"] = 8,
    ["VillageCenter"] = 4,
    ["Headquarters"] = 4,
    ["Melee"] = 0,
};

-- -------------------------------------------------------------------------- --

UnitBaseSpeed = {
    ["Bow"] = 320,
    ["CavalryLight"] = 500,
    ["CavalryHeavy"] = 500,
    ["Hero"] = 400,
    ["Rifle"] = 320,
    
    ["PV_Cannon1"] = 240,
    ["PV_Cannon2"] = 260,
    ["PV_Cannon3"] = 220,
    ["PV_Cannon4"] = 180,
};

