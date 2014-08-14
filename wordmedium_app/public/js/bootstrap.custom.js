
// select emulation
$('.select-group ul li a').click(function(){
    var legend = $(this).closest('.select-group').find('.select-legend');
    if (legend) {
        legend.text($(this).text());
        legend.attr("value", $(this).attr("value"));
    }
    return true; // IMPORTANT!
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
                    // `data.redirect` must contain the string URL to redirect to
                    window.location.href = data.redirect;
                } else {
                    // handler to the event `formdata` must be binded to the form element
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



