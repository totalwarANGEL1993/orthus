package twa.siedelwood.s5.questeditor.gui;

import java.awt.event.ActionEvent;
import java.awt.event.ActionListener;
import javax.swing.BorderFactory;
import javax.swing.JButton;
import javax.swing.JComboBox;
import javax.swing.JLabel;
import javax.swing.JList;
import javax.swing.JPanel;
import javax.swing.JScrollPane;
import javax.swing.JTextArea;
import javax.swing.JTextField;
import javax.swing.event.ListSelectionEvent;
import javax.swing.event.ListSelectionListener;
import twa.siedelwood.s5.questeditor.controller.TabQuestAssistantController;

@SuppressWarnings("serial")
public class TabQuestAssistant extends JPanel implements ActionListener, ListSelectionListener
{
	private final int x;
	private final int y;
	private final TabQuestAssistantController controller;
	
	private JPanel questBox;
	private JList<String> questList;
	private JButton addQuest;
	private JButton subQuest;
	
	private JPanel behaviorBox;
	private JList<String> behaviorList;
	private JButton addBehavior;
	private JButton subBehavior;
	
	private JPanel settingsBox;
	private JLabel settingsTimeLabel;
	private JLabel settingsTitleLabel;
	private JTextField settingsTime;
	private JTextField settingsTitle;
	private JTextArea settingsText;
	
	private JPanel detailsBox;
	private JPanel detailsPanel;
	private JComboBox<String> settingsType;
	private JComboBox<Integer> settingsPlayer;
	
	public TabQuestAssistant (final int x, final int y, final TabQuestAssistantController controller) {
		this.controller = controller;
		this.x = x;
		this.y = y;
	}
	
	public JButton getAddQuest() {
		return addQuest;
	}
	
	public JButton getSubQuest() {
		return subQuest;
	}
	
	public JList<String> getQuestList() {
		return questList;
	}
	
	public JButton getAddBehavior() {
		return addBehavior;
	}
	
	public JButton getSubBehavior() {
		return subBehavior;
	}
	
	public JList<String> getBehaviorList() {
		return behaviorList;
	}

	public void buildTab()
	{
		setLayout(null);
		setVisible(true);
		
		buildQuestGroup();
		buildBehaviorGroup();
		buildSettingsGroup();
		//buildDetailsGroup();
	}
	
	public void buildDetailsGroup() {
		detailsBox = new JPanel(null);
		detailsBox.setBorder(BorderFactory.createTitledBorder("Behaviordetails"));
		detailsBox.setBounds(260, 218, x-525, y-258);
		detailsBox.setVisible(true);
		add(detailsBox);
		
		final JScrollPane scrollPaneDetails = new JScrollPane();
		detailsPanel = new JPanel(null);
		detailsPanel.setBounds(5, 15, x-535, y-280);
		detailsPanel.setBorder(null);
		scrollPaneDetails.setViewportView(detailsPanel);
		scrollPaneDetails.setBorder(null);
		scrollPaneDetails.setBounds(5, 15, x-535, y-280);
		scrollPaneDetails.setVisible(true);
		detailsBox.add(scrollPaneDetails);
	}
	
	public void buildSettingsGroup() {
		settingsBox = new JPanel(null);
		settingsBox.setBorder(BorderFactory.createTitledBorder("Auftragsparameter"));
		settingsBox.setBounds(260, 10, x-525, y-50);
		settingsBox.setVisible(true);
		add(settingsBox);
		
		settingsType = new JComboBox<String>();
		settingsType.addItem("MAINQUEST_OPEN");
		settingsType.addItem("SUBQUEST_OPEN");
		settingsType.setBounds(10, 25, x-600, 20);
		settingsBox.add(settingsType);
		
		settingsPlayer = new JComboBox<Integer>();
		settingsPlayer.addItem(1);
		settingsPlayer.addItem(2);
		settingsPlayer.addItem(3);
		settingsPlayer.addItem(4);
		settingsPlayer.addItem(5);
		settingsPlayer.addItem(6);
		settingsPlayer.addItem(7);
		settingsPlayer.addItem(8);
		settingsPlayer.setBounds(x-575, 25, 40, 20);
		settingsBox.add(settingsPlayer);
		
		settingsTime = new JTextField();
		settingsTime.setBounds(x-575, 70, 40, 20);
		settingsBox.add(settingsTime);
		
		settingsTimeLabel = new JLabel("Zeit");
		settingsTimeLabel.setBounds(x-575, 50, 40, 20);
		settingsBox.add(settingsTimeLabel);
		
		settingsTitle = new JTextField();
		settingsTitle.setBounds(10, 70, x-600, 20);
		settingsBox.add(settingsTitle);
		
		settingsTitleLabel = new JLabel("Auftragsbeschreibung");
		settingsTitleLabel.setBounds(10, 50, 200, 20);
		settingsBox.add(settingsTitleLabel);
		
		final JScrollPane scrollPaneDesc = new JScrollPane();
		settingsText = new JTextArea();
		settingsText.setBounds(10, 105, x-545, 90);
		scrollPaneDesc.setViewportView(settingsText);
		scrollPaneDesc.setBounds(10, 100, x-545, 95);
		scrollPaneDesc.setVisible(true);
		settingsBox.add(scrollPaneDesc);
	}
	
	public void buildBehaviorGroup() {
		behaviorBox = new JPanel(null);
		behaviorBox.setBorder(BorderFactory.createTitledBorder("Verhaltensliste"));
		behaviorBox.setBounds(x-260, 10, 250, y-50);
		behaviorBox.setVisible(true);
		add(behaviorBox);
		
		addBehavior = new JButton("+");
		addBehavior.setBounds(75, y-85, 45, 25);
		behaviorBox.add(addBehavior);
		
		subBehavior = new JButton("-");
		subBehavior.setBounds(140, y-85, 45, 25);
		behaviorBox.add(subBehavior);
		
		final JScrollPane scrollPaneForbid = new JScrollPane();
		behaviorList = new JList<String>();
		behaviorList.setBounds(10, 25, 230, y-120);
		scrollPaneForbid.setViewportView(behaviorList);
		scrollPaneForbid.setBounds(10, 25, 230, y-120);
		scrollPaneForbid.setVisible(true);
		behaviorBox.add(scrollPaneForbid);
	}
	
	public void buildQuestGroup() {
		questBox = new JPanel(null);
		questBox.setBorder(BorderFactory.createTitledBorder("Auftragsliste"));
		questBox.setBounds(5, 10, 250, y-50);
		questBox.setVisible(true);
		add(questBox);
		
		addQuest = new JButton("+");
		addQuest.setBounds(75, y-85, 45, 25);
		questBox.add(addQuest);
		
		subQuest = new JButton("-");
		subQuest.setBounds(140, y-85, 45, 25);
		questBox.add(subQuest);
		
		final JScrollPane scrollPaneForbid = new JScrollPane();
		questList = new JList<String>();
		questList.setBounds(10, 25, 230, y-120);
		scrollPaneForbid.setViewportView(questList);
		scrollPaneForbid.setBounds(10, 25, 230, y-120);
		scrollPaneForbid.setVisible(true);
		questBox.add(scrollPaneForbid);
	}
	
	@Override
	public void actionPerformed(final ActionEvent ae)
	{
		controller.tabQuestAction(ae);
	}

	@Override
	public void valueChanged(final ListSelectionEvent le) {
		controller.tabQuestAction(le);
	}
}
