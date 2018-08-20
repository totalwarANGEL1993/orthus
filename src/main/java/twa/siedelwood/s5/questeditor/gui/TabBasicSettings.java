package twa.siedelwood.s5.questeditor.gui;

import java.awt.Color;
import java.awt.event.ActionEvent;
import java.awt.event.ActionListener;
import javax.swing.BorderFactory;
import javax.swing.JButton;
import javax.swing.JCheckBox;
import javax.swing.JComboBox;
import javax.swing.JLabel;
import javax.swing.JList;
import javax.swing.JPanel;
import javax.swing.JScrollPane;
import javax.swing.JTextField;
import javax.swing.ListSelectionModel;
import twa.siedelwood.s5.questeditor.controller.TabBasicSettingsController;

@SuppressWarnings("serial")
public class TabBasicSettings extends JPanel implements ActionListener
{
	private final int x;
	private final int y;
	private final TabBasicSettingsController controller;
	
	private JPanel diplomacyBox;
	private JComboBox[] playerDiplomacies;
	private JComboBox[] playerColors;
	private JTextField[] playerNames;
	private JLabel[] playerName;
	
	private JPanel debugBox;
	private JCheckBox[] debugOptions;
	
	private JPanel resourceBox;
	private JTextField[] resourceAmount;
	private JLabel[] resourceNames;
	
	private JPanel technologyBox;
	private JLabel forbidTechLabel;
	private JList forbidTechnologies;
	private JLabel researchedTechLabel;
	private JList researchedTechnologies;
	private JButton addForbid;
	private JButton addResearch;
	private JButton subForbid;
	private JButton subResearch;
	
	public TabBasicSettings (final int x, final int y, final TabBasicSettingsController controller) {
		this.controller = controller;
		this.x = x;
		this.y = y;
	}
	
	public JTextField[] getResourceAmount() {
		return resourceAmount;
	}
	
	public JCheckBox[] getDebugOptions() {
		return debugOptions;
	}
	
	public JTextField[] getPlayerNames() {
		return playerNames;
	}
	
	public JComboBox[] getPlayerDiplomacies() {
		return playerDiplomacies;
	}
	
	public JComboBox[] getPlayerColors() {
		return playerColors;
	}
	
	public JLabel[] getResourceNames() {
		return resourceNames;
	}
	
	public JList getForbidTechnologyList() {
		return forbidTechnologies;
	}
	
	public JList getResearchedTechnologyList() {
		return researchedTechnologies;
	}
	
	public JButton getAddForbid() {
		return addForbid;
	}
	
	public JButton getSubForbid() {
		return subForbid;
	}
	
	public JButton getAddResearch() {
		return addResearch;
	}
	
	public JButton getSubResearch() {
		return subResearch;
	}

	public void buildTab()
	{
		setLayout(null);
		setVisible(true);
		
		buildDebugGroup();
		buildDiplomacyGroup();
		buildResourceGroup();
		buildTechnologyGroup();
	}
	
	private void buildTechnologyGroup() {
		technologyBox = new JPanel(null);
		technologyBox.setBorder(BorderFactory.createTitledBorder("Technologien einstellen"));
		technologyBox.setBounds(470, 160, 330, y-195);
		technologyBox.setVisible(true);
		add(technologyBox);
		
		forbidTechLabel = new JLabel("Verbotene Technologien");
		forbidTechLabel.setBounds(10, 160, 250, 20);
		technologyBox.add(forbidTechLabel);
		
		researchedTechLabel = new JLabel("Erforschte Technologien");
		researchedTechLabel.setBounds(10, 355, 250, 20);
		technologyBox.add(researchedTechLabel);
		
		final JScrollPane scrollPaneForbid = new JScrollPane();
		forbidTechnologies = new JList<String>();
		forbidTechnologies.setBounds(10, 15, x-500, 140);
		forbidTechnologies.setSelectionMode(ListSelectionModel.SINGLE_SELECTION);
		scrollPaneForbid.setViewportView(forbidTechnologies);
		scrollPaneForbid.setBounds(10, 15, x-500, 140);
		scrollPaneForbid.setVisible(true);
		technologyBox.add(scrollPaneForbid);
		
		addForbid = new JButton("hinzufügen");
		addForbid.setBounds(10, 185, 115, 20);
		addForbid.addActionListener(this);
		technologyBox.add(addForbid);
		
		subForbid = new JButton("entfernen");
		subForbid.setBounds(130, 185, 115, 20);
		subForbid.addActionListener(this);
		technologyBox.add(subForbid);
		
		final JScrollPane scrollPaneResearched = new JScrollPane();
		researchedTechnologies = new JList<String>();
		researchedTechnologies.setBounds(10, 210, x-500, 140);
		researchedTechnologies.setSelectionMode(ListSelectionModel.SINGLE_SELECTION);
		scrollPaneResearched.setViewportView(researchedTechnologies);
		scrollPaneResearched.setBounds(10, 210, x-500, 140);
		scrollPaneResearched.setVisible(true);
		technologyBox.add(scrollPaneResearched);
		
		addResearch = new JButton("hinzufügen");
		addResearch.setBounds(10, 380, 115, 20);
		addResearch.addActionListener(this);
		technologyBox.add(addResearch);
		
		subResearch = new JButton("entfernen");
		subResearch.setBounds(130, 380, 115, 20);
		subResearch.addActionListener(this);
		technologyBox.add(subResearch);
	}
	
	private void buildResourceGroup() {
		resourceBox = new JPanel(null);
		resourceBox.setBorder(BorderFactory.createTitledBorder("Startrohstoffe festlegen"));
		resourceBox.setBounds(5, 70, x-15, 70);
		resourceBox.setVisible(true);
		add(resourceBox);
		
		resourceAmount = new JTextField[6];
		resourceNames = new JLabel[6];
		
		for (int i= 0; i<6; i++) {
			resourceNames[i] = new JLabel("Rohstoff " + (i+1));
			resourceNames[i].setBounds(10+(130*i), 15, 120, 20);
			resourceBox.add(resourceNames[i]);
			
			resourceAmount[i] = new JTextField("0");
			resourceAmount[i].setBounds(10+(130*i), 40, 120, 20);
			resourceBox.add(resourceAmount[i]);
		}
	}
	
	private void buildDebugGroup()
	{
		debugBox = new JPanel(null);
		debugBox.setBorder(BorderFactory.createTitledBorder("Testmodus"));
		debugBox.setBounds(5, 15, x-15, 45);
		debugBox.setVisible(true);
		add(debugBox);
		
		debugOptions = new JCheckBox[3];
		
		debugOptions[0] = new JCheckBox("Nutze Questverfolgung");
		debugOptions[0].setBounds(10, 15, 200, 20);
		debugBox.add(debugOptions[0]);
		
		debugOptions[1] = new JCheckBox("Nutze Debug Cheats");
		debugOptions[1].setBounds(210, 15, 180, 20);
		debugBox.add(debugOptions[1]);
		
		debugOptions[2] = new JCheckBox("Nutze Debug Shell");
		debugOptions[2].setBounds(390, 15, 200, 20);
		debugBox.add(debugOptions[2]);
	}

	private void buildDiplomacyGroup() {
		diplomacyBox = new JPanel(null);
		diplomacyBox.setBorder(BorderFactory.createTitledBorder("Diplomatieeinstellungen vornehmen"));
		diplomacyBox.setBounds(5, 160, 460, y-195);
		diplomacyBox.setVisible(true);
		add(diplomacyBox);
		
		playerDiplomacies = new JComboBox[8];
		playerColors = new JComboBox[8];
		playerNames = new JTextField[8];
		playerName = new JLabel[8];
		
		for (int i=0; i<8; i++) {
			playerName[i] = new JLabel("Spieler " + (i+1));
			playerName[i].setBounds(10, 20 + (45*i), 100, 20);
			playerName[i].setVisible(true);
			diplomacyBox.add(playerName[i]);
			
			playerNames[i] = new JTextField();
			playerNames[i].setBounds(10, 40 + (45*i), 150, 20);
			playerNames[i].setVisible(true);
			diplomacyBox.add(playerNames[i]);
			
			playerDiplomacies[i] = new JComboBox();
			playerDiplomacies[i].setBounds(165, 40 + (45*i), 100, 20);
			playerDiplomacies[i].setVisible(true);
			if (i == 0) {
				playerDiplomacies[i].setEnabled(false);
			}
			diplomacyBox.add(playerDiplomacies[i]);
			
			playerColors[i] = new JComboBox();
			playerColors[i].setBounds(270, 40 + (45*i), 180, 20);
			playerColors[i].setVisible(true);
			diplomacyBox.add(playerColors[i]);
		}
	}
	
	@Override
	public void actionPerformed(final ActionEvent ae)
	{
		controller.actionPerformed(ae);
	}
}
