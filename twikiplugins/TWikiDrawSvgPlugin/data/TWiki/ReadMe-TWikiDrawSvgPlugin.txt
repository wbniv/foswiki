
TWikiDrawSVG
Plugin using Java Web Start and SVG technologies
Guillaume Wenger & Christophe Rei
Ecole des Mines de Paris - ISIA

TWiki is installed on many web sites, mainly behind corporate firewalls. 
TWiki is being used by many major companies, because it is very user friendly compared to some well established commercial 
groupware systems like Lotus Notes. TWikiDrawSVG is a plugin based on TWikiDrawPlugin and our improvements allow the users to :
	- edit one picture via Java Web Start, a new technology which allows all users 
	(provided that they have downloaded Java Web Start available on the Sun web site) not to depend on the web browser;

	- save and view this picture as a SVG document. 
	Scalable Vector Graphics format (SVG) is a new Web graphics format and technology based on XML. 
	SVG allows Web designers and developers to easily integrate vector graphics and text with XML, 
	HTML, CSS and JavaScript to create high quality, interactive user interfaces and online applications that can be 
	delivered to any viewing device. 

The new code proposed here launches Java Web Start application, takes the previous saving format, parses it and transforms 
it into a SVG format. The applet's improvement uses SvgSaver.class which parses the previous applet's saved document, and 
translate it into SVG format. 
The old application was based on the Jar (~ 2 Mo) and the .draw (~ 10 Ko) files downloading via the network and the execution 
was done by the browser, like a common applet.
Now, the system based on the Java Web Start technology allows a faster execution after the first use. Thus, the application 
is dowloaded at the first connection, then JWS manages the upgrading for the next connections. So the next execution are 
faster and only the .jnlp (~ 2 Ko) and the .draw files are exchanched between the provider and the customer.
