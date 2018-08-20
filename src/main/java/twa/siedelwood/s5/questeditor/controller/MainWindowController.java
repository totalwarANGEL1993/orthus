package twa.siedelwood.s5.questeditor.controller;

import java.awt.event.ActionEvent;
import java.io.File;
import java.io.InputStream;
import java.util.Arrays;
import javax.swing.JFileChooser;
import javax.swing.JFrame;
import javax.swing.SwingUtilities;
import javax.swing.filechooser.FileNameExtensionFilter;
import twa.siedelwood.s5.questeditor.extern.MapFileManager;
import twa.siedelwood.s5.questeditor.gui.MainWindow;
import twa.siedelwood.s5.questeditor.gui.TabBasicSettings;
import twa.siedelwood.s5.questeditor.gui.TabQuestAssistant;
import twa.siedelwood.s5.questeditor.gui.TabUserManual;

public class MainWindowController
{
	private final boolean debug;
	private final MainWindowController self;
	private final TabBasicSettingsController basicTabController;
	private final TabQuestAssistantController questTabController;
	
	private MainWindow mainWindow;
	private TabBasicSettings basicSettings;
	private TabQuestAssistant questAssistant;
	private String currentMapPath;
	private String currentSettingsPath;
	private TabUserManual manualTab;
	
	public MainWindowController(final boolean debug) {
		this.debug = debug;
		currentSettingsPath = "cnf";
		basicTabController = new TabBasicSettingsController();
		questTabController = new TabQuestAssistantController();
		self = this;
	}
	
	public boolean isDebugMode() {
		return debug;
	}
	
	public void run() {
		SwingUtilities.invokeLater(() -> {
			final int x = 810;
			final int y = 700;
			
			manualTab = new TabUserManual(x, y-95);
			manualTab.buildTab();
			
			basicSettings = new TabBasicSettings(x, y-95, basicTabController);
			basicSettings.buildTab();
			basicTabController.setBasicSettings(basicSettings);
			
			questAssistant = new TabQuestAssistant(x, y-95, questTabController);
			questAssistant.buildTab();
			questTabController.setBasicSettings(basicSettings);
			
			mainWindow = new MainWindow(x, y, self);
			mainWindow.buildWindow(Arrays.asList(
					manualTab, basicSettings, questAssistant
			));
			mainWindow.setVisible(true);
			
			final JFrame frame = new JFrame();
			frame.setDefaultCloseOperation(JFrame.EXIT_ON_CLOSE);
			frame.setTitle("Siedler 5 Skriptassistent");
			frame.setSize(x, y);
			frame.setLocationRelativeTo(null);
			frame.setResizable(false);
			frame.add(mainWindow);
			frame.setVisible(true);
		});
	}
	
	private void saveData() throws InterfaceControllerException {
		try
		{
			final JFileChooser fc = new JFileChooser();
			fc.setFileSelectionMode(JFileChooser.DIRECTORIES_ONLY);
			final int returnVal = fc.showOpenDialog(null);
			if (returnVal == JFileChooser.APPROVE_OPTION) {
				final File file = fc.getSelectedFile();

				currentSettingsPath = file.getAbsolutePath();
				basicTabController.setCurrentSettingsPath(currentSettingsPath);
				basicTabController.save();
			}
		}
		catch (final Exception e)
		{
			throw new InterfaceControllerException(e);
		}
	}
	
	private void loadData() throws InterfaceControllerException {
		try
		{
			final JFileChooser fc = new JFileChooser();
			fc.setFileSelectionMode(JFileChooser.DIRECTORIES_ONLY);
			final int returnVal = fc.showOpenDialog(null);
			if (returnVal == JFileChooser.APPROVE_OPTION) {
				final File file = fc.getSelectedFile();
				
				currentSettingsPath = file.getAbsolutePath();
				basicTabController.setCurrentSettingsPath(currentSettingsPath);
				basicTabController.load();
			}
		}
		catch (final Exception e)
		{
			throw new InterfaceControllerException(e);
		}
	}
	
	private void saveMap() throws InterfaceControllerException {
		try
		{
			final MapFileManager mfm = new MapFileManager();
			
			String resHome = "/resources/";
			if (isDebugMode()) {
				resHome = "/";
			}
			final InputStream qsb = MainWindowController.class.getResourceAsStream(resHome + "lua/qsb.lua");
			
			// TODO Create and move script files!
			
			mfm.setMapPath(currentMapPath + ".unpacked");
			mfm.add(qsb, "maps/externalmap/qsb.lua");
			mfm.packMap();
		}
		catch (final Exception e)
		{
			throw new InterfaceControllerException(e);
		}
	}
	
	private void openMap() throws InterfaceControllerException {
		try
		{
			final MapFileManager mfm = new MapFileManager();
			
			final JFileChooser fc = new JFileChooser();
			fc.setAcceptAllFileFilterUsed(false);
			fc.addChoosableFileFilter(new FileNameExtensionFilter("Kartenarchiv", "s5x"));
			final int returnVal = fc.showOpenDialog(null);
			if (returnVal == JFileChooser.APPROVE_OPTION) {
				final File file = fc.getSelectedFile();
				currentMapPath = file.getAbsolutePath();
				mfm.setMapPath(currentMapPath);
				if (mfm.unpackMap()) {
					mainWindow.getSaveMapButton().setEnabled(true);
					mainWindow.getSaveButton().setEnabled(true);
					mainWindow.getOpenButton().setEnabled(true);
					mainWindow.getMapPathField().setText(file.getAbsolutePath());
					mainWindow.getTabPane().setEnabledAt(1, true);
					mainWindow.getTabPane().setEnabledAt(2, true);
					mainWindow.getTabPane().setEnabledAt(3, true);
					
					basicTabController.setCurrentMapPath(currentMapPath);
					basicTabController.load();
				}
			}
		}
		catch (final Exception e)
		{
			throw new InterfaceControllerException(e);
		}
	}

	public void mainWindowAction(final ActionEvent event, final MainWindowAction actionType) {
		if (actionType == MainWindowAction.OPEN_MAP) {
			try
			{
				openMap();
			}
			catch (final Exception e)
			{
				// TODO Display error window here!
				e.printStackTrace();
			}
		}
		
		if (actionType == MainWindowAction.SAVE_MAP) {
			try
			{
				saveMap();
			}
			catch (final Exception e)
			{
				// TODO Display error window here!
				e.printStackTrace();
			}
		}
		
		if (actionType == MainWindowAction.OPEN_MISSION) {
			try
			{
				loadData();
			}
			catch (final Exception e)
			{
				// TODO Display error window here!
				e.printStackTrace();
			}
		}
		
		if (actionType == MainWindowAction.SAVE_MISSION) {
			try
			{
				saveData();
			}
			catch (final Exception e)
			{
				// TODO Display error window here!
				e.printStackTrace();
			}
		}
	}
	
	public static void main(final String[] args)
	{
		final boolean debug = args.length > 0;
		final MainWindowController ic = new MainWindowController(debug);
		ic.run();
	}
}
