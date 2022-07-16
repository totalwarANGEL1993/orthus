-- ########################################################################## --
-- #  MP Syncing                                                            # --
-- #  --------------------------------------------------------------------  # --
-- #    Author:   totalwarANGEL                                             # --
-- ########################################################################## --

---
-- This module provides a simple synchronization for multiplayer maps.
--
-- Synchronization is done by creating an event that houses a function and
-- optional parameters. These Events can be fired to synchronize code called
-- from the GUI hence only by one player.
--
-- <b>Required modules:</b>
-- <ul>
-- <li>qsb.oop</li>
-- <li>qsb.quest.questtools</li>
-- </ul>
--
-- @set sort=true
--

QuestSync = {
    ScriptEvents = {},
    Transactions = {},
    TransactionParameter = {},
    UniqueActionCounter = 1,
    UniqueTributeCounter = 999,
};

---
-- Installs the module.
-- @within QuestSync
-- @local
--
function QuestSync:Install()
    self:OverrideMessageReceived();
    self:ActivateTributePaidTrigger();
end

---
-- Creates an script event and returns the event ID. Use the ID to call the
-- created event.
-- @param[type=function] _Function Function to call
-- @see QuestSync:SynchronizedCall
--
function QuestSync:CreateScriptEvent(_Function)
    self.UniqueActionCounter = self.UniqueActionCounter +1;
    local ActionIndex = self.UniqueActionCounter;

    self.ScriptEvents[ActionIndex] = {
        Function = _Function,
        CNetwork = "QuestSync_CNetworkHandler_" .. self.UniqueActionCounter;
    };
    if CNetwork then
        CNetwork.SetNetworkHandler(
            self.ScriptEvents[ActionIndex].CNetwork,
            _Function
        );
    end
    return self.UniqueActionCounter;
end

---
-- Removes an script event.
-- @param[type=number] _ID ID of event
-- @see QuestSync:CreateScriptEvent
--
function QuestSync:DeleteScriptEvent(_ID)
    if _ID and self.ScriptEvents[_ID] then
        self.ScriptEvents[_ID] = nil;
    end
end

---
-- Calls the script event synchronous for all players.
-- @param[type=number] _ID ID of script event
-- @param              ... List of Parameters (String or Number)
-- @see QuestSync:CreateScriptEvent
--
function QuestSync:SynchronizedCall(_ID, ...)
    arg = arg or {};
    local Msg = "";
    if table.getn(arg) > 0 then
        for i= 1, table.getn(arg), 1 do
            Msg = Msg .. tostring(arg[i]) .. ":::";
        end
    end
    if CNetwork then
        local Name = self.ScriptEvents[_ID].CNetwork;
        CNetwork.SendCommand(Name, unpack(arg));
    else
        local PlayerID = GUI.GetPlayerID();
        local Time = Logic.GetTimeMs();
        self:TransactionSend(_ID, PlayerID, Time, Msg, arg);
    end
end

function QuestSync:TransactionSend(_ID, _PlayerID, _Time, _Msg, _Parameter)
    -- Create message
    _Msg = _Msg or "";
    local PreHashedMsg = "".._ID..":::" .._PlayerID..":::" .._Time.. ":::" .._Msg;
    local Hash = _ID.. "_" .._PlayerID.. "_" .._Time;
    local TransMsg = "___MPTransact:::"..Hash..":::" ..PreHashedMsg;
    self.Transactions[Hash] = {};
    -- Send message
    if self:IsMultiplayerGame() then
        XNetwork.Chat_SendMessageToAll(TransMsg);
    else
        MPGame_ApplicationCallback_ReceivedChatMessage(TransMsg, 0, _PlayerID);
    end
    -- Wait for ack
    StartSimpleHiResJobEx(function(_PlayerID, _Hash, _Time, ...)
        if _Time +2 < Logic.GetTime() then
            -- Message("DEBUG: Timeout for " .._Hash);
            return true;
        end
        local ActivePlayers = QuestSync:GetActivePlayers();
        local AllAcksReceived = true;
        for i= 1, table.getn(ActivePlayers), 1 do
            if _PlayerID ~= ActivePlayers[i] and not QuestSync.Transactions[Hash][ActivePlayers[i]] then
                AllAcksReceived = false;
            end
        end
        if AllAcksReceived == true then
            table.insert(_Parameter, 1, -1);
            local ID = QuestSync:CreateTribute(_PlayerID, _ID, unpack(_Parameter));
            QuestSync:PayTribute(_PlayerID, ID);
            return true;
        end
    end, _PlayerID, Hash, Logic.GetTime(), unpack(_Parameter));
end

function QuestSync:TransactionAcknowledge(_Hash, _Time)
    -- Create message
    local PlayerID = GUI.GetPlayerID();
    local TransMsg = "___MPAcknowledge:::" .._Hash.. ":::" ..PlayerID.. ":::" .._Time.. ":::";
    -- Send message
    if self:IsMultiplayerGame() then
        XNetwork.Chat_SendMessageToAll(TransMsg);
    else
        MPGame_ApplicationCallback_ReceivedChatMessage(TransMsg, 0, PlayerID);
    end
end

function QuestSync:TransactionManage(_Type, _Msg)
    -- Handle received request
    if _Type == 1 then
        local Parameters      = self:TransactionSplitMessage(_Msg);
        local Hash            = table.remove(Parameters, 1);
        local Action          = table.remove(Parameters, 1);
        local SendingPlayerID = table.remove(Parameters, 1);
        local Timestamp       = table.remove(Parameters, 1);
        if SendingPlayerID ~= GUI.GetPlayerID() then
            self:TransactionAcknowledge(Hash, Timestamp);
            QuestSync:CreateTribute(SendingPlayerID, Action, unpack(Parameters));
        end
    -- Handle received client ack
    elseif _Type == 2 then
        local Parameters = self:TransactionSplitMessage(_Msg);
        local Hash       = table.remove(Parameters, 1);
        local PlayerID   = table.remove(Parameters, 1);
        local Timestamp  = table.remove(Parameters, 1);
        self.Transactions[Hash] = self.Transactions[Hash] or {};
        self.Transactions[Hash][PlayerID] = true;
    end
end

function QuestSync:TransactionSplitMessage(_Msg)
    local MsgParts = {};
    local Msg = _Msg;
    repeat
        local s, e = string.find(Msg, ":::");
        local PartString = string.sub(Msg, 1, s-1);
        local PartNumber = tonumber(PartString);
        local Part = (PartNumber ~= nil and PartNumber) or PartString;
        table.insert(MsgParts, Part);
        Msg = string.sub(Msg, e+1);
    until Msg == "";
    return MsgParts;
end

function QuestSync:CreateTribute(_PlayerID, _ID, ...)
    self.UniqueTributeCounter = self.UniqueTributeCounter +1;
    Logic.AddTribute(_PlayerID, self.UniqueTributeCounter, 0, 0, "", {[ResourceType.Gold] = 0});
    self.TransactionParameter[self.UniqueTributeCounter] = {
        Action    = _ID,
        Parameter = copy(arg),
    };
    return self.UniqueTributeCounter;
end

function QuestSync:PayTribute(_PlayerID, _TributeID)
    GUI.PayTribute(_PlayerID, _TributeID);
end

function QuestSync:ActivateTributePaidTrigger()
    StartInlineJob(
        Events.LOGIC_EVENT_TRIBUTE_PAID,
        function()
            QuestSync:OnTributePaidTrigger(Event.GetTributeUniqueID());
        end
    );
end

function QuestSync:OnTributePaidTrigger(_ID)
    if self.TransactionParameter[_ID] then
        local ActionID  = self.TransactionParameter[_ID].Action;
        local Parameter = self.TransactionParameter[_ID].Parameter;
        if self.ScriptEvents[ActionID] then
            self.ScriptEvents[ActionID].Function(unpack(Parameter));
        end
    end
end

function QuestSync:OverrideMessageReceived()
    if self.IsActive then
        return true;
    end
    self.IsActive = true;

    MPGame_ApplicationCallback_ReceivedChatMessage_Orig_QuestSync = MPGame_ApplicationCallback_ReceivedChatMessage
    MPGame_ApplicationCallback_ReceivedChatMessage = function(_Message, _AlliedOnly, _SenderPlayerID)
        -- Receive transaction
        local s, e = string.find(_Message, "___MPTransact:::");
        if e then
            QuestSync:TransactionManage(1, string.sub(_Message, e+1));
            return;
        end
        -- Receive ack
        local s, e = string.find(_Message, "___MPAcknowledge:::");
        if e then
            QuestSync:TransactionManage(2, string.sub(_Message, e+1));
            return;
        end
        -- Execute callback
        MPGame_ApplicationCallback_ReceivedChatMessage_Orig_QuestSync(_Message, _AlliedOnly, _SenderPlayerID);
    end
end

---
-- Checks if the current mission is running as a Multiplayer game.
-- @return[type=boolean] Mission runs in multiplayer
-- @local
--
function QuestSync:IsMultiplayerGame()
    return XNetwork.Manager_DoesExist() == 1;
end

---
-- Returns true, if the copy of the game is the History Edition.
-- @return[type=boolean] Game is History Edition
-- @local
--
function QuestSync:IsHistoryEdition()
    return XNetwork.Manager_IsNATReady ~= nil;
end

---
-- Returns true, if the copy of the game is the Community Edition.
-- (e.g. Kimichuras Community Server)
-- @return[type=boolean] Game is Community Edition
-- @local
--
function QuestSync:IsCNetwork()
    return CNetwork ~= nil;
end

---
-- Returns true, if the copy of the game is the original version.
-- @return[type=boolean] Game is Original Edition
-- @local
--
function QuestSync:IsOriginal()
    return not self:IsHistoryEdition() and not self:IsCNetwork();
end

---
-- Returns true, if the game is properly patched to version 1.06.0217. If the
-- copy of the game is not the original than it is assumed that the game has
-- been patched.
-- @return[type=boolean] Game has latest patch
-- @local
--
function QuestSync:IsPatched()
    if not self:IsOriginal() then
        return true;
    end
    return string.find(Framework.GetProgramVersion(), "1.06.0217") ~= nil;
end

---
-- Returns true, if the player on this ID is active.
-- @param[type=number] _PlayerID ID of player
-- @return[type=boolean] Player is active
-- @local
--
function QuestSync:IsPlayerActive(_PlayerID)
    local Players = {};
    if self:IsMultiplayerGame() then
        return Logic.PlayerGetGameState(_PlayerID) == 1;
    end
    return _PlayerID == GUI.GetPlayerID();
end

---
-- Returns the player ID of the host
-- @return[type=number] ID of Player
-- @local
--
function QuestSync:GetHostPlayerID()
    if self:IsMultiplayerGame() then
        for k, v in pairs(self:GetActivePlayers()) do
            local HostNetworkAddress   = XNetwork.Host_UserInSession_GetHostNetworkAddress();
            local PlayerNetworkAddress = XNetwork.GameInformation_GetNetworkAddressByPlayerID(v);
            return v;
        end
    end
    return GUI.GetPlayerID();
end

---
-- Returns true, if the player is the host.
-- @param[type=number] _PlayerID ID of player
-- @return[type=boolean] Player is host
-- @local
--
function QuestSync:IsPlayerHost(_PlayerID)
    if self:IsMultiplayerGame() then
        local HostNetworkAddress   = XNetwork.Host_UserInSession_GetHostNetworkAddress();
        local PlayerNetworkAddress = XNetwork.GameInformation_GetNetworkAddressByPlayerID(_PlayerID);
        return HostNetworkAddress == PlayerNetworkAddress;
    end
    return true;
end

---
-- Returns the number of human players. In Singleplayer this will always be 1.
-- @return[type=number] Amount of humans
-- @within QuestSync
--
function QuestSync:GetActivePlayers()
    local Players = {};
    if self:IsMultiplayerGame() then
        -- TODO: Does that fix everything for Community Server?
        for i= 1, table.getn(Score.Player), 1 do
            if Logic.PlayerGetGameState(i) == 1 then
                table.insert(Players, i);
            end
        end
    else
        table.insert(Players, GUI.GetPlayerID());
    end
    return Players;
end

---
-- Returns all active teams.
-- @return[type=number] List of teams
-- @within QuestSync
--
function QuestSync:GetActiveTeams()
    if self:IsMultiplayerGame() then
        local Teams = {};
        for k, v in pairs(self:GetActivePlayers()) do
            local Team = self:GetTeamOfPlayer(v);
            if not IsInTable(Team, Teams) then
                table.insert(Teams, Team);
            end
        end
        return Teams;
    else
        return {1};
    end
end

---
-- Returns the team the player is in.
-- @param[type=number] _PlayerID ID of player
-- @return[type=number] Team of player
-- @within QuestSync
--
function QuestSync:GetTeamOfPlayer(_PlayerID)
    if self:IsMultiplayerGame() then
        return XNetwork.GameInformation_GetPlayerTeam(_PlayerID);
    else
        return _PlayerID;
    end
end

