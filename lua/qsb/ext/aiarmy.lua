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
    HomePosition         = nil,
    State                = ArmyStates.Decide;
    TroopCount           = 8;
    Troops               = {},
    RodeLength           = 3500;
    Strength             = 0;
    RetreatStrength      = 0.2;
    Producers            = {},

    AttackAllowed        = true,
    DefendAllowed        = true,
    IsRespawningArmy     = false,
    InitialSpawned       = false,

    Target               = nil,
}

AiArmyList = {};

function AiArmy:construct(_PlayerID, _ArmyID, _Home, _Range, _TroopAmount)
    self.PlayerID = _PlayerID;
    self.ArmyID = _ArmyID;
    self.HomePosition = _Home;
    self.RodeLength = _Range;
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

function AiArmy:GetArmyPosition()
    local CurrentTroops = table.getn(self.Troops);
    if table.getn(self.Troops) == 0 then
        return self.HomePosition;
    else
        return QuestTools.GetGeometricFocus(unpack(self.Troops));
    end
end

function AiArmy:CalculateStrength()
    local Strength = 0;
    for i= table.getn(self.Troops), 1, -1 do
        local TroopStrength = 1;
        if Logic.IsLeader(self.Troops[i]) == 1 then
            local MaxSoldiers = Logic.LeaderGetMaxNumberOfSoldiers(self.Troops[i]);
            if MaxSoldiers > 0 then
                local CurSoldiers = Logic.LeaderGetNumberOfSoldiers(self.Troops[i]);
                TroopStrength = TroopStrength * (CurSoldiers/MaxSoldiers);
            end
        end
        Strength = Strength + TroopStrength;
    end
    return Strength;
end

function AiArmy:Operate()
    if self.ArmyIsDead then
        return true;
    end
    if self.ArmyIsPaused then
        return false;
    end

    for i= table.getn(self.Troops), 1, -1 do
        if not IsExisting(self.Troops[i]) then
            table.remove(self.Troops, i);
        end
    end

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

-- -------------------------------------------------------------------------- --

function AiArmy:CallSelectActionBehavior()
    if self.SelectActionBehavior then
        self:SelectActionBehavior(self);
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
        _Army.State = ArmyStates.Retreat;
        return;
    end
    -- handle attack
    if _Army.AttackAllowed then
        if not _Army.Target then
            -- TODO: Select target
            return;
        else
            _Army.State = ArmyStates.Attack;
            return;
        end
    end
    -- handle defend
    if _Army.DefendAllowed then
        -- TODO: Select target
        return;
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
        _Army.State = ArmyStates.Retreat;
        return;
    end
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
        _Army.State = ArmyStates.Retreat;
        return;
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
        _Army.State = ArmyStates.Refill;
    elseif QuestTools.GetDistance(_Army:GetArmyPosition(), _Army.HomePosition) <= 2000 then
        _Army.State = ArmyStates.Refill;
    else
        local HomePosition = GetPosition(_Army.HomePosition);
        local Weak = _Army:GetWeakTroops();
        _Army:DispatchTroopsToProducers(Weak);
        for i= table.getn(_Army.Troops), 1, -1 do
            if Logic.IsEntityMoving(_Army.Troops[i]) == false then
                Logic.MoveSettler(_Army.Troops[i], HomePosition.X, HomePosition.Y);
            end
        end
    end
end

function AiArmy:GetWeakTroops()
    local Weak = {};
    for i= table.getn(self.Troops), 1, -1 do
        local Cur = Logic.LeaderGetNumberOfSoldiers(self.Troops[i]);
        local Max = Logic.LeaderGetMaxNumberOfSoldiers(self.Troops[i]);
        if Max > 0 and Cur < Max then
            table.insert(Weak, table.remove(self.Troops, i));
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
            if v and v:IsAlive() and QuestTools.IsInTable(Troops[i], v.ApproachPosition) then
                local ProducerType = Logic.GetEntityType(GetID(v.ScriptName));
                if v.IsSpawner and v:IsInTypeList(TroopType) then
                    table.insert(v.Troops.Created, table.remove(Troops, i));
                    break;
                elseif v.IsRecruiter and v:IsSuitableUnitType(TroopType) then
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
    if table.getn(_Army.Troops) == _Army.TroopCount then
        local HomePosition = GetPosition(_Army.HomePosition);
        for i= table.getn(_Army.Troops), 1, -1 do
            if Logic.IsEntityMoving(_Army.Troops[i]) == false then
                Logic.MoveSettler(_Army.Troops[i], HomePosition.X, HomePosition.Y);
            end
        end
        _Army.State = ArmyStates.Decide;
    else
        -- Initial spawn
        if _Army.IsRespawningArmy then
            if not _Army.InitialSpawned then
                local Spawner = _Army:GetSpawnerProducers();
                if table.getn(Spawner) > 0 then
                    for i= table.getn(Spawner), 1, -1 do
                        if table.getn(_Army.Troops) < _Army.TroopCount then
                            Spawner[i]:CreateTroop(true);
                            local ID = Spawner[i]:GetTroop();
                            if ID > 0 then
                                table.insert(_Army.Troops, ID);
                            end
                        end
                    end
                    return;
                end
            end
        end
    
        -- normal spawn/recruitment
        for k, v in pairs(_Army.Producers) do
            if v then
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

