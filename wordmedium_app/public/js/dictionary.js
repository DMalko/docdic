
// dictionary card rendering function
function makeCardTabs(cardStock, cardStockExtra) {
    var dic = {tabs: '', body: ''};
    
    if (! (cardStock || cardStockExtra)) { return dic }
    
    var tab_id = 0;
    for (var dictionary in cardStock) {
        if (!cardStock.hasOwnProperty(dictionary)) continue;
        // make card tab
        dic.tabs += '<li class="pull-right';
        dic.body += '<div id="dic_tab' + tab_id + '" class="tab-pane';
        if (tab_id == 0) {
            dic.tabs += ' active">';
            dic.body += ' active">';
        } else {
            dic.tabs += '">';
            dic.body += '">';
        }
        dic.tabs += '<a href="#dic_tab' + tab_id + '" data-toggle="tab">' + dictionary + '</a></li>';
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
                
                //dic.body += '<p class="dic-kword">' + keyword + '</p>';
                if (wordforms.length) {
                    dic.body += '<div class="dic-wform"><span class="dic-wform-legend">forms: </span>';
                    for (var formid = 0, form_len = wordforms.length; formid < form_len; formid++) {
                        dic.body += wordforms[formid][0];
                        if (wordforms[formid][1]) {
                            dic.body += '<span class="dic-wform-type"> (' + wordforms[formid][0] + ')</span>';
                        }
                        if (formid + 1 < form_len) {
                            dic.body += ', '
                        }
                    }
                    dic.body += '</div>';
                }
                if (alsouse.length) {
                    dic.body += '<div class="dic-alsou"><span class="dic-alsou-legend">also uses: </span>';
                    for (var useid = 0, use_len = alsouse.length; useid < use_len; useid++) {
                        dic.body += alsouse[useid][0];
                        if (alsouse[1]) {
                            dic.body += '<span class="dic-alsou-type"> (' + alsouse[useid][0] + ')</span>';
                        }
                        if (useid + 1 < use_len) {
                            dic.body += ', '
                        }
                    }
                    dic.body += '</div>';
                }
                if (comment.length) {
                    dic.body += '<div class="dic-comment">' + comment + '</div>';
                }
                if (definitions.length) {
                    dic.body += '<div class="dic-def">';
                    for (var defid = 0, def_len = definitions.length; defid < def_len; defid++) {
                        var pronuns   = definitions[defid][0];
                        var spchparts = definitions[defid][1];
                        
                        if (pronuns.length) {
                            for (var p = 0, p_len = pronuns.length; p < p_len; p++) {
                                var transcription = pronuns[p][0];
                                var sound         = pronuns[p][1];
                                var note          = pronuns[p][2];
                                
                                dic.body += '<div class="dic-pronun">';
                                dic.body += '<span class="dic-transcr">' + '[' + transcription + ']' + ' </span>';
                                if (sound) {
                                    dic.body += '<a class="dic-sound" href="' + sound + '"><span class="sound-image"></span></a>';
                                }
                                dic.body += '<span class="dic-note"> ' + note + '</span>';
                                dic.body += '</div>';
                            }
                        }
                        if (spchparts.length) {
                            for (var sp = 0, sp_len = spchparts.length; sp < sp_len; sp++) {
                                var speechpart = spchparts[sp][0];
                                var records    = spchparts[sp][1];
                                
                                dic.body += '<div class="dic-speechpart speechpart-' + speechpart + '">';
                                dic.body += '<div class="dic-speechpart-legend">' + speechpart + '</div>';
                                dic.body += '<table class="dic-transl-table">';
                                dic.body += '<tbody>';
                                if (records.length) {
                                    for (var t = 0, t_len = records.length; t < t_len; t++) {
                                        var rate        = records[t][0];
                                        var translation = records[t][1];
                                        var synonyms    = records[t][2];
                                        
                                        dic.body += '<tr class="dic-record">';
                                        dic.body += '<td class="dic-translation" rate="' + rate + '">' + translation + '</td>';
                                        dic.body += '<td class="dic-synonyms">';
                                        if (synonyms.length) {
                                            for (var s = 0, s_len = synonyms.length; s < s_len; s++) {
                                                dic.body += '<span class="dic-synonym">' + synonyms[s] + '</span>';
                                                if (s + 1 < s_len) {
                                                    dic.body += ', ';
                                                }
                                            }
                                        }
                                        dic.body += '</td>';
                                        dic.body += '</tr>';
                                    }
                                }
                                dic.body += '</tbody>';
                                dic.body += '</table>';
                                dic.body += '</div>';
                            }
                        }
                    }
                    dic.body += '</div>'; 
                }
            }
        }
        dic.body += '</div>';
    }
    // extra dictionaries
    for (var dictionary in cardStockExtra) {
        if (!cardStockExtra.hasOwnProperty(dictionary)) continue;
        // make card tab
        dic.tabs += '<li class="pull-right';
        dic.body += '<div id="dic_tab' + tab_id + '" class="tab-pane';
        if (tab_id == 0) {
            dic.tabs += ' active">';
            dic.body += ' active">';
        } else {
            dic.tabs += '">';
            dic.body += '">';
        }
        dic.tabs += '<a href="#dic_tab' + tab_id + '" data-toggle="tab">' + dictionary + '</a></li>';
        tab_id++;
        // make card body
        for (var cEid = 0, c_len = cardStockExtra[dictionary].length; cEid < c_len; cEid++) {
            if (cardStockExtra[dictionary][cEid]) {
                //dic.body += '<p class="dic-kword">' + keyword + '</p>';
                dic.body += '<div class="dic-extracard">' + cardStockExtra[dictionary][cEid] + '</div>';
            }
        }
        dic.body += '</div>';
    }
    
    return dic;
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
        $('#dict_tab_panel').addClass("hide");
        $('#dict_msg_panel').html(data.msg);
    } else {
        $('#trn_query').val('');
        $('#dict_msg_panel').html(data.word);
        
        var dicData = makeCardTabs(data.trn, data.extra);
        
        $('#dic_tabs').html(dicData.tabs);
        $('#dic_body').html(dicData.body);
        $('#dict_tab_panel').removeClass("hide");
    }
});
