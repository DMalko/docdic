// select emulation
$('.select-group ul li a').click(function(){
    $(this).closest('.select-group').find('.select-legend').text($(this).text());

    return true; // IMPORTANT!
});

// swapper
$('#swapper').click(function(){
    var trn_from = $(this).closest('#lang_panel').find('#trn_from');
    var trn_to = $(this).closest('#lang_panel').find('#trn_to');
    
    var item = trn_from.text();
    trn_from.text(trn_to.text());
    trn_to.text(item);
    
    return false;
});

/* BEGIN of ajax form submit plugin */
(function($) {
    $.fn.autosubmit = function() {
        this.submit(function(event) {
            var form = $(this);
            $.ajax({
                type: form.attr('method'),
                url: form.attr('action'),
                data: form.serialize(),
                dataType: 'json'
            }).done(function(data) {
                if (data.redirect) {
                    // data.redirect must contain the string URL to redirect to
                    window.location.href = data.redirect;
                } else {
                    form.trigger('formdata', [data]);
                }
            }).fail(function() {
                alert("Wrong server response. Try again.");
            });
            event.preventDefault();
        });
    }
})(jQuery)
/* END of ajax form submit plugin */

$(function() {
    $('form[data-autosubmit]').autosubmit();
});

$('form[data-autosubmit]').bind('formdata', function(event, data){
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

$('form[data-autosubmit]').click(function(){
    $(this).find('.alert').addClass("hide");
});

// dictionary tabs
$('#dictab a').click(function (e) {
    e.preventDefault();
    $(this).tab('show');
})
