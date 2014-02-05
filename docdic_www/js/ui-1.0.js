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
$('#swap').click(function(){
    var item = $('#source input').val();
    $('#source input').val($('#target input').val());
    $('#target input').val(item);
    
    item = $('#source > .ddselect_item').html();
    $('#source > .ddselect_item').html($('#target > .ddselect_item').html());
    $('#target > .ddselect_item').html(item);

    return false;
});
/* END of swap */

/* BEGIN of tabmenu */
$('.tab_container').load(function() {
    
});

$('.tab_list > a').click(function() {
    var $this = $(this);

});
/* END of tabmenu */