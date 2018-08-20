package twa.siedelwood.s5.questeditor.gui;

import java.awt.Color;
import java.awt.event.ActionEvent;
import java.awt.event.ActionListener;
import java.awt.event.WindowEvent;
import java.util.Vector;
import javax.swing.BorderFactory;
import javax.swing.JButton;
import javax.swing.JDialog;
import javax.swing.JFrame;
import javax.swing.JList;
import javax.swing.JPanel;
import javax.swing.JScrollPane;
import javax.swing.JTextField;
import javax.swing.ListSelectionModel;

@SuppressWarnings("serial")
public class CreateQuestDialog extends JDialog implements ActionListener
{
	private JPanel panel;
	private JTextField questNameField;
	private JButton confirm;
	private String questName;
	
	public CreateQuestDialog(final JFrame parent, final String title, final boolean flag) {
		super(parent, title, flag);
		questName = null;
		
		setSize(450, 100);
		setLocationRelativeTo(parent);
		setDefaultCloseOperation(DISPOSE_ON_CLOSE);
		setResizable(false);
		
		panel = new JPanel(null);
		panel.setSize(450, 100);
		add(panel);
		
		questNameField = new JTextField();
		questNameField.setBounds(10, 10, 425, 20);
		questNameField.setVisible(true);
		panel.add(questNameField);
		
		confirm = new JButton("Bestätigen");
		confirm.setBounds(165, 40, 120, 20);
		confirm.addActionListener(this);
		confirm.setVisible(true);
		panel.add(confirm);
		
		setVisible(true);
	}
	
	public void reset() {
		questName = null;
	}
	
	public String getName() {
		return questName;
	}

	@Override
	public void actionPerformed(final ActionEvent e)
	{
		if (!questNameField.getText().equals("")) {
			questName = questNameField.getText();
		}
		dispatchEvent(new WindowEvent(this, WindowEvent.WINDOW_CLOSING));
	}
}
