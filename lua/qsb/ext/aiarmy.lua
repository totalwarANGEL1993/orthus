-- ########################################################################## --
-- #  AI Generator                                                          # --
-- #  --------------------------------------------------------------------  # --
-- #    Author:   totalwarANGEL                                             # --
-- ########################################################################## --

---
--
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
-- 
--
ArmyStates = {
    Decide = 1,
    Attack  = 2,
    Guard   = 3,
    Retreat = 4,
    Refill  = 5,
}

AiArmy = {
    PlayerID             = -1,
    ArmyID               = -1,
    State                = ArmyStates.Decide;
    TroopStates          = {};
    TroopCount           = 8;
    Troops               = {},
    TroopTargets         = {},
    RodeLength           = 3000;
    OuterRange           = 0;
    Strength             = 0;
    RetreatStrength      = 0.2;
    Producers            = {},

    AttackAllowed        = true,
    DefendAllowed        = true,
    IsRespawningArmy     = false,
    InitialSpawned       = false,

    AttackTarget         = nil,
    GuardTarget          = nil,
    GuardStartTime       = 0,
    GuardMaximumTime     = 5*60,
    HomePosition         = nil,
}

AiArmyList = {};

function AiArmy:construct(_PlayerID, _ArmyID, _Home, _Range, _Home, _TroopAmount)
    self.PlayerID = _PlayerID;
    self.ArmyID = _ArmyID;
    self.HomePosition = _Home;
    self.RodeLength = _Range;
    self.OuterRange = _Range * 0.5;
    self.TroopCount = _TroopAmount;

    self:StartControllerJob();
    AiArmyList[_ArmyID] = self;
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
        self.Producers[k] = nil;
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
                SetHealth(v.ScriptName, 0);
            end
        end
    end
    self.Producers = {};

    if _DestroyTroops then
        for i= table.getn(self.Troops), 1, -1 do
            if IsExisting(self.Troops[i]) then
                DestroyEntity(self.Troops[i]);
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
    return true;
end

function AiArmy:IsFighting()
    for i= table.getn(self.Troops), 1, -1 do
        local Task = Logic.GetCurrentTaskList(self.Troops[i]);
        return string.find(Task, "BATTLE") ~= nil;
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

function AiArmy:IsAttackAllowed()
    return self.AttackAllowed == true;
end

function AiArmy:SetAttackAllowed(_Flag)
    self.AttackAllowed = _Flag == true;
    return self;
end

function AiArmy:IsDefenceAllowed()
    return self.DefendAllowed == true;
end

function AiArmy:SetDefenceAllowed(_Flag)
    self.DefendAllowed = _Flag == true;
    return self;
end

-- -------------------------------------------------------------------------- --

function AiArmy:Operate()
    if self.ArmyIsDead then
        return true;
    end
    if self.ArmyIsPaused then
        return false;
    end

    self:ClearDeadTroops();
    self:ClearDeadTroopTargets();

    if self.State == ArmyStates.Decide then
        self:CallSelectActionBehavior();
    end
    if self.State == ArmyStates.Attack then
        self:CallAttackBehavior();
    end
    if self.State == ArmyStates.Guard then
        self:CallDefenceBehavior();
    end
    if self.State == ArmyStates.Retreat then
        self:CallRetreatBehavior();
    end
    if self.State == ArmyStates.Refill then
        self:CallRefillBehavior();
    end
    return false;
end

function AiArmy:ClearDeadTroops()
    for i= table.getn(self.Troops), 1, -1 do
        if not IsExisting(self.Troops[i]) then
            table.remove(self.Troops, i);
        end
    end
end

function AiArmy:ClearDeadTroopTargets()
    for i= table.getn(self.Troops), 1, -1 do
        if not IsExisting(self.Troops[i]) or not IsExisting(self.TroopTargets[self.Troops[i]]) then
            self.TroopTargets[self.Troops[i]] = nil;
        end
    end
end

-- -------------------------------------------------------------------------- --

function AiArmy:CallSelectActionBehavior()
    if self.SelectActionBehavior then
        self:SelectActionBehavior();
    end
    return self;
end

function AiArmy:SetSelectActionBehavior(_Behavior)
    self.SelectActionBehavior = _Behavior;
    return self;
end

function AiArmy.SelectActionBehavior(_Army)
    -- check retreat condition
    if _Army:CalculateStrength() < _Army.RetreatStrength then
        AiArmyList[_Army.ArmyID].State = ArmyStates.Retreat;
        AiArmyList[_Army.ArmyID].TroopStates = {};
        return;
    end

    -- handle attack/defend
    if _Army.AttackAllowed and _Army.AttackTarget then
        AiArmyList[_Army.ArmyID].State = ArmyStates.Attack;
        AiArmyList[_Army.ArmyID].TroopStates = {};
        return;
    end
    if _Army.DefendAllowed and _Army.GuardTarget then
        AiArmyList[_Army.ArmyID].State = ArmyStates.Guard;
        AiArmyList[_Army.ArmyID].TroopStates = {};
        AiArmyList[_Army.ArmyID].GuardStartTime = Logic.GetTime();
        return;
    end

    -- control troops
    for i= table.getn(_Army.Troops), 1, -1 do
        local Range = _Army.RodeLength + _Army.OuterRange;
        if not _Army.TroopStates[_Army.Troops[i]] then
            if QuestTools.GetDistance(_Army.Troops[i], _Army:GetArmyPosition()) > Range then
                AiArmy:MoveTroop(_Army.Troops[i], _Army:GetArmyPosition());
                AiArmyList[_Army.ArmyID].TroopTargets[_Army.Troops[i]] = nil;
                AiArmyList[_Army.ArmyID].TroopStates[_Army.Troops[i]] = 1;
            elseif QuestTools.GetDistance(_Army.Troops[i], _Army.HomePosition) > Range * 1.5 then
                AiArmy:MoveTroop(_Army.Troops[i], _Army.HomePosition);
                AiArmyList[_Army.ArmyID].TroopTargets[_Army.Troops[i]] = nil;
                AiArmyList[_Army.ArmyID].TroopStates[_Army.Troops[i]] = 2;
            else
                _Army:TroopAttackPrioritizedTarget(_Army.Troops[i], _Army.HomePosition);
                if Logic.IsEntityMoving(_Army.Troops[i]) == false then
                    if not string.find(Logic.GetCurrentTaskList(_Army.Troops[i]), "BATTLE") then                       
                        local Range = 1200;
                        if QuestTools.GetDistance(_Army.Troops[i], _Army.HomePosition) > Range then
                            AiArmy:MoveTroop(_Army.Troops[i], _Army.HomePosition);
                            AiArmyList[_Army.ArmyID].TroopTargets[_Army.Troops[i]] = nil;
                        end
                    end
                end
            end
        elseif _Army.TroopStates[_Army.Troops[i]] == 1 then
            local Range = 1200;
            if QuestTools.GetDistance(_Army.Troops[i], _Army:GetArmyPosition()) < Range then
                AiArmyList[_Army.ArmyID].TroopStates[_Army.Troops[i]] = nil;
            end
        elseif _Army.TroopStates[_Army.Troops[i]] == 2 then
            local Range = 1200;
            if QuestTools.GetDistance(_Army.Troops[i], _Army.HomePosition) < Range then
                AiArmyList[_Army.ArmyID].TroopStates[_Army.Troops[i]] = nil;
            end
        end
    end

    if not _Army:IsFighting() then
        if _Army:HasWeakTroops() then
            AiArmyList[_Army.ArmyID].State = ArmyStates.Retreat; 
        end
    end
end

-- -------------------------------------------------------------------------- --

function AiArmy:CallAttackBehavior()
    if self.AttackBehavior then
        self:AttackBehavior();
    end
    return self;
end

function AiArmy:SetAttackBehavior(_Behavior)
    self.AttackBehavior = _Behavior;
    return self;
end

function AiArmy.AttackBehavior(_Army)
    -- check retreat condition
    if _Army:CalculateStrength() < _Army.RetreatStrength then
        AiArmyList[_Army.ArmyID].State = ArmyStates.Retreat;
        return;
    end

    -- finish attack
    local Enemies = AiArmy:GetEnemiesInSight(_Army.PlayerID, _Army.AttackTarget);
    if not _Army.AttackAllowed or _Army.AttackTarget or table.getn(Enemies) == 0 then
        AiArmyList[_Army.ArmyID].State = ArmyStates.Decide;
        return;
    end
end

function AiArmy:TroopAttackPrioritizedTarget(_TroopID, _Position)
    local Position = _Position or _TroopID;
    if type(Position) ~= "table" then
        Position = GetPosition(Position);
    end
    local Priority = self:GetEnemyPriorityForTroop(_TroopID);
    local Target = self:GetPrioritizedAttackTarget(Position, _TroopID, Priority);
    if (Target ~= nil and Target ~= 0) then
        if not self.TroopTargets[_TroopID] then
            self.TroopTargets[_TroopID] = Target;
        elseif self.TroopTargets[_TroopID] ~= Target then
            self.TroopTargets[_TroopID] = Target;
        end
    end
    if self.TroopTargets[_TroopID] then
        if not string.find(Logic.GetCurrentTaskList(_TroopID), "BATTLE") then
            Logic.GroupAttack(_TroopID, self.TroopTargets[_TroopID]);
            return true;
        end
    end
    return false;
end

function AiArmy:AttackPrioritizedTarget(_Position)
    local Result = true;
    for i= table.getn(self.Troops), 1, -1 do
        local Position = _Position or self.Troops[i];
        if type(Position) ~= "table" then
            Position = GetPosition(Position);
        end
        Result = Result and self:TroopAttackPrioritizedTarget(self.Troops[i], Position);
    end
    return Result;
end

-- -------------------------------------------------------------------------- --

function AiArmy:CallDefenceBehavior()
    if self.DefenceBehavior then
        self:DefenceBehavior();
    end
    return self;
end

function AiArmy:SetDefenceBehavior(_Behavior)
    self.DefenceBehavior = _Behavior;
    return self;
end

function AiArmy.DefenceBehavior(_Army)
    -- check retreat condition
    if _Army:CalculateStrength() < _Army.RetreatStrength then
        AiArmyList[_Army.ArmyID].State = ArmyStates.Retreat;
        return;
    end

    -- controll attack
    if _Army.AttackAllowed and _Army.AttackTarget then
        AiArmyList[_Army.ArmyID].State = ArmyStates.Attack;
        AiArmyList[_Army.ArmyID].GuardTarget = nil;
        return;
    end

    -- check has target
    if not _Army.DefendAllowed or not _Army.GuardTarget then
        AiArmyList[_Army.ArmyID].State = ArmyStates.Retreat;
        return;
    end

    -- end guard after time is up
    if _Army.GuardMaximumTime > -1 then
        if _Army.GuardStartTime + _Army.GuardMaximumTime < Logic.GetTime() then
            AiArmyList[_Army.ArmyID].GuardTarget = nil;
            AiArmyList[_Army.ArmyID].State = ArmyStates.Retreat;
            return;
        end
    end
end

-- -------------------------------------------------------------------------- --

function AiArmy:CallRetreatBehavior()
    if self.RetreatBehavior then
        self:RetreatBehavior();
    end
    return self;
end

function AiArmy:SetRetreatBehavior(_Behavior)
    self.RetreatBehavior = _Behavior;
    return self;
end

function AiArmy.RetreatBehavior(_Army)
    if table.getn(_Army.Troops) == 0 then
        AiArmyList[_Army.ArmyID].State = ArmyStates.Refill;
    elseif QuestTools.GetDistance(_Army:GetArmyPosition(), _Army.HomePosition) <= 2000 then
        AiArmyList[_Army.ArmyID].State = ArmyStates.Refill;
    else
        local Weak = _Army:GetWeakTroops();
        _Army:DispatchTroopsToProducers(Weak);
        _Army:Move(_Army.HomePosition);
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
    -- TODO: dispatch the troops more evenly among the producers 
    for i= table.getn(Troops), 1, -1 do
        local TroopType = Logic.GetEntityType(Troops[i]);
        for k, v in pairs(self.Producers) do
            if v and v:IsAlive() and not QuestTools.IsInTable(Troops[i], v.Troops.Created) then
                local ProducerType = Logic.GetEntityType(GetID(v.ScriptName));
                if v.IsSpawner and v:IsInTypeList(TroopType) then
                    AiArmy:MoveTroop(self.Troops[i], v.ApproachPosition);
                    table.insert(v.Troops.Created, table.remove(Troops, i));
                    break;
                elseif v.IsRecruiter and v:IsSuitableUnitType(TroopType) then
                    AiArmy:MoveTroop(self.Troops[i], v.ApproachPosition);
                    table.insert(v.Troops.Created, table.remove(Troops, i));
                    break;
                end
            end
        end
    end
    -- destroy rest
    for i= table.getn(Troops), 1, -1 do
        DestroyEntity(Troops[i]);
    end
end

-- -------------------------------------------------------------------------- --

function AiArmy:CallRefillBehavior()
    if self.RefillBehavior then
        self:RefillBehavior();
    end
    return self;
end

function AiArmy:SetRefillBehavior(_Behavior)
    self.RefillBehavior = _Behavior;
    return self;
end

function AiArmy.RefillBehavior(_Army)
    if _Army:HasWeakTroops() then
        local Weak = _Army:GetWeakTroops();
        _Army:DispatchTroopsToProducers(Weak);
        _Army:Move(_Army.HomePosition);
        return;
    end
    
    if table.getn(_Army.Troops) == _Army.TroopCount then
        local HomePosition = GetPosition(_Army.HomePosition);
        _Army:Move(_Army.HomePosition);
        AiArmyList[_Army.ArmyID].State = ArmyStates.Decide;
    else
        -- Initial spawn
        if _Army.IsRespawningArmy then
            if not _Army.InitialSpawned then
                local Spawner = _Army:GetSpawnerProducers();
                if table.getn(Spawner) > 0 then                    
                    for i= table.getn(Spawner), 1, -1 do
                        if table.getn(_Army.Troops) < _Army.TroopCount then
                            Spawner[i]:CreateTroop(true, true);
                            local ID = Spawner[i]:GetTroop();
                            if ID > 0 then
                                table.insert(_Army.Troops, ID);
                            end
                        else
                            break;
                        end
                    end
                    if table.getn(_Army.Troops) >= _Army.TroopCount then
                        AiArmyList[_Army.ArmyID].InitialSpawned = true;
                    end
                end
                return;
            end
        end
    
        -- normal spawn/recruitment
        local ProducerInTable = false;
        for k, v in pairs(_Army.Producers) do
            if v then
                ProducerInTable = true;
                if table.getn(_Army.Troops) < _Army.TroopCount then
                    if QuestTools.GetReachablePosition(_Army.HomePosition, v.ApproachPosition) ~= nil then
                        local ID = v:GetTroop();
                        if ID > 0 then
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

        -- return to decide state
        if not ProducerInTable then
            AiArmyList[_Army.ArmyID].State = ArmyStates.Decide;
        end
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
    local SpawnerList = 0;
    for k, v in pairs(self.Producers) do
        if v then
            SpawnerList = SpawnerList + table.getn(v.Troops.Created);
        end
    end
    return SpawnerList;
end

-- -------------------------------------------------------------------------- --



function AiArmy:GetArmyPosition()
    local CurrentTroops = table.getn(self.Troops);
    if table.getn(self.Troops) == 0 then
        return self.HomePosition;
    else
        return QuestTools.GetGeometricFocus(unpack(self.Troops));
    end
end

function AiArmy:Move(_Positon)
    local Positon = _Positon;
    if type(Positon) ~= "table" then
        Positon = GetPosition(Positon);
    end
    for i= table.getn(self.Troops), 1, -1 do
        -- if Logic.IsEntityMoving(self.Troops[i]) == false then
            Logic.MoveSettler(self.Troops[i], Positon.X, Positon.Y);
        -- end
    end
end

function AiArmy:MoveTroop(_TroopID, _Positon)
    local Positon = _Positon;
    if type(Positon) ~= "table" then
        Positon = GetPosition(Positon);
    end
    Logic.MoveSettler(_TroopID, Positon.X, Positon.Y);
end

function AiArmy:MoveToPositionIfToFarAway(_Positon, _MaxDistance)
    local MaxDistance = _MaxDistance or (self.RodeLength + self.OuterRange);
    local Positon = _Positon;
    if type(Positon) ~= "table" then
        Positon = GetPosition(Positon);
    end
    for i= table.getn(self.Troops), 1, -1 do
        if QuestTools.GetDistance(self.Troops[i], _Positon) > MaxDistance then
            Logic.MoveSettler(self.Troops[i], Positon.X, Positon.Y);
            self.TroopTargets[self.Troops[i]] = nil;
        end
    end
end

-- -------------------------------------------------------------------------- --

function AiArmy:CalculateStrength()
    local CurStrength = 0;
    local MaxStrength = 0;
    for i= table.getn(self.Troops), 1, -1 do
        MaxStrength = MaxStrength + 1;
        CurStrength = CurStrength + 1;
        if Logic.IsEntityInCategory(self.Troops[i], EntityCategories.Cannon) == 1 then
            MaxStrength = MaxStrength + 5;
            CurStrength = CurStrength + 5;
        elseif Logic.IsLeader(self.Troops[i]) == 1 then
            MaxStrength = MaxStrength + Logic.LeaderGetMaxNumberOfSoldiers(self.Troops[i]);
            CurStrength = CurStrength + Logic.LeaderGetNumberOfSoldiers(self.Troops[i]);
        end
    end
    if MaxStrength == 0 then
        return 0;
    end
    return CurStrength/MaxStrength;
end

function AiArmy:GetEnemiesInSight(_PlayerID, _Position)
    local AllEnemiesInSight = {};
    for i= 1, 8, 1 do
        if i ~= _PlayerID and Logic.GetDiplomacyState(_PlayerID, i) == Diplomacy.Hostile then
            local Range = self.RodeLength + self.OuterRange;
            local PlayerEntities = QuestTools.GetPlayerEntities(i, 0);
            for j= table.getn(PlayerEntities), 1, -1 do
                if Logic.GetEntityHealth(PlayerEntities[j]) > 0 then
                    if Logic.IsEntityInCategory(PlayerEntities[j], EntityCategories.Cannon) == 1
                    or (Logic.IsHero(PlayerEntities[j]) == 1 and Logic.GetCamouflageTimeLeft(PlayerEntities[j]) == 0)
                    or Logic.IsBuilding(PlayerEntities[j]) == 1 
                    or Logic.IsLeader(PlayerEntities[j]) == 1 then
                        if QuestTools.GetDistance(_Position, PlayerEntities[j]) < Range then
                            table.insert(AllEnemiesInSight, PlayerEntities[j]);
                        end
                    end
                end
            end
        end
    end
    return AllEnemiesInSight;
end

-- -------------------------------------------------------------------------- --

GroupTargetingPriorities = {};

-- Attack priority for cannons.
GroupTargetingPriorities.Cannon = {
    ["MilitaryBuilding"] = 1.0,
    ["EvilLeader"] = 0.8,
    ["VillageCenter"] = 0.6,
    ["Headquarters"] = 0.5,
    ["LongRange"] = 0.3,
    ["Melee"] = 0.01,
};

-- Attack priority for heavy cavalry.
GroupTargetingPriorities.HeavyCavalry = {
    ["Cannon"] = 1.0,
    ["LongRange"] = 0.8,
    ["Sword"] = 0.7,
    ["Hero10"] = 0.6,
    ["Hero4"] = 0.5,
    ["MilitaryBuilding"] = 0.4,
    ["Hero"] = 0.3,
    ["Spear"] = 0.01,
};

-- Attack priority for swordmen.
GroupTargetingPriorities.Sword = {
    ["Cannon"] = 1.0,
    ["MilitaryBuilding"] = 0.9,
    ["Spear"] = 0.8,
    ["LongRange"] = 0.7,
    ["Hero"] = 0.7,
    ["CavalryHeavy"] = 0.01,
};

-- Attack priority for spearmen.
GroupTargetingPriorities.Spear = {
    ["CavalryHeavy"] = 1.0,
    ["MilitaryBuilding"] = 0.9,
    ["CavalryLight"] = 0.8,
    ["Hero"] = 0.5,
    ["LongRange"] = 0.1,
    ["Sword"] = 0.01,
};

-- Attack priority for bowmen.
GroupTargetingPriorities.Ranged = {
    ["MilitaryBuilding"] = 1.0,
    ["Hero10"] = 0.9,
    ["Hero4"] = 0.8,
    ["Hero"] = 0.7,
    ["VillageCenter"] = 0.4,
    ["Headquarters"] = 0.4,
    ["CavalryHeavy"] = 0.4,
    ["CavalryLight"] = 0.01,
};

-- Attack priority for marksmen.
GroupTargetingPriorities.Rifle = {
    ["MilitaryBuilding"] = 1.0,
    ["Hero10"] = 0.9,
    ["EvilLeader"] = 0.8,
    ["VillageCenter"] = 0.7,
    ["Headquarters"] = 0.7,
    ["Cannon"] = 0.6,
    ["LongRange"] = 0.4,
    ["Melee"] = 0.01,
};

function AiArmy:GetEnemyPriorityForTroop(_EntityID)
    if IsExisting(_EntityID) then
        -- Call evil units troop controller
        if Logic.IsEntityInCategory(_EntityID, EntityCategories.EvilLeader) == 1 then
            if Logic.GetEntityType(_EntityID) == Entities.CU_Evil_LeaderSkirmisher then
                return GroupTargetingPriorities.Ranged;
            end
            return GroupTargetingPriorities.Sword;
        end
        if Logic.IsEntityInCategory(_EntityID, EntityCategories.CavalryHeavy) == 1 then
            return GroupTargetingPriorities.HeavyCavalry;
        end
        if Logic.IsEntityInCategory(_EntityID, EntityCategories.Sword) == 1 then
            return GroupTargetingPriorities.Sword;
        end
        if Logic.IsEntityInCategory(_EntityID, EntityCategories.Spear) == 1 then
            return GroupTargetingPriorities.Spear;
        end
        if Logic.IsEntityInCategory(_EntityID, EntityCategories.Rifle) == 1 then
            return GroupTargetingPriorities.Rifle;
        end
        if Logic.IsEntityInCategory(_EntityID, EntityCategories.LongRange) == 1 then
            return GroupTargetingPriorities.Ranged;
        end
        if Logic.IsEntityInCategory(_EntityID, EntityCategories.Cannon) == 1 then
            return GroupTargetingPriorities.Cannon;
        end
    end
    return {};
end

function AiArmy:GetPrioritizedAttackTarget(_Position, _TroopID, _Priority)
    if IsExisting(_TroopID) then
        local Range = self.RodeLength + self.OuterRange;
        local Priority = self:GetEnemyPriorityForTroop(_TroopID);
        local TargetToPriorityList = self:GetEnemiesWithTheirPriority(_TroopID, Priority, Range);
        if table.getn(TargetToPriorityList) == 0 then
            return 0;
        end

        local Comperator = function(a, b)
            if a == nil or b == nil then
                return false;
            elseif a[2] > b[2] then
                return true;
            elseif a[2] > b[2] then
                return false;
            end
        end
        table.sort(TargetToPriorityList, Comperator);
        return TargetToPriorityList[1][1];
    end
    return 0;
end

function AiArmy:GetEnemiesWithTheirPriority(_EntityID, _Priority, _AreaSize)
    local PlayerID = Logic.EntityGetPlayer(_EntityID);
    local Enemies = self:GetEnemiesInSight(PlayerID, _EntityID);
    local Targets = {};

    local AlreadyAddTarget = false;
    for i= 1, table.getn(Enemies) do
        local TargetPriority = self:CalculateTargetPriority(_EntityID, Enemies[i], _AreaSize, _Priority);
        table.insert(Targets, {Enemies[i], TargetPriority});
        if self.TroopTargets[_EntityID] == Enemies[i] then
            AlreadyAddTarget = true;
        end
    end
    if not AlreadyAddTarget and self.TroopTargets[_EntityID] then
        local TargetPriority = self:CalculateTargetPriority(_EntityID, self.TroopTargets[_EntityID], _AreaSize, _Priority);
        table.insert(Targets, {self.TroopTargets[_EntityID], TargetPriority});
    end

    return Targets;
end

function AiArmy:CalculateTargetPriority(_EntityID, _TargetID, _AreaSize, _Priority)
    local Priority = 0;
    local Distance = QuestTools.GetDistance(_EntityID, _TargetID);
    if Distance >= _AreaSize then
        return Priority;
    end
    Priority = 1;
    -- Soldiers factor
    if Logic.IsLeader(_TargetID) == 1 then
        local MaxSoldiers = Logic.LeaderGetMaxNumberOfSoldiers(_TargetID);
        local CurSoldiers = Logic.LeaderGetNumberOfSoldiers(_TargetID);
        Priority = Priority * (CurSoldiers/MaxSoldiers);
    end
    -- Type factor
    for k, v in pairs(QuestTools.GetEntityCategoriesAsString(_TargetID)) do
        Priority = (v and Priority * (_Priority[v] or 1)) or Priority;
    end
    -- if self.TroopTargets[_EntityID] == _TargetID then
    --     Priority = Priority * 0.5;
    -- end
    return Priority;
end

