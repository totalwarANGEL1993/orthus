-- ########################################################################## --
-- #  Workspace Controlls                                                   # --
-- #  --------------------------------------------------------------------  # --
-- #    Author:   totalwarANGEL                                             # --
-- ########################################################################## --

---
-- A passive module that allows the player to change the amout of worker 
-- in the building.
--
-- This way it is not needed to tear down the city to make space for soldiers
-- in the village centers. After the fight the soldiers can be expelld and
-- new workers be recruited.
--
-- <b>Required modules:</b>
-- <ul>
-- <li>qsb.oop</li>
-- <li>qsb.mpsync</li>
-- </ul>
--
-- @set sort=true
--

QuestSystem.Workplace = {
    m_Data = {
        WorkplaceStates = {},
        UseMod = true,
    },
};

---
-- Installs the mod.
-- @within QuestSystem.Workplace
-- @local
--
function QuestSystem.Workplace:Install()
    self:OverrideInterfaceAction();
    self:OverrideInterfaceTooltip();
    self:OverrideInterfaceUpdate();
end

---
-- Enables or disables the mod.
--
-- @param[type=boolean] _Flag Mod is enabled
-- @within QuestSystem.Workplace
-- @local
--
function QuestSystem.Workplace:EnableMod(_Flag)
    self.m_Data.UseMod = _Flag == true;
end

---
-- Overrides the interface actions.
-- @within QuestSystem.Workplace
-- @local
--
function QuestSystem.Workplace:OverrideInterfaceAction()
    GUIAction_SetAmountOfWorkers_Orig_WorkplaceMod = GUIAction_SetAmountOfWorkers
    GUIAction_SetAmountOfWorkers = function(_state)
		if _state == "few" then
			local sel = GUI.GetSelectedEntity();
			local worker = {Logic.GetAttachedWorkersToBuilding(sel)};
			local eName = GiveEntityName(sel);
			XGUIEng.HighLightButton("SetWorkersAmountFew",1);
			XGUIEng.HighLightButton("SetWorkersAmountHalf",0);
            XGUIEng.HighLightButton("SetWorkersAmountFull",0);
            
			QuestSystem.Workplace.m_Data.WorkplaceStates[eName] = _state;
			for j=1,table.getn(worker)do
				Logic.SetTaskList(worker[j],TaskLists.TL_WORKER_EAT_START);
			end
            GUIAction_SetAmountOfWorkers_Orig_WorkplaceMod(_state);
            
		elseif _state == "half" then
			local sel = GUI.GetSelectedEntity();
			local worker = {Logic.GetAttachedWorkersToBuilding(sel)};
			local eName = GiveEntityName(sel);
			XGUIEng.HighLightButton("SetWorkersAmountFew",0);
			XGUIEng.HighLightButton("SetWorkersAmountHalf",1);
            XGUIEng.HighLightButton("SetWorkersAmountFull",0);
            
			QuestSystem.Workplace.m_Data.WorkplaceStates[eName] = _state;
			for j=1,math.ceil(table.getn(worker)/2)do
				Logic.SetTaskList(worker[j],TaskLists.TL_WORKER_EAT_START);
			end
            GUIAction_SetAmountOfWorkers_Orig_WorkplaceMod(_state);
            
		elseif _state == "full" then
			local sel = GUI.GetSelectedEntity();
			local worker = {Logic.GetAttachedWorkersToBuilding(sel)};
			local eName = GiveEntityName(sel);
			XGUIEng.HighLightButton("SetWorkersAmountFew",0);
			XGUIEng.HighLightButton("SetWorkersAmountHalf",0);
			XGUIEng.HighLightButton("SetWorkersAmountFull",1);
			
			QuestSystem.Workplace.m_Data.WorkplaceStates[eName] = _state;
			GUIAction_SetAmountOfWorkers_Orig_WorkplaceMod(_state);
		end
	end
end

---
-- Overrides the interface tooptip methods.
-- @within QuestSystem.Workplace
-- @local
--
function QuestSystem.Workplace:OverrideInterfaceTooltip()
    GUITooltip_NormalButton_Orig_WorkplaceMod = GUITooltip_NormalButton
	GUITooltip_NormalButton = function(a)
		GUITooltip_NormalButton_Orig_WorkplaceMod(a);
        local lang = (XNetworkUbiCom.Tool_GetCurrentLanguageShortName() == "de" and "de") or "en";

		if a == "MenuBuildingGeneric/setworkerfew" then
			if not(QuestSystem.Workplace.m_Data.UseMod == true) then
				XGUIEng.SetText(gvGUI_WidgetID.TooltipBottomText, QuestSystem.Workplace.Text.Literacy.Forbidden);
			else
				if Logic.IsTechnologyResearched( 1, Technologies.GT_Literacy )== 0 then
					XGUIEng.SetText(gvGUI_WidgetID.TooltipBottomText, QuestSystem.Workplace.Text.SettingDisabled[lang]);
				else
					XGUIEng.SetText(gvGUI_WidgetID.TooltipBottomText, QuestSystem.Workplace.Text.SettingFew[lang]);
				end
			end
			XGUIEng.SetText(gvGUI_WidgetID.TooltipBottomCosts, "");
            XGUIEng.SetText(gvGUI_WidgetID.TooltipBottomShortCut, "");
            
		elseif a == "MenuBuildingGeneric/setworkerhalf" then
			if not(QuestSystem.Workplace.m_Data.UseMod == true) then
				XGUIEng.SetText(gvGUI_WidgetID.TooltipBottomText, QuestSystem.Workplace.Text.Literacy.Forbidden);
			else
				if Logic.IsTechnologyResearched( 1, Technologies.GT_Literacy )== 0 then
					XGUIEng.SetText(gvGUI_WidgetID.TooltipBottomText, QuestSystem.Workplace.Text.SettingDisabled[lang]);
				else
					XGUIEng.SetText(gvGUI_WidgetID.TooltipBottomText, QuestSystem.Workplace.Text.SettingHalf[lang]);
				end
			end
			XGUIEng.SetText(gvGUI_WidgetID.TooltipBottomCosts, "");
            XGUIEng.SetText(gvGUI_WidgetID.TooltipBottomShortCut, "");
            
		elseif a == "MenuBuildingGeneric/setworkerfull" then
			if not(QuestSystem.Workplace.m_Data.UseMod == true) then
				XGUIEng.SetText(gvGUI_WidgetID.TooltipBottomText, QuestSystem.Workplace.Text.Literacy.Forbidden);
			else
				if Logic.IsTechnologyResearched( 1, Technologies.GT_Literacy )== 0 then
					XGUIEng.SetText(gvGUI_WidgetID.TooltipBottomText, QuestSystem.Workplace.Text.SettingDisabled[lang]);
				else
					XGUIEng.SetText(gvGUI_WidgetID.TooltipBottomText, QuestSystem.Workplace.Text.SettingFull[lang]);
				end
			end
			XGUIEng.SetText(gvGUI_WidgetID.TooltipBottomCosts, "");
			XGUIEng.SetText(gvGUI_WidgetID.TooltipBottomShortCut, "");
		end
    end
    
    GUITooltip_ResearchTechnologies_Orig_WorkplaceMod = GUITooltip_ResearchTechnologies
	GUITooltip_ResearchTechnologies = function(a,b,c,d)
		GUITooltip_ResearchTechnologies_Orig_WorkplaceMod(a,b,c,d);
		local lang = (XNetworkUbiCom.Tool_GetCurrentLanguageShortName() == "de" and "de") or "en";

		if a == Technologies.GT_Literacy then
			if Logic.GetTechnologyState(1,a) == 0 then
				XGUIEng.SetText( gvGUI_WidgetID.TooltipBottomText, QuestSystem.Workplace.Text.Literacy.Forbidden[lang]);
			else
				if Logic.IsTechnologyResearched(1,a) == 0 then
					XGUIEng.SetText( gvGUI_WidgetID.TooltipBottomText, QuestSystem.Workplace.Text.Literacy.Unreseached[lang]);
				else
					XGUIEng.SetText( gvGUI_WidgetID.TooltipBottomText, QuestSystem.Workplace.Text.Literacy.Reseached[lang]);
				end
			end
		end
	end
end

---
-- Overrides the interface update methods.
-- @within QuestSystem.Workplace
-- @local
--
function QuestSystem.Workplace:OverrideInterfaceUpdate()
    GUIUpdate_FindView_Orig_WorkplaceMod = GUIUpdate_FindView
	GUIUpdate_FindView = function()
		GUIUpdate_FindView_Orig_WorkplaceMod();
		local size = {GUI.GetScreenSize()};
		local sel = GUI.GetSelectedEntity();
		local pID = GUI.GetPlayerID();

		XGUIEng.SetWidgetPositionAndSize(XGUIEng.GetWidgetID("Details_Generic"),452,70,100,90);
		XGUIEng.SetWidgetPositionAndSize(XGUIEng.GetWidgetID("DetailsArmor"),4,30,70,15);
		XGUIEng.SetWidgetPositionAndSize(XGUIEng.GetWidgetID("DetailsDamage"),4,45,72,15);
		XGUIEng.SetWidgetPositionAndSize(XGUIEng.GetWidgetID("DetailsExperience"),4,64,80,20);
		XGUIEng.SetWidgetPositionAndSize(XGUIEng.GetWidgetID("DetailsGroupStrength"),7,82,80,10);
		XGUIEng.SetWidgetPositionAndSize(XGUIEng.GetWidgetID("DetailsGroupStrength_Soldier01"),0,0,13,13);
		XGUIEng.SetWidgetPositionAndSize(XGUIEng.GetWidgetID("DetailsGroupStrength_Soldier02"),9,0,13,13);
		XGUIEng.SetWidgetPositionAndSize(XGUIEng.GetWidgetID("DetailsGroupStrength_Soldier03"),18,0,13,13);
		XGUIEng.SetWidgetPositionAndSize(XGUIEng.GetWidgetID("DetailsGroupStrength_Soldier04"),27,0,13,13);
		XGUIEng.SetWidgetPositionAndSize(XGUIEng.GetWidgetID("DetailsGroupStrength_Soldier05"),36,0,13,13);
		XGUIEng.SetWidgetPositionAndSize(XGUIEng.GetWidgetID("DetailsGroupStrength_Soldier06"),45,0,13,13);
		XGUIEng.SetWidgetPositionAndSize(XGUIEng.GetWidgetID("DetailsGroupStrength_Soldier07"),54,0,13,13);
		XGUIEng.SetWidgetPositionAndSize(XGUIEng.GetWidgetID("DetailsGroupStrength_Soldier08"),63,0,13,13);
		XGUIEng.SetWidgetPositionAndSize(XGUIEng.GetWidgetID("Details_Workers"),455,135,100,55);
		XGUIEng.SetWidgetPosition(XGUIEng.GetWidgetID("Thief_StolenRessourceAmount"),470,82);
		XGUIEng.SetWidgetPosition(XGUIEng.GetWidgetID("Thief_StolenRessourceType"),455,64);
		XGUIEng.SetWidgetPosition(XGUIEng.GetWidgetID("DetailsHealth"),11,5);

		if Logic.IsEntityInCategory( sel, EntityCategories.Workplace )== 1
		and Logic.GetEntityType(sel) ~= Entities.PB_Market1
		and Logic.IsConstructionComplete(sel)== 1 then
			XGUIEng.SetWidgetPosition("SetWorkersAmountFew",4,25);
			XGUIEng.SetWidgetPosition("SetWorkersAmountHalf",30,25);
			XGUIEng.SetWidgetPosition("SetWorkersAmountFull",54,25);
			XGUIEng.SetWidgetPosition("WorkersAmountFew",2,45);
			XGUIEng.SetWidgetPosition("WorkersAmountHalf",28,45);
			XGUIEng.SetWidgetPosition("WorkersAmountFull",52,45);
			XGUIEng.SetWidgetPosition("WorkersIcon",27,0);
			XGUIEng.ShowWidget("Details_Workers",1);
			XGUIEng.ShowWidget("WorkersAmountFew",1);
			XGUIEng.ShowWidget("WorkersAmountHalf",1);
			XGUIEng.ShowWidget("WorkersAmountFull",1);
			XGUIEng.ShowWidget("SetWorkersAmountFew",1);
			XGUIEng.ShowWidget("SetWorkersAmountHalf",1);
			XGUIEng.ShowWidget("SetWorkersAmountFull",1);
			XGUIEng.ShowWidget("WorkersIcon",1);
			if Logic.IsTechnologyResearched( 1, Technologies.GT_Literacy )== 1
			and QuestSystem.Workplace.m_Data.UseMod == true then
				XGUIEng.DisableButton("SetWorkersAmountFew",0);
				XGUIEng.DisableButton("SetWorkersAmountHalf",0);
				XGUIEng.DisableButton("SetWorkersAmountFull",0);
			else
				XGUIEng.DisableButton("SetWorkersAmountFew",1);
				XGUIEng.DisableButton("SetWorkersAmountHalf",1);
				XGUIEng.DisableButton("SetWorkersAmountFull",1);
			end
		else
			XGUIEng.ShowWidget("Details_Workers",0);
		end
		QuestSystem.Workplace:UpdateDisplay();
	end

	GameCallback_OnBuildingUpgradeComplete_Orig_WorkplaceMod = GameCallback_OnBuildingUpgradeComplete
	GameCallback_OnBuildingUpgradeComplete = function(a,b)
		GameCallback_OnBuildingUpgradeComplete_Orig_WorkplaceMod(a,b);
		local eName = GiveEntityName(b);
		if QuestSystem.Workplace.m_Data.WorkplaceStates[eName] then
			local backupSel = {GUI.GetSelectedEntities()};
			GUI.ClearSelection();

			GUI.SelectEntity(b);
			GUIAction_SetAmountOfWorkers(QuestSystem.Workplace.m_Data.WorkplaceStates[eName]);
			GUI.DeselectEntity(b);

			if table.getn(backupSel) > 0 then
				for i=1,table.getn(backupSel)do
					if IsExisting(backupSel[i])then
						GUI.SelectEntity(backupSel[i]);
					end
				end
			end
		end
	end
end

---
-- Updates the workplace menu for the selected entity.
-- @within QuestSystem.Workplace
-- @local
--
function QuestSystem.Workplace:UpdateDisplay()
	local sel = GUI.GetSelectedEntity();
	if sel then
		local inTable = false;
		for k,v in pairs(self.m_Data.WorkplaceStates)do
			local eName = GiveEntityName(sel);
			if eName == tostring(k) then
				inTable = true;
				if IsExisting(eName)then
					if self.m_Data.WorkplaceStates[k] == "few" then
						XGUIEng.HighLightButton("SetWorkersAmountFew",1);
						XGUIEng.HighLightButton("SetWorkersAmountHalf",0);
                        XGUIEng.HighLightButton("SetWorkersAmountFull",0);
                        
                    elseif self.m_Data.WorkplaceStates[k] == "half" then
						XGUIEng.HighLightButton("SetWorkersAmountFew",0);
						XGUIEng.HighLightButton("SetWorkersAmountHalf",1);
                        XGUIEng.HighLightButton("SetWorkersAmountFull",0);
                        
					elseif self.m_Data.WorkplaceStates[k] == "full" then
						XGUIEng.HighLightButton("SetWorkersAmountFew",0);
						XGUIEng.HighLightButton("SetWorkersAmountHalf",0);
						XGUIEng.HighLightButton("SetWorkersAmountFull",1);
					end
				else
					self.m_Data.WorkplaceStates[k] = nil;
				end
			end
		end
		if not inTable then
			XGUIEng.HighLightButton("SetWorkersAmountFew",0);
			XGUIEng.HighLightButton("SetWorkersAmountHalf",0);
			XGUIEng.HighLightButton("SetWorkersAmountFull",1);
		end
	end
end

QuestSystem.Workplace.Text = {
    SettingFew = {
        de = " @color:180,180,180 Betrieb stilllegen @cr @color:255,255,255  Die Arbeit im Betrieb wird stillgelegt. Alle Arbeiter verlassen"..
             " die Siedlung, wenn sie keinen neuen Arbeitsplatz finden.",
        en = " @color:180,180,180 Stop work @cr @color:255,255,255  The production of the workplace is shut down. All workers will leave the"..
             " settlement if they can not find a new job.",
    },
    SettingHalf = {
        de = " @color:180,180,180 Halbe Belegschaft @cr @color:255,255,255  Die Belegschaft des Betriebs wird halbiert. Die überzähligen Arbeiter"..
             " verlassen die Siedlung, wenn sie keinen neuen Arbeitsplatz finden.",
        en = " @color:180,180,180 Half utilization @cr @color:255,255,255  The amount of workers is halved. The surplus workers leave the settlement"..
             " if they can not find a new job.",
    },
    SettingFull = {
        de = " @color:180,180,180 Volle Auslastung @cr @color:255,255,255  Alle möglichen Stellen im Betrieb werden mit Arbeitern beseitzt,"..
             " sofern not Platz für sie vorhanden ist.",
        en = " @color:180,180,180 Full utilization @cr @color:255,255,255  All possible workplaces will be manned with workers if there is"..
             " enough space in the village center.",
    },
    SettingDisabled = {
        de = " @color:244,184,0 benötigt: @color:255,255,255 Bildung @cr @color:244,184,0 ermöglicht: @color:255,255,255 Einstellen der"..
             " Arbeitermenge im Gebäude",
        en = " @color:244,184,0 requires: @color:255,255,255 Literacy @cr @color:244,184,0 allows: @color:255,255,255 Adjusting of workers"..
             " amount in the building",
    },
    SettingForbidden = {
        de = " @color:244,184,0 benötigt: @color:255,255,255 Bildung @cr @color:244,184,0 ermöglicht: @color:255,255,255 Einstellen der"..
             " Arbeitermenge im Gebäude",
        en = " @color:244,184,0 requires: @color:255,255,255 Literacy @cr @color:244,184,0 allows: @color:255,255,255 Adjusting of workers"..
             " amount in the building",
    },

    Literacy = {
        Unreseached = {
            de = "Bildung @cr @color:244,184,0 ermöglicht: @color:255,255,255 Kapelle, Lager, Astrolabium, Ausbau von Dorfzentren, Einstellen"..
                 " der Steuern und der Arbeitermenge in Werkstätten",
            en = "Literacy @cr @color:244,184,0 allows: @color:255,255,255 Chapel, Storehouse, Astrolabe, upgrade of Village Centers, adjusting"..
                 " of taxes and amount of worker in buildings",
        },
        Reseached = {
            de = "Bildung @cr @color:255,255,255 Nun könnt Ihr eine Kapelle und ein Lager bauen, Eure Dorfzentren ausbauen, die Höhe der Steuern"..
                 " einstellen und die Anzahl der Arbeiter in Euren Werkstätten ändern.",
            en = "Literacy @cr @color:255,255,255 Now you able to build a chapel and a storehouse. You can upgrade your village centers and adjust"..
                 " the tax high and the amount of worker in a building.",
        },
        Forbidden = {
            de = " @color:180,180,180 Nicht verfügbar @cr @color:255,255,255 Diese Technologie ist in dieser Mission noch nicht verfügbar.",
            en = " @color:180,180,180 Unavailable @cr @color:255,255,255 The technology is not yet available in this mission.",
        }
    }
};

-- Callbacks ---------------------------------------------------------------- --

GameCallback_OnQuestSystemLoaded_Orig_Workplace = GameCallback_OnQuestSystemLoaded;
GameCallback_OnQuestSystemLoaded = function()
    GameCallback_OnQuestSystemLoaded_Orig_Workplace();
    QuestSystem.Workplace:Install();
end

