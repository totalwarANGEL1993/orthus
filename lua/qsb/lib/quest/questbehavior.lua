-- ########################################################################## --
-- #  Behavior templates                                                    # --
-- #  --------------------------------------------------------------------  # --
-- #    Author:   totalwarANGEL                                             # --
-- ########################################################################## --

---
-- This is an abstraction layer of the quest system, allowing the user to
-- create quests much more simple. Also some behavior are recoded and there
-- is a better AI control script for armies than the default controller.
--
-- <b>Required modules:</b>
-- <ul>
-- <li>qsb.lib.oop</li>
-- <li>qsb.lib.questtools</li>
-- <li>qsb.quest.questsystem</li>
-- <li>qsb.quest.questdebug</li>
-- <li>qsb.ui.interaction</li>
-- <li>qsb.quest.questbriefing</li>
-- <li>qsb.ui.onscreeninfo</li>
-- <li>qsb.ai.aiarmy</li>
-- <li>qsb.ai.aicontroller</li>
-- </ul>
--
-- @set sort=true
--

---@diagnostic disable: undefined-global
---@diagnostic disable: lowercase-global

-- Quests and tools --

NestedQuestResultType = {
    Success = 1,
    Failure = 2,
    Ignored = 3,
};

---
-- Creates an quest from the given table. If the table contains a description,
-- the quest will insert itself into the questbook when it is triggered and
-- erase it, after it is finished or interrupted.
--
-- Keep in mind that there can be only 8 entries in the quest book unless you
-- use extra 3 or the standalone version of mcb's quest!
--
-- Table contains of the following entries:
-- <ul>
-- <li><b>Name:</b> Name of quest</li>
-- <li><b>Receiver:</b> Player that receives the quest</li>
-- <li><b>Time:</b> Time, until the quest is automatically over</li>
-- <li><b>Description:</b> Quest information displayed in the quest book.
-- (Mostly identical to Logic.CreateQuest or Logic.CreateQuestEx)</li>
-- </ul>
-- After the fields the behavior constructors are called.
--
-- @param[type=table] _Data Quest table
-- @return[type=number] Quest id
-- @return[type=table]  Quest instance
-- @within Methods
--
-- @usage CreateQuest {
--     Name = "VictoryCondition",
--     Description = {
--         Title = "Justice!",
--         Text  = "Time for paybeck. Destroy your enemy!",
--         Type  = MAINQUEST_OPEN,
--         Info  = 1
--     },
--
--     Goal_DestroyPlayer(2, "HQ2"),
--     Reward_Victory(),
--     Trigger_Time(0)
-- }
--
function CreateQuest(_Data)
    if not _Data.Name then
        Message("DEBUG: One quest has no name!");
        return;
    end
    local QuestName   = _Data.Name;
    local Receiver    = _Data.Receiver or 1;
    local Time        = _Data.Time;
    local Description = _Data.Description;

    local QuestObjectives = {};
    local QuestConditions = {};
    local QuestRewards = {};
    local QuestReprisals = {};

    for i= 1, table.getn(_Data), 1 do
        if _Data[i].GetGoalTable then
            table.insert(QuestObjectives, copy(_Data[i]:GetGoalTable()));
        elseif _Data[i].GetTriggerTable then
            table.insert(QuestConditions, copy(_Data[i]:GetTriggerTable()));
        elseif _Data[i].GetRewardTable then
            table.insert(QuestRewards, copy(_Data[i]:GetRewardTable()));
        elseif _Data[i].GetReprisalTable then
            table.insert(QuestReprisals, copy(_Data[i]:GetReprisalTable()));
        end
    end

    return new(QuestTemplate, QuestName, Receiver, Time, QuestObjectives, QuestConditions, QuestRewards, QuestReprisals, Description);
end

---
-- Creates an quest together with an array of fragment quests from the given
-- table. The fragments will be executed one after another. If the last fragment
-- is over the quest is finally completed.
--
-- Possible entries for the master quest:
-- <ul>
-- <li><b>Name:</b> Name of master quest</li>
-- <li><b>Receiver:</b> Player that receives the quest</li>
-- <li><b>Time:</b> Time, until the quest is automatically over</li>
-- <li><b>Description:</b> Quest information displayed in the quest book.
-- (Mostly identical to Logic.CreateQuest or Logic.CreateQuestEx)</li>
-- <li><b>Stages:</b> List of subquests</li>
-- </ul>
-- After the fields the behavior constructors for the master quest are called.
--
-- Inside the Stages attribute the sub quests are created. They are written as
-- unnamed tables. They can contain the same fields as the master quest. The sub
-- quests have always the same receiver as the master quest. It is possible to
-- infinitely stack sub quests into each other.
--
-- <b>Note:</b> Nested quests can be used to structure the mission. Those quests
-- can be manipulated as normal quests can.
--
-- @param[type=table] _Data Quest table
-- @return[type=number] Quest id
-- @return[type=table]  Quest instance
-- @within Methods
-- @see CreateQuest
--
-- @usage CreateNestedQuest {
-- 	Name 		= "NestedTraderQuest",
-- 	Description = {
-- 		Title = "Die Händler abklappern",
-- 		Text  = "Sprecht mit allen Händlern und sichert Euch Handelsverträge.",
-- 		Type  = MAINQUEST_OPEN,
-- 		Info  = 1,
-- 	},
-- 	Stages      = {
-- 		{
-- 			Description = {
-- 				Title = "Sprecht mit dem ersten Händler",
-- 				Text  = "",
-- 			},
-- 			Goal_NPC("trader1"),
-- 			Reward_Briefing("Trader1Briefing"),
-- 		},
-- 		{
-- 			Description = {
-- 				Title = "Sprecht mit dem zweiten Händler",
-- 				Text  = "",
-- 			},
-- 			Goal_NPC("trader2"),
-- 			Reward_Briefing("Trader1Briefing"),
-- 		},
-- 		{
-- 			Description = {
-- 				Title = "Sprecht mit dem dritten Händler",
-- 				Text  = "",
-- 			},
-- 			Goal_NPC("trader3"),
-- 			Reward_Briefing("Trader1Briefing"),
-- 		},
-- 		{
-- 			Goal_InstantSuccess(),
-- 			Trigger_QuestSuccess("NestedTraderQuest@Stage3", 5),
-- 		}
-- 	},
-- 	Trigger_Time(5),
-- };
--
function CreateNestedQuest(_Data)
    if not _Data.Name then
        Message("DEBUG: One quest has no name!");
        return;
    end
    _Data.Receiver = _Data.Receiver or 1;
    local QuestName = _Data.Name;

    QuestSystemBehavior.Data.QuestNameToStages[QuestName] = {};

    local LastQuestName = QuestName;
    for i= 1, table.getn(_Data.Stages) do
        -- configure stage
        _Data.Stages[i].Name = _Data.Stages[i].Name or QuestName.. "@Stage" ..i;
        _Data.Stages[i].Receiver = _Data.Receiver;
        _Data.Stages[i].Expected = _Data.Stages[i].Expected or NestedQuestResultType.Success;
        if _Data.Stages[i].Description then
            _Data.Stages[i].Description.Type = FRAGMENTQUEST_OPEN;
            _Data.Stages[i].Description.Info = 1;
        end
        table.insert(_Data, Goal_NoChange());

        -- configure stage
        if i == 1 then
            table.insert(_Data.Stages[i], Trigger_QuestActive(LastQuestName));
            table.insert(_Data, Goal_WinQuest(_Data.Stages[i].Name));
        else
            -- Create links for failure type
            if _Data.Stages[i].Expected == NestedQuestResultType.Failure then
                -- link to previous fragment
                if QuestSystemBehavior:DoesStageContainReprisalQuestBriefing(_Data.Stages[i-1]) then
                    table.insert(_Data.Stages[i], Trigger_Briefing(LastQuestName, "Failure"));
                else
                    table.insert(_Data.Stages[i], Trigger_QuestFailure(LastQuestName));
                end
                -- connect to master
                table.insert(_Data, Goal_FailQuest(_Data.Stages[i].Name));
            end

            -- Create links for success type
            if _Data.Stages[i].Expected == NestedQuestResultType.Success then
                -- link to previous fragment
                if QuestSystemBehavior:DoesStageContainRewardQuestBriefing(_Data.Stages[i-1]) then
                    table.insert(_Data.Stages[i], Trigger_Briefing(LastQuestName, "Success"));
                else
                    table.insert(_Data.Stages[i], Trigger_QuestSuccess(LastQuestName));
                end
                -- connect to master
                table.insert(_Data, Goal_WinQuest(_Data.Stages[i].Name));
            end

            -- Create links for ignored result
            if _Data.Stages[i].Expected == NestedQuestResultType.Ignored then
                -- link to previous fragment
                if QuestSystemBehavior:DoesStageContainRewardQuestBriefing(_Data.Stages[i-1])
                or QuestSystemBehavior:DoesStageContainRewardQuestBriefing(_Data.Stages[i-1]) then
                    table.insert(_Data.Stages[i], Trigger_Briefing(LastQuestName, "Any"));
                else
                    table.insert(_Data.Stages[i], Trigger_QuestOver(LastQuestName));
                end
                -- connect to master
                table.insert(_Data, Goal_CompleteQuest(_Data.Stages[i].Name));
            end

            -- handle failure and success of master
            if i == table.getn(_Data.Stages) then
                if _Data.Stages[i].Expected == NestedQuestResultType.Failure then
                    table.insert(_Data.Stages[i], Reprisal_QuestSucceed(QuestName));
                elseif _Data.Stages[i].Expected == NestedQuestResultType.Success then
                    table.insert(_Data.Stages[i], Reward_QuestSucceed(QuestName));
                else
                    table.insert(_Data.Stages[i], Reward_QuestSucceed(QuestName));
                    table.insert(_Data.Stages[i], Reprisal_QuestSucceed(QuestName));
                end
            end
            if _Data.Stages[i].Expected == NestedQuestResultType.Failure then
                table.insert(_Data.Stages[i], Reward_QuestFail(QuestName));
            end
            if _Data.Stages[i].Expected == NestedQuestResultType.Success then
                table.insert(_Data.Stages[i], Reprisal_QuestFail(QuestName));
            end
        end

        -- create quest for stage
        LastQuestName = _Data.Stages[i].Name;
        table.insert(QuestSystemBehavior.Data.QuestNameToStages[QuestName], LastQuestName);
        -- onion quests are bad style but I will support it
        if _Data.Stages[i].Stages then
            CreateNestedQuest(_Data.Stages[i]);
        end
        CreateQuest(_Data.Stages[i]);
    end
    return CreateQuest(_Data);
end

---
-- This function starts the quest system by loading all components in the
-- right order. Must be called on game start in the FMA.
-- @within Methods
--
function LoadQuestSystem()
    QuestSystemBehavior:PrepareQuestSystem();
end

---
-- Checks, if the S5Hook has been installed. Hook might not be installed, if
-- the player uses the History Edition.
--
-- @return[type=boolean] Hook installed
-- @within Methods
--
-- @usage if IsS5HookInstalled() then
--     -- ...
-- end
--
function IsS5HookInstalled()
    return QuestSystemBehavior.Data.S5HookInitalized == true;
end

-- Helper --

-- Has no use while mapping, so it's not documented.
function dbg(_Quest, _Behavior, _Message)
    GUI.AddStaticNote(string.format("DEBUG: %s:%s: %s", _Quest.m_QuestName, _Behavior.Data.Name, tostring(_Message)));
end

---
-- Registers a behavior
-- @param[type=table] _Behavior Behavior pseudo class
-- @within Methods
--
function RegisterBehavior(_Behavior)
    QuestSystemBehavior:RegisterBehavior(_Behavior)
end

---
-- Fails the quest.
-- @param _Quest Quest name or ID
-- @within Methods
--
function FailQuest(_Quest)
    -- Message("Fail quest " .._Quest);
    QuestSystemBehavior:GetQuestByNameOrID(_Quest):Fail();
end


---
-- Fails the Nested quest.
-- @param _QuestName Quest name or ID
-- @within Methods
--
function FailNestedQuest(_QuestName)
    if not QuestSystemBehavior.Data.QuestNameToStages[_QuestName] then
        FailQuest(_QuestName);
        return;
    end
    for i= 1, table.getn(QuestSystemBehavior.Data.QuestNameToStages[_QuestName]), 1 do
        FailQuest(QuestSystemBehavior.Data.QuestNameToStages[_QuestName][i]);
    end
    FailQuest(_QuestName);
end

---
-- Triggers the quest.
-- @param _Quest Quest name or ID
-- @within Methods
--
function StartQuest(_Quest)
    -- Message("Start quest " .._Quest);
    QuestSystemBehavior:GetQuestByNameOrID(_Quest):Trigger();
end

---
-- Triggers the Nested quest.
-- @param _QuestName Quest name or ID
-- @within Methods
--
function StartNestedQuest(_QuestName)
    if not QuestSystemBehavior.Data.QuestNameToStages[_QuestName] then
        StartQuest(_QuestName);
        return;
    end
    for i= 1, table.getn(QuestSystemBehavior.Data.QuestNameToStages[_QuestName]), 1 do
        StartQuest(QuestSystemBehavior.Data.QuestNameToStages[_QuestName][i]);
    end
    StartQuest(_QuestName);
end

---
-- Interrupts the quest.
-- @param _Quest Quest name or ID
-- @within Methods
--
function StopQuest(_Quest)
    -- Message("Stop quest " .._Quest);
    QuestSystemBehavior:GetQuestByNameOrID(_Quest):Interrupt();
end

---
-- Interrupts the Nested quest.
-- @param _QuestName Quest name or ID
-- @within Methods
--
function StopNestedQuest(_QuestName)
    if not QuestSystemBehavior.Data.QuestNameToStages[_QuestName] then
        StopQuest(_QuestName);
        return;
    end
    for i= 1, table.getn(QuestSystemBehavior.Data.QuestNameToStages[_QuestName]), 1 do
        StopQuest(QuestSystemBehavior.Data.QuestNameToStages[_QuestName][i]);
    end
    StopQuest(_QuestName);
end

---
-- Resets the quest.
-- @param _Quest Quest name or ID
-- @within Methods
--
function ResetQuest(_Quest)
    -- Message("Reset quest " .._Quest);
    QuestSystemBehavior:GetQuestByNameOrID(_Quest):Reset();
    Trigger.RequestTrigger(Events.LOGIC_EVENT_EVERY_SECOND, "", QuestSystem.QuestLoop, 1, {}, {GetQuestID(_Quest)});
end

---
-- Resets the Nested quest.
-- @param _QuestName Quest name or ID
-- @within Methods
--
function ResetNestedQuest(_QuestName)
    if not QuestSystemBehavior.Data.QuestNameToStages[_QuestName] then
        ResetQuest(_QuestName);
        return;
    end
    for i= 1, table.getn(QuestSystemBehavior.Data.QuestNameToStages[_QuestName]), 1 do
        StopQuest(QuestSystemBehavior.Data.QuestNameToStages[_QuestName][i]);
        ResetQuest(QuestSystemBehavior.Data.QuestNameToStages[_QuestName][i]);
    end
    ResetQuest(_QuestName);
end

---
-- Resets the quest and activates it immediately.
-- @param _Quest Quest name or ID
-- @within Methods
--
function RestartQuest(_Quest)
    -- Message("Restart quest " .._Quest);
    QuestSystemBehavior:GetQuestByNameOrID(_Quest):Reset()
    Trigger.RequestTrigger(Events.LOGIC_EVENT_EVERY_SECOND, "", QuestSystem.QuestLoop, 1, {}, {GetQuestID(_Quest)});
    QuestSystemBehavior:GetQuestByNameOrID(_Quest):Trigger();
end

---
-- Resets the Nested quest and activates it immediately.
-- @param _QuestName Quest name or ID
-- @within Methods
--
function RestartNestedQuest(_QuestName)
    for i= 1, table.getn(QuestSystemBehavior.Data.QuestNameToStages[_QuestName]), 1 do
        StopQuest(QuestSystemBehavior.Data.QuestNameToStages[_QuestName][i]);
        if i == 1 then
            RestartQuest(QuestSystemBehavior.Data.QuestNameToStages[_QuestName][i]);
        else
            ResetQuest(QuestSystemBehavior.Data.QuestNameToStages[_QuestName][i]);
        end
    end
    RestartQuest(_QuestName);
end

---
-- Wins the quest.
-- @param _Quest Quest name or ID
-- @within Methods
--
function WinQuest(_Quest)
    -- Message("Win quest " .._Quest);
    QuestSystemBehavior:GetQuestByNameOrID(_Quest):Success();
end

---
-- Wins the Nested quest.
-- @param _QuestName Quest name or ID
-- @within Methods
--
function WinNestedQuest(_QuestName)
    if not QuestSystemBehavior.Data.QuestNameToStages[_QuestName] then
        WinQuest(_QuestName);
        return;
    end
    for i= 1, table.getn(QuestSystemBehavior.Data.QuestNameToStages[_QuestName]), 1 do
        WinQuest(QuestSystemBehavior.Data.QuestNameToStages[_QuestName][i]);
    end
    WinQuest(_QuestName);
end

-- Behavior --

QuestSystemBehavior = {
    Data = {
        RegisteredQuestBehaviors = {},
        SystemInitalized = false,
        S5HookInitalized = false,
        Version = "1.4.0",

        QuestNameToStages = {},
        PlayerColorAssigment = {},
        AiPlayerAttackTargets = {},
        AiPlayerPatrolPoints = {},
        ChoicePages = {},
    }
};

---
-- Installs the questsystem. This function is a substitude for the original
-- method QuestSystem:InstallQuestSystem and will call the original first.
-- After that the behavior are initalized.
--
-- The modules qsb.interaction and qsb.information are also initalized.
--
-- If the S5Hook is found it will be automatically installed.
--
-- @within QuestSystemBehavior
-- @local
--
function QuestSystemBehavior:PrepareQuestSystem()
    if not self.Data.SystemInitalized then
        self.Data.SystemInitalized = true;

        AddOnSaveLoadedAction(function()
            QuestSystemBehavior:UpdatePlayerColorAssigment()
            Camera.ZoomSetFactorMax(2.0);
        end);
        if CppLogic then
            self.Data.CurrentMapName = Framework.GetCurrentMapName();
            AddOnSaveLoadedAction(function()
                QuestSystemBehavior:ReloadS5Hook()
            end);
            QuestSystemBehavior:InstallS5Hook();
        end

        Camera.ZoomSetFactorMax(2.0);
        QuestSystem:InstallQuestSystem();
        self:CreateBehaviorConstructors();
        self:OverwriteMapClosingFunctions();
        self:CreateScriptEvents();

        GameCallback_OnQuestSystemLoaded();
    end
end

function QuestSystemBehavior:CreateScriptEvents()
    QuestSync:DeleteScriptEvent(QuestDebug.ScriptEvents.AlterQuestResult);
    QuestDebug.ScriptEvents.AlterQuestResult = QuestSync:CreateScriptEvent(function(name, _ExecutingPlayer, _QuestID, _Result)
        if QuestID == 0 then
            if GUI.GetPlayerID() == _ExecutingPlayer then
                Message("Can not find quest: " ..command[2]);
            end
            return;
        end
        if QuestSystem.Quests[_QuestID] then
            local QuestName = QuestSystem.Quests[_QuestID].m_QuestName;
            if _Result == QuestResults.Success then
                if GUI.GetPlayerID() == _ExecutingPlayer then
                    Message("Succeed quest: " ..command[2]);
                end     
                if QuestSystemBehavior.Data.QuestNameToStages[QuestName] then
                    WinNestedQuest(QuestName);
                else
                    WinQuest(QuestName);
                end
            elseif _Result == QuestResults.Failure then
                if GUI.GetPlayerID() == _ExecutingPlayer then
                    Message("Fail quest: " ..command[2]);
                end
                if QuestSystemBehavior.Data.QuestNameToStages[QuestName] then
                    FailNestedQuest(QuestName);
                else
                    FailQuest(QuestName);
                end
            elseif _Result == QuestResults.Interrupted then
                if GUI.GetPlayerID() == _ExecutingPlayer then
                    Message("Stop quest: " ..command[2]);
                end           
                if QuestSystemBehavior.Data.QuestNameToStages[QuestName] then
                    StopNestedQuest(QuestName);
                else
                    StopQuest(QuestName);
                end
            end
        end
    end);

    QuestSync:DeleteScriptEvent(QuestDebug.ScriptEvents.AlterQuestState);
    QuestDebug.ScriptEvents.AlterQuestState = QuestSync:CreateScriptEvent(function(name, _ExecutingPlayer, _QuestID, _State)
        if QuestID == 0 then
            if GUI.GetPlayerID() == _ExecutingPlayer then
                Message("Can not find quest: " ..command[2]);
            end
            return;
        end
        if QuestSystem.Quests[_QuestID] then
            local QuestName = QuestSystem.Quests[_QuestID].m_QuestName;
            if _State == QuestStates.Active then
                if GUI.GetPlayerID() == _ExecutingPlayer then
                    Message("Start quest: " ..command[2]);
                end
                if QuestSystemBehavior.Data.QuestNameToStages[QuestName] then
                    StartNestedQuest(QuestName);
                else
                    StartQuest(QuestName);
                end
            elseif _State == -1 then
                if GUI.GetPlayerID() == _ExecutingPlayer then
                    Message("Restart quest: " ..command[2]);
                end
                if QuestSystemBehavior.Data.QuestNameToStages[QuestName] then
                    RestartNestedQuest(QuestName);
                else
                    RestartQuest(QuestName);
                end
            end
        end
    end);
end

---
-- Returns the quest or a generated null save fallback quest if the desired
-- quest does not exist.
-- @param _Subject Quest name or ID
-- @return[type=table] Quest
-- @within QuestSystemBehavior
-- @local
--
function QuestSystemBehavior:GetQuestByNameOrID(_Subject)
    local QuestID = GetQuestID(_Subject);
    if QuestID > 0 and QuestSystem.Quests[QuestID] then
        return QuestSystem.Quests[QuestID];
    end
    Message("Debug: Quest name or ID not found: " ..tostring(_Subject));
    return CreateQuest {
        Name = "Fallback_Quest_" ..table.getn(QuestSystem.Quests),
        Goal_InstantSuccess(),
        Trigger_NeverTriggered()
    }
end

function QuestSystemBehavior:DoesStageContainReprisalQuestBriefing(_Description)
    for i= 1, table.getn(_Description), 1 do
        if _Description[i][2] and _Description[i][2].Data and _Description[i][2].Data.Name then
            if _Description[i][2].Data.Name == "Reprisal_Briefing" then
                return true;
            end
        end
    end
    return false;
end

function QuestSystemBehavior:DoesStageContainRewardQuestBriefing(_Description)
    for i= 1, table.getn(_Description), 1 do
        if _Description[i][2] and _Description[i][2].Data and _Description[i][2].Data.Name then
            if _Description[i][2].Data.Name == "Reward_Briefing" then
                return true;
            end
        end
    end
    return false;
end

---
-- Setup the unloading of the map archive and CppLogic.
-- @within QuestSystemBehavior
-- @local
--
function QuestSystemBehavior:OverwriteMapClosingFunctions()
    if GetExtensionNumber() <= 2 then
        GUIAction_RestartMap_Orig_QuestSystemBehavior = GUIAction_RestartMap;
        GUIAction_RestartMap = function()
            QuestSystemBehavior:UnloadS5Hook();
            GUIAction_RestartMap_Orig_QuestSystemBehavior();
        end

        QuitGame_Orig_QuestSystemBehavior = QuitGame;
        QuitGame = function()
            QuestSystemBehavior:UnloadS5Hook();
            QuitGame_Orig_QuestSystemBehavior();
        end

        QuitApplication_Orig_QuestSystemBehavior = QuitApplication;
        QuitApplication = function()
            QuestSystemBehavior:UnloadS5Hook();
            QuitApplication_Orig_QuestSystemBehavior();
        end

        QuickLoad_Orig_QuestSystemBehavior = QuickLoad;
        QuickLoad = function()
            QuestSystemBehavior:UnloadS5Hook();
            QuickLoad_Orig_QuestSystemBehavior();
        end

        MainWindow_LoadGame_DoLoadGame_Orig_QuestSystemBehavior = MainWindow_LoadGame_DoLoadGame;
        MainWindow_LoadGame_DoLoadGame = function(_Slot)
            QuestSystemBehavior:UnloadS5Hook();
            MainWindow_LoadGame_DoLoadGame_Orig_QuestSystemBehavior(_Slot);
        end
    end
end

---
-- Unloads the map archive and the CppLogic.
-- @within QuestSystemBehavior
-- @local
--
function QuestSystemBehavior:UnloadS5Hook()
    if not CppLogic.OnLeaveMap then
        Message("ERROR: Can not find CppLogic!");
        return;
    end
    if GetExtensionNumber() <= 2 and CppLogic then
        if string.find(Folders.Map, "externalmap") then
            CppLogic.Logic.RemoveTopArchive();
        end
        CppLogic.OnLeaveMap();
        Trigger.DisableTriggerSystem(1);
    end
end

---
-- Registers a behavior.
-- @param[type=table] _Behavior Behavior pseudo class
-- @within QuestSystemBehavior
-- @local
--
function QuestSystemBehavior:RegisterBehavior(_Behavior)
    table.insert(QuestSystemBehavior.Data.RegisteredQuestBehaviors, _Behavior.Data.Name);
end

---
-- Generates the behavior constructor methods for all registered behavior.
-- @within QuestSystemBehavior
-- @local
--
function QuestSystemBehavior:CreateBehaviorConstructors()
    for i= 1, table.getn(QuestSystemBehavior.Data.RegisteredQuestBehaviors), 1 do
        if _G["b_" ..QuestSystemBehavior.Data.RegisteredQuestBehaviors[i]] then
            _G["b_" ..QuestSystemBehavior.Data.RegisteredQuestBehaviors[i]].New = function(self, ...)
                local Behavior = copy(_G["b_" ..self.Data.Name]);
                for i= 1, table.getn(arg), 1 do
                    Behavior:AddParameter(i, arg[i]);
                end
                return Behavior;
            end
        else
            GUI.AddStaticNote("b_" ..QuestSystemBehavior.Data.RegisteredQuestBehaviors[i].. " does not exist!");
        end
    end
end

---
-- Upgrades an existing AI player with a higher technology level.
-- @param[type=number] _PlayerID     ID of player
-- @param[type=number] _NewTechLevel Technology level
-- @within QuestSystemBehavior
-- @local
--
function QuestSystemBehavior:UpgradeAI(_PlayerID, _NewTechLevel)
    if AiController.Players[_PlayerID] then
        AiController:UpgradeTroops(_PlayerID, _NewTechLevel);
    end
end

-- Save Actions --

function QuestSystemBehavior:UpdatePlayerColorAssigment()
    for i= 1, table.getn(Score.Player), 1 do
        local Color = QuestSystemBehavior.Data.PlayerColorAssigment[i];
        if Color then
            Display.SetPlayerColorMapping(i, Color);
        end
    end
end

function QuestSystemBehavior:InstallS5Hook()
    if not CppLogic or not CppLogic.Logic.ReloadCutscene then
        Message("ERROR: Can not find CppLogic!");
        return;
    end
    self.Data.S5HookInitalized = true;
end

function QuestSystemBehavior:ReloadS5Hook()
    CppLogic_ResetGlobal();
    if not CppLogic.Logic.ReloadCutscene then
        Message("ERROR: Can not find CppLogic!");
        self.Data.S5HookInitalized = false;
        return;
    end
    if string.find(Folders.Map, "externalmap") then
        CppLogic.Logic.ReloadCutscene();
    else
        CppLogic.Logic.ReloadCutscene(Folders.Map);
    end
end

-- -------------------------------------------------------------------------- --
-- Vanilla Behavior                                                           --
-- -------------------------------------------------------------------------- --

---
-- Calls a user function as objective.
-- @param[type=string] _FunctionName function to call
-- @within Goals
--
function Goal_MapScriptFunction(...)
    return b_Goal_MapScriptFunction:New(unpack(arg));
end

b_Goal_MapScriptFunction = {
    Data = {
        Name = "Goal_MapScriptFunction",
        Type = Objectives.MapScriptFunction
    },
};

function b_Goal_MapScriptFunction:AddParameter(_Index, _Parameter)
    if _Index == 1 then
        self.Data.CustomFunction = _Parameter;
    end
end

function b_Goal_MapScriptFunction:GetGoalTable()
    return {self.Data.Type, {self.CustomFunction, self}};
end

function b_Goal_MapScriptFunction:CustomFunction(_Quest)
    return _G[self.Data.CustomFunction](self, _Quest);
end

function b_Goal_MapScriptFunction:Reset(_Quest)
    SaveCall{ResetBehaviorProgress, self};
end

function b_Goal_MapScriptFunction:Debug(_Quest)
    if (type(self.Data.CustomFunction) == "string" and _G[self.Data.CustomFunction] == nil)
    or (self.Data.CustomFunction) == nil then
        dbg(_Quest, self, "Function ist invalid:" ..tostring(self.Data.CustomFunction));
        return true;
    end
    return false;
end

QuestSystemBehavior:RegisterBehavior(b_Goal_MapScriptFunction);

-- -------------------------------------------------------------------------- --

---
-- The quest is immediately won.
-- @within Goals
--
function Goal_InstantSuccess(...)
    return b_Goal_InstantSuccess:New(unpack(arg));
end

b_Goal_InstantSuccess = {
    Data = {
        Name = "Goal_InstantSuccess",
        Type = Objectives.InstantSuccess
    },
};

function b_Goal_InstantSuccess:AddParameter(_Index, _Parameter)
end

function b_Goal_InstantSuccess:GetGoalTable()
    return {self.Data.Type};
end

QuestSystemBehavior:RegisterBehavior(b_Goal_InstantSuccess);

-- -------------------------------------------------------------------------- --

---
-- The quest is immediately lost.
-- @within Goals
--
function Goal_InstantFailure(...)
    return b_Goal_InstantFailure:New(unpack(arg));
end

b_Goal_InstantFailure = {
    Data = {
        Name = "Goal_InstantFailure",
        Type = Objectives.InstantSuccess
    },
};

function b_Goal_InstantFailure:AddParameter(_Index, _Parameter)
end

function b_Goal_InstantFailure:GetGoalTable()
    return {self.Data.Type};
end

QuestSystemBehavior:RegisterBehavior(b_Goal_InstantFailure);

-- -------------------------------------------------------------------------- --

---
-- The quest is never finished.
-- @within Goals
--
function Goal_NoChange(...)
    return b_Goal_NoChange:New(unpack(arg));
end

b_Goal_NoChange = {
    Data = {
        Name = "Goal_NoChange",
        Type = Objectives.NoChange
    },
};

function b_Goal_NoChange:AddParameter(_Index, _Parameter)
end

function b_Goal_NoChange:GetGoalTable()
    return {self.Data.Type};
end

QuestSystemBehavior:RegisterBehavior(b_Goal_NoChange);

-- -------------------------------------------------------------------------- --

---
-- The goal is won after the hero is comatose or the entity is destroyed.
-- @param _Target Target (building, hero or unit)
-- @within Goals
--
function Goal_Destroy(...)
    return b_Goal_Destroy:New(unpack(arg));
end

b_Goal_Destroy = {
    Data = {
        Name = "Goal_Destroy",
        Type = Objectives.Destroy
    },
};

function b_Goal_Destroy:AddParameter(_Index, _Parameter)
    if _Index == 1 then
        self.Data.Target = _Parameter;
    end
end

function b_Goal_Destroy:GetGoalTable()
    return {self.Data.Type, self.Data.Target};
end

QuestSystemBehavior:RegisterBehavior(b_Goal_Destroy);

-- -------------------------------------------------------------------------- --

---
-- The goal is won after the player creates entities in the area.
-- @param[type=string] _EntityType Entity type
-- @param[type=string] _Position Area center
-- @param[type=number] _Area Checked area size
-- @param[type=number] _Amount Amount to create
-- @param[type=boolean] _MarkerUse pointer
-- @param[type=number] _NewOwner Change owner after completion
-- @within Goals
--
function Goal_Create(...)
    return b_Goal_Create:New(unpack(arg));
end

b_Goal_Create = {
    Data = {
        Name = "Goal_Create",
        Type = Objectives.Create
    },
};

function b_Goal_Create:AddParameter(_Index, _Parameter)
    if _Index == 1 then
        self.Data.EntityType = Entities[_Parameter];
    elseif _Index == 2 then
        self.Data.Position = _Parameter;
    elseif _Index == 3 then
        self.Data.Area = _Parameter;
    elseif _Index == 4 then
        self.Data.Amount = _Parameter;
    elseif _Index == 5 then
        self.Data.Marker = _Parameter;
    elseif _Index == 6 then
        self.Data.NewOwner = _Parameter;
    end
end

function b_Goal_Create:GetGoalTable()
    return {self.Data.Type, self.Data.EntityType, self.Data.Position, self.Data.Area, self.Data.Amount, self.Data.Marker, self.Data.NewOwner};
end

QuestSystemBehavior:RegisterBehavior(b_Goal_Create);

-- -------------------------------------------------------------------------- --

---
-- The player has to build a bridge near the specified position.
-- @param[type=string] _Position Area center
-- @param[type=number] _Area Checked area size
-- @within Goals
--
function Goal_CreateBridge(...)
    return b_Goal_CreateBridge:New(unpack(arg));
end

b_Goal_CreateBridge = {
    Data = {
        Name = "Goal_CreateBridge",
        Type = Objectives.Bridge
    },
};

function b_Goal_CreateBridge:AddParameter(_Index, _Parameter)
    if _Index == 1 then
        self.Data.Position = _Parameter;
    elseif _Index == 2 then
        self.Data.Area = _Parameter;
    end
end

function b_Goal_CreateBridge:GetGoalTable()
    return {self.Data.Type, self.Data.Position, self.Data.Area};
end

QuestSystemBehavior:RegisterBehavior(b_Goal_CreateBridge);

-- -------------------------------------------------------------------------- --

---
-- The goal is won after the receiver has the diplomatic state to the player.
-- @param[type=number] _TargetPlayer Entity type
-- @param[type=string] _State Diplomacy state name
-- @within Goals
--
function Goal_Diplomacy(...)
    return b_Goal_Diplomacy:New(unpack(arg));
end

b_Goal_Diplomacy = {
    Data = {
        Name = "Goal_Diplomacy",
        Type = Objectives.Diplomacy
    },
};

function b_Goal_Diplomacy:AddParameter(_Index, _Parameter)
    if _Index == 1 then
        self.Data.PlayerID = _Parameter;
    elseif _Index == 2 then
        self.Data.State = Diplomacy[_Parameter];
    end
end

function b_Goal_Diplomacy:GetGoalTable()
    return {self.Data.Type, self.Data.PlayerID, self.Data.State};
end

QuestSystemBehavior:RegisterBehavior(b_Goal_Diplomacy);

-- -------------------------------------------------------------------------- --

---
-- The goal is won after the receiver produces some resources.
-- @param[type=string] _ResourceType Name of resource
-- @param[type=number] _Amount Amount of resource
-- @param[type=boolean] _ExcludeRaw Don't count raw type (default true)
-- @within Goals
--
function Goal_Produce(...)
    return b_Goal_Produce:New(unpack(arg));
end

b_Goal_Produce = {
    Data = {
        Name = "Goal_Produce",
        Type = Objectives.Produce
    },
};

function b_Goal_Produce:AddParameter(_Index, _Parameter)
    if _Index == 1 then
        self.Data.ResourceType = ResourceType[_Parameter];
    elseif _Index == 2 then
        self.Data.Amount = _Parameter;
    elseif _Index == 3 then
        self.Data.ExcludeRaw = (_Parameter == nil and true) or _Parameter;
    end
end

function b_Goal_Produce:GetGoalTable()
    return {self.Data.Type, self.Data.ResourceType, self.Data.Amount, self.Data.ExcludeRaw};
end

QuestSystemBehavior:RegisterBehavior(b_Goal_Produce);

-- -------------------------------------------------------------------------- --

---
-- This goal is automatically won, after the time limit is up. Until then the
-- unit or hero must be protected.
-- @param[type=string] _Target Target to protect
-- @within Goals
--
function Goal_Protect(...)
    return b_Goal_Protect:New(unpack(arg));
end

b_Goal_Protect = {
    Data = {
        Name = "Goal_Protect",
        Type = Objectives.Protect
    },
};

function b_Goal_Protect:AddParameter(_Index, _Parameter)
    if _Index == 1 then
        self.Data.Target = _Parameter;
    end
end

function b_Goal_Protect:GetGoalTable()
    return {self.Data.Type, self.Data.Target};
end

QuestSystemBehavior:RegisterBehavior(b_Goal_Protect);

-- -------------------------------------------------------------------------- --

---
-- This goal is won, after the entity has reached (or left) the target.
-- @param[type=string] _Entity Entity to move
-- @param[type=string] _Target Target to reach
-- @param[type=number] _Distance Distance between entities
-- @param[type=boolean] _LowerThan  Be lower than distance
-- @within Goals
--
function Goal_EntityDistance(...)
    return b_Goal_EntityDistance:New(unpack(arg));
end

b_Goal_EntityDistance = {
    Data = {
        Name = "Goal_EntityDistance",
        Type = Objectives.EntityDistance
    },
};

function b_Goal_EntityDistance:AddParameter(_Index, _Parameter)
    if _Index == 1 then
        self.Data.Entity = _Parameter;
    elseif _Index == 2 then
        self.Data.Target = _Parameter;
    elseif _Index == 3 then
        self.Data.Distance = _Parameter;
    elseif _Index == 4 then
        if type(_Parameter) == "string" then
            _Parameter = _Parameter == "<";
        end
        self.Data.LowerThan = _Parameter;
    end
end

function b_Goal_EntityDistance:GetGoalTable()
    return {self.Data.Type, self.Data.Entity, self.Data.Target, self.Data.Distance, self.Data.LowerThan};
end

QuestSystemBehavior:RegisterBehavior(b_Goal_EntityDistance);

-- -------------------------------------------------------------------------- --

---
-- To win this goal the player must have at least one unit of the category in
-- the area OR mustn't have any unit of that category in the area.
-- @param[type=number] _PlayerID Player to check
-- @param[type=string] _Category Category name
-- @param[type=string] _Target Area center
-- @param[type=number] _Area Size of area
-- @param[type=boolean] _LowerThan  Be lower than distance
-- @within Goals
--
function Goal_UnitsInArea(...)
    return b_Goal_UnitsInArea:New(unpack(arg));
end

b_Goal_UnitsInArea = {
    Data = {
        Name = "Goal_UnitsInArea",
        Type = Objectives.MapScriptFunction
    },
};

function b_Goal_UnitsInArea:AddParameter(_Index, _Parameter)
    if _Index == 1 then
        self.Data.PlayerID = _Parameter;
    elseif _Index == 2 then
        self.Data.Category = _Parameter;
    elseif _Index == 3 then
        self.Data.Target = _Parameter;
    elseif _Index == 4 then
        self.Data.Distance = _Parameter;
    elseif _Index == 5 then
        if type(_Parameter) == "string" then
            _Parameter = _Parameter == "<";
        end
        self.Data.LowerThan = _Parameter;
    end
end

function b_Goal_UnitsInArea:GetGoalTable()
    return {self.Data.Type, {self.CustomFunction, self}};
end

function b_Goal_UnitsInArea:CustomFunction(_Quest)
    local x, y, z = Logic.EntityGetPos(GetID(self.Data.Target));
    if self.Data.LowerThan then
        if Logic.IsPlayerEntityOfCategoryInArea(self.Data.PlayerID, x, y, self.Data.Distance, self.Data.Category) == 1 then
            return true;
        end
    else
        if Logic.IsPlayerEntityOfCategoryInArea(self.Data.PlayerID, x, y, self.Data.Distance, self.Data.Category) == 0 then
            return true;
        end
    end
end

function b_Goal_UnitsInArea:Debug(_Quest)
    if not self.Data.PlayerID or self.Data.PlayerID < 1 or self.Data.PlayerID > 8 then
        dbg(_Quest, self, "The player ID must be between 1 and 8!");
        return true;
    end
    if EntityCategories[self.Data.Category] == nil then
        dbg(_Quest, self, "The category does not exist!");
        return true;
    end
    if not IsExisting(self.Data.Target) then
        dbg(_Quest, self, "The entity for the area center does not exist!");
        return true;
    end
    if self.Data.Distance <= 0 then
        dbg(_Quest, self, "The area size must be greater than 0!");
        return true;
    end
    return false;
end

QuestSystemBehavior:RegisterBehavior(b_Goal_UnitsInArea);

-- -------------------------------------------------------------------------- --

---
-- This goal is won, after the player has an amount of worker.
-- @param[type=number] _Amount Amount to reach
-- @param[type=boolean] _LowerThan  Be lower than
-- @param[type=number] _OtherPlayer Other player
-- @within Goals
--
function Goal_WorkerCount(...)
    return b_Goal_WorkerCount:New(unpack(arg));
end

b_Goal_WorkerCount = {
    Data = {
        Name = "Goal_WorkerCount",
        Type = Objectives.Workers
    },
};

function b_Goal_WorkerCount:AddParameter(_Index, _Parameter)
    if _Index == 1 then
        self.Data.Amount = _Parameter;
    elseif _Index == 2 then
        if type(_Parameter) == "string" then
            _Parameter = _Parameter == "<";
        end
        self.Data.BeLowerThan = _Parameter;
    elseif _Index == 3 then
        self.Data.OtherPlayer = _Parameter;
    end
end

function b_Goal_WorkerCount:GetGoalTable()
    return {self.Data.Type, self.Data.Amount, self.Data.BeLowerThan, self.Data.OtherPlayer};
end

QuestSystemBehavior:RegisterBehavior(b_Goal_WorkerCount);

-- -------------------------------------------------------------------------- --

---
-- This goal is won, after the player has an amount of motivation.
-- @param[type=number] _Amount Amount to reach
-- @param[type=boolean] _LowerThan  Be lower than
-- @param[type=number] _OtherPlayer Other player
-- @within Goals
--
function Goal_Motivation(...)
    return b_Goal_Motivation:New(unpack(arg));
end

b_Goal_Motivation = {
    Data = {
        Name = "Goal_Motivation",
        Type = Objectives.Motivation
    },
};

function b_Goal_Motivation:AddParameter(_Index, _Parameter)
    if _Index == 1 then
        self.Data.Amount = _Parameter;
    elseif _Index == 2 then
        if type(_Parameter) == "string" then
            _Parameter = _Parameter == "<";
        end
        self.Data.BeLowerThan = _Parameter;
    elseif _Index == 3 then
        self.Data.OtherPlayer = _Parameter;
    end
end

function b_Goal_Motivation:GetGoalTable()
    return {self.Data.Type, self.Data.Amount, self.Data.BeLowerThan, self.Data.OtherPlayer};
end

QuestSystemBehavior:RegisterBehavior(b_Goal_Motivation);

-- -------------------------------------------------------------------------- --

---
-- This goal is won, after the player has an amount of settlers.
-- @param[type=number] _Amount Amount to reach
-- @param[type=boolean] _LowerThan  Be lower than
-- @param[type=number] _OtherPlayer Other player
-- @within Goals
--
function Goal_SettlerCount(...)
    return b_Goal_SettlerCount:New(unpack(arg));
end

b_Goal_SettlerCount = {
    Data = {
        Name = "Goal_SettlerCount",
        Type = Objectives.Settlers
    },
};

function b_Goal_SettlerCount:AddParameter(_Index, _Parameter)
    if _Index == 1 then
        self.Data.Amount = _Parameter;
    elseif _Index == 2 then
        if type(_Parameter) == "string" then
            _Parameter = _Parameter == "<";
        end
        self.Data.BeLowerThan = _Parameter;
    elseif _Index == 3 then
        self.Data.OtherPlayer = _Parameter;
    end
end

function b_Goal_SettlerCount:GetGoalTable()
    return {self.Data.Type, self.Data.Amount, self.Data.BeLowerThan, self.Data.OtherPlayer};
end

QuestSystemBehavior:RegisterBehavior(b_Goal_SettlerCount);

-- -------------------------------------------------------------------------- --

---
-- This goal is won, after the player has an amount of soldiers.
-- @param[type=number] _AmountAmount to reach
-- @param[type=boolean] _LowerThan  Be lower than
-- @param[type=number] _OtherPlayer Other player
-- @within Goals
--
function Goal_SoldierCount(...)
    return b_Goal_SoldierCount:New(unpack(arg));
end

b_Goal_SoldierCount = {
    Data = {
        Name = "Goal_SoldierCount",
        Type = Objectives.Soldiers
    },
};

function b_Goal_SoldierCount:AddParameter(_Index, _Parameter)
    if _Index == 1 then
        self.Data.Amount = _Parameter;
    elseif _Index == 2 then
        if type(_Parameter) == "string" then
            _Parameter = _Parameter == "<";
        end
        self.Data.BeLowerThan = _Parameter;
    elseif _Index == 3 then
        self.Data.OtherPlayer = _Parameter;
    end
end

function b_Goal_SoldierCount:GetGoalTable()
    return {self.Data.Type, self.Data.Amount, self.Data.BeLowerThan, self.Data.OtherPlayer};
end

QuestSystemBehavior:RegisterBehavior(b_Goal_SoldierCount);

-- -------------------------------------------------------------------------- --

---
-- This goal is won, after the player reached an amount of units.
-- @param[type=string] _EntityType Entity type name
-- @param[type=number] _Amount Amount to reach
-- @within Goals
--
function Goal_Units(...)
    return b_Goal_Units:New(unpack(arg));
end

b_Goal_Units = {
    Data = {
        Name = "Goal_Units",
        Type = Objectives.Units
    },
};

function b_Goal_Units:AddParameter(_Index, _Parameter)
    if _Index == 1 then
        self.Data.UnitType = Entities[_Parameter];
    elseif _Index == 2 then
        self.Data.Amount = _Parameter;
    end
end

function b_Goal_Units:GetGoalTable()
    return {self.Data.Type, self.Data.UnitType, self.Data.Amount};
end

QuestSystemBehavior:RegisterBehavior(b_Goal_Units);

-- -------------------------------------------------------------------------- --

---
-- This goal is won, after the receiver has researched the technology.
-- @param[type=string] _Technology Technology name
-- @within Goals
--
function Goal_Technology(...)
    return b_Goal_Technology:New(unpack(arg));
end

b_Goal_Technology = {
    Data = {
        Name = "Goal_Technology",
        Type = Objectives.Technology
    },
};

function b_Goal_Technology:AddParameter(_Index, _Parameter)
    if _Index == 1 then
        self.Data.Technology = Technologies[_Parameter];
    end
end

function b_Goal_Technology:GetGoalTable()
    return {self.Data.Type, self.Data.Technology};
end

QuestSystemBehavior:RegisterBehavior(b_Goal_Technology);

-- -------------------------------------------------------------------------- --

---
-- This goal is won, after the receiver has upgraded their headquarters.
-- @param[type=number] _Level Upgrades (1 or 2)
-- @within Goals
--
function Goal_UpgradeHeadquarters(...)
    return b_Goal_UpgradeHeadquarters:New(unpack(arg));
end

b_Goal_UpgradeHeadquarters = {
    Data = {
        Name = "Goal_UpgradeHeadquarters",
        Type = Objectives.Headquarters
    },
};

function b_Goal_UpgradeHeadquarters:AddParameter(_Index, _Parameter)
    if _Index == 1 then
        self.Data.Level = _Parameter;
    end
end

function b_Goal_UpgradeHeadquarters:GetGoalTable()
    return {self.Data.Type, self.Data.Level};
end

QuestSystemBehavior:RegisterBehavior(b_Goal_UpgradeHeadquarters);

-- -------------------------------------------------------------------------- --

---
-- This goal is won, after a hero of the receiver talked to the character.
-- It can be any hero or a special named hero.
-- @param[type=string] _Target Target entity
-- @param[type=string] _Hero Optional required hero
-- @param[type=string] _Message Optional wrong hero message
-- @within Goals
--
function Goal_NPC(...)
    return b_Goal_NPC:New(unpack(arg));
end

b_Goal_NPC = {
    Data = {
        Name = "Goal_NPC",
        Type = Objectives.NPC
    },
};

function b_Goal_NPC:AddParameter(_Index, _Parameter)
    if _Index == 1 then
        self.Data.Target = _Parameter;
    elseif _Index == 2 then
        if _Parameter == "" or _Parameter == "INVALID_SCRIPTNAME" then
            _Parameter = nil;
        end
        self.Data.Hero = _Parameter;
    elseif _Index == 3 then
        if _Parameter == "" then
            _Parameter = nil;
        end
        self.Data.Message = _Parameter;
    end
end

function b_Goal_NPC:GetGoalTable()
    return {self.Data.Type, self.Data.Target, self.Data.Hero, self.Data.Message};
end

QuestSystemBehavior:RegisterBehavior(b_Goal_NPC);

-- -------------------------------------------------------------------------- --

---
-- This goal is won, after the receiver destroyed some entities of type of the
-- player.
-- @param[type=number] _PlayerID Owner of entities
-- @param[type=string] _TypeName Entity type name
-- @param[type=number] _Amount Amount to destroy
-- @within Goals
--
function Goal_DestroyType(...)
    return b_Goal_DestroyType:New(unpack(arg));
end

b_Goal_DestroyType = {
    Data = {
        Name = "Goal_DestroyType",
        Type = Objectives.DestroyType
    },
};

function b_Goal_DestroyType:AddParameter(_Index, _Parameter)
    if _Index == 1 then
        self.Data.PlayerID = _Parameter;
    elseif _Index == 2 then
        self.Data.TypeName = Entities[_Parameter];
    elseif _Index == 3 then
        self.Data.Amount = _Parameter;
    end
end

function b_Goal_DestroyType:GetGoalTable()
    return {self.Data.Type, self.Data.PlayerID, self.Data.TypeName, self.Data.Amount};
end

QuestSystemBehavior:RegisterBehavior(b_Goal_DestroyType);

-- -------------------------------------------------------------------------- --

---
-- This goal is won, after the receiver destroyed some entities of category of
-- the player.
-- @param[type=number] _PlayerID Owner of entities
-- @param[type=string] _TypeName Entity type name
-- @param[type=number] _Amount Amount to destroy
-- @within Goals
--
function Goal_DestroyCategory(...)
    return b_Goal_DestroyCategory:New(unpack(arg));
end

b_Goal_DestroyCategory = {
    Data = {
        Name = "Goal_DestroyCategory",
        Type = Objectives.DestroyCategory
    },
};

function b_Goal_DestroyCategory:AddParameter(_Index, _Parameter)
    if _Index == 1 then
        self.Data.PlayerID = _Parameter;
    elseif _Index == 2 then
        self.Data.CategoryName = EntityCategories[_Parameter];
    elseif _Index == 3 then
        self.Data.Amount = _Parameter;
    end
end

function b_Goal_DestroyCategory:GetGoalTable()
    return {self.Data.Type, self.Data.PlayerID, self.Data.CategoryName, self.Data.Amount};
end

QuestSystemBehavior:RegisterBehavior(b_Goal_DestroyCategory);

-- -------------------------------------------------------------------------- --

---
-- This goal is won, after the receiver payed the tribute.
-- @param[type=string] _Message Tribute message
-- @param[type=number] _Gold Amount of gold
-- @param[type=number] _Clay Amount of clay
-- @param[type=number] _Wood Amount of wood
-- @param[type=number] _Stone Amount of stone
-- @param[type=number] _Iron Amount of iron
-- @param[type=number] _Sulfur Amount of sulfur
-- @within Goals
--
function Goal_Tribute(...)
    return b_Goal_Tribute:New(unpack(arg));
end

b_Goal_Tribute = {
    Data = {
        Name = "Goal_Tribute",
        Type = Objectives.Tribute
    },
};

function b_Goal_Tribute:AddParameter(_Index, _Parameter)
    
    if _Index == 1 then
        self.Data.Message = _Parameter;
    elseif _Index == 2 then
        self.Data.Gold = _Parameter or 0;
    elseif _Index == 3 then
        self.Data.Clay = _Parameter or 0;
    elseif _Index == 4 then
        self.Data.Wood = _Parameter or 0;
    elseif _Index == 5 then
        self.Data.Stone = _Parameter or 0;
    elseif _Index == 6 then
        self.Data.Iron = _Parameter or 0;
    elseif _Index == 7 then
        self.Data.Sulfur = _Parameter or 0;
    end
end

function b_Goal_Tribute:GetGoalTable()
    return {self.Data.Type, {
        ResourceType.Gold,   self.Data.Gold,
        ResourceType.Clay,   self.Data.Clay,
        ResourceType.Wood,   self.Data.Wood,
        ResourceType.Stone,  self.Data.Stone,
        ResourceType.Iron,   self.Data.Iron,
        ResourceType.Sulfur, self.Data.Sulfur,
    }, self.Data.Message};
end

QuestSystemBehavior:RegisterBehavior(b_Goal_Tribute);

-- -------------------------------------------------------------------------- --

---
-- This goal is won, after the receiver changed the weather to the state.
-- @param[type=number] _State Weather state
-- @within Goals
--
function Goal_WeatherState(...)
    return b_Goal_WeatherState:New(unpack(arg));
end

b_Goal_WeatherState = {
    Data = {
        Name = "Goal_WeatherState",
        Type = Objectives.WeatherState
    },
};

function b_Goal_WeatherState:AddParameter(_Index, _Parameter)
    if _Index == 1 then
        self.Data.StateID = WeatherStates[_Parameter];
    end
end

function b_Goal_WeatherState:GetGoalTable()
    return {self.Data.Type, self.Data.StateID};
end

QuestSystemBehavior:RegisterBehavior(b_Goal_WeatherState);

-- -------------------------------------------------------------------------- --

---
-- This goal is won, after some offers of a merchant are bought.
-- @param[type=string] _Merchant  Merchant npc
-- @param[type=number] _Offer Index of offer
-- @param[type=number] _Amount Amount to buy
-- @within Goals
--
function Goal_BuyOffer(...)
    return b_Goal_BuyOffer:New(unpack(arg));
end

b_Goal_BuyOffer = {
    Data = {
        Name = "Goal_BuyOffer",
        Type = Objectives.MapScriptFunction
    },
};

function b_Goal_BuyOffer:AddParameter(_Index, _Parameter)
    if _Index == 1 then
        self.Data.Merchant = _Parameter;
    elseif _Index == 2 then
        self.Data.Offer = _Parameter;
    elseif _Index == 3 then
        self.Data.Amount = _Parameter;
    end
end

function b_Goal_BuyOffer:GetGoalTable()
    return {self.Data.Type, {self.CustomFunction, self}};
end

function b_Goal_BuyOffer:CustomFunction(_Quest)
    if not Interaction.IO[self.Data.Merchant] then
        return false;
    end
    SetBehaviorProgress(
        self,
        Interaction.IO[self.Data.Merchant]:GetTradingVolume(self.Data.Offer),
        self.Data.Amount
    );
    if Interaction.IO[self.Data.Merchant]:GetTradingVolume(self.Data.Offer) >= self.Data.Amount then
        return true;
    end
end

function b_Goal_BuyOffer:Reset(_Quest)
    ResetBehaviorProgress(self);
end

QuestSystemBehavior:RegisterBehavior(b_Goal_BuyOffer);

-- -------------------------------------------------------------------------- --

---
-- This goal is won, after all units of a player are destroyed.
-- @param[type=number] _PlayerID id of player
-- @within Goals
--
function Goal_DestroyAllPlayerUnits(...)
    return b_Goal_DestroyAllPlayerUnits:New(unpack(arg));
end

b_Goal_DestroyAllPlayerUnits = {
    Data = {
        Name = "Goal_DestroyAllPlayerUnits",
        Type = Objectives.DestroyAllPlayerUnits
    },
};

function b_Goal_DestroyAllPlayerUnits:AddParameter(_Index, _Parameter)
    if _Index == 1 then
        self.Data.PlayerID = _Parameter;
    end
end

function b_Goal_DestroyAllPlayerUnits:GetGoalTable()
    return {self.Data.Type, self.Data.PlayerID};
end

QuestSystemBehavior:RegisterBehavior(b_Goal_DestroyAllPlayerUnits);

-- -------------------------------------------------------------------------- --

---
-- The plaver must eliminate all of his enemies in a distinct area.
-- @param[type=string] _Position Area center
-- @param[type=number] _AreaSize Area size
-- @within Goals
--
function Goal_DestroyEnemiesInArea(...)
    return b_Goal_DestroyEnemiesInArea:New(unpack(arg));
end

b_Goal_DestroyEnemiesInArea = {
    Data = {
        Name = "Goal_DestroyEnemiesInArea",
        Type = Objectives.MapScriptFunction
    },
};

function b_Goal_DestroyEnemiesInArea:AddParameter(_Index, _Parameter)
    if _Index == 1 then
        self.Data.Position = _Parameter;
    elseif _Index == 2 then
        self.Data.AreaSize = _Parameter;
    end
end

function b_Goal_DestroyEnemiesInArea:GetGoalTable()
    return {self.Data.Type, {self.CustomFunction, self}};
end

function b_Goal_DestroyEnemiesInArea:CustomFunction(_Quest)
    if not AreEnemiesInArea(_Quest.m_Receiver, GetPosition(self.Data.Position), self.Data.AreaSize) then
        return true;
    end
end

function b_Goal_DestroyEnemiesInArea:Debug(_Quest)
    if not IsExisting(self.Data.Position) then
        dbg(_Quest, self, "Position can not be found: " ..tostring(self.Data.Position));
        return true;
    end
    if not self.Data.AreaSize or self.Data.AreaSize < 0 then
        dbg(_Quest, self, "Area size is invalid!");
        return true;
    end
    return false;
end

QuestSystemBehavior:RegisterBehavior(b_Goal_DestroyEnemiesInArea);

-- -------------------------------------------------------------------------- --

---
-- The player must steal the amount of the resource from other players.
-- @param[type=string] _Good   Area center
-- @param[type=number] _Amount Area size
-- @within Goals
--
function Goal_Steal(...)
    return b_Goal_Steal:New(unpack(arg));
end

b_Goal_Steal = {
    Data = {
        Name = "Goal_Steal",
        Type = Objectives.Steal
    },
};

function b_Goal_Steal:AddParameter(_Index, _Parameter)
    if _Index == 1 then
        self.Data.Good = ResourceType[_Parameter];
    elseif _Index == 2 then
        self.Data.Amount = _Parameter;
    end
end

function b_Goal_Steal:GetGoalTable()
    return {self.Data.Type, self.Data.Good, self.Data.Amount};
end

QuestSystemBehavior:RegisterBehavior(b_Goal_Steal);

-- -------------------------------------------------------------------------- --

---
-- Calls a user function as reprisal.
-- @param[type=string] _FunctionName function to call
-- @within Reprisals
--
function Reprisal_MapScriptFunction(...)
    return b_Reprisal_MapScriptFunction:New(unpack(arg));
end

b_Reprisal_MapScriptFunction = {
    Data = {
        Name = "Reprisal_MapScriptFunction",
        Type = Callbacks.MapScriptFunction
    },
};

function b_Reprisal_MapScriptFunction:AddParameter(_Index, _Parameter)
    if _Index == 1 then
        self.Data.CustomFunction = _Parameter;
    end
end

function b_Reprisal_MapScriptFunction:GetReprisalTable()
    return {self.Data.Type, {self.CustomFunction, self}};
end

function b_Reprisal_MapScriptFunction:CustomFunction(_Quest)
    _G[self.Data.CustomFunction](self, _Quest);
end

function b_Reprisal_MapScriptFunction:Debug(_Quest)
    if (type(self.Data.CustomFunction) == "string" and _G[self.Data.CustomFunction] == nil)
    or (self.Data.CustomFunction) == nil then
        dbg(_Quest, self, "Function ist invalid:" ..tostring(self.Data.CustomFunction));
        return true;
    end
    return false;
end

QuestSystemBehavior:RegisterBehavior(b_Reprisal_MapScriptFunction);

-- -------------------------------------------------------------------------- --

---
-- The receiver loses the game.
-- @within Reprisals
--
function Reprisal_Defeat(...)
    return b_Reprisal_Defeat:New(unpack(arg));
end

b_Reprisal_Defeat = {
    Data = {
        Name = "Reprisal_Defeat",
        Type = Callbacks.Defeat
    },
};

function b_Reprisal_Defeat:AddParameter(_Index, _Parameter)
end

function b_Reprisal_Defeat:GetReprisalTable()
    return {self.Data.Type};
end

QuestSystemBehavior:RegisterBehavior(b_Reprisal_Defeat);

-- -------------------------------------------------------------------------- --

---
-- Another player loses the game.
-- @param[type=number] _PlayerID Target player
-- @within Reprisals
--
function Reprisal_DefeatOtherPlayer(...)
    return b_Reprisal_DefeatOtherPlayer:New(unpack(arg));
end

b_Reprisal_DefeatOtherPlayer = {
    Data = {
        Name = "Reprisal_DefeatOtherPlayer",
        Type = Callbacks.MapScriptFunction
    },
};

function b_Reprisal_DefeatOtherPlayer:AddParameter(_Index, _Parameter)
    if _Index == 1 then
        self.Data.PlayerID = _Parameter;
    end
end

function b_Reprisal_DefeatOtherPlayer:GetReprisalTable()
    return {self.Data.Type, {self.CustomFunction, self}};
end

function b_Reprisal_DefeatOtherPlayer:CustomFunction(_Quest)
    if GUI.GetPlayerID() == self.Data.PlayerID then
        Sound.PlayFeedbackSound(Sounds.VoicesMentor_COMMENT_BadPlay_rnd_01);
    end
    Logic.PlayerSetGameStateToLost(self.Data.PlayerID);
    if Network.Manager_DoesExist() == 0 then
        Trigger.DisableTriggerSystem(1);
    end
end

function b_Reprisal_DefeatOtherPlayer:Debug(_Quest)
    if not self.Data.PlayerID or self.Data.PlayerID < 1 or self.Data.PlayerID > 8 then
        dbg(_Quest, self, "Player ID must be between 1 and 8!");
        return true;
    end
end

QuestSystemBehavior:RegisterBehavior(b_Reprisal_DefeatOtherPlayer);

-- -------------------------------------------------------------------------- --

---
-- The receiver wins the game.
-- @within Reprisals
--
function Reprisal_Victory(...)
    return b_Reprisal_Victory:New(unpack(arg));
end

b_Reprisal_Victory = {
    Data = {
        Name = "Reprisal_Victory",
        Type = Callbacks.Victory
    },
};

function b_Reprisal_Victory:AddParameter(_Index, _Parameter)
end

function b_Reprisal_Victory:GetReprisalTable()
    return {self.Data.Type};
end

QuestSystemBehavior:RegisterBehavior(b_Reprisal_Victory);

-- -------------------------------------------------------------------------- --

---
-- Another player wins the game.
-- @param[type=number] _PlayerID Target player
-- @within Reprisals
--
function Reprisal_VictoryOtherPlayer(...)
    return b_Reprisal_VictoryOtherPlayer:New(unpack(arg));
end

b_Reprisal_VictoryOtherPlayer = {
    Data = {
        Name = "Reprisal_VictoryOtherPlayer",
        Type = Callbacks.MapScriptFunction
    },
};

function b_Reprisal_VictoryOtherPlayer:AddParameter(_Index, _Parameter)
    if _Index == 1 then
        self.Data.PlayerID = _Parameter;
    end
end

function b_Reprisal_VictoryOtherPlayer:GetReprisalTable()
    return {self.Data.Type, {self.CustomFunction, self}};
end

function b_Reprisal_VictoryOtherPlayer:CustomFunction(_Quest)
    if GUI.GetPlayerID() == self.Data.PlayerID then
        Sound.PlayFeedbackSound(Sounds.VoicesMentor_COMMENT_GoodPlay_rnd_01);
    end
    Logic.PlayerSetGameStateToWon(self.Data.PlayerID);
    if XNetwork.Manager_DoesExist() == 0 then
        Trigger.DisableTriggerSystem(1);
    end
end

function b_Reprisal_VictoryOtherPlayer:Debug(_Quest)
    if not self.Data.PlayerID or self.Data.PlayerID < 1 or self.Data.PlayerID > 8 then
        dbg(_Quest, self, "Player ID must be between 1 and 8!");
        return true;
    end
end

QuestSystemBehavior:RegisterBehavior(b_Reprisal_VictoryOtherPlayer);

-- -------------------------------------------------------------------------- --

---
-- Starts the briefing. The briefing function must return the briefing id.
-- @param[type=string] _FunctionName function to call
-- @within Reprisals
--
function Reprisal_Briefing(...)
    return b_Reprisal_Briefing:New(unpack(arg));
end

b_Reprisal_Briefing = {
    Data = {
        Name = "Reprisal_Briefing",
        Type = Callbacks.MapScriptFunction
    },
};

function b_Reprisal_Briefing:AddParameter(_Index, _Parameter)
    if _Index == 1 then
        self.Data.Briefing = _Parameter;
    end
end

function b_Reprisal_Briefing:GetReprisalTable()
    return {self.Data.Type, {self.CustomFunction, self}};
end

function b_Reprisal_Briefing:CustomFunction(_Quest)
    _Quest.m_FailureBriefing = SaveCall{
        _G[self.Data.Briefing],
        _Quest.m_Receiver,
        ErrorHandler = function() return -1; end
    };
end

function b_Reprisal_Briefing:Reset(_Quest)
    _Quest.m_FailureBriefing = nil;
end

function b_Reprisal_Briefing:Debug(_Quest)
    if type(self.Data.Briefing) ~= "string" or _G[self.Data.Briefing] == nil then
        dbg(_Quest, self, "Briefing functtion ist invalid:" ..tostring(self.Data.Briefing));
        return true;
    end
    if _Quest.m_FailureBriefing ~= nil then 
        dbg(_Quest, self, "There is already a failure briefing assigned!");
        return true;
    end
    return false;
end

QuestSystemBehavior:RegisterBehavior(b_Reprisal_Briefing);

-- -------------------------------------------------------------------------- --

---
-- Changes the owner of the entity.
-- @param[type=string] _Entity Entity to change
-- @param[type=number] _Owner Owner of entity
-- @within Reprisals
--
function Reprisal_ChangePlayer(...)
    return b_Reprisal_ChangePlayer:New(unpack(arg));
end

b_Reprisal_ChangePlayer = {
    Data = {
        Name = "Reprisal_ChangePlayer",
        Type = Callbacks.ChangePlayer
    },
};

function b_Reprisal_ChangePlayer:AddParameter(_Index, _Parameter)
    if _Index == 1 then
        self.Data.Entity = _Parameter;
    elseif _Index == 2 then
        self.Data.Owner = _Parameter;
    end
end

function b_Reprisal_ChangePlayer:GetReprisalTable()
    return {self.Data.Type, self.Data.Entity, self.Data.Owner};
end

QuestSystemBehavior:RegisterBehavior(b_Reprisal_ChangePlayer);

-- -------------------------------------------------------------------------- --

---
-- Displays a text message on the screen.
--
-- In addition to the placeholders the game offers (@cr, @color, @ra, ...),
-- there are 2 new placeholders for both _G values and custom values.
--
-- @param[type=string] _Message Message to display
-- @within Reprisals
--
function Reprisal_Message(...)
    return b_Reprisal_Message:New(unpack(arg));
end

b_Reprisal_Message = {
    Data = {
        Name = "Reprisal_Message",
        Type = Callbacks.Message
    },
};

function b_Reprisal_Message:AddParameter(_Index, _Parameter)
    if _Index == 1 then
        self.Data.Message = _Parameter;
    end
end

function b_Reprisal_Message:GetReprisalTable()
    return {self.Data.Type, self.Data.Message};
end

QuestSystemBehavior:RegisterBehavior(b_Reprisal_Message);

-- -------------------------------------------------------------------------- --

---
-- Replaces the entity with a XD_ScriptEntity.
-- @param[type=string] _EntityEntity to destroy
-- @within Reprisals
--
function Reprisal_DestroyEntity(...)
    return b_Reprisal_DestroyEntity:New(unpack(arg));
end

b_Reprisal_DestroyEntity = {
    Data = {
        Name = "Reprisal_DestroyEntity",
        Type = Callbacks.DestroyEntity
    },
};

function b_Reprisal_DestroyEntity:AddParameter(_Index, _Parameter)
    if _Index == 1 then
        self.Data.Entity = _Parameter;
    end
end

function b_Reprisal_DestroyEntity:GetReprisalTable()
    return {self.Data.Type, self.Data.Entity};
end

QuestSystemBehavior:RegisterBehavior(b_Reprisal_DestroyEntity);

-- -------------------------------------------------------------------------- --

---
-- Destroys the effect with the given effect name.
-- @param[type=string] _Effect Effect to destroy
-- @within Reprisals
--
function Reprisal_DestroyEffect(...)
    return b_Reprisal_DestroyEffect:New(unpack(arg));
end

b_Reprisal_DestroyEffect = {
    Data = {
        Name = "Reprisal_DestroyEffect",
        Type = Callbacks.DestroyEffect
    },
};

function b_Reprisal_DestroyEffect:AddParameter(_Index, _Parameter)
    if _Index == 1 then
        self.Data.Effect = _Parameter;
    end
end

function b_Reprisal_DestroyEffect:GetReprisalTable()
    return {self.Data.Type, self.Data.Effect};
end

QuestSystemBehavior:RegisterBehavior(b_Reprisal_DestroyEffect);

-- -------------------------------------------------------------------------- --

---
-- Changes the diplomacy state between two players.
-- @param[type=number] _PlayerID1 First player id
-- @param[type=number] _PlayerID2 Second player id
-- @param[type=string] _Diplomacy Diplomacy state name
-- @within Reprisals
--
function Reprisal_Diplomacy(...)
    return b_Reprisal_Diplomacy:New(unpack(arg));
end

b_Reprisal_Diplomacy = {
    Data = {
        Name = "Reprisal_Diplomacy",
        Type = Callbacks.Diplomacy
    },
};

function b_Reprisal_Diplomacy:AddParameter(_Index, _Parameter)
    if _Index == 1 then
        self.Data.PlayerID1 = _Parameter;
    elseif _Index == 2 then
        self.Data.PlayerID2 = _Parameter;
    elseif _Index == 3 then
        self.Data.Diplomacy = Diplomacy[_Parameter];
    end
end

function b_Reprisal_Diplomacy:GetReprisalTable()
    return {self.Data.Type, self.Data.PlayerID1, self.Data.PlayerID2, self.Data.Diplomacy};
end

QuestSystemBehavior:RegisterBehavior(b_Reprisal_Diplomacy);

-- -------------------------------------------------------------------------- --

---
-- Removes the description of a quest from the quest book.
-- @param[type=string] _QuestName Quest name
-- @within Reprisals
--
function Reprisal_RemoveQuest(...)
    return b_Reprisal_RemoveQuest:New(unpack(arg));
end

b_Reprisal_RemoveQuest = {
    Data = {
        Name = "Reprisal_RemoveQuest",
        Type = Callbacks.RemoveQuest
    },
};

function b_Reprisal_RemoveQuest:AddParameter(_Index, _Parameter)
    if _Index == 1 then
        self.Data.QuestName = _Parameter;
    end
end

function b_Reprisal_RemoveQuest:GetReprisalTable()
    return {self.Data.Type, self.Data.QuestName};
end

QuestSystemBehavior:RegisterBehavior(b_Reprisal_RemoveQuest);

-- -------------------------------------------------------------------------- --

---
-- Let the quest succeed.
-- @param[type=string] _QuestName Quest name
-- @within Reprisals
--
function Reprisal_QuestSucceed(...)
    return b_Reprisal_QuestSucceed:New(unpack(arg));
end

b_Reprisal_QuestSucceed = {
    Data = {
        Name = "Reprisal_QuestSucceed",
        Type = Callbacks.QuestSucceed
    },
};

function b_Reprisal_QuestSucceed:AddParameter(_Index, _Parameter)
    if _Index == 1 then
        self.Data.QuestName = _Parameter;
    end
end

function b_Reprisal_QuestSucceed:GetReprisalTable()
    return {self.Data.Type, self.Data.QuestName};
end

QuestSystemBehavior:RegisterBehavior(b_Reprisal_QuestSucceed);

-- -------------------------------------------------------------------------- --

---
-- Let the quest fail.
-- @param[type=string] _QuestName Quest name
-- @within Reprisals
--
function Reprisal_QuestFail(...)
    return b_Reprisal_QuestFail:New(unpack(arg));
end

b_Reprisal_QuestFail = {
    Data = {
        Name = "Reprisal_QuestFail",
        Type = Callbacks.QuestFail
    },
};

function b_Reprisal_QuestFail:AddParameter(_Index, _Parameter)
    if _Index == 1 then
        self.Data.QuestName = _Parameter;
    end
end

function b_Reprisal_QuestFail:GetReprisalTable()
    return {self.Data.Type, self.Data.QuestName};
end

QuestSystemBehavior:RegisterBehavior(b_Reprisal_QuestFail);

-- -------------------------------------------------------------------------- --

---
-- Interrupts the quest.
-- @param[type=string] _QuestName Quest name
-- @within Reprisals
--
function Reprisal_QuestInterrupt(...)
    return b_Reprisal_QuestInterrupt:New(unpack(arg));
end

b_Reprisal_QuestInterrupt = {
    Data = {
        Name = "Reprisal_QuestInterrupt",
        Type = Callbacks.QuestInterrupt
    },
};

function b_Reprisal_QuestInterrupt:AddParameter(_Index, _Parameter)
    if _Index == 1 then
        self.Data.QuestName = _Parameter;
    end
end

function b_Reprisal_QuestInterrupt:GetReprisalTable()
    return {self.Data.Type, self.Data.QuestName};
end

QuestSystemBehavior:RegisterBehavior(b_Reprisal_QuestInterrupt);

-- -------------------------------------------------------------------------- --

---
-- Activates the quest.
-- @param[type=string] _QuestName Quest name
-- @within Reprisals
--
function Reprisal_QuestActivate(...)
    return b_Reprisal_QuestActivate:New(unpack(arg));
end

b_Reprisal_QuestActivate = {
    Data = {
        Name = "Reprisal_QuestActivate",
        Type = Callbacks.QuestActivate
    },
};

function b_Reprisal_QuestActivate:AddParameter(_Index, _Parameter)
    if _Index == 1 then
        self.Data.QuestName = _Parameter;
    end
end

function b_Reprisal_QuestActivate:GetReprisalTable()
    return {self.Data.Type, self.Data.QuestName};
end

QuestSystemBehavior:RegisterBehavior(b_Reprisal_QuestActivate);

-- -------------------------------------------------------------------------- --

---
-- Restarts the quest.
-- @param[type=string] _QuestName Quest name
-- @within Reprisals
--
function Reprisal_QuestRestart(...)
    return b_Reprisal_QuestRestart:New(unpack(arg));
end

b_Reprisal_QuestRestart = {
    Data = {
        Name = "Reprisal_QuestRestart",
        Type = Callbacks.QuestRestart
    },
};

function b_Reprisal_QuestRestart:AddParameter(_Index, _Parameter)
    if _Index == 1 then
        self.Data.QuestName = _Parameter;
    end
end

function b_Reprisal_QuestRestart:GetReprisalTable()
    return {self.Data.Type, self.Data.QuestName};
end

QuestSystemBehavior:RegisterBehavior(b_Reprisal_QuestRestart);

-- -------------------------------------------------------------------------- --

---
-- Changes the state of a technology.
-- @param[type=string] _Technology Technology name
-- @param[type=string] _State      Technology state name
-- @within Reprisals
--
function Reprisal_Technology(...)
    return b_Reprisal_Technology:New(unpack(arg));
end

b_Reprisal_Technology = {
    Data = {
        Name = "Reprisal_Technology",
        Type = Callbacks.Technology
    },
};

function b_Reprisal_Technology:AddParameter(_Index, _Parameter)
    if _Index == 1 then
        self.Data.Technology = Technologies[_Parameter];
    elseif _Index == 2 then
        self.Data.State = TechnologyStates[_Parameter];
    end
end

function b_Reprisal_Technology:GetReprisalTable()
    return {self.Data.Type, self.Data.Technology, self.Data.State};
end

QuestSystemBehavior:RegisterBehavior(b_Reprisal_Technology);

-- -------------------------------------------------------------------------- --

---
-- Removes the exploration of an area.
-- @param[type=string] _AreaCenter Center of exploration
-- @within Reprisals
--
function Reprisal_ConcealArea(...)
    return b_Reprisal_ConcealArea:New(unpack(arg));
end

b_Reprisal_ConcealArea = {
    Data = {
        Name = "Reprisal_ConcealArea",
        Type = Callbacks.ConcealArea
    },
};

function b_Reprisal_ConcealArea:AddParameter(_Index, _Parameter)
    if _Index == 1 then
        self.Data.AreaCenter = _Parameter;
    end
end

function b_Reprisal_ConcealArea:GetReprisalTable()
    return {self.Data.Type, self.Data.AreaCenter};
end

QuestSystemBehavior:RegisterBehavior(b_Reprisal_ConcealArea);

-- -------------------------------------------------------------------------- --

---
-- Moves an entity to the destination.
-- @param[type=string] _Entity Entity to move
-- @param[type=string] _Destination Moving target of entity
-- @within Reprisals
--
function Reprisal_Move(...)
    return b_Reprisal_Move:New(unpack(arg));
end

b_Reprisal_Move = {
    Data = {
        Name = "Reprisal_Move",
        Type = Callbacks.Move
    },
};

function b_Reprisal_Move:AddParameter(_Index, _Parameter)
    if _Index == 1 then
        self.Data.Entity = _Parameter;
    elseif _Index == 2 then
        self.Data.Destination = _Parameter;
    end
end

function b_Reprisal_Move:GetReprisalTable()
    return {self.Data.Type, self.Data.Entity, self.Data.Destination};
end

QuestSystemBehavior:RegisterBehavior(b_Reprisal_Move);

-- -------------------------------------------------------------------------- --

---
-- Calls a user function as reward.
-- @param[type=string] _FunctionName function to call
-- @within Rewards
--
function Reward_MapScriptFunction(...)
    return b_Reward_MapScriptFunction:New(unpack(arg));
end

b_Reward_MapScriptFunction = {
    Data = {
        Name = "Reward_MapScriptFunction",
        Type = Callbacks.MapScriptFunction
    },
};

function b_Reward_MapScriptFunction:AddParameter(_Index, _Parameter)
    if _Index == 1 then
        self.Data.CustomFunction = _Parameter;
    end
end

function b_Reward_MapScriptFunction:GetRewardTable()
    return {self.Data.Type, {self.CustomFunction, self}};
end

function b_Reward_MapScriptFunction:CustomFunction(_Quest)
    _G[self.Data.CustomFunction](self, _Quest);
end

function b_Reward_MapScriptFunction:Debug(_Quest)
    if (type(self.Data.CustomFunction) == "string" and _G[self.Data.CustomFunction] == nil)
    or (self.Data.CustomFunction) == nil then
        dbg(_Quest, self, "Function ist invalid:" ..tostring(self.Data.CustomFunction));
        return true;
    end
    return false;
end

QuestSystemBehavior:RegisterBehavior(b_Reward_MapScriptFunction);

-- -------------------------------------------------------------------------- --

---
-- The receiver loses the game.
-- @within Rewards
--
function Reward_Defeat(...)
    return b_Reward_Defeat:New(unpack(arg));
end

b_Reward_Defeat = copy(b_Reprisal_Defeat);
b_Reward_Defeat.Data.Name = "Reward_Defeat";
b_Reward_Defeat.Data.Type = Callbacks.Defeat;
b_Reward_Defeat.GetReprisalTable = nil;

function b_Reward_Defeat:GetRewardTable()
    return {self.Data.Type};
end

QuestSystemBehavior:RegisterBehavior(b_Reward_Defeat);

-- -------------------------------------------------------------------------- --

---
-- Another player loses the game.
-- @param[type=number] _PlayerID Target player
-- @within Rewards
--
function Reward_DefeatOtherPlayer(...)
    return b_Reward_DefeatOtherPlayer:New(unpack(arg));
end

b_Reward_DefeatOtherPlayer = copy(b_Reprisal_DefeatOtherPlayer);
b_Reward_DefeatOtherPlayer.Data.Name = "Reward_DefeatOtherPlayer";
b_Reward_DefeatOtherPlayer.Data.Type = Callbacks.Defeat;
b_Reward_DefeatOtherPlayer.GetReprisalTable = nil;

function b_Reward_DefeatOtherPlayer:GetRewardTable()
    return {self.Data.Type, {self.CustomFunction, self}};
end

QuestSystemBehavior:RegisterBehavior(b_Reward_DefeatOtherPlayer);

-- -------------------------------------------------------------------------- --

---
-- The receiver wins the game.
-- @within Rewards
--
function Reward_Victory(...)
    return b_Reward_Victory:New(unpack(arg));
end

b_Reward_Victory = copy(b_Reprisal_Victory);
b_Reward_Victory.Data.Name = "Reward_Victory";
b_Reward_Victory.Data.Type = Callbacks.Victory;
b_Reward_Victory.GetReprisalTable = nil;

function b_Reward_Victory:GetRewardTable()
    return {self.Data.Type};
end

QuestSystemBehavior:RegisterBehavior(b_Reward_Victory);

-- -------------------------------------------------------------------------- --

---
-- Another player wins the game.
-- @param[type=number] _PlayerID Target player
-- @within Rewards
--
function Reward_VictoryOtherPlayer(...)
    return b_Reward_VictoryOtherPlayer:New(unpack(arg));
end

b_Reward_VictoryOtherPlayer = copy(b_Reprisal_VictoryOtherPlayer);
b_Reward_VictoryOtherPlayer.Data.Name = "Reward_VictoryOtherPlayer";
b_Reward_VictoryOtherPlayer.Data.Type = Callbacks.Defeat;
b_Reward_VictoryOtherPlayer.GetReprisalTable = nil;

function b_Reward_VictoryOtherPlayer:GetRewardTable()
    return {self.Data.Type, {self.CustomFunction, self}};
end

QuestSystemBehavior:RegisterBehavior(b_Reward_VictoryOtherPlayer);

-- -------------------------------------------------------------------------- --

---
-- Starts the briefing. The briefing function must return the briefing id.
-- @param[type=string] _FunctionName function to call
-- @within Rewards
--
function Reward_Briefing(...)
    return b_Reward_Briefing:New(unpack(arg));
end

b_Reward_Briefing = {
    Data = {
        Name = "Reward_Briefing",
        Type = Callbacks.MapScriptFunction
    },
};

function b_Reward_Briefing:AddParameter(_Index, _Parameter)
    if _Index == 1 then
        self.Data.Briefing = _Parameter;
    end
end

function b_Reward_Briefing:CustomFunction(_Quest)
    _Quest.m_SuccessBriefing = SaveCall{
        _G[self.Data.Briefing],
        _Quest.m_Receiver,
        ErrorHandler = function() return -1; end
    };
end

function b_Reward_Briefing:GetRewardTable()
    return {self.Data.Type, {self.CustomFunction, self}};
end

function b_Reward_Briefing:Reset(_Quest)
    _Quest.m_SuccessBriefing = nil;
end

function b_Reward_Briefing:Debug(_Quest)
    if type(self.Data.Briefing) ~= "string" or _G[self.Data.Briefing] == nil then
        dbg(_Quest, self, "Briefing functtion ist invalid:" ..tostring(self.Data.Briefing));
        return true;
    end
    if _Quest.m_SuccessBriefing ~= nil then 
        dbg(_Quest, self, "There is already a success briefing assigned!");
        return true;
    end
    return false;
end

QuestSystemBehavior:RegisterBehavior(b_Reward_Briefing);

-- -------------------------------------------------------------------------- --

---
-- Changes the owner of the entity.
-- @param[type=string] _EntityEntity to change
-- @param[type=number] _Owner Owner of entity
-- @within Rewards
--
function Reward_ChangePlayer(...)
    return b_Reward_ChangePlayer:New(unpack(arg));
end

b_Reward_ChangePlayer = copy(b_Reprisal_ChangePlayer);
b_Reward_ChangePlayer.Data.Name = "Reward_ChangePlayer";
b_Reward_ChangePlayer.Data.Type = Callbacks.ChangePlayer;
b_Reward_ChangePlayer.GetReprisalTable = nil;

function b_Reward_ChangePlayer:GetRewardTable()
    return {self.Data.Type, self.Data.Entity, self.Data.Owner};
end

QuestSystemBehavior:RegisterBehavior(b_Reward_ChangePlayer);

-- -------------------------------------------------------------------------- --

---
-- Displays a text message on the screen.
--
-- In addition to the placeholders the game offers (@cr, @color, @ra, ...),
-- there are 2 new placeholders for both _G values and custom values.
--
-- @param[type=string] _Message Message to display
-- @within Rewards
--
function Reward_Message(...)
    return b_Reward_Message:New(unpack(arg));
end

b_Reward_Message = copy(b_Reprisal_Message);
b_Reward_Message.Data.Name = "Reward_Message";
b_Reward_Message.Data.Type = Callbacks.Message;
b_Reward_Message.GetReprisalTable = nil;

function b_Reward_Message:GetRewardTable()
    return {self.Data.Type, self.Data.Message};
end

QuestSystemBehavior:RegisterBehavior(b_Reward_Message);

-- -------------------------------------------------------------------------- --

---
-- Replaces the entity with a XD_ScriptEntity.
-- @param[type=string] _EntityEntity to destroy
-- @within Rewards
--
function Reward_DestroyEntity(...)
    return b_Reward_DestroyEntity:New(unpack(arg));
end

b_Reward_DestroyEntity = copy(b_Reprisal_DestroyEntity);
b_Reward_DestroyEntity.Data.Name = "Reward_DestroyEntity";
b_Reward_DestroyEntity.Data.Type = Callbacks.DestroyEntity;
b_Reward_DestroyEntity.GetReprisalTable = nil;

function b_Reward_DestroyEntity:GetRewardTable()
    return {self.Data.Type, self.Data.Entity};
end

QuestSystemBehavior:RegisterBehavior(b_Reward_DestroyEntity);

-- -------------------------------------------------------------------------- --

---
-- Destroys the effect with the given effect name.
-- @param[type=string] _Effect Effect to destroy
-- @within Rewards
--
function Reward_DestroyEffect(...)
    return b_Reward_DestroyEffect:New(unpack(arg));
end

b_Reward_DestroyEffect = copy(b_Reprisal_DestroyEffect);
b_Reward_DestroyEffect.Data.Name = "Reward_DestroyEffect";
b_Reward_DestroyEffect.Data.Type = Callbacks.DestroyEffect;
b_Reward_DestroyEffect.GetReprisalTable = nil;

function b_Reward_DestroyEffect:GetRewardTable()
    return {self.Data.Type, self.Data.Effect};
end

QuestSystemBehavior:RegisterBehavior(b_Reward_DestroyEffect);

-- -------------------------------------------------------------------------- --

---
-- Changes the diplomacy state between two players.
-- @param[type=number] _PlayerID1 First player id
-- @param[type=number] _PlayerID2 Second player id
-- @param[type=string] _Diplomacy Diplomacy state name
-- @within Rewards
--
function Reward_Diplomacy(...)
    return b_Reward_Diplomacy:New(unpack(arg));
end

b_Reward_Diplomacy = copy(b_Reprisal_Diplomacy);
b_Reward_Diplomacy.Data.Name = "Reward_Diplomacy";
b_Reward_Diplomacy.Data.Type = Callbacks.Diplomacy;
b_Reward_Diplomacy.GetReprisalTable = nil;

function b_Reward_Diplomacy:GetRewardTable()
    return {self.Data.Type, self.Data.PlayerID1, self.Data.PlayerID2, self.Data.Diplomacy};
end

QuestSystemBehavior:RegisterBehavior(b_Reward_Diplomacy);

-- -------------------------------------------------------------------------- --

---
-- Removes the description of a quest from the quest book.
-- @param[type=string] _QuestName Quest name
-- @within Rewards
--
function Reward_RemoveQuest(...)
    return b_Reward_RemoveQuest:New(unpack(arg));
end

b_Reward_RemoveQuest = copy(b_Reprisal_RemoveQuest);
b_Reward_RemoveQuest.Data.Name = "Reward_RemoveQuest";
b_Reward_RemoveQuest.Data.Type = Callbacks.RemoveQuest;
b_Reward_RemoveQuest.GetReprisalTable = nil;

function b_Reward_RemoveQuest:GetRewardTable()
    return {self.Data.Type, self.Data.QuestName};
end

QuestSystemBehavior:RegisterBehavior(b_Reward_RemoveQuest);

-- -------------------------------------------------------------------------- --

---
-- Let the quest succeed.
-- @param[type=string] _QuestName Quest name
-- @within Rewards
--
function Reward_QuestSucceed(...)
    return b_Reward_QuestSucceed:New(unpack(arg));
end

b_Reward_QuestSucceed = copy(b_Reprisal_QuestSucceed);
b_Reward_QuestSucceed.Data.Name = "Reward_QuestSucceed";
b_Reward_QuestSucceed.Data.Type = Callbacks.QuestSucceed;
b_Reward_QuestSucceed.GetReprisalTable = nil;

function b_Reward_QuestSucceed:GetRewardTable()
    return {self.Data.Type, self.Data.QuestName};
end

QuestSystemBehavior:RegisterBehavior(b_Reward_QuestSucceed);

-- -------------------------------------------------------------------------- --

---
-- Let the quest fail.
-- @param[type=string] _QuestName Quest name
-- @within Rewards
--
function Reward_QuestFail(...)
    return b_Reward_QuestFail:New(unpack(arg));
end

b_Reward_QuestFail = copy(b_Reprisal_QuestFail);
b_Reward_QuestFail.Data.Name = "Reward_QuestFail";
b_Reward_QuestFail.Data.Type = Callbacks.QuestFail;
b_Reward_QuestFail.GetReprisalTable = nil;

function b_Reward_QuestFail:GetRewardTable()
    return {self.Data.Type, self.Data.QuestName};
end

QuestSystemBehavior:RegisterBehavior(b_Reward_QuestFail);

-- -------------------------------------------------------------------------- --

---
-- Interrupts the quest.
-- @param[type=string] _QuestName Quest name
-- @within Rewards
--
function Reward_QuestInterrupt(...)
    return b_Reward_QuestInterrupt:New(unpack(arg));
end

b_Reward_QuestInterrupt = copy(b_Reprisal_QuestInterrupt);
b_Reward_QuestInterrupt.Data.Name = "Reward_QuestInterrupt";
b_Reward_QuestInterrupt.Data.Type = Callbacks.QuestInterrupt;
b_Reward_QuestInterrupt.GetReprisalTable = nil;

function b_Reward_QuestInterrupt:GetRewardTable()
    return {self.Data.Type, self.Data.QuestName};
end

QuestSystemBehavior:RegisterBehavior(b_Reward_QuestInterrupt);

-- -------------------------------------------------------------------------- --

---
-- Activates the quest.
-- @param[type=string] _QuestName Quest name
-- @within Rewards
--
function Reward_QuestActivate(...)
    return b_Reward_QuestActivate:New(unpack(arg));
end

b_Reward_QuestActivate = copy(b_Reprisal_QuestActivate);
b_Reward_QuestActivate.Data.Name = "Reward_QuestActivate";
b_Reward_QuestActivate.Data.Type = Callbacks.QuestActivate;
b_Reward_QuestActivate.GetReprisalTable = nil;

function b_Reward_QuestActivate:GetRewardTable()
    return {self.Data.Type, self.Data.QuestName};
end

QuestSystemBehavior:RegisterBehavior(b_Reward_QuestActivate);

-- -------------------------------------------------------------------------- --

---
-- Restarts the quest.
-- @param[type=string] _QuestName Quest name
-- @within Rewards
--
function Reward_QuestRestart(...)
    return b_Reward_QuestRestart:New(unpack(arg));
end

b_Reward_QuestRestart = copy(b_Reprisal_QuestRestart);
b_Reward_QuestRestart.Data.Name = "Reward_QuestRestart";
b_Reward_QuestRestart.Data.Type = Callbacks.QuestRestart;
b_Reward_QuestRestart.GetReprisalTable = nil;

function b_Reward_QuestRestart:GetRewardTable()
    return {self.Data.Type, self.Data.QuestName};
end

QuestSystemBehavior:RegisterBehavior(b_Reward_QuestRestart);

-- -------------------------------------------------------------------------- --

---
-- Changes the state of a technology.
-- @param[type=string] _Technology Technology name
-- @param[type=string] _State Technology state name
-- @within Rewards
--
function Reward_Technology(...)
    return b_Reward_Technology:New(unpack(arg));
end

b_Reward_Technology = copy(b_Reprisal_Technology);
b_Reward_Technology.Data.Name = "Reward_Technology";
b_Reward_Technology.Data.Type = Callbacks.Technology;
b_Reward_Technology.GetReprisalTable = nil;

function b_Reward_Technology:GetRewardTable()
    return {self.Data.Type, self.Data.Technology, self.Data.State};
end

QuestSystemBehavior:RegisterBehavior(b_Reward_Technology);

-- -------------------------------------------------------------------------- --

---
-- Removes the exploration of an area.
-- @param[type=string] _AreaCenter Center of exploration
-- @within Rewards
--
function Reward_ConcealArea(...)
    return b_Reward_ConcealArea:New(unpack(arg));
end

b_Reward_ConcealArea = copy(b_Reprisal_ConcealArea);
b_Reward_ConcealArea.Data.Name = "Reward_ConcealArea";
b_Reward_ConcealArea.Data.Type = Callbacks.ConcealArea;
b_Reward_ConcealArea.GetReprisalTable = nil;

function b_Reward_ConcealArea:GetRewardTable()
    return {self.Data.Type, self.Data.AreaCenter};
end

QuestSystemBehavior:RegisterBehavior(b_Reward_ConcealArea);

-- -------------------------------------------------------------------------- --

---
-- Moves an entity to the destination.
-- @param[type=string] _EntityEntity to move
-- @param[type=string] _Destination Moving target of entity
-- @within Rewards
--
function Reward_Move(...)
    return b_Reward_Move:New(unpack(arg));
end

b_Reward_Move = copy(b_Reprisal_Move);
b_Reward_Move.Data.Name = "Reward_Move";
b_Reward_Move.Data.Type = Callbacks.Move;
b_Reward_Move.GetReprisalTable = nil;

function b_Reward_Move:GetRewardTable()
    return {self.Data.Type, self.Data.Entity, self.Data.Destination};
end

QuestSystemBehavior:RegisterBehavior(b_Reward_Move);

-- -------------------------------------------------------------------------- --

---
-- Replaces an script entity with a new entity of the chosen type. You can set
-- a new owner. If unchanged the entity will adopt the owner of the script
-- entity.
-- @param[type=string] _ScriptName Script name of entity
-- @param[type=string] _EntityType Entity type name
-- @within Rewards
--
function Reward_CreateEntity(...)
    return b_Reward_CreateEntity:New(unpack(arg));
end

b_Reward_CreateEntity = {
    Data = {
        Name = "Reward_CreateEntity",
        Type = Callbacks.CreateEntity
    },
};

function b_Reward_CreateEntity:AddParameter(_Index, _Parameter)
    if _Index == 1 then
        self.Data.ScriptName = _Parameter;
    elseif _Index == 2 then
        self.Data.EntityType = Entities[_Parameter];
    elseif _Index == 3 then
        if _Parameter == "-" or _Parameter == nil then
            self.Data.PlayerID = nil;
            return;
        end
        self.Data.PlayerID = tonumber(_Parameter);
    end
end

function b_Reward_CreateEntity:GetRewardTable()
    return {self.Data.Type, self.Data.ScriptName, self.Data.EntityType, self.Data.PlayerID};
end

QuestSystemBehavior:RegisterBehavior(b_Reward_CreateEntity);

-- -------------------------------------------------------------------------- --

---
-- Replaces an script entity with a military group of the chosen type. You can
-- set a new owner. If unchanged the entity will adopt the owner of the script
-- entity.
-- @param[type=string] _ScriptName Script name of entity
-- @param[type=string] _EntityType Entity type name
-- @param[type=number] _Soldiers Amount of soldiers
-- @within Rewards
--
function Reward_CreateGroup(...)
    return b_Reward_CreateGroup:New(unpack(arg));
end

b_Reward_CreateGroup = {
    Data = {
        Name = "Reward_CreateGroup",
        Type = Callbacks.CreateGroup
    },
};

function b_Reward_CreateGroup:AddParameter(_Index, _Parameter)
    if _Index == 1 then
        self.Data.ScriptName = _Parameter;
    elseif _Index == 2 then
        self.Data.EntityType = Entities[_Parameter];
    elseif _Index == 3 then
        self.Data.SoldierCount = _Parameter;
    elseif _Index == 4 then
        if _Parameter == "-" or _Parameter == nil then
            self.Data.PlayerID = nil;
            return;
        end
        self.Data.PlayerID = tonumber(_Parameter);
    end
end

function b_Reward_CreateGroup:GetRewardTable()
    return {self.Data.Type, self.Data.ScriptName, self.Data.EntityType, self.Data.SoldierCount, self.Data.PlayerID};
end

QuestSystemBehavior:RegisterBehavior(b_Reward_CreateGroup);

-- -------------------------------------------------------------------------- --

---
-- Creates an effect at the position.
-- @param[type=string] _EffectName  Name for the effect
-- @param[type=table] _Position     Position of effect
-- @param[type=string] _EffectType  Effect type name
-- @within Rewards
--
function Reward_CreateEffect(...)
    return b_Reward_CreateEffect:New(unpack(arg));
end

b_Reward_CreateEffect = {
    Data = {
        Name = "Reward_CreateEffect",
        Type = Callbacks.CreateEffect
    },
};

function b_Reward_CreateEffect:AddParameter(_Index, _Parameter)
    if _Index == 1 then
        self.Data.EffectName = _Parameter;
    elseif _Index == 2 then
        self.Data.Position = _Parameter;
    elseif _Index == 3 then
        self.Data.EffectType = GGL_Effects[_Parameter];
    end
end

function b_Reward_CreateEffect:GetRewardTable()
    return {self.Data.Type, self.Data.EffectName, self.Data.EffectType, self.Data.Position};
end

QuestSystemBehavior:RegisterBehavior(b_Reward_CreateEffect);

-- -------------------------------------------------------------------------- --

---
-- Give or remove resources from the player.
-- @param[type=string] _Resource Name for the effect
-- @param[type=number] _Amount   Menge an Rohstoffen
-- @within Rewards
--
function Reward_Resource(...)
    return b_Reward_Resource:New(unpack(arg));
end

b_Reward_Resource = {
    Data = {
        Name = "Reward_Resource",
        Type = Callbacks.Resource
    },
};

function b_Reward_Resource:AddParameter(_Index, _Parameter)
    if _Index == 1 then
        self.Data.Resource = ResourceType[_Parameter];
    elseif _Index == 2 then
        self.Data.Amount = _Parameter;
    end
end

function b_Reward_Resource:GetRewardTable()
    return {self.Data.Type, self.Data.Resource, self.Data.Amount};
end

QuestSystemBehavior:RegisterBehavior(b_Reward_Resource);

-- -------------------------------------------------------------------------- --

---
-- Creates an minimap marker or minimap pulsar at the position.
-- @param[type=string] _MarkerType Marker type name
-- @param[type=string] _Position   Position of marker
-- @within Rewards
--
function Reward_CreateMarker(...)
    return b_Reward_CreateMarker:New(unpack(arg));
end

b_Reward_CreateMarker = {
    Data = {
        Name = "Reward_CreateMarker",
        Type = Callbacks.CreateMarker
    },
};

function b_Reward_CreateMarker:AddParameter(_Index, _Parameter)
    if _Index == 1 then
        self.Data.MarkerType = MarkerTypes[_Parameter];
    elseif _Index == 2 then
        self.Data.Position = _Parameter;
    end
end

function b_Reward_CreateMarker:GetRewardTable()
    return {self.Data.Type, self.Data.MarkerType, GetPosition(self.Data.Position)};
end

QuestSystemBehavior:RegisterBehavior(b_Reward_CreateMarker);

-- -------------------------------------------------------------------------- --

---
-- Removes a minimap marker or pulsar at the position.
-- @param[type=string] _Position Position of marker
-- @within Rewards
--
function Reward_DestroyMarker(...)
    return b_Reward_DestroyMarker:New(unpack(arg));
end

b_Reward_DestroyMarker = {
    Data = {
        Name = "Reward_DestroyMarker",
        Type = Callbacks.DestroyMarker
    },
};

function b_Reward_DestroyMarker:AddParameter(_Index, _Parameter)
    if _Index == 1 then
        self.Data.Position = _Parameter;
    end
end

function b_Reward_DestroyMarker:GetRewardTable()
    return {self.Data.Type, GetPosition(self.Data.Position)};
end

QuestSystemBehavior:RegisterBehavior(b_Reward_DestroyMarker);

-- -------------------------------------------------------------------------- --

---
-- Explores an area around a script entity.
-- @param[type=string] _AreaCenter Center of exploration
-- @param[type=number] _Exploration Size of exploration
-- @within Rewards
--
function Reward_RevealArea(...)
    return b_Reward_RevealArea:New(unpack(arg));
end

b_Reward_RevealArea = {
    Data = {
        Name = "Reward_RevealArea",
        Type = Callbacks.RevealArea
    },
};

function b_Reward_RevealArea:AddParameter(_Index, _Parameter)
    if _Index == 1 then
        self.Data.AreaCenter = _Parameter;
    elseif _Index == 2 then
        self.Data.Explore = _Parameter;
    end
end

function b_Reward_RevealArea:GetRewardTable()
    return {self.Data.Type, self.Data.AreaCenter, self.Data.Explore};
end

QuestSystemBehavior:RegisterBehavior(b_Reward_RevealArea);

-- -------------------------------------------------------------------------- --

---
-- Moves an entity to the destination and replace it with an XD_ScriptEntity
-- once it enters the fog or reaches the destination.
-- @param[type=string] _Entity Entity to move
-- @param[type=string] _Target Move destination
-- @within Rewards
--
function Reward_MoveAndVanish(...)
    return b_Reward_MoveAndVanish:New(unpack(arg));
end

b_Reward_MoveAndVanish = {
    Data = {
        Name = "Reward_MoveAndVanish",
        Type = Callbacks.MapScriptFunction
    },
};

function b_Reward_MoveAndVanish:AddParameter(_Index, _Parameter)
    if _Index == 1 then
        self.Data.Entity = _Parameter;
    elseif _Index == 2 then
        self.Data.Target = _Parameter;
    end
end

function b_Reward_MoveAndVanish:GetRewardTable()
    return {self.Data.Type, {self.CustomFunction, self}};
end

function b_Reward_MoveAndVanish:CustomFunction(_Quest)
    self:Reset(_Quest);
    self.Data.JobID = MoveAndVanish(self.Data.Entity, self.Data.Target);
end

function b_Reward_MoveAndVanish:Debug(_Quest)
    if not IsExisting(self.Data.Entity) then
        dbg(_Quest, self, "Entity does not exist: " ..tostring(self.Data.Entity));
        return true;
    end
    if not IsExisting(self.Data.Target) then
        dbg(_Quest, self, "Destionation does not exist: " ..tostring(self.Data.Target));
        return true;
    end
    return false;
end

function b_Reward_MoveAndVanish:Reset(_Quest)
    if self.Data.JobID and JobIsRunning(self.Data.JobID) then
        EndJob(self.Data.JobID);
    end
    self.Data.JobID = nil;
end

QuestSystemBehavior:RegisterBehavior(b_Reward_MoveAndVanish);

-- -------------------------------------------------------------------------- --

---
-- Calls a user function as condition.
-- @param[type=string] _FunctionName function to call
-- @within Triggers
--
function Trigger_MapScriptFunction(...)
    return b_Trigger_MapScriptFunction:New(unpack(arg));
end

b_Trigger_MapScriptFunction = {
    Data = {
        Name = "Trigger_MapScriptFunction",
        Type = Conditions.MapScriptFunction
    },
};

function b_Trigger_MapScriptFunction:AddParameter(_Index, _Parameter)
    if _Index == 1 then
        self.Data.CustomFunction = _Parameter;
    end
end

function b_Trigger_MapScriptFunction:GetTriggerTable()
    return {self.Data.Type, {self.CustomFunction, self}};
end
function b_Trigger_MapScriptFunction:CustomFunction(_Quest)
    return _G[self.Data.CustomFunction](self, _Quest);
end

function b_Trigger_MapScriptFunction:Debug(_Quest)
    if (type(self.Data.CustomFunction) == "string" and _G[self.Data.CustomFunction] == nil)
    or (self.Data.CustomFunction) == nil then
        dbg(_Quest, self, "Function ist invalid:" ..tostring(self.Data.CustomFunction));
        return true;
    end
    return false;
end

QuestSystemBehavior:RegisterBehavior(b_Trigger_MapScriptFunction);

-- -------------------------------------------------------------------------- --

---
-- Does never trigger the quest.
-- @param[type=string] _FunctionName function to call
-- @within Triggers
--
function Trigger_NeverTriggered(...)
    return b_Trigger_NeverTriggered:New(unpack(arg));
end

b_Trigger_NeverTriggered = {
    Data = {
        Name = "Trigger_NeverTriggered",
        Type = Conditions.NeverTriggered
    },
};

function b_Trigger_NeverTriggered:AddParameter(_Index, _Parameter)
    if _Index == 1 then
        self.Data.CustomFunction = _Parameter;
    end
end

function b_Trigger_NeverTriggered:GetTriggerTable()
    return {self.Data.Type};
end

QuestSystemBehavior:RegisterBehavior(b_Trigger_NeverTriggered);

-- -------------------------------------------------------------------------- --

---
-- Starts the quest immediately.
-- @within Triggers
--
function Trigger_AlwaysActive(...)
    return b_Trigger_AlwaysActive:New(unpack(arg));
end

b_Trigger_AlwaysActive = {
    Data = {
        Name = "Trigger_AlwaysActive",
        Type = Conditions.Time
    },
};

function b_Trigger_AlwaysActive:AddParameter(_Index, _Parameter)
end

function b_Trigger_AlwaysActive:GetTriggerTable()
    return {self.Data.Type, 0};
end

QuestSystemBehavior:RegisterBehavior(b_Trigger_AlwaysActive);

-- -------------------------------------------------------------------------- --

---
-- Starts the quest x seconds after the game has started.
-- @param[type=number] _Time Time to wait
-- @within Triggers
--
function Trigger_Time(...)
    return b_Trigger_Time:New(unpack(arg));
end

b_Trigger_Time = {
    Data = {
        Name = "Trigger_Time",
        Type = Conditions.Time
    },
};

function b_Trigger_Time:AddParameter(_Index, _Parameter)
    if _Index == 1 then
        self.Data.Time = _Parameter;
    end
end

function b_Trigger_Time:GetTriggerTable()
    return {self.Data.Type, self.Data.Time};
end

QuestSystemBehavior:RegisterBehavior(b_Trigger_Time);

-- -------------------------------------------------------------------------- --

---
-- Starts the quest when diplomacy between quest receiver and target player
-- reaches the state.
-- @param[type=number] _PlayerID Target player id
-- @param[type=string] _DiplomacyState Diplomacy state
-- @within Triggers
--
function Trigger_Diplomacy(...)
    return b_Trigger_Diplomacy:New(unpack(arg));
end

b_Trigger_Diplomacy = {
    Data = {
        Name = "Trigger_Diplomacy",
        Type = Conditions.Diplomacy
    },
};

function b_Trigger_Diplomacy:AddParameter(_Index, _Parameter)
    if _Index == 1 then
        self.Data.PlayerID = _Parameter;
    elseif _Index == 2 then
        self.Data.DiplomacyState = Diplomacy[_Parameter];
    end
end

function b_Trigger_Diplomacy:GetTriggerTable()
    return {self.Data.Type, self.Data.PlayerID, self.Data.DiplomacyState};
end

QuestSystemBehavior:RegisterBehavior(b_Trigger_Diplomacy);

-- -------------------------------------------------------------------------- --

---
-- Starts the quest when any briefing linked to the quest is finished. You can
-- choose either success or failure briefing or ignore the type entirely!
-- @param[type=string] _QuestName Linked quest
-- @within Triggers
--
function Trigger_Briefing(...)
    return b_Trigger_Briefing:New(unpack(arg));
end

b_Trigger_Briefing = {
    Data = {
        Name = "Trigger_Briefing",
        Type = Conditions.MapScriptFunction
    },
};

function b_Trigger_Briefing:AddParameter(_Index, _Parameter)
    if _Index == 1 then
        self.Data.BriefingQuest = _Parameter;
    elseif _Index == 2 then
        self.Data.Kind = _Parameter;
    end
end

function b_Trigger_Briefing:CustomFunction(_Quest)
    local Quest = QuestSystem.Quests[GetQuestID(self.Data.BriefingQuest)];
    if self.Data.Kind == "Any" then
        if Quest and Quest.m_SuccessBriefing and QuestSystem.Briefings[Quest.m_SuccessBriefing] == true then
            return true;
        end
        if Quest and Quest.m_FailureBriefing and QuestSystem.Briefings[Quest.m_FailureBriefing] == true then
            return true;
        end
    end
    if self.Data.Kind == "Success" then
        return (Quest and Quest.m_SuccessBriefing and QuestSystem.Briefings[Quest.m_SuccessBriefing] == true);
    end
    if self.Data.Kind == "Failure" then
        return (Quest and Quest.m_FailureBriefing and QuestSystem.Briefings[Quest.m_FailureBriefing] == true);
    end
    return false;
end

function b_Trigger_Briefing:GetTriggerTable()
    return {self.Data.Type, {self.CustomFunction, self}};
end

function b_Trigger_Briefing:CustomFunction(_Quest)
    local Quest = QuestSystem.Quests[GetQuestID(self.Data.BriefingQuest)];
    if self.Data.Kind == nil or self.Data.Kind == "Any" then
        return QuestSystem.Briefings[Quest.m_SuccessBriefing] == true or QuestSystem.Briefings[Quest.m_FailureBriefing] == true;
    elseif self.Data.Kind == "Success" then
        return QuestSystem.Briefings[Quest.m_SuccessBriefing] == true;
    elseif self.Data.Kind == "Failure" then
        return QuestSystem.Briefings[Quest.m_FailureBriefing] == true;
    end
    return false;
end

function b_Trigger_Briefing:Debug()
    return false;
end

QuestSystemBehavior:RegisterBehavior(b_Trigger_Briefing);

-- -------------------------------------------------------------------------- --

---
-- Starts the quest when the success briefing linked to the quest is finished.
-- A quest must succeed in order to start a success briefing!
-- @param[type=string] _QuestName Linked quest
-- @within Triggers
--
function Trigger_BriefingSuccess(...)
    return b_Trigger_BriefingSuccess:New(unpack(arg));
end

b_Trigger_BriefingSuccess = {
    Data = {
        Name = "Trigger_BriefingSuccess",
        Type = Conditions.MapScriptFunction
    },
};

function b_Trigger_BriefingSuccess:AddParameter(_Index, _Parameter)
    if _Index == 1 then
        self.Data.BriefingQuest = _Parameter;
    end
end

function b_Trigger_BriefingSuccess:CustomFunction(_Quest)
    local Quest = QuestSystem.Quests[GetQuestID(self.Data.BriefingQuest)];
    if Quest then
        if Quest.m_SuccessBriefing and QuestSystem.Briefings[Quest.m_SuccessBriefing] == true then
            return true;
        end
    end
    return false
end

function b_Trigger_BriefingSuccess:GetTriggerTable()
    return {self.Data.Type, {self.CustomFunction, self}};
end

function b_Trigger_BriefingSuccess:Debug(_Quest)
    local Quest = QuestSystem.Quests[GetQuestID(self.Data.BriefingQuest)];
    if not Quest or not Quest.m_SuccessBriefing then
        dbg(_Quest, self, "Quest does not have a success briefing attached!");
    end
    return false;
end

QuestSystemBehavior:RegisterBehavior(b_Trigger_BriefingSuccess);

-- -------------------------------------------------------------------------- --

---
-- Starts the quest when the failure briefing linked to the quest is finished.
-- A quest must fail in order to start a failure briefing!
-- @param[type=string] _QuestName Linked quest
-- @within Triggers
--
function Trigger_BriefingFailure(...)
    return b_Trigger_BriefingFailure:New(unpack(arg));
end

b_Trigger_BriefingFailure = {
    Data = {
        Name = "Trigger_BriefingFailure",
        Type = Conditions.MapScriptFunction
    },
};

function b_Trigger_BriefingFailure:AddParameter(_Index, _Parameter)
    if _Index == 1 then
        self.Data.BriefingQuest = _Parameter;
    end
end

function b_Trigger_BriefingFailure:CustomFunction(_Quest)
    local Quest = QuestSystem.Quests[GetQuestID(self.Data.BriefingQuest)];
    if Quest then
        if Quest.m_FailureBriefing and QuestSystem.Briefings[Quest.m_FailureBriefing] == true then
            return true;
        end
    end
    return false;
end

function b_Trigger_BriefingFailure:GetTriggerTable()
    return {self.Data.Type, {self.CustomFunction, self}};
end

function b_Trigger_BriefingFailure:Debug(_Quest)
    local Quest = QuestSystem.Quests[GetQuestID(self.Data.BriefingQuest)];
    if not Quest or not Quest.m_FailureBriefing then
        dbg(_Quest, self, "Quest does not have a failure briefing attached!");
    end
    return false;
end

QuestSystemBehavior:RegisterBehavior(b_Trigger_BriefingFailure);

-- -------------------------------------------------------------------------- --

---
-- Starts the quest on the next payday of the quest receiver.
-- @within Triggers
--
function Trigger_Payday(...)
    return b_Trigger_Payday:New(unpack(arg));
end

b_Trigger_Payday = {
    Data = {
        Name = "Trigger_Payday",
        Type = Conditions.Payday
    },
};

function b_Trigger_Payday:AddParameter(_Index, _Parameter)
end

function b_Trigger_Payday:GetTriggerTable()
    return {self.Data.Type};
end

QuestSystemBehavior:RegisterBehavior(b_Trigger_Payday);

-- -------------------------------------------------------------------------- --

---
-- Starts the quest after an entity has been destroyed. The quest is triggered
-- when the entity is destroyed either by script or by another player.
-- @param[type=string] _ScriptName Script name of entiry
-- @within Triggers
--
function Trigger_EntityDestroyed(...)
    return b_Trigger_EntityDestroyed:New(unpack(arg));
end

b_Trigger_EntityDestroyed = {
    Data = {
        Name = "Trigger_EntityDestroyed",
        Type = Conditions.EntityDestroyed
    },
};

function b_Trigger_EntityDestroyed:AddParameter(_Index, _Parameter)
    if _Index == 1 then
        self.Data.ScriptName = _Parameter;
    end
end

function b_Trigger_EntityDestroyed:GetTriggerTable()
    return {self.Data.Type, self.Data.ScriptName};
end

QuestSystemBehavior:RegisterBehavior(b_Trigger_EntityDestroyed);

-- -------------------------------------------------------------------------- --

---
-- Starts the quest when a weather state is activated
-- @param[type=number] _StateID Weather state to activate
-- @within Triggers
--
function Trigger_WeatherState(...)
    return b_Trigger_WeatherState:New(unpack(arg));
end

b_Trigger_WeatherState = {
    Data = {
        Name = "Trigger_WeatherState",
        Type = Conditions.WeatherState
    },
};

function b_Trigger_WeatherState:AddParameter(_Index, _Parameter)
    if _Index == 1 then
        self.Data.StateID = WeatherStates[_Parameter];
    end
end

function b_Trigger_WeatherState:GetTriggerTable()
    return {self.Data.Type, self.Data.StateID};
end

QuestSystemBehavior:RegisterBehavior(b_Trigger_WeatherState);

-- -------------------------------------------------------------------------- --

---
-- Starts the quest when two other quest are finished with the same result.
-- @param[type=string] _QuestNameA First quest
-- @param[type=string] _QuestNameB Second quest
-- @param[type=string] _Result Expected quest result
-- @within Triggers
--
function Trigger_QuestAndQuest(...)
    return b_Trigger_QuestAndQuest:New(unpack(arg));
end

b_Trigger_QuestAndQuest = {
    Data = {
        Name = "Trigger_QuestAndQuest",
        Type = Conditions.QuestAndQuest
    },
};

function b_Trigger_QuestAndQuest:AddParameter(_Index, _Parameter)
    if _Index == 1 then
        self.Data.QuestA = _Parameter;
    elseif _Index == 2 then
        self.Data.QuestB = _Parameter;
    elseif _Index == 3 then
        self.Data.Result = QuestResults[_Parameter];
    end
end

function b_Trigger_QuestAndQuest:GetTriggerTable()
    return {self.Data.Type, self.Data.QuestA, self.Data.QuestB, self.Data.Result};
end

QuestSystemBehavior:RegisterBehavior(b_Trigger_QuestAndQuest);

-- -------------------------------------------------------------------------- --

---
-- Starts the quest when one or both quest finished with the expected result.
-- @param[type=string] _QuestNameA First quest
-- @param[type=string] _QuestNameB Second quest
-- @param[type=string] _Result Expected quest result
-- @within Triggers
--
function Trigger_QuestOrQuest(...)
    return b_Trigger_QuestOrQuest:New(unpack(arg));
end

b_Trigger_QuestOrQuest = {
    Data = {
        Name = "Trigger_QuestOrQuest",
        Type = Conditions.QuestOrQuest
    },
};

function b_Trigger_QuestOrQuest:AddParameter(_Index, _Parameter)
    if _Index == 1 then
        self.Data.QuestA = _Parameter;
    elseif _Index == 2 then
        self.Data.QuestB = _Parameter;
    elseif _Index == 3 then
        self.Data.Result = QuestResults[_Parameter];
    end
end

function b_Trigger_QuestOrQuest:GetTriggerTable()
    return {self.Data.Type, self.Data.QuestA, self.Data.QuestB, self.Data.Result};
end

QuestSystemBehavior:RegisterBehavior(b_Trigger_QuestOrQuest);

-- -------------------------------------------------------------------------- --

---
-- Starts the quest when one quest but not the other finished with the expected
-- result.
-- @param[type=string] _QuestNameA First quest
-- @param[type=string] _QuestNameB Second quest
-- @param[type=string] _Result Expected quest result
-- @within Triggers
--
function Trigger_QuestXorQuest(...)
    return b_Trigger_QuestXorQuest:New(unpack(arg));
end

b_Trigger_QuestXorQuest = {
    Data = {
        Name = "Trigger_QuestXorQuest",
        Type = Conditions.QuestXorQuest
    },
};

function b_Trigger_QuestXorQuest:AddParameter(_Index, _Parameter)
    if _Index == 1 then
        self.Data.QuestA = _Parameter;
    elseif _Index == 2 then
        self.Data.QuestB = _Parameter;
    elseif _Index == 3 then
        self.Data.Result = QuestResults[_Parameter];
    end
end

function b_Trigger_QuestXorQuest:GetTriggerTable()
    return {self.Data.Type, self.Data.QuestA, self.Data.QuestB, self.Data.Result};
end

QuestSystemBehavior:RegisterBehavior(b_Trigger_QuestXorQuest);

-- -------------------------------------------------------------------------- --

---
-- The player must win a quest. If the quest fails this behavior will fail.
-- @param[type=string] _QuestName Quest name
-- @within Goals
--
function Goal_WinQuest(...)
    return b_Goal_WinQuest:New(unpack(arg));
end

b_Goal_WinQuest = {
    Data = {
        Name = "Goal_WinQuest",
        Type = Objectives.Quest
    },
};

function b_Goal_WinQuest:AddParameter(_Index, _Parameter)
    if _Index == 1 then
        self.Data.QuestName = _Parameter;
    end
end

function b_Goal_WinQuest:GetGoalTable()
    return {self.Data.Type, self.Data.QuestName, QuestResults.Success, true};
end

QuestSystemBehavior:RegisterBehavior(b_Goal_WinQuest);

-- -------------------------------------------------------------------------- --

---
-- The player must fail a quest. If the quest does not fails this behavior
-- will fail.
-- @param[type=string] _QuestName Quest name
-- @within Goals
--
function Goal_FailQuest(...)
    return b_Goal_FailQuest:New(unpack(arg));
end

b_Goal_FailQuest = {
    Data = {
        Name = "Goal_FailQuest",
        Type = Objectives.Quest
    },
};

function b_Goal_FailQuest:AddParameter(_Index, _Parameter)
    if _Index == 1 then
        self.Data.QuestName = _Parameter;
    end
end

function b_Goal_FailQuest:GetGoalTable()
    return {self.Data.Type, self.Data.QuestName, QuestResults.Failure, true};
end

QuestSystemBehavior:RegisterBehavior(b_Goal_FailQuest);

-- -------------------------------------------------------------------------- --

---
-- The player must finish a quest. The result does not matter.
-- @param[type=string] _QuestName Quest name
-- @within Goals
--
function Goal_CompleteQuest(...)
    return b_Goal_CompleteQuest:New(unpack(arg));
end

b_Goal_CompleteQuest = {
    Data = {
        Name = "Goal_CompleteQuest",
        Type = Objectives.Quest
    },
};

function b_Goal_CompleteQuest:AddParameter(_Index, _Parameter)
    if _Index == 1 then
        self.Data.QuestName = _Parameter;
    end
end

function b_Goal_CompleteQuest:GetGoalTable()
    return {self.Data.Type, self.Data.QuestName, nil, false};
end

QuestSystemBehavior:RegisterBehavior(b_Goal_CompleteQuest);

-- -------------------------------------------------------------------------- --
-- Custom Behavior                                                            --
-- -------------------------------------------------------------------------- --

---
-- This goal succeeds if the headquarter entity of the player is destroyed.
-- In addition, all buildings and settlers of this player are destroyed. If an
-- AI is active it will be deactivated.
-- @param[type=number] _PlayerID id of player
-- @param[type=string] _HQ HQ building of player
-- @within Goals
--
function Goal_DestroyPlayer(...)
    return b_Goal_DestroyPlayer:New(unpack(arg));
end

b_Goal_DestroyPlayer = {
    Data = {
        Name = "Goal_DestroyPlayer",
        Type = Objectives.MapScriptFunction
    },
};

function b_Goal_DestroyPlayer:AddParameter(_Index, _Parameter)
    if _Index == 1 then
        self.Data.PlayerID = _Parameter;
    elseif _Index == 2 then
        self.Data.Headquarter = _Parameter;
    end
end

function b_Goal_DestroyPlayer:GetGoalTable()
    return {self.Data.Type, {self.CustomFunction, self}};
end

function b_Goal_DestroyPlayer:CustomFunction(_Quest)
    if not IsExisting(self.Data.Headquarter) then
        if AiController.Players[self.Data.PlayerID] then
            AiController:DestroyPlayer(self.Data.PlayerID);
        end

        local PlayerEntities = GetPlayerEntities(self.Data.PlayerID, 0);
        for i= 1, table.getn(PlayerEntities), 1 do 
            if Logic.IsSettler(PlayerEntities[i]) == 1 or Logic.IsBuilding(PlayerEntities[i]) == 1 then
                if Logic.GetEntityHealth(PlayerEntities[i]) > 0 then
                    Logic.HurtEntity(PlayerEntities[i], Logic.GetEntityHealth(PlayerEntities[i]));
                end
            end
        end
        return true;
    end
end

function b_Goal_DestroyPlayer:Debug(_Quest)
    if not IsExisting(self.Data.Headquarter) then
        dbg(_Quest, self, "Headquarter of player " ..tostring(self.Data.PlayerID).. " is already destroyed!");
        return true;
    end
    if not Logic.IsBuilding(GetID(self.Data.Headquarter)) == 0 then
        dbg(_Quest, self, "Headquarter must be a building!");
        return true;
    end
    return false;
end

function b_Goal_DestroyPlayer:Reset(_Quest)
end

QuestSystemBehavior:RegisterBehavior(b_Goal_DestroyPlayer);

-- -------------------------------------------------------------------------- --

---
-- The player must destroy the army. For spawned armies the lifethread must
-- also be destroyed. Armies that can recruit new leader are defeated after
-- the ai is defeated.
-- @param[type=number] _PlayerID id of player
-- @param[type=string] _ArmyName Name of army
-- @within Goals
--
function Goal_DestroyArmy(...)
    return b_Goal_DestroyArmy:New(unpack(arg));
end

b_Goal_DestroyArmy = {
    Data = {
        Name = "Goal_DestroyArmy",
        Type = Objectives.MapScriptFunction
    },
};

function b_Goal_DestroyArmy:AddParameter(_Index, _Parameter)
    if _Index == 1 then
        self.Data.PlayerID = _Parameter;
    elseif _Index == 2 then
        self.Data.ArmyName = _Parameter;
    end
end

function b_Goal_DestroyArmy:GetGoalTable()
    return {self.Data.Type, {self.CustomFunction, self}};
end

function b_Goal_DestroyArmy:CustomFunction(_Quest)
    local Army = GetArmy(self.Data.ArmyName);
    if not Army then
        return true;
    end
    if Army:IsDead() then
        return true;
    end
end

function b_Goal_DestroyArmy:Debug(_Quest)
    local Army = GetArmy(self.Data.ArmyName);
    if Army == nil then
        local Player = tostring(self.Data.PlayerID);
        dbg(_Quest, self, "Army " ..tostring(self.Data.ArmyName).. " does not exist!");
        return true;
    end
    return false;
end

function b_Goal_DestroyArmy:Reset(_Quest)
end

QuestSystemBehavior:RegisterBehavior(b_Goal_DestroyArmy);

-- -------------------------------------------------------------------------- --

---
-- Restarts the quest and force it to be active immedaitly.
-- @param[type=string] _QuestName Quest name
-- @within Reprisals
--
function Reprisal_QuestRestartForceActive(...)
    return b_Reprisal_QuestRestartForceActive:New(unpack(arg));
end

b_Reprisal_QuestRestartForceActive = {
    Data = {
        Name = "Reprisal_QuestRestartForceActive",
        Type = Callbacks.MapScriptFunction
    },
};

function b_Reprisal_QuestRestartForceActive:AddParameter(_Index, _Parameter)
    if _Index == 1 then
        self.Data.QuestName = _Parameter;
    end
end

function b_Reprisal_QuestRestartForceActive:GetReprisalTable()
    return {self.Data.Type, {self.CustomFunction, self}};
end

function b_Reprisal_QuestRestartForceActive:CustomFunction(_Quest)
    local QuestID = GetQuestID(self.Data.QuestName);
    if QuestID == 0 then
        return;
    end
    if QuestSystem.Quests[QuestID].m_State == QuestStates.Over then
        QuestSystem.Quests[QuestID].m_State = QuestStates.Inactive;
        QuestSystem.Quests[QuestID].m_Result = QuestResults.Undecided;
        QuestSystem.Quests[QuestID]:Reset();
        Trigger.RequestTrigger(Events.LOGIC_EVENT_EVERY_SECOND, "", QuestSystem.QuestLoop, 1, {}, {QuestSystem.Quests[QuestID].m_QuestID});
        QuestSystem.Quests[QuestID]:Trigger();
    end
end

function b_Reprisal_QuestRestartForceActive:Debug(_Quest)
    local QuestID = GetQuestID(self.Data.QuestName);
    if QuestID == 0 then
        dbg(_Quest, self, "Quest '" ..tostring(self.Data.QuestName).. "' does not exist!");
        return true;
    end
    return false;
end

function b_Reprisal_QuestRestartForceActive:Reset(_Quest)
end

QuestSystemBehavior:RegisterBehavior(b_Reprisal_QuestRestart);

-- -------------------------------------------------------------------------- --

---
-- Changes the vulnerablty of a settler or building.
-- @param[type=string] _ScriptName Entity to affect
-- @param[type=boolean] _Flag  State of vulnerablty
-- @within Reprisals
--
function Reprisal_SetVulnerablity(...)
    return b_Reprisal_SetVulnerablity:New(unpack(arg));
end

b_Reprisal_SetVulnerablity = {
    Data = {
        Name = "Reprisal_SetVulnerablity",
        Type = Callbacks.MapScriptFunction
    },
};

function b_Reprisal_SetVulnerablity:AddParameter(_Index, _Parameter)
    if _Index == 1 then
        self.Data.Entity = _Parameter;
    elseif _Index == 2 then
        self.Data.Flag = _Parameter;
    end
end

function b_Reprisal_SetVulnerablity:GetReprisalTable()
    return {self.Data.Type, {self.CustomFunction, self}};
end

function b_Reprisal_SetVulnerablity:CustomFunction(_Quest)
    if not IsExisting(self.Data.Entity) then
        return;
    end
    if self.Data.Flag then
        MakeVulnerable(GetID(self.Data.Entity));
    else
        MakeInvulnerable(GetID(self.Data.Entity));
    end
end

function b_Reprisal_SetVulnerablity:Debug(_Quest)
    local EntityID = GetID(self.Data.Entity);
    if not IsExisting(EntityID) then
        dbg(_Quest, self, "Target entity is destroyed!");
        return true;
    end
    if Logic.IsSettler(EntityID) == 0 and Logic.IsBuilding(EntityID) == 0 then
        dbg(_Quest, self, "Only settlers and buildings allowed!");
        return true;
    end
    return false;
end

QuestSystemBehavior:RegisterBehavior(b_Reprisal_SetVulnerablity);

-- -------------------------------------------------------------------------- --

---
-- Opens a palisade or a wall gate.
-- @param[type=string] _Name Name of gate
-- @within Reprisals
--
function Reprisal_OpenGate(...)
    return b_Reprisal_OpenGate:New(unpack(arg));
end

b_Reprisal_OpenGate = {
    Data = {
        Name = "Reprisal_OpenGate",
        Type = Callbacks.MapScriptFunction
    },
};

function b_Reprisal_OpenGate:AddParameter(_Index, _Parameter)
    if _Index == 1 then
        self.Data.Entity = _Parameter;
    end
end

function b_Reprisal_OpenGate:GetReprisalTable()
    return {self.Data.Type, {self.CustomFunction, self}};
end

function b_Reprisal_OpenGate:CustomFunction(_Quest)
    if not IsExisting(self.Data.Entity) then
        return;
    end
    local TypeName = Logic.GetEntityTypeName(Logic.GetEntityType(GetID(self.Data.Entity)));
    if TypeName == "XD_PalisadeGate1" then
        ReplaceEntity(self.Data.Entity, Entities.XD_PalisadeGate2);
    elseif TypeName == "XD_DarkWallStraightGate_Closed" then
        ReplaceEntity(self.Data.Entity, Entities.XD_DarkWallStraightGate);
    elseif TypeName == "XD_WallStraightGate_Closed" then
        ReplaceEntity(self.Data.Entity, Entities.XD_WallStraightGate);
    end
end

function b_Reprisal_OpenGate:Debug(_Quest)
    local EntityID = GetID(self.Data.Entity);
    if not IsExisting(EntityID) then
        dbg(_Quest, self, "Gate does not exist!");
        return true;
    end
    return false;
end

QuestSystemBehavior:RegisterBehavior(b_Reprisal_OpenGate);

-- -------------------------------------------------------------------------- --

---
-- Closes a palisade or a wall gate.
-- @param[type=string] _Name Name of gate
-- @within Reprisals
--
function Reprisal_CloseGate(...)
    return b_Reprisal_CloseGate:New(unpack(arg));
end

b_Reprisal_CloseGate = copy(b_Reprisal_OpenGate);
b_Reprisal_CloseGate.Data.Name = "Reprisal_CloseGate";

function b_Reprisal_CloseGate:CustomFunction(_Quest)
    if not IsExisting(self.Data.Entity) then
        return;
    end
    local TypeName = Logic.GetEntityTypeName(Logic.GetEntityType(GetID(self.Data.Entity)));
    if TypeName == "XD_PalisadeGate2" then
        ReplaceEntity(self.Data.Entity, Entities.XD_PalisadeGate1);
    elseif TypeName == "XD_DarkWallStraightGate" then
        ReplaceEntity(self.Data.Entity, Entities.XD_DarkWallStraightGate_Closed);
    elseif TypeName == "XD_WallStraightGate" then
        ReplaceEntity(self.Data.Entity, Entities.XD_WallStraightGate_Closed);
    end
end

QuestSystemBehavior:RegisterBehavior(b_Reprisal_CloseGate);

-- -------------------------------------------------------------------------- --

---
-- Opens a palisade or a wall gate.
-- @param[type=string] _Name Name of gate
-- @within Rewards
--
function Reward_OpenGate(...)
    return b_Reward_OpenGate:New(unpack(arg));
end

b_Reward_OpenGate = copy(b_Reprisal_OpenGate);
b_Reward_OpenGate.Data.Name = "Reward_OpenGate";
b_Reward_OpenGate.Data.Type = Callbacks.MapScriptFunction;
b_Reward_OpenGate.GetReprisalTable = nil;

function b_Reward_OpenGate:GetRewardTable()
    return {self.Data.Type, {self.CustomFunction, self}};
end

QuestSystemBehavior:RegisterBehavior(b_Reward_OpenGate);

-- -------------------------------------------------------------------------- --

---
-- Closes a palisade or a wall gate.
-- @param[type=string] _Name Name of gate
-- @within Rewards
--
function Reward_CloseGate(...)
    return b_Reward_CloseGate:New(unpack(arg));
end

b_Reward_CloseGate = copy(b_Reprisal_CloseGate);
b_Reward_CloseGate.Data.Name = "Reward_CloseGate";
b_Reward_CloseGate.Data.Type = Callbacks.MapScriptFunction;
b_Reward_CloseGate.GetReprisalTable = nil;

function b_Reward_CloseGate:GetRewardTable()
    return {self.Data.Type, {self.CustomFunction, self}};
end

QuestSystemBehavior:RegisterBehavior(b_Reward_CloseGate);

-- -------------------------------------------------------------------------- --

---
-- Changes the vulnerablty of a settler or building.
-- @param[type=string] _ScriptName Entity to affect
-- @param[type=boolean] _Flag  State of vulnerablty
-- @within Rewards
--
function Reward_SetVulnerablity(...)
    return b_Reward_SetVulnerablity:New(unpack(arg));
end

b_Reward_SetVulnerablity = copy(b_Reprisal_SetVulnerablity);
b_Reward_SetVulnerablity.Data.Name = "Reward_SetVulnerablity";
b_Reward_SetVulnerablity.Data.Type = Callbacks.MapScriptFunction;
b_Reward_SetVulnerablity.GetReprisalTable = nil;

function b_Reward_SetVulnerablity:GetRewardTable()
    return {self.Data.Type, {self.CustomFunction, self}};
end

QuestSystemBehavior:RegisterBehavior(b_Reward_SetVulnerablity);

-- -------------------------------------------------------------------------- --

---
-- Restarts the quest and force it to be active immedaitly.
-- @param[type=string] _QuestName Quest name
-- @within Rewards
--
function Reward_QuestRestartForceActive(...)
    return b_Reward_QuestRestartForceActive:New(unpack(arg));
end

b_Reward_QuestRestartForceActive = copy(b_Reprisal_QuestRestartForceActive);
b_Reward_QuestRestartForceActive.Data.Name = "Reward_QuestRestartForceActive";
b_Reward_QuestRestartForceActive.Data.Type = Callbacks.QuestRestartForceActive;
b_Reward_QuestRestartForceActive.GetReprisalTable = nil;

function b_Reward_QuestRestartForceActive:GetRewardTable()
    return {self.Data.Type, self.Data.QuestName};
end

QuestSystemBehavior:RegisterBehavior(b_Reward_QuestRestartForceActive);

-- -------------------------------------------------------------------------- --

---
-- Creates an merchant with up to 4 offers. Each offer purchases a fixed
-- amount of a resource for 1000 units of gold. Default inflation will be used.
-- @param[type=string] _Merchant Merchant name
-- @param[type=string] _O1 Resourcetype on sale
-- @param[type=number] _A1 Quantity to post
-- @param[type=string] _O2 Resourcetype on sale
-- @param[type=number] _A2 Quantity to post
-- @param[type=string] _O3 Resourcetype on sale
-- @param[type=number] _A3 Quantity to post
-- @param[type=string] _O4 Resourcetype on sale
-- @param[type=number] _A4 Quantity to post
-- @within Rewards
--
function Reward_OpenResourceSale(...)
    return b_Reward_OpenResourceSale:New(unpack(arg));
end

b_Reward_OpenResourceSale = {
    Data = {
        Name = "Reward_OpenResourceSale",
        Type = Callbacks.MapScriptFunction
    },
};

function b_Reward_OpenResourceSale:AddParameter(_Index, _Parameter)
    if _Index == 1 then
        self.Data.Merchant = _Parameter;
    elseif _Index == 2 then
        self.Data.OfferType1 = _Parameter;
    elseif _Index == 3 then
        self.Data.OfferAmount1 = _Parameter;
    elseif _Index == 4 then
        self.Data.OfferType2 = _Parameter;
    elseif _Index == 5 then
        self.Data.OfferAmount2 = _Parameter;
    elseif _Index == 6 then
        self.Data.OfferType3 = _Parameter;
    elseif _Index == 7 then
        self.Data.OfferAmount3 = _Parameter;
    elseif _Index == 8 then
        self.Data.OfferType4 = _Parameter;
    elseif _Index == 9 then
        self.Data.OfferAmount4 = _Parameter;
    end
end

function b_Reward_OpenResourceSale:GetRewardTable()
    return {self.Data.Type, {self.CustomFunction, self}};
end

function b_Reward_OpenResourceSale:CustomFunction(_Quest)
    local ResourceGoldRatio   = {
        ["Clay"]   = 1250,
        ["Wood"]   = 1400,
        ["Stone"]  = 1150,
        ["Iron"]   = 1100,
        ["Sulfur"] = 850,
    };

    if Interaction.IO[self.Data.Merchant] then
        Interaction.IO[self.Data.Merchant]:Deactivate();
    end

    local NPC = new(NonPlayerMerchant, self.Data.Merchant);
    if self.Data.OfferType1 ~= nil and self.Data.OfferType1 ~= "-" then
        NPC:AddResourceOffer(ResourceType.Gold, 1000, {[self.Data.OfferType1] = ResourceGoldRatio[self.Data.OfferType1] or 1000}, self.Data.OfferAmount1, 3*60);
    end
    if self.Data.OfferType2 ~= nil and self.Data.OfferType2 ~= "-" then
        NPC:AddResourceOffer(ResourceType.Gold, 1000, {[self.Data.OfferType2] = ResourceGoldRatio[self.Data.OfferType2] or 1000}, self.Data.OfferAmount2, 3*60);
    end
    if self.Data.OfferType3 ~= nil and self.Data.OfferType3 ~= "-" then
        NPC:AddResourceOffer(ResourceType.Gold, 1000, {[self.Data.OfferType3] = ResourceGoldRatio[self.Data.OfferType3] or 1000}, self.Data.OfferAmount3, 3*60);
    end
    if self.Data.OfferType4 ~= nil and self.Data.OfferType4 ~= "-" then
        NPC:AddResourceOffer(ResourceType.Gold, 1000, {[self.Data.OfferType4] = ResourceGoldRatio[self.Data.OfferType4] or 1000}, self.Data.OfferAmount4, 3*60);
    end
    NPC:Activate();
end

function b_Reward_OpenResourceSale:Debug(_Quest)
    for i = 1, 4, 1 do
        if self.Data["OfferType" ..i] and self.Data["OfferType" ..i] == ResourceType.Gold then
            dbg(_Quest, self, "Selling gold is not allowed!");
            return true;
        end
    end
    return false;
end

function b_Reward_OpenResourceSale:Reset(_Quest)
end

QuestSystemBehavior:RegisterBehavior(b_Reward_OpenResourceSale);

-- -------------------------------------------------------------------------- --

---
-- Creates an merchant with up to 4 offers. Each offer sells 1000 units of a
-- resource for a fixed amount of gold. Default inflation will be used.
-- @param[type=string] _Merchant Merchant name
-- @param[type=string] _O1 Resourcetype on sale
-- @param[type=number] _A1 Quantity to post
-- @param[type=string] _O2 Resourcetype on sale
-- @param[type=number] _A2 Quantity to post
-- @param[type=string] _O3 Resourcetype on sale
-- @param[type=number] _A3 Quantity to post
-- @param[type=string] _O4 Resourcetype on sale
-- @param[type=number] _A4 Quantity to post
-- @within Rewards
--
function Reward_OpenResourcePurchase(...)
    return b_Reward_OpenResourcePurchase:New(unpack(arg));
end

b_Reward_OpenResourcePurchase = {
    Data = {
        Name = "Reward_OpenResourcePurchase",
        Type = Callbacks.MapScriptFunction
    },
};

function b_Reward_OpenResourcePurchase:AddParameter(_Index, _Parameter)
    if _Index == 1 then
        self.Data.Merchant = _Parameter;
    elseif _Index == 2 then
        self.Data.OfferType1 = ResourceType[_Parameter];
    elseif _Index == 3 then
        self.Data.OfferAmount1 = _Parameter;
    elseif _Index == 4 then
        self.Data.OfferType2 = ResourceType[_Parameter];
    elseif _Index == 5 then
        self.Data.OfferAmount2 = _Parameter;
    elseif _Index == 6 then
        self.Data.OfferType3 = ResourceType[_Parameter];
    elseif _Index == 7 then
        self.Data.OfferAmount3 = _Parameter;
    elseif _Index == 8 then
        self.Data.OfferType4 = ResourceType[_Parameter];
    elseif _Index == 9 then
        self.Data.OfferAmount4 = _Parameter;
    end
end

function b_Reward_OpenResourcePurchase:GetRewardTable()
    return {self.Data.Type, {self.CustomFunction, self}};
end

function b_Reward_OpenResourcePurchase:CustomFunction(_Quest)
    local ResourceGoldRatio   = {
        [ResourceType.Clay]   = 750,
        [ResourceType.Wood]   = 600,
        [ResourceType.Stone]  = 850,
        [ResourceType.Iron]   = 900,
        [ResourceType.Sulfur] = 1150,
    };

    if Interaction.IO[self.Data.Merchant] then
        Interaction.IO[self.Data.Merchant]:Deactivate();
    end

    local NPC = new(NonPlayerMerchant, self.Data.Merchant);
    if self.Data.OfferType1 then
        NPC:AddResourceOffer(self.Data.OfferType1, 1000, {Gold = ResourceGoldRatio[self.Data.OfferType1] or 1000}, self.Data.OfferAmount1, 3*60);
    end
    if self.Data.OfferType2 then
        NPC:AddResourceOffer(self.Data.OfferType2, 1000, {Gold = ResourceGoldRatio[self.Data.OfferType2] or 1000}, self.Data.OfferAmount2, 3*60);
    end
    if self.Data.OfferType3 then
        NPC:AddResourceOffer(self.Data.OfferType3, 1000, {Gold = ResourceGoldRatio[self.Data.OfferType3] or 1000}, self.Data.OfferAmount3, 3*60);
    end
    if self.Data.OfferType4 then
        NPC:AddResourceOffer(self.Data.OfferType4, 1000, {Gold = ResourceGoldRatio[self.Data.OfferType4] or 1000}, self.Data.OfferAmount4, 3*60);
    end
    NPC:Activate();
end

function b_Reward_OpenResourcePurchase:Debug(_Quest)
    for i = 1, 4, 1 do
        if self.Data["OfferType" ..i] and self.Data["OfferType" ..i] == ResourceType.Gold then
            dbg(_Quest, self, "Purchasing gold is not allowed!");
            return true;
        end
    end
    return false;
end

function b_Reward_OpenResourcePurchase:Reset(_Quest)
end

QuestSystemBehavior:RegisterBehavior(b_Reward_OpenResourcePurchase);

-- -------------------------------------------------------------------------- --

---
-- Creates an mercenary merchant with up to 4 offers.
-- Default inflation will be used.
-- @param[type=string] _Merchant Merchant name
-- @param[type=string] _O1 Resourcetype on sale
-- @param[type=number] _C1 Gold costs
-- @param[type=number] _A1 Quantity to post
-- @param[type=string] _O2 Resourcetype on sale
-- @param[type=number] _C2 Gold costs
-- @param[type=number] _A2 Quantity to post
-- @param[type=string] _O3 Resourcetype on sale
-- @param[type=number] _C3 Gold costs
-- @param[type=number] _A3 Quantity to post
-- @param[type=string] _O4 Resourcetype on sale
-- @param[type=number] _C4 Gold costs
-- @param[type=number] _A4 Quantity to post
-- @within Rewards
--
function Reward_OpenMercenaryMerchant(...)
    return b_Reward_OpenMercenaryMerchant:New(unpack(arg));
end

b_Reward_OpenMercenaryMerchant = {
    Data = {
        Name = "Reward_OpenMercenaryMerchant",
        Type = Callbacks.MapScriptFunction
    },
};

function b_Reward_OpenMercenaryMerchant:AddParameter(_Index, _Parameter)
    if _Index == 1 then
        self.Data.Merchant = _Parameter;
    elseif _Index == 2 then
        self.Data.OfferType1 = Entities[_Parameter];
    elseif _Index == 3 then
        self.Data.OfferCost1 = _Parameter;
    elseif _Index == 4 then
        self.Data.OfferAmount1 = _Parameter;
    elseif _Index == 5 then
        self.Data.OfferType2 = Entities[_Parameter];
    elseif _Index == 6 then
        self.Data.OfferCost2 = _Parameter;
    elseif _Index == 7 then
        self.Data.OfferAmount2 = _Parameter;
    elseif _Index == 8 then
        self.Data.OfferType3 = Entities[_Parameter];
    elseif _Index == 9 then
        self.Data.OfferCost3 = _Parameter;
    elseif _Index == 10 then
        self.Data.OfferAmount3 = _Parameter;
    elseif _Index == 11 then
        self.Data.OfferType4 = Entities[_Parameter];
    elseif _Index == 12 then
        self.Data.OfferCost4 = _Parameter;
    elseif _Index == 13 then
        self.Data.OfferAmount4 = _Parameter;
    end
end

function b_Reward_OpenMercenaryMerchant:GetRewardTable()
    return {self.Data.Type, {self.CustomFunction, self}};
end

function b_Reward_OpenMercenaryMerchant:CustomFunction(_Quest)
    if Interaction.IO[self.Data.Merchant] then
        Interaction.IO[self.Data.Merchant]:Deactivate();
    end

    local NPC = new(NonPlayerMerchant, self.Data.Merchant);
    if self.Data.OfferType1 then
        NPC:AddTroopOffer(self.Data.OfferType1, {Gold = self.Data.OfferCost1}, self.Data.OfferAmount1, 3*60);
    end
    if self.Data.OfferType2 then
        NPC:AddTroopOffer(self.Data.OfferType2, {Gold = self.Data.OfferCost2}, self.Data.OfferAmount2, 3*60);
    end
    if self.Data.OfferType3 then
        NPC:AddTroopOffer(self.Data.OfferType3, {Gold = self.Data.OfferCost3}, self.Data.OfferAmount3, 3*60);
    end
    if self.Data.OfferType4 then
        NPC:AddTroopOffer(self.Data.OfferType4, {Gold = self.Data.OfferCost4}, self.Data.OfferAmount4, 3*60);
    end
    if IsExisting(self.Data.Merchant .. "Spawnpoint") then
        NPC:SetSpawnpoint(self.Data.Merchant .. "Spawnpoint");
    end
    NPC:Activate();
end

function b_Reward_OpenMercenaryMerchant:Debug(_Quest)
    for i = 1, 4, 1 do
        if self.Data["OfferType" ..i] and (not self.Data["OfferCost" ..i] or not self.Data["OfferAmount" ..i]) then
            dbg(_Quest, self, "Offer " ..i.. " is not correctly configured!");
            return true;
        end
    end
    return false;
end

QuestSystemBehavior:RegisterBehavior(b_Reward_OpenMercenaryMerchant);

-- -------------------------------------------------------------------------- --

---
-- Deactivates any kind of merchant.
-- @param[type=string] _Merchant Merchant name
-- @within Rewards
--
function Reward_CloseMerchant(...)
    return b_Reward_CloseMerchant:New(unpack(arg));
end

b_Reward_CloseMerchant = {
    Data = {
        Name = "Reward_CloseMerchant",
        Type = Callbacks.MapScriptFunction
    },
};

function b_Reward_CloseMerchant:AddParameter(_Index, _Parameter)
    if _Index == 1 then
        self.Data.Merchant = _Parameter;
    end
end

function b_Reward_CloseMerchant:GetRewardTable()
    return {self.Data.Type, {self.CustomFunction, self}};
end

function b_Reward_CloseMerchant:CustomFunction(_Quest)
    if Interaction.IO[self.Data.Merchant] then
        Interaction.IO[self.Data.Merchant]:Deactivate();
    end
end

QuestSystemBehavior:RegisterBehavior(b_Reward_CloseMerchant);

-- -------------------------------------------------------------------------- --

---
-- Creates an AI player but don't creates any armies.
--
-- Initalising the AI is nessessary for usung the quest system behavior army
-- controller.
--
-- @param[type=number]  _PlayerID  Id of player
-- @param[type=number]  _TechLevel Technology level
-- @param[type=number]  _SerfLimit Amount of serfs
-- @param[type=boolean] _Repair    Repair damaged buildings
-- @param[type=boolean] _Rebuild   Rebuild destryoed buildings
-- @within Rewards
--
function Reward_AI_CreateAIPlayer(...)
    return b_Reward_AI_CreateAIPlayer:New(unpack(arg));
end

b_Reward_AI_CreateAIPlayer = {
    Data = {
        Name = "Reward_AI_CreateAIPlayer",
        Type = Callbacks.MapScriptFunction
    },
};

function b_Reward_AI_CreateAIPlayer:AddParameter(_Index, _Parameter)
    if _Index == 1 then
        self.Data.PlayerID = _Parameter;
    elseif _Index == 2 then
        self.Data.TechLevel = _Parameter;
    elseif _Index == 3 then
        self.Data.SerfLimit = _Parameter;
    elseif _Index == 4 then
        self.Data.Repair = _Parameter;
    elseif _Index == 5 then
        self.Data.Rebuild = _Parameter;
    end
end

function b_Reward_AI_CreateAIPlayer:GetRewardTable()
    return {self.Data.Type, {self.CustomFunction, self}};
end

function b_Reward_AI_CreateAIPlayer:CustomFunction(_Quest)
    SaveCall{
        CreateAIPlayer,
        self.Data.PlayerID,
        self.Data.TechLevel,
        self.Data.SerfLimit,
        nil,
        0,
        self.Data.Repair == true,
        self.Data.Rebuild == true
    };
end

function b_Reward_AI_CreateAIPlayer:Debug(_Quest)
    if not self.Data.PlayerID or self.Data.PlayerID < 1 or self.Data.PlayerID > 8 then
        dbg(_Quest, self, "Player ID must be between 1 and 8!");
        return true;
    end
    if not self.Data.TechLevel or self.Data.TechLevel < 1 or self.Data.TechLevel > 4 then
        dbg(_Quest, self, "Technology level must be between 1 and 4!");
        return true;
    end
    if type(self.Data.SerfLimit) ~= "number" or self.Data.SerfLimit < 0 then
        dbg(_Quest, self, "Serf limit must be a number >= 0!");
        return true;
    end
    if AiController.Players[self.Data.PlayerID] then
        dbg(_Quest, self, "A player already exists for ID " ..tostring(self.Data.PlayerID));
        return true;
    end

    -- Most expensive check last
    local PlayerEntities = GetPlayerEntities(self.Data.PlayerID, 0);
    for i= 1, table.getn(PlayerEntities), 1 do
        if Logic.IsBuilding(PlayerEntities[i]) == 1 then
            return false;
        end
    end
    dbg(_Quest, self, "Player " ..tostring(self.Data.PlayerID).. " must have at least 1 building!");
    return true;
end

function b_Reward_AI_CreateAIPlayer:Reset(_Quest)
end

QuestSystemBehavior:RegisterBehavior(b_Reward_AI_CreateAIPlayer);

-- -------------------------------------------------------------------------- --

---
-- Destroys an AI player and all of their created armies.
--
-- <b>Note</b>: All armies of the player will be deleted. Even those that are
-- hidden from the AI's control.
--
-- @param[type=number]  _PlayerID  Id of player
-- @within Rewards
--
function Reward_AI_DestroyAIPlayer(...)
    return b_Reward_AI_DestroyAIPlayer:New(unpack(arg));
end

b_Reward_AI_DestroyAIPlayer = {
    Data = {
        Name = "Reward_AI_DestroyAIPlayer",
        Type = Callbacks.MapScriptFunction
    },
};

function b_Reward_AI_DestroyAIPlayer:AddParameter(_Index, _Parameter)
    if _Index == 1 then
        self.Data.PlayerID = _Parameter;
    end
end

function b_Reward_AI_DestroyAIPlayer:GetRewardTable()
    return {self.Data.Type, {self.CustomFunction, self}};
end

function b_Reward_AI_DestroyAIPlayer:CustomFunction(_Quest)
    SaveCall{DestroyAIPlayer, self.Data.PlayerID};
end

function b_Reward_AI_DestroyAIPlayer:Debug(_Quest)
    if not self.Data.PlayerID or self.Data.PlayerID < 1 or self.Data.PlayerID > 8 then
        dbg(_Quest, self, "Player ID must be between 1 and 8!");
        return true;
    end
    return true;
end

function b_Reward_AI_DestroyAIPlayer:Reset(_Quest)
end

QuestSystemBehavior:RegisterBehavior(b_Reward_AI_DestroyAIPlayer);

-- -------------------------------------------------------------------------- --

---
-- Creates an AI player and let it creates their own armies.
--
-- Armies will gather at the rally point and will automatically deployed on
-- attack targets and patrol points by the AI. The AI will need accessable
-- recruiting facilities to buy troops.
--
-- <b>Note:</b> Armies will have 12 groups instead of 8!
--
-- @param[type=number]  _PlayerID   Id of player
-- @param[type=number]  _TechLevel  Technology level
-- @param[type=number]  _SerfLimit  Amount of serfs
-- @param[type=string]  _RallyPoint Rally point for armies
-- @param[type=number]  _ArmyAmount Amount of recruited armies
-- @param[type=boolean] _Repair     Repair damaged buildings
-- @param[type=boolean] _Rebuild    Rebuild destryoed buildings
-- @within Rewards
--
function Reward_AI_SetupAIPlayer(...)
    return b_Reward_AI_SetupAIPlayer:New(unpack(arg));
end

b_Reward_AI_SetupAIPlayer = {
    Data = {
        Name = "Reward_AI_SetupAIPlayer",
        Type = Callbacks.MapScriptFunction
    },
};

function b_Reward_AI_SetupAIPlayer:AddParameter(_Index, _Parameter)
    if _Index == 1 then
        self.Data.PlayerID = _Parameter;
    elseif _Index == 2 then
        self.Data.TechLevel = _Parameter;
    elseif _Index == 3 then
        self.Data.SerfLimit = _Parameter;
    elseif _Index == 4 then
        self.Data.RallyPoint = _Parameter;
    elseif _Index == 5 then
        self.Data.ArmyAmount = _Parameter;
    elseif _Index == 6 then
        self.Data.Repair = _Parameter;
    elseif _Index == 7 then
        self.Data.Rebuild = _Parameter;
    end
end

function b_Reward_AI_SetupAIPlayer:GetRewardTable()
    return {self.Data.Type, {self.CustomFunction, self}};
end

function b_Reward_AI_SetupAIPlayer:CustomFunction(_Quest)
    SaveCall{
        CreateAIPlayer,
        self.Data.PlayerID,
        self.Data.TechLevel,
        self.Data.SerfLimit,
        self.Data.RallyPoint,
        self.Data.ArmyAmount,
        self.Data.Repair == true,
        self.Data.Rebuild == true
    };
end

function b_Reward_AI_SetupAIPlayer:Debug(_Quest)
    if not self.Data.PlayerID or self.Data.PlayerID < 1 or self.Data.PlayerID > 8 then
        dbg(_Quest, self, "Player ID must be between 1 and 8!");
        return true;
    end
    if not self.Data.TechLevel or self.Data.TechLevel < 1 or self.Data.TechLevel > 4 then
        dbg(_Quest, self, "Technology level must be between 1 and 4!");
        return true;
    end
    if type(self.Data.SerfLimit) ~= "number" or self.Data.SerfLimit < 0 then
        dbg(_Quest, self, "Serf limit must be a number >= 0!");
        return true;
    end
    if not IsExisting(self.Data.RallyPoint) or Logic.GetSector(GetID(self.Data.RallyPoint)) == 0 then
        dbg(_Quest, self, "Rally point does not exist or is in blocking!");
        return true;
    end
    if type(self.Data.ArmyAmount) ~= "number" or self.Data.ArmyAmount <= 0 then
        dbg(_Quest, self, "Army amount must be a number > 0!");
        return true;
    end
    if AiController.Players[self.Data.PlayerID] then
        dbg(_Quest, self, "A player already exists for ID " ..tostring(self.Data.PlayerID));
        return true;
    end

    -- Most expensive check last
    local PlayerEntities = GetPlayerEntities(self.Data.PlayerID, 0);
    for i= 1, table.getn(PlayerEntities), 1 do
        if Logic.IsBuilding(PlayerEntities[i]) == 1 then
            return false;
        end
    end
    dbg(_Quest, self, "Player " ..tostring(self.Data.PlayerID).. " must have at least 1 building!");
    return true;
end

function b_Reward_AI_SetupAIPlayer:Reset(_Quest)
end

QuestSystemBehavior:RegisterBehavior(b_Reward_AI_SetupAIPlayer);

-- -------------------------------------------------------------------------- --

---
-- Commands an AI player to build a building at the position.
--
-- The AI will need serfs to heed the command.
--
-- <b>Note</b>: If you wish to perform more complicated construction commands
-- to let the AI build up a base or something similar then you should use the
-- classic method by calling an script callback.
--
-- @param[type=number] _PlayerID  Id of player
-- @param[type=string] _Type      Type of building
-- @param[type=string] _Position  Location of building
-- @within Rewards
--
function Reward_AI_ConstructBuilding(...)
    return b_Reward_AI_ConstructBuilding:New(unpack(arg));
end

b_Reward_AI_ConstructBuilding = {
    Data = {
        Name = "Reward_AI_ConstructBuilding",
        Type = Callbacks.MapScriptFunction
    },
};

function b_Reward_AI_ConstructBuilding:AddParameter(_Index, _Parameter)
    if _Index == 1 then
        self.Data.PlayerID = _Parameter;
    elseif _Index == 2 then
        self.Data.BuildingType = Entities[_Parameter] or _Parameter;
    elseif _Index == 3 then
        self.Data.Position = _Parameter;
    end
end

function b_Reward_AI_ConstructBuilding:GetRewardTable()
    return {self.Data.Type, {self.CustomFunction, self}};
end

function b_Reward_AI_ConstructBuilding:CustomFunction(_Quest)
    FeedAiWithConstructionPlanFile(
        self.Data.PlayerID,
        {type = self.Data.BuildingType, pos = GetPosition(self.Data.Position)}
    );
end

function b_Reward_AI_ConstructBuilding:Debug(_Quest)
    if AiController.Players[self.Data.PlayerID] == nil then
        dbg(_Quest, self, "Player " ..tostring(self.Data.PlayerID).. " does not have an AI!");
        return true;
    end
    if not IsInTable(self.Data.BuildingType, Entities) then
        dbg(_Quest, self, "Chosen type does not exist!");
        return true;
    end
    if not IsExisting(self.Data.Position) then
        dbg(_Quest, self, "Position " ..self.Data.Position.. " does not exist!");
        return true;
    end
    return false;
end

function b_Reward_AI_ConstructBuilding:Reset(_Quest)
end

QuestSystemBehavior:RegisterBehavior(b_Reward_AI_ConstructBuilding);

-- -------------------------------------------------------------------------- --

---
-- Defines an army that must be recruited by the AI.
--
-- Use script entities named with PlayerX_AttackTargetY to define positions
-- that will be attacked by the army. Also you can use entities named with
-- PlayerX_PatrolPointY to define positions were the army will patrol.
--
-- X shall be replaced with the player ID.
-- 
-- Y shall be replaced with the index of the waypoint of players armies.
--
-- @param[type=string] _ArmyName  Army identifier
-- @param[type=number] _PlayerID  Id of player
-- @param[type=number] _Strength  Strength of army
-- @param[type=string] _Position  Army base position
-- @param[type=number] _Area      Average action range
-- @within Rewards
--
function Reward_AI_CreateArmy(...)
    return b_Reward_AI_CreateArmy:New(unpack(arg));
end

b_Reward_AI_CreateArmy = {
    Data = {
        Name = "Reward_AI_CreateArmy",
        Type = Callbacks.MapScriptFunction
    },
};

function b_Reward_AI_CreateArmy:AddParameter(_Index, _Parameter)
    if _Index == 1 then
        self.Data.ArmyName = _Parameter;
    elseif _Index == 2 then
        self.Data.PlayerID = _Parameter;
    elseif _Index == 3 then
        self.Data.Strength = _Parameter;
    elseif _Index == 4 then
        self.Data.Position = _Parameter;
    elseif _Index == 5 then
        self.Data.RodeLength = _Parameter;
    end
end

function b_Reward_AI_CreateArmy:GetRewardTable()
    return {self.Data.Type, {self.CustomFunction, self}};
end

function b_Reward_AI_CreateArmy:CustomFunction(_Quest)
    local Army = SaveCall{
        CreateAIPlayerArmy,
        self.Data.ArmyName,
        self.Data.PlayerID,
        self.Data.Strength,
        self.Data.Position,
        self.Data.RodeLength,
        -- TODO: Currently without effect!
        self.Data.TroopType
    };
    if not Army then
        dbg(_Quest, self, "Army creation for player " ..tostring(self.Data.PlayerID).. " failed!");
    end
end

function b_Reward_AI_CreateArmy:Debug(_Quest)
    if AiController.Players[self.Data.PlayerID] == nil then
        dbg(_Quest, self, "Player " ..tostring(self.Data.PlayerID).. " does not have an AI!");
        return true;
    end
    if self.Data.ArmyName == "" or self.Data.ArmyName == nil then
        dbg(_Quest, self, "An army got an invalid identifier!");
        return true;
    end
    if AiControllerArmyNameToID[self.Data.ArmyName] then
        dbg(_Quest, self, "Army '" ..tostring(self.Data.ArmyName).. "' is already created!");
        return true;
    end
    return false;
end

function b_Reward_AI_CreateArmy:Reset(_Quest)
end

QuestSystemBehavior:RegisterBehavior(b_Reward_AI_CreateArmy);

-- -------------------------------------------------------------------------- --

---
-- Defines an army of up to 6 different unit types that is spawned from a
-- generator entity.
--
-- Use script entities named with PlayerX_AttackTargetY to define positions
-- that will be attacked by the army. Also you can use entities named with
-- PlayerX_PatrolPointY to define positions were the army will patrol.
--
-- X shall be replaced with the player ID.
-- 
-- Y shall be replaced with the index of the waypoint of players armies.
--
-- @param[type=string] _ArmyName Army identifier
-- @param[type=number] _PlayerID Id of player
-- @param[type=string] _Spawner Name of generator
-- @param[type=number] _Strength Strength of army
-- @param[type=string] _Position Army base position
-- @param[type=number] _Area Average action range
-- @param[type=number] _Respawn Time till reinforcements spawned
-- @param[type=string] _TT1 Troop type 1
-- @param[type=string] _TT2 Troop type 2
-- @param[type=string] _TT3 Troop type 3
-- @param[type=string] _TT4 Troop type 4
-- @param[type=string] _TT5 Troop type 5
-- @param[type=string] _TT6 Troop type 6
-- @within Rewards
--
function Reward_AI_CreateSpawnArmy(...)
    return b_Reward_AI_CreateSpawnArmy:New(unpack(arg));
end

b_Reward_AI_CreateSpawnArmy = {
    Data = {
        Name = "Reward_AI_CreateSpawnArmy",
        Type = Callbacks.MapScriptFunction
    },
};

function b_Reward_AI_CreateSpawnArmy:AddParameter(_Index, _Parameter)
    if _Index == 1 then
        self.Data.ArmyName = _Parameter;
    elseif _Index == 2 then
        self.Data.PlayerID = _Parameter;
    elseif _Index == 3 then
        self.Data.LifeThread = _Parameter;
    elseif _Index == 4 then
        self.Data.Strength = _Parameter;
    elseif _Index == 5 then
        self.Data.Position = _Parameter;
    elseif _Index == 6 then
        self.Data.RodeLength = _Parameter;
    elseif _Index == 7 then
        self.Data.RespawnTime = _Parameter;
    elseif _Index == 8 then
        self.Data.TroopType1 = _Parameter;
    elseif _Index == 9 then
        self.Data.TroopType2 = _Parameter;
    elseif _Index == 10 then
        self.Data.TroopType3 = _Parameter;
    elseif _Index == 11 then
        self.Data.TroopType4 = _Parameter;
    elseif _Index == 12 then
        self.Data.TroopType5 = _Parameter;
    elseif _Index == 13 then
        self.Data.TroopType6 = _Parameter;
    end
end

function b_Reward_AI_CreateSpawnArmy:GetRewardTable()
    return {self.Data.Type, {self.CustomFunction, self}};
end

function b_Reward_AI_CreateSpawnArmy:CustomFunction(_Quest)
    -- Get types
    local TroopTypes = {};
    for i= 1, 6, 1 do
        if self.Data["TroopType" ..i] and Entities[self.Data["TroopType" ..i]] then
            local Exp = (string.find(self.Data["TroopType" ..i], "PV_") and 0) or 3;
            table.insert(TroopTypes, {Entities[self.Data["TroopType" ..i]], Exp});
        end
    end
    -- Create army
    local Army = SaveCall{
        CreateAIPlayerSpawnArmy,
        self.Data.ArmyName,
        self.Data.PlayerID,
        self.Data.Strength,
        self.Data.Position,
        self.Data.LifeThread,
        self.Data.RodeLength,
        self.Data.RespawnTime,
        unpack(TroopTypes)
    };
    if not Army then
        dbg(_Quest, self, "Army creation for player " ..tostring(self.Data.PlayerID).. " failed!");
    end
end

function b_Reward_AI_CreateSpawnArmy:Debug(_Quest)
    if AiController.Players[self.Data.PlayerID] == nil then
        dbg(_Quest, self, "Player " ..tostring(self.Data.PlayerID).. " does not have an AI!");
        return true;
    end
    if self.Data.ArmyName == "" or self.Data.ArmyName == nil then
        dbg(_Quest, self, "An army got an invalid identifier!");
        return true;
    end
    if AiControllerArmyNameToID[self.Data.ArmyName] then
        dbg(_Quest, self, "Army '" ..tostring(self.Data.ArmyName).. "' is already created!");
        return true;
    end
    if not IsExisting(self.Data.LifeThread) then
        dbg(_Quest, self, "Army '" ..tostring(self.Data.ArmyName).. "' has no life thread!");
        return true;
    end

    local ValidMember = false;
    for i= 1, 6, 1 do
        if Entities[self.Data["TroopType" ..i]] ~= nil then
            ValidMember = true;
            break;
        end
    end
    if ValidMember == false then
        dbg(_Quest, self, "Army '" ..tostring(self.Data.ArmyName).. "' has no troop types assigned!");
        return true;
    end
    return false;
end

function b_Reward_AI_CreateSpawnArmy:Reset(_Quest)
end

QuestSystemBehavior:RegisterBehavior(b_Reward_AI_CreateSpawnArmy);

-- -------------------------------------------------------------------------- --

---
-- Destroys an army and all existing troops of this army.
--
-- @param[type=string] _ArmyName Army identifier
-- @within Rewards
--
function Reward_AI_DestroyArmy(...)
    return b_Reward_AI_DestroyArmy:New(unpack(arg));
end

b_Reward_AI_DestroyArmy = {
    Data = {
        Name = "Reward_AI_DestroyArmy",
        Type = Callbacks.MapScriptFunction
    },
};

function b_Reward_AI_DestroyArmy:AddParameter(_Index, _Parameter)
    if _Index == 1 then
        self.Data.ArmyName = _Parameter;
    end
end

function b_Reward_AI_DestroyArmy:GetRewardTable()
    return {self.Data.Type, {self.CustomFunction, self}};
end

function b_Reward_AI_DestroyArmy:CustomFunction(_Quest)
    if AiControllerArmyNameToID[self.Data.ArmyName] then
        SaveCall{ArmyDisband, self.Data.ArmyName, true, false};
    end
end

function b_Reward_AI_DestroyArmy:Debug(_Quest)
    if self.Data.ArmyName == "" or self.Data.ArmyName == nil then
        dbg(_Quest, self, "An army got an invalid identifier!");
        return true;
    end
    if not AiControllerArmyNameToID[self.Data.ArmyName] then
        dbg(_Quest, self, "Army '" ..tostring(self.Data.ArmyName).. "' does not exist!");
        return true;
    end
    return false;
end

function b_Reward_AI_DestroyArmy:Reset(_Quest)
end

QuestSystemBehavior:RegisterBehavior(b_Reward_AI_DestroyArmy);

-- -------------------------------------------------------------------------- --

---
-- Disables or enables the patrol behavior for armies.
--
-- @param[type=string] _ArmyName Army identifier
-- @param[type=boolean] _Flag  Patrol disabled
-- @within Rewards
--
function Reward_AI_EnableArmyPatrol(...)
    return b_Reward_AI_EnableArmyPatrol:New(unpack(arg));
end

b_Reward_AI_EnableArmyPatrol = {
    Data = {
        Name = "Reward_AI_EnableArmyPatrol",
        Type = Callbacks.MapScriptFunction
    },
};

function b_Reward_AI_EnableArmyPatrol:AddParameter(_Index, _Parameter)
    if _Index == 1 then
        self.Data.ArmyName = _Parameter;
    elseif _Index == 2 then
        self.Data.Flag = _Parameter;
    end
end

function b_Reward_AI_EnableArmyPatrol:GetRewardTable()
    return {self.Data.Type, {self.CustomFunction, self}};
end

function b_Reward_AI_EnableArmyPatrol:CustomFunction(_Quest)
    if AiControllerArmyNameToID[self.Data.ArmyName] then
        SaveCall{ArmySetExemtFromPatrol, self.Data.ArmyName, not self.Data.Flag};
    end
end

function b_Reward_AI_EnableArmyPatrol:Debug(_Quest)
    if not AiControllerArmyNameToID[self.Data.ArmyName] then
        dbg(_Quest, self, "Army '" ..tostring(self.Data.ArmyName).. "' does not exist!");
        return true;
    end
    return false;
end

function b_Reward_AI_EnableArmyPatrol:Reset(_Quest)
end

QuestSystemBehavior:RegisterBehavior(b_Reward_AI_EnableArmyPatrol);

-- -------------------------------------------------------------------------- --

---
-- Disables or enables the attack behavior for armies.
--
-- @param[type=string] _ArmyName Army identifier
-- @param[type=boolean] _Flag  Attack disabled
-- @within Rewards
--
function Reward_AI_EnableArmyAttack(...)
    return b_Reward_AI_EnableArmyAttack:New(unpack(arg));
end

b_Reward_AI_EnableArmyAttack = {
    Data = {
        Name = "Reward_AI_EnableArmyAttack",
        Type = Callbacks.MapScriptFunction
    },
};

function b_Reward_AI_EnableArmyAttack:AddParameter(_Index, _Parameter)
    if _Index == 1  then
        self.Data.ArmyName = _Parameter;
    elseif _Index == 2 then
        self.Data.Flag = _Parameter;
    end
end

function b_Reward_AI_EnableArmyAttack:GetRewardTable()
    return {self.Data.Type, {self.CustomFunction, self}};
end

function b_Reward_AI_EnableArmyAttack:CustomFunction(_Quest)
    if AiControllerArmyNameToID[self.Data.ArmyName] then
        SaveCall{ArmySetExemtFromAttack, self.Data.ArmyName, not self.Data.Flag};
    end
end

function b_Reward_AI_EnableArmyAttack:Debug(_Quest)
    if not AiControllerArmyNameToID[self.Data.ArmyName] then
        dbg(_Quest, self, "Army '" ..tostring(self.Data.ArmyName).. "' does not exist!");
        return true;
    end
    return false;
end

function b_Reward_AI_EnableArmyAttack:Reset(_Quest)
end

QuestSystemBehavior:RegisterBehavior(b_Reward_AI_EnableArmyAttack);

-- -------------------------------------------------------------------------- --

---
-- Changes the color of a player.
-- @param[type=number] _PlayerID ID of player
-- @param              _Color Color name or Color index
-- @within Rewards
--
function Reward_SetPlayerColor(...)
    return b_Reward_SetPlayerColor:New(unpack(arg));
end

b_Reward_SetPlayerColor = {
    Data = {
        Name = "Reward_SetPlayerColor",
        Type = Callbacks.MapScriptFunction
    },
};

function b_Reward_SetPlayerColor:AddParameter(_Index, _Parameter)
    if _Index == 1 then
        self.Data.PlayerID = _Parameter;
    elseif _Index == 2 then
        self.Data.Color = _Parameter;
    end
end

function b_Reward_SetPlayerColor:GetRewardTable()
    return {self.Data.Type, {self.CustomFunction, self}};
end

function b_Reward_SetPlayerColor:CustomFunction(_Quest)
    QuestSystemBehavior.Data.PlayerColorAssigment[self.Data.PlayerID] = _G[self.Data.Color] or self.Data.Color;
    QuestSystemBehavior:UpdatePlayerColorAssigment();
end

function b_Reward_SetPlayerColor:Debug(_Quest)
    if self.Data.PlayerID < 1 or self.Data.PlayerID > 8 then
        dbg(_Quest, self, "PlayerID is wrong!");
        return true;
    end
    if type(self.Data.Color) ~= "number" and not _G[self.Data.Color] then
        dbg(_Quest, self, "Color does not exist!");
        return true;
    end
    return false;
end

function b_Reward_SetPlayerColor:Reset(_Quest)
end

QuestSystemBehavior:RegisterBehavior(b_Reward_SetPlayerColor);

-- -------------------------------------------------------------------------- --

---
-- Activates the debug mode.
-- @param[type=boolean] _UseDebugQuests Activates the runtime debug für quests
-- @param[type=boolean] _UseCheats Activates the cheats
-- @param[type=boolean] _UseShell Activates the shell
-- @param[type=boolean] _UseQuestTrace Activates the quest trace
-- @within Rewards
--
function Reward_DEBUG(...)
    return b_Reward_DEBUG:New(unpack(arg));
end

b_Reward_DEBUG = {
    Data = {
        Name = "Reward_DEBUG",
        Type = Callbacks.MapScriptFunction
    },
};

function b_Reward_DEBUG:AddParameter(_Index, _Parameter)
    if _Index == 1 then
        self.Data.UseDebugQuests = _Parameter;
    elseif _Index == 2 then
        self.Data.UseCheats = _Parameter;
    elseif _Index == 3 then
        self.Data.UseShell = _Parameter;
    elseif _Index == 4 then
        self.Data.UseQuestTrace = _Parameter;
    end
end

function b_Reward_DEBUG:GetRewardTable()
    return {self.Data.Type, {self.CustomFunction, self}};
end

function b_Reward_DEBUG:CustomFunction(_Quest)
    if QuestDebug then
        QuestDebug:Activate(
            self.Data.UseDebugQuests,
            self.Data.UseCheats,
            self.Data.UseShell,
            self.Data.UseQuestTrace
        );
    end
end

function b_Reward_DEBUG:Debug(_Quest)
    return false;
end

function b_Reward_DEBUG:Reset(_Quest)
end

QuestSystemBehavior:RegisterBehavior(b_Reward_DEBUG);

-- -------------------------------------------------------------------------- --

---
-- Starts the quest when another quest is successfully finished.
-- @param[type=string] _QuestName First quest
-- @param[type=number] _Waittime Time to wait
-- @within Triggers
--
function Trigger_QuestSuccess(...)
    return b_Trigger_QuestSuccess:New(unpack(arg));
end

b_Trigger_QuestSuccess = {
    Data = {
        Name = "Trigger_QuestSuccess",
        Type = Conditions.MapScriptFunction
    },
};

function b_Trigger_QuestSuccess:AddParameter(_Index, _Parameter)
    if _Index == 1 then
        self.Data.QuestName = _Parameter;
    elseif _Index == 2 then
        self.Data.Waittime = _Parameter;
    end
end

function b_Trigger_QuestSuccess:GetTriggerTable()
    return {self.Data.Type, {self.CustomFunction, self}};
end

function b_Trigger_QuestSuccess:CustomFunction(_Quest)
    self.Data.Waittime = self.Data.Waittime or 0;
    local QuestID = GetQuestID(self.Data.QuestName);
    if QuestSystem.Quests[QuestID] and QuestSystem.Quests[QuestID].m_Result == QuestResults.Success then
        self.Data.StartTime = self.Data.StartTime or Logic.GetTime();
        if self.Data.Waittime + self.Data.StartTime < Logic.GetTime() then
            return true;
        end
    end
end

function b_Trigger_QuestSuccess:Debug(_Quest)
    if GetQuestID(self.Data.QuestName) == 0 then
        dbg(_Quest, self, "Quest does not exist: " ..tostring(self.Data.QuestName));
    end
    return false;
end

function b_Trigger_QuestSuccess:Reset(_Quest)
    self.Data.StartTime = nil;
end

QuestSystemBehavior:RegisterBehavior(b_Trigger_QuestSuccess);

-- -------------------------------------------------------------------------- --

---
-- Starts the quest when another quest has failed.
-- @param[type=string] _QuestName First quest
-- @param[type=number] _Waittime Time to wait
-- @within Triggers
--
function Trigger_QuestFailure(...)
    return b_Trigger_QuestFailure:New(unpack(arg));
end

b_Trigger_QuestFailure = {
    Data = {
        Name = "Trigger_QuestFailure",
        Type = Conditions.MapScriptFunction
    },
};

function b_Trigger_QuestFailure:AddParameter(_Index, _Parameter)
    if _Index == 1 then
        self.Data.QuestName = _Parameter;
    elseif _Index == 2 then
        self.Data.Waittime = _Parameter;
    end
end

function b_Trigger_QuestFailure:GetTriggerTable()
    return {self.Data.Type, {self.CustomFunction, self}};
end

function b_Trigger_QuestFailure:CustomFunction(_Quest)
    self.Data.Waittime = self.Data.Waittime or 0;
    local QuestID = GetQuestID(self.Data.QuestName);
    if QuestSystem.Quests[QuestID] and QuestSystem.Quests[QuestID].m_Result == QuestResults.Failure then
        self.Data.StartTime = self.Data.StartTime or Logic.GetTime();
        if self.Data.Waittime + self.Data.StartTime < Logic.GetTime() then
            return true;
        end
    end
end

function b_Trigger_QuestFailure:Debug(_Quest)
    if GetQuestID(self.Data.QuestName) == 0 then
        dbg(_Quest, self, "Quest does not exist: " ..tostring(self.Data.QuestName));
    end
    return false;
end

function b_Trigger_QuestFailure:Reset(_Quest)
    self.Data.StartTime = nil;
end

QuestSystemBehavior:RegisterBehavior(b_Trigger_QuestFailure);

-- -------------------------------------------------------------------------- --

---
-- Starts the quest when another quest is over.
-- @param[type=string] _QuestName First quest
-- @param[type=number] _Waittime Time to wait
-- @within Triggers
--
function Trigger_QuestOver(...)
    return b_Trigger_QuestOver:New(unpack(arg));
end

b_Trigger_QuestOver = {
    Data = {
        Name = "Trigger_QuestOver",
        Type = Conditions.MapScriptFunction
    },
};

function b_Trigger_QuestOver:AddParameter(_Index, _Parameter)
    if _Index == 1 then
        self.Data.QuestName = _Parameter;
    elseif _Index == 2 then
        self.Data.Waittime = _Parameter;
    end
end

function b_Trigger_QuestOver:GetTriggerTable()
    return {self.Data.Type, {self.CustomFunction, self}};
end

function b_Trigger_QuestOver:CustomFunction(_Quest)
    self.Data.Waittime = self.Data.Waittime or 0;
    local QuestID = GetQuestID(self.Data.QuestName);
    if QuestSystem.Quests[QuestID] and QuestSystem.Quests[QuestID].m_State == QuestStates.Over then
        self.Data.StartTime = self.Data.StartTime or Logic.GetTime();
        if self.Data.Waittime + self.Data.StartTime < Logic.GetTime() then
            return true;
        end
    end
end

function b_Trigger_QuestOver:Debug(_Quest)
    if GetQuestID(self.Data.QuestName) == 0 then
        dbg(_Quest, self, "Quest does not exist: " ..tostring(self.Data.QuestName));
    end
    return false;
end

function b_Trigger_QuestOver:Reset(_Quest)
    self.Data.StartTime = nil;
end

QuestSystemBehavior:RegisterBehavior(b_Trigger_QuestOver);

-- -------------------------------------------------------------------------- --

---
-- Starts the quest when another quest is interrupted.
-- @param[type=string] _QuestName First quest
-- @param[type=number] _Waittime Time to wait
-- @within Triggers
--
function Trigger_QuestInterrupted(...)
    return b_Trigger_QuestInterrupted:New(unpack(arg));
end

b_Trigger_QuestInterrupted = {
    Data = {
        Name = "Trigger_QuestInterrupted",
        Type = Conditions.MapScriptFunction
    },
};

function b_Trigger_QuestInterrupted:AddParameter(_Index, _Parameter)
    if _Index == 1 then
        self.Data.QuestName = _Parameter;
    elseif _Index == 2 then
        self.Data.Waittime = _Parameter;
    end
end

function b_Trigger_QuestInterrupted:GetTriggerTable()
    return {self.Data.Type, {self.CustomFunction, self}};
end

function b_Trigger_QuestInterrupted:CustomFunction(_Quest)
    self.Data.Waittime = self.Data.Waittime or 0;
    local QuestID = GetQuestID(self.Data.QuestName);
    if QuestSystem.Quests[QuestID] and QuestSystem.Quests[QuestID].m_State == QuestStates.Over and QuestSystem.Quests[QuestID].m_Result == QuestStates.Interrupted then
        self.Data.StartTime = self.Data.StartTime or Logic.GetTime();
        if self.Data.Waittime + self.Data.StartTime < Logic.GetTime() then
            return true;
        end
    end
end

function b_Trigger_QuestInterrupted:Debug(_Quest)
    if GetQuestID(self.Data.QuestName) == 0 then
        dbg(_Quest, self, "Quest does not exist: " ..tostring(self.Data.QuestName));
    end
    return false;
end

function b_Trigger_QuestInterrupted:Reset(_Quest)
    self.Data.StartTime = nil;
end

QuestSystemBehavior:RegisterBehavior(b_Trigger_QuestInterrupted);

-- -------------------------------------------------------------------------- --

---
-- Starts the quest when another quest is active.
-- @param[type=string] _QuestName First quest
-- @param[type=number] _Waittime Time to wait
-- @within Triggers
--
function Trigger_QuestActive(...)
    return b_Trigger_QuestActive:New(unpack(arg));
end

b_Trigger_QuestActive = {
    Data = {
        Name = "Trigger_QuestActive",
        Type = Conditions.MapScriptFunction
    },
};

function b_Trigger_QuestActive:AddParameter(_Index, _Parameter)
    if _Index == 1 then
        self.Data.QuestName = _Parameter;
    elseif _Index == 2 then
        self.Data.Waittime = _Parameter;
    end
end

function b_Trigger_QuestActive:GetTriggerTable()
    return {self.Data.Type, {self.CustomFunction, self}};
end

function b_Trigger_QuestActive:CustomFunction(_Quest)
    self.Data.Waittime = self.Data.Waittime or 0;
    local QuestID = GetQuestID(self.Data.QuestName);
    if QuestSystem.Quests[QuestID] and QuestSystem.Quests[QuestID].m_State == QuestStates.Active then
        self.Data.StartTime = self.Data.StartTime or Logic.GetTime();
        if self.Data.Waittime + self.Data.StartTime < Logic.GetTime() then
            return true;
        end
    end
end

function b_Trigger_QuestActive:Debug(_Quest)
    if GetQuestID(self.Data.QuestName) == 0 then
        dbg(_Quest, self, "Quest does not exist: " ..tostring(self.Data.QuestName));
    end
    return false;
end

function b_Trigger_QuestActive:Reset(_Quest)
    self.Data.StartTime = nil;
end

QuestSystemBehavior:RegisterBehavior(b_Trigger_QuestActive);

-- -------------------------------------------------------------------------- --

---
-- Starts the quest when another quest has not been triggered.
-- @param[type=string] _QuestName First quest
-- @param[type=number] _Waittime Time to wait
-- @within Triggers
--
function Trigger_QuestNotTriggered(...)
    return b_Trigger_QuestNotTriggered:New(unpack(arg));
end

b_Trigger_QuestNotTriggered = {
    Data = {
        Name = "Trigger_QuestNotTriggered",
        Type = Conditions.MapScriptFunction
    },
};

function b_Trigger_QuestNotTriggered:AddParameter(_Index, _Parameter)
    if _Index == 1 then
        self.Data.QuestName = _Parameter;
    elseif _Index == 2 then
        self.Data.Waittime = _Parameter;
    end
end

function b_Trigger_QuestNotTriggered:GetTriggerTable()
    return {self.Data.Type, {self.CustomFunction, self}};
end

function b_Trigger_QuestNotTriggered:CustomFunction(_Quest)
    self.Data.Waittime = self.Data.Waittime or 0;
    local QuestID = GetQuestID(self.Data.QuestName);
    if QuestSystem.Quests[QuestID] and QuestSystem.Quests[QuestID].m_State == QuestStates.Inactive then
        self.Data.StartTime = self.Data.StartTime or Logic.GetTime();
        if self.Data.Waittime + self.Data.StartTime < Logic.GetTime() then
            return true;
        end
    end
end

function b_Trigger_QuestNotTriggered:Debug(_Quest)
    if GetQuestID(self.Data.QuestName) == 0 then
        dbg(_Quest, self, "Quest does not exist: " ..tostring(self.Data.QuestName));
    end
    return false;
end

function b_Trigger_QuestNotTriggered:Reset(_Quest)
    self.Data.StartTime = nil;
end

QuestSystemBehavior:RegisterBehavior(b_Trigger_QuestNotTriggered);

-- -------------------------------------------------------------------------- --
-- Custom Variable Behavior                                                   --
-- -------------------------------------------------------------------------- --

---
-- Compares a numeric custom value with number or another custom value.
-- If the values match the condition then the goal is reached.
-- @param[type=string] _Name Variable identifier
-- @param[type=string] _Comparison Comparsion operator
-- @param[type=number] _Value Integer value
-- @within Goals
--
function Goal_CustomVariable(...)
    return b_Goal_CustomVariable:New(unpack(arg));
end

b_Goal_CustomVariable = {
    Data = {
        Name = "Goal_CustomVariable",
        Type = Objectives.MapScriptFunction
    },
};

function b_Goal_CustomVariable:AddParameter(_Index, _Parameter)
    if _Index == 1 then
        self.Data.VariableName = _Parameter;
    elseif _Index == 2 then
        self.Data.Operator = _Parameter;
    elseif _Index == 3 then
        self.Data.Value = _Parameter;
    end
end

function b_Goal_CustomVariable:GetGoalTable()
    return {self.Data.Type, {self.CustomFunction, self}};
end

function b_Goal_CustomVariable:CustomFunction(_Quest)
    local CustomValue = QuestSystem.CustomVariables[self.Data.VariableName];
    local ComparsionValue = self.Data.Value;
    if type(ComparsionValue) == "string" then
        ComparsionValue = QuestSystem.CustomVariables[self.Data.Value];
    end

    if CustomValue and ComparsionValue then
        if self.Data.Operator == "==" and CustomValue == ComparsionValue then
            return true;
        elseif self.Data.Operator == "~=" and CustomValue ~= ComparsionValue then
            return true;
        elseif self.Data.Operator == "<" and CustomValue < ComparsionValue then
            return true;
        elseif self.Data.Operator == "<=" and CustomValue <= ComparsionValue then
            return true;
        elseif self.Data.Operator == ">=" and CustomValue >= ComparsionValue then
            return true;
        elseif self.Data.Operator == ">" and CustomValue > ComparsionValue then
            return true;
        end
    end
end

function b_Goal_CustomVariable:Debug(_Quest)
    return false;
end

function b_Goal_CustomVariable:Reset(_Quest)
end

QuestSystemBehavior:RegisterBehavior(b_Goal_CustomVariable);

-- -------------------------------------------------------------------------- --

---
-- Alters a numeric custom value by the given value or value of the given
-- custom variable using the mathematical operation.
-- @param[type=string] _Name Variable identifier
-- @param[type=string] _Operator Operator
-- @param[type=number] _Value Integer value
-- @within Triggers
--
function Reprisal_CustomVariable(...)
    return b_Reprisal_CustomVariable:New(unpack(arg));
end

b_Reprisal_CustomVariable = {
    Data = {
        Name = "Reprisal_CustomVariable",
        Type = Callbacks.MapScriptFunction
    },
};

function b_Reprisal_CustomVariable:AddParameter(_Index, _Parameter)
    if _Index == 1 then
        self.Data.VariableName = _Parameter;
    elseif _Index == 2 then
        self.Data.Operator = _Parameter;
    elseif _Index == 3 then
        self.Data.Value = _Parameter;
    end
end

function b_Reprisal_CustomVariable:GetReprisalTable()
    return {self.Data.Type, {self.CustomFunction, self}};
end

function b_Reprisal_CustomVariable:CustomFunction(_Quest)
    local OldValue = QuestSystem.CustomVariables[self.Data.VariableName] or 0;
    local NewValue = self.Data.Value;
    if type(NewValue) == "string" then
        NewValue = QuestSystem.CustomVariables[self.Data.Value];
    end

    if NewValue then
        if self.Data.Operator == "=" then
            OldValue = NewValue;
        elseif self.Data.Operator == "+" then
            OldValue = OldValue + NewValue;
        elseif self.Data.Operator == "-" then
            OldValue = OldValue - NewValue;
        elseif self.Data.Operator == "*" then
            OldValue = OldValue * NewValue;
        elseif self.Data.Operator == "/" then
            OldValue = OldValue / NewValue;
        elseif self.Data.Operator == "%" then
            OldValue = math.mod(OldValue, NewValue);
        elseif self.Data.Operator == "^" then
            OldValue = OldValue ^ NewValue;
        end
        QuestSystem.CustomVariables[self.Data.VariableName] = OldValue;
    end
end

function b_Reprisal_CustomVariable:Debug(_Quest)
    return false;
end

function b_Reprisal_CustomVariable:Reset(_Quest)
end

QuestSystemBehavior:RegisterBehavior(b_Reprisal_CustomVariable);

-- -------------------------------------------------------------------------- --

---
-- Alters a numeric custom value by the given value or value of the given
-- custom variable using the mathematical operation.
-- @param[type=string] _Name Variable identifier
-- @param[type=string] _Operator Operator
-- @param[type=number] _Value Integer value
-- @within Triggers
--
function Reward_CustomVariable(...)
    return b_Reward_CustomVariable:New(unpack(arg));
end

b_Reward_CustomVariable = copy(b_Reprisal_CustomVariable);
b_Reward_CustomVariable.Data.Name = "Reward_CustomVariable";
b_Reward_CustomVariable.Data.Type = Callbacks.MapScriptFunction;
b_Reward_CustomVariable.GetReprisalTable = nil;

function b_Reward_CustomVariable:GetRewardTable()
    return {self.Data.Type, {self.CustomFunction, self}};
end

QuestSystemBehavior:RegisterBehavior(b_Reward_CustomVariable);

-- -------------------------------------------------------------------------- --

---
-- Compares a numeric custom value with number or another custom value.
-- If the values match the condition then the trigger returns true.
-- @param[type=string] _Name Variable identifier
-- @param[type=string] _Comparison Comparsion operator
-- @param[type=number] _Value Integer value
-- @within Triggers
--
function Trigger_CustomVariable(...)
    return b_Trigger_CustomVariable:New(unpack(arg));
end

b_Trigger_CustomVariable = {
    Data = {
        Name = "Trigger_CustomVariable",
        Type = Conditions.MapScriptFunction
    },
};

function b_Trigger_CustomVariable:AddParameter(_Index, _Parameter)
    if _Index == 1 then
        self.Data.VariableName = _Parameter;
    elseif _Index == 2 then
        self.Data.Operator = _Parameter;
    elseif _Index == 3 then
        self.Data.Value = _Parameter;
    end
end

function b_Trigger_CustomVariable:GetTriggerTable()
    return {self.Data.Type, {self.CustomFunction, self}};
end

function b_Trigger_CustomVariable:CustomFunction(_Quest)
    local CustomValue = QuestSystem.CustomVariables[self.Data.VariableName];
    local ComparsionValue = self.Data.Value;
    if type(ComparsionValue) == "string" then
        ComparsionValue = QuestSystem.CustomVariables[self.Data.Value];
    end

    if CustomValue and ComparsionValue then
        if self.Data.Operator == "==" and CustomValue == ComparsionValue then
            return true;
        elseif self.Data.Operator == "~=" and CustomValue ~= ComparsionValue then
            return true;
        elseif self.Data.Operator == "<" and CustomValue < ComparsionValue then
            return true;
        elseif self.Data.Operator == "<=" and CustomValue <= ComparsionValue then
            return true;
        elseif self.Data.Operator == ">=" and CustomValue >= ComparsionValue then
            return true;
        elseif self.Data.Operator == ">" and CustomValue > ComparsionValue then
            return true;
        end
    end
    return false;
end

function b_Trigger_CustomVariable:Debug(_Quest)
    return false;
end

function b_Trigger_CustomVariable:Reset(_Quest)
end

QuestSystemBehavior:RegisterBehavior(b_Trigger_CustomVariable);

-- -------------------------------------------------------------------------- --

---
-- After the player made a choice in a briefing that choice can be checked by
-- this goal. If the choice was selected, the goal succeeds. If not, it fails.
--
-- Use this behavior in hidden quests!
--
-- <b>Hint:</b> This goal is only ment to be used by the assistent and thus
-- not visible in the user documentation. Real mapper don't use the assistent
-- so they can do this properly by script.
--
-- @param[type=string] _ChoicePage Name of page
-- @param[type=number] _Answer Number of selected answer
-- @within Goals
-- @local
--
function Goal_MultipleChoiceSelection(...)
    return b_Goal_MultipleChoiceSelection:New(unpack(arg));
end

b_Goal_MultipleChoiceSelection = {
    Data = {
        Name = "Goal_MultipleChoiceSelection",
        Type = Objectives.MapScriptFunction
    },
};

function b_Goal_MultipleChoiceSelection:AddParameter(_Index, _Parameter)
    if _Index == 1 then
        self.Data.ChoicePage = _Parameter;
    elseif _Index == 2 then
        self.Data.Answer = _Parameter;
    end
end

function b_Goal_MultipleChoiceSelection:GetGoalTable()
    return {self.Data.Type, {self.CustomFunction, self}};
end

function b_Goal_MultipleChoiceSelection:CustomFunction(_Quest)
    QuestBriefing.SelectedChoices[_Quest.m_Receiver] = QuestBriefing.SelectedChoices[_Quest.m_Receiver] or {};
    if QuestBriefing.SelectedChoices[_Quest.m_Receiver][self.Data.ChoicePage] ~= nil then
        return QuestBriefing.SelectedChoices[_Quest.m_Receiver][self.Data.ChoicePage] == self.Data.Answer;
    end
end

function b_Goal_MultipleChoiceSelection:Debug(_Quest)
    if (self.Data.ChoicePage == nil or self.Data.ChoicePage == "") then
        dbg(_Quest, self, "Choice page name is missing!");
        return true;
    end
    return false;
end

function b_Goal_MultipleChoiceSelection:Reset(_Quest)
    if self.Data.Briefing and self.Data.ChoicePage then
        QuestBriefing.SelectedChoices[_Quest.m_Receiver] = QuestBriefing.SelectedChoices[_Quest.m_Receiver] or {};
        QuestBriefing.SelectedChoices[_Quest.m_Receiver][self.Data.ChoicePage] = nil;
    end
end

QuestSystemBehavior:RegisterBehavior(b_Goal_MultipleChoiceSelection);

-- Callbacks ---------------------------------------------------------------- --

GameCallback_OnQuestSystemLoaded = function()
end

