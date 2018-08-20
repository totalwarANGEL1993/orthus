
package twa.siedelwood.s5.questeditor.controller;

import java.awt.Window;
import java.awt.event.ActionEvent;
import java.io.File;
import java.io.FileReader;
import java.io.FileWriter;
import java.io.Reader;
import java.io.Writer;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.List;
import java.util.Vector;

import javax.swing.JCheckBox;
import javax.swing.JFrame;
import org.json.simple.JSONArray;
import org.json.simple.JSONObject;
import org.json.simple.parser.JSONParser;
import lombok.Setter;
import twa.siedelwood.s5.questeditor.gui.SelectTechnologyDialog;
import twa.siedelwood.s5.questeditor.gui.TabBasicSettings;

@Setter
public class TabBasicSettingsController
{
	private String currentMapPath;
	private String currentSettingsPath;
	private TabBasicSettings basicSettings;
	private JSONArray missionData;
	private Vector<String> technologyList;
	private Vector<String> techsForbidData;
	private Vector<String> techsResearchData;

	public TabBasicSettingsController()
	{
		technologyList = new Vector<>();
		currentSettingsPath = "cnf";
	}

	public void load() throws InterfaceControllerException
	{
		try
		{
			final JSONParser parser = new JSONParser();
			final Reader in = new FileReader(new File(currentSettingsPath + "/baseWindow.json"));
			missionData = (JSONArray) parser.parse(in);
			loadComponents();
			loadSettings();
		}
		catch (final Exception e)
		{
			throw new InterfaceControllerException(e);
		}
	}

	public void save() throws InterfaceControllerException
	{
		try
		{
			final Writer out = new FileWriter(new File(currentSettingsPath + "/baseWindow.json"));
			saveSettings();
			missionData.writeJSONString(out);
			out.flush();
			out.close();
		}
		catch (final Exception e)
		{
			throw new InterfaceControllerException(e);
		}
	}

	@SuppressWarnings("unchecked")
	private void loadComponents()
	{
		int i;

		final JSONArray diploStates = (JSONArray) ((JSONObject) missionData.get(0)).get("DiplomacyStates");
		for (i = 0; i < 8; i++)
		{
			basicSettings.getPlayerDiplomacies()[i].addItem(diploStates.get(0));
			basicSettings.getPlayerDiplomacies()[i].addItem(diploStates.get(1));
			basicSettings.getPlayerDiplomacies()[i].addItem(diploStates.get(2));
		}

		final JSONArray playerColors = (JSONArray) ((JSONObject) missionData.get(0)).get("PlayerColors");
		for (i = 0; i < 8; i++)
		{
			for (final Object k : playerColors)
			{
				basicSettings.getPlayerColors()[i].addItem(k);
			}
		}

		final JSONArray resources = (JSONArray) ((JSONObject) missionData.get(0)).get("Resources");
		for (i = 0; i < 6; i++)
		{
			basicSettings.getResourceNames()[i].setText((String) resources.get(i));
		}

		final JSONArray technologies = (JSONArray) ((JSONObject) missionData.get(0)).get("Technologies");
		for (i = 0; i < technologies.size(); i++)
		{
			technologyList.add((String) technologies.get(i));
		}
	}
	
	@SuppressWarnings("unchecked")
	private void saveSettings() {
		int i;
		JCheckBox[] dbg = basicSettings.getDebugOptions();
		List<Long> res = new ArrayList<>();
		for (i=0; i<6; i++) res.add(Long.parseLong(basicSettings.getResourceAmount()[i].getText()));
		List<String> names = new ArrayList<>();
		for (i=0; i<8; i++) names.add(basicSettings.getPlayerNames()[i].getText());
		List<Long> diplo = new ArrayList<>();
		for (i=0; i<8; i++) diplo.add(new Long(basicSettings.getPlayerDiplomacies()[i].getSelectedIndex()));
		List<Long> color = new ArrayList<>();
		for (i=0; i<8; i++) color.add(new Long(basicSettings.getPlayerColors()[i].getSelectedIndex()));
		
		((JSONObject) missionData.get(0)).remove("Technologies");
		((JSONObject) missionData.get(0)).put("Technologies", technologyList);
		
		((JSONObject) missionData.get(1)).remove("StartResources");
		((JSONObject) missionData.get(1)).put("StartResources", res);
		
		((JSONObject) missionData.get(1)).remove("PlayerNames");
		((JSONObject) missionData.get(1)).put("PlayerNames", names);
		
		((JSONObject) missionData.get(1)).remove("PlayerDiplomacies");
		((JSONObject) missionData.get(1)).put("PlayerDiplomacies", diplo);
		
		((JSONObject) missionData.get(1)).remove("PlayerColors");
		((JSONObject) missionData.get(1)).put("PlayerColors", color);
		
		((JSONObject) missionData.get(1)).remove("DebugMode");
		((JSONObject) missionData.get(1)).put("DebugMode", Arrays.asList(dbg[0].isSelected(), dbg[1].isSelected(), dbg[2].isSelected()));
		
		((JSONObject) missionData.get(1)).remove("ForbidTechnologies");
		((JSONObject) missionData.get(1)).put("ForbidTechnologies", techsForbidData);
		
		((JSONObject) missionData.get(1)).remove("ResearchedTechnologies");
		((JSONObject) missionData.get(1)).put("ResearchedTechnologies", techsResearchData);
	}

	@SuppressWarnings("unchecked")
	private void loadSettings()
	{
		int i;

		final JSONArray debug = (JSONArray) ((JSONObject) missionData.get(1)).get("DebugMode");
		for (i = 0; i < 3; i++)
		{
			basicSettings.getDebugOptions()[i].setSelected((boolean) debug.get(i));
		}

		final JSONArray resources = (JSONArray) ((JSONObject) missionData.get(1)).get("StartResources");
		for (i = 0; i < 6; i++)
		{
			basicSettings.getResourceAmount()[i].setText(((Long) resources.get(i)).toString());
		}

		final JSONArray playerNames = (JSONArray) ((JSONObject) missionData.get(1)).get("PlayerNames");
		for (i = 0; i < 8; i++)
		{
			basicSettings.getPlayerNames()[i].setText((String) playerNames.get(i));
		}
		
		final JSONArray playerDiplomacies = (JSONArray) ((JSONObject) missionData.get(1)).get("PlayerDiplomacies");
		for (i = 0; i < 8; i++)
		{
			basicSettings.getPlayerDiplomacies()[i].setSelectedIndex(((Long) playerDiplomacies.get(i)).intValue());
		}
		
		final JSONArray playerColors = (JSONArray) ((JSONObject) missionData.get(1)).get("PlayerColors");
		for (i = 0; i < 8; i++)
		{
			basicSettings.getPlayerColors()[i].setSelectedIndex(((Long) playerColors.get(i)).intValue());
		}

		final JSONArray forbidTechnologies = (JSONArray) ((JSONObject) missionData.get(1)).get("ForbidTechnologies");
		techsForbidData = new Vector<>();
		for (i = 0; i < forbidTechnologies.size(); i++)
		{
			techsForbidData.add((String) forbidTechnologies.get(i));
		}
		basicSettings.getForbidTechnologyList().setListData(techsForbidData);

		final JSONArray researchTechnologies = (JSONArray) ((JSONObject) missionData.get(1)).get("ResearchedTechnologies");
		techsResearchData = new Vector<>();
		for (i = 0; i < researchTechnologies.size(); i++)
		{
			techsResearchData.add((String) researchTechnologies.get(i));
		}
		basicSettings.getResearchedTechnologyList().setListData(techsResearchData);
	}

	@SuppressWarnings("unchecked")
	public void actionPerformed(final ActionEvent ae)
	{
		if (ae.getSource() == basicSettings.getAddForbid()) {
			final Window activeWindow = javax.swing.FocusManager.getCurrentManager().getActiveWindow();
			final SelectTechnologyDialog techDialog = new SelectTechnologyDialog((JFrame) activeWindow, "Technologie auswählen", true, technologyList);
			
			final int selectedIndex = techDialog.getSelected();
			if (selectedIndex > -1) {
				final String selectedTech = technologyList.get(selectedIndex);
				technologyList.remove(selectedIndex);
				techsForbidData.add(selectedTech);
				basicSettings.getForbidTechnologyList().setListData(techsForbidData);
			}
		}
		
		if (ae.getSource() == basicSettings.getSubForbid()) {
			final int selectedIndex = basicSettings.getForbidTechnologyList().getSelectedIndex();
			if (selectedIndex > -1) {
				final String selectedTech = techsForbidData.get(selectedIndex);
				techsForbidData.remove(selectedIndex);
				basicSettings.getForbidTechnologyList().setListData(techsForbidData);
				technologyList.add(selectedTech);
			}
		}
		
		if (ae.getSource() == basicSettings.getAddResearch()) {
			final Window activeWindow = javax.swing.FocusManager.getCurrentManager().getActiveWindow();
			final SelectTechnologyDialog techDialog = new SelectTechnologyDialog((JFrame) activeWindow, "Technologie auswählen", true, technologyList);
			
			final int selectedIndex = techDialog.getSelected();
			if (selectedIndex > -1) {
				final String selectedTech = technologyList.get(selectedIndex);
				technologyList.remove(selectedIndex);
				techsResearchData.add(selectedTech);
				basicSettings.getResearchedTechnologyList().setListData(techsResearchData);
			}
		}
		
		if (ae.getSource() == basicSettings.getSubResearch()) {
			final int selectedIndex = basicSettings.getResearchedTechnologyList().getSelectedIndex();
			if (selectedIndex > -1) {
				final String selectedTech = techsResearchData.get(selectedIndex);
				techsResearchData.remove(selectedIndex);
				basicSettings.getResearchedTechnologyList().setListData(techsResearchData);
				technologyList.add(selectedTech);
			}
		}
	}
}
