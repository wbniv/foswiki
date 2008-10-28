package com.mrjc.twiki.addons;
import java.applet.Applet;
import java.awt.Color;
import java.awt.Dimension;
import java.awt.Image;
import java.awt.event.ActionEvent;
import java.awt.event.ActionListener;
import java.awt.dnd.DnDConstants;
import java.awt.dnd.DropTarget;
import java.awt.dnd.DropTargetDragEvent;
import java.awt.dnd.DropTargetDropEvent;
import java.awt.dnd.DropTargetEvent;
import java.awt.dnd.DropTargetListener;
import java.io.File;
import java.io.FileWriter;
import java.io.IOException;
import java.io.Reader;
import java.net.MalformedURLException;
import java.net.URL;
import java.util.AbstractList;
import javax.swing.JButton;
import javax.swing.JTextArea;
import javax.swing.JScrollPane;

/**
 *  Twiki paste applet. 
 *
 *@author	Catherine Macleod 
 
 There is a free .gif encoder here:
http://www.acme.com/resources/classes/Acme/JPM/Encoders/GifEncoder.java
and free .png decoder/encoder here:
http://www.visualtek.com

 */

public class TwikiPaste extends Applet implements ActionListener, DropTargetListener
{
	private static String DATATYPE_TEXT = "text";
    private static String DATATYPE_RICHTEXT = "rich text"; 
    private static String DATATYPE_IMAGE = "image"; 
    private static String DATATYPE_FILE = "one or more files";
	 
    private JTextArea msgTxt;
	private FileUploader fu;
	private ClipboardHelper cbHelper;
	private File file;
	private java.awt.dnd.DropTarget dropTarget;
	private String action;
	private String redirectHTML;
	private String redirectURL;
    public static String javaPasteCvsRevision = "Cvs: $Revision$";
	
	public TwikiPaste() {

		super();

		msgTxt = new JTextArea();
		dropTarget = new DropTarget(msgTxt, this); // DnDConstants.ACTION_REFERENCE,
		
	}

    /**
     * Initialises applet - adds text area and paste button to screen.
     * 
     * @author	Catherine Macleod
     */
    public void init() 
	{
		cbHelper = new ClipboardHelper();
		
		msgTxt.setLineWrap(true);
		JScrollPane scrollPane = new JScrollPane(msgTxt);
		scrollPane.setVerticalScrollBarPolicy(JScrollPane.VERTICAL_SCROLLBAR_AS_NEEDED);
		scrollPane.setPreferredSize(new Dimension(370,160));
		
		JButton pasteBtn = new JButton("paste from clipboard");
		pasteBtn.addActionListener(this);
		add(pasteBtn);
		add(scrollPane);
		setBackground (Color.white);
		
		action = getParameter("action");

		if (action == null || action.equals("")) {
			System.out.println("no action");
			addText("No action parameter supplied to applet. This should be the URL of the upload script.");
			addText("for instance, <APPLET CODE = \"...>\"\n"+ 
				"<PARAM NAME=\"action\" VALUE=\"http://localhost:8123/twiki/bin/upload.pl/Main/CatherineMacleod>\"\n");
		} else {
			
		    System.out.println(javaPasteCvsRevision + " ACTION='"+action+"'");
		    addText("TWiki "+ javaPasteCvsRevision + "Paste initiated\n\n");
		    addText("With this utility, you can paste capture pictures or files\n placed on the Clipboard.\n");
			addText("For conversation on this tool, please see:\n http://javapaste.mrjc.com/JavaPaste.htm\n\n");
		}
		repaint();
    }

    /**
     * Writes input text to screen
     * 
     * @author	Catherine Macleod
     * @param	newWord text to be written to screen 
     */
    public void addText(String newWord) 
	{
		msgTxt.append(newWord);
        repaint();
    }
	
    private String getTypeOfData(Object dataOnClipboard) 
    {
    	String ans;
    	
		if (dataOnClipboard instanceof Byte) {
			ans = "Data on clipboard is a byte array\n";
		} else if (dataOnClipboard instanceof String)
    		ans = "Data on clipboard is "+DATATYPE_TEXT+"\n";
		else if (dataOnClipboard instanceof Reader)
			ans = "Data on clipboard is "+DATATYPE_RICHTEXT+"\n";
		else if (dataOnClipboard instanceof Image)
			ans = "Data on clipboard is "+DATATYPE_IMAGE+"\n";
		else if (dataOnClipboard instanceof AbstractList)
			ans = "Data on clipboard is "+DATATYPE_FILE+"\n";
		else ans = "Data on clipboard is unrecognised: "+dataOnClipboard.getClass().getName() +"\n";
		
		return ans;
    }

	/**
	 * Pastes clipboard contents onto Twiki page (saves clipboard contents are file and
	 * attaches file to twiki page).

	 * 
	 * Multiple scenarios to consider:
     *     -     user rightclicks on an image and selects copy - paste in twiki
     *            causes conversion to a JPG and the resulting image is uploaded
     * 	   -	   	 user rightclicks on files in windows explorer and selects
     * copy. paste in twiki results in file references on the clipboard
     *      -      user selects and copies text onto the clipboard, Pastes in
     * twiki causes upload of a text file with the contents.
	 *  
	 * @author	Catherine Macleod
	 * @param	e button action 
	 */
	public void actionPerformed(ActionEvent eNotUsed) {

		try {
		    processData(cbHelper.getClipboardContents());
		} catch (java.security.AccessControlException ace) {
			addText(ace.toString());
		}
	}
	
	public void processData(Object dataOnClipboard) {
		
		
/* This causes system to hang in drag and drop mode!
 * 
 *		GetComment g = new GetComment();
 *		g.show();
 *		String comment = g.getText();
*/

		String comment = "";
		
		addText("Okay, starting paste. Please wait.\n");
		//addText(dataOnClipboard.getClass().toString());
		addText(getTypeOfData(dataOnClipboard));


		try {
			//NB, Passing a reference to this object is a hack to allow 
			//    the uploader to show that it is doing something.
			//    It should be implemented using an interface, perhaps Observable
			//    Feel free.
			  
			fu = new FileUploader(action, this);
			fu.uploadData(dataOnClipboard, comment);
			redirectHTML = fu.getPOSTRequestResponse();
			
			addText(redirectHTML);
			redirectURL = getBaseURL(redirectHTML);
			if ( !(redirectURL.equals("")) )
			{
				try
				{
					getAppletContext().showDocument(new URL(redirectURL));
				}
				catch (MalformedURLException murle)
				{
					murle.printStackTrace();
				}
			}
		} catch (Exception e)
		{
		    addText("\n\nOoops! Fatal exception: "+e.getMessage()+"\n"+e.toString());	
		}
		
		
		
    }
	
	/**
	 * Saves input HTML to a file.
	 * 
	 * @author	Catherine Macleod
	 * @param	html html to be saved 
	 * @return	htmlm file 
	 */
	private File saveHTML(String html)
	{
		File htmlOutput= null;
		try
		{
			htmlOutput = new File(System.getProperty("user.dir")+System.getProperty("file.separator")+"myUpload.html");
			FileWriter fw = new FileWriter(htmlOutput);
			fw.write(html);
			fw.flush();
			fw.close();
		}
		catch (IOException ioe)
		{
			ioe.printStackTrace();
		}
		
		return htmlOutput;
	}
	
	/**
	 * Searches the input HTML for the BASE tag and returns the base URL.
	 * 
	 * @author	Catherine Macleod
	 * @param	html html containing base URL 
	 * @return	base URL 
	 */
	private String getBaseURL(String html)
	{
		String newURL = "";
		
		if (html.indexOf("<base") != -1)
		{
			int baseIndex = html.indexOf("<base");
			int start = html.indexOf("\"", baseIndex);
			int end = html.indexOf("\"", start+1);
			newURL = html.substring(start+1, end);
		}
		return newURL;
	}
	
	
	/** If run as an application.
	 * Don't do this.
	 * @param args
	 
	public static void main(String[] args)
	{
		
		System.out.println("running");

		JFrame frame = new JFrame();
		Dialog d = new Dialog(frame,"X",true);
		TwikiPaste twikiPaste = new TwikiPaste();
		twikiPaste.appInit();
		
		frame.getContentPane().add(twikiPaste);
		frame.setSize(370, 200);

		frame.show();
		
		frame.addWindowListener(new java.awt.event.WindowAdapter()
		{
			public void windowClosing(java.awt.event.WindowEvent we)
			{
				System.exit(0);
			}
		});
		
	
	public void appInit()
	{
		cbHelper = new ClipboardHelper();
		action = "http://10.117.16.143/twiki/bin/upload.pl/Main/CatherineMacleod";
		msgTxt = new JTextArea();
		msgTxt.setLineWrap(true);
		JScrollPane scrollPane = new JScrollPane(msgTxt);
		scrollPane.setVerticalScrollBarPolicy(JScrollPane.VERTICAL_SCROLLBAR_AS_NEEDED);
		scrollPane.setPreferredSize(new Dimension(370,160));
		
		JButton pasteBtn = new JButton("paste from clipboard");
		pasteBtn.addActionListener(this);
		add(pasteBtn);
		add(scrollPane);
		setBackground (Color.white);
		repaint();
		
	}
	
		
	}
	
	*/
	/**
	 * @see java.awt.dnd.DropTargetListener#dragEnter(java.awt.dnd.DropTargetDragEvent)
	 */
	public void dragEnter(DropTargetDragEvent dtde) {
	}
	/**
	 * @see java.awt.dnd.DropTargetListener#dragOver(java.awt.dnd.DropTargetDragEvent)
	 */
	public void dragOver(DropTargetDragEvent dtde) {
	}
	/**
	 * @see java.awt.dnd.DropTargetListener#dropActionChanged(java.awt.dnd.DropTargetDragEvent)
	 */
	public void dropActionChanged(DropTargetDragEvent dtde) {
	}
	/**
	 * @see java.awt.dnd.DropTargetListener#dragExit(java.awt.dnd.DropTargetEvent)
	 */
	public void dragExit(DropTargetEvent dte) {
	}
	/**
	 * @see java.awt.dnd.DropTargetListener#drop(java.awt.dnd.DropTargetDropEvent)
	 */
	public void drop(DropTargetDropEvent dtde) {

		dtde.acceptDrop(DnDConstants.ACTION_LINK);	
		processData(cbHelper.getData(dtde.getTransferable()));
		dtde.dropComplete(true);


	}

}
