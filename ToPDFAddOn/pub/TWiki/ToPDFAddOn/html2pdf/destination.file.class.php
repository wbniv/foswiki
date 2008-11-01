<?php
class DestinationFile extends Destination {
  var $_link_text;
  var $_dest_path;
  function DestinationFile($filename, $link_text = null, $dest_path = null) {
    $this->Destination($filename);
    $this->_dest_path = $dest_path;
    $this->_link_text = $link_text;
  }

  function process($tmp_filename, $content_type) {
    if($this->_dest_path == null) {
    	$dest_filename = OUTPUT_FILE_DIRECTORY.$this->filename_escape($this->get_filename()).".".$content_type->default_extension;
    }
    else {
    	$dest_filename = $this->_dest_path.$this->filename_escape($this->get_filename()).".".$content_type->default_extension;
    }
   print "dest : $dest_filename\n\r";
    copy($tmp_filename, $dest_filename);

    $text = $this->_link_text;
    $text = preg_replace('/%link%/', 'file://'.$dest_filename, $text);
    $text = preg_replace('/%name%/', $this->get_filename(), $text);
    print $text;
  }
}
?>
