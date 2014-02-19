/* BEGIN of "menu container" */
$('.menu_label').click(function(){
    /* the objects can be enclosed! */
    var that = $(this).closest('.menu').find('.menu_label');
    var active_index = that.index(this);
    that.each(function(index){
        if (index == active_index) {
            $(this).addClass('active_label');
        }else{
            $(this).removeClass('active_label');
        }
    });
    $(this).closest('.menu_container').children('.menu_body').children('.body_content').each(function(index){
        if (index == active_index) {
            $(this).removeClass('hidden_content');
        }else{
            $(this).addClass('hidden_content');
        }
    });    
    return false;
});
/* END of "menu container" */