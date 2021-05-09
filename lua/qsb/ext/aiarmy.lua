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
    Idle    = 1,
    Advance = 2,
    Attack  = 3,
    Guard   = 4,
    Retreat = 5,
    Refill  = 6,
}

---
-- 
--
ArmySubStates = {
    None      = 1,
    Defensive = 2,
    Offensive = 3,
}

AiArmyIdSequence = 0;

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

    Target               = nil,
    AttackTarget         = nil,
    GuardTarget          = nil,
    GuardStartTime       = 0,
    GuardMaximumTime     = 5*60,
    HomePosition         = nil,

    -- DEPRECATED
    TroopTargets         = {},
}

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
                if Logic.IsLeader(self.Troops[i]) == 1 then
                    local Soldiers = {Logic.GetSoldiersAttachedToLeader(self.Troops[i])};
                    for j= Soldiers[1]+1, 2, -1 do
                        SetHealth(Soldiers[j], 0);
                    end
                end
                SetHealth(self.Troops[i], 0);
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
        return not Task or string.find(Task, "BATTLE") ~= nil;
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

function AiArmy:GetArmyPosition()
    if table.getn(self.Troops) == 0 then
        return self.HomePosition;
    else
        return QuestTools.GetGeometricFocus(unpack(self.Troops));
    end
end

function AiArmy:IsArmyNearTarget(_Distance)
    if self.Target then
        for i= table.getn(self.Troops), 1, -1 do
            if IsNear(self.Troops, self.Target, _Distance) then
                return true;
            end
        end
    end
    return false;
end

function AiArmy:SetAttackTarget(_Target)
    self.AttackTarget = _Target;
    return self;
end

function AiArmy:IsAttackAllowed()
    return self.AttackAllowed == true;
end

function AiArmy:SetAttackAllowed(_Flag)
    self.AttackAllowed = _Flag == true;
    return self;
end

function AiArmy:SetGuardTarget(_Target)
    self.GuardTarget = _Target;
    return self;
end

function AiArmy:IsDefenceAllowed()
    return self.DefendAllowed == true;
end

function AiArmy:SetDefenceAllowed(_Flag)
    self.DefendAllowed = _Flag == true;
    return self;
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

function AiArmy:MoveTroop(_TroopID, _Positon)
    local Positon = _Positon;
    if type(Positon) ~= "table" then
        Positon = GetPosition(Positon);
    end
    Logic.MoveSettler(_TroopID, Positon.X, Positon.Y);
end

function AiArmy:TroopAttack(_TroopID, _Target)
    Logic.GroupAttack(_TroopID, GetID(_Target));
end

function AiArmy:TroopAttackMove(_TroopID, _Positon)
    local Positon = _Positon;
    if type(Positon) ~= "table" then
        Positon = GetPosition(Positon);
    end
    Logic.GroupAttackMove(_TroopID, Positon.X, Positon.Y);
end

function AiArmy:IsScattered(_Position, _Area)
    for i= table.getn(self.Troops), 1, -1 do
        if QuestTools.GetDistance(self.Troops[i], _Position) > _Area then
            return true;
        end
    end
    return false;
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
                    AiArmy:MoveTroop(Troops[i], v.ApproachPosition);
                    table.insert(v.Troops.Created, Troops[i]);
                    table.remove(Troops, i);
                    break;
                elseif v.IsRecruiter and v:IsSuitableUnitType(TroopType) then
                    AiArmy:MoveTroop(Troops[i], v.ApproachPosition);
                    table.insert(v.Troops.Created, Troops[i]);
                    table.remove(Troops, i);
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
        if not IsExisting(self.Troops[i]) then
            table.remove(self.Troops, i);
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

    self:ClearDeadTroops();
    self:ClearDeadTroopTargets();

    if self.State == ArmyStates.Idle then
        self:CallIdleStateController();
    elseif self.State == ArmyStates.Advance then
        self:CallAdvanceStateController();
    elseif self.State == ArmyStates.Attack then
        self:CallAttackStateController();
    elseif self.State == ArmyStates.Guard then
        self:CallGuardStateController();
    elseif self.State == ArmyStates.Retreat then
        self:CallRetreatStateController();
    elseif self.State == ArmyStates.Refill then
        self:CallRefillStateController();
    end
    return false;
end

-- -------------------------------------------------------------------------- --

function AiArmy:CallIdleStateController()
    if self.IdleStateController then
        self:IdleStateController();
    end
    return self;
end

function AiArmy:SetIdleStateController(_Behavior)
    self.IdleStateController = _Behavior;
    return self;
end

function AiArmy:IdleStateController()
    -- check retreat condition
    if self:CalculateStrength() < self.RetreatStrength then
        self:ClearTargets();
        self.State = ArmyStates.Retreat;
        return;
    end

    -- handle attack/defend
    if self.AttackTarget then
        self.State = ArmyStates.Advance;
        self.Target = self.AttackTarget;
        self:ClearTargets();
        return;
    end
    if self.GuardTarget then
        self.State = ArmyStates.Advance;
        self.Target = self.GuardTarget;
        self:ClearTargets();
        return;
    end

    -- control troops
    local AreaSize = self.RodeLength + self.OuterRange;
    if QuestTools.AreEnemiesInArea(self.PlayerID, self:GetArmyPosition(), AreaSize) then
        self.SubState = ArmySubStates.Defensive;
    else
        self.SubState = ArmySubStates.None;
    end
end

-- -------------------------------------------------------------------------- --

function AiArmy:CallAdvanceStateController()
    if self.AdvanceStateController then
        self:AdvanceStateController();
    end
    return self;
end

function AiArmy:SetAdvanceStateController(_Behavior)
    self.AdvanceStateController = _Behavior;
    return self;
end

function AiArmy:AdvanceStateController()
    -- check retreat condition
    if self:CalculateStrength() < self.RetreatStrength then
        self:ClearTargets();
        AiArmyList[self.ArmyID].State = ArmyStates.Retreat;
        return;
    end

    -- abort advance
    if not self.AttackAllowed and not self.AttackTarget then
        self.SubState = ArmySubStates.None;
        self.State = ArmyStates.Idle;
        return;
    end

    -- enter attack/defend state
    if self:IsArmyNearTarget(self.RodeLength + self.OuterRange) then
        self:ClearTargets();
        if self.Target == self.AttackTarget then
            self.State = ArmyStates.Attack;
        elseif self.Target == self.GuardTarget then
            self.State = ArmyStates.Guard;
            self.GuardStartedTime = Logic.GetTime();
        else
            self.SubState = ArmySubStates.None;
            self.State = ArmyStates.Idle;
        end
        return;

    -- move army to target
    else
        if not self:IsScattered(self:GetArmyPosition(), self.RodeLength) then
            if not self:IsMoving() and not self:IsFighting() then
                if self.SubState == ArmySubStates.Defensive then
                    self:ControlTroopOperations(self:GetArmyPosition(), EnemiesTheir);
                else
                    self:AttackMove(self.Target, true);
                end
            end
        else
            self:Move(self:GetArmyPosition(), true);
        end
    end

    -- control troops
    local AreaSize = self.RodeLength + self.OuterRange;
    if QuestTools.AreEnemiesInArea(self.PlayerID, self:GetArmyPosition(), AreaSize) then
        self.SubState = ArmySubStates.Defensive;
    else
        self.SubState = ArmySubStates.None;
    end
end

-- -------------------------------------------------------------------------- --

function AiArmy:CallAttackStateController()
    if self.AttackStateController then
        self:AttackStateController();
    end
    return self;
end

function AiArmy:SetAttackStateController(_Behavior)
    self.AttackStateController = _Behavior;
    return self;
end

function AiArmy:AttackStateController()
    -- check retreat condition
    if self:CalculateStrength() < self.RetreatStrength then
        self:ClearTargets();
        self.State = ArmyStates.Retreat;
        return;
    end

    -- finish attack
    local AreaSize = self.RodeLength + self.OuterRange;
    local EnemiesTheir = self:GetEnemiesInArea(self.PlayerID, self.Target, AreaSize);
    if not self.AttackTarget or table.getn(EnemiesTheir) == 0 then
        self:ClearTargets();
        self.State = ArmyStates.Idle;
        self.SubState = ArmySubStates.None;
        self.AttackTarget = nil;
        self.Target = nil;
        return;
    end

    -- control troops
    self:ControlTroopOperations(self:GetArmyPosition(), EnemiesTheir);
end

-- -------------------------------------------------------------------------- --

function AiArmy:CallGuardStateController()
    if self.GuardStateController then
        self:GuardStateController();
    end
    return self;
end

function AiArmy:SetGuardStateController(_Behavior)
    self.GuardStateController = _Behavior;
    return self;
end

function AiArmy:GuardStateController()
    -- check retreat condition
    if self:CalculateStrength() < self.RetreatStrength then
        self:ClearTargets();
        self.State = ArmyStates.Retreat;
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
            self.State = ArmyStates.Idle;
            self.SubState = ArmySubStates.None;
            if self:HasWeakTroops() then
                self.State = ArmyStates.Retreat;
            end
            self.GuardTarget = nil;
            self.Target = nil;
            return;
        end
    end

    -- control troops
    self:ControlTroopOperations(self:GetArmyPosition());
end

-- -------------------------------------------------------------------------- --

function AiArmy:CallRetreatStateController()
    if self.RetreatStateController then
        self:RetreatStateController();
    end
    return self;
end

function AiArmy:SetRetreatStateController(_Behavior)
    self.RetreatStateController = _Behavior;
    return self;
end

function AiArmy:RetreatStateController()
    if table.getn(self.Troops) == 0 then
        self.State = ArmyStates.Refill;
        self.SubState = ArmySubStates.None;
    elseif QuestTools.GetDistance(self:GetArmyPosition(), self.HomePosition) <= 2000 then
        self.State = ArmyStates.Refill;
        self.SubState = ArmySubStates.None;
    else
        local Weak = self:GetWeakTroops();
        self:DispatchTroopsToProducers(Weak);
        self:Move(self.HomePosition);
    end
    self:ClearTargets();
end

-- -------------------------------------------------------------------------- --

function AiArmy:CallRefillStateController()
    if self.RefillStateController then
        self:RefillStateController();
    end
    return self;
end

function AiArmy:SetRefillStateController(_Behavior)
    self.RefillStateController = _Behavior;
    return self;
end

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
                if table.getn(Spawner) > 0 then                    
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

    -- control troops
    self:ControlTroopOperations(self.HomePosition);
end

-- -------------------------------------------------------------------------- --

function AiArmy:ControlTroopOperations(_Position, _Enemies)
    for i= table.getn(self.Troops), 1, -1 do
        self.TroopProperties[self.Troops[i]] = self.TroopProperties[self.Troops[i]] or {
            State  = 0,
            Target = 0,
            Time   = 0,
        };
        local AreaSize = self.RodeLength + self.OuterRange;
        local Enemies = _Enemies or self:GetEnemiesInArea(self.PlayerID, _Position, AreaSize);
        self:ControlTroopOperation(self.Troops[i], _Position, Enemies);
    end

    -- refill weak troops
    if not self:IsFighting() then
        if self:HasWeakTroops() then
            local Enemies = AiArmy:GetEnemiesInRodeLength(self.PlayerID, self.HomePosition);
            if table.getn(Enemies) == 0 then
                self.State = ArmyStates.Retreat;
            end
        end
    end
end

function AiArmy:ControlTroopOperation(_TroopID, _Position, _Enemies)
    local ArmyPosition = self:GetArmyPosition();
    if self.TroopProperties[_TroopID].State == 0 then
        if self.State == ArmyStates.Attack then
            local Target = self:TargetEnemy(_TroopID, _Enemies);
            if Target > 0 then
                if QuestTools.GetDistance(_TroopID, ArmyPosition) > self.RodeLength + self.OuterRange then
                    self:MoveTroop(_TroopID, ArmyPosition);
                    self.TroopProperties[_TroopID] = {State = 1, Target = 0, Time = 0,};
                else
                    if not self:IsTroopFighting(_TroopID) then
                        if Logic.IsEntityInCategory(_TroopID, EntityCategories.LongRange) == 1
                        or Logic.IsEntityInCategory(_TroopID, EntityCategories.Cannon) == 1 then
                            self:TroopAttack(_TroopID, Target);
                        else
                            self:TroopAttackMove(_TroopID, Target);
                        end
                    end
                end
            else
                if QuestTools.GetDistance(_TroopID, ArmyPosition) > self.RodeLength / 2 then
                    self:MoveTroop(_TroopID, ArmyPosition);
                    self.TroopProperties[_TroopID] = {State = 1, Target = 0, Time = 0,};
                else
                    if not Logic.IsEntityMoving(_TroopID) then
                        self:TroopAttackMove(_TroopID, _Position);
                    end
                end
            end
        else
            local Target = self:TargetEnemy(_TroopID, _Enemies);
            if Target > 0 then
                if QuestTools.GetDistance(_TroopID, ArmyPosition) > self.RodeLength + self.OuterRange then
                    self.TroopProperties[_TroopID] = {State = 1, Target = 0, Time = 0,};
                else
                    if self.State ~= ArmyStates.Retreat then
                        if not self:IsTroopFighting(_TroopID) then
                            if Logic.IsEntityInCategory(_TroopID, EntityCategories.Melee) == 1 then
                                self:TroopAttackMove(_TroopID, Target);
                            else
                                self:TroopAttack(_TroopID, Target);
                            end
                        end
                    end
                end
            else
                if QuestTools.GetDistance(_TroopID, _Position) > self.RodeLength / 2 then
                    self:MoveTroop(_TroopID, _Position);
                end
            end
        end
    elseif self.TroopProperties[_TroopID].State == 1 then
        if QuestTools.GetDistance(_TroopID, ArmyPosition) < 750 then
            self.TroopProperties[_TroopID].State = 0;
        else
            if Logic.IsEntityMoving(_TroopID) == false then
                self:MoveTroop(_TroopID, ArmyPosition);
            end
        end
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
    elseif Logic.IsEntityInCategory(_TroopID, EntityCategories.Spear) == 1
    or     Logic.IsEntityInCategory(_TroopID, EntityCategories.Sword) == 1 then
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

function AiArmy:GetEnemiesInRodeLength(_PlayerID, _Position)
    return self:GetEnemiesInArea(_PlayerID, _Position, self.RodeLength + self.OuterRange);
end

function AiArmy:GetEnemiesInArea(_PlayerID, _Position, _Range)
    if type(_Position) ~= "table" then
        _Position = GetPosition(_Position);
    end
    local AllEnemiesInSight = {};
    for i= 1, 8, 1 do
        if i ~= _PlayerID and Logic.GetDiplomacyState(_PlayerID, i) == Diplomacy.Hostile then
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
            if QuestTools.AreEnemiesInArea(self.PlayerID, self:GetArmyPosition(), self.RodeLength) then
                self.TroopProperties[_TroopID].Target = Enemies[1];
                self.TroopProperties[_TroopID].Time   = 5;
            end
            return Enemies[1];
        end
    end
    return 0;
end

function AiArmy:GetEnemiesInRangeOfTroop(_TroopID)
    local Range = self.RodeLength + self.OuterRange;
    local Enemies = self:GetEnemiesInArea(self.PlayerID, _TroopID, Range);
    for i= table.getn(Enemies), 1, -1 do
        if not IsExisting(Enemies[i]) or Logic.GetEntityHealth(Enemies[i]) == 0 then
            table.remove(Enemies, i);
        end
    end
    if table.getn(Enemies) > 1 then
        table.sort(Enemies, function(a, b)
            local Cost1 = math.floor(QuestTools.GetDistance(a, _TroopID) / 10);
            local Factor1 = self:GetTargetCostFactorForTroop(a, _TroopID);
            local Priority1 = Cost1 * Factor1;
            
            local Cost2 = math.floor(QuestTools.GetDistance(b, _TroopID) / 10);
            local Factor2 = self:GetTargetCostFactorForTroop(b, _TroopID);
            local Priority2 = Cost2 * Factor2;

            if Priority1 == 0 then
                return false;
            elseif Priority2 == 0 then
                return true;
            elseif Priority1 == 0 and Priority2 == 0 then
                return false;
            else
                return Priority1 < Priority2;
            end
        end)
    end
    return Enemies;
end

function AiArmy:GetTargetCostFactorForTroop(_TargetID, _TroopID)
    local Factor = 1.0;
    local Priority = self:GetTargetCostFactors(_TargetID);
    for k, v in pairs(QuestTools.GetEntityCategoriesAsString(_TargetID)) do
        Factor = Factor * (Priority[v] or 1);
    end
    local Cur = 1;
    local Max = 1;
    if Logic.IsLeader(_TargetID) == 1 then
        Cur = Logic.LeaderGetNumberOfSoldiers(_TargetID);
        Max = Logic.LeaderGetMaxNumberOfSoldiers(_TargetID);
    end
    Factor = Factor * ((Max > 0 and 1 - (Cur/Max)) or 1);
    return Factor;
end

function AiArmy:GetTargetCostFactors(_TargetID)
    if Logic.IsEntityInCategory(_TroopID, EntityCategories.Hero) == 1 then
        -- TODO: Implement
    end
    if Logic.IsEntityInCategory(_TroopID, EntityCategories.EvilLeader) == 1 then
        if Logic.GetEntityType(_TroopID) == Entities.CU_Evil_LeaderSkirmisher then
            return GroupTargetingPriorities.Ranged;
        end
        return GroupTargetingPriorities.Sword;
    end
    if Logic.IsEntityInCategory(_TroopID, EntityCategories.CavalryHeavy) == 1 then
        return GroupTargetingPriorities.HeavyCavalry;
    end
    if Logic.IsEntityInCategory(_TroopID, EntityCategories.Sword) == 1 then
        return GroupTargetingPriorities.Sword;
    end
    if Logic.IsEntityInCategory(_TroopID, EntityCategories.Spear) == 1 then
        return GroupTargetingPriorities.Spear;
    end
    if Logic.IsEntityInCategory(_TroopID, EntityCategories.Rifle) == 1 then
        return GroupTargetingPriorities.Rifle;
    end
    if Logic.IsEntityInCategory(_TroopID, EntityCategories.LongRange) == 1 then
        return GroupTargetingPriorities.Ranged;
    end
    if Logic.IsEntityInCategory(_TroopID, EntityCategories.Cannon) == 1 then
        return GroupTargetingPriorities.Cannon;
    end
    return {};
end

-- -------------------------------------------------------------------------- --

GroupTargetingPriorities = {};

GroupTargetingPriorities.Cannon = {
    ["MilitaryBuilding"] = 0.1,
    ["EvilLeader"] = 0.3,
    ["VillageCenter"] = 0.4,
    ["Headquarters"] = 0.4,
    ["LongRange"] = 0.5,
};
GroupTargetingPriorities.HeavyCavalry = {
    ["Hero"] = 0.2,
    ["Cannon"] = 0.2,
    ["LongRange"] = 0.3,
    ["MilitaryBuilding"] = 0.4,
    ["Sword"] = 0.4,
    ["Hero10"] = 0.7,
    ["Hero4"] = 0.9,
    ["Spear"] = 0,
};
GroupTargetingPriorities.Sword = {
    ["Hero"] = 0.2,
    ["Spear"] = 0.3,
    ["Cannon"] = 0.3,
    ["LongRange"] = 0.4,
    ["CavalryHeavy"] = 0,
};
GroupTargetingPriorities.Spear = {
    ["CavalryHeavy"] = 0.1,
    ["CavalryLight"] = 0.3,
    ["MilitaryBuilding"] = 0.7,
    ["Sword"] = 0,
    ["LongRange"] = 0,
};
GroupTargetingPriorities.Ranged = {
    ["MilitaryBuilding"] = 0.3,
    ["CavalryHeavy"] = 0.3,
    ["CavalryLight"] = 0.3,
    ["VillageCenter"] = 0.5,
    ["Headquarters"] = 0.5,
    ["Hero"] = 0.6,
    ["Hero10"] = 0.7,
    ["Hero4"] = 0.9,
};
GroupTargetingPriorities.Rifle = {
    ["EvilLeader"] = 0.1,
    ["LongRange"] = 0.2,
    ["Cannon"] = 0.2,
    ["MilitaryBuilding"] = 0.3,
    ["VillageCenter"] = 0.4,
    ["Headquarters"] = 0.4,
    ["Hero10"] = 0.8,
    ["Melee"] = 0.95,
};

