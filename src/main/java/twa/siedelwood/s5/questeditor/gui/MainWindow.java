package twa.siedelwood.s5.questeditor.gui;

import java.awt.event.ActionEvent;
import java.awt.event.ActionListener;
import java.util.List;
import javax.swing.JButton;
import javax.swing.JLabel;
import javax.swing.JPanel;
import javax.swing.JTabbedPane;
import javax.swing.JTextField;
import twa.siedelwood.s5.questeditor.controller.MainWindowAction;
import twa.siedelwood.s5.questeditor.controller.MainWindowController;

@SuppressWarnings("serial")
public class MainWindow extends JPanel implements ActionListener
{
	private final int x;
	private final int y;
	private final MainWindowController interfaceController;
	private JTabbedPane tabs;
	private JButton openButton;
	private JButton saveButton;
	private JButton openMapButton;
	private JButton saveMapButton;
	private JLabel mapPathLabel;
	private JTextField mapPathField;
	
	public MainWindow(final int x, final int y, final MainWindowController interfaceController) {
		this.interfaceController = interfaceController;
		this.x = x;
		this.y = y;
	}
	
	public JButton getOpenButton()
	{
		return openButton;
	}

	public JButton getSaveButton()
	{
		return saveButton;
	}

	public JButton getOpenMapButton()
	{
		return openMapButton;
	}

	public JButton getSaveMapButton()
	{
		return saveMapButton;
	}

	public JTextField getMapPathField()
	{
		return mapPathField;
	}
	
	public JTabbedPane getTabPane()
	{
		return tabs;
	}

	public void buildWindow(final List<JPanel> tabList) {
		setBounds(0, 0, x, y);
		setLayout(null);

		tabs = new JTabbedPane();
		tabs.addTab("Anleitung", tabList.get(0));
		tabs.setEnabledAt(0, true);
		tabs.addTab("Grundeinstellungen", tabList.get(1));
		tabs.setEnabledAt(1, false);
		tabs.addTab("Quests erstellen", tabList.get(2));
		tabs.setEnabledAt(2, false);
		tabs.addTab("Briefings erstellen", new JPanel(null));
		tabs.setEnabledAt(3, false);
		tabs.setBounds(0, 0, x, y-100);
		tabs.setVisible(true);
		add(tabs);
		
		openButton = new JButton("Öffnen");
		openButton.setBounds(x-270, y-60, 120, 20);
		openButton.addActionListener(this);
		openButton.setEnabled(false);
		openButton.setVisible(true);
		add(openButton);
		
		saveButton = new JButton("Speichern");
		saveButton.setBounds(x-140, y-60, 120, 20);
		saveButton.addActionListener(this);
		saveButton.setEnabled(false);
		saveButton.setVisible(true);
		add(saveButton);
		
		openMapButton = new JButton("Map laden");
		openMapButton.setBounds(10, y-60, 120, 20);
		openMapButton.addActionListener(this);
		openMapButton.setVisible(true);
		add(openMapButton);
		
		saveMapButton = new JButton("Map packen");
		saveMapButton.setBounds(140, y-60, 120, 20);
		saveMapButton.addActionListener(this);
		saveMapButton.setEnabled(false);
		saveMapButton.setVisible(true);
		add(saveMapButton);
		
		mapPathLabel = new JLabel("Geladene Map:");
		mapPathLabel.setBounds(5, y-100, x-50, 15);
		mapPathLabel.setVisible(true);
		add(mapPathLabel);
		
		mapPathField = new JTextField();
		mapPathField.setBounds(5, y-85, x-15, 20);
		mapPathField.setEditable(false);
		mapPathField.setVisible(true);
		add(mapPathField);
		
		setVisible(true);
	}

	@Override
	public void actionPerformed(final ActionEvent e)
	{
		if (e.getSource() == openButton) {
			interfaceController.mainWindowAction(e, MainWindowAction.OPEN_MISSION);
		}
		if (e.getSource() == saveButton) {
			interfaceController.mainWindowAction(e, MainWindowAction.SAVE_MISSION);
		}
		if (e.getSource() == openMapButton) {
			interfaceController.mainWindowAction(e, MainWindowAction.OPEN_MAP);
		}
		if (e.getSource() == saveMapButton) {
			interfaceController.mainWindowAction(e, MainWindowAction.SAVE_MAP);
		}
	}
}
