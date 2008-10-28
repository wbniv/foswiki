package uk.org.ellery.twiki;
import java.awt.Image;
import java.awt.image.BufferedImage;
import java.net.HttpURLConnection;
import java.net.URL;
import java.io.BufferedReader;
import java.io.ByteArrayOutputStream;
import java.io.DataOutputStream;
import java.io.File;
import java.io.FileInputStream;
import java.io.InputStreamReader;
import java.io.IOException;
import java.io.Reader;
import java.util.AbstractList;
import java.util.Iterator;
import java.text.MessageFormat;

import com.sun.image.codec.jpeg.JPEGCodec;
import com.sun.image.codec.jpeg.JPEGEncodeParam;
import com.sun.image.codec.jpeg.JPEGImageEncoder;


/**
 *  Helper class for HTTP POST requests to upload files
 *
 *@author	Catherine Macleod 
 */
public class FileUploader 
{
    HttpURLConnection httpURLConn;
    String uploadScript;
    //private TwikiPaste twikiPaste;

    private static String boundary="7d1fbfe5050c";
    private static String twoHyphens="--";
    private static String lineEnd="\r\n";
	
	String jpgExtension = ".jpg";
	String gifExtension = ".gif";
	String txtExtension = ".txt";
	String docExtension = ".doc";
	
    /**
     * Constructor. 
     * 
     * @author	Catherine Macleod
     * @param	cgiScript script to action HTTP POST request 
     */
    public FileUploader(String cgiScript) throws IOException
    {
		httpURLConn = null;
	//	twikiPaste = hack;
    	uploadScript = cgiScript;
    }

    private void addMessage(String string)
    {
    	string += "\n"; // or CRLF
  //  	if (twikiPaste != null) {
    //       twikiPaste.addText(string);
    //	} else {
    	   System.out.println("msg: "+string);	
    //	}	
    }


	
	void appendDispositionToOutputStream(DataOutputStream outStream, String fileName) throws IOException {
		String contentDispositionLines = "Content-Disposition: form-data; name=\"filepath\";" + " filename=\"{0}\"" + lineEnd +lineEnd;
		Object[] args = {fileName};
		outStream.writeBytes(MessageFormat.format(contentDispositionLines, args));		
	}
	
	/** uploading rich text */
	public void appendToOutputStream(Reader data, String fileName, DataOutputStream outStream) throws IOException
	{
		appendDispositionToOutputStream(outStream, fileName);
		
		int bytesRead, bytesAvailable;
		int maxBufferSize = 1*1024*1024;
		char[] buffer = new char[maxBufferSize];

		InputStreamReader inputStream = (InputStreamReader)data;
		// read file data and write it into form
		bytesRead = inputStream.read(buffer, 0, maxBufferSize);
		while (bytesRead > 0)
		{
   		    outStream.writeBytes((new String(buffer)).substring(0, bytesRead));
			bytesRead = inputStream.read(buffer, 0, maxBufferSize);
		}
		inputStream.close();
		
	}
	
	public void appendToOutputStream(String data, String fileName, DataOutputStream outStream) throws IOException
	{
		appendDispositionToOutputStream(outStream,fileName);
		outStream.writeBytes((String)data);
	}
	
	public void appendToOutputStream(Image data, String fileName, DataOutputStream outStream) throws IOException
	{
		appendDispositionToOutputStream(outStream,fileName);
		ByteArrayOutputStream out = new ByteArrayOutputStream();
		JPEGImageEncoder encoder = JPEGCodec.createJPEGEncoder(out);
		JPEGEncodeParam param = encoder.getDefaultJPEGEncodeParam((BufferedImage)data);
		param.setQuality(1.0f, false);  // max quality
		encoder.setJPEGEncodeParam(param);
		encoder.encode((BufferedImage)data);
		outStream.write(out.toByteArray());
		out.flush();
		out.close();
	}
	
	public void appendToOutputStream(String fileName, DataOutputStream outStream) throws IOException
	{
		File f = new File(fileName);
		appendToOutputStream(f, outStream);
	}

	/**
	 * Reads contents of a file.
	 *
	 * @author	Catherine Macleod
	 * @param	file file from which content is to be read
	 * @return	file contents
	 */
	
	public void appendToOutputStream(File file, DataOutputStream outStream) throws IOException
	{
		String fileName = file.getName();		
		appendDispositionToOutputStream(outStream, fileName);
		
		final int BUFLEN = 1024;
		byte[] buff = new byte[BUFLEN];

		FileInputStream fis = new FileInputStream(file);
		while (fis.available() > 0)
		{
			int lengthRead = fis.read(buff, 0, BUFLEN);
			outStream.write(buff, 0, lengthRead);
			System.out.println("Sending "+lengthRead+" bytes");
		}

		fis.close();
		
	}

	
	public void appendDelimiterToOutputStream(DataOutputStream outStream) throws IOException
	{
		outStream.writeBytes(lineEnd + twoHyphens + boundary + lineEnd);
	}
	
	public void appendEndOfDelimitersToOutputStream(DataOutputStream outStream) throws IOException
	{
		// send multipart form data necessary after file data
		outStream.writeBytes(lineEnd);
		outStream.writeBytes(twoHyphens + boundary + twoHyphens + lineEnd);
	}
	
	public void appendCommentToOutputStream(String comment, DataOutputStream outStream) throws IOException
	{
		outStream.writeBytes(lineEnd);
		outStream.writeBytes(twoHyphens + boundary + lineEnd);
		outStream.writeBytes("Content-Disposition: form-data; name=\"filecomment\"");
		outStream.writeBytes(lineEnd + lineEnd);
		outStream.writeBytes(comment);	
	}

	/**
	 * Initialises connection.
	 *
	 * @author	Catherine Macleod

	 *  * @param	url to send the upload
	 */
	public void initialiseConnection () throws IOException
	{
		// create HTTP-connection to the script/servlet/whatever on the server and set its properties
		URL theURL = new URL(uploadScript);
		httpURLConn  = (HttpURLConnection)theURL.openConnection();

		httpURLConn.setRequestMethod("POST");
		httpURLConn.setInstanceFollowRedirects(false);
		httpURLConn.setRequestProperty("Connection", "Keep-Alive");
		httpURLConn.setDoOutput(true);
		httpURLConn.setUseCaches(false);
		httpURLConn.setRequestProperty("Accept-Charset", "iso-8859-1,*,utf-8");
		httpURLConn.setRequestProperty("Accept-Language", "en");
		httpURLConn.setRequestProperty("Content-type", "multipart/form-data; boundary=" + boundary);

	}
		
	public DataOutputStream startUpload() throws IOException
	{
		initialiseConnection();
		DataOutputStream outStream = new DataOutputStream (httpURLConn.getOutputStream());
		appendDelimiterToOutputStream(outStream);
		return outStream;
	}
	
	public void finishUpload(DataOutputStream outStream) throws IOException
	{
		String comment = "";
		appendEndOfDelimitersToOutputStream(outStream);
		// send comment
		if (comment.length() > 0 ) {
			appendCommentToOutputStream(comment, outStream);
		}
		// close streams
		outStream.flush();
		outStream.close();
		
	}
    /**
     * Uploads data from clipboard.
     * 
     * When invoked, examines the data object. If it is a Reader, reads up to
     * size MaxBufferSize and 
     * 
     * @author	Catherine Macleod
     * @param	filename file to upload
     */
    public void uploadData(Object data, String comment) throws IOException
    {
        
						 
		// NB. reader type if uploading richtext.			 
		if (data instanceof Reader)
		{
			// open output stream to server, POST data and multipart form up to the file data
			DataOutputStream outStream = startUpload();
			addMessage("You've got RTF on the clipboard... uploading as clipboard.rtf"); 
			appendToOutputStream((Reader)data, "clipboard.rtf", outStream);
			finishUpload(outStream);
			
		}
		// the thing on the clipboard is just some text, we want to make a file called clipboard.txt and shove it in.
		else if (data instanceof String)
		{
			DataOutputStream outStream = startUpload();
			addMessage("You've got text on the clipboard... uploading as clipboard.txt");
			appendToOutputStream((String) data, "clipboard.txt", outStream);
			finishUpload(outStream);
		}
		// the thing on the clipboard is an image, e.g. a bitmap
		// WE WANT TO MAKE A FILE (ASK THEM FOR THE NAME) AND upload that.
		else if (data instanceof Image)
		{
			DataOutputStream outStream = startUpload();
			addMessage("Converting image on clipboard to jpeg, uploading as clipboard.jpg");
			appendToOutputStream((Image)data, "clipboard.jpg", outStream);
			finishUpload(outStream);				
		}
		// if there is more than one thing on the clipboard
		else if (data instanceof AbstractList)
		{
			System.out.println("AbstractList uploader");
			AbstractList al = (AbstractList)data;

			Iterator iterator = al.iterator();
			File f = null;
			while (iterator.hasNext())
			{
				f = ((File)iterator.next());
				DataOutputStream outStream = startUpload();
				addMessage("filename: "+f.getPath());
				appendToOutputStream(f,outStream);					
				finishUpload(outStream);
			}
		} else {
		    addMessage("I can't send this, as I don't understand the type: " +  data.getClass().getName());
		}

    }


    /**
     * Get extension of a filename
     * 
     * @param fileName
     * @return String
     */
	String getExtension(String fileName) {
			String fileExtension = "";
			
		if ((fileName.indexOf(".") > -1)) {
			fileExtension = fileName.substring(fileName.indexOf("."));
		} else {
			fileExtension = "";
		}
            return fileExtension;
	}
	


    /**
     * Uploads file.
     * 
     * @author	Catherine Macleod
     * @param	filename file to upload
     
    public void testUploadFile(String filename, String comment)
    {
	    DataOutputStream outStream;
	    int bytesRead, bytesAvailable, bufferSize;
	    byte[] buffer;
	    int maxBufferSize = 1*1024*1024;
		
	    try 
		{
	        // create FileInputStream to read from file
	        FileInputStream fileInputStream = new FileInputStream(new File(filename));

	        // open output stream to server, POST data and multipart form up to the file data
	        outStream = new DataOutputStream (httpURLConn.getOutputStream ());
	        outStream.writeBytes(twoHyphens + boundary + lineEnd);
	        outStream.writeBytes("Content-Disposition: form-data; name=\"filepath\";" + " filename=\""+ filename + "\"" + lineEnd);
	        outStream.writeBytes(lineEnd);

	        bytesAvailable = fileInputStream.available();
	        bufferSize = Math.min(bytesAvailable,maxBufferSize);
	        buffer = new byte[bufferSize];

	        // read file data and write it into form
	        bytesRead = fileInputStream.read(buffer, 0, bufferSize);
	        while (bytesRead > 0) 
			{
	            outStream.write(buffer, 0, bufferSize);
	            bytesAvailable = fileInputStream.available();
	            bufferSize = Math.min(bytesAvailable,maxBufferSize);
	            bytesRead = fileInputStream.read(buffer, 0, bufferSize);
	        }

	        // send multipart form data necessary after file data
	        outStream.writeBytes(lineEnd);
	        outStream.writeBytes(twoHyphens + boundary + twoHyphens + lineEnd);

	        // close streams
	        fileInputStream.close();
	        outStream.flush ();
	        outStream.close ();

	    }
	    catch (IOException ioex) 
		{
			ioex.printStackTrace(); 
		}
    }
	*/
    
    /**
     * Returns POST request response.
     * 
     * @author	Catherine Macleod
     * @return	POST request reponse 
     */
    public String getPOSTRequestResponse()
    {

	    BufferedReader inStream;
		StringBuffer results = new StringBuffer();
		String newURL = "";
	    try
		{
	        // display server response data on console.
			System.out.println("Response: "+httpURLConn.getResponseCode()+" "+httpURLConn.getResponseMessage());
			inStream = new BufferedReader(new InputStreamReader(httpURLConn.getInputStream()));
			System.out.println(httpURLConn.getURL());
	        String str;
			int i = 0;
	        while ((str = inStream.readLine()) != null)
				results.append(str+"\n");

	        inStream.close ();
	    }
	    catch (IOException ioex) {
	    	String problem = "FileUploader.getPOSTRequestResponse IOException: Couldn't get server response..connection already closed. "+ioex.toString();
	    	System.out.println(problem);	        
	        return problem;
	    }
		return results.toString();
    }

/*
    public static void main (String[] args) 
	{
//		FileUploader fu = new FileUploader("http://10.117.16.143/twiki/bin/upload.pl/Main/CatherineMacleod");
		FileUploader fu = new FileUploader("http://localhost:8123");
		fu.testUploadFile("C:\\WINNT\\Profiles\\Cmacleod\\Desktop\\test.txt","");
		System.out.println(fu.getPOSTRequestResponse());
		
    }
    */ 
}
