<?php
    $foswikiConfigPath = "../../../lib";
    //$foswikiConfigPath = "/var/www/www.collaborganize.de/core/lib";
    $foswikiConfig = file_get_contents("$foswikiConfigPath/LocalSite.cfg");

    preg_match_all('/\$Foswiki::cfg\{Plugins\}\{ToPDFPlugin\}\{([^\}]+)\}=["]?([^";]+)["]?;/', $foswikiConfig, $tmp, PREG_SET_ORDER);
    $_CONFIG = array();
    foreach($tmp as $value) {
        $_CONFIG[$value[1]] = $value[2];
    }

	require_once('html2pdf/config.inc.php');
	require_once(HTML2PS_DIR."pipeline.class.php");
	require_once(HTML2PS_DIR.'pipeline.factory.class.php');
	parse_config_file(HTML2PS_DIR."html2ps.config");

	$sourcefn = $argv[1];
	$destfn = $argv[2];
	$outputdir = $argv[3];
	$articlePath = $argv[4];
	$author = $argv[5];
    $headerFile= $argv[6];
    $footerFile= $argv[7];
	$date = date($_CONFIG['DateFormat']);
	$g_css_index = 0;
	$g_stylesheet_title = "";
	$g_baseurl = $_CONFIG['BaseUrl'];
	$g_config = array ( 	'cssmedia' => 'print',
				'renderimages' => $_CONFIG['RenderImages'],
				'renderforms' => $_CONFIG['RenderForms'],
				'renderlinks' => $_CONFIG['RenderLinks'],
				'mode' => "html",
				'debugbox' => false,
				'pagewidth' => $_CONFIG['PageWidth'],
				'draw_page_border' => false,
				'smartpagebreak' => true,
				'media' => $_CONFIG['MediaType'],
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

	// for fetching the css files
	require_once(HTML2PS_DIR.'fetcher.local.class.php');
	#$pipeline->fetchers[] = new FetcherLocalfile("");
	$pipeline->fetchers[] = new FetcherLocalfile($sourcefn);

	require_once(HTML2PS_DIR.'fetcher.url.curl.class.php');
	$pipeline->fetchers[] = new FetcherUrlCurl();
	#toc!
	if($_CONFIG['CreateTOC'])
        $pipeline->add_feature('toc', array('location', 'before'));

    $header_html = file_get_contents($headerFile);
    $footer_html =file_get_contents($footerFile);
	$pipeline->pre_tree_filters = array();
	if( $header_html != '' || $footer_html != '') {
		$filter = new PreTreeFilterHeaderFooter($header_html, $footer_html);
		$pipeline->pre_tree_filters[] = $filter;
	}
  	$image_encoder = new PSL3ImageEncoderStream();

	$pipeline->data_filters[] = new DataFilterDoctype();
	$pipeline->data_filters[] = new DataFilterUTF8('iso-8859-15');
 	$pipeline->data_filters[] = new DataFilterHTML2XHTML();
	$pipeline->parser = new ParserXHTML;

	$pipeline->post_tree_filters = array();
	$pipeline->layout_engine = new LayoutEngineDefault;
	$pipeline->output_driver = new OutputDriverFPDF();
	$pipeline->destination = new DestinationFile($destfn,"",$outputdir);
	$pipeline->process($sourcefn,$g_media);
?>
