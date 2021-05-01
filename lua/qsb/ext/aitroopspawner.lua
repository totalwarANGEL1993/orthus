-- ########################################################################## --
-- #  AI Troop Recruiter                                                    # --
-- #  --------------------------------------------------------------------  # --
-- #    Author:   totalwarANGEL                                             # --
-- ########################################################################## --

-- -------------------------------------------------------------------------- --

AiTroopSpawner = {
    ScriptName = nil,
    Troops = {
        Maximum = 8,
        Selector = function(self)
            local Size = table.getn(self.Troops.Types);
            return self.Troops.Types[math.random(1, Size)];
        end,
        Types = {},
        Created = {},
    },
}

AiTroopSpawnerList = {};

function AiTroopSpawner:New(_ScriptName)
    local Spawner = copy(AiTroopSpawner);
    Spawner.ScriptName = _ScriptName;
    AiTroopSpawnerList[_ScriptName] = Spawner;
    Spawner:Initalize();
    return Spawner;
end

function AiTroopSpawner:Initalize()
    if not self.Initalized then
        self.Initalized = true;
        
        -- Save approach position
        local Position = GetPosition(self.ScriptName);
        local ID = AI.Entity_CreateFormation(8, Entities.PU_Serf, 0, 0, Position.X, Position.Y, 0, 0, 0, 0);
        self.ApproachPosition = GetPosition(ID);
        DestroyEntity(ID);
    end
end

function AiTroopSpawner:AddType(_Type, _Exp)
    table.insert(self.Troops.Types, {_Type, _Exp});
    return self;
end

function AiTroopSpawner:ClearTypes()
    self.Troops.Types = {};
    return self;
end

function AiTroopSpawner:SetApproachPosition(_Position)
    self.ApproachPosition = _Position;
    return self;
end

function AiTroopSpawner:SetMaxTroops(_Max)
    self.Troops.Maximum = _Max;
    return self;
end

function AiTroopSpawner:IsReady()
    if self.ScriptName and IsExisting(self.ScriptName) then
        if table.getn(self.Troops.Created) < self.Troops.Maximum then
            return true;
        end
    end
    return false;
end

function AiTroopSpawner:GetTroop()
    for i= table.getn(self.Troops.Created), 1, -1 do
        if IsExisting(self.Troops.Created[i]) then
            return table.remove(self.Troops.Created, i);
        else
            table.remove(self.Troops.Created, i);
        end
    end
    return 0;
end

function AiTroopSpawner:CreateTroop()
    if self:IsReady() then
        if table.getn(self.Troops.Types) > 0 then
            local TroopType = self.Troops.Selector(self);
            local ID = GetID(self.ScriptName);
            local PlayerID = Logic.EntityGetPlayer(ID);
            local Position = self.ApproachPosition;

            local TroopID = AI.Entity_CreateFormation(
                PlayerID,
                TroopType[1],
                0,
                16,
                Position.X,
                Position.Y,
                0,
                0,
                TroopType[2] or 0,
                16
            );
            table.insert(self.Troops.Created, TroopID);
        end
    end
end

