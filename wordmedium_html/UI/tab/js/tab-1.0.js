/* BEGIN of "tab container" */
var itemtab = $('.tab_container .tab_label').click(function(){
    var active_index = itemtab.index(this);
    $(this).closest('.tab_list').find('.tab_label').each(function(index){
        if (index == active_index) {
            $(this).addClass('active_tab');
        }else{
            $(this).removeClass('active_tab');
        }
    });
    $(this).closest('.tab_container').find('.tab_content').each(function(index){
        if (index == active_index) {
            $(this).removeClass('hidden_content');
        }else{
            $(this).addClass('hidden_content');
        }
    });    
    return false;
});
/* END of "tab container" */