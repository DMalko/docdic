/*!
 * UI library
 * Version 1.0
*/

/* BEGIN of "selector" */
$('.ddselect > .ddselect_item').click(function(){
    $(this).siblings('.ddselect_list').toggle();
});

$('.ddselect_item').click(function(){
    var svalue = $(this).html();
    var hvalue = $(this).children('.hidden_ddvalue').text();
    $(this).closest('.ddselect').children('.ddselect_item').html(svalue);
    $(this).closest('.ddselect').find('input').val(hvalue);
    $(this).closest('.ddselect_list').hide();
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
});
/* END of swap */