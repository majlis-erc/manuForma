function manuforma_changecolorsvg(domsvg, mycolor)
{
	// console.log(mycolor,$(domsvg));
	$(domsvg).find("*").each(function(){
		if ($(this).css("fill")>"" && $(this).css("fill")!="none") $(this).css("fill",mycolor);
		if ($(this).css("stroke")>"" && $(this).css("stroke")!="none") $(this).css("stroke",mycolor);
	});
}

function manuforma_adapthtml()
{
	var logobutton = $(".navbar .navbar-brand");
	logobutton.html('<object width="200" height="40" class="logo-filtered" data="resources/images/hn/logo_manuforma.svg" type="image/svg+xml"></object>');
	logobutton.find("object").click(function(){
		var mylink = $(this).parent().attr("href");
		document.location = mylink;
	});
	
	if ($("h2.replaceh1").length <= 0)
	{
		var eltTitle = $("h1.h2");
		var newEltTitle = $('<h2 class="h3 replaceh1">'+ eltTitle.html() +'</h2>');
		newEltTitle.find("span").removeAttr("id");
		
		var MutationObserver = window.MutationObserver || window.WebKitMutationObserver;
		var myObserver = new MutationObserver(function(){
			$(".headerxform h2").html($("h1.h2").html());
		});
		var obsConfig = {
		  childList: true,
		  characterData: true,
		  attributes: true,
		  subtree: true
		};
		eltTitle.each(function() {
			myObserver.observe(this, obsConfig);
		});
		
		var subtitledetail = $("main > .alert.hint");
		var newheader = $('<div class="headerxform"></div>'); 
		eltTitle.parent().removeClass("border-bottom");
		newheader.append(newEltTitle);
		newheader.append(subtitledetail);
		$("#edit").prepend(newheader);
	}
	
	$("#sidebarMenu").removeClass("bg-light").addClass("bg-dark");
	$("main").addClass("bg-dark");
	
	$("input[type=file]:not(.withlabel)").each(function(){
		var finalId = $(this).attr("id");
		if (!finalId) {
			finalId = randomId(10);
			$(this).attr("id",finalId);
		}
		$(this).addClass("withlabel");
		var labelsupport = $('<label for="'+finalId+'" class="withinputfile">Browse</label>');
		/* labelsupport.click(function(){
			$('#'+$(this).attr("for")).click();
		}); */
		$(this).before(labelsupport);
	});
	
	var monverrou = false;
	var monlast = null;
	var mongroup = null;
	$("#view-main-entry > *").each(function(){
		if ($(this).prop("tagName") == "SPAN")
		{
			if (monverrou == false)  {
				monverrou = true;
				mongroup = $('<div class="input-group"></div>');
				if (monlast == null) { $(this).parent().prepend(mongroup); }
				else { monlast.after(mongroup); }
			}
			mongroup.append($(this));
		}
		else 
		{
			monlast = $(this);
			monverrou = false;
		}
	});
	
	$(".xforms-label").each(function() {
		var simplifiedtext = $.trim($(this).text().toLowerCase());
		if (simplifiedtext == "load selected record") {
			var masection = $(this).closest(".input-group");
			if (masection.length > 0 && masection.parent().hasClass("fileLoading"))
			{
				masection.parent().after(masection);
			}
		}
	});
	
	manuforma_adaptmorehtml()
}

function manuforma_adaptmorehtml()
{
	$(".accordion-body hr:first-child").remove();
	$(".headerxform").show();
	$(".accordion-body > h4").each(function(){
		$(this).before('<span class="input-group-text">'+ $(this).text() +'</span>');
		$(this).remove();
	});
	
	var titleform = $(".accordion-body .btn-group:first-child span.input-group-text");
	titleform.each(function(){
		var accordion = $(this).closest(".accordion-body");
		accordion.prepend($(this));
		accordion.addClass("with-title");
	});
	
/*	$(".btn-group").removeClass("border-bottom");*/
	/*  I do not like having the attributes in this menu, it makes it crowded and messy, will check with max before removing it though. */
	/* 
	$(".element").each(function(){
		var latoolbar = $(this).siblings(".btn-toolbar");
		latoolbar.find(".btn-group").append($(this).find("> .attr-group"));
	}); 
	*/
	$(".btn-toolbar.elementControls").each(function(){
		if ($(this).find(".btn-group2").length <= 0) $(this).append($('<div class="btn-group2"></div>'));
		var mybtngrp2 = $(this).find(".btn-group2");
		mybtngrp2.append($(this).find(".btn-group > span.btn.controls"));
	});
	
	/* changed in the xslt 
	$(".btn .bi-plus-circle").removeClass("bi-plus-circle").addClass("bi-plus");
	$(".btn .bi-x-circle").removeClass("bi-x-circle").addClass("bi-x");
	$("img[src='resources/images/TEI-175.jpg']").attr("src","resources/images/hn/Text_Encoding_InitiativeTEI_Logo.svg");
	 */ 
	 
    /* Hide empty buttons.  */
       $(".btn-toolbar .input-group").each(function() {
            if ($(this).find(".xforms-group-content").children(".xforms-disabled").length > 0) $(this).hide();
      })
	 
	$(".xforms-alert-icon").addClass("nobackground").html($('<i class="bi bi-x-circle"></i> Cancel'));
	$("#edit .elementControls .justify-content-between").removeClass("justify-content-between");
}

function manuforma_prepareLoadObjectSVG(myobj) {
	console.log("loaded",$(myobj));
	var domsvg = myobj.getSVGDocument();
	// console.log("Loaded",domsvg);
	// setTimeout(manuforma_changecolorsvg,200,obj2,"white");
	manuforma_changecolorsvg(domsvg,"white");
}

function manuforma_started() {
	manuforma_adapthtml();
	
	$(".navbar-brand object.logo-filtered").on('load', function(){
		manuforma_prepareLoadObjectSVG(this);
	});
	$(".blochome object.logo-filtered").each(function(obj1){
		setTimeout(function(){
			manuforma_prepareLoadObjectSVG(obj1);
		},1000);
	});
	
	$(".blochome").on("mouseenter",function(){
		var monobj = $(this).find(".logo-filtered")[0];
		if (monobj) manuforma_changecolorsvg(monobj.getSVGDocument(),getComputedStyle(document.documentElement).getPropertyValue("--color-primary")); 
	});
	$(".blochome").on("mouseleave",function(){
		var monobj = $(this).find(".logo-filtered")[0];
		if (monobj) manuforma_changecolorsvg(monobj.getSVGDocument(),"black");
	}); 
	$(".blochome").on("click",function(){
		var monobj = $(this).find("a");
		document.location = monobj.attr("href");
	}); 
	
	var MutationObserver = window.MutationObserver || window.WebKitMutationObserver;
	var myObserver = new MutationObserver(manuforma_adaptmorehtml);
	var obsConfig = {
	  childList: true,
	  characterData: false,
	  attributes: true,
	  subtree: false
	};

	$("#edit > div").each(function() {
		myObserver.observe(this, obsConfig);
	});
}

const randomId = function(length = 6) {
  return Math.random().toString(36).substring(2, length+2);
};

document.addEventListener('readystatechange', event => { 
	if (event.target.readyState === "interactive") {
	}
	if (event.target.readyState === "complete") {
		setTimeout(manuforma_started,200);
    }
});
