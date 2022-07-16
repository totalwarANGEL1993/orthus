-- ########################################################################## --
-- #  Quest Debug                                                           # --
-- #  --------------------------------------------------------------------  # --
-- #    Author:   totalwarANGEL                                             # --
-- ########################################################################## --

---
-- Implements a debug mode for the quest system featuring visual quest trace
-- on screen, advanced cheats and a simple shell for controlling quests while
-- the map is in development.
--
-- Some cheats are disabled in Multiplayer!
--
-- <b>Required modules:</b>
-- <ul>
-- <li>qsb.oop</li>
-- <li>qsb.quest.questsystem</li>
-- <li>qsb.quest.questtools</li>
-- </ul>
--
-- @set sort=true
--

QuestDebug = {
    ScriptEvents = {},
};

---
-- Activates the debug mode. Use the flags to decide which features you want
-- to use.
--
-- @param[type=boolean] _CheckQuests Call debug check of behavior
-- @param[type=boolean] _TraceQuests Display quest status changes
-- @param[type=boolean] _Cheats      Activate debug cheats
-- @param[type=boolean] _Console     Activate debug shell
-- @within Methods
--
-- @usage ActivateDebugMode(true, false, true, true);
--
function ActivateDebugMode(_CheckQuests, _TraceQuests, _Cheats, _Console)
    QuestDebug:Activate(_CheckQuests, _Cheats, _Console, _TraceQuests);
end

-- -------------------------------------------------------------------------- --

function QuestDebug:Activate(_CheckQuests, _DebugKeys, _DebugShell, _QuestTrace)
    self.m_QuestTrace = _QuestTrace == true;
    self.m_CheckQuests = _CheckQuests == true;
    self.m_DebugKeys = _DebugKeys == true;
    self.m_DebugShell = _DebugShell == true;

    self:CreateScriptEvents();
    self:OverrideSaveGameLoaded();
    self:CreateCheats();
    self:CreateCheatMethods();
    self:ActivateConsole();
    self:OverrideQuestSystemTriggerQuest();
end

function QuestDebug:OverrideQuestSystemTriggerQuest()
    QuestTemplate.TriggerOriginal = QuestTemplate.Trigger;
    QuestTemplate.Trigger = function(self)
        if QuestDebug.m_CheckQuests then
            for i= 1, table.getn(self.m_Objectives), 1 do
                if self.m_Objectives[i][1] == Objectives.MapScriptFunction and self.m_Objectives[i][2][2].Debug then
                    if self.m_Objectives[i][2][2]:Debug(self) then
                        self:Interrupt();
                        return;
                    end
                end
            end
            for i= 1, table.getn(self.m_Conditions), 1 do
                if self.m_Conditions[i][1] == Conditions.MapScriptFunction and self.m_Conditions[i][2][2].Debug then
                    if self.m_Conditions[i][2][2]:Debug(self) then
                        self:Interrupt();
                        return;
                    end
                end
            end
            for i= 1, table.getn(self.m_Rewards), 1 do
                if self.m_Rewards[i][1] == Callbacks.MapScriptFunction and self.m_Rewards[i][2][2].Debug then
                    if self.m_Rewards[i][2][2]:Debug(self) then
                        self:Interrupt();
                        return;
                    end
                end
            end
            for i= 1, table.getn(self.m_Reprisals), 1 do
                if self.m_Reprisals[i][1] == Callbacks.MapScriptFunction and self.m_Reprisals[i][2][2].Debug then
                    if self.m_Reprisals[i][2][2]:Debug(self) then
                        self:Interrupt();
                        return;
                    end
                end
            end
        end
        
        QuestTemplate.TriggerOriginal(self);
    end
end

function QuestDebug:PrintQuestStatus(_QuestID, _State, _Result)
    if self.m_QuestTrace then 
        local QuestState = GetKeyByValue(_State, QuestStates);
        local QuestResult = GetKeyByValue(_Result, QuestResults);
        local QuestName = QuestSystem.Quests[_QuestID].m_QuestName;
        Message("Quest '" ..QuestName.."' changed: State is now " ..QuestState.. "; Result is now " ..QuestResult);
    end
end

function QuestDebug:ActivateConsole()
    if self.m_DebugShell then
        Input.KeyBindDown(Keys.OemPipe, "XGUIEng.ShowWidget('ChatInput',1)", 2);
        
        -- Override chat input string, but only once
        if not GameCallback_GUI_ChatStringInputDone_Orig_QuestDebug then
            GameCallback_GUI_ChatStringInputDone_Orig_QuestDebug = GameCallback_GUI_ChatStringInputDone;
            GameCallback_GUI_ChatStringInputDone = function(_M)
                local Tokens = QuestDebug:TokenizeCommand(_M);
                if not QuestDebug:EvaluateCommand(Tokens) then
                    GameCallback_GUI_ChatStringInputDone_Orig_QuestDebug(_M);
                end
            end
        end
    end
end
function eval(_Input)
    return QuestDebug:EvaluateCommand(QuestDebug:TokenizeCommand(_Input));
end

function QuestDebug:TokenizeCommand(_Message)
    local Commands = {};
    local DAmberCommands = {_Message};
    local AmberCommands = {_Message};
    
    -- parse && delimiter
    local s, e = string.find(_Message, "%s+&&%s+");
    if s then
        DAmberCommands = {};
        while (s) do
            local tmp = string.sub(_Message, 1, s-1);
            table.insert(DAmberCommands, tmp);
            _Message = string.sub(_Message, e+1);
            s, e = string.find(_Message, "%s+&&%s+");
        end
        if string.len(_Message) > 0 then 
            table.insert(DAmberCommands, _Message);
        end
    end

    -- parse & delimiter
    if table.getn(DAmberCommands) > 0 then
        AmberCommands = {};
    end
    for i= 1, table.getn(DAmberCommands), 1 do
        local s, e = string.find(DAmberCommands[i], "%s+&%s+");
        if s then
            local LastCommand = "";
            while (s) do
                local tmp = string.sub(DAmberCommands[i], 1, s-1);
                table.insert(AmberCommands, LastCommand .. tmp);
                if string.find(tmp, " ") then
                    LastCommand = string.sub(tmp, 1, string.find(tmp, " ")-1) .. " ";
                end
                DAmberCommands[i] = string.sub(DAmberCommands[i], e+1);
                s, e = string.find(DAmberCommands[i], "%s+&%s+");
            end
            if string.len(DAmberCommands[i]) > 0 then 
                table.insert(AmberCommands, LastCommand .. DAmberCommands[i]);
            end
        else
            table.insert(AmberCommands, DAmberCommands[i]);
        end
    end

    -- parse spaces
    for i= 1, table.getn(AmberCommands), 1 do
        local CommandLine = {};
        local s, e = string.find(AmberCommands[i], "%s+");
        if s then
            while (s) do
                local tmp = string.sub(AmberCommands[i], 1, s-1);
                table.insert(CommandLine, tmp);
                AmberCommands[i] = string.sub(AmberCommands[i], e+1);
                s, e = string.find(AmberCommands[i], "%s+");
            end
            table.insert(CommandLine, AmberCommands[i]);
        else
            table.insert(CommandLine, AmberCommands[i]);
        end
        table.insert(Commands, CommandLine);
    end
    return Commands;
end

function QuestDebug:CreateScriptEvents()
    self.ScriptEvents.AlterQuestResult = QuestSync:CreateScriptEvent(function(name, _ExecutingPlayer, _QuestID, _Result)
        if _QuestID == 0 then
            if GUI.GetPlayerID() == _ExecutingPlayer then
                Message("Can not find quest!");
            end
            return;
        end
        if QuestSystem.Quests[_QuestID] then
            local QuestName = QuestSystem.Quests[_QuestID].m_QuestName;
            if _Result == QuestResults.Success then
                if GUI.GetPlayerID() == _ExecutingPlayer then
                    Message("Succeed quest: " ..QuestName);
                end
                QuestSystem.Quests[_QuestID]:Success();
            elseif _Result == QuestResults.Failure then
                if GUI.GetPlayerID() == _ExecutingPlayer then
                    Message("Fail quest: " ..QuestName);
                end
                QuestSystem.Quests[_QuestID]:Fail();
            elseif _Result == QuestResults.Interrupted then
                if GUI.GetPlayerID() == _ExecutingPlayer then
                    Message("Stop quest: " ..QuestName);
                end
                QuestSystem.Quests[_QuestID]:Interrupt();
            end
        end
    end);

    self.ScriptEvents.AlterQuestState = QuestSync:CreateScriptEvent(function(name, _ExecutingPlayer, _QuestID, _State)
        if _QuestID == 0 then
            if GUI.GetPlayerID() == _ExecutingPlayer then
                Message("Can not find quest!");
            end
            return;
        end
        if QuestSystem.Quests[_QuestID] then
            local QuestName = QuestSystem.Quests[_QuestID].m_QuestName;
            if _State == QuestStates.Active then
                if GUI.GetPlayerID() == _ExecutingPlayer then
                    Message("Start quest: " ..QuestName);
                end
                QuestSystem.Quests[_QuestID]:Trigger();
            elseif _State == -1 then
                if GUI.GetPlayerID() == _ExecutingPlayer then
                    Message("Restart quest: " ..QuestName);
                end
                Trigger.RequestTrigger(
                    Events.LOGIC_EVENT_EVERY_SECOND,
                    "",
                    QuestSystem.QuestLoop,
                    1,
                    {},
                    {QuestSystem.Quests[_QuestID].m_QuestID}
                );
                QuestSystem.Quests[_QuestID].m_State = QuestStates.Inactive;
                QuestSystem.Quests[_QuestID].m_Result = QuestResults.Undecided;
                QuestSystem.Quests[_QuestID]:Trigger();
            end
        end
    end);

    self.ScriptEvents.WakeUpHero = QuestSync:CreateScriptEvent(function(name, _ExecutingPlayer, _Hero)
        if Logic.IsHero(GetID(_Hero)) == 1 then
            local ID = ReplaceEntity(_Hero, Logic.GetEntityType(GetID(_Hero)));
            if GUI.GetPlayerID() == _ExecutingPlayer then
                Message("Hero " ..ID.. " has been ressurected!");
            end
        end
    end);

    self.ScriptEvents.AlterDiplomacyState = QuestSync:CreateScriptEvent(function(name, _ExecutingPlayer, _Player1, _Player2, _State)
        local Exploration = (_State == Diplomacy.Friendly and 1) or 0;
        Logic.SetShareExplorationWithPlayerFlag(_Player1, _Player2, Exploration);
        Logic.SetShareExplorationWithPlayerFlag(_Player2, _Player1, Exploration);	
        Logic.SetDiplomacyState(_Player1, _Player2, _State);
        if GUI.GetPlayerID() == _ExecutingPlayer then
            Message("Diplomacy state between " .._Player1.." and " .._Player2.. " is now " .._State.. "!");
        end
    end);

    self.ScriptEvents.ClearNotes = QuestSync:CreateScriptEvent(function(name, _ExecutingPlayer)
        if GUI.GetPlayerID() == _ExecutingPlayer then
            GUI.ClearNotes();
        end
    end);

    self.ScriptEvents.ShowQuestStatus = QuestSync:CreateScriptEvent(function(name, _ExecutingPlayer, _Option, _Quest)
        if GUI.GetPlayerID() ~= _ExecutingPlayer then
            return;
        end
        if _Option == "active" then
            for i= 1, table.getn(QuestSystem.Quests), 1 do 
                local ActiveQuests = "";
                if QuestSystem.Quests[i].m_State == QuestStates.Active then
                    ActiveQuests = ActiveQuests .. QuestSystem.Quests[i].m_QuestName .. " @cr ";
                end
                GUI.AddStaticNote(ActiveQuests);
            end
        elseif _Option == "names" then
            for i= 1, table.getn(QuestSystem.Quests), 1 do 
                local ActiveQuests = "";
                if _Quest and string.find(QuestSystem.Quests[i].m_QuestName, _Quest) then
                    ActiveQuests = ActiveQuests .. QuestSystem.Quests[i].m_QuestName .. " @cr ";
                end
                GUI.AddStaticNote(ActiveQuests);
            end
        elseif _Option == "detail" then
            local QuestID = GetQuestID(_Quest);
            if QuestID == 0 then
                Message("Can not find quest: " .._Quest);
            end
            local QuestName      = "Name: " ..QuestSystem.Quests[QuestID].m_QuestName.. " @cr ";
            local QuestState     = "State: " ..GetKeyByValue(QuestSystem.Quests[QuestID].m_State, QuestStates).. " @cr ";
            local QuestResult    = "Result: " ..GetKeyByValue(QuestSystem.Quests[QuestID].m_Result, QuestResults).. " @cr ";
            local QuestReceiver  = "Receiver: " ..QuestSystem.Quests[QuestID].m_Receiver.. " @cr ";
            local QuestTime      = "Time: " ..QuestSystem.Quests[QuestID].m_Time.. " @cr ";
            local QuestGoals     = "Objectives: " ..table.getn(QuestSystem.Quests[QuestID].m_Objectives).. " @cr ";
            local QuestTriggers  = "Conditions: " ..table.getn(QuestSystem.Quests[QuestID].m_Conditions).. " @cr ";
            local QuestRewards   = "Rewards: " ..table.getn(QuestSystem.Quests[QuestID].m_Rewards).. " @cr ";
            local QuestReprisals = "Reprisals: " ..table.getn(QuestSystem.Quests[QuestID].m_Reprisals);
            GUI.AddStaticNote(
                QuestName .. QuestState .. QuestResult .. QuestReceiver .. QuestTime .. QuestGoals .. QuestTriggers .. QuestRewards .. QuestReprisals
            );
        end
    end);

    self.ScriptEvents.ShowCheatCodes = QuestSync:CreateScriptEvent(function(name, _ExecutingPlayer, _Option)
        if GUI.GetPlayerID() ~= _ExecutingPlayer then
            return;
        end

        local MessageText = "unknown category: " .._Option;
        if _Option == "cheats" then
            MessageText = "CHEAT CATEGORIES: @cr ";
            MessageText = MessageText .. "Render settings: help camera @cr ";
            MessageText = MessageText .. "Game settings: help game @cr ";
            MessageText = MessageText .. "Entity cheats: help entity @cr ";
            MessageText = MessageText .. "Resource cheats: help resource @cr ";
            
        elseif _Option == "player" then
            MessageText = "PLAYER CHEATS: @cr ";
            MessageText = MessageText .. "(not in multiplayer) @cr ";
            MessageText = MessageText .. "control player 1: SHIFT + ALT + 1 @cr ";
            MessageText = MessageText .. "control player 2: SHIFT + ALT + 2 @cr ";
            MessageText = MessageText .. "control player 3: SHIFT + ALT + 3 @cr ";
            MessageText = MessageText .. "control player 4: SHIFT + ALT + 4 @cr ";
            MessageText = MessageText .. "control player 5: SHIFT + ALT + 5 @cr ";
            MessageText = MessageText .. "control player 6: SHIFT + ALT + 6 @cr ";
            MessageText = MessageText .. "control player 7: SHIFT + ALT + 7 @cr ";
            MessageText = MessageText .. "control player 8: SHIFT + ALT + 8 @cr ";
            
        elseif _Option == "camera" then
            MessageText = "CAMERA CHEATS: @cr ";
            MessageText = MessageText .. "Switch camera: CTRL + SHIFT + Num 9 @cr ";
            MessageText = MessageText .. "Increase angle: CTRL + Num 4 @cr ";
            MessageText = MessageText .. "Decrease angle: CTRL + Num 1 @cr ";
            MessageText = MessageText .. "Increase zoom: CTRL + Num 5 @cr ";
            MessageText = MessageText .. "Decrease zoom: CTRL + Num 2 @cr ";
            MessageText = MessageText .. "Toggle FoW: CTRL + SHIFT + F @cr ";
            MessageText = MessageText .. "Toggle GUI: CTRL + SHIFT + G @cr ";
            MessageText = MessageText .. "Toggle sky: CTRL + SHIFT + H @cr ";

        elseif _Option == "game" then
            MessageText = "GAME CHEATS: @cr ";
            MessageText = MessageText .. "(not in multiplayer) @cr ";
            MessageText = MessageText .. "Show FPS: CTRL + SHIFT + 1 @cr ";
            MessageText = MessageText .. "Reset speed: Num Multiply @cr ";
            MessageText = MessageText .. "Increase speed: Num Add @cr ";
            MessageText = MessageText .. "Decrease speed: Numm Subtract @cr ";
            MessageText = MessageText .. "Close game: CTRL + ALT + C @cr ";
            MessageText = MessageText .. "Restart map: CTRL + ALT + R @cr ";
        
        elseif _Option == "entity" then
            MessageText = "ENTITY CHEATS: @cr ";
            MessageText = MessageText .. "Change owner: SHIFT + 1 ... 8 @cr ";
            MessageText = MessageText .. "Hurt entity: CTRL + H @cr ";
            MessageText = MessageText .. "Heal entity: SHIFT + H @cr ";
            MessageText = MessageText .. "Cheat swordmen: CTRL + ALT + 1 @cr ";
            MessageText = MessageText .. "Cheat bowmen: CTRL + ALT + 2 @cr ";
            MessageText = MessageText .. "Cheat spearmen: CTRL + ALT + 3 @cr ";
            MessageText = MessageText .. "Cheat heavy cavalry: CTRL + ALT + 4 @cr ";
            MessageText = MessageText .. "Cheat light cavalry: CTRL + ALT + 5 @cr ";
            MessageText = MessageText .. "Cheat iron cannon: CTRL + ALT + 6 @cr ";
            MessageText = MessageText .. "Cheat siege cannon: CTRL + ALT + 7 @cr ";
            MessageText = MessageText .. "Cheat rifle: CTRL + ALT + 8 @cr ";

        elseif _Option == "resource" then
            MessageText = "RESOURCE CHEATS: @cr ";
            MessageText = MessageText .. "Cheat 100 gold: CTRL + F1 ... 8 @cr ";
            MessageText = MessageText .. "Cheat 100 cley: CTRL + F2 ... 8 @cr ";
            MessageText = MessageText .. "Cheat 100 wood: CTRL + F3 ... 8 @cr ";
            MessageText = MessageText .. "Cheat 100 stone: CTRL + F4 ... 8 @cr ";
            MessageText = MessageText .. "Cheat 100 Iron: CTRL + F5 ... 8 @cr ";
            MessageText = MessageText .. "Cheat 100 sulfur: CTRL + F6 ... 8 @cr ";
            MessageText = MessageText .. "Cheat 100 faith: CTRL + F7 ... 8 @cr ";
            MessageText = MessageText .. "Cheat 100 weather energy: CTRL + F8 ... 8 @cr ";
            MessageText = MessageText .. "Unlock all techs: CTRL + F9 ... 8 @cr ";
        end
        GUI.AddStaticNote(MessageText);
    end);

    self.ScriptEvents.ChangeEntityPlayer = QuestSync:CreateScriptEvent(function(name, _ExecutingPlayer, _Entity, _Player)
        if IsExisting(_Entity) then
            if Logic.IsLeader(_Entity) == 1 then
                Tools.ChangeGroupPlayerID(_Entity, _Player);
            else
                if Logic.IsEntityInCategory(_Entity,EntityCategories.Soldier) == 1 then
                    Tools.ChangeGroupPlayerID(SoldierGetLeader(_Entity), _Player);
                else
                    ChangePlayer(_Entity, _Player);
                end
            end
        end
    end);

    self.ScriptEvents.ChangeEntityHealth = QuestSync:CreateScriptEvent(function(name, _ExecutingPlayer, _Entity, _Flag)
        if IsExisting(_Entity) then
            if _Flag == 0 then
                if Logic.IsLeader(_Entity) == 1 then
                    local soldiers = {Logic.GetSoldiersAttachedToLeader(_Entity)};
                    if soldiers[1] == 0 then
                        Logic.HurtEntity(_Entity, 50);
                    else
                        Logic.HurtEntity(soldiers[2], 50);
                    end
                else
                    Logic.HurtEntity(_Entity, 50);
                end
            end
            if _Flag == 1 then
                Logic.HealEntity(_Entity, 50);
            end
        end
    end);

    self.ScriptEvents.CheatUnitAtMousePosition = QuestSync:CreateScriptEvent(function(name, _ExecutingPlayer, _X, _Y, _Flag)
        local pos = {X= _X, Y= _Y};
        if IsValidPosition(pos) then
            if _Flag == 1 then
                Tools.CreateGroup(GUI.GetPlayerID(), Entities.PU_LeaderSword4, 8, pos.X , pos.Y , 0);
                if GUI.GetPlayerID() == _ExecutingPlayer then
                    Message("cheating unit PU_LeaderSword4!");
                end
            elseif _Flag == 2 then
                Tools.CreateGroup(GUI.GetPlayerID(), Entities.PU_LeaderBow4, 8, pos.X , pos.Y , 0);
                if GUI.GetPlayerID() == _ExecutingPlayer then
                    Message("cheating unit PU_LeaderBow4!");
                end
            elseif _Flag == 3 then
                Tools.CreateGroup(GUI.GetPlayerID(), Entities.PU_LeaderPoleArm4, 8, pos.X , pos.Y , 0);
                if GUI.GetPlayerID() == _ExecutingPlayer then
                    Message("cheating unit PU_LeaderPoleArm4!");
                end
            elseif _Flag == 4 then
                Tools.CreateGroup(GUI.GetPlayerID(), Entities.PU_LeaderHeavyCavalry2, 3, pos.X , pos.Y , 0);
                if GUI.GetPlayerID() == _ExecutingPlayer then
                    Message("cheating unit PU_LeaderHeavyCavalry2!");
                end
            elseif _Flag == 5 then
                Tools.CreateGroup(GUI.GetPlayerID(), Entities.PU_LeaderCavalry2, 3, pos.X , pos.Y , 0);
                if GUI.GetPlayerID() == _ExecutingPlayer then
                    Message("cheating unit PU_LeaderCavalry2!");
                end
            elseif _Flag == 6 then
                Tools.CreateGroup(GUI.GetPlayerID(), Entities.PV_Cannon3, 0, pos.X , pos.Y , 0);
                if GUI.GetPlayerID() == _ExecutingPlayer then
                    Message("cheating unit PV_Cannon3!");
                end
            elseif _Flag == 7 then
                Tools.CreateGroup(GUI.GetPlayerID(), Entities.PV_Cannon4, 0, pos.X , pos.Y , 0);
                if GUI.GetPlayerID() == _ExecutingPlayer then
                    Message("cheating unit PV_Cannon4!");
                end
            elseif _Flag == 8 then
                if Entities.PU_LeaderRifle2 then
                    Tools.CreateGroup(GUI.GetPlayerID(), Entities.PU_LeaderRifle2, 8, pos.X , pos.Y , 0);
                    if GUI.GetPlayerID() == _ExecutingPlayer then
                        Message("cheating unit PU_LeaderRifle2!");
                    end
                end
            end
        else
            if GUI.GetPlayerID() == _ExecutingPlayer then
                Message("cheating unit failed!");
            end
        end
    end);

    self.ScriptEvents.AddResourcesToPlayer = QuestSync:CreateScriptEvent(function(name, _ExecutingPlayer, _Type, _Amount)
        Logic.AddToPlayersGlobalResource(_ExecutingPlayer, _Type, _Amount);
    end);

    self.ScriptEvents.CheatTechnologies = QuestSync:CreateScriptEvent(function(name, _ExecutingPlayer)
        CheatTechnologies(_ExecutingPlayer)
    end);
end

function QuestDebug:EvaluateCommand(_Tokens)
    for _, command in pairs(_Tokens) do
        local Action = string.lower(command[1]);        

        if Action == "load" then
            if QuestSync:IsMultiplayerGame() then
                return;
            end
            Script.Load(command[2]);
            Message("Loaded script " ..command[2]);
            return true;

        elseif Action == "win" then 
            local QuestID = GetQuestID(command[2]);
            QuestSync:SynchronizedCall(self.ScriptEvents.AlterQuestResult, GUI.GetPlayerID(), QuestID, QuestResults.Success);
            return true;

        elseif Action == "fail" then 
            local QuestID = GetQuestID(command[2]);
            QuestSync:SynchronizedCall(self.ScriptEvents.AlterQuestResult, GUI.GetPlayerID(), QuestID, QuestResults.Failure);
            return true;
        
        elseif Action == "stop" then 
            local QuestID = GetQuestID(command[2]);
            QuestSync:SynchronizedCall(self.ScriptEvents.AlterQuestResult, GUI.GetPlayerID(), QuestID, QuestResults.Interrupted);
            return true;

        elseif Action == "start" then 
            local QuestID = GetQuestID(command[2]);
            QuestSync:SynchronizedCall(self.ScriptEvents.AlterQuestState, GUI.GetPlayerID(), QuestID, QuestStates.Active);
            return true;
            
        elseif Action == "reset" then 
            local QuestID = GetQuestID(command[2]);
            QuestSync:SynchronizedCall(self.ScriptEvents.AlterQuestState, GUI.GetPlayerID(), QuestID, -1);
            return true;

        elseif Action == "wakeup" then 
            QuestSync:SynchronizedCall(self.ScriptEvents.WakeUpHero, GUI.GetPlayerID(), command[2]);
            return true;

        elseif Action == "diplomacy" then
            QuestSync:SynchronizedCall(self.ScriptEvents.AlterDiplomacyState, GUI.GetPlayerID(), command[2], command[3], command[4]);
            return true;

        elseif Action == "clear" then 
            QuestSync:SynchronizedCall(self.ScriptEvents.ClearNotes, GUI.GetPlayerID());
            return true;

        elseif Action == "show" then
            QuestSync:SynchronizedCall(self.ScriptEvents.ShowQuestStatus, GUI.GetPlayerID(), command[2], command[3]);
            return true;

        elseif Action == "help" then
            QuestSync:SynchronizedCall(self.ScriptEvents.ShowCheatCodes, GUI.GetPlayerID(), command[2]);
            return true;
        end
    end
    return false;
end

function QuestDebug:CreateCheats()
    if self.m_DebugKeys then
        -- Open quest shell
        Input.KeyBindDown(Keys.OemPipe, "XGUIEng.ShowWidget('ChatInput',1)",2);

        -- Render settings
        Input.KeyBindDown(Keys.ModifierControl + Keys.ModifierShift + Keys.D1,  "Game.ShowFPS(-1)", 2);
        Input.KeyBindDown(Keys.ModifierControl + Keys.ModifierShift + Keys.F,   "LocalKeyBindings_ToggleFoW()", 2);
        Input.KeyBindDown(Keys.ModifierControl + Keys.ModifierShift + Keys.G,   "Game.GUIActivate(-1)", 2);
        Input.KeyBindDown(Keys.ModifierControl + Keys.ModifierShift + Keys.Y,   "Display.SetRenderSky(-1)", 2);
        
        -- Changing entity owner
        Input.KeyBindDown(Keys.ModifierShift + Keys.D1, "Cheats_ChangePlayer(1)", 2);
        Input.KeyBindDown(Keys.ModifierShift + Keys.D2, "Cheats_ChangePlayer(2)", 2);
        Input.KeyBindDown(Keys.ModifierShift + Keys.D3, "Cheats_ChangePlayer(3)", 2);
        Input.KeyBindDown(Keys.ModifierShift + Keys.D4, "Cheats_ChangePlayer(4)", 2);
        Input.KeyBindDown(Keys.ModifierShift + Keys.D5, "Cheats_ChangePlayer(5)", 2);
        Input.KeyBindDown(Keys.ModifierShift + Keys.D6, "Cheats_ChangePlayer(6)", 2);
        Input.KeyBindDown(Keys.ModifierShift + Keys.D7, "Cheats_ChangePlayer(7)", 2);
        Input.KeyBindDown(Keys.ModifierShift + Keys.D8, "Cheats_ChangePlayer(8)", 2);

        -- Changing controling player
        if not QuestSync:IsMultiplayerGame() then
            Input.KeyBindDown(Keys.ModifierShift + Keys.ModifierAlt + Keys.D1, "GUI.SetControlledPlayer(1)", 2);
            Input.KeyBindDown(Keys.ModifierShift + Keys.ModifierAlt + Keys.D2, "GUI.SetControlledPlayer(2)", 2);
            Input.KeyBindDown(Keys.ModifierShift + Keys.ModifierAlt + Keys.D3, "GUI.SetControlledPlayer(3)", 2);
            Input.KeyBindDown(Keys.ModifierShift + Keys.ModifierAlt + Keys.D4, "GUI.SetControlledPlayer(4)", 2);
            Input.KeyBindDown(Keys.ModifierShift + Keys.ModifierAlt + Keys.D5, "GUI.SetControlledPlayer(5)", 2);
            Input.KeyBindDown(Keys.ModifierShift + Keys.ModifierAlt + Keys.D6, "GUI.SetControlledPlayer(6)", 2);
            Input.KeyBindDown(Keys.ModifierShift + Keys.ModifierAlt + Keys.D7, "GUI.SetControlledPlayer(7)", 2);
            Input.KeyBindDown(Keys.ModifierShift + Keys.ModifierAlt + Keys.D8, "GUI.SetControlledPlayer(8)", 2);
        end
        
        -- Change entity health
        Input.KeyBindDown(Keys.ModifierControl + Keys.H, "Cheats_ChangeHealth(0)", 2);
        Input.KeyBindDown(Keys.ModifierShift + Keys.H, "Cheats_ChangeHealth(1)", 2);
        
        -- Cheat units
        Input.KeyBindDown(Keys.ModifierControl + Keys.ModifierAlt + Keys.D1, "Cheats_CreateUnitUnderMouse(1)", 2);
        Input.KeyBindDown(Keys.ModifierControl + Keys.ModifierAlt + Keys.D2, "Cheats_CreateUnitUnderMouse(2)", 2);
        Input.KeyBindDown(Keys.ModifierControl + Keys.ModifierAlt + Keys.D3, "Cheats_CreateUnitUnderMouse(3)", 2);
        Input.KeyBindDown(Keys.ModifierControl + Keys.ModifierAlt + Keys.D4, "Cheats_CreateUnitUnderMouse(4)", 2);
        Input.KeyBindDown(Keys.ModifierControl + Keys.ModifierAlt + Keys.D5, "Cheats_CreateUnitUnderMouse(5)", 2);
        Input.KeyBindDown(Keys.ModifierControl + Keys.ModifierAlt + Keys.D6, "Cheats_CreateUnitUnderMouse(6)", 2);
        Input.KeyBindDown(Keys.ModifierControl + Keys.ModifierAlt + Keys.D7, "Cheats_CreateUnitUnderMouse(7)", 2);
        Input.KeyBindDown(Keys.ModifierControl + Keys.ModifierAlt + Keys.D8, "Cheats_CreateUnitUnderMouse(8)", 2);

        -- Cheat resources
        Input.KeyBindDown(Keys.ModifierControl + Keys.F1, "Cheats_AddResourcesToPlayer(ResourceType.GoldRaw, 100)", 2);
        Input.KeyBindDown(Keys.ModifierControl + Keys.F2, "Cheats_AddResourcesToPlayer(ResourceType.ClayRaw, 100)", 2);
        Input.KeyBindDown(Keys.ModifierControl + Keys.F3, "Cheats_AddResourcesToPlayer(ResourceType.WoodRaw, 100)", 2);
        Input.KeyBindDown(Keys.ModifierControl + Keys.F4, "Cheats_AddResourcesToPlayer(ResourceType.StoneRaw, 100)", 2);
        Input.KeyBindDown(Keys.ModifierControl + Keys.F5, "Cheats_AddResourcesToPlayer(ResourceType.IronRaw, 100)", 2);
        Input.KeyBindDown(Keys.ModifierControl + Keys.F6, "Cheats_AddResourcesToPlayer(ResourceType.SulfurRaw, 100)", 2);
        Input.KeyBindDown(Keys.ModifierControl + Keys.F7, "Cheats_AddResourcesToPlayer(ResourceType.Faith, 100)", 2);
        Input.KeyBindDown(Keys.ModifierControl + Keys.F8, "Cheats_AddResourcesToPlayer(ResourceType.WeatherEnergy, 100)", 2);
        Input.KeyBindDown(Keys.ModifierControl + Keys.F9, "Cheats_CheatTechnologies(1)");

        -- Game functions
        if not QuestSync:IsMultiplayerGame() then
            Input.KeyBindDown(Keys.Multiply, "Game.GameTimeReset()", 2);
            Input.KeyBindDown(Keys.Subtract, "Game.GameTimeSlowDown()", 2);
            Input.KeyBindDown(Keys.Add,      "Game.GameTimeSpeedUp()", 2);
            Input.KeyBindDown(Keys.ModifierControl + Keys.ModifierAlt + Keys.C, "Framework.CloseGame()", 2);
            Input.KeyBindDown(Keys.ModifierControl + Keys.ModifierAlt + Keys.R, "Framework.RestartMap()", 2);
        end

        -- Camera debug
        Input.KeyBindDown(Keys.ModifierControl + Keys.ModifierAlt + Keys.NumPad9, "Camera_ToggleDefault()", 2);
        Input.KeyBindDown(Keys.ModifierControl + Keys.NumPad4, "Camera_IncreaseAngle()", 2);
        Input.KeyBindDown(Keys.ModifierControl + Keys.NumPad1, "Camera_DecreaseAngle()", 2);
        Input.KeyBindDown(Keys.ModifierControl + Keys.NumPad5, "Camera_IncreaseZoom()", 2);
        Input.KeyBindDown(Keys.ModifierControl + Keys.NumPad2, "Camera_DecreaseZoom()", 2);
    end
end

function QuestDebug:CreateCheatMethods()
    -- Changing entity owner
    function Cheats_ChangePlayer(_player)
        local eID = GUI.GetEntityAtPosition(GUI.GetMousePosition());
        QuestSync:SynchronizedCall(self.ScriptEvents.ChangeEntityPlayer, GUI.GetPlayerID(), eID, _player);
    end

    -- Change entity health
    function Cheats_ChangeHealth(_flag)
        local eID = GUI.GetEntityAtPosition(GUI.GetMousePosition());
        QuestSync:SynchronizedCall(self.ScriptEvents.ChangeEntityHealth, GUI.GetPlayerID(), eID, _flag);
    end

    -- Cheat units
    function Cheats_CreateUnitUnderMouse(_flag)
        local mouse = {GUI.Debug_GetMapPositionUnderMouse()};
        QuestSync:SynchronizedCall(self.ScriptEvents.CheatUnitAtMousePosition, GUI.GetPlayerID(), mouse[1], mouse[2], _flag);
    end

    function Cheats_AddResourcesToPlayer(_Resource, _Amount)
        QuestSync:SynchronizedCall(self.ScriptEvents.AddResourcesToPlayer, GUI.GetPlayerID(), _Resource, _Amount);
    end

    function Cheats_CheatTechnologies(_PlayerID)
        QuestSync:SynchronizedCall(self.ScriptEvents.CheatTechnologies, GUI.GetPlayerID());
    end
end

function QuestDebug:OverrideSaveGameLoaded()
    AddOnSaveLoadedAction(function()
        QuestDebug:CreateCheats();
    end);
end

-- Callbacks ---------------------------------------------------------------- --

GameCallback_OnQuestStatusChanged_Orig_QsbQuestDebug = GameCallback_OnQuestStatusChanged;
function GameCallback_OnQuestStatusChanged(_QuestID, _State, _Result)
    if GameCallback_OnQuestStatusChanged_Orig_QsbQuestDebug then
        GameCallback_OnQuestStatusChanged_Orig_QsbQuestDebug(_QuestID, _State, _Result);
    end
    QuestDebug:PrintQuestStatus(_QuestID, _State, _Result);
end

