-- ########################################################################## --
-- #  AI Army                                                               # --
-- #  --------------------------------------------------------------------  # --
-- #    Author:   totalwarANGEL                                             # --
-- ########################################################################## --

---
-- This module is used by the AI controller to create armies.
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
-- @field Retreat Army is retreating to the home position
-- @field Refill Army is requesting new soldiers from the producers
--
ArmyStates = {
    Idle       = 1,
    Advance    = 2,
    Battle     = 3,
    Obliberate = 4,
    Guard      = 5,
    Retreat    = 6,
    Refill     = 7,
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
    TroopProperties      = {};
    TroopCount           = 8;
    RodeLength           = 3000;
    OuterRange           = 0;
    Strength             = 0;
    RetreatStrength      = 0.25;
    Producers            = {},

    AttackAllowed        = true,
    DefendAllowed        = true,
    IsRespawningArmy     = false,
    InitialSpawned       = false,
    IsHiddenFromAI       = false,

    Target               = nil,
    AttackTarget         = nil,
    GuardTarget          = nil,
    BattleTarget         = nil,
    GuardStartTime       = 0,
    GuardMaximumTime     = 2*60,
    AssembleTimer        = 0,
    GuardPosList         = {Visited = {}},
    HomePosition         = nil,
}

AiArmyIdSequence = 0;
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
    AiArmyList[self.ArmyID] = self;
end
class(AiArmy);

function AiArmy:StartControllerJob()
    if self.ControllerJobID and JobIsRunning(self.ControllerJobID) then
        EndJob(self.ControllerJobID);
    end
    self.ControllerJobID = QuestTools.StartInlineJob(Events.LOGIC_EVENT_EVERY_SECOND, function(_ID)
        return AiArmyList[_ID]:Operate();
    end, self.ArmyID);
end

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

function AiArmy:IsDead()
    if self.ArmyIsDead == true then
        return true;
    end
    for k, v in pairs(self.Producers) do
        if v and IsExisting(v.ScriptName) then
            return false;
        end
    end
    if not self.IsRespawningArmy then
        return false;
    end
    return true;
end

function AiArmy:SetIsDead(_Flag)
    self.ArmyIsDead = _Flag == true;
    return self;
end

function AiArmy:IsFighting()
    for i= table.getn(self.Troops), 1, -1 do
        local Task = Logic.GetCurrentTaskList(self.Troops[i]);
        if Task then
            return string.find(Task, "BATTLE") ~= nil;
        end
    end
    return false;
end

function AiArmy:IsMoving()
    for i= table.getn(self.Troops), 1, -1 do
        if Logic.IsEntityMoving(self.Troops[i]) == true then
            return true;
        end
    end
    return false;
end

function AiArmy:IsTroopFighting(_TroopID)
    if IsExisting(_TroopID) then
        local Task = Logic.GetCurrentTaskList(_TroopID);
        return not Task or string.find(Task, "BATTLE") ~= nil;
    end
    return false;
end

function AiArmy:GetArmyOrientation()
    if table.getn(self.Troops) == 0 then
        return 0;
    else
        local Rotation = 0;
        for i= 1, table.getn(self.Troops), 1 do
            Rotation = Rotation + (Logic.GetEntityOrientation(self.Troops[i]));
        end
        return Rotation / table.getn(self.Troops);
    end
end

function AiArmy:GetArmyPosition()
    if table.getn(self.Troops) == 0 then
        return self.HomePosition;
    else
        return QuestTools.GetGeometricFocus(unpack(self.Troops));
    end
end

function AiArmy:GetArmyFrontPosition()
    if table.getn(self.Troops) == 0 then
        return self.HomePosition;
    else
        local Rotation = self:GetArmyOrientation() +90;
        local Postion = QuestTools.GetCirclePosition(
            self:GetArmyPosition(), self.RodeLength, Rotation -90
        );
        return Postion;
    end
end

function AiArmy:GetArmyTroops()
    return self.Troops;
end

function AiArmy:IsInArmy(_TroopID)
    for i= 1, table.getn(self.Troops), 1 do
        if self.Troops[i] == _TroopID then
            return true;
        end
    end
    return false;
end

function AiArmy:SetHiddenFromAI(_Flag)
    self.IsHiddenFromAI = _Flag == true;
    return self;
end

function AiArmy:GetAttackTarget()
    return self.AttackTarget;
end

function AiArmy:GetAttackTargetIndex()
    if self.AttackTarget then
        return self.AttackTarget.Current;
    end
    return 0;
end

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

function AiArmy:SetAttackTargetIndex(_Index)
    if self.AttackTarget then
        self.AttackTarget.Current = _Index;
        if _Index < 1 or table.getn(self.AttackTarget) > _Index then
            self.AttackTarget.Current = 1;
        end
    end
    return self;
end

function AiArmy:SetAttackAllowed(_Flag)
    self.AttackAllowed = _Flag == true;
    return self;
end

function AiArmy:SetGuardTarget(_Target)
    self.GuardTarget = _Target;
    return self;
end

function AiArmy:SetGuardPosList(_List)
    self.GuardPosList = _List;
    self.GuardPosList.Visited = {};
    return self;
end

function AiArmy:AddVisitedGuardPosition(_Position)
    table.insert(self.GuardPosList.Visited, _Position);
    return self;
end

function AiArmy:ClearVisitedGuardPositions()
    self.GuardPosList.Visited = {};
    return self;
end

function AiArmy:IsDefenceAllowed()
    return self.DefendAllowed == true;
end

function AiArmy:SetDefenceAllowed(_Flag)
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

function AiArmy:GetArmyBlockPositonMap(_Position)
    local Position = _Position or self:GetArmyPosition();
    if type(_Position) ~= "table" then
        Position = GetPosition(_Position);
    end
    local RowCount = self.TroopsPerLine or 3;
    local Rotation = self:GetArmyOrientation() -180;
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
    return PositionMap
end

function AiArmy:MoveAsBlock(_Position, _Agressive, _Abort)
    if not _Abort and self:IsMoving() then
        return;
    end
    local Position = _Position;
    if type(_Position) ~= "table" then
        Position = GetPosition(_Position);
    end
    local RowCount = self.TroopsPerLine or 3;
    local Rotation = self:GetArmyOrientation() -180;
    local Distance = 500;

    local PositionMap = self:GetArmyBlockPositonMap(Position);
    
    if table.getn(self.Troops) == 1 then
        local TroopPosition = PositionMap[self.Troops[1]];
        if _Agressive then
            Logic.GroupAttackMove(self.Troops[1], TroopPosition.X, TroopPosition.Y, 0 + Rotation);
        else
            Logic.MoveSettler(self.Troops[1], TroopPosition.X, TroopPosition.Y, 0 + Rotation);
        end
    else
        for i= 1, table.getn(self.Troops), 1 do
            local TroopPosition = PositionMap[self.Troops[i]];
            if _Agressive then
                Logic.GroupAttackMove(self.Troops[i], TroopPosition.X, TroopPosition.Y, 0 + Rotation);
            else
                Logic.MoveSettler(self.Troops[i], TroopPosition.X, TroopPosition.Y, 0 + Rotation);
            end
        end
    end
end

function AiArmy:Move(_Positon, _Abort)
    local Positon = _Positon;
    if type(Positon) ~= "table" then
        Positon = GetPosition(Positon);
    end
    for i= table.getn(self.Troops), 1, -1 do
        if _Abort or not Logic.IsEntityMoving(self.Troops[i]) then
            Logic.MoveSettler(self.Troops[i], Positon.X, Positon.Y, -1);
        end
    end
end

function AiArmy:Attack(_TargetID, _Abort)
    for i= table.getn(self.Troops), 1, -1 do
        if _Abort or not Logic.IsEntityMoving(self.Troops[i]) then
            Logic.GroupAttack(self.Troops[i], _TargetID);
        end
    end
end

function AiArmy:AttackMove(_Positon, _Abort)
    local Positon = _Positon;
    if type(Positon) ~= "table" then
        Positon = GetPosition(Positon);
    end
    for i= table.getn(self.Troops), 1, -1 do
        if _Abort or not Logic.IsEntityMoving(self.Troops[i]) then
            Logic.GroupAttackMove(self.Troops[i], Positon.X, Positon.Y, -1);
        end
    end
end

function AiArmy:MoveTroop(_TroopID, _Positon, _Abort)
    if _Abort or not Logic.IsEntityMoving(_TroopID) then
        local Positon = _Positon;
        if type(Positon) ~= "table" then
            Positon = GetPosition(Positon);
        end
        Logic.MoveSettler(_TroopID, Positon.X, Positon.Y, -1);
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
        Logic.GroupAttackMove(_TroopID, Positon.X, Positon.Y, -1);
    end
end

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
    for k, v in pairs(self.Troops) do
        if v then
            local Cur = Logic.LeaderGetNumberOfSoldiers(v);
            local Max = Logic.LeaderGetMaxNumberOfSoldiers(v);
            if Max > 0 and Cur < Max then
                table.insert(Weak, v);
                self.Troops[k] = nil;
            end
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
        DestroyEntity(Troops[i]);
    end
end

function AiArmy:GetSpawnerProducers()
    local SpawnerList = {};
    for k, v in pairs(self.Producers) do
        if v and v.IsSpawner then
            if QuestTools.GetReachablePosition(self.HomePosition, v.ApproachPosition) ~= nil then
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
        if Logic.IsHero(self.Troops[i]) == 0 then
            if not IsExisting(self.Troops[i]) then
                table.remove(self.Troops, i);
            end
        else
            if not IsExisting(self.Troops[i]) or Logic.GetEntityHealth(self.Troops[i]) == 0 then
                -- TODO: What should we do with a drunken sailor?
                -- SetPosition(self.Troops[i], GetPosition(self.HomePosition));
                table.remove(self.Troops, i);
            end
        end
    end
end

function AiArmy:ClearDeadTroopTargets()
    for i= table.getn(self.Troops), 1, -1 do
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

function AiArmy:ClearTargets()
    for i= 1, table.getn(self.Troops), 1 do
        if AiArmyList[self.ArmyID].TroopProperties[self.Troops[i]] then
            AiArmyList[self.ArmyID].TroopProperties[self.Troops[i]].Target = 0;
        end
    end
end

-- -------------------------------------------------------------------------- --

function AiArmy:Operate()
    if self.ArmyIsDead then
        return true;
    end
    if self.ArmyIsPaused then
        return false;
    end

    self.AssembleTimer = self.AssembleTimer +1;

    self:ClearDeadTroops();
    self:ClearDeadTroopTargets();

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
    elseif self.State == ArmyStates.Retreat then
        self:RetreatStateController();
    elseif self.State == ArmyStates.Refill then
        self:RefillStateController();
    end
    return false;
end

-- -------------------------------------------------------------------------- --

function AiArmy:IdleStateController()
    -- check retreat condition
    if self:CalculateStrength() < self.RetreatStrength then
        self.State = ArmyStates.Retreat;
        self:ClearTargets();
        self:ResetArmySpeed();
        return;
    end

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
        self:NormalizedArmySpeed();
        self:ClearTargets();
        return;
    end
end

-- -------------------------------------------------------------------------- --

function AiArmy:AdvanceStateController()
    -- check retreat condition
    if self:CalculateStrength() < self.RetreatStrength then
        self.State = ArmyStates.Retreat;
        self.SubState = ArmySubStates.None;
        self:ClearTargets();
        self:ResetArmySpeed();
        return;
    end
    
    -- check has target
    if not self.AttackTarget and not self.GuardTarget then
        self.State = ArmyStates.Retreat;
        self.SubState = ArmySubStates.None;
        self.Target = nil;
        self:ResetArmySpeed();
        return;
    end

    -- find enemies
    local Position = self:GetArmyFrontPosition();
    local Enemies = self:GetEnemiesInArea(Position, self.RodeLength);
    if table.getn(Enemies) > 0 then
        self.BattleTarget = Position;
        self.State = ArmyStates.Battle;
        self.SubState = ArmySubStates.None;
        self:ResetArmySpeed();
        return;
    end

    -- advance to target
    if QuestTools.GetDistance(self.Target, self:GetArmyPosition()) > self.RodeLength then
        if not self:IsMoving() and not self:IsFighting() then
            -- self:Move(self.Target);
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
            self.GuardStartTime = Logic.GetTime();
            self:ResetArmySpeed();
        else
            self.State = ArmyStates.Retreat;
            self.SubState = ArmySubStates.None;
            self.Target = nil;
            self:ResetArmySpeed();
        end
        return;
    end
    self:Assemble(1600);
end

-- -------------------------------------------------------------------------- --

function AiArmy:BattleStateController()
    -- check retreat condition
    if self:CalculateStrength() < self.RetreatStrength then
        self.BattleTarget = nil;
        self.State = ArmyStates.Retreat;
        self.SubState = ArmySubStates.None;
        self:ClearTargets();
        return;
    end

    -- find enemies
    local AreaSize = self.RodeLength;
    local AreaCenter = self.BattleTarget;
    local Enemies = self:GetEnemiesInArea(AreaCenter, AreaSize);
    if table.getn(Enemies) == 0 then
        self.BattleTarget = nil;
        self.State = ArmyStates.Advance;
        self.SubState = ArmySubStates.None;
        self:NormalizedArmySpeed();
        self:MoveAsBlock(self.Target, false, true);
        return;
    else
        local Enemies = self:GetEnemiesInArea(AreaCenter, AreaSize);
        self:ControlTroops(AreaCenter, Enemies);
    end
    self:Assemble(self.RodeLength);
end

-- -------------------------------------------------------------------------- --

function AiArmy:ObliberateStateController()
    -- check retreat condition
    if self:CalculateStrength() < self.RetreatStrength then
        self.State = ArmyStates.Retreat;
        self:ClearTargets();
        return;
    end
    
    -- check has target
    if not self.AttackTarget then
        self.State = ArmyStates.Retreat;
        self.SubState = ArmySubStates.None;
        self.Target = nil;
        return;
    end

    -- find enemies
    local AreaSize = self.RodeLength + self.OuterRange;
    local AreaCenter = self:GetArmyPosition();
    local Enemies = self:GetEnemiesInArea(AreaCenter, AreaSize);
    if table.getn(Enemies) == 0 then
        self.State = ArmyStates.Retreat;
        self.SubState = ArmySubStates.None;
        self.Target = nil;
        return;
    else
        local Enemies = self:GetEnemiesInArea(AreaCenter, AreaSize);
        self:ControlTroops(AreaCenter, Enemies);
    end
    self:Assemble(AreaSize);
end

-- -------------------------------------------------------------------------- --

function AiArmy:GuardStateController()
    -- check retreat condition
    if self:CalculateStrength() < self.RetreatStrength then
        self.State = ArmyStates.Retreat;
        self:ClearTargets();
        return;
    end

    -- check has target
    if not self.GuardTarget then
        self.State = ArmyStates.Retreat;
        return;
    end

    -- end guard after time is up
    if self.GuardMaximumTime > -1 then
        if self.GuardStartTime + self.GuardMaximumTime < Logic.GetTime() then
            self:ClearTargets();
            self.SubState = ArmySubStates.None;
            self.State = ArmyStates.Retreat;
            self.GuardTarget = nil;
            self.Target = nil;
            return;
        end
    end

    -- find enemies
    local AreaSize = self.RodeLength + self.OuterRange;
    local AreaCenter = self:GetArmyPosition();
    local Enemies = self:GetEnemiesInArea(AreaCenter, AreaSize);
    if table.getn(Enemies) == 0 then
        self:Assemble(self.RodeLength);
        return;
    else
        local Enemies = self:GetEnemiesInArea(AreaCenter, AreaSize);
        self:ControlTroops(AreaCenter, Enemies);
    end
    self:Assemble(AreaSize);
end

-- -------------------------------------------------------------------------- --

function AiArmy:RetreatStateController()
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
        local Weak = self:GetWeakTroops();
        self:DispatchTroopsToProducers(Weak);
        self:Move(self.HomePosition, self:IsFighting());
        self.GuardTarget = nil;
        self.AttackTarget = nil;
    end
    self:ClearTargets();
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
                            self:ChoseFormation(ID);
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
                    if QuestTools.GetReachablePosition(self.HomePosition, v.ApproachPosition) ~= nil then
                        local ID = v:GetTroop();
                        if ID > 0 then
                            self:ChoseFormation(ID);
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
        for i= 1, table.getn(self.Troops), 1 do
            if self.SubState ~= ArmySubStates.Assemble then
                if GetDistance(self.Troops[i], PositionMap[self.Troops[i]]) > _Area then
                    IsScattered = true;
                    break;
                end
            end
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
        if (self.State ~= ArmyStates.Retreat and self.State ~= ArmyStates.Refill) then
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
    if self.TroopProperties[_TroopID].Command +1 < Logic.GetTime() then
        local Sight = Logic.GetEntityExplorationRange(_TroopID) * 100;
        if  QuestTools.GetDistance(_TroopID, _EnemyID) < Sight then
            if not self:IsTroopFighting(_TroopID) then
                self:TroopAttack(_TroopID, _EnemyID, true);
            end
        else
            self:TroopAttackMove(_TroopID, _EnemyID, false);
        end
        self.TroopProperties[_TroopID].Command = Logic.GetTime();
    end
end

-- -------------------------------------------------------------------------- --

function AiArmy:ChoseFormation(_TroopID, _Function)
    if _Function then
        _Function(_TroopID);
        return;
    end
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

function AiArmy:CalculateStrength()
    local CurStrength = 0;
    local MaxStrength = 0;
    for i= table.getn(self.Troops), 1, -1 do
        if Logic.IsEntityInCategory(self.Troops[i], EntityCategories.Cannon) == 1 then
            MaxStrength = MaxStrength + 5;
            CurStrength = CurStrength + 5;
        elseif Logic.IsLeader(self.Troops[i]) == 1 then
            MaxStrength = MaxStrength + 1 + Logic.LeaderGetMaxNumberOfSoldiers(self.Troops[i]);
            CurStrength = CurStrength + 1 + Logic.LeaderGetNumberOfSoldiers(self.Troops[i]);
        else
            MaxStrength = MaxStrength + 1;
            CurStrength = CurStrength + 1;
        end
    end
    if MaxStrength == 0 then
        return 0;
    end
    return CurStrength/MaxStrength;
end

function AiArmy:GetEnemiesInRodeLength(_Position)
    return self:GetEnemiesInArea(_Position, self.RodeLength);
end

function AiArmy:GetEnemiesInArea(_Position, _Range, _PlayerID)
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
                    if Logic.IsEntityInCategory(PlayerEntities[j], EntityCategories.Cannon) == 1
                    or (Logic.IsHero(PlayerEntities[j]) == 1 and Logic.GetCamouflageTimeLeft(PlayerEntities[j]) == 0)
                    or Logic.IsBuilding(PlayerEntities[j]) == 1 
                    or Logic.IsLeader(PlayerEntities[j]) == 1 then
                        table.insert(AllEnemiesInSight, PlayerEntities[j]);
                    end
                end
            end
        end
    end
    return AllEnemiesInSight;
end

-- -------------------------------------------------------------------------- --

function AiArmy:TargetEnemy(_TroopID, _Enemies)
    if self.TroopProperties[_TroopID] then
        if self.TroopProperties[_TroopID].Target ~= 0 then
            local OldTarget = self.TroopProperties[_TroopID].Target;
            if IsExisting(OldTarget) and Logic.GetEntityHealth(OldTarget) > 0 then
                self.TroopProperties[_TroopID].Time = self.TroopProperties[_TroopID].Time -1;
                if self.TroopProperties[_TroopID].Time > 0 then
                    return OldTarget;
                end
            end
        end

        local Enemies = _Enemies or self:GetEnemiesInRangeOfTroop(_TroopID);
        if table.getn(Enemies) > 0 then
            self.TroopProperties[_TroopID].Target = Enemies[1];
            self.TroopProperties[_TroopID].Time   = 15;
            return Enemies[1];
        end
    end
    return 0;
end

function AiArmy:GetEnemiesInRangeOfTroop(_TroopID)
    local Range = self.RodeLength + self.OuterRange;
    local Enemies = self:GetEnemiesInArea(_TroopID, Range);
    for i= table.getn(Enemies), 1, -1 do
        if not IsExisting(Enemies[i]) or Logic.GetEntityHealth(Enemies[i]) == 0 then
            table.remove(Enemies, i);
        end
    end
    if table.getn(Enemies) > 1 then
        table.sort(Enemies, function(a, b)
            local Cost1 = math.floor(QuestTools.GetDistance(a, _TroopID));
            local Factor1 = self:GetTargetCostFactorForTroop(a, _TroopID);
            local Priority1 = Cost1 * Factor1;
            
            local Cost2 = math.floor(QuestTools.GetDistance(b, _TroopID));
            local Factor2 = self:GetTargetCostFactorForTroop(b, _TroopID);
            local Priority2 = Cost2 * Factor2;

            if Priority1 == 0 then
                return false;
            elseif Priority2 == 0 then
                return true;
            elseif Priority1 == 0 and Priority2 == 0 then
                return false;
            else
                return Priority1 > Priority2;
            end
        end)
    end
    return Enemies;
end

function AiArmy:GetTargetCostFactorForTroop(_TargetID, _TroopID)
    local Factor = 1.0;
    local Priority = self:GetTargetCostFactors(_TargetID);
    for k, v in pairs(QuestTools.GetEntityCategoriesAsString(_TargetID)) do
        if Priority[v] and Priority[v] > 0 then
            Factor = Factor * ((1/Priority[v]) or 1);
        else
            Factor = 0;
            break;
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
    ["MilitaryBuilding"] = 6,
    ["EvilLeader"] = 5,
    ["LongRange"] = 3,
    ["Hero10"] = 2,
};
GroupTargetingPriorities.LightCavalry = {
    ["Hero"] = 6,
    ["Cannon"] = 5,
    ["MilitaryBuilding"] = 4,
    ["Spear"] = 3,
    ["Sword"] = 3,
    ["Hero10"] = 3,
    ["Hero4"] = 3,
    ["EvilLeader"] = 0,
    ["LongRange"] = 0,
    ["Rifle"] = 0,
};
GroupTargetingPriorities.HeavyCavalry = {
    ["Hero"] = 6,
    ["Cannon"] = 5,
    ["LongRange"] = 3,
    ["MilitaryBuilding"] = 3,
    ["Sword"] = 3,
    ["Hero10"] = 3,
    ["Hero4"] = 3,
    ["Spear"] = 0,
};
GroupTargetingPriorities.Sword = {
    ["Hero"] = 6,
    ["Spear"] = 5,
    ["Cannon"] = 5,
    ["LongRange"] = 4,
    ["Serf"] = 3,
    ["CavalryHeavy"] = 0,
};
GroupTargetingPriorities.Spear = {
    ["CavalryHeavy"] = 6,
    ["CavalryLight"] = 6,
    ["MilitaryBuilding"] = 4,
    ["Serf"] = 2,
    ["Sword"] = 0,
    ["LongRange"] = 0,
};
GroupTargetingPriorities.Ranged = {
    ["MilitaryBuilding"] = 6,
    ["CavalryHeavy"] = 5,
    ["CavalryLight"] = 5,
    ["VillageCenter"] = 3,
    ["Headquarters"] = 3,
    ["Hero"] = 3,
    ["Hero10"] = 2,
    ["Hero4"] = 2,
    ["EvilLeader"] = 0,
};
GroupTargetingPriorities.Rifle = {
    ["EvilLeader"] = 6,
    ["LongRange"] = 6,
    ["Cannon"] = 5,
    ["MilitaryBuilding"] = 5,
    ["VillageCenter"] = 3,
    ["Headquarters"] = 3,
    ["Hero10"] = 2,
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

