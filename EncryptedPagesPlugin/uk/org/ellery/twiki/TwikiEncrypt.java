package uk.org.ellery.twiki;

/**
 * @author rellery
 *
 * To change this generated comment edit the template variable "typecomment":
 * Window>Preferences>Java>Templates.
 * To enable and disable the creation of type comments go to
 * Window>Preferences>Java>Code Generation.
 */
/*jadclipse*/// Decompiled by Jad v1.5.8e2. Copyright 2001 Pavel Kouznetsov.
// Jad home page: http://kpdus.tripod.com/jad.html
// Decompiler options: packimports(3) radix(10) lradix(10)
// Source File Name:   TwikiEncrypt.java

import java.applet.Applet;
import java.applet.AppletContext;
import java.awt.*;
import java.awt.dnd.DropTarget;
import java.awt.event.ActionEvent;
import java.awt.event.ActionListener;
import java.io.*;
import java.net.MalformedURLException;
import java.net.URL;
import java.util.AbstractList;
import java.util.Properties;

import javax.swing.*;
import javax.swing.text.JTextComponent;

public class TwikiEncrypt extends Applet
	implements ActionListener
{

	private static Properties encodedProps = null;
	private static Properties displayProps = null;
	


	private static String DATATYPE_TEXT = "text";
	private static String DATATYPE_RICHTEXT = "rich text";
	private static String DATATYPE_IMAGE = "image";
	private static String DATATYPE_FILE = "one or more files";
	private static int counter = 0;
	private static String password = null;
	private JTextField msgTxt;
	private File file;
	private DropTarget dropTarget;
	private String action;
	private String redirectHTML;
	private String redirectURL;
	private String myKey;
	private JButton pasteBtn;

	public TwikiEncrypt()
	{
		msgTxt = new JTextField(50);
	}

	public void init()
	{
		myKey = getParameter("KEY");
		System.out.println("KEY=" + myKey);
		String encryptedData = readEncryptedData();
		encodedProps = readProperties(encryptedData);
		displayProps = new Properties(encodedProps);
		

		String myValue = displayProps.getProperty(myKey);		
		
		if (myValue != null) {
			addText(myValue);
		} else {
			displayProps.setProperty(myKey,"");
		}
		
		JScrollPane scrollPane = new JScrollPane(msgTxt);
		scrollPane.setVerticalScrollBarPolicy(20);
		scrollPane.setPreferredSize(new Dimension(300, 50));
		pasteBtn = new JButton("Decrypt");

		if (myValue == null) {
			pasteBtn.setText("Encrypt");
		}

		pasteBtn.addActionListener(this);
		add(pasteBtn);
		add(scrollPane);
		setBackground(Color.white);
		repaint();
	}

	private void addText(String newWord)
	{
		msgTxt.setText(newWord);
		repaint();
		System.out.println("repainted");
	}

	private String readEncryptedData()
	{
		StringBuffer buffer = new StringBuffer();
		byte byteBuff[] = new byte[1024];
		int byteLen = 0;
		String text = null;
		try
		{
			URL url = new URL(getParameter("ATTACHURL") + "/EncryptedData.txt");
			System.out.println(getCodeBase());
			System.out.println(url);
			for(DataInputStream stream = new DataInputStream(url.openStream()); stream.available() > 0; buffer.append(new String(byteBuff, 0, byteLen)))
				byteLen = stream.read(byteBuff, 0, 1024);

		}
		catch(IOException e)
		{
			if (e instanceof FileNotFoundException) {
				return "";
			}
			System.out.println(e);
			System.out.println("Exception reading url");
		}
		return buffer.toString();
	}

	private void writeEncryptedData()
		throws IOException
	{
		String uploadURL;
		if (getParameter("TEST") == null) {
			uploadURL = getDocumentBase().toString().replaceFirst("/view", "/upload");
		} else {
			//uploadURL = "http://twiki.org/cgi-bin/upload/Sandbox/EncryptionApplet";
			uploadURL = "http://localhost:8123/twiki/bin/upload.pl/Main/CatherineMacleod";
		}			
			
		System.out.println(uploadURL);
		FileUploader fu = new FileUploader(uploadURL);
		java.io.DataOutputStream outStream = fu.startUpload();
		fu.appendToOutputStream(encodedProps.toString(), "EncryptedData.txt", outStream);
		fu.finishUpload(outStream);
		redirectHTML = fu.getPOSTRequestResponse();
	}

	public void actionPerformed(ActionEvent eNotUsed)
	{
		try {

			if (password == null) {
				GetPassword gp = new GetPassword();
				gp.show();
				password = gp.getText();
				Crypt.password = password;
			}
			
			Crypt crypto = new Crypt();
			
			if (pasteBtn.getText().equals("Decrypt")) {
			
				displayProps.setProperty(myKey, crypto.decryptStringToString(encodedProps.getProperty(myKey)));
				addText(displayProps.getProperty(myKey));
							
					
				pasteBtn.setText("Encrypt");
			} else {
				
				if (! displayProps.getProperty(myKey).equals(msgTxt.getText())) {
					encodedProps.setProperty(myKey, crypto.encryptStringToString(msgTxt.getText()));
					System.out.println(encodedProps.toString());
					writeEncryptedData();
				}	
				
				pasteBtn.setText("Decrypt");
				displayProps.setProperty(myKey, encodedProps.getProperty(myKey));
				addText(displayProps.getProperty(myKey));
			}
		}
		catch (Exception e) {
			addText("An Exception occurred " + e.toString());
			
			
		}
			
		pasteBtn.repaint();
		
	}


/*
	public static void main(String[] args) {
		

		
		
		props.setProperty("key1",Crypt.encryptStringToString("val1"));
		props.setProperty("key2",Crypt.encryptStringToString("val2"));
		
		String encryptedProps = props.toString();
		readProperties(encryptedProps);
		
		props = new Properties();
		System.out.println(encryptedProps);
		
	}
*/
		
	public static Properties readProperties(String encryptedProps) {	
		
		Properties props = new Properties();
	
		if (encryptedProps.length() == 0) {
			return props;
		}
	
		int currentLoc = 0;
		
		do {
			int valLoc;
			int endLoc;
			String key = encryptedProps.substring(++currentLoc, valLoc=encryptedProps.indexOf("=", currentLoc));
			endLoc=encryptedProps.indexOf(",", valLoc);
			if (endLoc == -1) {endLoc = encryptedProps.indexOf("}", valLoc);}
			String val = encryptedProps.substring(++valLoc, endLoc);
			System.out.println(key+val);
			props.setProperty(key,val);
			
			currentLoc=endLoc+1;

		} while (currentLoc < encryptedProps.length());
	
		return props;	
	}

	

}

