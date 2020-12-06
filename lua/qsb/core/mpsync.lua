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
-- <li>qsb.core.oop</li>
-- </ul>
--
-- @set sort=true
--

MPSync = {
    ScriptEvents = {},
    Transactions = {},
    TransactionParameter = {},
    UniqueActionCounter = 1,
    UniqueTributeCounter = 100000,
};

---
-- Installs the module.
-- @within MPSync
-- @local
--
function MPSync:Install()
    self:OverrideMessageReceived();
    self:ActivateTributePaidTrigger();

    if CNetwork then
        CNetwork.SetNetworkHandler("MPSync_CNetwork_SnchronizedCall", function(_Name, _PlayerID, ...)
            if CNetwork.IsAllowedToManipulatePlayer(_Name, _PlayerID) then

            end;
        end);
    end
end

---
-- Creates an script event and returns the event ID. Use the ID to call the
-- created event.
-- @param[type=function] _Function Function to call
-- @within MPSync
-- @see MPSync:SnchronizedCall
--
function MPSync:CreateScriptEvent(_Function)
    self.UniqueActionCounter = self.UniqueActionCounter +1;
    local ActionIndex = self.UniqueActionCounter;

    self.ScriptEvents[ActionIndex] = {
        Function  = _Function,
    }    
    return self.UniqueActionCounter;
end

---
-- Calls the script event synchronous for all players.
-- @param[type=number] _Function ID of script event
-- @param              ...       List of Parameters (String or Number)
-- @within MPSync
-- @see MPSync:CreateScriptEvent
--
function MPSync:SnchronizedCall(_ID, ...)
    arg = arg or {};
    local Msg = "";
    if table.getn(arg) > 0 then
        for i= 1, table.getn(arg), 1 do
            Msg = Msg .. tostring(arg[i]) .. ":::";
        end
    end
    local PlayerID = GUI.GetPlayerID();
    local Time = Logic.GetTimeMs();
    
    if CNetwork then
        CNetwork.SendCommand(
            "MPSync_CNetwork_SnchronizedCall",
            GUI.GetPlayerID(),
            _ID,
            unpack(arg)
        );
    else
        self:TransactionSend(_ID, PlayerID, Time, Msg, arg);
    end
end
function MPSync_CNetwork_SnchronizedCall(_ID, ...)

end

function MPSync:TransactionSend(_ID, _PlayerID, _Time, _Msg, _Parameter)
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
        local ActivePlayers = MPSync:GetActivePlayers();
        local AllAcksReceived = true;
        for i= 1, table.getn(ActivePlayers), 1 do
            if _PlayerID ~= ActivePlayers[i] and not MPSync.Transactions[Hash][ActivePlayers[i]] then
                AllAcksReceived = false;
            end
        end
        if AllAcksReceived == true then
            local ID = MPSync:CreateTribute(_PlayerID, _ID, unpack(_Parameter));
            MPSync:PayTribute(_PlayerID, ID);
            return true;
        end
    end, _PlayerID, Hash, Logic.GetTime(), unpack(_Parameter));
end

function MPSync:TransactionAcknowledge(_Hash, _Time)
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

function MPSync:TransactionManage(_Type, _Msg)
    -- Handle received request
    if _Type == 1 then
        local Parameters      = self:TransactionSplitMessage(_Msg);
        local Hash            = table.remove(Parameters, 1);
        local Action          = table.remove(Parameters, 1);
        local SendingPlayerID = table.remove(Parameters, 1);
        local Timestamp       = table.remove(Parameters, 1);
        if SendingPlayerID ~= GUI.GetPlayerID() then
            self:TransactionAcknowledge(Hash, Timestamp);
            MPSync:CreateTribute(SendingPlayerID, Action, unpack(Parameters));
            -- StartSimpleHiResJobEx(function(_Hash, _Time)
            --     if _Time +2 < Logic.GetTime() then
            --         -- Message("DEBUG: Timeout for " .._Hash);
            --         return true;
            --     end
            --     if not MPSync:IsPlayerActive(SendingPlayerID) then
            --         return true;
            --     end
            --     if self.Transactions[Hash][SendingPlayerID] == true then
            --         MPSync.ScriptEvents[Action].Function(unpack(Parameters));
            --         return true;
            --     end
            -- end, Hash, Logic.GetTime());
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

function MPSync:TransactionSplitMessage(_Msg)
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

---
-- 
-- @within MPSync
-- @local
--
function MPSync:CreateTribute(_PlayerID, _ID, ...)
    self.UniqueTributeCounter = self.UniqueTributeCounter +1;
    Logic.AddTribute(_PlayerID, self.UniqueTributeCounter, 0, 0, "", {[ResourceType.Gold] = 0});
    self.TransactionParameter[self.UniqueTributeCounter] = {
        Action    = _ID,
        Parameter = copy(arg),
    };
    return self.UniqueTributeCounter;
end

---
-- 
-- @within MPSync
-- @local
--
function MPSync:PayTribute(_PlayerID, _ID)
    GUI.PayTribute(_PlayerID, _ID);
end

---
-- 
-- @within MPSync
-- @local
--
function MPSync:ActivateTributePaidTrigger()
    QuestSystem:StartInlineJob(
        Events.LOGIC_EVENT_TRIBUTE_PAID,
        function()
            MPSync:OnTributePaidTrigger(Event.GetTributeUniqueID());
        end
    );
end

---
-- 
-- @within MPSync
-- @local
--
function MPSync:OnTributePaidTrigger(_ID)
    if self.TransactionParameter[_ID] then
        local ActionID  = self.TransactionParameter[_ID].Action;
        local Parameter = self.TransactionParameter[_ID].Parameter;
        if self.ScriptEvents[ActionID] then
            self.ScriptEvents[ActionID].Function(unpack(Parameter));
        end
    end
end

---
-- Overrides the internal message callback.
-- @within MPSync
-- @local
--
function MPSync:OverrideMessageReceived()
    if self.IsActive then
        return true;
    end
    self.IsActive = true;

    MPGame_ApplicationCallback_ReceivedChatMessage_Orig_MPSync = MPGame_ApplicationCallback_ReceivedChatMessage
    MPGame_ApplicationCallback_ReceivedChatMessage = function(_Message, _AlliedOnly, _SenderPlayerID)
        -- Receive transaction
        local s, e = string.find(_Message, "___MPTransact:::");
        if e then
            MPSync:TransactionManage(1, string.sub(_Message, e+1));
            return;
        end
        -- Receive ack
        local s, e = string.find(_Message, "___MPAcknowledge:::");
        if e then
            MPSync:TransactionManage(2, string.sub(_Message, e+1));
            return;
        end
        -- Execute callback
        MPGame_ApplicationCallback_ReceivedChatMessage_Orig_MPSync(_Message, _AlliedOnly, _SenderPlayerID);
    end
end

---
-- Checks if the current mission is running as a Multiplayer game.
-- @return[type=boolean] Mission runs in multiplayer
-- @within MPSync
-- @local
--
function MPSync:IsMultiplayerGame()
    return XNetwork.Manager_DoesExist() == 1;
end

---
-- Returns true, if the copy of the game is the History Edition.
-- @return[type=boolean] Game is History Edition
-- @within MPSync
-- @local
--
function MPSync:IsHistoryEdition()
    return XNetwork.Manager_IsNATReady ~= nil;
end

---
-- Returns true, if the copy of the game is the Community Edition.
-- (e.g. Kimichuras Community Server)
-- @return[type=boolean] Game is Community Edition
-- @within MPSync
-- @local
--
function MPSync:IsCommunityEdition()
    return CNetwork ~= nil;
end

---
-- Returns true, if the copy of the game is the original version.
-- @return[type=boolean] Game is Original Edition
-- @within MPSync
-- @local
--
function MPSync:IsOriginal()
    return not self:IsHistoryEdition() and not self:IsCommunityEdition();
end

---
-- Returns true, if the game is properly patched to version 1.06.0217. If the
-- copy of the game is not the original than it is assumed that the game has
-- been patched.
-- @return[type=boolean] Game has latest patch
-- @within MPSync
-- @local
--
function MPSync:IsPatched()
    if not self:IsOriginal() then
        return true;
    end
    return string.find(Framework.GetProgramVersion(), "1.06.0217") ~= nil;
end

---
-- 
-- @within MPSync
-- @local
--
function MPSync:IsPlayerActive(_PlayerID)
    local Players = {};
    if self:IsMultiplayerGame() then
        return Logic.PlayerGetGameState(_PlayerID) == 1;
    end
    return true;
end

---
-- Returns the number of human players. In Singleplayer this will always be 1.
-- @return[type=number] Amount of humans
-- @within MPSync
-- @local
--
function MPSync:GetActivePlayers()
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
-- Returns the team the player is in.
-- @param[type=number] _PlayerID ID of player
-- @return[type=number] Team of player
-- @within MPSync
-- @local
--
function MPSync:GetTeamOfPlayer(_PlayerID)
    if self:IsMultiplayerGame() then
        return XNetwork.GameInformation_GetPlayerTeam(_PlayerID);
    else
        return _PlayerID;
    end
end

-- CNetwork.SetNetworkHandler("CreateHaybale", function(name, _playerId, _x, _y)
--     if CNetwork.IsAllowedToManipulatePlayer(name, _playerId) then
--         local time = Logic.GetTimeMs();
--         if time - SheepWar.Cooldowns[_playerId] >= 4000 then
--             Logic.CreateEntity(Entities.XD_MiscHaybale2, _x, _y, 0, 1);
--             SheepWar.Cooldowns[_playerId] = time;
--         end;
--     end;
-- end);


-- -- aufrufen durch gui o. ä.
-- CNetwork.SendCommand("CreateHaybale", GUI.GetPlayerID(), GUI.Debug_GetMapPositionUnderMouse());
