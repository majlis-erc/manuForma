$(document).ready(function () {
// Login or create new user
//Make sure passwords match ref: https://gist.github.com/grayghostvisuals/6984561

jQuery.validator.addMethod( 'passwordMatch', function(value, element) {
    
    // The two password inputs
    var password = $("#password").val();
    var confirmPassword = $("#passwordConfirm").val();

    // Check for equality with the password inputs
    if (password != confirmPassword ) {
        return false;
    } else {
        return true;
    }

}, "Your Passwords Must Match");

$('#newUserForm').validate({
    // rules
    rules: {
        password: {
            required: true,
            minlength: 3
        },
        passwordConfirm: {
            required: true,
            minlength: 3,
            passwordMatch: true // set this on the field you're trying to match
        }
    },

    // messages
    messages: {
        password: {
            required: "What is your password?",
            minlength: "Your password must contain more than 3 characters"
        },
        passwordConfirm: {
            required: "You must confirm your password",
            minlength: "Your password must contain more than 3 characters",
            passwordMatch: "Your Passwords Must Match" // custom message for mismatched passwords
        }
    }
});//end validate

function ConvertFormToJSON(form){
    var array = jQuery(form).serializeArray();
    var json = {};
    
    jQuery.each(array, function() {
        json[this.name] = this.value || '';
    });
    
    return json;
}  

$("#newUserForm").submit(function( event ) {
  event.preventDefault();
  var form = $(this);
  var url = $(this).attr('action');
  var data = ConvertFormToJSON(form);
  $.ajaxSetup({
    contentType: "application/json; charset=utf-8"
  });
  $.post(url, JSON.stringify(data), function(data) {
   var message = $(data).attr('message')
   // Return success 
   if(message == 'success') {
      $('#responseBody').html(message);
   } else {
         alert('Error: ' + message);
      $(form)[0].reset();
    }
    }).fail( function(jqXHR, textStatus, errorThrown) {
    // do fail notice
    console.log(textStatus);
  });
  //end post
});

//loginModal
$("#loginForm").submit(function( event ) {
  event.preventDefault();
  var form = $(this);
  var url = $(this).attr('action');
  $.post(url, form.serialize(), function(data) { 
    $('.modal-body').html('Logged in!');
  }).fail( function(jqXHR, textStatus, errorThrown) {
    // do fail notice
    alert('Wrong user name or password');
    console.log(textStatus);
  },'xml');
  //end post
});

$("#loginForm .closeModal").click(function( event ) {
    window.location.reload();
});

$("#newUserForm .closeModal").click(function( event ) {
//On close relaunch window, and relaunch login? at least for newUser? 
    window.location.reload();
});

//loginModal
$('#logout').click(function(event) {
  event.preventDefault();
  var url = $(this).attr('href');
  $.get(url, function(data) {
    window.location.reload()
 });
  //end post
});

/* 
$('.authenticate').click(function(event) {
  event.preventDefault();
  var url = $(this).attr('href');
  $.get('userInfo', function(data) {
    $.get(url, function(data) {
        window.location = url;
    });
  }).fail( function(jqXHR, textStatus, errorThrown) {
     console.log(textStatus);
  });  
}); 

*/
});

