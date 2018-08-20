-- ########################################################################## --
-- #  Questsystem                                                           # --
-- #  --------------------------------------------------------------------  # --
-- #    Author:   totalwarANGEL                                             # --
-- ########################################################################## --

---
-- This is an approach to create a RoaE like quest system. Although we can not
-- visualize a failed quest in the quest log, the pure logic of the system is
-- portable to Settlers 5. This little system implements the RoaE system.
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
-- <li>Reprisal: Pubishments after the quest faild.</li>
-- </ul>
--
-- A quest is generated like this:<br>
-- <pre>local QuestID = new(QuestTemplate, "SomeName", SomeObjectives, SomeConditions, 1, -1, SomeRewards, SomeReprisals)</pre>
--
-- @set sort=true
--

QuestSystem = {
    QuestLoop = "QuestSystem_QuestControllerJob",
    Quests = {},
    QuestMarkers = {},
    MinimapMarkers = {},
    Briefings = {},
    HurtEntities = {},
    NamedEffects = {},

    Verbose = false,
};

-- -------------------------------------------------------------------------- --

QuestTemplate = {};

---
-- Creates a quest.
--
-- @param _QuestName [string] Quest name
-- @param _Receiver [number] Receiving player
-- @param _Time [number] Completion time
-- @param _Objectives [table] List of objectives
-- @param _Conditions [table] List of conditions
-- @param _Rewards [table] List of rewards
-- @param _Reprisals [table] List of reprisals
-- @param _Description [table] Quest description
-- @within Constructor
--
function QuestTemplate:construct(_QuestName, _Receiver, _Time, _Objectives, _Conditions, _Rewards, _Reprisals, _Description)
    self:InstallQuestSystem();
    
    self.m_QuestName   = _QuestName;
    self.m_Objectives  = (_Objectives and copy(_Objectives)) or {};
    self.m_Conditions  = (_Conditions and copy(_Conditions)) or {};
    self.m_Rewards     = (_Rewards and copy(_Rewards)) or {};
    self.m_Reprisals   = (_Reprisals and copy(_Reprisals)) or {};
    self.m_Description = _Description;
    self.m_Time        = _Time or -1;

    self.m_State       = QuestStates.Inactive;
    self.m_Result      = QuestResults.Undecided;
    self.m_Receiver    = _Receiver or GUI.GetPlayerID();

    table.insert(QuestSystem.Quests, self);
    self.m_QuestID = table.getn(QuestSystem.Quests);
    Trigger.RequestTrigger(
        Events.LOGIC_EVENT_EVERY_TURN,
        "",
        QuestSystem.QuestLoop,
        1,
        {},
        {self.m_QuestID}
    );
    return self.m_QuestID, self;
end

class(QuestTemplate);

---
-- Initalizes the quest system.
-- @within QuestTemplate
-- @local
--
function QuestTemplate:InstallQuestSystem()
    if QuestSystem.SystemInstalled ~= true then 
        QuestSystem.SystemInstalled = true;

        self:InitalizeQuestEventTrigger();
        
        -- Extern!
        if ActivateBriefingExpansion then
            ActivateBriefingExpansion();
        end

        StartBriefing_Orig_QuestSystem = StartBriefing;
        StartBriefing = function(_Briefing)
            StartBriefing_Orig_QuestSystem(_Briefing);
            gvUniqueBriefingID = (gvUniqueBriefingID or 0) +1;
            briefingState.BriefingID = gvUniqueBriefingID;
            return gvUniqueBriefingID;
        end

        EndBriefing_Orig_QuestSystem = EndBriefing;
        EndBriefing = function()
            EndBriefing_Orig_QuestSystem();
            QuestSystem.Briefings[briefingState.BriefingID] = true;
        end
    end
end

---
-- Displays a debug message if the verbose flag is set.
-- @param _Text [string] Displayed message
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
-- Checks, if the objective of the quest is fullfilled or not.
--
-- @param _Index [number] Index of behavior
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

    elseif Behavior[1] == Objectives.Success then 
        Behavior.Completed = true;

    elseif Behavior[1] == Objectives.Failure then
        Behavior.Completed = false;

    elseif Behavior[1] == Objectives.Custom then 
        Behavior.Completed = Behavior[2](Behavior, self);

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

    elseif Behavior[1] == Objectives.Create then 
        local Position = (type(Behavior[3]) == "table" and Behavior[3]) or GetPosition(Behavior[3]);
        if AreEntitiesInArea(self.m_Receiver, Behavior[2], Position, Behavior[4], Behavior[5]) then 
            Behavior.Completed = true;
        end

    elseif Behavior[1] == Objectives.Produce then 
        if Logic.GetPlayersGlobalResource(self.m_Receiver, Behavior[2]) > Behavior[3] then 
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
        if Behavior[5] then
            if GetDistance(Behavior[2], Behavior[3]) < (Behavior[4] or 2000) then 
                Behavior.Completed = true;
            end
        else
            if GetDistance(Behavior[2], Behavior[3]) >= (Behavior[4] or 2000) then 
                Behavior.Completed = true;
            end
        end

    elseif Behavior[1] == Objectives.Settlers then 
        if Logic.GetNumberOfAttractedSettlers(self.m_Receiver) < Behavior[2] then 
            Behavior.Completed = true;
        elseif Logic.GetNumberOfAttractedSettlers(self.m_Receiver) >= Behavior[2] then 
            Behavior.Completed = true;
        end

    elseif Behavior[1] == Objectives.Workers then 
        if Logic.GetNumberOfAttractedWorker(self.m_Receiver) < Behavior[2] then 
            Behavior.Completed = true;
        elseif Logic.GetNumberOfAttractedWorker(self.m_Receiver) >= Behavior[2] then 
            Behavior.Completed = true;
        end

    elseif Behavior[1] == Objectives.Soldiers then 
        if Logic.GetNumberOfAttractedSoldiers(self.m_Receiver) >= Behavior[2] then 
            Behavior.Completed = true;
        end

    elseif Behavior[1] == Objectives.Motivation then 
        if Logic.GetAverageMotivation(self.m_Receiver) < Behavior[2] then 
            Behavior.Completed = true;
        elseif Logic.GetAverageMotivation(self.m_Receiver) >= Behavior[2] then 
            Behavior.Completed = true;
        end

    elseif Behavior[1] == Objectives.Units then 
        if Logic.GetNumberOfEntitiesOfTypeOfPlayer(self.m_Receiver, Behavior[2]) >= Behavior[3] then 
            Behavior.Completed = true;
        end

    elseif Behavior[1] == Objectives.Technology then 
        if Logic.IsTechnologyResearched(self.m_Receiver, Behavior[2]) == 1 then 
            Behavior.Completed = true;
        end

    elseif Behavior[1] == Objectives.Headquarter then 
        if Logic.GetPlayerEntities(self.m_Receiver, Entities.PB_Headquarters1 + Behavior[2], 1) > 0 then 
            Behavior.Completed = true;
        end

    elseif Behavior[1] == Objectives.NPC then
        if Behavior[5] and TalkedToNPC(Behavior[5]) then 
            Behavior.Completed = true;
        end

    elseif Behavior[1] == Objectives.DestroyType or Behavior[1] == Objectives.DestroyCategory then
        Behavior[5] = Behavior[5] or 0;
        if Behavior[4] <= Behavior[5] then 
            Behavior.Completed = true;
        end

    elseif Behavior[1] == Objectives.Tribute then
        if Behavior[4] == nil then
            g_UniqueTributeCounter = (g_UniqueTributeCounter or 0) +1;
            Logic.AddTribute(self.m_Receiver, g_UniqueTributeCounter, 0, 0, Behavior[3], unpack(Behavior[2]));
            Behavior[4] = g_UniqueTributeCounter;
        end
        if Behavior[5] then 
            Behavior.Completed = true;
        end

    elseif Behavior[1] == Objectives.WeatherState then
        if Logic.GetWeatherState() == Behavior[2] then 
            Behavior.Completed = true;
        end
    end

    return Behavior.Completed;
end

---
-- Checks the trigger condition for the quest.
--
-- @param _Index [number] Index of behavior
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

    elseif Behavior[1] == Conditions.Custom then 
        return Behavior[2](Behavior, self);

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

    elseif Behavior[1] == Conditions.PlayerDestroyed then
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
-- Calls the reward behavior for the quest.
--
-- @param _Index [number] Index of behavior
-- @within QuestTemplate
-- @local
--
function QuestTemplate:ApplyReward(_Index)
    local Behavior = self.m_Rewards[_Index];

    if Behavior[1] == Rewards.Defeat then 
        Sound.PlayFeedbackSound(Sounds.VoicesMentor_COMMENT_BadPlay_rnd_01);
        Defeat();

    elseif Behavior[1] == Rewards.Victory then 
        Sound.PlayFeedbackSound(Sounds.VoicesMentor_COMMENT_GoodPlay_rnd_01);
        Victory();

    elseif Behavior[1] == Rewards.Custom then 
        Behavior[2](Behavior, self);

    elseif Behavior[1] == Rewards.Briefing then 
        self.m_BriefingID = Behavior[2](self);

    elseif Behavior[1] == Rewards.ChangePlayer then 
        ChangePlayer(Behavior[2], Behavior[3]);

    elseif Behavior[1] == Rewards.Message then 
        Message(Behavior[2]);
        ChangePlayer(Behavior[2], Behavior[3]);

    elseif Behavior[1] == Rewards.DestroyEntity then
        if IsExisting(Behavior[2]) then
            local Position = GetPosition(Behavior[2]);
            local PlayerID = GetPlayer(Behavior[2]);
            local Orientation = Logic.GetEntityOrientation(GetID(Behavior[2]));
            DestroyEntity(Behavior[2]);
            local EntityID = Logic.CreateEntity(Entities.XD_ScriptEntity, Position.X, Position.Y, Orientation, PlayerID);
            Logic.SetEntityName(EntityID, Behavior[2]);
        end

    elseif Behavior[1] == Rewards.DestroyEffect then
        if QuestSystem.NamedEffects[Behavior[2]] then
            Logic.DestroyEffect(QuestSystem.NamedEffects[Behavior[2]]);
        end
    
    elseif Behavior[1] == Rewards.CreateEntity then
        ReplaceEntity(Behavior[2], Behavior[3]);

    elseif Behavior[1] == Rewards.CreateGroup then
        local Position = GetPosition(Behavior[2]);
        local PlayerID = GetPlayer(Behavior[2]);
        local Orientation = Logic.GetEntityOrientation(GetID(Behavior[2]));
        DestroyEntity(Behavior[2]);
        CreateMilitaryGroup(PlayerID, Behavior[3], Behavior[4], Position, Behavior[2]);

    elseif Behavior[1] == Rewards.CreateEffect then
        local Position = GetPosition(Behavior[4]);
        local EffectID = Logic.CreateEffect(Behavior[3], Position.X, Position.Y, 0);
        QuestSystem.NamedEffects[Behavior[2]] = EffectID;

    elseif Behavior[1] == Rewards.Diplomacy then
        Logic.Logic.SetDiplomacyState(Behavior[2], Behavior[3], Behavior[4]);

    elseif Behavior[1] == Rewards.Resource then
        if Behavior[3] > 0 then
            Logic.AddToPlayersGlobalResource(self.m_Receiver, Behavior[2], Behavior[3]);
        elseif Behavior[3] < 0 then
            Logic.SubFromPlayersGlobalResource(self.m_Receiver, Behavior[2], math.abs(Behavior[3]));
        end

    elseif Behavior[1] == Rewards.AddJornal then

    elseif Behavior[1] == Rewards.ChangeJornal then

    elseif Behavior[1] == Rewards.RemoveQuest then
        local QuestID = GetQuestID(Behavior[2]);
        if QuestID > 0 then
            Logic.RemoveQuest(self.m_Receiver, QuestID);
        end

    elseif Behavior[1] == Rewards.QuestSucceed then
        local QuestID = GetQuestID(Behavior[2]);
        if QuestID == 0 then 
            return;
        end
        if QuestSystem.Quests[QuestID].m_Result == QuestResults.Undecided and QuestSystem.Quests[QuestID].m_State == QuestStates.Active then
            QuestSystem.Quests[QuestID]:Success();
        end

    elseif Behavior[1] == Rewards.QuestFail then
        local QuestID = GetQuestID(Behavior[2]);
        if QuestID == 0 then 
            return;
        end
        if QuestSystem.Quests[QuestID].m_Result == QuestResults.Undecided and QuestSystem.Quests[QuestID].m_State == QuestStates.Active then
            QuestSystem.Quests[QuestID]:Fail();
        end

    elseif Behavior[1] == Rewards.QuestInterrupt then
        local QuestID = GetQuestID(Behavior[2]);
        if QuestID == 0 then 
            return;
        end
        QuestSystem.Quests[QuestID]:Interrupt();

    elseif Behavior[1] == Rewards.QuestActivate then
        local QuestID = GetQuestID(Behavior[2]);
        if QuestID == 0 then 
            return;
        end
        if QuestSystem.Quests[QuestID].m_State == QuestStates.Inactive then
            QuestSystem.Quests[QuestID]:Trigger();
        end

    elseif Behavior[1] == Rewards.QuestRestart or Behavior[1] == Rewards.QuestRestartForceActive then
        local QuestID = GetQuestID(Behavior[2]);
        if QuestID == 0 then 
            return;
        end
        if QuestSystem.Quests[QuestID].m_State == QuestStates.Over then
            QuestSystem.Quests[QuestID].m_State = QuestStates.Inactive;
            QuestSystem.Quests[QuestID].m_Result = QuestResults.Undecided;
            QuestSystem.Quests[QuestID]:Reset();
            Trigger.RequestTrigger(Events.LOGIC_EVENT_EVERY_TURN, "", QuestSystem.QuestLoop, 1, {}, {QuestSystem.Quests[QuestID].m_QuestID});
            if Behavior[1] == Rewards.QuestRestartForceActive then
                QuestSystem.Quests[QuestID]:Trigger();
            end
        end

    elseif Behavior[1] == Rewards.Technology then
        _G[Behavior[3].. "Technology"](Behavior[2], self.m_Receiver);

    elseif Behavior[1] == Rewards.CreateMarker then
        if Behavior[2] == MarkerTypes.StaticFriendly then 
            GUI.CreateMinimapMarker(Behavior[3].X, Behavior[3].Y, 0);
        elseif Behavior[2] == MarkerTypes.StaticNeutral then 
            GUI.CreateMinimapMarker(Behavior[3].X, Behavior[3].Y, 2);
        elseif Behavior[2] == MarkerTypes.StaticEnemy then 
            GUI.CreateMinimapMarker(Behavior[3].X, Behavior[3].Y, 6);
        elseif Behavior[2] == MarkerTypes.PulseFriendly then 
            GUI.CreateMinimapPulse(Behavior[3].X, Behavior[3].Y, 0);
        elseif Behavior[2] == MarkerTypes.PulseNeutral then 
            GUI.CreateMinimapPulse(Behavior[3].X, Behavior[3].Y, 2);
        else
            GUI.CreateMinimapPulse(Behavior[3].X, Behavior[3].Y, 6);
        end

    elseif Behavior[1] == Rewards.DestroyMarker then
        GUI.DestroyMinimapPulse(Behavior[3].X, Behavior[3].Y);

    elseif Behavior[1] == Rewards.CreateArmy then
        gvMission.KIPlayerArmies              = gvMission.KIPlayerArmies or {};
        gvMission.KIPlayerArmies[Behavior[2]] = gvMission.KIPlayerArmies[Behavior[2]] or {};
        
        -- If not created then create army
        if not gvMission.KIPlayerArmies[Behavior[2]][Behavior[3]] then
            local army 				= {};

            army.player 			= Behavior[2];
            army.id					= Behavior[3];
            army.strength			= Behavior[5];
            army.position			= GetPosition(Behavior[4]);
            army.rodeLength			= 6000;
            army.retreatStrength	= math.ceil(Behavior[5]/3);
            army.baseDefenseRange	= 3500;
            army.outerDefenseRange	= 7000;
            army.AttackAllowed		= false;
            army.beAgressive        = true;
            army.AllowedTypes		= (type(Behavior[7]) == "table" and Behavior[7]) or {Behavior[7]};
            
            army.advanced                = {};
            army.advanced.attackPosition = (type(Behavior[6]) == "table" and Behavior[6]) or {Behavior[6]};

            gvMission.KIPlayerArmies[Behavior[2]][Behavior[3]] = army;
            SetupAITroopGenerator("CreatedKIPlayerArmies" ..army.player.. "_" ..army.id, gvMission.KIPlayerArmies[Behavior[2]][Behavior[3]]);
            Trigger.RequestTrigger(Events.LOGIC_EVENT_EVERY_SECOND, "", "ARMY_LOOP_AI_ADVANCED", 1, 0, {Behavior[2], Behavior[3]});
        end
    
    elseif Behavior[1] == Rewards.CreateAI then
        gvMission.KIPlayers = gvMission.KIPlayers or {};
        if not gvMission.KIPlayers[Behavior[2]] then
            gvMission.KIPlayers[Behavior[2]] = true;

            local description 	= {
                serfLimit	  	= Behavior[3],
                resourceFocus 	= nil,
                rebuild		  	= {delay = 0},
                extracting	  	= Behavior[4],
                repairing	  	= Behavior[5],
                constructing  	= Behavior[6],
                resources	  	= {gold = 30000, clay = 3000, wood = 9000, stone = 3000, iron = 9000, sulfur = 9000},
                refresh   	  	= {gold = 800,   clay =   40, wood =   40, stone =   40, iron =  400, sulfur =  400, updateTime	= 15},
            }
            SetupPlayerAi(Behavior[2], description);
        end
    end
end

---
-- Calls the reprisal behavior for the quest.
--
-- @param _Index [number] Index of behavior
-- @within QuestTemplate
-- @local
--
function QuestTemplate:ApplyReprisal(_Index)
    local Behavior = self.m_Reprisals[_Index];

    if Behavior[1] == Reprisals.Defeat then 
        Sound.PlayFeedbackSound(Sounds.VoicesMentor_COMMENT_BadPlay_rnd_01);
        Defeat();

    elseif Behavior[1] == Reprisals.Victory then 
        Sound.PlayFeedbackSound(Sounds.VoicesMentor_COMMENT_GoodPlay_rnd_01);
        Victory();

    elseif Behavior[1] == Reprisals.Custom then 
        Behavior[2](Behavior, self);

    elseif Behavior[1] == Reprisals.Briefing then 
        self.m_BriefingID = Behavior[2](self);

    elseif Behavior[1] == Reprisals.ChangePlayer then 
        ChangePlayer(Behavior[2], Behavior[3]);

    elseif Behavior[1] == Reprisals.Message then 
        Message(Behavior[2]);

    elseif Behavior[1] == Reprisals.DestroyEntity then
        if IsExisting(Behavior[2]) then
            local Position = GetPosition(Behavior[2]);
            local PlayerID = GetPlayer(Behavior[2]);
            local Orientation = Logic.GetEntityOrientation(GetID(Behavior[2]));
            DestroyEntity(Behavior[2]);
            local EntityID = Logic.CreateEntity(Entities.XD_ScriptEntity, Position.X, Position.Y, Orientation, PlayerID);
            Logic.SetEntityName(EntityID, Behavior[2]);
        end

    elseif Behavior[1] == Reprisals.DestroyEffect then
        if QuestSystem.NamedEffects[Behavior[2]] then
            Logic.DestroyEffect(QuestSystem.NamedEffects[Behavior[2]]);
        end 

    elseif Behavior[1] == Reprisals.Diplomacy then
        Logic.Logic.SetDiplomacyState(Behavior[2], Behavior[3], Behavior[4]);

    elseif Behavior[1] == Reprisals.AddJornal then

    elseif Behavior[1] == Reprisals.ChangeJornal then

    elseif Behavior[1] == Reprisals.RemoveQuest then
        local QuestID = GetQuestID(Behavior[2]);
        if QuestID > 0 then
            Logic.RemoveQuest(self.m_Receiver, QuestID);
        end

    elseif Behavior[1] == Reprisals.QuestSucceed then
        local QuestID = GetQuestID(Behavior[2]);
        if QuestID == 0 then 
            return;
        end
        if QuestSystem.Quests[QuestID].m_Result == QuestResults.Undecided and QuestSystem.Quests[QuestID].m_State == QuestStates.Active then
            QuestSystem.Quests[QuestID]:Success();
        end

    elseif Behavior[1] == Reprisals.QuestFail then
        local QuestID = GetQuestID(Behavior[2]);
        if QuestID == 0 then 
            return;
        end
        if QuestSystem.Quests[QuestID].m_Result == QuestResults.Undecided and QuestSystem.Quests[QuestID].m_State == QuestStates.Active then
            QuestSystem.Quests[QuestID]:Fail();
        end

    elseif Behavior[1] == Reprisals.QuestInterrupt then
        local QuestID = GetQuestID(Behavior[2]);
        if QuestID == 0 then 
            return;
        end
        QuestSystem.Quests[QuestID]:Interrupt();

    elseif Behavior[1] == Reprisals.QuestActivate then
        local QuestID = GetQuestID(Behavior[2]);
        if QuestID == 0 then 
            return;
        end
        if QuestSystem.Quests[QuestID].m_State == QuestStates.Inactive then
            QuestSystem.Quests[QuestID]:Trigger();
        end

    elseif Behavior[1] == Reprisals.QuestRestart or Behavior[1] == Reprisals.QuestRestartForceActive then
        local QuestID = GetQuestID(Behavior[2]);
        if QuestID == 0 then 
            return;
        end
        if QuestSystem.Quests[QuestID].m_State == QuestStates.Over then
            QuestSystem.Quests[QuestID].m_State = QuestStates.Inactive;
            QuestSystem.Quests[QuestID].m_Result = QuestResults.Undecided;
            QuestSystem.Quests[QuestID]:Reset();
            Trigger.RequestTrigger(Events.LOGIC_EVENT_EVERY_TURN, "", QuestSystem.QuestLoop, 1, {}, {QuestSystem.Quests[QuestID].m_QuestID});
            if Behavior[1] == Reprisals.QuestRestartForceActive then
                QuestSystem.Quests[QuestID]:Trigger();
            end
        end

    elseif Behavior[1] == Reprisals.Technology then
        _G[Behavior[3].. "Technology"](Behavior[2], self.m_Receiver);
    end
end

---
-- Triggers the quest.
-- @within QuestTemplate
-- @local
--
function QuestTemplate:Trigger()
    self:verbose("DEBUG: Trigger quest '" ..self.m_QuestName.. "'");
    self:Reset();

    -- Add quest
    if self.m_Description then
        local Desc = self.m_Description;
        if not Desc.Position then
            Logic.AddQuest(self.m_Receiver, self.m_QuestID, Desc.Type, Desc.Title, Desc.Text, 1);
        else
            Logic.AddQuestEx(self.m_Receiver, self.m_QuestID, Desc.Type, Desc.Title, Desc.Text, Desc.Position.X, Desc.Position.Y, 1);
        end
    end

    -- Backup custom behavior
    for i= 1, table.getn(self.m_Objectives), 1 do 
        if self.m_Objectives[i][1] == Objectives.Custom then 
            self.m_Objectives[i].Original = copy(self.m_Objectives[i]);
        end
    end
    for i= 1, table.getn(self.m_Conditions), 1 do 
        if self.m_Conditions[i][1] == Conditions.Custom then 
            self.m_Conditions[i].Original = copy(self.m_Conditions[i]);
        end
    end
    for i= 1, table.getn(self.m_Rewards), 1 do 
        if self.m_Rewards[i][1] == Rewards.Custom then 
            self.m_Rewards[i].Original = copy(self.m_Rewards[i]);
        end
    end
    for i= 1, table.getn(self.m_Reprisals), 1 do 
        if self.m_Reprisals[i][1] == Reprisals.Custom then 
            self.m_Reprisals[i].Original = copy(self.m_Reprisals[i]);
        end
    end

    self.m_State = QuestStates.Active;
    self.m_Result = QuestResults.Undecided;
    self.m_StartTime = Logic.GetTime();
    self:ShowQuestMarkers();

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
    -- Remove quest
    if self.m_Description then
        Logic.SetQuestType(self.m_Receiver, self.m_QuestID, self.m_Description.Type +1, 1);
    end

    self:verbose("DEBUG: Succeed quest '" ..self.m_QuestName.. "'");

    self.m_State = QuestStates.Over;
    self.m_Result = QuestResults.Success;
    self.m_Briefing = nil;
    self:RemoveQuestMarkers();

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
    -- Remove quest
    if self.m_Description then
        Logic.RemoveQuest(self.m_Receiver, self.m_QuestID);
    end

    self:verbose("DEBUG: Fail quest '" ..self.m_QuestName.. "'");

    self.m_State = QuestStates.Over;
    self.m_Result = QuestResults.Failure;
    self.m_Briefing = nil;
    self:RemoveQuestMarkers();

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
    self.m_Briefing = nil;
    self:RemoveQuestMarkers();

    if GameCallback_OnQuestStatusChanged then
        GameCallback_OnQuestStatusChanged(self.m_QuestID, self.m_State, self.m_Result);
    end
end

---
-- Resets the quest.
-- @within QuestTemplate
-- @local
--
function QuestTemplate:Reset()
    -- Remove quest
    if self.m_Description then
        Logic.RemoveQuest(self.m_Receiver, self.m_QuestID);
    end

    -- Reset quest briefing
    self.m_Briefing = nil;

    -- Reset objectives
    for i= 1, table.getn(self.m_Objectives), 1 do 
        if self.m_Objectives[i][1] == Objectives.Custom then 
            self.m_Objectives[i] = copy(self.m_Objectives[i].Original, {});

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
        if self.m_Conditions[i][1] == Conditions.Custom then 
            self.m_Conditions[i] = copy(self.m_Conditions[i].Original, {});

        elseif self.m_Conditions[i][1] == Conditions.PlayerDestroyed then
            -- Will not be restored, because normally a player only dies once!

        elseif self.m_Conditions[i][1] == Conditions.Payday then
            self.m_Conditions[i][2] = nil;
        end
    end

    -- Reset rewards
    for i= 1, table.getn(self.m_Rewards), 1 do 
        if self.m_Rewards[i][1] == Rewards.Custom then 
            self.m_Rewards[i] = copy(self.m_Rewards[i].Original, {});
        end
    end

    -- Reset reprisals
    for i= 1, table.getn(self.m_Reprisals), 1 do 
        if self.m_Reprisals[i][1] == Reprisals.Custom then 
            self.m_Reprisals[i] = copy(self.m_Reprisals[i].Original, {});
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
    -- TBA
    self:verbose("DEBUG: Show Markers of quest '" ..self.m_QuestName.. "'");

    -- NPC
    for i= 1, table.getn(self.m_Objectives), 1 do
        if self.m_Objectives[i][1] == Objectives.NPC then
            CreateNPC({
                name = self.m_Objectives[i][2],
                heroName = self.m_Objectives[i][3],
                wrongHeroMessage = self.m_Objectives[i][4],
                callback = function() end
            });
            self.m_Objectives[i][5] = NPC[GetID(self.m_Objectives[i][2])];
        end
    end

    -- Create
    for i= 1, table.getn(self.m_Objectives), 1 do
        if self.m_Objectives[i][1] == Objectives.Create then
            if self.m_Objectives[i][6] then 
                local Position = (type(self.m_Objectives[i][3]) == "table" and self.m_Objectives[i][3]) or GetPosition(self.m_Objectives[i][3]);
                self.m_Objectives[i][7] = Logic.CreateEffect(GGL_Effects.FXTerrainPointer, Position.X, Position.Y, 1);
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
    -- TBA
    self:verbose("DEBUG: Hide Markers of quest '" ..self.m_QuestName.. "'");

    -- NPC
    for i= 1, table.getn(self.m_Objectives), 1 do
        if self.m_Objectives[i][1] == Objectives.NPC then
            if self.m_Objectives[i][5] then
                DestroyNPC(self.m_Objectives[i][5]);
                self.m_Objectives[i][5] = nil;
            end
        end
    end

    -- Create
    for i= 1, table.getn(self.m_Objectives), 1 do
        if self.m_Objectives[i][1] == Objectives.Create then
            if self.m_Objectives[i][7] then 
                Logic.DestroyEffect(self.m_Objectives[i][7]);
            end
        end
    end
end

-- -------------------------------------------------------------------------- --

---
-- Enables the triggers for quests.
-- @within QuestTemplate
-- @local
--
function QuestTemplate:InitalizeQuestEventTrigger()
    Trigger.RequestTrigger(
        Events.LOGIC_EVENT_ENTITY_HURT_ENTITY,
        "",
        "QuestSystem_DestroyedEntities_TagParticipants",
        1
    );

    Trigger.RequestTrigger(
        Events.LOGIC_EVENT_ENTITY_DESTROYED,
        "",
        "QuestSystem_DestroyedEntities_RegisterDestroyed",
        1
    );

    Trigger.RequestTrigger(
        Events.LOGIC_EVENT_EVERY_SECOND,
        "",
        "QuestSystem_DestroyedEntities_ClearTagged",
        1
    );

    Trigger.RequestTrigger(
        Events.LOGIC_EVENT_TRIBUTE_PAID,
		"",
		"QuestSystem_TributePayedTrigger",
        1
    );
    
    Trigger.RequestTrigger(
        Events.LOGIC_EVENT_EVERY_TURN,
        "",
        "QuestSystem_OnPaydayTrigger",
        1
    );

    Trigger.RequestTrigger(
        Events.LOGIC_EVENT_PLAYER_DIED,
        "",
        "QuestSystem_OnPlayerDestroyedTrigger",
        1
    );
end

---
-- Handels the event when a player is destroying an entity.
--
-- @param _AttackingPlayer [number] Player id of attacker
-- @param _AttackingID [number] Entity id of attacker
-- @param _DefendingPlayer [number] Player id of defender
-- @param _DefendingID [number] Entity of defender
-- @within QuestTemplate
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
-- @param _TributeID [number] ID of Tribute
-- @within QuestTemplate
-- @local
--
function QuestSystem:QuestTributePayed(_TributeID)
    for i= 1, table.getn(self.Quests), 1 do
        local Quest = self.Quests[i];
        if Quest.m_State == QuestStates.Active and Quest.m_Result == QuestResults.Undecided then 
            for j= 1, table.getn(Quest.m_Objectives), 1 do
                if Quest.m_Objectives[j][1] == Objectives.Tribute then
                    if _TributeID == Quest.m_Objectives[j][4] then 
                        Quest.m_Objectives[j][5] = true;
                    end
                end
            end
        end
    end
end

---
-- Handels the event when a player died.
--
-- @param _PlayerID [number] ID of Player
-- @within QuestTemplate
-- @local
--
function QuestSystem:QuestPlayerDestroyed(_PlayerID)
    for i= 1, table.getn(self.Quests), 1 do
        local Quest = self.Quests[i];
        if Quest.m_State == QuestStates.Inactive then 
            for j= 1, table.getn(Quest.m_Conditions), 1 do
                if Quest.m_Conditions[j][1] == Conditions.PlayerDestroyed then
                    if _PlayerID == Quest.m_Conditions[j][1] then 
                        Quest.m_Conditions[j][2] = true;
                    end
                end
            end
        end
    end
end

---
-- Handles the payday event for all quests.
--
-- @param _PlayerID [number] ID of player
-- @within QuestTemplate
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

-- -------------------------------------------------------------------------- --

---
-- Saves attacked entities and their attacker.
-- @within TriggerCallbacks
-- @local
--
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

---
-- If an entity is destroyed and in the hurt list, call the event. If a soldier
-- is destroyed, the leader id is passed to the event. So be careful: A leader
-- may dies multipe times. ;)
-- @within TriggerCallbacks
-- @local
--
function QuestSystem_DestroyedEntities_RegisterDestroyed()
    local Destroyed = {Event.GetEntityID()};
    for i= 1, table.getn(Destroyed), 1 do 
        if QuestSystem.HurtEntities[Destroyed[i]] then
            local AttackerID = QuestSystem.HurtEntities[Destroyed[i]][1];
            local AttackingPlayer = Logic.EntityGetPlayer(AttackerID);
            local DefendingPlayer = Logic.EntityGetPlayer(Destroyed[i]);
            QuestTemplate:ObjectiveDestroyedEntitiesHandler(AttackingPlayer, AttackerID, DefendingPlayer, Destroyed[i]);
        end
    end
end

---
-- Frequently clear the hurt list.
-- @within TriggerCallbacks
-- @local
--
function QuestSystem_DestroyedEntities_ClearTagged()
    for k, v in pairs(QuestSystem.HurtEntities) do 
        if v and v[2]+3 < Logic.GetTime() then
            QuestSystem.HurtEntities[k] = nil;
        end
    end
end

---
-- Calls the tribute manager after a tribute is payed.
-- @within TriggerCallbacks
-- @local
--
function QuestSystem_TributePayedTrigger()
    QuestSystem:QuestTributePayed(Event.GetTributeUniqueID());
end

---
-- Calls the payday manager on payday.
-- @within TriggerCallbacks
-- @local
--
function QuestSystem_OnPaydayTrigger()
    PaydayTimeoutFlag = PaydayTimeoutFlag or {};
    PaydayOverFlag = PaydayOverFlag or {};
    
    for i= 1, 8, 1 do
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

---
-- Calls the event manager for died player.
-- @within TriggerCallbacks
-- @local
--
function QuestSystem_OnPlayerDestroyedTrigger()
    QuestSystem:QuestPlayerDestroyed(Event.GetPlayerID());
end

---
-- Controlls the flow of the quest. This function is called by code!
-- @param _QuestID [number] ID of quest
-- @within TriggerCallbacks
-- @local
--
function QuestSystem_QuestControllerJob(_QuestID)
    local Quest = QuestSystem.Quests[_QuestID];

    if Quest.m_State == QuestStates.Inactive then
        if Quest.m_Result == QuestResults.Undecided then
            local QuestIsTriggered = true;
            for i = 1, table.getn(Quest.m_Conditions) do
                QuestIsTriggered = Quest:IsConditionFulfilled(i) == true;
            end
            if QuestIsTriggered then
                Quest:Trigger();
            end
        end

    elseif Quest.m_State == QuestStates.Active then
        if Quest.m_Result == QuestResults.Undecided then
            local AllObjectivesTrue = true;
            local AnyObjectiveFalse = false;

            for i = 1, table.getn(Quest.m_Objectives) do
                local ObjectiveCompleted = Quest:IsObjectiveCompleted(i);
                if Quest.m_Time > -1 and Quest.m_StartTime + Quest.m_Time < Logic.GetTime() then
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

    elseif Quest.m_State == QuestStates.Over then
        if Quest.m_Result == QuestResults.Success then
            for i = 1, table.getn(Quest.m_Rewards) do
                Quest:ApplyReward(i);
            end
        elseif Quest.m_Result == QuestResults.Failure then
            for i = 1, table.getn(Quest.m_Reprisals) do
                Quest:ApplyReprisal(i);
            end
        end
        return true;
    end
end

-- -------------------------------------------------------------------------- --

AI_ARMYSTATE_DEFEND	  = 1;
AI_ARMYSTATE_REFRESH  = 2;
AI_ARMYSTATE_ATTACK	  = 3;
AI_ARMYSTATE_FALLBACK = 4;

-- a table "Advanced" with entries:
--	* Types <table>
--	* State <number> (is automaticly set if nil)
--	* attackPosition <table>

function ARMY_LOOP_AI_ADVANCED(_PlayerID,_ID)
	local army = gvMission.KIPlayerArmies[_PlayerID][_ID];
	local all  = gvMission.KIPlayerArmies[_PlayerID];

	if army.Advanced ~= nil then
		if army.Advanced.State == nil then
			army.Advanced.State = AI_ARMYSTATE_DEFEND;
		end

		if army.Advanced.State == AI_ARMYSTATE_DEFEND then
			local underProcessing = {};
			for k,v in pairs(all) do
				if all[k].Advanced.Target ~= nil then
					table.insert(underProcessing, all[k].Advanced.Target);
				end
			end

			for i=1,table.getn(army.Advanced.attackPosition),1 do
				local atkPos = army.Advanced.attackPosition[i];
				if  AreEnemiesInArea(army.player, GetPosition(atkPos), army.rodeLength)
				and army.Advanced.Target == nil and not IstDrin(atkPos,underProcessing) then
					Redeploy(army, GetPosition(atkPos));
					army.Advanced.Target = atkPos;
					army.Advanced.State = AI_ARMYSTATE_ATTACK;
					break;
				end
			end

			if IsVeryWeak(army) or IsDead(army) then
				army.Advanced.State = AI_ARMYSTATE_FALLBACK;
				Redeploy(army, army.position);
			end

		elseif army.Advanced.State == AI_ARMYSTATE_ATTACK then
			if army.Advanced.Target then
				if not AreEnemiesInArea(army.player, GetPosition(army.Advanced.Target), army.rodeLength) then
					army.Advanced.State = AI_ARMYSTATE_DEFEND;
					army.Advanced.Target = nil;
					Redeploy(army, army.position);
				end
			end

			if IsVeryWeak(army) or IsDead(army) then
				army.Advanced.State = AI_ARMYSTATE_FALLBACK;
				army.Advanced.Target = nil;
				Redeploy(army, army.position);
			end

		elseif army.Advanced.State == AI_ARMYSTATE_FALLBACK then
			if IsDeadWrapper(army) or IsArmyNear(army, army.position) then
				army.Advanced.State = AI_ARMYSTATE_REFRESH;
			end

		elseif army.Advanced.State == AI_ARMYSTATE_REFRESH then
			if HasFullStrength(army) then
				army.Advanced.State = AI_ARMYSTATE_DEFEND;
				Redeploy(army, army.position);
			end
		end
	end
end

-- -------------------------------------------------------------------------- --

---
-- Checks if a value is inside a table.
--
-- @param _Value [mixed] Value to find
-- @param _Table [table] Table to search
-- @return [boolean] Value found
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
-- @param _player [number] Player ID
-- @param _position [table] Area center
-- @param _range [number] Area size
-- @return [boolean] Enemies near
--
function AreEnemiesInArea( _player, _position, _range)
    return AreEntitiesOfDiplomacyStateInArea( _player, _position, _range, Diplomacy.Hostile )
end

---
-- Checks the area for entities of an allied player.
--
-- @param _player [number] Player ID
-- @param _position [table] Area center
-- @param _range [number] Area size
-- @return [boolean] Allies near
--
function AreAlliesInArea( _player, _position, _range)
    return AreEntitiesOfDiplomacyStateInArea( _player, _position, _range, Diplomacy.Friendly )
end

---
-- Checks the area for entities of other parties with a diplomatic state to
-- the player.
--
-- @param _player [number] Player ID
-- @param _position [table] Area center
-- @param _range [number] Area size
-- @param _state [number] Diplomatic state
-- @return [boolean] Entities near
--
function AreEntitiesOfDiplomacyStateInArea(_player, _position, _range, _state )
	for i = 1,8 do
		if Logic.GetDiplomacyState( _player, i) == _state then
			if AreEntitiesInArea( i, 0, _position, _range, 1) then
				return true
			end
		end
	end
	return false
end

---
-- Returns the quest ID of the quest with the name.
-- If the quest is not found, 0 is returned.
--
-- @param _QuestName [string] Quest name
-- @return [number] Quest ID
-- @within Helper
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
-- @param _QuestName [string] Name of quest
-- @return [boolean] Valid quest
-- @within Helper
--
function IsValidQuest(_QuestName)
    return GetQuestID(_QuestName) ~= 0;
end

---
-- Returns the distance between two positions or entities.
--
-- @param _pos1 [string|number|table] Position 1
-- @param _pos2 [string|number|table] Position 2
-- @return [number] Distance between positions
-- @within Helper
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
-- @param _input [table|string|number] Army or entity
-- @return [boolean] Army or entity is dead
-- @within Helper
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

-- -------------------------------------------------------------------------- --

-- Allows tributes... You are not documented, you are just here. ;)
function GameCallback_FulfillTribute(_PlayerID, _TributeID)
	return 1
end

-- -------------------------------------------------------------------------- --

---
-- Possible types of minimap markers and pulsars.
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
--
-- @field NeverTriggered
-- Quest will never be triggered.
-- <pre>{Conditions.NeverTriggered}</pre>
--
-- @field Time
-- Quest will be triggered after some time after mapstart.
-- <pre>{Conditions.Time, _Waiitime}</pre>
--
-- @field Custom
-- Quest will be triggered when a user function returns true.
-- <pre>{Conditions.Custom, _Function}</pre>
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
-- @field PlayerDestroyed
-- Starts the quest when a player died
-- <pre>{Conditions.PlayerDestroyed, _PlayerID}</pre>
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
    Custom = 3,
    Diplomacy = 4,
    Briefing = 5,
    QuestSuccess = 6,
    QuestFailure = 7,
    QuestInterrupt = 8,
    QuestActive = 9,
    QuestOver = 10,
    QuestNotTriggered = 11,
    Payday = 12,
    PlayerDestroyed = 13,
    EntityDestroyed = 14,
    WeatherState = 15,
    QuestAndQuest = 16,
    QuestOrQuest = 17,
    QuestXorQuest = 18,
}

---
-- Objective types the player musst fulfill to succeed.
--
-- @field Custom
-- Quest result will be decided by a user function
-- <pre>{Objectives.Custom, _Function, ...}</pre>
--
-- @field Failure
-- Quest will allways instantly fail.
-- <pre>{Objectives.Failure}</pre>
--
-- @field Success
-- Quest will allways instantly succeed.
-- <pre>{Objectives.Success}</pre>
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
-- <pre>{Objectives.Create, _entityType, _position, _range, _amount, _mark}</pre>
--
-- @field Diplomacy
-- Reach a diplomatic state to another player.
-- <pre>{Objectives.Diplomacy, _OtherPlayer, _State}</pre>
--
-- @field Produce
-- Gain a amount of resources.
-- <pre>{Objectives.Produce, _Resource, _Amount}</pre>
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
-- <pre>{Objectives.Workers, _Amount, _LowerThan}</pre>
--
-- @field Motivation
-- Reach a minimum amount of average motivation for the workers.
-- <pre>{Objectives.Motivation, _Amount, _LowerThan}</pre>
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
-- <pre>{Objectives.Headquarter, _Upgrades}</pre>
--
-- @field NPC
-- Talk to an npc. The npc will be initalized. Required hero is optional.
-- <pre>{Objectives.NPC, _Settler, _RequiredHero, _WongHeroMessage}</pre>
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
-- <pre>{Objectives.Settlers, _Amount, _LowerThan}</pre>
--
-- @field Soldiers
-- Reach a number of military units in the settlement.
-- <pre>{Objectives.Soldiers, _Amount, _LowerThan}</pre>
--
-- @field WeatherState
-- The player must change the weather to the weather state.
-- <pre>{Objectives.WeatherState, _State}</pre>
--
Objectives = {
    Custom = 1,
    Failure = 2,
    Success = 3,
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
    NPC = 16,
    DestroyType = 17,
    DestroyCategory = 18,
    Tribute = 19,
    Settlers = 20,
    Soldiers = 21,
    WeatherState = 22,
}

---
-- Actions that are performed when a quest is finished successfully.
--
-- @field Custom
-- Calls a user function as reward.
-- <pre>{Rewards.Custom, _Function, ...}</pre>
--
-- @field Defeat
-- Player looses the game.
-- <pre>{Rewards.Defeat}</pre>
--
-- @field Victory
-- Player wins the game.
-- <pre>{Rewards.Victory}</pre>
--
-- @field Briefing
-- Calls a function with a briefing. The function is expected to return
-- the briefing id! Attach only one briefing to one quest!
-- <pre>{Rewards.Briefing, _Briefing}</pre>
--
-- @field ChangePlayer
-- Changes the owner of the entity
-- <pre>{Rewards.ChangePlayer, _Entity, _Owner}</pre>
--
-- @field Message
-- Displays a simple message on screen.
-- <pre>{Rewards.Message, _Message}</pre>
--
-- @field DestroyEntity
-- Replace a named entity or millitary group with a script entity.
-- <pre>{Rewards.Message, _ScriptName}</pre>
--
-- @field DestroyEffect
-- Destroy a named graphic effect.
-- <pre>{Rewards.Message, _EffectName}</pre>
--
-- @field CreateEntity
-- Replaces a script entity with a new entity. The new entity will have the
-- same owner and orientation as the script entity.
-- <pre>{Rewards.CreateEntity, _ScriptName, _Type}</pre>
--
-- @field CreateGroup
-- Replaces a script entity with a military group. The group will have the
-- same owner and orientation as the script entity.
-- <pre>{Rewards.CreateGroup, _ScriptName, _Type, _Soldiers}</pre>
--
-- @field CreateEffect
-- Creates an effect at the position.
-- <pre>{Rewards.DestroyEffect, _EffectName, _EffectType, _Position}</pre>
--
-- @field Diplomacy
-- Changes the diplomacy state between two players.
-- <pre>{Rewards.Diplomacy, _PlayerID1, _PlayerID2, _State}</pre>
--
-- @field Resource
-- Give or remove resources from the player.
-- <pre>{Rewards.Resource, _ResourceType, _Amount}</pre>
--
-- @field RemoveQuest
-- Removes a quest from the quest book.
-- <pre>{Rewards.RemoveQuest, _QuestName}</pre>
--
-- @field QuestSucceed
-- Let a active quest succeed.
-- <pre>{Rewards.QuestSucceed, _QuestName}</pre>
--
-- @field QuestFail
-- Let a active quest fail.
-- <pre>{Rewards.QuestFail, _QuestName}</pre>
--
-- @field QuestInterrupt
-- Interrupts a quest even when it was not startet.
-- <pre>{Rewards.QuestInterrupt, _QuestName}</pre>
--
-- @field QuestActivate
-- Activates a quest when it was not triggered
-- <pre>{Rewards.QuestActivate, _QuestName}</pre>
--
-- @field QuestRestart
-- Restarts a quest so that it can be triggered again.
-- <pre>{Rewards.QuestRestart, _QuestName}</pre>
--
-- @field QuestRestartForceActive
-- Restarts a quest and triggers it immedaitly despite the conditions.
-- <pre>{Rewards.QuestRestartForceActive, _QuestName}</pre>
--
-- @field Technology
-- Change the state of a technology.
-- Possible technology states:
-- <ul>
-- <li>Allow: A technology will be allowed</li>
-- <li>Research: A technology is set as research</li>
-- <li>Forbid: A technology is unaccessable</li>
-- </ul>
-- <pre>{Rewards.Technology, _Tech, _StateName}</pre>
--
-- @field CreateArmy
-- Creates an army for the AI. Each army of a player need at least one unique
-- target point.
-- <pre>{Rewards.CreateArmy, _PlayerID, _ArmyID, _Position, _Strength, _Targets, _AllowedTypes}</pre>
--
-- @field CreateMarker
-- Creates an minimap marker or minimap pulsar at the position.
-- <pre>{Rewards.CreateMarker, _Type, _PositionTable}</pre>
--
-- @field DestroyMarker
-- Removes a minimap marker or pulsar at the position.
-- <pre>{Rewards.DestroyMarker, _PositionTable}</pre>
--
-- @field CreateAI
-- Creates a simple AI player.
-- <pre>{Rewards.CreateAI, _PlayerID, _SerfLimit, _Extract, _Repair, _Construct}</pre>
--
Rewards = {
    Custom = 1,
    Defeat = 2,
    Victory = 3,
    Briefing = 4,
    ChangePlayer = 5,
    Message = 6,
    DestroyEntity = 7,
    DestroyEffect = 8,
    CreateEntity = 9,
    CreateGroup = 10,
    CreateEffect = 11,
    Diplomacy = 12,
    Resource = 13,
    RemoveQuest = 16,
    QuestSucceed = 17,
    QuestFail = 18,
    QuestInterrupt = 19,
    QuestActivate = 20,
    QuestRestart = 21,
    QuestRestartForceActive = 22,
    Technology = 23,
    CreateArmy = 24,
    CreateMarker = 25,
    DestroyMarker = 26,
    CreateAI = 27,
}

---
-- Actions that are performed when a quest failed.
--
-- @field Custom
-- Calls a user function as reprisal.
-- <pre>{Reprisals.Custom, _Function, ...}</pre>
--
-- @field Defeat
-- Player looses the game.
-- <pre>{Reprisals.Defeat}</pre>
--
-- @field Victory
-- Player wins the game.
-- <pre>{Reprisals.Victory}</pre>
--
-- @field Briefing
-- Calls a function with a briefing. The function is expected to return
-- the briefing id! Attach only one briefing to one quest!
-- <pre>{Reprisals.Briefing, _Briefing}</pre>
--
-- @field ChangePlayer
-- Changes the owner of the entity
-- <pre>{Reprisals.ChangePlayer, _Entity, _Owner}</pre>
--
-- @field Message
-- Displays a simple message on screen.
-- <pre>{Reprisals.Message, _Message}</pre>
--
-- @field DestroyEntity
-- Replace a named entity or millitary group with a script entity.
-- <pre>{Reprisals.Message, _ScriptName}</pre>
--
-- @field DestroyEffect
-- Destroy a named graphic effect.
-- <pre>{Reprisals.Message, _EffectName}</pre>
--
-- @field Diplomacy
-- Changes the diplomacy state between two players.
-- <pre>{Reprisals.Diplomacy, _PlayerID1, _PlayerID2, _State}</pre>
--
-- @field RemoveQuest
-- Removes a quest from the quest book.
-- <pre>{Reprisals.RemoveQuest, _QuestName}</pre>
--
-- @field QuestSucceed
-- Let a active quest succeed.
-- <pre>{Reprisals.QuestSucceed, _QuestName}</pre>
--
-- @field QuestFail
-- Let a active quest fail.
-- <pre>{Reprisals.QuestFail, _QuestName}</pre>
--
-- @field QuestInterrupt
-- Interrupts a quest even when it was not startet.
-- <pre>{Reprisals.QuestInterrupt, _QuestName}</pre>
--
-- @field QuestActivate
-- Activates a quest when it was not triggered
-- <pre>{Reprisals.QuestActivate, _QuestName}</pre>
--
-- @field QuestRestart
-- Restarts a quest so that it can be triggered again.
-- <pre>{Reprisals.QuestRestart, _QuestName}</pre>
--
-- @field QuestRestartForceActive
-- Restarts a quest and triggers it immedaitly despite the conditions.
-- <pre>{Reprisals.QuestRestartForceActive, _QuestName}</pre>
--
-- @field Technology
-- Change the state of a technology.
-- Possible technology states:
-- <ul>
-- <li>Allow: A technology will be allowed</li>
-- <li>Research: A technology is set as research</li>
-- <li>Forbid: A technology is unaccessable</li>
-- <pre>{Reprisals.Technology, _Tech, _StateName}</pre>
--
Reprisals = {
    Custom = 1,
    Defeat = 2,
    Victory = 3,
    Briefing = 4,
    ChangePlayer = 5,
    Message = 6,
    DestroyEntity = 7,
    DestroyEffect = 8,
    Diplomacy = 9,
    RemoveQuest = 12,
    QuestSucceed = 13,
    QuestFail = 14,
    QuestInterrupt = 15,
    QuestActivate = 16,
    QuestRestart = 17,
    QuestRestartForceActive = 18,
    Technology = 19,
}
