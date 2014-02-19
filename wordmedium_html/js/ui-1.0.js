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
