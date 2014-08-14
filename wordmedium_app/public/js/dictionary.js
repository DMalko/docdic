
// dictionary card rendering function
function makeCardTabs(cardStock) {
    
    if (!cardStock) { return 0 }
    
    var dictabs = $('#dic_tabs').html();
    var dicbody = $('#dic_body').html();
    
    var tab_id = 0;
    for (var dictionary in cardStock) {
        if (!cardStock.hasOwnProperty(dictionary)) continue;
        // make card tab
        dictabs += '<li class="pull-right';
        dicbody += '<div id="tab' + tab_id + '" class="tab-pane';
        if (tab_id == 0) {
            dictabs += ' active">';
            dicbody += ' active">';
        } else {
            dictabs += '">';
            dicbody += '">';
        }
        dictabs += '<a href="#tab' + tab_id + '" data-toggle="tab">' + dictionary + '</a></li>';
        tab_id++;
        // make card body
        for (var cid = 0, c_len = cardStock[dictionary].length; cid < c_len; cid++) {
            if (cardStock[dictionary][cid]) {
                var cardfield = $.parseJSON(cardStock[dictionary][cid]);
                
                var keyword     = cardfield[0];
                var wordforms   = cardfield[1];
                var alsouse     = cardfield[2];
                var comment     = cardfield[3];
                var definitions = cardfield[4];
                
                //dicbody += '<p class="dict-kword">' + keyword + '</p>';
                if (wordforms.length) {
                    dicbody += '<div class="dict-wform"><span class="dict-wform-legend">forms: </span>';
                    for (var formid = 0, form_len = wordforms.length; formid < form_len; formid++) {
                        dicbody += wordforms[formid][0];
                        if (wordforms[formid][1]) {
                            dicbody += '<span class="dict-wform-type"> (' + wordforms[formid][0] + ')</span>';
                        }
                        if (formid + 1 < form_len) {
                            dicbody += ', '
                        }
                    }
                    dicbody += '</div>';
                }
                if (alsouse.length) {
                    dicbody += '<div class="dict-alsou"><span class="dict-alsou-legend">also uses: </span>';
                    for (var useid = 0, use_len = alsouse.length; useid < use_len; useid++) {
                        dicbody += alsouse[useid][0];
                        if (alsouse[1]) {
                            dicbody += '<span class="dict-alsou-type"> (' + alsouse[useid][0] + ')</span>';
                        }
                        if (useid + 1 < use_len) {
                            dicbody += ', '
                        }
                    }
                    dicbody += '</div>';
                }
                if (comment.length) {
                    dicbody += '<div class="dict-comment">' + comment + '</div>';
                }
                if (definitions.length) {
                    dicbody += '<div class="dict-def">';
                    for (var defid = 0, def_len = definitions.length; defid < def_len; defid++) {
                        var pronuns   = definitions[defid][0];
                        var spchparts = definitions[defid][1];
                        
                        if (pronuns.length) {
                            for (var p = 0, p_len = pronuns.length; p < p_len; p++) {
                                var transcription = pronuns[p][0];
                                var sound         = pronuns[p][1];
                                var note          = pronuns[p][2];
                                
                                dicbody += '<div class="dict-pronun">';
                                dicbody += '<span class="dict-transcr">' + '[' + transcription + ']' + ' </span>';
                                if (sound) {
                                    dicbody += '<a class="dict-sound" href="' + sound + '"><span class="sound-image"></span></a>';
                                }
                                dicbody += '<span class="dict-note"> ' + note + '</span>';
                                dicbody += '</div>';
                            }
                        }
                        if (spchparts.length) {
                            for (var sp = 0, sp_len = spchparts.length; sp < sp_len; sp++) {
                                var speechpart = spchparts[sp][0];
                                var records    = spchparts[sp][1];
                                
                                dicbody += '<div class="dict-speechpart speechpart-' + speechpart + '">';
                                dicbody += '<div class="dict-speechpart-legend">' + speechpart + '</div>';
                                dicbody += '<table class="dict-transl-table">';
                                dicbody += '<tbody>';
                                if (records.length) {
                                    for (var t = 0, t_len = records.length; t < t_len; t++) {
                                        var rate        = records[t][0];
                                        var translation = records[t][1];
                                        var synonyms    = records[t][2];
                                        
                                        dicbody += '<tr class="dict-record">';
                                        dicbody += '<td class="dict-translation" rate="' + rate + '">' + translation + '</td>';
                                        dicbody += '<td class="dict-synonyms">';
                                        if (synonyms.length) {
                                            for (var s = 0, s_len = synonyms.length; s < s_len; s++) {
                                                dicbody += '<span class="dict-synonym">' + synonyms[s] + '</span>';
                                                if (s + 1 < s_len) {
                                                    dicbody += ', ';
                                                }
                                            }
                                        }
                                        dicbody += '</td>';
                                        dicbody += '</tr>';
                                    }
                                }
                                dicbody += '</tbody>';
                                dicbody += '</table>';
                                dicbody += '</div>';
                            }
                        }
                    }
                    dicbody += '</div>'; 
                }
            }
        }
        dicbody += '</div>';
    }
    $('#dic_tabs').html(dictabs);
    $('#dic_body').html(dicbody);
    
    return 1;
}

function extraTab() {
    
}

// dictionary tabs
$('#dic_tabs a').click(function (e) {
    e.preventDefault();
    $(this).tab('show');
})

// swapper
$('#lang_swapper').click(function(){
    var trn_from = $(this).closest('#dict_lang_panel').find('#trn_from');
    var trn_to = $(this).closest('#dict_lang_panel').find('#trn_to');
    
    var text_item = trn_from.text();
    var value_item = trn_from.attr("value");
    
    trn_from.text(trn_to.text());
    trn_from.attr("value", trn_to.attr("value"));
    
    trn_to.text(text_item);
    trn_to.attr("value", value_item);
    
    return false;
});

// translate form button
$('#btn-translate').click(function(){
    $('#trn_source').attr("value", $('#trn_from').attr("value"));
    $('#trn_target').attr("value", $('#trn_to').attr("value"));
    $('#trn_form').submit();
});

// dictionary tabs
$('#trn_form').bind('formdata', function(event, data) {
    $('#dict_msg_panel').html('');
    $('#dic_tabs').html('');
    $('#dic_body').html('');
    
    if (data.msg) {
        $('#dict_msg_panel').html(data.msg);
    } else {
        $('#trn_query').val('');
        $('#dict_msg_panel').html(data.word);
        makeCardTabs(data.trn);
    }
});
