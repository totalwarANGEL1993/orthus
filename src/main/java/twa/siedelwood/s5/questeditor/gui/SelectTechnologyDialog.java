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
import javax.swing.ListSelectionModel;

@SuppressWarnings("serial")
public class SelectTechnologyDialog extends JDialog implements ActionListener
{
	private final JList techList;
	private final JButton confirm;
	private int listIndex;
	
	public SelectTechnologyDialog(final JFrame parent, final String title, final boolean flag, final Vector<String> list) {
		super(parent, title, flag);
		listIndex = -1;
		
		setSize(225, 400);
		setLocationRelativeTo(parent);
		setDefaultCloseOperation(DISPOSE_ON_CLOSE);
		setResizable(false);
		
		final JPanel panel = new JPanel(null);
		panel.setSize(225, 400);
		add(panel);
		
		final JScrollPane scrollPane = new JScrollPane();
		techList = new JList<String>();
		techList.setBounds(10, 0, 200, 320);
		techList.setListData(list);
		techList.setSelectionMode(ListSelectionModel.SINGLE_SELECTION);
		scrollPane.setViewportView(techList);
		scrollPane.setBounds(10, 10, 200, 320);
		scrollPane.setVisible(true);
		panel.add(scrollPane);
		
		confirm = new JButton("Auswählen");
		confirm.setBounds(45, 335, 120, 20);
		confirm.addActionListener(this);
		confirm.setVisible(true);
		panel.add(confirm);
		
		add(panel);
		setVisible(true);
	}
	
	public void reset() {
		listIndex = -1;
	}
	
	public int getSelected() {
		return listIndex;
	}

	@Override
	public void actionPerformed(final ActionEvent e)
	{
		listIndex = techList.getSelectedIndex();
		dispatchEvent(new WindowEvent(this, WindowEvent.WINDOW_CLOSING));
	}
}
