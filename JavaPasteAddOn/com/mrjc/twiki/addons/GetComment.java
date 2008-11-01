// Program 17.3: An Alert Dialog class
package com.mrjc.twiki.addons;
//import java.awt.Dimension;
//import java.awt.Panel;    
//import java.awt.Label;
//import java.awt.FlowLayout;
import java.awt.TextField;
import java.awt.event.KeyEvent;
import java.awt.event.KeyListener;

import javax.swing.JDialog;
import javax.swing.JFrame;


public class GetComment extends JDialog implements KeyListener {

  private static String s = "Please enter a comment or press <Enter>";
  private TextField t;
  private String returnedText;
  
  public String getText() {
  	return returnedText;
  }

  public GetComment () {
  	
  	super(new JFrame(), true);
 
    setTitle("Please enter a comment or press Enter");
    //add("Center", new Label(s));
    //Panel p = new Panel();
    //p.setLayout(new FlowLayout());
    //p.add(new Button("OK"));
    
    t = new TextField();
    //t.setSize(new Dimension(400,200));
    t.addKeyListener(this);
    
    
    
    //p.add(t );
    //add("South", p);
    //p.add(t);
    getContentPane().add(t);
    //Dimension d = new Dimension(600,70);
    //setSize(d);
    
   
    
    //resize(300,100);
    //move(100,200);
    setBounds(100,200,600,70);  

  }  
  
	public void keyTyped(KeyEvent e) {}
	public void keyReleased(KeyEvent e) {}
	public void keyPressed(KeyEvent e) {
	  int key = e.getKeyCode();
	  if (key == KeyEvent.VK_ENTER) {
	  	 returnedText = t.getText();
	  	 System.out.println("CoMMENT IS " + returnedText);
		 hide();
		 }
	  }

  
 /* public boolean action(Event e, Object o) {
  
    if(e.target instanceof Button) {
      hide();
      return true;    
    }
    return false;
  
  }*/

}
