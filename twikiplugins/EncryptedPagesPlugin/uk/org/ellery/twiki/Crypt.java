/**
 * @author rellery
 *
 * To change this generated comment edit the template variable "typecomment":
 * Window>Preferences>Java>Templates.
 * To enable and disable the creation of type comments go to
 * Window>Preferences>Java>Code Generation.
 */

package uk.org.ellery.twiki;

import java.io.IOException;
import java.security.NoSuchAlgorithmException;
import java.security.Security;
import java.security.spec.InvalidKeySpecException;
import java.util.Random;

import javax.crypto.Cipher;
import javax.crypto.SecretKey;
import javax.crypto.SecretKeyFactory;
import javax.crypto.spec.PBEKeySpec;
import javax.crypto.spec.PBEParameterSpec;


//import sun.security.krb5.internal.au;

public class Crypt {

  public static String password = "default";

  private byte[] salt;

  private static int count = 12345;

  static {
	// Security.addProvider(new com.sun.crypto.provider.SunJCE());
  //   Security.addProvider(new ABA);
  }

  private SecretKey generateKey() throws NoSuchAlgorithmException,
  InvalidKeySpecException {
	PBEKeySpec spec = new PBEKeySpec(password.
									 toCharArray());

	return SecretKeyFactory.getInstance("PBEWithMD5AndDES").generateSecret(spec);


  }





  public byte[] crypt(byte[] input, int mode)  {
	byte[] result = null;

	try {

	  SecretKey key = generateKey();

	  PBEParameterSpec spec = new PBEParameterSpec(salt, count);

	  //Cipher ciph = Cipher.getInstance("PBEWithMD5AndTripleDES");
		Cipher ciph = Cipher.getInstance("PBEWithMD5AndDES");
	  
	  ciph.init(mode, key, spec);

	  result =  ciph.doFinal(input);
	}
	catch (Exception e) {System.out.println(e); }
	return result;
  }

 public byte[] encryptString(String plainText) {
   return crypt(plainText.getBytes(), Cipher.ENCRYPT_MODE);
 }

 public String encryptStringToString(String plainText) {

 	// Begin by creating a random salt of 64 bits (8 bytes)
 	salt = new byte[8];
 	Random random = new Random();
 	random.nextBytes(salt);
	
	//call Crypt
 	byte[] cipherText = encryptString(plainText);

 	String saltString = encode(salt);
 	String ciphertextString = encode(cipherText);


 	return saltString+ciphertextString;

 }

   public byte[] decryptString(String plainText) throws IOException{

   	// Begin by splitting the text into salt and text Strings
   	// salt is first 12 chars, BASE64 encoded from 8 bytes.
   	String saltString = plainText.substring(0,16);
   	String ciphertext = plainText.substring(16,plainText.length());

   	// BASE64Decode the bytes for the salt and the ciphertext
   	salt = decode(saltString);
   	byte[] ciphertextArray = decode(ciphertext);

	 return crypt(ciphertextArray, Cipher.DECRYPT_MODE);

  }

  public String decryptStringToString(String text) throws IOException{
	return new String(decryptString(text));
  }

 public static String encode(byte[] binaryData) {
 	
 	StringBuffer result = new StringBuffer();
 	for ( int i = 0; i < binaryData.length; i++ ) {
 	  Byte b = new Byte(binaryData[i]);
 	  int irep = b.intValue();
 	  if ( irep < 0 ) {
 		irep += 256;
 	  }

 	  if ( irep < 16 ) {
 		result.append('0');
 	  }

 	  result.append(Integer.toHexString(irep));
 	}
 	
 	return (new String(result));
 }
 	
 	
 	public static byte[] decode(String plainText) {
 	
 		byte[] plainBytes = new byte[plainText.length() / 2];
 		char[] plainChars = plainText.toCharArray();

 		for ( int i = 0; i < plainChars.length; i += 2 ) {

 		  int irep = Integer.parseInt(new String(plainChars, i, 2), 16);
 		  if ( irep > 127 ) {
 			 irep -= 256;
 		  }
 		  plainBytes[i/2] = new Integer(irep).byteValue();

 		}	
 	
 	return plainBytes;
 }


 public static void main(String[] argv) throws IOException{
   if ( argv.length != 2 ) {
	 System.err.println("Usage: Crypt [ -d | -e ] text");
	 System.exit(1);
   }

	Crypt crypto = new Crypt();

   if ( argv[0].equals("-e") ) {
	 System.out.println(crypto.encryptStringToString(argv[1]));
   } else if ( argv[0].equals("-d") ) {
	 System.out.println(crypto.decryptStringToString(argv[1]));
   }
 }

}