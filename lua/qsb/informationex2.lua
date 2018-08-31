-- ########################################################################## --
-- #  Interaction                                                           # --
-- #  --------------------------------------------------------------------  # --
-- #    Author:   totalwarANGEL                                             # --
-- ########################################################################## --

---
-- This module adds some briefing improvements. Some are just for cosmetics,
-- some are fixing pittful bugs, some offer helpful new features.
--
-- @set sort=true
--

QuestBriefing = {
    CurrentBriefingPage = {},
}

---
-- Installs the QuestBriefing mod.
-- @within QuestBriefing
-- @local
--
function QuestBriefing:Install()
    self:OverrideMultipleChoice();
    self:OverrideCinematic();
    self:OverrideEscape();
    self:CreateAddPageFunctions();
end

---
-- Returns the number of the extension.
-- @return [number] Extension number
-- @within QuestBriefing
-- @local
--
function QuestBriefing:GetExtraNumber()
    return tonumber(string.sub(Framework.GetProgramVersion(), string.len(Version)));
end

---
-- Overrides the escape callback.
-- @within QuestBriefing
-- @local
--
function QuestBriefing:OverrideEscape()
    GameCallback_Escape_Orig_QuestBriefing = GameCallback_Escape;
    GameCallback_Escape = function()
        -- Briefing no escape
        if IsBriefingActive() then
            if not briefingState.noEscape then
                return;
            end
        end
        -- Escape cutscene
        if gvCutscene then
			gvCutscene.Skip = true;
		end

        GameCallback_Escape_Orig_QuestBriefing();
	end
end

---
-- Overrides the briefing and cutscene functions that enter or leave the
-- cinematic mode.
--
-- Issues:
-- <ul>
-- <li>Implements the noEscape swith for briefings</li>
-- <li>Fixes the buggy game clock</li>
-- </ul>
--
-- @within QuestBriefing
-- @local
--
function QuestBriefing:OverrideCinematic()
    -- Briefings --

    StartBriefing_Orig_QuestBriefing = StartBriefing;
    StartBriefing = function(_briefing)
        assert(type(_briefing) == "table");
        if _briefing.noEscape then
            briefingState.noEscape = true;
        end
        if XGUIEng.IsWidgetShown("GameClock") == 1 then
			XGUIEng.ShowWidget("GameClock", 0);
			gvGameClockWasShown = true;
        end
		Game.GameTimeReset();
        GUI.ClearNotes();
        return StartBriefing_Orig_QuestBriefing(_briefing);
    end

    EndBriefing_Orig_QuestBriefing = EndBriefing;
    EndBriefing = function()
        if briefingState.noEscape then
            briefingState.noEscape = nil;
        end
        if gvGameClockWasShown then
			XGUIEng.ShowWidget("GameClock", 1);
			gvGameClockWasShown = false;
		end
        return EndBriefing_Orig_QuestBriefing();
    end

    -- Cutscenes --

    if StartCutscene then
        StartCutscene_Orig_QuestBriefing = StartCutscene;
        StartCutscene = function(_Cutscene,_SkipCutscene)
            QuestBriefing:SetBriefingLooks(true);
            Game.GameTimeReset();
            GUI.ClearNotes();

            if XGUIEng.IsWidgetShown("GameClock") == 1 then
				XGUIEng.ShowWidget("GameClock",0)
				gvGameClockWasShown = true
			end
            return StartCutscene_Orig_QuestBriefing(_Cutscene,_SkipCutscene);
        end
    end

    if CutsceneDone then
        CutsceneDone_Orig_QuestBriefing = CutsceneDone;
        CutsceneDone = function()
            if gvGameClockWasShown then
				XGUIEng.ShowWidget("GameClock",1)
				gvGameClockWasShown = false
			end
			return CutsceneDone_Orig_QuestBriefing();
		end
    end
end

---
-- Initalizes the add pages functions for simpler briefing pages.
-- @within QuestBriefing
-- @local
--
function QuestBriefing:CreateAddPageFunctions()

end

---
-- Displays the selectable text for the multiple choice page.
--
-- @within QuestBriefing
-- @local
--
function QuestBriefing:DisplayOptionSelection()
    local Options = briefingBook[1][briefingState.page].mc.options;

    local Text = "";
    for i= 1, table.getn(Options), 1 do
        if i == Options.current then
            Text = Text .. " @color:244,184,0 ";
        end
        Text = Text .. Options[i][1] .. " @cr ";
    end
    PrintMCText(text);
end

---
--
--
-- @within QuestBriefing
-- @local
--
function QuestBriefing:ActivateBriefingHotKeys()
    function KeyBinding_QuestBriefing_KeyboardAction(_Action)
        if IsBriefingActive() then
            if _Action == 1 then
                QuestBriefing:OnUpPressed();
            elseif _Action == 2 then
                QuestBriefing:OnDownPressed();
            else
                QuestBriefing:OnEnterPressed();
            end
        end
    end

    Input.KeyBindDown(Keys.Up, "KeyBinding_QuestBriefing_KeyboardAction(1)", 2);
    Input.KeyBindDown(Keys.Down, "KeyBinding_QuestBriefing_KeyboardAction(2)", 2);
    Input.KeyBindDown(Keys.Enter, "KeyBinding_QuestBriefing_KeyboardAction(3)", 2);
end

---
-- Deactivates the official keybindings.
--
-- @within QuestBriefing
-- @local
--
function QuestBriefing:DeactivateAllHotKeys()
	Input.KeyBindDown(Keys.F8 ,	"", 2);
	Input.KeyBindDown(Keys.Space, "",2);
	Input.KeyBindDown(Keys.Tab, "",2);
	Input.KeyBindDown(Keys.ModifierAlt + Keys.F4, "",2);

	Input.KeyBindDown(Keys.F1, "", 2);
	Input.KeyBindDown(Keys.F2, "", 2);
	Input.KeyBindDown(Keys.F3, "", 2);
	Input.KeyBindDown(Keys.F4, "", 2);
	Input.KeyBindDown(Keys.F5, "", 2);
	Input.KeyBindDown(Keys.ModifierShift + Keys.F5, "", 2);
	Input.KeyBindDown(Keys.F6, "", 2);
	Input.KeyBindDown(Keys.F7, "", 2);
	Input.KeyBindDown(Keys.ModifierShift + Keys.F4, "", 2);

	Input.KeyBindDown(Keys.F12 , "", 6);
	Input.KeyBindDown(Keys.F11 , "", 6);
	Input.KeyBindDown(Keys.ModifierControl + Keys.Add, "",6 );
	Input.KeyBindDown(Keys.ModifierControl + Keys.Subtract, "",6 );

	Input.KeyBindDown(Keys[XGUIEng.GetStringTableText( "KeyBindings/ChatToAll" )], "", 2);
	Input.KeyBindDown(Keys[XGUIEng.GetStringTableText( "KeyBindings/ChatToTeam" )], "", 2);

	Input.KeyBindDown(Keys.ModifierControl + Keys.D1, "", 2);
	Input.KeyBindDown(Keys.D1, "", 2);
	Input.KeyBindDown(Keys.ModifierControl + Keys.D2, "", 2);
	Input.KeyBindDown(Keys.D2, "", 2);
	Input.KeyBindDown(Keys.ModifierControl + Keys.D3, "", 2);
	Input.KeyBindDown(Keys.D3, "", 2);
	Input.KeyBindDown(Keys.ModifierControl + Keys.D4, "", 2);
	Input.KeyBindDown(Keys.D4, "", 2);
	Input.KeyBindDown(Keys.ModifierControl + Keys.D5, "", 2);
	Input.KeyBindDown(Keys.D5, "", 2);
	Input.KeyBindDown(Keys.ModifierControl + Keys.D6, "", 2);
	Input.KeyBindDown(Keys.D6, "", 2);
	Input.KeyBindDown(Keys.ModifierControl + Keys.D7, "", 2);
	Input.KeyBindDown(Keys.D7, "", 2);
	Input.KeyBindDown(Keys.ModifierControl + Keys.D8, "", 2);
	Input.KeyBindDown(Keys.D8, "", 2);
	Input.KeyBindDown(Keys.ModifierControl + Keys.D9, "", 2);
	Input.KeyBindDown(Keys.D9, "", 2);
	Input.KeyBindDown(Keys.ModifierControl + Keys.D0, "", 2);
	Input.KeyBindDown(Keys.D0, "", 2);

	Input.KeyBindDown(Keys.ModifierControl + Keys[XGUIEng.GetStringTableText( "KeyBindings/SelectResidence" )], 	"", 2);
	Input.KeyBindDown(Keys.ModifierControl + Keys[XGUIEng.GetStringTableText( "KeyBindings/SelectFarm" )], 			"", 2);
	Input.KeyBindDown(Keys.ModifierControl + Keys[XGUIEng.GetStringTableText( "KeyBindings/SelectVillage" )],		"", 2);
	Input.KeyBindDown(Keys.ModifierControl + Keys[XGUIEng.GetStringTableText( "KeyBindings/SelectHeadquarter" )],	"", 2);
	Input.KeyBindDown(Keys.ModifierControl + Keys[XGUIEng.GetStringTableText( "KeyBindings/SelectUniversity" )], 	"", 2);
	Input.KeyBindDown(Keys.ModifierControl + Keys[XGUIEng.GetStringTableText( "KeyBindings/SelectMarket" )], 		"", 2);
    Input.KeyBindDown(Keys.ModifierControl + Keys[XGUIEng.GetStringTableText( "KeyBindings/SelectMonastery" )], 	"", 2);
    Input.KeyBindDown(Keys.ModifierControl + Keys[XGUIEng.GetStringTableText( "KeyBindings/SelectBank" )], 			"", 2);
	Input.KeyBindDown(Keys.ModifierControl + Keys[XGUIEng.GetStringTableText( "KeyBindings/SelectBrickworks" )], 	"", 2);
	Input.KeyBindDown(Keys.ModifierControl + Keys[XGUIEng.GetStringTableText( "KeyBindings/SelectStoneMason" )], 	"", 2);
    Input.KeyBindDown(Keys.ModifierControl + Keys[XGUIEng.GetStringTableText( "KeyBindings/SelectBlacksmith" )], 	"", 2);
    Input.KeyBindDown(Keys.ModifierControl + Keys[XGUIEng.GetStringTableText( "KeyBindings/SelectAlchemist" )], 	"", 2);
    Input.KeyBindDown(Keys.ModifierControl + Keys[XGUIEng.GetStringTableText( "KeyBindings/SelectSawmill" )], 		"", 2);
    Input.KeyBindDown(Keys.ModifierControl + Keys[XGUIEng.GetStringTableText( "KeyBindings/SelectBarracks" )], 		"", 2);
    Input.KeyBindDown(Keys.ModifierControl + Keys[XGUIEng.GetStringTableText( "KeyBindings/SelectArchery" )], 		"", 2);
    Input.KeyBindDown(Keys.ModifierControl + Keys[XGUIEng.GetStringTableText( "KeyBindings/SelectFoundry" )], 		"", 2);
    Input.KeyBindDown(Keys.ModifierControl + Keys[XGUIEng.GetStringTableText( "KeyBindings/SelectStables" )], 		"", 2);
    Input.KeyBindDown(Keys.ModifierControl + Keys[XGUIEng.GetStringTableText( "KeyBindings/SelectTower" )], 		"", 2);
    Input.KeyBindDown(Keys.ModifierControl + Keys[XGUIEng.GetStringTableText( "KeyBindings/SelectWeatherTower" )], 	"", 2);
    Input.KeyBindDown(Keys.ModifierControl + Keys[XGUIEng.GetStringTableText( "KeyBindings/SelectPowerPlant" )], 	"", 2);
	Input.KeyBindDown(Keys[XGUIEng.GetStringTableText( "KeyBindings/SelectSerf" )],			                        "", 2);
	Input.KeyBindDown(Keys[XGUIEng.GetStringTableText( "KeyBindings/SelectIdleSerf" )],		                        "", 2);
	Input.KeyBindDown(Keys[XGUIEng.GetStringTableText( "KeyBindings/SelectIdleUnit" )],		                        "", 2);
	Input.KeyBindDown(Keys[XGUIEng.GetStringTableText( "KeyBindings/SelectNextHero" )],		                        "", 2);
	Input.KeyBindDown(Keys[XGUIEng.GetStringTableText( "KeyBindings/SelectPreviousHero" )],	                        "", 2);
	Input.KeyBindDown(Keys.ModifierControl + Keys.F10, "", 2);
	Input.KeyBindDown(Keys.ModifierControl + Keys.ModifierShift + Keys.F11, "", 2);
	Input.KeyBindDown(Keys.ModifierControl + Keys.ModifierShift + Keys.F12, "", 2);
	Input.KeyBindDown(Keys.ModifierControl + Keys.F12, "", 2);
	Input.KeyBindDown(Keys.ModifierControl + Keys.ModifierShift + Keys.F10, "");

    Input.KeyBindDown(Keys.ModifierControl + Keys[XGUIEng.GetStringTableText( "AOKeyBindings/SelectTavern" )], "", 2);
	Input.KeyBindDown(Keys.ModifierControl + Keys[XGUIEng.GetStringTableText( "AOKeyBindings/SelectGunsmith" )], "", 2);
	Input.KeyBindDown(Keys.ModifierControl + Keys[XGUIEng.GetStringTableText( "AOKeyBindings/SelectMasterBuilderWorkshop" )], "", 2);
end

---
-- Activates the official keybindings.
--
-- @within QuestBriefing
-- @local
--
function QuestBriefing:ReactivateAllHotKeys()
    OfficialKeyBindings_Init();
end

---
-- Overrides the multiple choice functions.
--
-- Issues:
-- <ul>
-- <li>Both MC buttons can now have a callback function</li>
-- <li>MC are no longer permamently highlighted</li>
-- </ul>
--
-- @within QuestBriefing
-- @local
--
function QuestBriefing:OverrideMultipleChoice()
    BriefingMCButtonSelected = function(_index)
        -- Buttons are dead. :(
    end

    Briefing_Extra = function(_page,_firstPage)
        -- Briefing actions with parameters
        if _page.action then
            assert( type(_page.action) == "function" );
            if type(_page.parameters) == "table" then
                _page.action(unpack(_page.parameters));
			else
                _page.action(_page.parameters);
            end
        end

        Input.CutsceneMode();
        Information:SetBriefingLooks(false);

        if _page.mc ~= nil then
			if _page.mc.text ~= nil then
				assert(_page.mc.title~=nil);
                Input.GameMode();
				PrintBriefingHeadline(_page.mc.title);
				PrintBriefingText(_page.mc.text);
                briefingBook[1][briefingState.page].mc.options.current = 1;
                QuestBriefing:SetBriefingLooks(true);
                QuestBriefing:DisplayOptionSelection();
                QuestBriefing:DeactivateAllHotKeys();

				XGUIEng.ShowWidget("CinematicMC_Container", 1);
				XGUIEng.ShowWidget("CinematicMC_Text", 1);
				XGUIEng.ShowWidget("CinematicMC_Headline", 0);
				XGUIEng.ShowWidget("CinematicBar01", 1);
                briefingState.waitingForMC = true;
				return;
			end
		end
    end
end

---
-- Switches to the previous item in the option list.
--
-- @within QuestBriefing
-- @local
--
function QuestBriefing:OnUpPressed()
    if not briefingBook[1][briefingState.page].mc then
        return;
    end
    
    assert(briefingBook[1][briefingState.page].mc.options, "Multiple choice options are missing!");
    briefingBook[1][briefingState.page].mc.options.current = briefingBook[1][briefingState.page].mc.options.current +1;
    if table.getn(briefingBook[1][briefingState.page].mc.options) < briefingBook[1][briefingState.page].mc.options.current then
        briefingBook[1][briefingState.page].mc.options.current = 1;
    end
    self:DisplayOptionSelection();
end

---
-- Switches to the next item in the option list.
--
-- @within QuestBriefing
-- @local
--
function QuestBriefing:OnDownPressed()
    if not briefingBook[1][briefingState.page].mc then
        return;
    end

    assert(briefingBook[1][briefingState.page].mc.options, "Multiple choice options are missing!");
    briefingBook[1][briefingState.page].mc.options.current = briefingBook[1][briefingState.page].mc.options.current -1;
    if 1 > briefingBook[1][briefingState.page].mc.options.current then
        briefingBook[1][briefingState.page].mc.options.current = table.getn(briefingBook[1][briefingState.page].mc.options);
    end
    self:DisplayOptionSelection();
end

---
-- Confirmas the current selected item in the multiselection.
--
-- @within QuestBriefing
-- @local
--
function QuestBriefing:OnEnterPressed()
    if not briefingBook[1][briefingState.page].mc then
        return;
    end

    assert(briefingBook[1][briefingState.page].mc.options, "Multiple choice options are missing!");
    local Current = briefingBook[1][briefingState.page].mc.options[briefingBook[1][briefingState.page].mc.options.current];
    briefingBook[1][briefingState.page].mc.selectedButton = briefingBook[1][briefingState.page].mc.options.current;
    if type(Current[2]) == "function" then
        briefingState.page = Current[2](unpack(Current));
    else
        briefingState.page = Current[2];
    end

    self:ReactivateAllHotKeys();
    XGUIEng.ShowWidget("CinematicMC_Container", 0);
    briefingState.timer = 0;
    briefingState.waitingForMC = false;
end

---
-- Sets the apperance of the cinematic mode.
--
-- @param _ShowMap [boolean] Display minimap
-- @within QuestBriefing
-- @local
--
function QuestBriefing:SetBriefingLooks(_ShowMap)
    local size = {GUI.GetScreenSize()};
    local choicePosY = (size[2]*(768/size[2]))-240;
    local titlePosY = 45;
    local textPosY = ((size[2]*(768/size[2])))-60;
    local button1SizeX = (((size[1]*(1024/size[1])))-500);
    local button2SizeX = (((size[1]*(1024/size[1])))-500);
    local titleSize = (size[1]-200);
    local bottomBarX = (size[2]*(768/size[2]))-85;
    local bottomBarY = (size[2]*(768/size[2]))-85;

    XGUIEng.SetWidgetPositionAndSize("CinematicMC_Container", 0, 0, size[1], size[2]);
    XGUIEng.SetWidgetPositionAndSize("Cinematic_Text", (200), textPosY, (680), 100);
    XGUIEng.SetWidgetPositionAndSize("CinematicMC_Text", (200), textPosY, (680), 60);
    XGUIEng.SetWidgetPositionAndSize("CinematicMC_Headline", 100, titlePosY, titleSize, 15);
    XGUIEng.SetWidgetPositionAndSize("Cinematic_Headline", 100, titlePosY, titleSize, 15);
    XGUIEng.SetWidgetPositionAndSize("CinematicBar01", 0, size[2], size[1], 185);
    XGUIEng.SetWidgetSize("CinematicBar00", size[1], 180);
    XGUIEng.ShowWidget("CinematicBar02", 0);
    XGUIEng.ShowWidget("CinematicBar01", 1);
    XGUIEng.ShowWidget("CinematicBar00", 1);

    XGUIEng.ShowWidget("CinematicMC_Button1", 0);
    XGUIEng.ShowWidget("CinematicMC_Button2", 0);

    XGUIEng.ShowWidget("CinematicMiniMapOverlay", (_ShowMap and 0) or 1);
    XGUIEng.ShowWidget("CinematicMiniMap", (_ShowMap and 0) or 1);
    XGUIEng.ShowWidget("CinematicFrameBG", (_ShowMap and 0) or 1);
    XGUIEng.ShowWidget("CinematicFrame", (_ShowMap and 0) or 1);
end

-- Countdown code --------------------------------------------------------------

---
-- Starts a visible or invisible countdown.
--
-- <b>Note:</b> There can only be one visible but infinit invisible countdonws.
--
-- @param _Limit [number] Time to count down
-- @param _Callback [function] Countdown callback
-- @param _Show [boolean] Countdown visible
--
function StartCountdown(_Limit, _Callback, _Show)
    assert(type(_Limit) == "number")
    assert( not _Callback or type(_Callback) == "function" )
    Counter.Index = (Counter.Index or 0) + 1
    if _Show and CountdownIsVisisble() then
        assert(false, "StartCountdown: A countdown is already visible")
    end
    Counter["counter" .. Counter.Index] = {Limit = _Limit, TickCount = 0, Callback = _Callback, Show = _Show, Finished = false}
    if _Show then
        MapLocal_StartCountDown(_Limit)
    end
    if Counter.JobId == nil then
        Counter.JobId = StartSimpleJob("CountdownTick")
    end
    return Counter.Index
end

---
-- Stops the countdown with the ID.
-- @param _Id [number] Countdown ID
--
function StopCountdown(_Id)
    if Counter.Index == nil then
        return
    end
    if _Id == nil then
        for i = 1, Counter.Index do
            if Counter.IsValid("counter" .. i) then
                if Counter["counter" .. i].Show then
                    MapLocal_StopCountDown()
                end
                Counter["counter" .. i] = nil
            end
        end
    else
        if Counter.IsValid("counter" .. _Id) then
            if Counter["counter" .. _Id].Show then
                MapLocal_StopCountDown()
            end
            Counter["counter" .. _Id] = nil
        end
    end
end

function CountdownTick()
    local empty = true
    for i = 1, Counter.Index do
        if Counter.IsValid("counter" .. i) then
            if Counter.Tick("counter" .. i) then
                Counter["counter" .. i].Finished = true
            end
            if Counter["counter" .. i].Finished and not IsBriefingActive() then
                if Counter["counter" .. i].Show then
                    MapLocal_StopCountDown()
                end
                if type(Counter["counter" .. i].Callback) == "function" then
                    Counter["counter" .. i].Callback()
                end
                Counter["counter" .. i] = nil
            end
            empty = false
        end
    end
    if empty then
        Counter.JobId = nil
        Counter.Index = nil
        return true
    end
end

---
-- Returns true if a countdown is visible.
-- @return [boolean] Visible countdown
--
function CountdownIsVisisble()
    for i = 1, Counter.Index do
        if Counter.IsValid("counter" .. i) and Counter["counter" .. i].Show then
            return true
        end
    end
    return false
end
