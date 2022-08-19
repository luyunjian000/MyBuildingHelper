function TopNotification(msg) {
    AddNotification(msg, $('#TopNotifications'));
}

function BottomNotification(msg) {
    AddNotification(msg, $('#BottomNotifications'));
}



function simpleLocalize(str) {
    var result = str.replace(/\{#(.*?)\}/g, function(match, token) {
        // $.Msg(1212,token)
        return $.Localize("#" + token)
    });
    return result
}

function parseScript(script) {
    // $.Msg(script)
    var tokens = []
    while (script && script.length > 0) {
        var tokenStart = script.indexOf("<#")
        if (tokenStart == -1) {
            tokens.push(script)
            script = null
        } else if (tokenStart != 0) {
            tokens.push(script.substr(0, tokenStart))
            script = script.substr(tokenStart)
        } else {
            var tokenEnd = script.indexOf(">")
            tokens.push(script.substr(0, tokenEnd + 1))
            script = script.substr(tokenEnd + 1)
        }
    }
    var nodes = tokens.map(function(a) {
        var i = a.indexOf("<#")
        if (i == 0) {
            const txt = simpleLocalize(a.substr(a.indexOf(" ") + 1, a.length - 2 - a.indexOf(" ")))
            return [txt, a.substr(1, a.indexOf(" ") - 1)]
        } else {
            const txt = simpleLocalize(a)
            return ([txt, "#FFFFFF"])
        }
    })
    return nodes
}

String.formatArr = function() {
    var formatStr = arguments[0];
    var args = arguments[1]
    if (!args) {
        return formatStr
    }
    if (typeof formatStr === 'string') {
        for (var i = 0; i < args.length; i++) {
            pattern = new RegExp('\\{' + (i) + '\\}', 'g');
            formatStr = formatStr.replace(pattern, args[i]);
        }
    } else {
        formatStr = '';
    }
    return formatStr;
};
//  example <#BDFF00 text1 text2 text3/> 
function notify_top_script(msg) {
    var script = msg.script || ""
    var args = msg.args
    var scriptLocalized = $.Localize(script)
    if (args) {
        args = Object.keys(args)
            .map(function(key) {
                return args[key];
            });
    }
    var formatedStr = String.formatArr(scriptLocalized, args)

    var nodes = parseScript(formatedStr)

    for (let index = 0; index < nodes.length; index++) {
        const node = nodes[index]
            //$.Msg(node[0],node[1])
        AddNotification({ text: (node[0]), duration: 7.0, continue: (index != 0), style: { color: node[1] } }, $('#TopNotifications'))
    }
}

function NotifyMessage(msg) {
    var script = msg.script || ""
    var args = msg.args
    var scriptLocalized = $.Localize(script)
    if (args) {
        args = Object.keys(args)
            .map(function(key) {
                return args[key];
            });
    }
    var formatedStr = String.formatArr(scriptLocalized, args)
    var nodes = parseScript(formatedStr)
    for (let index = 0; index < nodes.length; index++) {
        const node = nodes[index]
            //$.Msg(node[0],node[1])
        AddNotification({ text: (node[0]), duration: 7.0, continue: (index != 0), style: { color: node[1], "font-size": "28px" } }, $('#TopNotifications'))
    }
}

function TopRemoveNotification(msg) {
    RemoveNotification(msg, $('#TopNotifications'));
}

function BottomRemoveNotification(msg) {
    RemoveNotification(msg, $('#BottomNotifications'));
}

function RemoveNotification(msg, panel) {
    var count = msg.count;
    if (count > 0 && panel.GetChildCount() > 0) {
        var start = panel.GetChildCount() - count;
        if (start < 0)
            start = 0;

        for (i = start; i < panel.GetChildCount(); i++) {
            var lastPanel = panel.GetChild(i);
            //lastPanel.SetAttributeInt("deleted", 1);
            lastPanel.deleted = true;
            lastPanel.DeleteAsync(0);
        }
    }
}

function AddNotification(msg, panel) {
    var newNotification = true;
    var lastNotification = panel.GetChild(panel.GetChildCount() - 1)
        //$.Msg(msg)

    msg.continue = msg.continue || false;
    //msg.continue = true;

    if (lastNotification != null && msg.continue)
        newNotification = false;

    if (newNotification) {
        lastNotification = $.CreatePanel('Panel', panel, '');
        lastNotification.AddClass('NotificationLine')
        lastNotification.hittest = false;
    }

    var notification = null;

    if (msg.hero != null)
        notification = $.CreatePanel('DOTAHeroImage', lastNotification, '');
    else if (msg.image != null)
        notification = $.CreatePanel('Image', lastNotification, '');
    else if (msg.ability != null)
        notification = $.CreatePanel('DOTAAbilityImage', lastNotification, '');
    else if (msg.item != null)
        notification = $.CreatePanel('DOTAItemImage', lastNotification, '');
    else
        notification = $.CreatePanel('Label', lastNotification, '');

    if (typeof(msg.duration) != "number") {
        //$.Msg("[Notifications] Notification Duration is not a number!");
        msg.duration = 3
    }

    if (newNotification) {
        $.Schedule(msg.duration, function() {
            //$.Msg('callback')
            if (lastNotification.deleted)
                return;

            lastNotification.DeleteAsync(0);
        });
    }

    if (msg.hero != null) {
        notification.heroimagestyle = msg.imagestyle || "icon";
        notification.heroname = msg.hero
        notification.hittest = false;
    } else if (msg.image != null) {
        notification.SetImage(msg.image);
        notification.hittest = false;
    } else if (msg.ability != null) {
        notification.abilityname = msg.ability
        notification.hittest = false;
    } else if (msg.item != null) {
        notification.itemname = msg.item
        notification.hittest = false;
    } else {
        notification.html = true;
        var text = msg.text || "No Text provided";
        notification.text = $.Localize(text)
        notification.hittest = false;
        notification.AddClass('TitleText');
    }

    if (msg.class)
        notification.AddClass(msg.class);
    else
        notification.AddClass('NotificationMessage');

    if (msg.style) {
        for (var key in msg.style) {
            var value = msg.style[key]
            notification.style[key] = value;
        }
    }
}

(function() {
    GameEvents.Subscribe("top_notification", TopNotification);
    GameEvents.Subscribe("bottom_notification", BottomNotification);
    GameEvents.Subscribe("top_remove_notification", TopRemoveNotification);
    GameEvents.Subscribe("bottom_remove_notification", BottomRemoveNotification);
    GameEvents.Subscribe("notify_message", NotifyMessage);

    GameEvents.Subscribe("notify_top_script", notify_top_script);
})();