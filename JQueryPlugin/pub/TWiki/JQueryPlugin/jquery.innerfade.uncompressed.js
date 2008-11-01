/* =========================================================

// jquery.innerfade.js

// Datum: 2007-01-29
// Firma: Medienfreunde Hofmann & Baldes GbR
// Autor: Torsten Baldes
// Mail: t.baldes@medienfreunde.com
// Web: http://medienfreunde.com

// based on the work of Matt Oakes http://portfolio.gizone.co.uk/applications/slideshow/

// ========================================================= */


(function($) {

$.fn.innerfade = function(options) {

	this.each(function(){ 	
		
		var settings = {
			animationtype: 'fade',
			speed: 'normal',
			timeout: 2000,
			type: 'sequence',
			containerheight: 'auto',
			runningclass: 'innerfade'
		};
		
		if(options)
			$.extend(settings, options);
		
		var elements = $(this).children();
	
		if (elements.length > 1) {
		
			$(this).css('position', 'relative');
	
			$(this).css('height', settings.containerheight);
			$(this).addClass(settings.runningclass);
			
			for ( var i = 0; i < elements.length; i++ ) {
				$(elements[i]).css('z-index', String(elements.length-i)).css('position', 'absolute');
				$(elements[i]).hide();
			};
		
			if ( settings.type == 'sequence' ) {
				setTimeout(function(){
					$.innerfade.next(elements, settings, 1, 0);
				}, settings.timeout);
				$(elements[0]).show();
			} else if ( settings.type == 'random' ) {
				setTimeout(function(){
					do { current = Math.floor ( Math.random ( ) * ( elements.length ) ); } while ( current == 0 )
					$.innerfade.next(elements, settings, current, 0);
				}, settings.timeout);
				$(elements[0]).show();
			}	else {
				alert('type must either be \'sequence\' or \'random\'');
			}
			
		}
		
	});
};


$.innerfade = function() {}
$.innerfade.next = function (elements, settings, current, last) {

	if ( settings.animationtype == 'slide' ) {
		$(elements[last]).slideUp(settings.speed, $(elements[current]).slideDown(settings.speed));
	} else if ( settings.animationtype == 'fade' ) {
		$(elements[last]).fadeOut(settings.speed);
		$(elements[current]).fadeIn(settings.speed);
	} else {
		alert('animationtype must either be \'slide\' or \'fade\'');
	};
	
	if ( settings.type == 'sequence' ) {
		if ( ( current + 1 ) < elements.length ) {
			current = current + 1;
			last = current - 1;
		} else {
			current = 0;
			last = elements.length - 1;
		};
	}	else if ( settings.type == 'random' ) {
		last = current;
		while (	current == last ) {
			current = Math.floor ( Math.random ( ) * ( elements.length ) );
		};
	}	else {
		alert('type must either be \'sequence\' or \'random\'');
	};
	setTimeout((function(){$.innerfade.next(elements, settings, current, last);}), settings.timeout);
};
})(jQuery);
