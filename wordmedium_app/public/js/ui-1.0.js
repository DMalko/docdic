/*!
 * UI library
 * Version 1.0
*/

/* BEGIN of "selector" */
$('.ddselect > .ddselect_item').click(function(){
    $(this).siblings('.ddselect_list').toggle();

    return false;
});

$('.ddselect_item').click(function(){
    var svalue = $(this).html();
    var hvalue = $(this).children('.ddselect_hidden').text();
    $(this).closest('.ddselect').children('.ddselect_item').html(svalue);
    $(this).closest('.ddselect').children('input').val(hvalue);
    $(this).closest('.ddselect_list').hide();

    return false;
});
/* END of "selector" */

/* BEGIN of swap */
$('.swap').click(function(){
    var source = $(this).closest('.translbar').find('#source .ddselect_hidden:text');
    var target = $(this).closest('.translbar').find('#target .ddselect_hidden:text');
    var item = source.val();
    source.val(target.val());
    target.val(item);
    
    item = $('#source .ddselect > .ddselect_item').html();
    $('#source .ddselect > .ddselect_item').html($('#target .ddselect > .ddselect_item').html());
    $('#target .ddselect > .ddselect_item').html(item);

    return false;
});
/* END of swap */

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
    var emsg = $(this).find('.error-message');
    if (emsg) {
        emsg.html(data.msg);
        emsg.css('visibility', 'visible');
    }
});

$('form[data-autosubmit]').click(function(){
    var emsg = $(this).find('.error-message');
    if (emsg) {
        emsg.css('visibility', 'hidden');
    }
});
