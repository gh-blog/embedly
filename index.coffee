through2 = require 'through2'
marked = require 'marked'
async = require 'async'
request = require 'request'
_ = require 'lodash'

# requires 'info'

module.exports = (options = { api_key: '' }) ->
    { api_key } = options
    processFile = (file, enc, done) ->
        if file.isPost
            { $ } = file

            isExternal = (i, el) ->
                $el = $ el
                url = $el.attr('href') || $el.attr('src')

                if url and url.match /^http/i
                    $el.data 'url', url
                    return yes
                no

            # @TODO check options...
            # @TODO fix this
            isEmbeddable = (i, el) ->
                $el = $ el
                url = $el.data 'url'
                url and url.match /goodreads/gi

            getOEmbed = (urls..., done) ->
                return done null, [] if not urls.length
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

                request.get req, (err, res) ->
                    if err
                        # @TODO: log WARN
                        return done err, []
                    try
                        jsonArray = JSON.parse res.body
                        done null, jsonArray
                    catch e
                        # @TODO: log DEBUG
                        done e, []

            embed = ($el, json) ->
                $el.addClass 'embedded embedly'
                switch
                    when json.html
                        $el[i].html json.html
                    else
                        html = "
                            <a href='${url}'>
                            <img
                                src='${thumbnail_url}'
                                style='
                                    width: {$thumbnail_width};
                                    height: {$thumbnail_height};
                                '
                            />
                            </a>
                            <p>
                                ${description}
                            </p>
                        "
                        html = _.template html, json
                        $el.html html

            getEmbed = (externals, done) ->
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
                    done()

            externals = $('*')
                .filter(isExternal)
                .filter(isEmbeddable).toArray()

            async.each externals, getEmbed, (err) ->
                file.contents = new Buffer $.html()
                done null, file
        else
            done null, file

    through2.obj processFile