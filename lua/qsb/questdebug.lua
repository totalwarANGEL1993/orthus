-- ########################################################################## --
-- #  Red Dragon - Quest Debug                                              # --
-- #  --------------------------------------------------------------------  # --
-- #    Author:   totalwarANGEL                                             # --
-- #    Package:  Logic                                                     # --
-- ########################################################################## --

---
-- Implements a debug mode for the quest system featuring visual quest trace
-- on screen, advanced cheats and a simple shell for controlling quests while
-- the map is in development.
--
-- @set sort=true
--

QuestSystemDebug = {};

---
-- Activates the debug mode. Use the flags to decide which features you want
-- to use.
--
-- @param _QuestTrace [boolean] Display quest status changes
-- @param _DebugKeys [boolean] Activate debug cheats
-- @param _DebugShell [boolean] Activate debug shell
-- @local
--
function QuestSystemDebug:Activate(_QuestTrace, _DebugKeys, _DebugShell)
    self.m_QuestTrace = _QuestTrace == true;
    self.m_DebugKeys = _DebugKeys == true;
    self.m_DebugShell = _DebugShell == true;

    self:OverrideSaveGameLoaded();
    self:CreateCheats();
    self:CreateCheatMethods();
    self:ActivateConsole();
end

---
-- Displays a status change of a quest, but only if quest trace is active.
--
-- This function is called by GameCallback_OnQuestStatusChanged.
--
-- @param _QuestID [number] ID of quest
-- @param _State [number] Quest state
-- @param _Result [number] Result state
-- @local
--
function QuestSystemDebug:PrintQuestStatus(_QuestID, _State, _Result)
    if self.m_QuestTrace then 
        local QuestState = self:GetKeyByValue(QuestStates, _State);
        local QuestResult = self:GetKeyByValue(QuestResults, _Result);
        local QuestName = QuestSystem.Quests[_QuestID].m_QuestName;
        Message("Quest '" ..QuestName.."' changed: State is now " ..QuestState.. "; Result is now " ..QuestResult);
    end
end

---
-- Activates the cheat console if the debug shell flag is set.
-- @local
--
function QuestSystemDebug:ActivateConsole()
    if self.m_DebugShell then
        Input.KeyBindDown(Keys.OemPipe, "XGUIEng.ShowWidget('ChatInput',1)", 2);
        
        -- Override chat input string, but only once
        if not GameCallback_GUI_ChatStringInputDone_Orig_QuestSystemDebug then
            GameCallback_GUI_ChatStringInputDone_Orig_QuestSystemDebug = GameCallback_GUI_ChatStringInputDone;
            GameCallback_GUI_ChatStringInputDone = function(_M)
                local Tokens = QuestSystemDebug:TokenizeCommand(_M);
                if not QuestSystemDebug:EvaluateCommand(Tokens) then
                    GameCallback_GUI_ChatStringInputDone_Orig_QuestSystemDebug(_M);
                end
            end
        end
    end
end

---
-- Receives the message from the chat input and split it into tokens.
-- @param _Message [string] Message to tokenize
-- @local
--
function QuestSystemDebug:TokenizeCommand(_Message)
    local Commands = {_Message};
    
    -- parse & delimiter
    local s, e = string.find(_Message, " & ");
    if s then 
        Commands = {};
        while (s) do
            table.insert(Commands, string.sub(_Message, 1, s-1));
            _Message = string.sub(_Message, e+1);
            s, e = string.find(_Message, " & ");
        end
        if string.len(_Message) > 0 then 
            table.insert(Commands, _Message);
        end
    end

    -- parse single arguments
    for i= 1, table.getn(Commands), 1 do 
        local tmp = Commands[i];
        local s, e = string.find(tmp, "%s+");
        if s then 
            Commands[i] = {};
            while (s) do
                table.insert(Commands[i], string.sub(tmp, 1, s-1));
                tmp = string.sub(tmp, e+1);
                s, e = string.find(tmp, "%s+");
            end
            if string.len(tmp) > 0 then 
                table.insert(Commands[i], tmp);
            end
        else
            Commands[i] = {tmp};
        end
    end

    -- parse && repeater
    local i = 1;
    while (Commands[i]) do
        local j = 1;
        while (Commands[i][j]) do
            if Commands[i][j] == "&&" and Commands[i][j+1] then
                table.remove(Commands[i], j);

                local NewCommand = {};
                while (Commands[i][j] and Commands[i][j] ~= "&&") do
                    table.insert(NewCommand, Commands[i][j]);
                    table.remove(Commands[i], j);
                end
                table.insert(NewCommand, 1, Commands[i][j-table.getn(NewCommand)-1])
                table.insert(Commands, i+1, NewCommand);
            else
                j = j +1;
            end
        end
        i = i +1;
    end

    return Commands;
end

---
-- Takes a table with command tokens and executes the commands if possible.
-- @param _Tokens [table] List of tokens
-- @local
--
function QuestSystemDebug:EvaluateCommand(_Tokens)
    local CommandExecuted = false;
    for _, command in pairs(_Tokens) do
        local Action = string.lower(command[1]);        
        -- Quest stuff
        
        if Action == "win" then 
            CommandExecuted = true;
            local QuestID = GetQuestID(command[2]);
            if QuestID == 0 then
                Message("Can not find quest: " ..command[2]);
                return true;
            end
            Message("Succeed quest: " ..command[2]);
            QuestSystem.Quests[QuestID]:Success();

        elseif Action == "fail" then 
            CommandExecuted = true;
            local QuestID = GetQuestID(command[2]);
            if QuestID == 0 then
                Message("Can not find quest: " ..command[2]);
                return true;
            end
            Message("Fail quest: " ..command[2]);
            QuestSystem.Quests[QuestID]:Fail();
        
        elseif Action == "stop" then 
            CommandExecuted = true;
            local QuestID = GetQuestID(command[2]);
            if QuestID == 0 then
                Message("Can not find quest: " ..command[2]);
                return true;
            end
            Message("Stop quest: " ..command[2]);
            QuestSystem.Quests[QuestID]:Interrupt();

        elseif Action == "start" then 
            CommandExecuted = true;
            local QuestID = GetQuestID(command[2]);
            if QuestID == 0 then
                Message("Can not find quest: " ..command[2]);
                return true;
            end
            Message("Start quest: " ..command[2]);
            QuestSystem.Quests[QuestID]:Trigger();
            
        elseif Action == "reset" then 
            CommandExecuted = true;
            local QuestID = GetQuestID(command[2]);
            if QuestID == 0 then
                Message("Can not find quest: " ..command[2]);
                return true;
            end
            Message("Restart quest: " ..command[2]);
            Trigger.RequestTrigger(Events.LOGIC_EVENT_EVERY_TURN, "", QuestSystem.QuestLoop, 1, {}, {QuestSystem.Quests[QuestID].m_QuestID});
            QuestSystem.Quests[QuestID].m_State = QuestStates.Inactive;
            QuestSystem.Quests[QuestID].m_Result = QuestResults.Undecided;
            QuestSystem.Quests[QuestID]:Trigger();

        elseif Action == "wakeup" then 
            CommandExecuted = true;
            if Logic.IsHero(GetID(command[2])) == 1 then 
                ReplaceEntity(command[2], Logic.GetEntityType(GetID(command[2])));
            end

        elseif Action == "diplomacy" then
            CommandExecuted = true;
            local Exploration = (command[4] == Diplomacy.Friendly and 1) or 0;
            Logic.SetShareExplorationWithPlayerFlag(command[2], command[3], Exploration);
            Logic.SetShareExplorationWithPlayerFlag(command[3], command[2], Exploration);	
            Logic.SetDiplomacyState(command[2], command[3], command[4]);
            Message("Diplomacy state between " ..command[2].." and " ..command[3].. " is now " ..command[4].. "!");

        elseif Action == "clear" then 
            CommandExecuted = true;
            GUI.ClearNotes();

        elseif Action == "show" then 
            CommandExecuted = true;
            if command[2] == "active" then
                for i= 1, table.getn(QuestSystem.Quests), 1 do 
                    local ActiveQuests = "";
                    if QuestSystem.Quests[i].m_State == QuestStates.Active then
                        ActiveQuests = ActiveQuests .. QuestSystem.Quests[i].m_QuestName .. " @cr ";
                    end
                    GUI.AddStaticNote(ActiveQuests);
                end
            elseif command[2] == "names" then
                for i= 1, table.getn(QuestSystem.Quests), 1 do 
                    local ActiveQuests = "";
                    if command[3] and string.find(QuestSystem.Quests[i].m_QuestName, command[3]) then
                        ActiveQuests = ActiveQuests .. QuestSystem.Quests[i].m_QuestName .. " @cr ";
                    end
                    GUI.AddStaticNote(ActiveQuests);
                end
            elseif command[2] == "detail" then
                local QuestID = GetQuestID(command[3]);
                if QuestID == 0 then
                    Message("Can not find quest: " ..command[2]);
                end
                local QuestName      = "Name: " ..QuestSystem.Quests[QuestID].m_QuestName.. " @cr ";
                local QuestState     = "State: " ..QuestSystemDebug:GetKeyByValue(QuestStates, QuestSystem.Quests[QuestID].m_State).. " @cr ";
                local QuestResult    = "Result: " ..QuestSystemDebug:GetKeyByValue(QuestResults, QuestSystem.Quests[QuestID].m_Result).. " @cr ";
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

        elseif Action == "help" then
            CommandExecuted = true;
            local MessageText = "unknown category: " ..command[2];

            if command[2] == "cheats" then
                MessageText = "CHEAT CATEGORIES: @cr ";
                MessageText = MessageText .. "Render settings: help camera @cr ";
                MessageText = MessageText .. "Game settings: help game @cr ";
                MessageText = MessageText .. "Entity cheats: help entity @cr ";
                MessageText = MessageText .. "Resource cheats: help resource @cr ";
                
            elseif command[2] == "camera" then
                MessageText = "CAMERA CHEATS: @cr ";
                MessageText = MessageText .. "Switch camera: CTRL + SHIFT + Num 9 @cr ";
                MessageText = MessageText .. "Increase angle: CTRL + Num 4 @cr ";
                MessageText = MessageText .. "Decrease angle: CTRL + Num 1 @cr ";
                MessageText = MessageText .. "Increase zoom: CTRL + Num 5 @cr ";
                MessageText = MessageText .. "Decrease zoom: CTRL + Num 2 @cr ";
                MessageText = MessageText .. "Toggle FoW: CTRL + F @cr ";
                MessageText = MessageText .. "Toggle GUI: CTRL + G @cr ";
                MessageText = MessageText .. "Toggle sky: CTRL + H @cr ";

            elseif command[2] == "game" then
                MessageText = "GAME CHEATS: @cr ";
                MessageText = MessageText .. "Show FPS: CTRL + SHIFT + 1 @cr ";
                MessageText = MessageText .. "Reset speed: Num Multiply @cr ";
                MessageText = MessageText .. "Increase speed: Num Add @cr ";
                MessageText = MessageText .. "Decrease speed: Numm Subtract @cr ";
                MessageText = MessageText .. "Close game: CTRL + ALT + C @cr ";
                MessageText = MessageText .. "Restart map: CTRL + ALT + R @cr ";
            
            elseif command[2] == "entity" then
                MessageText = "ENTITY CHEATS: @cr ";
                MessageText = MessageText .. "Change owner: SHIFT + 1 ... 8 @cr ";
                MessageText = MessageText .. "Hurt entity: CTRL + H @cr ";
                MessageText = MessageText .. "Heal entity: SHIFT + H @cr ";
                MessageText = MessageText .. "Cheat swordmen: CTRL + ALT + 1 @cr ";
                MessageText = MessageText .. "Cheat bowmen: CTRL + ALT + 2 @cr ";
                MessageText = MessageText .. "Cheat rifle: CTRL + ALT + 3 @cr ";
                MessageText = MessageText .. "Cheat heavy cavalry: CTRL + ALT + 4 @cr ";
                MessageText = MessageText .. "Cheat siege cannon: CTRL + ALT + 5 @cr ";

            elseif command[2] == "resource" then
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
        end
    end
    return CommandExecuted;
end

---
-- Activates the cheat hotkeys. This function is automatically called when
-- a save is loaded.
-- @local
--
function QuestSystemDebug:CreateCheats()
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
        
        -- Change entity health
        Input.KeyBindDown(Keys.ModifierControl + Keys.H, "Cheats_ChangeHealth(0)", 2);
        Input.KeyBindDown(Keys.ModifierShift + Keys.H, "Cheats_ChangeHealth(1)", 2);
        
        -- Cheat units
        Input.KeyBindDown(Keys.ModifierControl + Keys.ModifierAlt + Keys.D1, "Cheats_CreateUnitUnderMouse(1)", 2);
        Input.KeyBindDown(Keys.ModifierControl + Keys.ModifierAlt + Keys.D2, "Cheats_CreateUnitUnderMouse(2)", 2);
        Input.KeyBindDown(Keys.ModifierControl + Keys.ModifierAlt + Keys.D3, "Cheats_CreateUnitUnderMouse(3)", 2);
        Input.KeyBindDown(Keys.ModifierControl + Keys.ModifierAlt + Keys.D4, "Cheats_CreateUnitUnderMouse(4)", 2);
        Input.KeyBindDown(Keys.ModifierControl + Keys.ModifierAlt + Keys.D5, "Cheats_CreateUnitUnderMouse(5)", 2);

        -- Cheat resources
        Input.KeyBindDown(Keys.ModifierControl + Keys.F1, "Logic.AddToPlayersGlobalResource(GUI.GetPlayerID(), ResourceType.GoldRaw, 100)", 2);
        Input.KeyBindDown(Keys.ModifierControl + Keys.F2, "Logic.AddToPlayersGlobalResource(GUI.GetPlayerID(), ResourceType.ClayRaw, 100)", 2);
        Input.KeyBindDown(Keys.ModifierControl + Keys.F3, "Logic.AddToPlayersGlobalResource(GUI.GetPlayerID(), ResourceType.WoodRaw, 100)", 2);
        Input.KeyBindDown(Keys.ModifierControl + Keys.F4, "Logic.AddToPlayersGlobalResource(GUI.GetPlayerID(), ResourceType.StoneRaw, 100)", 2);
        Input.KeyBindDown(Keys.ModifierControl + Keys.F5, "Logic.AddToPlayersGlobalResource(GUI.GetPlayerID(), ResourceType.IronRaw, 100)", 2);
        Input.KeyBindDown(Keys.ModifierControl + Keys.F6, "Logic.AddToPlayersGlobalResource(GUI.GetPlayerID(), ResourceType.SulfurRaw, 100)", 2);
        Input.KeyBindDown(Keys.ModifierControl + Keys.F7, "Logic.AddToPlayersGlobalResource(GUI.GetPlayerID(), ResourceType.Faith, 100)", 2);
        Input.KeyBindDown(Keys.ModifierControl + Keys.F8, "Logic.AddToPlayersGlobalResource(GUI.GetPlayerID(), ResourceType.WeatherEnergy, 100)", 2);
        Input.KeyBindDown(Keys.ModifierControl + Keys.F9, "CheatTechnologies(1)");

        -- Game functions
        Input.KeyBindDown(Keys.Multiply, "Game.GameTimeReset()", 2);
        Input.KeyBindDown(Keys.Subtract, "Game.GameTimeSlowDown()", 2);
        Input.KeyBindDown(Keys.Add,      "Game.GameTimeSpeedUp()", 2);
        Input.KeyBindDown(Keys.ModifierControl + Keys.ModifierAlt + Keys.C, "Framework.CloseGame()", 2);
        Input.KeyBindDown(Keys.ModifierControl + Keys.ModifierAlt + Keys.R, "Framework.RestartMap()", 2);

        -- Camera debug
        Input.KeyBindDown(Keys.ModifierControl + Keys.ModifierAlt + Keys.NumPad9, "Camera_ToggleDefault()", 2);
        Input.KeyBindDown(Keys.ModifierControl + Keys.NumPad4, "Camera_IncreaseAngle()", 2);
        Input.KeyBindDown(Keys.ModifierControl + Keys.NumPad1, "Camera_DecreaseAngle()", 2);
        Input.KeyBindDown(Keys.ModifierControl + Keys.NumPad5, "Camera_IncreaseZoom()", 2);
        Input.KeyBindDown(Keys.ModifierControl + Keys.NumPad2, "Camera_DecreaseZoom()", 2);
    end
end

---
-- Defines some functions used by the cheats.
-- @local
--
function QuestSystemDebug:CreateCheatMethods()
    -- Changing entity owner
    function Cheats_ChangePlayer(_player)
        local eID = GUI.GetEntityAtPosition(GUI.GetMousePosition());
        if IsExisting(eID) then
            if Logic.IsLeader(eID) == 1 then
                Tools.ChangeGroupPlayerID(eID,_player);
            else
                if Logic.IsEntityInCategory(eID,EntityCategories.Soldier) == 1 then
                    Tools.ChangeGroupPlayerID(SoldierGetLeaderEntityID(eID),_player);
                else
                    ChangePlayer(eID,_player);
                end
            end
        end
    end

    -- Change entity health
    function Cheats_ChangeHealth(_flag)
        local eID = GUI.GetEntityAtPosition(GUI.GetMousePosition());
        if IsExisting(eID) then
            if _flag == 0 then
                if Logic.IsLeader(eID) == 1 then
                    local soldiers = {Logic.GetSoldiersAttachedToLeader(eID)};
                    if soldiers[1] == 0 then
                        Logic.HurtEntity(eID,50);
                    else
                        Logic.HurtEntity(soldiers[2],50);
                    end
                else
                    Logic.HurtEntity(eID,50);
                end
            end
            if _flag == 1 then Logic.HealEntity(eID,50); end
        end
    end

    -- Cheat units
    function Cheats_CreateUnitUnderMouse(_flag)
        local mouse = {GUI.Debug_GetMapPositionUnderMouse()};
        local pos = {X= mouse[1], Y= mouse[2]};
        if IsValidPosition(pos) then
            if _flag == 1 then
                Tools.CreateGroup(GUI.GetPlayerID(), Entities.PU_LeaderSword4, 8, pos.X , pos.Y ,0 );
                Message("cheating unit PU_LeaderSword4!");
            elseif _flag == 2 then
                Tools.CreateGroup(GUI.GetPlayerID(), Entities.PU_LeaderBow4, 8, pos.X , pos.Y ,0 );
                Message("cheating unit PU_LeaderBow4!");
            elseif _flag == 3 then
                Tools.CreateGroup(GUI.GetPlayerID(), Entities.PU_LeaderRifle2, 8, pos.X , pos.Y ,0 );
                Message("cheating unit PU_LeaderRifle2!");
            elseif _flag == 4 then
                Tools.CreateGroup(GUI.GetPlayerID(), Entities.PU_LeaderHeavyCavalry2, 8, pos.X , pos.Y ,0 );
                Message("cheating unit PU_LeaderHeavyCavalry2!");
            elseif _flag == 5 then
                Tools.CreateGroup(GUI.GetPlayerID(), Entities.PV_Cannon4, 0, pos.X , pos.Y ,0 );
                Message("cheating unit PV_Cannon4!");
            end
        else
            Message("cheating unit failed!");
        end
    end
end

---
-- Overrides the save loaded callback to restore the debug functionallity.
-- @local
--
function QuestSystemDebug:OverrideSaveGameLoaded()
    Mission_OnSaveGameLoaded_Orig_QuestSystemDebug = Mission_OnSaveGameLoaded;
    Mission_OnSaveGameLoaded = function()
        Mission_OnSaveGameLoaded_Orig_QuestSystemDebug();

        QuestSystemDebug:CreateCheats();
    end
end

---
-- A helper for finding a key to a value in a table.
-- @local
--
-- @param _Table [table] Questioned table
-- @param _Value [mixed] Value to find
-- @return [string] Key of value
--
function QuestSystemDebug:GetKeyByValue(_Table, _Value)
    for k, v in pairs(_Table) do 
        if v == _Value then
            return k;
        end
    end
end

-- Callbacks ---------------------------------------------------------------- --

function GameCallback_OnQuestStatusChanged(_QuestID, _State, _Result)
    QuestSystemDebug:PrintQuestStatus(_QuestID, _State, _Result);
end

-- -------------------------------------------------------------------------- --

---
-- Checks if the position table contains a valid position on the map.
--
-- @param _pos [table] Position to check
-- @return [boolean] Position valid
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

SoldierTypes = {
	[Entities.CU_BanditSoldierBow1] = Entities.CU_BanditLeaderBow1,
	[Entities.CU_BanditSoldierSword1] = Entities.CU_BanditLeaderSword1,
	[Entities.CU_BanditSoldierSword2] = Entities.CU_BanditLeaderSword2,
	[Entities.CU_Barbarian_SoldierClub1] = Entities.CU_Barbarian_LeaderClub1,
	[Entities.CU_Barbarian_SoldierClub2] = Entities.CU_Barbarian_LeaderClub2,
	[Entities.CU_BlackKnight_SoldierMace1] = Entities.CU_BlackKnight_LeaderMace1,
	[Entities.CU_BlackKnight_SoldierMace2] = Entities.CU_BlackKnight_LeaderMace2,
	[Entities.CU_Evil_SoldierBearman1] = Entities.CU_Evil_LeaderBearman1,
	[Entities.CU_Evil_SoldierSkirmisher1] = Entities.CU_Evil_LeaderSkirmisher1,
	[Entities.PU_SoldierBow1] = Entities.PU_LeaderBow1,
	[Entities.PU_SoldierBow2] = Entities.PU_LeaderBow2,
	[Entities.PU_SoldierBow3] = Entities.PU_LeaderBow3,
	[Entities.PU_SoldierBow4] = Entities.PU_LeaderBow4,
	[Entities.PU_SoldierCavalry1] = Entities.PU_LeaderCavalry1,
	[Entities.PU_SoldierCavalry2] = Entities.PU_LeaderCavalry2,
	[Entities.PU_SoldierHeavyCavalry1] = Entities.PU_LeaderHeavyCavalry1,
	[Entities.PU_SoldierHeavyCavalry2] = Entities.PU_LeaderHeavyCavalry2,
	[Entities.PU_SoldierPoleArm1] = Entities.PU_LeaderPoleArm1,
	[Entities.PU_SoldierPoleArm2] = Entities.PU_LeaderPoleArm2,
	[Entities.PU_SoldierPoleArm3] = Entities.PU_LeaderPoleArm3,
	[Entities.PU_SoldierPoleArm4] = Entities.PU_LeaderPoleArm4,
	[Entities.PU_SoldierRifle1] = Entities.PU_LeaderRifle1,
	[Entities.PU_SoldierRifle2] = Entities.PU_LeaderRifle2,
	[Entities.PU_SoldierSword1] = Entities.PU_LeaderSword1,
	[Entities.PU_SoldierSword2] = Entities.PU_LeaderSword2,
	[Entities.PU_SoldierSword3] = Entities.PU_LeaderSword3,
	[Entities.PU_SoldierSword4] = Entities.PU_LeaderSword4,
};

---
-- Returns the leader entity ID of the soldier.
--
-- @param _eID [number] Entity ID of soldier
-- @return [number] Entity ID of leader
--
function SoldierGetLeaderEntityID(_eID)
	local leadType = SoldierTypes[Logic.GetEntityType(_eID)]
	if leadType then
		local pID = GetPlayer(_eID);
		local n,leaderID = Logic.GetPlayerEntities(pID, leadType, 1);
		local firstLeaderID = leaderID;
		if n > 0 then
			repeat
				local soldiers = {Logic.GetSoldiersAttachedToLeader(leaderID)};
				if soldiers[1] then
					for i = 2,soldiers[1]+1 do
						if soldiers[i] == _eID then
							return leaderID,soldiers[2];
						end
					end
				end
				leaderID = Logic.GetNextEntityOfPlayerOfType(leaderID);
			until leaderID == firstLeaderID;
		end
	end
	return _eID;
end

