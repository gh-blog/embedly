through2 = require 'through2'
marked = require 'marked'
async = require 'async'
request = require 'request'
_ = template: require 'lodash.template'

# requires 'info'
# @TODO: unify this regexp across all plugins
externalRegExp = new RegExp '^((ftp|http)s?:)?//', 'i'

module.exports = (options = { api_key: '' }) ->
    { api_key } = options
    processFile = (file, enc, done) ->
        if file.isPost
            { $ } = file

            isExternal = (i, el) ->
                $el = $ el
                url = $el.attr('href') || $el.attr('src')
                if url and url.match externalRegExp
                    $el.data 'url', url
                    return yes
                return no

            # @TODO check options...
            # @TODO fix this
            isEmbeddable = (i, el) ->
                $el = $ el
                if $el.parent('p').text().trim() is $el.text().trim()
                    url = $el.data 'url'
                    return yes
                return no

            getOEmbed = (urls, callback) ->
                return callback null, [] if not urls.length
                # @TODO: iframely
                # req =
                #     url: "http://iframe.ly/api/oembed\
                #     ?api_key=#{secret.iframely.api_key}\
                #     &url=#{url}"
                req =
                    url: "http://api.embed.ly/1/oembed\
                    ?key=#{api_key}\
                    &urls=#{ urls.join ',' }\
                    &format=json"

                # @TODO DEBUG req.url
                console.log '[embedly] urls', urls

                request.get req, (err, res) ->
                    if err
                        # @TODO: log WARN
                        return callback err, []
                    try
                        jsonArray = JSON.parse res.body
                        return callback null, jsonArray
                    catch e
                        # @TODO: log DEBUG
                        return callback e, []

            getEmbed = (externals, callback) ->
                $externals = $ externals

                $urlElements = []
                urls = []

                $externals.each (i, el) ->
                    $el = $ el
                    url = $el.data 'url'
                    $urlElements.push $el
                    urls.push url

                getOEmbed urls, (err, jsonArray) ->
                    for jsonObj, i in jsonArray
                        try embed $urlElements[i], jsonObj
                        switch jsonObj.type
                            when 'video'
                                file.videos.push jsonObj.url
                            when 'image'
                                file.images.push jsonObj.url
                            when 'link'
                                file.links.push jsonObj.url
                            when 'audio'
                                file.audios.push jsonObj.url
                    callback()

            embed = ($el, json) ->
                if json.html
                    html = json.html
                else
                    html = "
                        <div class='media-container'>
                            <a href='${url}'>
                                <img
                                    src='${thumbnail_url}'
                                    style='
                                        width: ${thumbnail_width};
                                        height: ${thumbnail_height};
                                    '
                                />
                            </a>
                        </div>
                        <p>
                            ${description}
                        </p>
                    "
                    html = _.template html, json
                $el.replaceWith $(html).addClass('embed embedded embedly')


            externals = $('*:not(iframe):not(.embed)')
                .filter(isExternal)
                .filter(isEmbeddable).toArray()

            async.each externals, getEmbed, (err) ->
                file.contents = new Buffer $.html()
                done null, file
        else
            done null, file

    through2.obj processFile