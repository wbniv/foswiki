package com.mrjc.twiki.addons.debug;
import java.io.*;
import java.net.*;
//import java.util.*;

public class DebugPostServer
{
   public static final int PORT = 8123;

   public static void main(String[] args)
      throws Exception
   {

      ServerSocket server = new ServerSocket(PORT);
      System.out.println("server: started server on port " + PORT);

      for (;;) {

         // Wait for requests

         System.out.println("server: waiting for request");
         Socket client = server.accept();

      	// Open server socket
      	File output = new File("DebugServerStdOut.txt");
      	FileWriter fw = new FileWriter(output);

         System.out.println("server: request received from "
            + client.getInetAddress().getHostName());

         // Read headers

         BufferedReader in =
            new BufferedReader(
            new InputStreamReader(
            client.getInputStream()));
         int contentLength = -1;
         for (;;) {
            String line = in.readLine();
            if (line == null)
               break;
            System.out.println("client: " + line);
			fw.write(line+"\n");
            if (line.toUpperCase().startsWith("CONTENT-LENGTH:")) {
               int p = line.indexOf(" ");
               String value = line.substring(p).trim();
               contentLength = Integer.parseInt(value);
            }
            if (line.trim().equals(""))
               break;
         }

         // Read content

         if (contentLength > 0) {
            char[] chars = new char[contentLength];
            in.read(chars);
            String line = new String(chars);
            System.out.println("client: " + line);
         	fw.write(line);
         }

         // Dummy OK

         PrintWriter out = new PrintWriter(client.getOutputStream());
         out.println("HTTP/1.0 200 OK");
         out.println("Content-Type: text/html");
         out.println("");
         out.println("<H3>OK</H3>");
         out.flush();

         // Close streams

         in.close();
         out.close();
         client.close();
		 
		 fw.flush();
		 fw.close();
      }
   }
}
