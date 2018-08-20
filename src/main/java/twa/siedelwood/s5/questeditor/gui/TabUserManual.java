package twa.siedelwood.s5.questeditor.gui;

import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Paths;

import javax.swing.JLabel;
import javax.swing.JPanel;

@SuppressWarnings("serial")
public class TabUserManual extends JPanel
{
	private final int x;
	private final int y;
	private JLabel manual;
	
	public TabUserManual (final int x, final int y) {
		this.x = x;
		this.y = y;
	}

	public void buildTab()
	{
		setLayout(null);
		
		manual = new JLabel();
		manual.setBounds(10, 0, x-20, y-110);
		manual.setVerticalAlignment(JLabel.TOP);
		
		String text;
		try {
			text = new String(Files.readAllBytes(Paths.get("cnf/manual.html")));
		} catch (IOException e) {
			text = "ERROR: Content not found!";
		}
		
		manual.setText(text);
		manual.setVisible(true);
		add(manual);
		
		setVisible(true);
	}
}
