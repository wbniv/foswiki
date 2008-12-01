<?php
	require_once('html2pdf/config.inc.php');
	require_once('header.inc.php');
	require_once(HTML2PS_DIR."pipeline.class.php");
	require_once(HTML2PS_DIR.'pipeline.factory.class.php');
	parse_config_file(HTML2PS_DIR."html2ps.config");

	$sourcefn = $argv[1];
	$destfn = $argv[2];
	$outputdir = $argv[3];
	$articlePath = $argv[4];
	$author = $argv[5];
	$date = date("d.m.y");
	$g_css_index = 0;
	$g_stylesheet_title = "";
	$g_baseurl = "http://domain.tld";
	$g_config = array ( 	'cssmedia' => 'print',
				'renderimages' => true,
				'renderforms' => false,
				'renderlinks' => true,
				'mode' => "html",
				'debugbox' => false,
				'pagewidth' => 755,
				'draw_page_border' => false,
				'smartpagebreak' => true,
				'media' => 'A4',
				'pdfversion' => '1.6',
				'method' => 'fpdf',
                                'transparency_workaround' => false,
				'scalepoints' => false,
				'pslevel' => 3,
				'output' => "",
				'landscape' => false	
				);

			
	$g_media = Media::predefined($g_config['media']);
	$g_media->set_pixels($g_config['pagewidth']);
	$g_media->set_margins(array(	'left' =>10,
					'right' => 10,
					'top' => 25,
					'bottom' => 10));

	$g_media->set_landscape($g_config['landscape']);
	$pipeline = new Pipeline();
	$pipeline->configure($g_config);

	global $g_px_scale;
	$g_px_scale = mm2pt($g_media->width() - $g_media->margins['left'] - $g_media->margins['right']) / $g_media->pixels;
	global $g_pt_scale;
	$g_pt_scale = $g_px_scale * 1.43; 

	// we use the memory fetcher, because the file fetcher is somehow broken
        $data = file_get_contents($sourcefn);	
        require_once(HTML2PS_DIR.'fetcher.memory.class.php');
	$pipeline->fetchers[] = new FetcherMemory($data, $g_baseurl);
        // we will need him for images
        require_once(HTML2PS_DIR.'fetcher.local.class.php');
	$pipeline->fetchers[] = new FetcherLocalfile("");
	// for fetching the css files
	require_once(HTML2PS_DIR.'fetcher.url.curl.class.php');
	$pipeline->fetchers[] = new FetcherUrlCurl();
	
	#toc!
	//$pipeline->add_feature('toc', array('location', 'before'));
	
	$pipeline->pre_tree_filters = array();	
	/*if( $header_html != '' || $footer_html != '') {
		$filter = new PreTreeFilterHeaderFooter($header_html, $footer_html);
		$pipeline->pre_tree_filters[] = $filter;
	}
*/
  	$image_encoder = new PSL3ImageEncoderStream();

	$pipeline->data_filters[] = new DataFilterDoctype();
	$pipeline->data_filters[] = new DataFilterUTF8('iso-8859-15');
  	$pipeline->data_filters[] = new DataFilterHTML2XHTML();
	$pipeline->parser = new ParserXHTML;

	$pipeline->post_tree_filters = array();
	$pipeline->layout_engine = new LayoutEngineDefault;
	$pipeline->output_driver = new OutputDriverFPDF();
	$pipeline->destination = new DestinationFile($destfn,"",$outputdir);
	$pipeline->process($g_baseurl,$g_media);
?>
