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