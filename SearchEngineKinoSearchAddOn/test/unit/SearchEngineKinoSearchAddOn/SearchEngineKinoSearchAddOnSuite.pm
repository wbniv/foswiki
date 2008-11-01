package SearchEngineKinoSearchAddOnSuite;
use base qw(Unit::TestSuite);

sub include_tests {
    qw( KinoSearchTests IndexTests SearchTests StringifyBaseTest Doc_antiwordTests Doc_wvTests Doc_abiwordTests XlsTests PdfTests TxtTests HtmlTests PptTests);
};

1;
