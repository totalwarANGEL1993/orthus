-- ########################################################################## --
-- #  AI Army                                                               # --
-- #  --------------------------------------------------------------------  # --
-- #    Author:   totalwarANGEL                                             # --
-- ########################################################################## --

---
-- This module is used by the AI controller to create armies. Using or Changing
-- functions of the army is at your own risk.
--
-- <b>Required modules:</b>
-- <ul>
-- <li>qsb.oop</li>
-- <li>qsb.quest.questsync</li>
-- <li>qsb.quest.questtools</li>
-- <li>qsb.ai.aitrooprecruiter</li>
-- <li>qsb.ai.aitroopspawner</li>
-- </ul>
--
-- @set sort=true
--

ArmySubBehavior = {
    None      = 1,
    Assemble  = 2,
};

AiArmy = {
    PlayerID             = -1,
    ArmyID               = -1,
    Troops               = {},
    AbandonedTroops      = {},
    IncommingTroops      = {},
    TroopProperties      = {},
    TroopCount           = 8,
    RodeLength           = 3000,
    OuterRange           = 0,
    AbandonStrength      = 0.10,
    LastTick             = 0,
    Producers            = {},


    IsRespawningArmy     = false,
    InitialSpawned       = false,
    IsHiddenFromAI       = false,
    IsIgnoringProducer   = false,
    IsDirectlyTargeting  = true,

    BehaviorQueue        = {},
    CurrentBehavior      = nil,
    AssembleTimer        = 0,
    HomePosition         = nil,
}

AiArmyControllerJobId = nil;
AiArmyAttackedJobId = nil;
AiArmyIdSequence = 0;
AiArmyTroopIDToArmyID = {};
AiArmyIncommingTroopIDToArmyID = {};
AiArmyTickFrequency = 3;
AiArmyList = {};

-- -------------------------------------------------------------------------- --

function AiArmy:construct(_PlayerID, _Home, _Range, _TroopAmount)
    AiArmyIdSequence = AiArmyIdSequence +1;
    self.PlayerID = _PlayerID;
    self.ArmyID = AiArmyIdSequence;
    self.TickTime = math.mod(AiArmyIdSequence, AiArmyTickFrequency);
    self.HomePosition = _Home;
    self.RodeLength = _Range;
    self.OuterRange = _Range * 0.75;
    self.TroopCount = (_TroopAmount > 20 and 20) or _TroopAmount;

    self:StartControllerJob();
    table.insert(AiArmyList, self);
end
class(AiArmy);

-- -------------------------------------------------------------------------- --

function AiArmy:StartControllerJob()
    -- Controller
    if not AiArmyControllerJobId then
        AiArmyControllerJobId = QuestTools.StartSimpleHiResJobEx(function()
            return AiArmy:ArmyOperationScheduler();
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

function AiArmy:ArmyOperationScheduler()
    if AiArmy ~= self then
        return;
    end

    -- get armies needed to be scheduled
    local QualifyingArmies = {};
    for i= 1, table.getn(AiArmyList), 1 do
        if math.mod(Logic.GetCurrentTurn(), AiArmyTickFrequency) == AiArmyList[i].TickTime then
            table.insert(QualifyingArmies, i);
        end
    end

    -- schedule army
    if table.getn(QualifyingArmies) > 0 then
        -- sort armys by last execution
        if table.getn(QualifyingArmies) > 1 then
            table.sort(QualifyingArmies, function(a, b)
                return AiArmyList[a].LastTick < AiArmyList[b].LastTick;
            end);
        end
        -- execute operation
        if AiArmyList[QualifyingArmies[1]] then
            AiArmyList[QualifyingArmies[1]]:Operate();
            AiArmyList[QualifyingArmies[1]].LastTick = self:GetTime();
        end
    end
end

function AiArmy:ArmyAttackedReactionController(_Attacker, _Attacked)
    for i= 1, table.getn(_Attacked), 1 do
        for j= 1, table.getn(AiArmyList), 1 do
            if not AiArmyList[j]:IsDead() then
                if not AiArmyList[j]:IsExecutingBehavior("Battle") then
                    local VictimID = _Attacked[i];
                    if Logic.IsEntityInCategory(VictimID, EntityCategories.Soldier) == 1 then
                        VictimID = QuestTools.SoldierGetLeader(VictimID);
                    end
                    if VictimID and QuestTools.IsInTable(VictimID, AiArmyList[j].Troops) then
                        AiArmyList[j]:InsertBehavior(AiArmyBehavior:New(
                            "Battle",
                            GetPosition(_Attacker),
                            4000
                        ));
                        AiArmyList[j]:InvalidateCurrentBehavior();
                        AiArmyList[j]:NextBehavior();
                        break;
                    end
                end
            end
        end
    end
end

function AiArmy:Operate()
    self.ArmyOrientationCache = nil;
    self.ArmyPositionCache = nil;
    self.ArmyFrontCache = nil;
    self.ArmyFormationCache = nil;

    self.AssembleTimer = self.AssembleTimer +1;

    self:ClearDeadTroops();
    self:ClearDeadIncommingTroops();
    self:ClearDeadTroopTargets();
    if self:IsDead() then
        self:AbandonRemainingTroops();
        self:CheckAbandonedTroops();
        return;
    end
    self:CheckIncommingTroops();
    self:CheckAbandonedTroops();

    if  not self:IsExecutingBehavior("Retreat") 
    and not self:IsExecutingBehavior("Refill") then
        if self:CalculateStrength(true) < self.AbandonStrength then
            self:ClearBehaviorsNotLooped();
            local NewBehavior = AiArmyBehavior:New("Retreat");
            self:InsertBehavior(NewBehavior);
            self:SetSubBehavior(ArmySubBehavior.None);
            self:AbandonRemainingTroops();
            self:ClearTargets();
            self:ResetArmySpeed();
        end
    end
    self:NextBehavior();
end

-- -------------------------------------------------------------------------- --

function AiArmy:GetTime()
    return math.floor(Logic.GetTime() * 10);
end

---
-- Adds an entity to the army.
--
-- Currently the army supports only leaders and cannons. Scouts and thieves are
-- tolerated but there is no distinction between them and the normal leaders.
-- Migrating troops are advancing aggressive to the central point of the army,
-- attacking any enemy in sight.
--
-- <b>Note:</b> Adding an entity instantly can cause the problem that the
-- center of the army becomes way off and targeting might not work.
--
-- <b>Note:</b> If the regular members have been defeated the home position
-- becomes the new central point and troops will migrating there.
--
-- @param[type=number]  _TroopID   ID of troop
-- @param[type=boolean] _Instantly Add entity in an instant
-- @within Properties
--
function AiArmy:AddEntity(_TroopID, _Instantly)
    if not self:IsTroopAlive(_TroopID) then
        return;
    end
    if Logic.IsEntityInCategory(_TroopID, EntityCategories.Cannon) ==  1
    or Logic.IsLeader(_TroopID) == 1 then
        return;
    end
    if not QuestTools.IsInTable(_TroopID, self.Troops) and not QuestTools.IsInTable(_TroopID, self.IncommingTroops) then
        return;
    end
    self:CallChoseFormation(_TroopID);
    if _Instantly then
        AiArmyTroopIDToArmyID[_TroopID] = self.ArmyID;
        table.insert(self.Troops, _TroopID);
    else
        AiArmyIncommingTroopIDToArmyID[_TroopID] = self.ArmyID;
        table.insert(self.IncommingTroops, _TroopID);
    end
end

---
-- Removes an entity from the army.
--
-- @param[type=number] _TroopID ID of troop
-- @within Properties
--
function AiArmy:RemoveEntity(_TroopID)
    for i= table.getn(self.Troops), 1, -1 do
        if self.Troops[i] == _TroopID then
            AiArmyTroopIDToArmyID[_TroopID] = nil;
            table.remove(self.Troops, i);
        end
    end
    self:RemoveIncommingEntity(_TroopID);
end

---
-- Removes an entity only from the incomming list of the army.
--
-- @param[type=number] _TroopID ID of troop
-- @within Properties
--
function AiArmy:RemoveIncommingEntity(_TroopID)
    for i= table.getn(self.IncommingTroops), 1, -1 do
        if self.IncommingTroops[i] == _TroopID then
            AiArmyIncommingTroopIDToArmyID[_TroopID] = nil;
            table.remove(self.IncommingTroops, i);
        end
    end
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
                    if self:IsTroopAlive(self.Troops[i]) then
                        Logic.SetTaskList(self.Troops[i], TaskLists.TL_DIE);
                    end
                end
            end
        end
    end
    self.Troops = {};

    self.ArmyIsDead = true;
    self.ArmyIsPaused = true;
    return self;
end

---
-- Checks if an army is dead.
--
-- An army is dead when all of their producers are destroyed. Additionally the
-- army can stay alive until every member is killed.
--
-- <b>Note:</b> Selfrecruiting armies will never be dead. Check player insted.
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
    if not self.IsRespawningArmy then
        return false;
    end
    if self.IsIgnoringProducer then
        return table.getn(self.Troops) == 0 and table.getn(self.IncommingTroops) == 0;
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
-- Switches the targeting mode between accurate and inaccurate. Accurate means
-- ranged troops will target enemies at max range. Inaccurate on the other hand
-- makes them behave normally.
--
-- @param[type=boolean] _Flag Direct targeting flag
-- @within Properties
--
function AiArmy:SetDirectlyTargeting(_Flag)
    self.IsDirectlyTargeting = _Flag == true;
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
        if Logic.IsEntityInCategory(self.Troops[i], EntityCategories.Cannon) == 0 then
            if self:IsTroopFighting(self.Troops[i]) == true then
                return true;
            end
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
        if self:IsTroopMoving(self.Troops[i]) == true then
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
    if self:IsTroopAlive(_TroopID) then
        return string.find(Logic.GetCurrentTaskList(_TroopID) or "", "BATTLE") ~= nil;
    end
    return false;
end

---
-- Checks if a troop of the army is moving.
--
-- @param[type=number] _TroopID ID of troop
-- @return[type=boolean] Troop is moving
-- @within Properties
--
function AiArmy:IsTroopMoving(_TroopID)
    if self:IsTroopAlive(_TroopID) then
        return Logic.IsEntityMoving(_TroopID) == true;
    end
    return false;
end

function AiArmy:IsTroopAlive(_TroopID)
    return self:IsEntityAlive(_TroopID);
end

function AiArmy:IsEntityAlive(_ID)
    if IsExisting(_ID) then
        local TaskList = Logic.GetCurrentTaskList(_ID);
        local Health = Logic.GetEntityHealth(_ID);
        if Health > 0 and (not TaskList or not string.find(TaskList, "TL_DIE")) then
            return true;
        end
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
-- <b>Note:</b> Troops only count as army member if they are added to the
-- troops. Incomming troops do not count as in the army.
--
-- @param[type=number] _TroopID ID of troop
-- @return[type=boolean] Is in army
-- @within Properties
--
function AiArmy:IsInArmy(_TroopID)
    if AiArmyTroopIDToArmyID[_TroopID] then
        if self:IsTroopAlive(_TroopID) then
            return AiArmyTroopIDToArmyID[_TroopID] == self.ArmyID;
        end
        AiArmyTroopIDToArmyID[_TroopID] = nil;
    end
    return false;
end

---
-- Checks if the passed entity ID is an incomming member.
--
-- @param[type=number] _TroopID ID of troop
-- @return[type=boolean] Is in army
-- @within Properties
--
function AiArmy:IsIncomming(_TroopID)
    if AiArmyIncommingTroopIDToArmyID[_TroopID] then
        if self:IsTroopAlive(_TroopID) then
            return AiArmyIncommingTroopIDToArmyID[_TroopID] == self.ArmyID;
        end
        AiArmyIncommingTroopIDToArmyID[_TroopID] = nil;
    end
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

function AiArmy:SetSubBehavior(_State)
    self.SubBehavior = _State;
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
-- @within Calculator
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
    if self.ArmyFrontCache then
        return self.ArmyFrontCache;
    end
    if not self.GetArmyFront then
        self.ArmyFrontCache = self.DefaultGetArmyFront(self);
        return self.ArmyFrontCache;
    end
    self.ArmyFrontCache = self.GetArmyFront(self);
    return self.ArmyFrontCache;
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
-- @within Calculator
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
            local CurrentDistance = self:GetDistanceSqared(self.Troops[i], ArmyPosition);
            if CurrentDistance > MaxDistance then
                MaxDistance = CurrentDistance;
            end
        end
        local Rotation = self:CallGetArmyOrientation();
        local Position = QuestTools.GetCirclePosition(
            ArmyPosition, math.sqrt(MaxDistance) * 1.5, Rotation
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
        if self.Troops[i] and self:IsTroopAlive(self.Troops[i]) then
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
                if not self:IsTroopAlive(self.Troops[i]) then
                    local ID = table.remove(self.Troops, i);
                    AiArmyTroopIDToArmyID[ID] = nil;
                end
            else
                if not IsExisting(self.Troops[i]) then
                    -- TODO: What should we do with a drunken sailor?
                    -- SetPosition(self.Troops[i], GetPosition(self.HomePosition));
                    local ID = table.remove(self.Troops, i);
                    AiArmyTroopIDToArmyID[ID] = nil;
                end
            end
        end
    end
end

function AiArmy:ClearDeadIncommingTroops()
    for i= table.getn(self.IncommingTroops), 1, -1 do
        if self.IncommingTroops[i] then
            if Logic.IsHero(self.IncommingTroops[i]) == 0 then
                if not self:IsTroopAlive(self.IncommingTroops[i]) then
                    local ID = table.remove(self.IncommingTroops, i);
                    AiArmyIncommingTroopIDToArmyID[ID] = nil;
                end
            else
                if not IsExisting(self.IncommingTroops[i]) then
                    -- TODO: What should we do with a drunken sailor?
                    -- SetPosition(self.Troops[i], GetPosition(self.HomePosition));
                    local ID = table.remove(self.IncommingTroops, i);
                    AiArmyIncommingTroopIDToArmyID[ID] = nil;
                end
            end
        end
    end
end

function AiArmy:CheckIncommingTroops()
    local ArrivalDistance = 1500^2;
    for i= table.getn(self.IncommingTroops), 1, -1 do
        if self:GetDistanceSqared(self.IncommingTroops[i], self:GetArmyPosition()) < ArrivalDistance then
            self:AddEntity(self.IncommingTroops[i], true);
            self:RemoveIncommingEntity(self.IncommingTroops[i]);
        else
            self:TroopAttackMove(self.IncommingTroops[i], self:GetArmyPosition(), false);
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

function AiArmy:ClearDeadTroopTargets()
    for i= table.getn(self.Troops), 1, -1 do
        if self.Troops[i] then
            if not self:IsTroopAlive(self.Troops[i]) then
                self.TroopProperties[self.Troops[i]] = nil;
            else
                if self.TroopProperties[self.Troops[i]] then
                    if self.TroopProperties[self.Troops[i]].Target ~= 0 then
                        local ID = self.TroopProperties[self.Troops[i]].Target;
                        if not self:IsTroopAlive(ID) then
                            self.TroopProperties[self.Troops[i]].Target = 0;
                            self.TroopProperties[self.Troops[i]].Time   = 0;
                        end
                    end
                end
            end
        end
    end
end

function AiArmy:AbandonRemainingTroops()
    for i= table.getn(self.Troops), 1, -1 do
        local ID = table.remove(self.Troops, i);
        if ID and self:IsTroopAlive(ID) then
            table.insert(self.AbandonedTroops, ID);
        end
    end
end

function AiArmy:CheckAbandonedTroops()
    for i= table.getn(self.AbandonedTroops), 1, -1 do
        local ID = self.AbandonedTroops[i];
        if self:IsTroopAlive(ID) then
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

function AiArmy:GetTroopBaseSpeed(_TroopID)
    local Speed = 0;
    if not self:IsTroopAlive(_TroopID) then
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
    if self:IsTroopAlive(_TroopID) then
        Logic.SetSpeedFactor(_TroopID, _Factor);
        if Logic.IsLeader(_TroopID) == 1 then
            local Soldiers = {Logic.GetSoldiersAttachedToLeader(_TroopID)};
            for i= 2, Soldiers[1]+1, 1 do
                if self:IsEntityAlive(_TroopID) then
                    Logic.SetSpeedFactor(Soldiers[i], _Factor);
                end
            end
        end
    end
end

-- -------------------------------------------------------------------------- --

function AiArmy:Assemble(_Area)
    local IsScattered = false;
    if self.AssembleTimer >= 30 then
        self.AssembleTimer = 0;
        local PositionMap = self:GetArmyBlockPositonMap(self:GetArmyPosition());
        local TroopCount = table.getn(self.Troops);
        local TotalDistance = 0;
        for i= 1, TroopCount, 1 do
            if self.SubBehavior ~= ArmySubBehavior.Assemble then
                if PositionMap[self.Troops[i]] then
                    TotalDistance = TotalDistance + self:GetDistanceSqared(self.Troops[i], PositionMap[self.Troops[i]]);
                end
            end
        end
        if TotalDistance / TroopCount > _Area^2 then
            IsScattered = true;
        end
    end
    if IsScattered then
        if self.SubBehavior ~= ArmySubBehavior.Assemble then
            self:MoveAsBlock(self:GetArmyPosition(), false, true);
            self.SubBehavior = ArmySubBehavior.Assemble;
        end
    else
        if self.SubBehavior == ArmySubBehavior.Assemble then
            self.SubBehavior = ArmySubBehavior.None;
        end
    end
end

-- -------------------------------------------------------------------------- --

function AiArmy:ControlTroops(_Position, _Enemies)
    local Position = _Position or self:GetArmyPosition();
    for i= 1, table.getn(self.Troops), 1 do

        self.TroopProperties[self.Troops[i]] = self.TroopProperties[self.Troops[i]] or {
            Target  = 0,
            Time    = 0,
        };
        self:ControlSingleTroop(self.Troops[i], Position, _Enemies);
    end
end

function AiArmy:ControlSingleTroop(_TroopID, _Position, _Enemies)
    local Target = self:TargetEnemy(_TroopID, _Enemies);
    if Target > 0 then
        if not self:IsTroopFighting(_TroopID) then
            AI.Army_EnableLeaderAi(_TroopID, (self.IsDirectlyTargeting and 0) or 1);
            
            if Logic.IsEntityInCategory(_TroopID, EntityCategories.Cannon) == 1 then
                self:CannonTroopAttackTarget(_TroopID, Target);
            elseif Logic.IsEntityInCategory(_TroopID, EntityCategories.CavalryLight) == 1 then
                if self.IsDirectlyTargeting then
                    self:TroopAttack(_TroopID, Target, true);
                else
                    self:TroopAttackMove(_TroopID, Target, true);
                end
            elseif Logic.IsEntityInCategory(_TroopID, EntityCategories.LongRange) == 1 then
                if self.IsDirectlyTargeting then
                    self:TroopAttack(_TroopID, Target, true);
                else
                    self:TroopAttackMove(_TroopID, Target, true);
                end
            else
                if self.IsDirectlyTargeting then
                    self:TroopAttack(_TroopID, Target, true);
                else
                    self:TroopAttackMove(_TroopID, Target, true);
                end
            end
        end
    else
        if self.IsDirectlyTargeting then
            self:MoveTroop(_TroopID, _Position, true);
        else
            self:TroopAttackMove(_TroopID, _Position, false);
        end
    end
end

function AiArmy:CannonTroopAttackTarget(_TroopID, _EnemyID)
    local Sight = Logic.GetEntityExplorationRange(_TroopID) * 100;
    if self:GetDistanceSqared(_TroopID, _EnemyID) < Sight^2 then
        self:TroopAttack(_TroopID, _EnemyID, true);
    else
        if self.IsDirectlyTargeting then
            self:MoveTroop(_TroopID, _EnemyID, true);
        else
            self:TroopAttackMove(_TroopID, _EnemyID, true);
        end
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
-- @within Calculator
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
-- @within Calculator
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
    for i= 1, table.getn(Score.Player), 1 do
        if i ~= PlayerID and Logic.GetDiplomacyState(PlayerID, i) == Diplomacy.Hostile then
            local PlayerEntities = {Logic.GetPlayerEntitiesInArea(i, 0, _Position.X, _Position.Y, _Range, 16)};
            for j= PlayerEntities[1]+1, 2, -1 do
                local EntityType = Logic.GetEntityType(PlayerEntities[j]);
                local TypeName = Logic.GetEntityTypeName(EntityType);
                
                if (
                    (Logic.IsBuilding(PlayerEntities[j]) == 1 and 
                     Logic.IsEntityInCategory(PlayerEntities[j], EntityCategories.Workplace) == 0) or
                    (Logic.IsHero(PlayerEntities[j]) == 1 and
                     Logic.GetCamouflageDuration(PlayerEntities[j]) == 0) or
                    Logic.IsLeader(PlayerEntities[j]) == 1 or
                    Logic.IsEntityInCategory(PlayerEntities[j], EntityCategories.Cannon) == 1
                )
                and (
                    not FoundationTopTypeToFoundationType[TypeName] and
                    Logic.IsEntityInCategory(PlayerEntities[j], EntityCategories.Thief) == 0 and
                    Logic.GetEntityHealth(PlayerEntities[j]) > 0
                )
                then
                    table.insert(AllEnemiesInSight, PlayerEntities[j]);
                end
            end
        end
    end
    return AllEnemiesInSight;
end

function AiArmy:GetEnemiesInRodeLength(_Position)
    return self:CallGetEnemiesInArea(_Position, self.RodeLength);
end

function AiArmy:GetDistanceSqared(_Position1, _Position2)
    if (type(_Position1) == "string") or (type(_Position1) == "number") then
        _Position1 = GetPosition(_Position1);
    end
    if (type(_Position2) == "string") or (type(_Position2) == "number") then
        _Position2 = GetPosition(_Position2);
    end
    return ((_Position1.X - _Position2.X)^2) + ((_Position1.Y - _Position2.Y)^2);
end

FoundationTopTypeToFoundationType = {
    ["CB_Evil_Tower1_ArrowLauncher"] = "CB_Evil_Tower1",
    ["PB_DarkTower2_Ballista"]       = "PB_DarkTower2",
    ["PB_DarkTower3_Cannon"]         = "PB_DarkTower3",
    ["PU_Hero2_Cannon1"]             = "PU_Hero2_Foundation1",
    ["PU_Hero3_TrapCannon"]          = "PU_Hero3_Trap",
}

-- -------------------------------------------------------------------------- --

---
-- Returns the relative strength of the army.
--
-- The number represents the persentage of all troops that are still alive.
-- The value might be greater than 1 if troops have been added externally and
-- are still migrating ot the army.
--
-- @return[type=number] Current relative strength
-- @within Properties
--
function AiArmy:CalculateStrength(_WithIncomming)
    local CurStrength = 0;
    local MaxStrength = self.TroopCount;
    
    local Troops = copy(self.Troops, {});
    if _WithIncomming then
        Troops = copy(self.IncommingTroops, Troops);
    end
    
    for i= table.getn(Troops), 1, -1 do
        if Logic.IsLeader(Troops[i]) == 1 then
            local MaxSoldiers = Logic.LeaderGetMaxNumberOfSoldiers(Troops[i]);
            if MaxSoldiers > 0 then
                local CurSoldiers = Logic.LeaderGetNumberOfSoldiers(Troops[i]);
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

function AiArmy:NextBehavior()
    -- Get current command
    local Behavior = self.CurrentBehavior;
    if not Behavior then
        Behavior = self.BehaviorQueue[1];
        if not Behavior then
            if QuestTools.GetDistance(self:GetArmyPosition(), self.HomePosition) <= 1000 then
                Behavior = AiArmyBehavior:New("Idle", false);
            else
                Behavior = AiArmyBehavior:New("Retreat", false);
            end
            self:InsertBehavior(command);
        end
    end

    -- Set current command
    if self.CurrentBehavior ~= Behavior then
        self.CurrentBehavior = Behavior;
    end

    -- Execute command
    if self.CurrentBehavior:Run(self) then
        self.CurrentBehavior = nil;
        local Dequeued = self:DequeueBehavior();
        if Dequeued and Dequeued:IsLoop() then
            Dequeued:Reset();
            table.insert(self.BehaviorQueue, Dequeued);
        end
    end
end

function AiArmy:EnqueueBehavior(_Behavior)
    table.insert(self.BehaviorQueue, _Behavior);
    return self;
end

function AiArmy:DequeueBehavior()
    if table.getn(self.BehaviorQueue) > 0 then
        return table.remove(self.BehaviorQueue, 1);
    end
end

function AiArmy:InsertBehavior(_Behavior, _Index)
    table.insert(self.BehaviorQueue, _Index or 1, _Behavior);
    return self;
end

function AiArmy:RemoveBehavior(_Index)
    return table.remove(self.BehaviorQueue, _Index or 1);
end

function AiArmy:ClearBehaviors()
    self.CurrentBehavior = nil;
    self.BehaviorQueue = {};
    return self;
end

function AiArmy:ClearBehaviorsNotLooped()
    self.CurrentBehavior = nil;
    for i= table.getn(self.BehaviorQueue), 1, -1 do
        if not self.BehaviorQueue[i]:IsLoop() then
            table.remove(self.BehaviorQueue, i);
        end
    end
    return self;
end

function AiArmy:GetCurrentBehavior()
    return self.CurrentBehavior;
end

function AiArmy:InvalidateCurrentBehavior()
    self.CurrentBehavior = nil;
    return self;
end

function AiArmy:GetBehaviorInQueue(_Name)
    for i= 1, table.getn(self.BehaviorQueue), 1 do
        if self.BehaviorQueue[i].m_Identifier == _Name then
            return self.BehaviorQueue[i];
        end
    end
end

function AiArmy:IsValidBehavior(_Name)
    return type(AiArmyBehavior[Name]) == "table";
end

function AiArmy:IsBehaviorEnqueued(_Name)
    return self:GetBehaviorInQueue(_Name) ~= nil;
end

function AiArmy:IsExecutingBehavior(_Name)
    -- FIXME: This should never happen!
    if  not self.CurrentBehavior and not self.BehaviorQueue[1]
    and _Name == "Idle" then
        return true;
    end
    -- Check current command
    if self.CurrentBehavior then
        return self.CurrentBehavior.m_Identifier == _Name;
    end
    -- Check first command in queue
    if self.BehaviorQueue[1] and self.BehaviorQueue[1].m_Identifier == _Name then
        return true;
    end
    return false;
end

-- -------------------------------------------------------------------------- --

---
-- List of possible behavior for armies.
--
-- <b>Note:</b> If an army is attacked by the enemy it will always enter Battle
-- when not already battleing. In that case the position of the attacker is used
-- as anchor. The new created behavior will be set as the current behavior and
-- always the first in the queue.
--
-- @within AiArmyBehavior
--
-- @field Idle    The army is doing nothing.
-- @field Move    The army walks to the defined destination. Enemies are ignored
--                unless they attack the army.
-- @field Attack  The army walkst to the defined destination and will execute
--                Battle with outer range as area on arrival. While walking, the
--                army will always be aggressive.
-- @field Battle  The army is attacking all enemies in the area. If all enemies
--                are defeated, the behavior succeeds.
-- @field Guard   The army is staying at a position for awhile. If enemies
--                are detected, Battle is executed until enemies are defeated.
--                Setting guard time to -1 results in guarding forever.
-- @field Retreat The army is retreating to the home base. Retreat automatically
--                adds Refill after success.
-- @field Refill  The army is trying to replace fallen leaders and buy new
--                soldiers for the others.
--
AiArmyBehavior = {};

---
-- Creates a new instance of an behavior.
--
-- A behavior represents (in this case) a command that is put into a queue
-- together with others where they will be processed one after another. Some of
-- them can create new behaviors on their own and put them into the queue.
-- A behavior is finished when the action returns true. Behaviors can also be
-- executed in a loop. After one finished, it will automaticaly be reattached
-- at the end of the queue.
--
-- @param[type=string]  _Type Name of behavior
-- @param               ...   List of parameters
-- @param[type=boolean] _Loop Behavior is reattached after completion
-- @return[type=table] Instanciated behavior
-- @within AiArmyBehavior
-- @see AiArmyBehavior:Create
--
-- @usage -- Idle
-- AiArmyBehavior:New("Idle", _Loop);
-- -- Move
-- AiArmyBehavior:New("Move", _Target, _Distance, _Loop);
-- -- Attack
-- AiArmyBehavior:New("Attack", _Target, _Distance, _Loop);
-- -- Battle
-- AiArmyBehavior:New("Battle", _Position, _Distance, _Loop);
-- -- Guard
-- AiArmyBehavior:New("Guard", _Position, _Distance, _Time, _Loop);
-- -- Retreat
-- AiArmyBehavior:New("Retreat");
-- -- Refill
-- AiArmyBehavior:New("Refill");
--
function AiArmyBehavior:New(_Type, ...)
    arg = arg or {};
    if not AiArmyBehavior[_Type] then
        return;
    end
    return new (AiArmyBehavior[_Type], unpack(arg));
end

---
-- Creates a new custom behavior.
--
-- A custom behavior must have an unique name. You cannot create a behavior that
-- already exists.
--
-- A custom behavior needs an action function. First 3 parameter are fixed. The
-- function receives the self reference, the army reference and the loop flag.
-- All other parameters are optional. You can pass them like you would do with
-- default behaviors.
--
-- The reset function is optional and will be called after a behavior finished
-- and is removed (and might be reattached due to be looped) from the queue. It
-- receives the self reference as parameter.
--
-- After you created the behavior you can add fields by calling :AddField on the
-- behavior. A field can be accessey by using the self reference. Type 
-- self.m_Data.Fieldname to access the field. The main difference to parameters
-- is that they won't be passed when the action is called. Use them to control
-- states of your behavior.
--
-- <b>Note:</b> This feature is considered expert level! The default behavior
-- will be enough in most cases.
--
-- @param[type=string]   _Type   Name of behavior
-- @param[type=function] _Action Function called on each tick
-- @param[type=function] _Reset  (optional) Function called when dequeued
-- @within AiArmyBehavior
-- @see AiArmyBehavior:New
--
-- @usage -- Create behavior
-- AiArmyBehavior:Create("MyBehavior", MyBehaviorAction, MyBehaviorReset);
-- -- Add a control field after creation
-- AiArmyBehavior.MyBehavior:AddField("Key", 123);
-- -- Instanciate the behavior with parameters
-- AiArmyBehavior:New("MyBehavior", false, 1, "Dario");
-- -- Check if behavior is executed
-- if _Army:IsExecutingBehavior("MyBehavior") then
--
function AiArmyBehavior:Create(_Type, _Action, _Reset)
    assert(AiArmyBehavior[_Type] == nil, "A behavior named " ..tostring(_Type).. " already exists!");
    assert(type(_Action) == "function", "There is no action method for the behavior defined!");
    AiArmyBehavior[_Type] = {};
    inherit(AiArmyBehavior[_Type], AiArmyBehavior.Custom);
    AiArmyBehavior[_Type].m_Abstract = false;
    AiArmyBehavior[_Type].m_Run = _Action;
    AiArmyBehavior[_Type].m_Reset = _Reset;
end

-- -------------------------------------------------------------------------- --

-- This is not to be used directly
AiArmyBehavior.AbstractBehavior = {
    m_Identifier = "AbstractBehavior",
    m_Abstract = true,
    m_Loop = false,
}

function AiArmyBehavior.AbstractBehavior:construct(_Loop)
    self.m_Loop = _Loop == true;
end
class(AiArmyBehavior.AbstractBehavior);

function AiArmyBehavior.AbstractBehavior:IsLoop()
    return self.m_Loop == true;
end

function AiArmyBehavior.AbstractBehavior:Reset()
end

function AiArmyBehavior.AbstractBehavior:Run(_Army)
    return true;
end

-- -------------------------------------------------------------------------- --

-- Template for custom behavior
AiArmyBehavior.Custom = {
    m_Identifier = "Custom";
    m_Parameters = {},
    m_Data = {},
}

function AiArmyBehavior.Custom:construct(_Loop, ...)
    arg = arg or {};
    self.m_Loop = _Loop == true;
    for i= 1, table.getn(arg), 1 do
        table.insert(self.m_Parameters, arg[i]);
    end
end
inherit(AiArmyBehavior.Custom, AiArmyBehavior.AbstractBehavior);

function AiArmyBehavior.Custom:AddField(_Key, _Value)
    self.m_Data[_Key] = _Value;
end

function AiArmyBehavior.Custom:Run(_Army)
    assert(not self.m_Abstract, "You can not use AiArmyBehavior.Custom directly!");
    if self.m_Run and self:m_Run(_Army, unpack(self.m_Parameters)) then
        return true;
    end
end

function AiArmyBehavior.Custom:Reset(_Army)
    if self.m_Reset then
        self:m_Reset();
    end
end

-- -------------------------------------------------------------------------- --

-- Do nothing
AiArmyBehavior.Idle = {
    m_Identifier = "Idle",
    m_Abstract = false,
}

function AiArmyBehavior.Idle:construct(_Loop)
    self.m_Loop = _Loop == true;
end
inherit(AiArmyBehavior.Idle, AiArmyBehavior.AbstractBehavior);

-- -------------------------------------------------------------------------- --

-- Walk to an possition
AiArmyBehavior.Move = {
    m_Identifier = "Move",
    m_Abstract = false,
}

function AiArmyBehavior.Move:construct(_Target, _Distance, _Loop)
    if type(_Target) ~= "table" then
        _Target = {_Target};
    end
    _Target.Current = 1;

    self.m_Loop = _Loop == true;
    self.m_Target = _Target;
    self.m_Distance = _Distance;
end
inherit(AiArmyBehavior.Move, AiArmyBehavior.AbstractBehavior);

function AiArmyBehavior.Move:Run(_Army)
    local LastIdx = table.getn(self.m_Target);
    if QuestTools.GetDistance(_Army:GetArmyPosition(), self.m_Target[LastIdx]) <= 2000 then
        return true;
    end
    for i= table.getn(_Army.Troops), 1, -1 do
        local Exploration = Logic.GetEntityExplorationRange(_Army.Troops[i])*100;
        local Enemies = _Army:CallGetEnemiesInArea(_Army.Troops[i], Exploration+1000);
        if table.getn(Enemies) > 0 then
            _Army:InsertBehavior(AiArmyBehavior:New(
                "Battle",
                GetPosition(Enemies[1]),
                4000
            ));
            _Army:InvalidateCurrentBehavior();
            _Army:NextBehavior();
            return;
        end
    end
    _Army:MoveAsBlock(self.m_Target[self.m_Target.Current], false, false);
    _Army:NormalizedArmySpeed();
    _Army:Assemble(500);
    if self.m_Target.Current < table.getn(self.m_Target) then
        if QuestTools.GetDistance(_Army:GetArmyPosition(), self.m_Target[self.m_Target.Current]) <= self.m_Distance then
            self.m_Target.Current = self.m_Target.Current +1;
        end
    end
end

-- -------------------------------------------------------------------------- --

-- Walk to an possition and attacking enemies in a wide range on arrival
AiArmyBehavior.Attack = {
    m_Identifier = "Attack",
    m_Abstract = false,
}

function AiArmyBehavior.Attack:construct(_Target, _Distance, _Loop)
    if type(_Target) ~= "table" then
        _Target = {_Target};
    end
    _Target.Current = 1;
    
    self.m_Loop = _Loop == true;
    self.m_Target = _Target;
    self.m_Distance = _Distance;
end
inherit(AiArmyBehavior.Attack, AiArmyBehavior.Move);

function AiArmyBehavior.Attack:Run(_Army)
    local LastIdx = table.getn(self.m_Target);
    if QuestTools.GetDistance(_Army:GetArmyPosition(), self.m_Target[LastIdx]) <= 2000 then
        local Range = _Army.RodeLength + _Army.OuterRange;
        local Target = self.m_Target[LastIdx];
        _Army:InsertBehavior(AiArmyBehavior:New("Retreat"));
        _Army:InsertBehavior(AiArmyBehavior:New("Battle", Target, Range));
        return true;
    end
    for i= table.getn(_Army.Troops), 1, -1 do
        local Exploration = Logic.GetEntityExplorationRange(_Army.Troops[i])*100;
        local Enemies = _Army:CallGetEnemiesInArea(_Army.Troops[i], Exploration+1000);
        if table.getn(Enemies) > 0 then
            _Army:InsertBehavior(AiArmyBehavior:New(
                "Battle",
                GetPosition(Enemies[1]),
                4000
            ));
            _Army:InvalidateCurrentBehavior();
            _Army:NextBehavior();
            return;
        end
    end
    _Army:MoveAsBlock(self.m_Target[self.m_Target.Current], false, _Army:IsFighting());
    _Army:NormalizedArmySpeed();
    _Army:Assemble(500);
    if self.m_Target.Current < table.getn(self.m_Target) then
        if QuestTools.GetDistance(_Army:GetArmyPosition(), self.m_Target[self.m_Target.Current]) <= self.m_Distance then
            self.m_Target.Current = self.m_Target.Current +1;
        end
    end
end

-- -------------------------------------------------------------------------- --

-- Attack enemies in sight
AiArmyBehavior.Battle = {
    m_Identifier = "Battle",
    m_Abstract = false,
}

function AiArmyBehavior.Battle:construct(_Position, _Distance, _Loop)
    self.m_Loop = _Loop == true;
    self.m_Position = _Position;
    self.m_Distance = _Distance;
end
inherit(AiArmyBehavior.Battle, AiArmyBehavior.AbstractBehavior);

function AiArmyBehavior.Battle:Run(_Army)
    local Enemies = _Army:CallGetEnemiesInArea(self.m_Position, self.m_Distance);
    if table.getn(Enemies) > 0 then
        _Army:ControlTroops(self.m_Position, Enemies);
        _Army:ResetArmySpeed();
        _Army:Assemble(self.m_Distance);
        return;
    end
    _Army:MoveAsBlock(_Army:GetArmyPosition(), false, true);
    _Army:InvalidateCurrentBehavior();
    return true;
end

-- -------------------------------------------------------------------------- --

-- Stays at a point until the time is up and guards it
AiArmyBehavior.Guard = {
    m_Identifier = "Guard",
    m_Abstract = false,
    m_LastTime = 0;
    m_RetreatStrength = 0.4;
}

function AiArmyBehavior.Guard:construct(_Position, _Distance, _Time, _Loop)
    self.m_Loop = _Loop == true;
    self.m_Position = _Position;
    self.m_Distance = _Distance;
    self.m_Time = _Time;
end
inherit(AiArmyBehavior.Guard, AiArmyBehavior.AbstractBehavior);

function AiArmyBehavior.Guard:Run(_Army)
    -- enter area to defend
    if QuestTools.GetDistance(_Army:GetArmyPosition(), self.m_Position) >= 500 then
        _Army:MoveAsBlock(self.m_Position, false, false);
        _Army:NormalizedArmySpeed();
        if QuestTools.AreEnemiesInArea(_Army.PlayerID, _Army:GetArmyPosition(), 4000) then
            _Army:InsertBehavior(AiArmyBehavior:New(
                "Battle",
                _Army:GetArmyPosition(),
                4000
            ));
            _Army:InvalidateCurrentBehavior();
            _Army:NextBehavior();
        end
        return;
    end
    self.m_GuardStarded = true;

    -- defend area against enemy
    local Area = _Army.RodeLength + _Army.OuterRange;
    if QuestTools.AreEnemiesInArea(_Army.PlayerID, _Army:GetArmyPosition(), Area) then
        _Army:InsertBehavior(AiArmyBehavior:New(
            "Battle",
            _Army:GetArmyPosition(),
            Area
        ));
        _Army:InvalidateCurrentBehavior();
        _Army:NextBehavior();
        return;
    end
    _Army:Assemble(500);

    -- Check retreat strength
    if _Army:CalculateStrength() < self.m_RetreatStrength then
        _Army:InsertBehavior(AiArmyBehavior:New("Retreat"));
        _Army:InvalidateCurrentBehavior();
        return;
    end

    -- check guard time
    self.m_GuardTimer = self.m_GuardTimer or self.m_Time;
    if self.m_GuardStarded and self.m_GuardTimer ~= -1 then
        if self.m_GuardTimer == 0 then
            return true;
        end
        local CurrentTime = math.floor(Logic.GetTime());
        if self.m_LastTime == 0 then
            self.m_LastTime = CurrentTime;
        end
        if CurrentTime > self.m_LastTime then
            self.m_GuardTimer = self.m_GuardTimer - (CurrentTime - self.m_LastTime);
            if self.m_GuardTimer < 0 then
                self.m_GuardTimer = 0;
            end
        end
        self.m_LastTime = CurrentTime;
    end
end

function AiArmyBehavior.Guard:Reset()
    self.m_GuardTimer = nil;
    self.m_GuardStarded = nil;
    self.m_LastTime = 0;
end

-- -------------------------------------------------------------------------- --

-- Army retreats and automatically goes into refill state
AiArmyBehavior.Retreat = {
    m_Identifier = "Retreat",
    m_Abstract = false,
}

function AiArmyBehavior.Retreat:construct()
end
inherit(AiArmyBehavior.Retreat, AiArmyBehavior.AbstractBehavior);

function AiArmyBehavior.Retreat:Run(_Army)
    if QuestTools.GetDistance(_Army:GetArmyPosition(), _Army.HomePosition) <= 2000 then
        _Army:InsertBehavior(AiArmyBehavior:New("Refill"), 2);
        return true;
    end
    if QuestTools.AreEnemiesInArea(_Army.PlayerID, _Army:GetArmyPosition(), 4000) then
        _Army:InsertBehavior(AiArmyBehavior:New(
            "Battle",
            _Army:GetArmyPosition(),
            4000
        ));
        _Army:InvalidateCurrentBehavior();
        return;
    end
    _Army:NormalizedArmySpeed();
    _Army:SetSubBehavior(ArmySubBehavior.None);
    _Army:MoveAsBlock(_Army.HomePosition, false, false);
    _Army:Assemble(500);
end

-- -------------------------------------------------------------------------- --

-- Army retreats and automatically goes into refill state
AiArmyBehavior.Refill = {
    m_Identifier = "Refill",
    m_Abstract = false,
}

function AiArmyBehavior.Refill:construct()
end
inherit(AiArmyBehavior.Refill, AiArmyBehavior.AbstractBehavior);

function AiArmyBehavior.Refill:Run(_Army)
    if _Army:HasWeakTroops() then
        local Weak = _Army:GetWeakTroops();
        _Army:DispatchTroopsToProducers(Weak);
        _Army:Move(_Army.HomePosition);
        return;
    end
    if table.getn(_Army.Troops) == _Army.TroopCount then
        _Army:Move(_Army.HomePosition);
        return true;
    else
        -- group at home position
        for i= 1, table.getn(_Army.Troops), 1 do
            if QuestTools.GetDistance(_Army.Troops[i], _Army.HomePosition) >= 1500 then
                _Army:MoveTroop(_Army.Troops[i], _Army.HomePosition, false);
            end
        end
        -- Initial spawn
        if _Army.IsRespawningArmy then
            if not _Army.InitialSpawned then
                local Spawner = _Army:GetSpawnerProducers();
                for i= table.getn(Spawner), 1, -1 do
                    if Spawner[i]:IsAlive() and table.getn(_Army.Troops) < _Army.TroopCount then
                        Spawner[i]:CreateTroop(true, true);
                        local ID = Spawner[i]:GetTroop();
                        if ID > 0 then
                            _Army:CallChoseFormation(ID);
                            AiArmyTroopIDToArmyID[ID] = _Army.ArmyID;
                            table.insert(_Army.Troops, ID);
                        end
                    else
                        break;
                    end
                end
                if table.getn(_Army.Troops) >= _Army.TroopCount then
                    _Army.InitialSpawned = true;
                end
                return;
            end
        end
        -- normal spawn/recruitment
        local ProducerInTable = false;
        for k, v in pairs(_Army.Producers) do
            if v and v:IsAlive() then
                ProducerInTable = true;
                if table.getn(_Army.Troops) < _Army.TroopCount then
                    if QuestTools.SameSector(_Army.HomePosition, v.ApproachPosition) then
                        local ID = v:GetTroop();
                        if ID > 0 then
                            _Army:CallChoseFormation(ID);
                            AiArmyTroopIDToArmyID[ID] = _Army.ArmyID;
                            table.insert(_Army.Troops, ID);
                        elseif ID == 0 then
                            if _Army:CountUnpickedProducerTroops() < _Army.TroopCount - table.getn(_Army.Troops) then
                                v:CreateTroop(false);
                            end
                        end
                    end
                end
            end
        end
    end
end

-- -------------------------------------------------------------------------- --

function AiArmy:TargetEnemy(_TroopID, _Enemies)
    if self.TroopProperties[_TroopID] then
        if self.TroopProperties[_TroopID].Target ~= 0 then
            local OldTarget = self.TroopProperties[_TroopID].Target;
            if self:IsEntityAlive(OldTarget) then
                self.TroopProperties[_TroopID].Time = self.TroopProperties[_TroopID].Time -1;
                if self.TroopProperties[_TroopID].Time > 0 then
                    return OldTarget;
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

    for i= table.getn(Enemies), 1, -1 do
        if not self:IsTroopAlive(Enemies[i]) then
            table.remove(Enemies, i);
        end
    end

    if self.IsDirectlyTargeting then
        if table.getn(Enemies) > 1 then            
            table.sort(Enemies, function(a, b)
                if self then
                    return self:CallComputeEnemyPriority(_TroopID, a, b);
                end
                return false;
            end);
        end
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
-- @within Calculator
--
function AiArmy:SetEnemyPriorityComperator(_Function)
    self.ComputeEnemyPriority = _Function;
end

function AiArmy:DefaultComputeEnemyPriority(_TroopID, _EnemyID1, _EnemyID2)
    local Position = self:CallGetArmyFront();
    local Cost1 = self:GetDistanceSqared(Position, _EnemyID1);
    local Factor1 = self:CallGetTargetThreatFactor(_EnemyID1, _TroopID);
    local Priority1 = math.floor(Cost1 * Factor1);
    
    local Cost2 = self:GetDistanceSqared(Position, _EnemyID2);
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
-- Sets the function target enemies by priority. To reset to
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
-- @within Calculator
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
        if Logic.IsLeader(_TargetID) == 1 then
            local Cur = Logic.LeaderGetNumberOfSoldiers(_TargetID);
            local Max = Logic.LeaderGetMaxNumberOfSoldiers(_TargetID);
            Factor = Factor * ((Max > 0 and 1 - (Cur/Max)) or 1);
            if Factor == 0 then
                return 0.01;
            end
        end
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
    ["MilitaryBuilding"] = 100,
    ["EvilLeader"] = 90,
    ["LongRange"] = 50,
};
GroupTargetingPriorities.LightCavalry = {
    ["Hero"] = 100,
    ["Cannon"] = 90,
    ["MilitaryBuilding"] = 80,
    ["Spear"] = 40,
    ["Sword"] = 40,
    ["EvilLeader"] = 0,
    ["LongRange"] = 0,
    ["Rifle"] = 0,
};
GroupTargetingPriorities.HeavyCavalry = {
    ["Hero"] = 100,
    ["Cannon"] = 100,
    ["LongRange"] = 80,
    ["MilitaryBuilding"] = 60,
    ["Sword"] = 60,
    ["Spear"] = 0,
};
GroupTargetingPriorities.Sword = {
    ["Hero"] = 100,
    ["Spear"] = 90,
    ["Cannon"] = 80,
    ["LongRange"] = 60,
    ["MilitaryBuilding"] = 40,
    ["Serf"] = 30,
    ["CavalryHeavy"] = 0,
};
GroupTargetingPriorities.Spear = {
    ["CavalryHeavy"] = 100,
    ["CavalryLight"] = 100,
    ["MilitaryBuilding"] = 90,
    ["LongRange"] = 0,
    ["Serf"] = 0,
    ["Sword"] = 0,
};
GroupTargetingPriorities.Ranged = {
    ["MilitaryBuilding"] = 100,
    ["CavalryHeavy"] = 90,
    ["CavalryLight"] = 90,
    ["VillageCenter"] = 60,
    ["Headquarters"] = 60,
    ["Hero"] = 50,
    ["EvilLeader"] = 0,
};
GroupTargetingPriorities.Rifle = {
    ["EvilLeader"] = 100,
    ["LongRange"] = 100,
    ["MilitaryBuilding"] = 100,
    ["Cannon"] = 80,
    ["VillageCenter"] = 40,
    ["Headquarters"] = 40,
    ["Melee"] = 0,
};

