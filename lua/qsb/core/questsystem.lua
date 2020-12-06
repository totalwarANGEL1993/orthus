-- ########################################################################## --
-- #  Questsystem                                                           # --
-- #  --------------------------------------------------------------------  # --
-- #    Author:   totalwarANGEL                                             # --
-- ########################################################################## --

---
-- This is an approach to create a RoaE like quest system.
--
-- Quests can be either successfully finished or failed. If a quest is finished
-- successfully the rewards will be executed. If the quest fails the reprisals
-- will be executed instead. Quests are controlled by behaviors. Behind a
-- behavior is predefined code that is executed with certain parameters. It is
-- also possible to create a custom behavior for each type.
--
-- Types are:
-- <ul>
-- <li>Condition: Triggering the quest if conditions are true</li>
-- <li>Objective: What the player has to do to win (or to fail)</li>
-- <li>Reward: Rewards for successfully finishing a quest.</li>
-- <li>Reprisal: Pubishments after the quest failed.</li>
-- </ul>
-- But reprisals and rewards are both callbacks!
--
-- A quest is generated like this:<br>
-- <pre>local QuestID = new(QuestTemplate, "SomeName", SomeObjectives, SomeConditions, 1, 0, SomeRewards, SomeReprisals)</pre>
--
-- Some of the behavior might be redefined in the qsb.questbehavior abstraction
-- layer.
--
-- <b>Required modules:</b>
-- <ul>
-- <li>qsb.core.oop</li>
-- <li>qsb.core.mpsync</li>
-- </ul>
--
-- @set sort=true
--

QuestSystem = {
    QuestLoop = "QuestSystem_QuestControllerJob",
    QuestDescriptions = {},
    Quests = {},
    QuestMarkers = {},
    MinimapMarkers = {},
    Briefings = {},
    BriefingsQueue = {},
    HurtEntities = {},
    NamedEffects = {},
    NamedExplorations = {},
    NamedEntityNames = {},
    InlineJobs = {Counter = 0},
    CustomVariables = {},

    UniqueTributeID = 0,
    UniqueBriefingID = 0,
    Verbose = false,
};

-- -------------------------------------------------------------------------- --

---
-- This function initalizes the quest system.
-- @within QuestSystem
-- @local
--
function QuestSystem:InstallQuestSystem()
    if self.SystemInstalled ~= true then
        self.SystemInstalled = true;
        
        -- Initalize syncher
        EndJob(tributeJingleTriggerId);
        MPSync:Install();
        self.BriefingFinishedScriptEvent = MPSync:CreateScriptEvent(function(_ID)
            -- Register briefing end
            QuestSystem.Briefings[_ID] = true;
            -- Dequeue next briefing
            if table.getn(QuestSystem.BriefingsQueue) > 0 then
                local Entry = table.remove(QuestSystem.BriefingsQueue, 1);
                StartBriefing(Entry[1], Entry[2], Entry[3]);
            end
        end);

        -- Quest descriptions for all players
        for i= 1, table.getn(Score.Player), 1 do
            self.QuestDescriptions[i] = {};
        end

        -- Real random numbers
        local TimeString = "1" ..string.gsub(string.sub(Framework.GetSystemTimeDateString(), 12), "-", "");
        math.randomseed(tonumber(TimeString));
        math.random(1, 100);

        self:InitalizeQuestEventTrigger();

        -- Optional briefing expansion
        if ActivateBriefingExpansion then
            ActivateBriefingExpansion();
        end

        -- Briefing Start
        StartBriefing_Orig_QuestSystem = StartBriefing;
        StartBriefing = function(_Briefing, _Quest, _ID)
            -- Set briefing id
            if not _ID then
                QuestSystem.UniqueBriefingID = QuestSystem.UniqueBriefingID +1;
                _ID = QuestSystem.UniqueBriefingID;
            end
            -- initalize briefing id
            QuestSystem.Briefings[_ID] = false;

            -- Display briefing for receiver
            if _Quest.m_Receiver == GUI.GetPlayerID() then
                -- Enqueue if briefing active
                if IsBriefingActive() then
                    table.insert(QuestSystem.BriefingsQueue, {copy(_Briefing), _Quest, _ID});
                    return _ID;
                end
                -- Start briefing
                StartBriefing_Orig_QuestSystem(_Briefing);
                briefingState.BriefingID = _ID;
            end
            return _ID;
        end

        -- Briefing End
        EndBriefing_Orig_QuestSystem = EndBriefing;
        EndBriefing = function()
            local ID = briefingState.BriefingID;
            -- End briefing
            EndBriefing_Orig_QuestSystem();
            -- Send briefing end event
            MPSync:SnchronizedCall(self.BriefingFinishedScriptEvent, ID);
        end
    end
end

---
-- Enables the triggers for quests.
-- @within QuestSystem
-- @local
--
function QuestSystem:InitalizeQuestEventTrigger()
    function QuestSystem_DestroyedEntities_TagParticipants()
        local Attacker  = Event.GetEntityID1();
        local Defenders = {Event.GetEntityID2()};

        for i= 1, table.getn(Defenders), 1 do
            local Soldiers;
            if Logic.IsLeader(Defenders[i]) == 1 then
                Soldiers = {Logic.GetSoldiersAttachedToLeader(leaderID)};
                table.remove(Soldiers, 1);
            end
            QuestSystem.HurtEntities[Defenders[i]] = {Attacker, Logic.GetTime(), Soldiers};
        end
    end

    Trigger.RequestTrigger(
        Events.LOGIC_EVENT_ENTITY_HURT_ENTITY,
        "",
        "QuestSystem_DestroyedEntities_TagParticipants",
        1
    );

    -- ---------------------------------------------------------------------- --

    function QuestSystem_DestroyedEntities_RegisterDestroyed()
        local Destroyed = {Event.GetEntityID()};
        for i= 1, table.getn(Destroyed), 1 do
            if QuestSystem.HurtEntities[Destroyed[i]] then
                local AttackerID = QuestSystem.HurtEntities[Destroyed[i]][1];
                local AttackingPlayer = Logic.EntityGetPlayer(AttackerID);
                local DefendingPlayer = Logic.EntityGetPlayer(Destroyed[i]);
                QuestSystem:ObjectiveDestroyedEntitiesHandler(AttackingPlayer, AttackerID, DefendingPlayer, Destroyed[i]);
            end
        end
    end

    Trigger.RequestTrigger(
        Events.LOGIC_EVENT_ENTITY_DESTROYED,
        "",
        "QuestSystem_DestroyedEntities_RegisterDestroyed",
        1
    );

    -- ---------------------------------------------------------------------- --

    function QuestSystem_DestroyedEntities_ClearTagged()
        for k, v in pairs(QuestSystem.HurtEntities) do
            if v and v[2]+3 < Logic.GetTime() then
                QuestSystem.HurtEntities[k] = nil;
            end
        end
    end

    Trigger.RequestTrigger(
        Events.LOGIC_EVENT_EVERY_SECOND,
        "",
        "QuestSystem_DestroyedEntities_ClearTagged",
        1
    );

    -- ---------------------------------------------------------------------- --

    function QuestSystem_TributePayedTrigger()
        QuestSystem:QuestTributePayed(Event.GetTributeUniqueID());
    end

    Trigger.RequestTrigger(
        Events.LOGIC_EVENT_TRIBUTE_PAID,
		"",
		"QuestSystem_TributePayedTrigger",
        1
    );

    -- ---------------------------------------------------------------------- --

    function QuestSystem_OnPaydayTrigger()
        local PaydayTimeoutFlag = PaydayTimeoutFlag or {};
        local PaydayOverFlag = PaydayOverFlag or {};

        for i= 1, table.getn(Score.Player), 1 do
            PaydayTimeoutFlag[i] = PaydayTimeoutFlag[i] or false;
            PaydayOverFlag[i] = PaydayOverFlag[i] or false;

            if Logic.GetPlayerPaydayTimeLeft(i) < 1000  then
                PaydayTimeoutFlag[i] = true;
            elseif Logic.GetPlayerPaydayTimeLeft(i) > 118000 then
                PaydayTimeoutFlag[i] = false;
                PaydayOverFlag[i] = false;
            end
            if PaydayTimeoutFlag and not PaydayOverFlag then
                QuestSystem:QuestPaydayEvent(i);
                PaydayOverFlag[i] = true;
            end
        end
    end

    Trigger.RequestTrigger(
        Events.LOGIC_EVENT_EVERY_TURN,
        "",
        "QuestSystem_OnPaydayTrigger",
        1
    );

    -- ---------------------------------------------------------------------- --

    function QuestSystem_QuestControllerJob(_QuestID)
        local Quest = QuestSystem.Quests[_QuestID];

        if Quest.m_State == QuestStates.Inactive then
            if Quest.m_Result == QuestResults.Undecided then
                local QuestIsTriggered = true;
                for i = 1, table.getn(Quest.m_Conditions) do
                    QuestIsTriggered = QuestIsTriggered and Quest:IsConditionFulfilled(i) == true;
                end
                if QuestIsTriggered then
                    Quest:Trigger();
                end
            end
        end

        if Quest.m_State == QuestStates.Active then
            if Quest.m_Result == QuestResults.Undecided then
                local AllObjectivesTrue = true;
                local AnyObjectiveFalse = false;

                for i = 1, table.getn(Quest.m_Objectives) do
                    local ObjectiveCompleted = Quest:IsObjectiveCompleted(i);
                    if Quest.m_Time > 0 and Quest.m_StartTime + Quest.m_Time < Logic.GetTime() then
                        if ObjectiveCompleted == nil then
                            if Quest.m_Objectives[i][1] == Objectives.Protect or Quest.m_Objectives[i][1] == Objectives.NoChange then
                                ObjectiveCompleted = true;
                            else
                                ObjectiveCompleted = false;
                            end
                        end
                    end
                    AllObjectivesTrue = (ObjectiveCompleted == true) and AllObjectivesTrue;
                    AnyObjectiveFalse = (ObjectiveCompleted == false and true) or AnyObjectiveFalse;
                end

                if AnyObjectiveFalse then
                    Quest:Fail();
                elseif AllObjectivesTrue then
                    Quest:Success();
                end
            end
        end

        if Quest.m_State == QuestStates.Over then
            if Quest.m_Result == QuestResults.Success then
                for i = 1, table.getn(Quest.m_Rewards) do
                    Quest:ApplyCallbacks(Quest.m_Rewards[i]);
                end
            elseif Quest.m_Result == QuestResults.Failure then
                for i = 1, table.getn(Quest.m_Reprisals) do
                    Quest:ApplyCallbacks(Quest.m_Reprisals[i]);
                end
            end
            return true;
        end
    end
end

---
-- Returns the extension number. This function can be used to identify the
-- current expansion of the game.
-- @return[type=number] Extension
-- @within QuestSystem
-- @local
--
function QuestSystem:GetExtensionNumber()
    local Version = Framework.GetProgramVersion();
    local extensionNumber = tonumber(string.sub(Version, string.len(Version))) or 0;
    return extensionNumber;
end

---
-- Returns the next free slot in the quest book.
--
-- If the game is in ISAM mode then the next free slot is always the amount
-- of entries +1.
--
-- If the game is in vanilla mode then the next free slot is the next index
-- up to 8. If there is a finished quest in the jornal then it's slot is
-- returned and the old data is invalidated.
--
-- If no free slot can be found then nil is returned.
--
-- @return[type=number] Journal ID
-- @within QuestSystem
-- @local
--
function QuestSystem:GetNextFreeJornalID(_PlayerID)
    if self:GetExtensionNumber() == 3 then
        return table.getn(self.QuestDescriptions[_PlayerID]) +1;
    end
    
    local NextID = table.getn(self.QuestDescriptions[_PlayerID]) +1;
    if NextID < 9 then
        return NextID;
    end

    local OldestQuestIdx;
    local OldestQuestTime = Logic.GetTime();

    for i= table.getn(self.QuestDescriptions[_PlayerID]), 1, -1 do
        if self.QuestDescriptions[_PlayerID][i] ~= nil then
            local Quest = QuestSystem.Quests[self.QuestDescriptions[_PlayerID][i][1]];
            if Quest == nil then
                self:InvalidateQuestAtJornalID(_PlayerID, i);
                return i;
            else
                if Quest.m_FinishTime ~= nil and OldestQuestTime >= Quest.m_FinishTime then
                    OldestQuestTime = Quest.m_FinishTime;
                    OldestQuestIdx = i;
                end
            end
        end
    end

    if OldestQuestIdx ~= nil then
        self:InvalidateQuestAtJornalID(_PlayerID, OldestQuestIdx);
        return OldestQuestIdx;
    end
end

---
-- Returns the next free slot in the quest book.
-- @param[type=number] _QuestID Id of quest
-- @return[type=table] Journal entry
-- @return[type=number] Jornal ID
-- @within QuestSystem
-- @local
--
function QuestSystem:GetJornalByQuestID(_QuestID)
    local Quest = self.Quests[_QuestID];
    if not Quest then
        return;
    end
    for i= 1, table.getn(Score.Player), 1 do
        if  self.QuestDescriptions[Quest.m_Receiver][i] 
        and self.QuestDescriptions[Quest.m_Receiver][i][1] == _QuestID then
            return self.QuestDescriptions[Quest.m_Receiver][i], i;
        end
    end
end

---
-- Registers a quest from the quest system for the quest book slot.
-- @return[type=number] Jornal ID
-- @return[type=table] Quest data
-- @within QuestSystem
-- @local
--
function QuestSystem:RegisterQuestAtJornalID(_JornalID, _QuestData)
    local Quest = self.Quests[_QuestData[1]];
    if not Quest then
        return;
    end
    self.QuestDescriptions[Quest.m_Receiver][_JornalID] = copy(_QuestData);
end

---
-- Removes the registered entry for the quest book slot.
-- @param[type=number] _PlayerID ID of Receiver
-- @param[type=number] _JornalID Jornal ID
-- @within QuestSystem
-- @local
--
function QuestSystem:InvalidateQuestAtJornalID(_PlayerID, _JornalID)
    self.QuestDescriptions[_PlayerID][_JornalID] = nil;
end

-- -------------------------------------------------------------------------- --

QuestTemplate = {};

---
-- Creates a quest.
--
-- @param[type=string] _QuestName   Quest name
-- @param[type=number] _Receiver    Receiving player
-- @param[type=number] _Time        Completion time
-- @param[type=table]  _Objectives  List of objectives
-- @param[type=table]  _Conditions  List of conditions
-- @param[type=table]  _Rewards     List of rewards
-- @param[type=table]  _Reprisals   List of reprisals
-- @param[type=table]  _Description Quest description
-- @within QuestTemplate
--
function QuestTemplate:construct(_QuestName, _Receiver, _Time, _Objectives, _Conditions, _Rewards, _Reprisals, _Description)
    QuestSystem:InstallQuestSystem();

    self.m_QuestName   = _QuestName;
    self.m_Objectives  = (_Objectives and copy(_Objectives)) or {};
    self.m_Conditions  = (_Conditions and copy(_Conditions)) or {};
    self.m_Rewards     = (_Rewards and copy(_Rewards)) or {};
    self.m_Reprisals   = (_Reprisals and copy(_Reprisals)) or {};
    self.m_Time        = _Time or 0;
    self.m_Fragments   = {{}, {}, 0};

    if _Description then
        self.m_Description = QuestSystem:RemoveFormattingPlaceholders(_Description);
    end

    self.m_State       = QuestStates.Inactive;
    self.m_Result      = QuestResults.Undecided;
    self.m_Receiver    = _Receiver;

    table.insert(QuestSystem.Quests, self);
    self.m_QuestID = table.getn(QuestSystem.Quests);
    Trigger.RequestTrigger(
        Events.LOGIC_EVENT_EVERY_SECOND,
        "",
        QuestSystem.QuestLoop,
        1,
        {},
        {self.m_QuestID}
    );
end

class(QuestTemplate);

---
-- Displays a debug message if the verbose flag is set.
-- @param[type=string] _Text Displayed message
-- @within QuestTemplate
-- @local
--
function QuestTemplate:verbose(_Text)
    if QuestSystem.Verbose then
        Message(_Text);
    end
end

-- -------------------------------------------------------------------------- --

---
-- Checks, if the objective of the quest is fullfilled, failed or undecided.
--
-- @param[type=number] _Index Index of behavior
-- @within QuestTemplate
-- @local
--
function QuestTemplate:IsObjectiveCompleted(_Index)
    local Behavior = self.m_Objectives[_Index];
    -- Dont evaluate if already done
    if Behavior.Completed ~= nil then
        return Behavior.Completed;
    end

    if Behavior[1] == Objectives.NoChange then

    elseif Behavior[1] == Objectives.InstantSuccess then
        Behavior.Completed = true;

    elseif Behavior[1] == Objectives.InstantFailure then
        Behavior.Completed = false;

    elseif Behavior[1] == Objectives.MapScriptFunction then
        Behavior.Completed = Behavior[2][1](Behavior[2][2], self);

    elseif Behavior[1] == Objectives.Destroy then

        if type(Behavior[2]) == "table" then
            if IsDeadWrapper(Behavior[2]) then
                Behavior.Completed = true;
            end
        else
            local EntityID = GetID(Behavior[2]);
            if not IsExisting(EntityID) then
                Behavior.Completed = true;
            else
                if Logic.IsHero(EntityID) == 1 and Logic.GetEntityHealth(EntityID) == 0 then
                    Behavior.Completed = true;
                end
            end
        end

    elseif Behavior[1] == Objectives.DestroyAllPlayerUnits then
        local PlayerEntities = {Logic.GetAllPlayerEntities(Behavior[2], 16)};
        if PlayerEntities[1] == 0 then
            Behavior.Completed = true;
        else
            local LegalEntitiesCount = 0;
            for i= 2, table.getn(PlayerEntities), 1 do
                local Type = Logic.GetEntityType(PlayerEntities[i]);
                if  Type ~= Entities.XD_ScriptEntity and Type ~= Entities.XD_BuildBlockScriptEntity and Type ~= Entities.XS_Ambient and Type ~= Entities.XD_Explore10
                and Type ~= Entities.XD_CoordinateEntity and Type ~= Entities.XD_Camp_Internal and Type ~= Entities.XD_StandartePlayerColor
                and Type ~= Entities.XD_StandardLarge and Logic.IsEntityInCategory(PlayerEntities[i], EntityCategories.Wall) == 0 then
                    LegalEntitiesCount = LegalEntitiesCount +1;
                end
            end
            if LegalEntitiesCount == 0 then
                Behavior.Completed = true;
            end
        end

    elseif Behavior[1] == Objectives.Create then
        local Position = (type(Behavior[3]) == "table" and Behavior[3]) or GetPosition(Behavior[3]);

        local EnoughEntities = SaveCall{
            AreEntitiesInArea, self.m_Receiver, Behavior[2], Position, Behavior[4], Behavior[5],
            ErrorHandler = function() return false; end
        };

        if EnoughEntities then
            if Behavior[7] then
                local CreatedEntities = {Logic.GetPlayerEntitiesInArea(self.m_Receiver, Behavior[2], Position.X, Position.Y, Behavior[4], Behavior[5])};
                for i= 2, table.getn(CreatedEntities), 1 do
                    SaveCall{ChangePlayer, CreatedEntities[i], Behavior[7]};
                end
            end
            Behavior.Completed = true;
        end

    elseif Behavior[1] == Objectives.Produce then
        local Amount = Logic.GetPlayersGlobalResource(self.m_Receiver, Behavior[2]);
        if not Behavior[4] then
            Amount = Amount + Logic.GetPlayersGlobalResource(self.m_Receiver, Behavior[2]+1);
        end
        if Amount >= Behavior[3] then
            Behavior.Completed = true;
        end

    elseif Behavior[1] == Objectives.Protect then
        local EntityID = GetID(Behavior[2]);
        if not IsExisting(EntityID) then
            Behavior.Completed = false;
        else
            if Logic.IsHero(EntityID) == 1 and Logic.GetEntityHealth(EntityID) == 0 then
                Behavior.Completed = false;
            end
        end

    elseif Behavior[1] == Objectives.Diplomacy then
        if Logic.GetDiplomacyState(self.m_Receiver, Behavior[2]) == Behavior[3] then
            Behavior.Completed = true;
        end

    elseif Behavior[1] == Objectives.EntityDistance then
        local Distance = SaveCall{
            GetDistance, Behavior[2], Behavior[3],
            ErrorHandler = function() return 0; end
        };

        if Behavior[5] then
            if Distance < (Behavior[4] or 2000) then
                Behavior.Completed = true;
            end
        else
            if Distance >= (Behavior[4] or 2000) then
                Behavior.Completed = true;
            end
        end

    elseif Behavior[1] == Objectives.Settlers or Behavior[1] == Objectives.Workers or Behavior[1] == Objectives.Soldiers or Behavior[1] == Objectives.Motivation then
        local Amount = 0;
        if Behavior[1] == Objectives.Workers then
            Amount = Logic.GetNumberOfAttractedWorker(Behavior[4] or self.m_Receiver);
        elseif Behavior[1] == Objectives.Soldiers then
            Amount = Logic.GetNumberOfAttractedSoldiers(Behavior[4] or self.m_Receiver);
        elseif Behavior[1] == Objectives.Motivation then
            Amount = Logic.GetAverageMotivation(Behavior[4] or self.m_Receiver);
        else
            Amount = Logic.GetNumberOfAttractedSettlers(Behavior[4] or self.m_Receiver);
        end

        if Behavior[3] then
            if Amount < Behavior[2] then
                Behavior.Completed = true;
            end
        else
            if Amount >= Behavior[2] then
                Behavior.Completed = true;
            end
        end

    elseif Behavior[1] == Objectives.Units then
        if Logic.GetNumberOfEntitiesOfTypeOfPlayer(self.m_Receiver, Behavior[2]) >= Behavior[3] then
            Behavior.Completed = true;
        end

    elseif Behavior[1] == Objectives.Technology then
        if Logic.IsTechnologyResearched(self.m_Receiver, Behavior[2]) == 1 then
            Behavior.Completed = true;
        end

    elseif Behavior[1] == Objectives.Headquarters then
        if Logic.GetPlayerEntities(self.m_Receiver, Entities.PB_Headquarters1 + Behavior[2], 1) > 0 then
            Behavior.Completed = true;
        end

    elseif Behavior[1] == Objectives.DestroyType or Behavior[1] == Objectives.DestroyCategory then
        Behavior[5] = Behavior[5] or 0;
        if Behavior[4] <= Behavior[5] then
            Behavior.Completed = true;
        end

    elseif Behavior[1] == Objectives.Tribute then
        if Behavior[4] == nil then
            local Text = QuestSystem:ReplacePlaceholders(Behavior[3]);
            QuestSystem.UniqueTributeID = QuestSystem.UniqueTributeID +1;
            Logic.AddTribute(self.m_Receiver, QuestSystem.UniqueTributeID, 0, 0, Text, unpack(Behavior[2]));
            Behavior[4] = QuestSystem.UniqueTributeID;
        end
        if Behavior[5] then
            Behavior.Completed = true;
        end

    elseif Behavior[1] == Objectives.WeatherState then
        if Logic.GetWeatherState() == Behavior[2] then
            Behavior.Completed = true;
        end

    elseif Behavior[1] == Objectives.Quest then
        local QuestID = GetQuestID(Behavior[2]);
        if QuestID == 0 then
            Behavior.Completed = false;
        else
            if QuestSystem.Quests[QuestID]:ContainsObjective(Objectives.NoChange) then
                Behavior.Completed = true;

            elseif QuestSystem.Quests[QuestID].m_State == QuestStates.Over then
                if QuestSystem.Quests[QuestID].m_Result ~= QuestResults.Undecided then
                    if Behavior[3] == nil or QuestSystem.Quests[QuestID].m_Result == Behavior[3] 
                    or QuestSystem.Quests[QuestID].m_Result == QuestResults.Interrupted then
                        Behavior.Completed = true;
                    else
                        -- failed and not required -> true
                        -- failed and required -> false
                        Behavior.Completed = not Behavior[4];
                    end
                else
                    Behavior.Completed = true;
                end
            end
        end
    elseif Behavior[1] == Objectives.Bridge then
        if not IsExisting(Behavior[2]) then
            Behavior.Completed = false;
        else
            local x, y, z = Logic.EntityGetPos(GetID(Behavior[2]));
            for i= 1, 4, 1 do
                local n, Entity = Logic.GetEntitiesInArea(Entities["PB_Bridge" ..i], x, y, Behavior[3], 1);
                if n > 0 and Logic.IsConstructionComplete(Entity) == 1 then
                    Behavior.Completed = true;
                    break;
                end
            end
        end
    end

    return Behavior.Completed;
end

---
-- Checks the trigger condition for the quest.
--
-- @param[type=number] _Index Index of behavior
-- @within QuestTemplate
-- @local
--
function QuestTemplate:IsConditionFulfilled(_Index)
    local Behavior = self.m_Conditions[_Index];

    if Behavior[1] == Conditions.NeverTriggered then

    elseif Behavior[1] == Conditions.Time then
        return Logic.GetTime() >= Behavior[2];

    elseif Behavior[1] == Conditions.Quest then
        local QuestID = GetQuestID(Behavior[2]);
        if QuestID == 0 then
            return false;
        end
        if  (Behavior[3] == nil or Behavior[3] == QuestSystem.Quests[QuestID].m_State)
        and (Behavior[4] == nil or Behavior[4] == QuestSystem.Quests[QuestID].m_Result) then
            return true;
        end

    elseif Behavior[1] == Conditions.MapScriptFunction then
        return Behavior[2][1](Behavior[2][2], self);

    elseif Behavior[1] == Conditions.Briefing then
        local Quest = QuestSystem.Quests[GetQuestID(Behavior[2])];
        if Quest and Quest.m_Briefing then
            return QuestSystem.Briefings[Quest.m_Briefing] == true;
        end

    elseif Behavior[1] == Conditions.Diplomacy then
        if Logic.GetDiplomacyState(self.m_Receiver, Behavior[2]) == Behavior[3] then
            return true;
        end

    elseif Behavior[1] == Conditions.QuestSuccess then
        local QuestID = GetQuestID(Behavior[2]);
        if QuestID == 0 then
            return false;
        end
        if QuestSystem.Quests[QuestID].m_Result == QuestResults.Success then
            return true;
        end

    elseif Behavior[1] == Conditions.QuestFailure then
        local QuestID = GetQuestID(Behavior[2]);
        if QuestID == 0 then
            return false;
        end
        if QuestSystem.Quests[QuestID].m_Result == QuestResults.Failure then
            return true;
        end

    elseif Behavior[1] == Conditions.QuestInterrupt then
        local QuestID = GetQuestID(Behavior[2]);
        if QuestID == 0 then
            return false;
        end
        if QuestSystem.Quests[QuestID].m_Result == QuestResults.Interrupted then
            return true;
        end

    elseif Behavior[1] == Conditions.QuestActive then
        local QuestID = GetQuestID(Behavior[2]);
        if QuestID == 0 then
            return false;
        end
        if QuestSystem.Quests[QuestID].m_State == QuestStates.Active then
            return true;
        end

    elseif Behavior[1] == Conditions.QuestOver then
        local QuestID = GetQuestID(Behavior[2]);
        if QuestID == 0 then
            return false;
        end
        if QuestSystem.Quests[QuestID].m_State == QuestStates.Over then
            return true;
        end

    elseif Behavior[1] == Conditions.QuestNotTriggered then
        local QuestID = GetQuestID(Behavior[2]);
        if QuestID == 0 then
            return false;
        end
        if QuestSystem.Quests[QuestID].m_State == QuestStates.Inactive then
            return true;
        end

    elseif Behavior[1] == Conditions.Payday then
        return Behavior[2] == true;

    elseif Behavior[1] == Conditions.EntityDestroyed then
        return IsExisting(Behavior[2]) == false;

    elseif Behavior[1] == Conditions.WeatherState then
        return Logic.GetWeatherState() == Behavior[2];

    elseif Behavior[1] == Conditions.QuestOrQuest then
        local QuestID1 = GetQuestID(Behavior[2]);
        local QuestID2 = GetQuestID(Behavior[3]);
        if QuestID1 == 0 or QuestID2 == 0 then
            return false;
        end
        local ResultQuest1 = QuestSystem.Quests[QuestID1].m_Result;
        local ResultQuest2 = QuestSystem.Quests[QuestID2].m_Result;
        return ResultQuest1 == Behavior[4] or ResultQuest2 == Behavior[4];

    elseif Behavior[1] == Conditions.QuestAndQuest then
        local QuestID1 = GetQuestID(Behavior[2]);
        local QuestID2 = GetQuestID(Behavior[3]);
        if QuestID1 == 0 or QuestID2 == 0 then
            return false;
        end
        local ResultQuest1 = QuestSystem.Quests[QuestID1].m_Result;
        local ResultQuest2 = QuestSystem.Quests[QuestID2].m_Result;
        return ResultQuest1 == Behavior[4] and ResultQuest2 == Behavior[4];

    elseif Behavior[1] == Conditions.QuestXorQuest then
        local QuestID1 = GetQuestID(Behavior[2]);
        local QuestID2 = GetQuestID(Behavior[3]);
        if QuestID1 == 0 or QuestID2 == 0 then
            return false;
        end
        local ResultQuest1 = QuestSystem.Quests[QuestID1].m_Result == Behavior[4];
        local ResultQuest2 = QuestSystem.Quests[QuestID2].m_Result == Behavior[4];
        return (ResultQuest1 and not ResultQuest2) or (not ResultQuest1 and ResultQuest2);
    end

    return false;
end

---
-- Calls the callback behavior for the quest.
--
-- @param[type=table] _Behavior Table of behavior
-- @within QuestTemplate
-- @local
--
function QuestTemplate:ApplyCallbacks(_Behavior)
    if _Behavior[1] == Callbacks.Defeat then
        if self.m_Receiver == GUI.GetPlayerID() then
            Sound.PlayFeedbackSound(Sounds.VoicesMentor_COMMENT_BadPlay_rnd_01);
        end
        Logic.PlayerSetGameStateToLost(self.m_Receiver);
        Trigger.DisableTriggerSystem(1);

    elseif _Behavior[1] == Callbacks.Victory then
        if self.m_Receiver == GUI.GetPlayerID() then
            Sound.PlayFeedbackSound(Sounds.VoicesMentor_COMMENT_GoodPlay_rnd_01);
        end
        Logic.PlayerSetGameStateToWon(self.m_Receiver);
        if XNetwork.Manager_DoesExist() == 1 then
            Trigger.DisableTriggerSystem(1);
        end

    elseif _Behavior[1] == Callbacks.MapScriptFunction then
        SaveCall{_Behavior[2][1], _Behavior[2][2], self};

    elseif _Behavior[1] == Callbacks.Briefing then
        self.m_Briefing = _Behavior[2][1](_Behavior[2][2], self);

    elseif _Behavior[1] == Callbacks.ChangePlayer then
        SaveCall{ChangePlayer, _Behavior[2], _Behavior[3]};

    elseif _Behavior[1] == Callbacks.Message then
        SaveCall{Message, QuestSystem:ReplacePlaceholders(_Behavior[2])};

    elseif _Behavior[1] == Callbacks.DestroyEntity then
        if IsExisting(_Behavior[2]) then
            local Position = GetPosition(_Behavior[2]);
            local PlayerID = GetPlayer(_Behavior[2]);
            local Orientation = Logic.GetEntityOrientation(GetID(_Behavior[2]));
            DestroyEntity(_Behavior[2]);
            local EntityID = Logic.CreateEntity(Entities.XD_ScriptEntity, Position.X, Position.Y, Orientation, PlayerID);
            Logic.SetEntityName(EntityID, _Behavior[2]);
        end

    elseif _Behavior[1] == Callbacks.DestroyEffect then
        if QuestSystem.NamedEffects[_Behavior[2]] then
            Logic.DestroyEffect(QuestSystem.NamedEffects[_Behavior[2]]);
        end

    elseif _Behavior[1] == Callbacks.CreateEntity then
        SaveCall{ReplaceEntity, _Behavior[2], _Behavior[3]};

    elseif _Behavior[1] == Callbacks.CreateGroup then
        if not IsExisting(_Behavior[2]) then
            return;
        end
        local Position = SaveCall{
            GetPosition, _Behavior[2],
            ErrorHandler = function() return {X= 100, Y= 100}; end
        };
        local PlayerID = SaveCall{
            GetPlayer, _Behavior[2],
            ErrorHandler = function() return 1; end
        };
        local Orientation = Logic.GetEntityOrientation(GetID(_Behavior[2]));
        DestroyEntity(_Behavior[2]);
        SaveCall{CreateMilitaryGroup, PlayerID, _Behavior[3], _Behavior[4], Position, _Behavior[2]};

    elseif _Behavior[1] == Callbacks.CreateEffect then
        local Position = SaveCall{
            GetPosition, _Behavior[4],
            ErrorHandler = function() return {X= 100, Y= 100}; end
        };
        local EffectID = Logic.CreateEffect(_Behavior[3], Position.X, Position.Y, 0);
        QuestSystem.NamedEffects[_Behavior[2]] = EffectID;

    elseif _Behavior[1] == Callbacks.Diplomacy then
        local Exploration = (_Behavior[4] == Diplomacy.Friendly and 1) or 0;
        Logic.SetShareExplorationWithPlayerFlag(_Behavior[2], _Behavior[3], Exploration);
		Logic.SetShareExplorationWithPlayerFlag(_Behavior[3], _Behavior[2], Exploration);
        Logic.SetDiplomacyState(_Behavior[2], _Behavior[3], _Behavior[4]);

    elseif _Behavior[1] == Callbacks.Resource then
        if _Behavior[3] > 0 then
            Logic.AddToPlayersGlobalResource(self.m_Receiver, _Behavior[2], _Behavior[3]);
        elseif _Behavior[3] < 0 then
            Logic.SubFromPlayersGlobalResource(self.m_Receiver, _Behavior[2], math.abs(_Behavior[3]));
        end

    elseif _Behavior[1] == Callbacks.RemoveQuest then
        local QuestID = GetQuestID(_Behavior[2]);
        if QuestID > 0 then
            self:RemoveQuest();
        end

    elseif _Behavior[1] == Callbacks.QuestSucceed then
        local QuestID = GetQuestID(_Behavior[2]);
        if QuestID == 0 then
            return;
        end
        if QuestSystem.Quests[QuestID].m_Result == QuestResults.Undecided and QuestSystem.Quests[QuestID].m_State == QuestStates.Active then
            QuestSystem.Quests[QuestID]:Success();
        end

    elseif _Behavior[1] == Callbacks.QuestFail then
        local QuestID = GetQuestID(_Behavior[2]);
        if QuestID == 0 then
            return;
        end
        if QuestSystem.Quests[QuestID].m_Result == QuestResults.Undecided and QuestSystem.Quests[QuestID].m_State == QuestStates.Active then
            QuestSystem.Quests[QuestID]:Fail();
        end

    elseif _Behavior[1] == Callbacks.QuestInterrupt then
        local QuestID = GetQuestID(_Behavior[2]);
        if QuestID == 0 or QuestSystem.Quests[QuestID].m_Result == QuestResults.Over then
            return;
        end
        QuestSystem.Quests[QuestID]:Interrupt();

    elseif _Behavior[1] == Callbacks.QuestActivate then
        local QuestID = GetQuestID(_Behavior[2]);
        if QuestID == 0 or QuestSystem.Quests[QuestID].m_State ~= QuestStates.Inactive then
            return;
        end
        QuestSystem.Quests[QuestID]:Trigger();

    elseif _Behavior[1] == Callbacks.QuestRestart then
        local QuestID = GetQuestID(_Behavior[2]);
        if QuestID == 0 then
            return;
        end
        if QuestSystem.Quests[QuestID].m_State == QuestStates.Over then
            QuestSystem.Quests[QuestID].m_State = QuestStates.Inactive;
            QuestSystem.Quests[QuestID].m_Result = QuestResults.Undecided;
            QuestSystem.Quests[QuestID]:Reset();
            Trigger.RequestTrigger(Events.LOGIC_EVENT_EVERY_SECOND, "", QuestSystem.QuestLoop, 1, {}, {QuestSystem.Quests[QuestID].m_QuestID});
        end

    elseif _Behavior[1] == Callbacks.Technology then
        Logic.SetTechnologyState(self.m_Receiver, _Behavior[2], _Behavior[3]);

    elseif _Behavior[1] == Callbacks.CreateMarker then
        if self.m_Receiver == GUI.GetPlayerID() then
            if _Behavior[2] == MarkerTypes.StaticFriendly then
                GUI.CreateMinimapMarker(_Behavior[3].X, _Behavior[3].Y, 0);
            elseif _Behavior[2] == MarkerTypes.StaticNeutral then
                GUI.CreateMinimapMarker(_Behavior[3].X, _Behavior[3].Y, 2);
            elseif _Behavior[2] == MarkerTypes.StaticEnemy then
                GUI.CreateMinimapMarker(_Behavior[3].X, _Behavior[3].Y, 6);
            elseif _Behavior[2] == MarkerTypes.PulseFriendly then
                GUI.CreateMinimapPulse(_Behavior[3].X, _Behavior[3].Y, 0);
            elseif _Behavior[2] == MarkerTypes.PulseNeutral then
                GUI.CreateMinimapPulse(_Behavior[3].X, _Behavior[3].Y, 2);
            else
                GUI.CreateMinimapPulse(_Behavior[3].X, _Behavior[3].Y, 6);
            end
        end

    elseif _Behavior[1] == Callbacks.DestroyMarker then
        if self.m_Receiver == GUI.GetPlayerID() then
            if _Behavior[2] then
                GUI.DestroyMinimapPulse(_Behavior[2].X, _Behavior[2].Y);
            end
        end

    elseif _Behavior[1] == Callbacks.RevealArea then
        if QuestSystem.NamedExplorations[_Behavior[2]] then
            DestroyEntity(QuestSystem.NamedExplorations[_Behavior[2]]);
        end
        local Position = SaveCall{
            GetPosition, _Behavior[2],
            ErrorHandler = function() return {X= 100, Y= 100}; end
        };
        local ViewCenter = Logic.CreateEntity(Entities.XD_ScriptEntity, Position.X, Position.Y, 0, self.m_Receiver);
        Logic.SetEntityExplorationRange(ViewCenter, _Behavior[3]/100);
        QuestSystem.NamedExplorations[_Behavior[2]] = ViewCenter;

    elseif _Behavior[1] == Callbacks.ConcealArea then
        if QuestSystem.NamedExplorations[_Behavior[2]] then
            DestroyEntity(QuestSystem.NamedExplorations[_Behavior[2]]);
        end

    elseif _Behavior[1] == Callbacks.Move then
        Move(_Behavior[2], _Behavior[3]);
    end
end

---
-- Calls :Reset first and then triggers the quest.
-- @within QuestTemplate
-- @local
--
function QuestTemplate:Trigger()
    self:verbose("DEBUG: Trigger quest '" ..self.m_QuestName.. "'");
    self:Reset();

    -- Add quest
    if self.m_Description then
        if not self.m_Description.Position then
            self:CreateQuest();
        else
            self:CreateQuestEx();
        end
    end

    self.m_State = QuestStates.Active;
    self.m_Result = QuestResults.Undecided;
    self.m_StartTime = Logic.GetTime();
    self:ShowQuestMarkers();
    self:PushFragment();
    self:PullFragments();

    if GameCallback_OnQuestStatusChanged then
        GameCallback_OnQuestStatusChanged(self.m_QuestID, self.m_State, self.m_Result);
    end
end

---
-- Let the quest end successfully.
-- @within QuestTemplate
-- @local
--
function QuestTemplate:Success()
    self:verbose("DEBUG: Succeed quest '" ..self.m_QuestName.. "'");
    self:Reset(true);

    self.m_State = QuestStates.Over;
    self.m_Result = QuestResults.Success;
    self.m_FinishTime = Logic.GetTime();
    self.m_Briefing = nil;
    self:RemoveQuestMarkers();

    if self.m_Description then
        self:QuestSetSuccessfull();
    end
    self:PushFragment();
    self:PullFragments();

    if GameCallback_OnQuestStatusChanged then
        GameCallback_OnQuestStatusChanged(self.m_QuestID, self.m_State, self.m_Result);
    end
end

---
-- Let the quest end in failure.
-- @within QuestTemplate
-- @local
--
function QuestTemplate:Fail()
    self:verbose("DEBUG: Fail quest '" ..self.m_QuestName.. "'");
    self:Reset(true);

    self.m_State = QuestStates.Over;
    self.m_Result = QuestResults.Failure;
    self.m_FinishTime = Logic.GetTime();
    self.m_Briefing = nil;
    self:RemoveQuestMarkers();

    if self.m_Description then
        self:QuestSetFailed();
    end
    self:PushFragment();
    self:PullFragments();

    if GameCallback_OnQuestStatusChanged then
        GameCallback_OnQuestStatusChanged(self.m_QuestID, self.m_State, self.m_Result);
    end
end

---
-- Interrupts the quest.
-- @within QuestTemplate
-- @local
--
function QuestTemplate:Interrupt()
    self:verbose("DEBUG: Interrupt quest '" ..self.m_QuestName.. "'");
    self:Reset();

    self.m_State = QuestStates.Over;
    self.m_Result = QuestResults.Interrupted;
    self.m_FinishTime = Logic.GetTime();
    self.m_Briefing = nil;
    self:RemoveQuestMarkers();
    self:PushFragment();
    self:PullFragments();

    if GameCallback_OnQuestStatusChanged then
        GameCallback_OnQuestStatusChanged(self.m_QuestID, self.m_State, self.m_Result);
    end
end

---
-- Resets the quest. If there is a Reset method in a custom behavior this
-- method will be called.
-- @param[type=boolean] _VanillaSpareDescription Do not delete description
-- @within QuestTemplate
-- @local
--
function QuestTemplate:Reset(_VanillaSpareDescription)
    -- Remove quest
    if self.m_Description and not _VanillaSpareDescription then
        self:RemoveQuest();
    end

    -- Reset finish time
    self.m_FinishTime = nil;

    -- Reset quest briefing
    self.m_Briefing = nil;

    -- Reset objectives
    for i= 1, table.getn(self.m_Objectives), 1 do
        self.m_Objectives[i].Completed = nil;
        if self.m_Objectives[i][1] == Objectives.MapScriptFunction then
            if self.m_Objectives[i][2][2].Reset then
                self.m_Objectives[i][2][2]:Reset(self);
            end

        elseif self.m_Objectives[i][1] == Objectives.DestroyType or self.m_Objectives[i][1] == Objectives.DestroyCategory then
            self.m_Objectives[i][5] = 0;

        elseif self.m_Objectives[i][1] == Objectives.Tribute then
            if self.m_Objectives[i][4] then
                Logic.RemoveTribute(self.m_Receiver, self.m_Objectives[i][4]);
            end
            self.m_Objectives[i][5] = nil;
        end
    end

    -- Reset conditions
    for i= 1, table.getn(self.m_Conditions), 1 do
        if self.m_Conditions[i][1] == Conditions.MapScriptFunction then
            if self.m_Conditions[i][2][2].Reset then
                self.m_Conditions[i][2][2]:Reset(self);
            end

        elseif self.m_Conditions[i][1] == Conditions.Payday then
            self.m_Conditions[i][2] = nil;
        end
    end

    -- Reset callbacks
    for i= 1, table.getn(self.m_Rewards), 1 do
        if self.m_Rewards[i][1] == Callbacks.MapScriptFunction then
            if self.m_Rewards[i][2][2].Reset then
                self.m_Rewards[i][2][2]:Reset(self);
            end
        end
    end
    for i= 1, table.getn(self.m_Reprisals), 1 do
        if self.m_Reprisals[i][1] == Callbacks.MapScriptFunction then
            if self.m_Reprisals[i][2][2].Reset then
                self.m_Reprisals[i][2][2]:Reset(self);
            end
        end
    end
end

-- -------------------------------------------------------------------------- --

---
-- When the state of the quest changes trigger the :PullFragments method of
-- all master quests to make them update their description.
-- @within QuestTemplate
-- @local
--
function QuestTemplate:PushFragment()
    if self.m_Description and self.m_Description.Type == FRAGMENTQUEST_OPEN then
        for k, v in pairs(QuestSystem.Quests) do
            if v and v.m_Description and v.m_Description.Type ~= FRAGMENTQUEST_OPEN then
                for i= 1, table.getn(v.m_Objectives), 1 do
                    if v.m_Objectives[i][1] == Objectives.Quest and GetQuestID(v.m_Objectives[i][2]) == self.m_QuestID then
                        v:PullFragments();
                    end
                end
            end
        end
    end
end

---
-- Pulls the descriptions of all fragments attached to the quest.
-- @within QuestTemplate
-- @local
--
function QuestTemplate:PullFragments()
    if self.m_Description and (self.m_Description.Type == SUBQUEST_OPEN or self.m_Description.Type == MAINQUEST_OPEN) then
        self.m_Fragments = {{}, {}, 0};
        for i= 1, table.getn(self.m_Objectives), 1 do
            self:UpdateFragment(i);
        end
        self:AttachFragments();
    end
end

---
-- Returns true, if the quest contains at least 1 objective of the type.
-- @param[type=number] _Objective Type of objective
-- @within QuestTemplate
-- @local
--
function QuestTemplate:ContainsObjective(_Objective)
    for i= 1, table.getn(self.m_Objectives), 1 do
        self.m_Objectives[i].Completed = nil;
        if self.m_Objectives[i][1] == _Objective then
            return true;
        end
    end
    return false;
end

---
-- Updates the fragment connected to the objective.
-- @param[type=number] _Objective Index of objective
-- @within QuestTemplate
-- @local
--
function QuestTemplate:UpdateFragment(_Objective)
    local Jornal, ID = QuestSystem:GetJornalByQuestID(self.m_QuestID);
    if Jornal == nil then
        return;
    end

    local Running = false;
    local Fragment = "";
    local Objective = self.m_Objectives[_Objective];
    if Objective and Objective[1] == Objectives.Quest then
        local FragmentQuest = QuestSystem.Quests[GetQuestID(Objective[2])];
        if FragmentQuest and FragmentQuest.m_Description and FragmentQuest.m_Description.Type == FRAGMENTQUEST_OPEN then
            -- As long as the master is running show the fragments colored
            if self.m_State == QuestStates.Active then
                if FragmentQuest.m_State == QuestStates.Active then
                    Running = true;
                    self.m_Fragments[3] = self.m_Fragments[3] +1;
                    Fragment = Fragment .. string.format(
                        "{white}{cr}%d) %s{cr}%s{cr}{white}",
                        self.m_Fragments[3],
                        FragmentQuest.m_Description.Title,
                        FragmentQuest.m_Description.Text
                    );
                elseif FragmentQuest.m_State == QuestStates.Over then
                    self.m_Fragments[3] = self.m_Fragments[3] +1;
                    local Color = "{grey}";
                    if FragmentQuest.m_Result == QuestResults.Success then
                        Color = "{green}";
                    elseif FragmentQuest.m_Result == QuestResults.Failure then
                        Color = "{red}";
                    end
                    Fragment = Fragment .. string.format(
                        Color.. "{cr}%d) %s{white}",
                        self.m_Fragments[3],
                        FragmentQuest.m_Description.Title
                    );
                end
            -- If the master is finished show all framgents greyed out
            else
                self.m_Fragments[3] = self.m_Fragments[3] +1;
                Fragment = Fragment .. string.format(
                    "{grey}{cr}%d) %s{white}",
                    self.m_Fragments[3],
                    FragmentQuest.m_Description.Title
                );
            end
        end
    end

    if Fragment ~= "" then
        Fragment = QuestSystem:ReplacePlaceholders(Fragment);
        if Running then
            table.insert(self.m_Fragments[1], Fragment);
        else
            table.insert(self.m_Fragments[2], Fragment);
        end
    end
end

---
-- Updates the fragments in the quest description.
--
-- <b>Hint</b>: Currently extra 3 will not be supported.
--
-- @within QuestTemplate
-- @local
--
function QuestTemplate:AttachFragments()
    local Jornal, ID = QuestSystem:GetJornalByQuestID(self.m_QuestID);
    if Jornal == nil or ID == nil then
        return;
    end

    if table.getn(self.m_Fragments[1]) == 0 and table.getn(self.m_Fragments[2]) == 0 then
        return;
    end

    local NewQuestText = Jornal[5] .. " @cr ";
    for i= 1, table.getn(self.m_Fragments[1]), 1 do
        NewQuestText = NewQuestText .. self.m_Fragments[1][i];
    end
    for i= 1, table.getn(self.m_Fragments[2]), 1 do
        NewQuestText = NewQuestText .. self.m_Fragments[2][i];
    end
    
    if QuestSystem:GetExtensionNumber() > 2 then
        -- TODO: implement for ISAM!
        if self.m_Description.Type == MAINQUEST_OPEN or self.m_Description.Type == SUBQUEST_OPEN then

        end
    else
        if self.m_State ~= QuestStates.Inactive then
            if self.m_Description.Type == MAINQUEST_OPEN or self.m_Description.Type == SUBQUEST_OPEN then
                Logic.RemoveQuest(self.m_Receiver, ID);

                local Language = (XNetworkUbiCom.Tool_GetCurrentLanguageShortName() == "de" and "de") or "en";
                local ResultText = "";
                local ResultType = Jornal[3] + ((self.m_State == QuestStates.Over and 1) or 0);
                NewQuestText = QuestSystem:ReplacePlaceholders(
                    ((self.m_State == QuestStates.Over and "{grey}") or "") ..NewQuestText
                );

                if self.m_Result == QuestResults.Failure then
                    ResultText = "{red}" ..((Language == "de" and "GESCHEITERT: ") or "FAILED: ").. "{white}";
                elseif self.m_Result == QuestResults.Success then
                    ResultText = "{green}" ..((Language == "de" and "ERFOLGREICH: ") or "SUCCESSFUL: ").. "{white}";
                end
                ResultText = QuestSystem:ReplacePlaceholders(ResultText);

                if self.m_Description.X ~= nil then
                    Logic.AddQuestEx(Jornal[2], ID, ResultType, ResultText.. Jornal[4], NewQuestText, Jornal[7], Jornal[8], 0);
                else
                    Logic.AddQuest(Jornal[2], ID, ResultType, ResultText.. Jornal[4], NewQuestText, 0);
                end
            end
        end
    end
end

---
-- Creates a normal quest in the quest book.
-- @within QuestTemplate
-- @local
--
function QuestTemplate:CreateQuest()
    if self.m_Description then
        if self.m_Description.Type ~= FRAGMENTQUEST_OPEN then
            local QuestID = QuestSystem:GetNextFreeJornalID(self.m_Receiver);
            if QuestID == nil then
                GUI.AddStaticNote("ERROR: Too many quests in jornal!");
                return;
            end

            local Title = self.m_Description.Title;
            local Text  = self.m_Description.Text;

            if QuestSystem:GetExtensionNumber() > 2 then
                mcbQuestGUI.simpleQuest.logicAddQuest(
                    self.m_Receiver, QuestID, self.m_Description.Type, Title, Text, self.m_Description.Info or 1
                );
            else
                Title = QuestSystem:ReplacePlaceholders(self.m_Description.Title);
                Text  = QuestSystem:ReplacePlaceholders(self.m_Description.Text);
                Logic.AddQuest(
                    self.m_Receiver, QuestID, self.m_Description.Type, Title, Text, self.m_Description.Info or 1
                );
            end
            
            QuestSystem:RegisterQuestAtJornalID(
                QuestID,
                {self.m_QuestID, self.m_Receiver, self.m_Description.Type, Title, Text, 
                 self.m_Description.Info or 1, self.m_Description.X, self.m_Description.Y}
            );
        end
    end
end

---
-- Creates a quest with an attached position in the quest book.
-- @within QuestTemplate
-- @local
--
function QuestTemplate:CreateQuestEx()
    if self.m_Description and self.m_Description.Position then
        if self.m_Description.Type ~= FRAGMENTQUEST_OPEN then
            local QuestID = QuestSystem:GetNextFreeJornalID(self.m_Receiver);
            if QuestID == nil then
                GUI.AddStaticNote("ERROR: Only 8 entries in quest book allowed!");
                return;
            end

            local Title = self.m_Description.Title;
            local Text  = self.m_Description.Text;

            if QuestSystem:GetExtensionNumber() > 2 then
                mcbQuestGUI.simpleQuest.logicAddQuestEx(
                    self.m_Receiver, QuestID, self.m_Description.Type, Title, Text, self.m_Description.X, 
                    self.m_Description.Y, self.m_Description.Info or 1
                );
            else
                Title = QuestSystem:ReplacePlaceholders(self.m_Description.Title);
                Text  = QuestSystem:ReplacePlaceholders(self.m_Description.Text);
                Logic.AddQuestEx(
                    self.m_Receiver, QuestID, self.m_Description.Type, Title, Text, self.m_Description.X, 
                    self.m_Description.Y, self.m_Description.Info or 1
                );
            end

            QuestSystem:RegisterQuestAtJornalID(
                QuestID,
                {self.m_QuestID, self.m_Receiver, self.m_Description.Type, Title, Text, 
                 self.m_Description.Info or 1, self.m_Description.X, self.m_Description.Y}
            );
        end
    end
end

---
-- Marks the quest as failed in the quest book. In vanilla game the quest
-- is just removed.
-- @within QuestTemplate
-- @local
--
function QuestTemplate:QuestSetFailed()
    if self.m_Description and self.m_Description.Type ~= FRAGMENTQUEST_OPEN then
        local Jornal, ID = QuestSystem:GetJornalByQuestID(self.m_QuestID);
        if Jornal then
            if QuestSystem:GetExtensionNumber() > 2 then
                mcbQuestGUI.simpleQuest.logicSetQuestType(self.m_Receiver, ID, Jornal[3] +1, Jornal[6]);
            else
                Logic.RemoveQuest(self.m_Receiver, ID);

                local Language = (XNetworkUbiCom.Tool_GetCurrentLanguageShortName() == "de" and "de") or "en";
                local ResultText = QuestSystem:ReplacePlaceholders(
                    "{red}" ..((Language == "de" and "GESCHEITERT: ") or "FAILED: ").. "{white}"
                );

                if Jornal[7] == nil then
                    Logic.AddQuest(Jornal[2], ID, Jornal[3] +1, ResultText.. Jornal[4], Jornal[5], Jornal[6]);
                else
                    Logic.AddQuestEx(Jornal[2], ID, Jornal[3] +1, ResultText.. Jornal[4], Jornal[5], Jornal[7], Jornal[8], Jornal[6]);
                end
            end
        end
    end
end

---
-- Marks the quest as successfull in the quest book.
-- @within QuestTemplate
-- @local
--
function QuestTemplate:QuestSetSuccessfull()
    if self.m_Description and self.m_Description.Type ~= FRAGMENTQUEST_OPEN then
        local Jornal, ID = QuestSystem:GetJornalByQuestID(self.m_QuestID);
        if Jornal then
            if QuestSystem:GetExtensionNumber() > 2 then
                mcbQuestGUI.simpleQuest.logicSetQuestType(self.m_Receiver, ID, Jornal[3] +1, Jornal[6]);
            else
                Logic.RemoveQuest(self.m_Receiver, ID);

                local Language = (XNetworkUbiCom.Tool_GetCurrentLanguageShortName() == "de" and "de") or "en";
                local ResultText = QuestSystem:ReplacePlaceholders(
                    "{green}" ..((Language == "de" and "ERFOLGREICH: ") or "SUCCESSFUL: ").. "{white}"
                );

                if Jornal[7] == nil then
                    Logic.AddQuest(Jornal[2], ID, Jornal[3] +1, ResultText.. Jornal[4], Jornal[5], Jornal[6]);
                else
                    Logic.AddQuestEx(Jornal[2], ID, Jornal[3] +1, ResultText.. Jornal[4], Jornal[5], Jornal[7], Jornal[8], Jornal[6]);
                end
            end
        end
    end
end

---
-- Removes a Quest from the quest book.
-- @within QuestTemplate
-- @local
--
function QuestTemplate:RemoveQuest()
    if self.m_Description and self.m_Description.Type ~= FRAGMENTQUEST_OPEN then
        local Jornal, ID = QuestSystem:GetJornalByQuestID(self.m_QuestID);
        if Jornal then
            if QuestSystem:GetExtensionNumber() > 2 then
                mcbQuestGUI.simpleQuest.logicRemoveQuest(self.m_Receiver, ID);
            else
                Logic.RemoveQuest(self.m_Receiver, ID);
                QuestSystem:InvalidateQuestAtJornalID(self.m_Receiver, ID);
            end
        end
    end
end

-- -------------------------------------------------------------------------- --

---
-- Displays all quest markers of the behaviors.
-- @within QuestTemplate
-- @local
--
function QuestTemplate:ShowQuestMarkers()
    self:verbose("DEBUG: Show Markers of quest '" ..self.m_QuestName.. "'");

    for i= 1, table.getn(self.m_Objectives), 1 do
        if self.m_State == QuestStates.Active then
            if self.m_Objectives[i][1] == Objectives.Create then
                if self.m_Objectives[i][6] then
                    local Position = (type(self.m_Objectives[i][3]) == "table" and self.m_Objectives[i][3]) or GetPosition(self.m_Objectives[i][3]);
                    self.m_Objectives[i][8] = Logic.CreateEffect(GGL_Effects.FXTerrainPointer, Position.X, Position.Y, 1);
                end
            end
        end
    end
end

---
-- Removes all quest markers of the behaviors.
-- @within QuestTemplate
-- @local
--
function QuestTemplate:RemoveQuestMarkers()
    self:verbose("DEBUG: Hide Markers of quest '" ..self.m_QuestName.. "'");

    for i= 1, table.getn(self.m_Objectives), 1 do
        if self.m_State == QuestStates.Over then
            if self.m_Objectives[i][1] == Objectives.Create then
                if self.m_Objectives[i][8] then
                    Logic.DestroyEffect(self.m_Objectives[i][8]);
                end
            end
        end
    end
end

-- -------------------------------------------------------------------------- --

---
-- Handels the event when a player is destroying an entity.
--
-- @param[type=number] _AttackingPlayer Player id of attacker
-- @param[type=number] _AttackingID     Entity id of attacker
-- @param[type=number] _DefendingPlayer Player id of defender
-- @param[type=number] _DefendingID     Entity of defender
-- @within QuestSystem
-- @local
--
function QuestSystem:ObjectiveDestroyedEntitiesHandler(_AttackingPlayer, _AttackingID, _DefendingPlayer, _DefendingID)
    for i= 1, table.getn(self.Quests), 1 do
        local Quest = self.Quests[i];
        if Quest.m_State == QuestStates.Active and Quest.m_Result == QuestResults.Undecided then
            for j= 1, table.getn(Quest.m_Objectives), 1 do
                -- Destroy type
                if Quest.m_Objectives[j][1] == Objectives.DestroyType then
                    Quest.m_Objectives[j][5] = Quest.m_Objectives[j][5] or 0;
                    if Quest.m_Receiver == _AttackingPlayer and (Quest.m_Objectives[j][2] == -1 or _DefendingPlayer == Quest.m_Objectives[j][2]) then
                        if Logic.GetEntityType(_DefendingID) == Quest.m_Objectives[j][3] then
                            Quest.m_Objectives[j][5] = Quest.m_Objectives[j][5] + 1;
                        end
                    end
                -- Destroy category
                elseif Quest.m_Objectives[j][1] == Objectives.DestroyCategory then
                    Quest.m_Objectives[j][5] = Quest.m_Objectives[j][5] or 0;
                    if Quest.m_Receiver == _AttackingPlayer and (Quest.m_Objectives[j][2] == -1 or _DefendingPlayer == Quest.m_Objectives[j][2]) then
                        if Logic.IsEntityInCategory(_DefendingID, Quest.m_Objectives[j][3]) == 1 then
                            Quest.m_Objectives[j][5] = Quest.m_Objectives[j][5] + 1;
                        end
                    end
                end
            end
        end
    end
end

---
-- Handels the event when a player has paid a tribute.
--
-- @param[type=number] _TributeID ID of Tribute
-- @within QuestSystem
-- @local
--
function QuestSystem:QuestTributePayed(_TributeID)
    for i= 1, table.getn(self.Quests), 1 do
        local Quest = self.Quests[i];
        if Quest.m_State == QuestStates.Active and Quest.m_Result == QuestResults.Undecided then
            for j= 1, table.getn(Quest.m_Objectives), 1 do
                if Quest.m_Objectives[j][1] == Objectives.Tribute then
                    if _TributeID == Quest.m_Objectives[j][4] then
                        if Quest.m_Receiver == GUI.GetPlayerID() then
                            Sound.PlayGUISound(Sounds.OnKlick_Select_helias, 127);
                        end
                        Quest.m_Objectives[j][5] = true;
                    end
                end
            end
        end
    end
end

---
-- Handles the payday event for all quests.
--
-- @param[type=number] _PlayerID ID of player
-- @within QuestSystem
-- @local
--
function QuestSystem:QuestPaydayEvent(_PlayerID)
    for i= 1, table.getn(self.Quests), 1 do
        local Quest = self.Quests[i];
        if Quest.m_Receiver == _PlayerID and Quest.m_State == QuestStates.Inactive then
            for j= 1, table.getn(Quest.m_Conditions), 1 do
                if Quest.m_Conditions[j][1] == Conditions.Payday then
                    Quest.m_Conditions[j][2] = true;
                end
            end
        end
    end
end

---
-- Creates a new inline job.
--
-- If a table is passed as one of the arguments then a copy will be created.
-- It will not be a reference because of saving issues.
--
-- @param[type=number]   _EventType Event type
-- @param[type=function] _Function Lua function reference
-- @param ...            Optional arguments
-- @return[type=number] ID of started job
-- @within QuestSystem
-- @local
--
function QuestSystem:StartInlineJob(_EventType, _Function, ...)
    -- Who needs a trigger fix. :D
    self.InlineJobs.Counter = self.InlineJobs.Counter +1;
    _G["QuestSystem_InlineJob_Data_" ..self.InlineJobs.Counter] = copy(arg);
    _G["QuestSystem_InlineJob_Function_" ..self.InlineJobs.Counter] = _Function;
    _G["QuestSystem_InlineJob_Executor_" ..self.InlineJobs.Counter] = function(i)
        if _G["QuestSystem_InlineJob_Function_" ..i](unpack(_G["QuestSystem_InlineJob_Data_" ..i])) then
            return true;
        end
    end
    return Trigger.RequestTrigger(_EventType, "", "QuestSystem_InlineJob_Executor_" ..self.InlineJobs.Counter, 1, {}, {self.InlineJobs.Counter});
end

---
-- Raplaces the placeholders in the message with their values.
--
-- @param[type=string] _Message Text to parse
-- @return[type=string] New text
-- @within QuestSystem
-- @local
--
function QuestSystem:ReplacePlaceholders(_Message)
    if type(_Message) == "table" then
        for k, v in pairs(_Message) do
            _Message[k] = self:ReplacePlaceholders(v);
        end

    elseif type(_Message) == "string" then
        -- Replace hero and npc names
        local HeroName = QuestSystem.NamedEntityNames[gvLastInteractionHeroName] or "HERO_NAME_NOT_FOUND";
        local NpcName = QuestSystem.NamedEntityNames[gvLastInteractionNpcName] or "NPC_NAME_NOT_FOUND";
        _Message = string.gsub(_Message, "{hero}", HeroName);
        _Message = string.gsub(_Message, "{npc}", NpcName);

        -- Replace valued placeholders
        _Message = self:ReplaceKeyValuePlaceholders(_Message);
        
        -- Replace basic placeholders last        
        _Message = string.gsub(_Message, "{cr}", " @cr ");
        _Message = string.gsub(_Message, "{nl}", " @cr ");
        _Message = string.gsub(_Message, "{ra}", " @ra ");
        _Message = string.gsub(_Message, "{qq}", "\"");
        _Message = string.gsub(_Message, "{center}", " @center ");
        _Message = string.gsub(_Message, "{red}", " @color:180,0,0 ");
        _Message = string.gsub(_Message, "{green}", " @color:0,180,0 ");
        _Message = string.gsub(_Message, "{blue}", " @color:0,0,180 ");
        _Message = string.gsub(_Message, "{yellow}", " @color:235,235,0 ");
        _Message = string.gsub(_Message, "{violet}", " @color:180,0,180 ");
        _Message = string.gsub(_Message, "{azure}", " @color:0,180,180 ");
        _Message = string.gsub(_Message, "{black}", " @color:40,40,40 ");
        _Message = string.gsub(_Message, "{white}", " @color:255,255,255 ");
        _Message = string.gsub(_Message, "{grey}", " @color:180,180,180 ");
    end
    return _Message;
end

---
-- Replaces all valued placeholders in the message with their value.
--
-- @param[type=string] _Message Text to parse
-- @return[type=string] New text
-- @within QuestSystem
-- @local
--
function QuestSystem:ReplaceKeyValuePlaceholders(_Message)
    local s, e = string.find(_Message, "{", 1);
    while (s) do
        local ss, ee      = string.find(_Message, "}", e+1);
        local Before      = (s <= 1 and "") or string.sub(_Message, 1, s-1);
        local After       = (ee and string.sub(_Message, ee+1)) or "";
        local Placeholder = string.sub(_Message, e+1, ss-1);

        if string.find(Placeholder, "color") then
            _Message = Before .. " @" .. Placeholder .. " " .. After;
        end
        if string.find(Placeholder, "val:") then
            local Value = _G[string.sub(Placeholder, string.find(Placeholder, ":")+1)];
            if type(Value) == "string" or type(value) == "number" then
                _Message = Before .. Value .. After;
            end
        end
        if string.find(Placeholder, "cval:") then
            local Value = _G[string.sub(Placeholder, string.find(Placeholder, ":")+1)];
            if Value and QuestSystem.CustomVariables[Value] then
                _Message = Before .. QuestSystem.CustomVariables[Value] .. After;
            end
        end
        if string.find(Placeholder, "name:") then
            local Value = string.sub(Placeholder, string.find(Placeholder, ":")+1);
            if Value and QuestSystem.NamedEntityNames[Value] then
                _Message = Before .. QuestSystem.NamedEntityNames[Value] .. After;
            end
        end
        s, e = string.find(_Message, "{", ee+1);
    end
    return _Message;
end

---
-- Removes all formating placeholders from the message.
--
-- @param[type=string] _Message Text to parse
-- @return[type=string] New text
-- @within QuestSystem
-- @local
--
function QuestSystem:RemoveFormattingPlaceholders(_Message)
    if type(_Message) == "table" then
        for k, v in pairs(_Message) do
            _Message[k] = self:RemoveFormattingPlaceholders(v);
        end
    elseif type(_Message) == "string" then
        _Message = string.gsub(_Message, "{ra}", "");
        _Message = string.gsub(_Message, "{center}", "");
        _Message = string.gsub(_Message, "{color:%d,%d,%d}", "");
        _Message = string.gsub(_Message, "{red}", "");
        _Message = string.gsub(_Message, "{green}", "");
        _Message = string.gsub(_Message, "{blue}", "");
        _Message = string.gsub(_Message, "{yellow}", "");
        _Message = string.gsub(_Message, "{violet}", "");
        _Message = string.gsub(_Message, "{azure}", "");
        _Message = string.gsub(_Message, "{black}", "");
        _Message = string.gsub(_Message, "{white}", "");
        -- _Message = string.gsub(_Message, "{grey}", "");

        _Message = string.gsub(_Message, "@color:%d,%d,%d", "");
        _Message = string.gsub(_Message, "@center", "");
        _Message = string.gsub(_Message, "@ra", "");
    end
    return _Message;
end

-- -------------------------------------------------------------------------- --

---
-- Checks worldwide for doodad entities or player entities.
--
-- Be careful: This method is using expensive area checks. Do better not use
-- it inside of jobs.
--
-- @param[type=number] _PlayerID ID of player
-- @param[type=number] _Type     Type of entity
-- @param[type=number] _AreaSize (Optional) Area size
-- @param[type=table]  _Position (Optional) Area center
-- @return[type=table] Result set
-- @within Methods
--
function FindAllEntities(_PlayerID, _Type, _AreaSize, _Position)
	local ResultSet = {};
    
    _AreaSize = _AreaSize or Logic.WorldGetSize();
    _Position = _Position or {X = _AreaSize/2, Y = _AreaSize/2};
    
    local Data;
	if _PlayerID == 0 then
		Data = {Logic.GetEntitiesInArea(_Type, _Position.X, _Position.Y, math.floor(_AreaSize * 0.71), 16)};
	else
		Data = {Logic.GetPlayerEntitiesInArea(_PlayerID, _Type, _Position.X, _Position.Y, math.floor(_AreaSize * 0.71), 16)};
    end
    
	if Data[1] >= 16 then
		local HalfAreaSize = _AreaSize / 2;
		local PositionX1 = _Position.X - _AreaSize / 4;
		local PositionX2 = _Position.X + _AreaSize / 4;
		local PositionY1 = _Position.Y - _AreaSize / 4;
		local PositionY2 = _Position.Y + _AreaSize / 4;
		local ResultSetRecursive = FindAllEntities(_PlayerID, _Type, HalfAreaSize, {X=PositionX1,Y=PositionY1});
		for i = 1, table.getn(ResultSetRecursive) do
			if not FindValue(ResultSetRecursive[i], ResultSet) then
				table.insert(ResultSet, ResultSetRecursive[i]);
			end
		end
		local ResultSetRecursive = FindAllEntities(_PlayerID, _Type, HalfAreaSize, {X=PositionX1,Y=PositionY2});
		for i = 1, table.getn(ResultSetRecursive) do
			if not FindValue(ResultSetRecursive[i], ResultSet) then
				table.insert(ResultSet, ResultSetRecursive[i]);
			end
		end
		local ResultSetRecursive = FindAllEntities(_PlayerID, _Type, HalfAreaSize, {X=PositionX2,Y=PositionY1});
		for i = 1, table.getn(ResultSetRecursive) do
			if not FindValue(ResultSetRecursive[i], ResultSet) then
				table.insert(ResultSet, ResultSetRecursive[i]);
			end
		end
		local ResultSetRecursive = FindAllEntities(_PlayerID, _Type, HalfAreaSize, {X=PositionX2,Y=PositionY2});
		for i = 1, table.getn(ResultSetRecursive) do
			if not FindValue(ResultSetRecursive[i], ResultSet) then
				table.insert(ResultSet, ResultSetRecursive[i]);
			end
		end
	else
		table.remove(Data, 1);
		for i = 1, table.getn(Data) do
			if not FindValue(Data[i], ResultSet) then
				table.insert(ResultSet, Data[i]);
			end
		end
	end
	return ResultSet
end

---
-- Checks if a value is inside a table.
--
-- @param             _Value Value to find
-- @param[type=table] _Table Table to search
-- @return[type=boolean] Value found
-- @within Methods
--
function FindValue(_Value, _Table)
	for k,v in pairs(_Table)do
		if v == _Value then
			return true;
		end
	end
	return false;
end
IstDrin = FindValue;

---
-- Checks the area for entities of an enemy player.
--
-- @param[type=number] _player   Player ID
-- @param[type=table]  _position Area center
-- @param[type=number] _range    Area size
-- @return[type=boolean] Enemies near
-- @within Methods
--
function AreEnemiesInArea( _player, _position, _range)
    return AreEntitiesOfDiplomacyStateInArea(_player, _position, _range, Diplomacy.Hostile);
end

---
-- Checks the area for entities of an allied player.
--
-- @param[type=number] _player   Player ID
-- @param[type=table]  _position Area center
-- @param[type=number] _range    Area size
-- @return[type=boolean] Allies near
-- @within Methods
--
function AreAlliesInArea( _player, _position, _range)
    return AreEntitiesOfDiplomacyStateInArea(_player, _position, _range, Diplomacy.Friendly);
end

---
-- Checks the area for entities of other parties with a diplomatic state to
-- the player.
--
-- The first 16 player entities in the area will be evaluated. If they're not
-- settler, heroes or buldings, they will be ignored.
--
-- @param[type=number] _player   Player ID
-- @param[type=table]  _position Area center
-- @param[type=number] _range    Area size
-- @param[type=number] _state    Diplomatic state
-- @return[type=boolean] Entities near
-- @within Methods
--
function AreEntitiesOfDiplomacyStateInArea(_player, _position, _range, _state)
	for i = 1,8 do
        if Logic.GetDiplomacyState(_player, i) == _state then
            local Data = {Logic.GetPlayerEntitiesInArea(i, 0, _position.X, _position.Y, _range, 16)};
            table.remove(Data, 1);
            for j= table.getn(Data), 1, -1 do
                if Logic.IsSettler(Data[j]) == 0 and Logic.IsBuilding(Data[j]) == 0 and Logic.IsHero(Data[j]) == 0 then
                    table.remove(Data, j);
                end
            end
            if table.getn(Data) > 0 then
				return true;
			end
		end
	end
	return false;
end

---
-- Returns the quest ID of the quest with the name.
-- If the quest is not found, 0 is returned.
--
-- @param[type=string] _QuestName Quest name
-- @return[type=number] Quest ID
-- @within Methods
--
function GetQuestID(_QuestName)
    for i= 1, table.getn(QuestSystem.Quests), 1 do
        if QuestSystem.Quests[i].m_QuestName == _QuestName or QuestSystem.Quests[i].m_QuestID == _QuestName then
            return i;
        end
    end
    return 0;
end

---
-- Returns true, if the quest is a valid (existing) quest.
-- @param[type=string] _QuestName Name of quest
-- @return[type=boolean] Valid quest
-- @within Methods
--
function IsValidQuest(_QuestName)
    return GetQuestID(_QuestName) ~= 0;
end

---
-- Returns the distance between two positions or entities.
--
-- @param _pos1 Position 1 (string, number oder table)
-- @param _pos2 Position 2 (string, number oder table)
-- @return[type=number] Distance between positions
-- @within Methods
--
function GetDistance(_pos1, _pos2)
    if (type(_pos1) == "string") or (type(_pos1) == "number") then
        _pos1 = GetPosition(_pos1);
    end
    if (type(_pos2) == "string") or (type(_pos2) == "number") then
        _pos2 = GetPosition(_pos2);
    end
	assert(type(_pos1) == "table");
	assert(type(_pos2) == "table");
    local xDistance = (_pos1.X - _pos2.X);
    local yDistance = (_pos1.Y - _pos2.Y);
    return math.sqrt((xDistance^2) + (yDistance^2));
end

---
-- Checks if an army or entity is dead. If an army has not been created yet
-- then it will not falsely assumed to be dead.
--
-- @param _input Army or entity (string, number oder table)
-- @return[type=boolean] Army or entity is dead
-- @within Methods
--
function IsDeadWrapper(_input)
    if type(_input) == "table" and not _input.created then
        _input.created = not IsDeadOrig(_input);
        return false;
    end
    return IsDeadOrig(_input);
end
IsDeadOrig = IsDead;
IsDead = IsDeadWrapper;

---
-- Checks if an army is near the position.
--
-- @param[type=table]  _Army     Army to check
-- @param              _Target   Target position
-- @param[type=number] _Distance Area size
-- @return[type=boolean] Army is near
-- @within Methods
--
function IsArmyNear(_Army, _Target, _Distance)
    local LeaderID = 0;
    if not _Distance then
        _Distance = _Army.rodeLength;
    end
    local NumberOfLeader = Logic.GetNumberOfLeader(_Army.player);
    for i = 1, NumberOfLeader do
        LeaderID = Logic.GetNextLeader(_Army.player, LeaderID);
        local ArmyID = AI.Entity_GetConnectedArmy(LeaderID);
        if ArmyID == _Army.id then
            if GetDistance(LeaderID, _Target) < _Distance then
                return true;
            end
        end
    end
    return false;
end

---
-- Checks, if the positions are in the same sector. If 2 possitions are not
-- in the same sector then they are not connected.
--
-- @param _pos1 Position 1
-- @param _pos2 Position 2
-- @return[type=boolean] Same sector
-- @within Methods
--
function SameSector(_pos1, _pos2)
	local sectorEntity1 = _pos1;
	local toVanish1;
	if type(sectorEntity1) == "table" then
		sectorEntity1 = Logic.CreateEntity(Entities.XD_ScriptEntity, _pos1.X, _pos1.Y, 0, 8);
		toVanish1 = true;
    end
    
	local sectorEntity2 = _pos2;
	local toVanish2;
	if type(sectorEntity2) == "table" then
		sectorEntity2 = Logic.CreateEntity(Entities.XD_ScriptEntity, _pos2.X, _pos2.Y, 0, 8);
		toVanish2 = true;
	end

	local eID1 = GetID(sectorEntity1);
	local eID2 = GetID(sectorEntity2);
	if (eID1 == nil or eID1 == 0) or (eID2 == nil or eID2 == 0) then
		return false;
	end

	local sector1 = Logic.GetSector(eID1)
	if toVanish1 then
		DestroyEntity(eID1);
	end
	local sector2 = Logic.GetSector(eID2)
	if toVanish2 then
		DestroyEntity(eID2);
	end
    return (sector1 ~= 0 and sector2 ~= 0 and sector1 == sector2);
end

---
-- Displays the name of any function that is to large to be loaded when a
-- savegame is loaded.
-- @param[type=table] t Table to check
-- @within Methods
-- @local
--
function CheckFunctionSize(t)
    table.foreach(t, function(k, v)
        if type(v) == "function" then
            local res, dmp = xpcall(
                function()return string.dump(v) end,
                function() end
            );
            if res and dmp then
                local size = string.len(dmp);
                if size > 16000 then
                    GUI.AddStaticNote(k .. " -> " .. size);
                    if LuaDebugger.Log then
                        LuaDebugger.Log(k .. " -> " .. size);
                    end
                end
            end
        end
        if type(v) == "table" and not tonumber(k) and v ~= _G then
            CheckFunctionSize(v);
        end
    end);
end

---
-- Calls a function in protected mode.
--
-- The function and the arguments must be passed as a table. If there is a
-- field ErrorHandler in the table, the handler will be called in case of
-- error. The error handler <i>must</i> be a function.
--
-- The error handler gets the actual error and all arguments from the original
-- call passed when executed.
--
-- SaveCall returns the return value of the function if no errors occur. If
-- something went wrong the return value of the error handler is returned. If
-- no handler is present the return value will always be nil.
--
-- <b>Note>/b>: Protected mode is <u>only</u>used when the field 
-- QuestSystem.IgnoreLuaDebugger is set to <i>true</i> or the LuaDebugger 
-- (the one coded by yoq) is absend. If non of these conditions met, simply
-- the original function will be executed.
--
-- @param[type=table] _Data Function to call (in a table)
-- @return Return value of function or of error handler
-- @within Methods
-- @local
--
--
function SaveCall(_Data)
    if type(_Data == "table" and type(_Data[1]) == "function") then
        local Function = table.remove(_Data, 1);
        if QuestSystem.IgnoreLuaDebugger or LuaDebugger.Log == nil then
            local Values = {xpcall(
                function() return Function(unpack(_Data)); end,
                function(_Error) return _Error; end
            )};
            if Values[1] == false then
                GUI.AddStaticNote("Runtime error: " ..tostring(Values[2]));
                if type(_Data.ErrorHandler) == "function" then
                    return SaveCall{_Data.ErrorHandler, Values[2], unpack(_Data)};
                end
            end
            return Values[2];
        else
            return Function(unpack(_Data));
        end
    end
end

---
-- Checks if the position table contains a valid position on the map.
--
-- @param[type=table] _pos Position to check
-- @return[type=boolean] Position valid
-- @within Methods
--
function IsValidPosition(_pos)
	if type(_pos) == "table" then
		if (_pos.X ~= nil and type(_pos.X) == "number") and (_pos.Y ~= nil and type(_pos.Y) == "number") then
			local world = {Logic.WorldGetSize()};
			if _pos.X <= world[1] and _pos.X >= 0 and _pos.Y <= world[2] and _pos.Y >= 0 then
				return true;
			end
		end
	end
	return false;
end

---
-- Returns the leader entity ID of the soldier.
--
-- FIXME: Not compatible to the History Edition!
--
-- @param[type=number] _eID Entity ID of soldier
-- @return[type=number] Entity ID of leader
-- @within Methods
--
function SoldierGetLeaderEntityID(_eID)
    if Logic.IsEntityInCategory(_eID, EntityCategories.Soldier) == 1 then
        return Logic.GetEntityScriptingValue(_eID, 69) or _eID;
    end
    return _eID;
end

---
-- Returns the script name of the entity. If the entity do not have a name a
-- unique ongoing name is added to the entity and returned
--
-- @param[type=number] _eID EntityID
-- @return[type=string] Script name
--
function GiveEntityName(_eID)
    if type(_eID) == "string" then
        return _eID;
    else
        assert(type(_eID) == "number");
        local name = Logic.GetEntityName(_eID);
        if (type(name) ~= "string" or name == "" ) then
            GiveEntityName_EntityNameCounter = (GiveEntityName_EntityNameCounter or 0)+ 1;
            name = "eName_"..GiveEntityName_EntityNameCounter;
            Logic.SetEntityName(_eID,name);
        end
        return name;
    end
end

-- -------------------------------------------------------------------------- --

-- Allows tributes... You are not documented, you are just here. ;)
function GameCallback_FulfillTribute(_PlayerID, _TributeID)
	return 1
end

-- -------------------------------------------------------------------------- --

---
-- Possible technology states for technology behavior.
-- @within Constants
--
-- @field Researched The technology has already been reearched
-- @field Allowed The technology can be researched
-- @field Forbidden The technology can not be researched
--
TechnologyStates = {
    Researched = 3,
    Allowed    = 2,
    Forbidden  = 0
}

---
-- Possible weather states for weather behavior
-- @within Constants
--
-- @field Summer Summer weather
-- @field Rain Rainy weather
-- @field Winter Snow is falling
--
WeatherStates = {
    Summer = 1,
    Rain   = 2,
    Winter = 3
}

---
-- Possible types of minimap markers and pulsars.
-- @within Constants
--
-- @field StaticFriendly Static green marker
-- @field StaticNeutral Static yellow marker
-- @field StaticEnemy Static red marker
-- @field PulseFriendly Green pulsar
-- @field PulseNeutral Yellow pulsar
-- @field PulseEnemy Red pulsar
--
MarkerTypes = {
    StaticFriendly = 1,
    StaticNeutral  = 2,
    StaticEnemy    = 3,
    PulseFriendly  = 4,
    PulseNeutral   = 5,
    PulseEnemy     = 6,
}

---
-- Possible states of an quest.
-- @within Constants
--
-- @field Inactive Quest was not triggered
-- @field Active Quest is running
-- @field Over Quest is finished
--
QuestStates = {
    Inactive = 1,
    Active   = 2,
    Over     = 3,
}

---
-- Possible results of an quest.
-- @within Constants
--
-- @field Undecided Quest result has not been decided
-- @field Success Quest was successfully completed
-- @field Failure Quest finished in failure
-- @field Interrupted Quest has been interrupted
--
QuestResults = {
    Undecided   = 1,
    Success     = 2,
    Failure     = 3,
    Interrupted = 4,
}

---
-- Condition types that triggers quests.
-- @within Constants
--
-- @field NeverTriggered
-- Quest will never be triggered.
-- <pre>{Conditions.NeverTriggered}</pre>
--
-- @field Time
-- Quest will be triggered after some time after mapstart.
-- <pre>{Conditions.Time, _Waiitime}</pre>
--
-- @field MapScriptFunction
-- Quest will be triggered when a user function returns true.
-- <pre>{Conditions.MapScriptFunction, _Function, _ArgumentList...}</pre>
--
-- @field Diplomacy
-- Starts the quest when a diplomatic state is reached.
-- <pre>{Conditions.Diplomacy, _Player, _Diplomacy}</pre>
--
-- @field Briefing
-- Starts the quest, after a briefing of another is finished.
-- <pre>{Conditions.Briefing, _QuestName}</pre>
--
-- @field QuestSuccess
-- Starts a quest when another quest is finished successfully.
-- <pre>{Conditions.QuestSuccess, _QuestName}</pre>
--
-- @field QuestFailure
-- Starts a quest when another quest has failed.
-- <pre>{Conditions.QuestFailure, _QuestName}</pre>
--
-- @field QuestInterrupt
-- Starts a quest when another quest is interrupted.
-- <pre>{Conditions.QuestInterrupt, _QuestName}</pre>
--
-- @field QuestActive
-- Starts a quest when another quest is active.
-- <pre>{Conditions.QuestActive, _QuestName}</pre>
--
-- @field QuestOver
-- Starts a quest when another quest either failed or is finished
-- sucessfully.
-- <pre>{Conditions.QuestOver, _QuestName}</pre>
--
-- @field QuestNotTriggered
-- Starts a quest when another quest has not yet been triggered.
-- <pre>{Conditions.QuestNotTriggered, _QuestName}</pre>
--
-- @field Payday
-- Starts the quest on the next payday
-- <pre>{Conditions.Payday}</pre>
--
-- @field EntityDestroyed
-- Starts the quest when a entity does not exist.
-- <pre>{Conditions.EntityDestroyed, _ScriptName}</pre>
--
-- @field WeatherState
-- Starts the quest when the weather changed to a weather state.
-- <pre>{Conditions.WeatherState, _State}</pre>
--
-- @field QuestAndQuest
-- Starts the quest when both quest have the same result.
-- <pre>{Conditions.QuestAndQuest, _Quest1, _Quest2, _Result}</pre>
--
-- @field QuestOrQuest
-- Starts the quest when one or both quest have the same result.
-- <pre>{Conditions.QuestOrQuest, _Quest1, _Quest2, _Result}</pre>
--
-- @field QuestXorQuest
-- Starts the quest when one or the other quest but NOT both have the
-- same result.
-- <pre>{Conditions.QuestXorQuest, _Quest1, _Quest2, _Result}</pre>
--
Conditions = {
    NeverTriggered = 1,
    Time = 2,
    MapScriptFunction = 3,
    Diplomacy = 4,
    Briefing = 5,
    QuestSuccess = 6,
    QuestFailure = 7,
    QuestInterrupt = 8,
    QuestActive = 9,
    QuestOver = 10,
    QuestNotTriggered = 11,
    Payday = 12,
    EntityDestroyed = 14,
    WeatherState = 15,
    QuestAndQuest = 16,
    QuestOrQuest = 17,
    QuestXorQuest = 18,
}

---
-- Objective types the player musst fulfill to succeed.
-- @within Constants
--
-- @field MapScriptFunction
-- Quest result will be decided by a user function
-- <pre>{Objectives.MapScriptFunction, _Function, _ArgumentList...}</pre>
--
-- @field InstantFailure
-- Quest will allways instantly fail.
-- <pre>{Objectives.InstantFailure}</pre>
--
-- @field InstantSuccess
-- Quest will allways instantly succeed.
-- <pre>{Objectives.InstantSuccess}</pre>
--
-- @field NoChange
-- Quest never changes
-- <pre>{Objectives.NoChange}</pre>
--
-- @field Destroy
-- Destroy a unit, a whole army or make a hero loose consciousness.
-- <pre>{Objectives.Destroy, _target}</pre>
--
-- @field Create
-- Create units or buildings in area.
-- <pre>{Objectives.Create, _entityType, _position, _range, _amount, _mark, _changeOwner}</pre>
--
-- @field Diplomacy
-- Reach a diplomatic state to another player.
-- <pre>{Objectives.Diplomacy, _OtherPlayer, _State}</pre>
--
-- @field Produce
-- Gain a amount of resources.
-- <pre>{Objectives.Produce, _Resource, _Amount, _WithoutRaw}</pre>
--
-- @field Protect
-- Shield a entity from any harm.
-- <pre>{Objectives.Protect, _Target}</pre>
--
-- @field EntityDistance
-- A entity must be near to a position on the map.
-- <pre>{Objectives.EntityDistance, _Entity, _Target, _Distance, _LowerThan}</pre>
--
-- @field Workers
-- Reach a number of workers in the settlement.
-- <pre>{Objectives.Workers, _Amount, _LowerThan, _OtherPlayer}</pre>
--
-- @field Motivation
-- Reach a minimum amount of average motivation for the workers.
-- <pre>{Objectives.Motivation, _Amount, _LowerThan, _OtherPlayer}</pre>
--
-- @field Units
-- Create an amount of units.
-- <pre>{Objectives.Units, _Type, _Amount}</pre>
--
-- @field Technology
-- Research a technology
-- <pre>{Objectives.Technology, _Tech}</pre>
--
-- @field Headquarter
-- Upgrade the headquarters one or two times
-- <pre>{Objectives.Headquarters, _Upgrades}</pre>
--
-- @field DestroyType
-- Destroy an amount of entities of type.
-- <pre>{Objectives.DestroyType, _PlayerID, _Type, _Amount}</pre>
--
-- @field DestroyCategory
-- Destroy an amount of entities in a category.
-- <pre>{Objectives.DestroyCategory, _PlayerID, _Category, _Amount}</pre>
--
-- @field Tribute
-- The player must pay a tribute to succeed
-- <pre>{Objectives.Tribute, _CostsTable, _Message}</pre>
--
-- @field Settlers
-- Reach an overall amount of settlers in the settlement.
-- <pre>{Objectives.Settlers, _Amount, _LowerThan, _OtherPlayer}</pre>
--
-- @field Soldiers
-- Reach a number of military units in the settlement.
-- <pre>{Objectives.Soldiers, _Amount, _LowerThan, _OtherPlayer}</pre>
--
-- @field WeatherState
-- The player must change the weather to the weather state.
-- <pre>{Objectives.WeatherState, _State}</pre>
--
-- @field DestroyAllPlayerUnits
-- The player must destroy all buildings and units of the player.
-- <pre>{Objectives.DestroyAllPlayerUnits, _PlayerID}</pre>
--
-- @field Quest
-- The player must complete the quest with the desired result. If the quest
-- is not required, failing the result will not fail the quest.
-- <pre>{Objectives.Quest, _Quest, _Result, _Required}</pre>
--
-- @field Bridge
-- The player must build a bridge in the marked area. Because bridges loose
-- their script names often, use a XD_ScriptEntity instead of the site.
-- <pre>{Objectives.Bridge, _AreaCenter, _AreaSize}</pre>
--
Objectives = {
    MapScriptFunction = 1,
    InstantFailure = 2,
    InstantSuccess = 3,
    NoChange = 4,
    Destroy = 5,
    Create = 6,
    Diplomacy = 7,
    Produce = 8,
    Protect = 9,
    EntityDistance = 10,
    Workers = 11,
    Motivation = 12,
    Units = 13,
    Technology = 14,
    Headquarter = 15,
    DestroyType = 17,
    DestroyCategory = 18,
    Tribute = 19,
    Settlers = 20,
    Soldiers = 21,
    WeatherState = 22,
    DestroyAllPlayerUnits = 24,
    Quest = 25,
    Bridge = 26,
}

---
-- Actions that are performed when a quest is finished.
-- @within Constants
--
-- @field MapScriptFunction
-- Calls a user function as reward.
-- <pre>{Callbacks.MapScriptFunction, _Function, _ArgumentList...}</pre>
--
-- @field Defeat
-- Player looses the game.
-- <pre>{Callbacks.Defeat}</pre>
--
-- @field Victory
-- Player wins the game.
-- <pre>{Callbacks.Victory}</pre>
--
-- @field Briefing
-- Calls a function with a briefing. The function is expected to return
-- the briefing id! Attach only one briefing to one quest!
-- <pre>{Callbacks.Briefing, _Briefing}</pre>
--
-- @field ChangePlayer
-- Changes the owner of the entity
-- <pre>{Callbacks.ChangePlayer, _Entity, _Owner}</pre>
--
-- @field Message
-- Displays a simple message on screen.
-- <pre>{Callbacks.Message, _Message}</pre>
--
-- @field DestroyEntity
-- Replace a named entity or millitary group with a script entity.
-- <pre>{Callbacks.Message, _ScriptName}</pre>
--
-- @field DestroyEffect
-- Destroy a named graphic effect.
-- <pre>{Callbacks.Message, _EffectName}</pre>
--
-- @field CreateEntity
-- Replaces a script entity with a new entity. The new entity will have the
-- same owner and orientation as the script entity.
-- <pre>{Callbacks.CreateEntity, _ScriptName, _Type}</pre>
--
-- @field CreateGroup
-- Replaces a script entity with a military group. The group will have the
-- same owner and orientation as the script entity.
-- <pre>{Callbacks.CreateGroup, _ScriptName, _Type, _Soldiers}</pre>
--
-- @field CreateEffect
-- Creates an effect at the position.
-- <pre>{Callbacks.DestroyEffect, _EffectName, _EffectType, _Position}</pre>
--
-- @field Diplomacy
-- Changes the diplomacy state between two players.
-- <pre>{Callbacks.Diplomacy, _PlayerID1, _PlayerID2, _State}</pre>
--
-- @field Resource
-- Give or remove resources from the player.
-- <pre>{Callbacks.Resource, _ResourceType, _Amount}</pre>
--
-- @field RemoveQuest
-- Removes a quest from the quest book. The quest itself stays untouched.
-- <pre>{Callbacks.RemoveQuest, _QuestName}</pre>
--
-- @field QuestSucceed
-- Let a active quest succeed.
-- <pre>{Callbacks.QuestSucceed, _QuestName}</pre>
--
-- @field QuestFail
-- Let a active quest fail.
-- <pre>{Callbacks.QuestFail, _QuestName}</pre>
--
-- @field QuestInterrupt
-- Interrupts a quest even when it was not startet.
-- <pre>{Callbacks.QuestInterrupt, _QuestName}</pre>
--
-- @field QuestActivate
-- Activates a quest when it was not triggered
-- <pre>{Callbacks.QuestActivate, _QuestName}</pre>
--
-- @field QuestRestart
-- Restarts a quest so that it can be triggered again.
-- <pre>{Callbacks.QuestRestart, _QuestName}</pre>
--
-- @field Technology
-- Change the state of a technology.
-- Possible technology states:
-- <ul>
-- <li>Allow: A technology will be allowed</li>
-- <li>Research: A technology is set as research</li>
-- <li>Forbid: A technology is unaccessable</li>
-- </ul>
-- <pre>{Callbacks.Technology, _Tech, _State}</pre>
--
-- @field CreateMarker
-- Creates an minimap marker or minimap pulsar at the position.
-- <pre>{Callbacks.CreateMarker, _Type, _PositionTable}</pre>
--
-- @field DestroyMarker
-- Removes a minimap marker or pulsar at the position.
-- <pre>{Callbacks.DestroyMarker, _PositionTable}</pre>
--
-- @field RevealArea
-- Explores an area around a script entity.
-- <pre>{Callbacks.RevealArea, _AreaCenter, _Explore}</pre>
--
-- @field ConcealArea
-- Removes the exploration of an area.
-- <pre>{Callbacks.ConcealArea, _AreaCenter}</pre>
--
-- @field Move
-- Removes the exploration of an area.
-- <pre>{Callbacks.Move, _Entity, _Destination}</pre>
--
Callbacks = {
    MapScriptFunction = 1,
    Defeat = 2,
    Victory = 3,
    Briefing = 4,
    ChangePlayer = 5,
    Message = 6,
    DestroyEntity = 7,
    DestroyEffect = 8,
    Diplomacy = 9,
    RemoveQuest = 10,
    QuestSucceed = 11,
    QuestFail = 12,
    QuestInterrupt = 13,
    QuestActivate = 14,
    QuestRestart = 15,
    Technology = 16,
    ConcealArea = 17,
    Move = 18,

    CreateGroup = 100,
    CreateEffect = 101,
    CreateEntity = 102,
    Resource = 103,
    CreateMarker = 104,
    DestroyMarker = 105,
    RevealArea = 106,
}
