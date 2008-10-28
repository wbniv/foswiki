package com.mrjc.twiki.addons;
import java.awt.Image;
import java.awt.Toolkit;
import java.awt.datatransfer.Clipboard;
import java.awt.datatransfer.DataFlavor;
import java.awt.datatransfer.Transferable;
import java.awt.datatransfer.UnsupportedFlavorException;
import java.io.File;
import java.io.IOException;
import java.io.Reader;
import java.util.AbstractList;
//import java.util.Hashtable;


/**
 *  Helper class for clipboard functions.
 *
 *@author	Catherine Macleod
 */
public class ClipboardHelper
{

	Toolkit toolkit;

	public static void main(String args[])
	{
		ClipboardHelper app = new ClipboardHelper();
	}

	/**
	 * Returns object representing data on clipboard
	 *
	 * @author	Catherine Macleod
	 * @return
	 */
	public Object getClipboardContents()
	{
		// Use the Toolkit object to obtain access to the system clipboard
		Clipboard clip=Toolkit.getDefaultToolkit().getSystemClipboard();
		// Get the clipboard contents
		return getData(clip.getContents(ClipboardHelper.this));

	}

	public Object getData(Transferable contents) {

		Object data = null;

		if (contents!=null)
		{
			 // Get the data flavors associated with the clipboard contents
			 DataFlavor flavors[]=contents.getTransferDataFlavors();
			 DataFlavor flavor = null;
			 File resultsFile;
			 for(int i=0;i<flavors.length;++i)
			 {
				System.out.println("In loop " + i);
				if (flavors[i].getRepresentationClass() != null)
				{
					try
					{
						System.out.println(flavors[i].getRepresentationClass());
						System.out.println("in loop:2");
						data = contents.getTransferData(flavors[i]);
						System.out.println("in loop:3");
						if ((data instanceof Reader)
							 || (data instanceof String)
							 || (data instanceof Image)
							 || (data instanceof AbstractList)) {

							 break;

						}

					}
					catch (UnsupportedFlavorException ufe)
					{
						System.out.println("ClipboardHelper.getClipboardContentsDataType UnsupportedException: "+ufe);
					}
					catch (IOException ioe)
					{
						System.out.println("ClipboardHelper.getClipboardContentsDataType IOException: "+ioe);
					}

				}

			 }
		}
		return data;
	}



	/**
	 * Writes contents of the clipboard to a file
	 *
	 * @author	Catherine Macleod
	 * @param	o object containing data from clipboard
	 * @return	file containing clipboard contents
	 *
	public File saveClipboardContentsToFile(Object o)
	{
		File file = null;
		String dataType = o.getClass().getName();
		try
		{
			if (o instanceof Image)
			{
			  file = new File(System.getProperty("user.dir")+System.getProperty("file.separator")+"myUpload.jpg");
			  FileOutputStream out = new FileOutputStream(file);
			  JPEGImageEncoder encoder = JPEGCodec.createJPEGEncoder(out);
			  JPEGEncodeParam param = encoder.getDefaultJPEGEncodeParam((BufferedImage)o);
			  param.setQuality(1.0f, false);  // max quality
			  encoder.setJPEGEncodeParam(param);
			  encoder.encode((BufferedImage)o);
			  out.flush();
			  out.close();
			}
			else if (o instanceof String)
			{
				file = new File(System.getProperty("user.dir")+System.getProperty("file.separator")+"myUpload.txt");
				FileWriter out = new FileWriter(file);
				out.write((String)o);
				out.flush();
				out.close();
			}
			else if (o instanceof Reader)
			{
				StringBuffer results = new StringBuffer();
				BufferedReader input = new BufferedReader((InputStreamReader)o);
				String str;
				while (null != ((str = input.readLine())))
					results.append(str);

				input.close ();

				file = new File(System.getProperty("user.dir")+System.getProperty("file.separator")+"myUpload.doc");
				FileWriter out = new FileWriter(file);
				out.write(results.toString());
				out.flush();
				out.close();
			}

		}
		catch (IOException ioe)
		{
			System.out.println("ClipboardHelper.getClipboardContents IOException: "+ioe);
		}
		return file;
	}
	*/


}

