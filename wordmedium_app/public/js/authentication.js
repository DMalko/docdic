
// show alert message in signin, signout and passreset forms
$('#signup_form, #signin_form, #passreset_form').bind('formdata', function(event, data){
    var emsg = $(this).find('.alert');
    if (emsg) {
        emsg.find(".alert-message").html(data.msg);
        emsg.removeClass("alert-info alert-danger alert-success");
        if (data.msgtype == 'ok') {
            emsg.addClass("alert-success");
        } else {
            emsg.addClass("alert-danger");
        }
        emsg.removeClass("hide");
    }
});

// hide alert message in signin, signout and passreset forms
$('#signup_bar, #signin_bar, #passreset_bar').click(function(){
    var emsg = $(this).find('.alert');
    if (emsg) {
        emsg.addClass("hide");
    }
});